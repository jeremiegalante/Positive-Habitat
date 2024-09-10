#Load generic Requires
require 'json'

#Load PH Requires
require_relative 'PH'
#require_relative 'patch/hash'
#require_relative 'patch/constructionPoint'
require_relative 'Frame'
require_relative 'patch/skp_drawingElement'
require_relative 'patch/skp_entities'
require_relative 'patch/skp_entity'
#require_relative 'patch/skp_attributeDictionary'

class PH::CornerFrame
  #CLASS VARIABLE
  @@posteXpos = {}
  @@nextPosteXpos = 0
  @@posteNextYPos = {}
  @@posteData = {}
  @@store = {}

  #CLASS VARIABLE ACCESSORS
  def self.posteData; return @@posteData; end

  #INSTANCE VARIABLE
  @ID = nil
  @atCoord =[]
  @cornerObjects = []
  @object
  @objectPurgeEntities = []
  @data = {}
  @angleData = {}

  #INSTANCE VARIABLE ACCESSORS
  attr_reader :mainObject
  attr_reader :borderObject
  attr_reader :doorObject

  def initialize(argCornerNomenclature)
    raise "argCornerNomenclature is not type of Hash" unless argCornerNomenclature.is_a? Hash

    #ID GENERATION
    #Change the ID in case a Frame already exists with the same ID and not the same data
    @ID = 10
    @@posteData.keys.sort.each do |currentID|
      break if currentID > @ID
      @ID += 10 if @@posteData[currentID] != @data
    end

    #CREATE
    @object = Sketchup.active_model.entities.add_group()
    toDelete = @object.entities.add_cpoint([0,0,0])
    @object.name = "POSTE ANGLE #{@ID}"

    #BUILD ENTITIES SELECTED DATA
    @data = argCornerNomenclature
    @cornerObjects = []

    PH::SelectionObserver.selection.each_pair do |currentEntity, order|
      #Ignore if no object is given
      unless currentEntity.nil?
        #Store the current Frame data
        @cornerObjects[order] = {}
        @cornerObjects[order]["ENT"] = currentEntity
        #@cornerObjects[order]["COPY"] = @object.entities.add_instance(currentEntity.definition, currentEntity.transformation).make_unique
        @cornerObjects[order]["FRAME"] = PH::Frame.store[currentEntity]
      end
    end

    #DATA
    #Store the new data generated
    @@posteData[@ID] = @data unless @@posteData.keys.include?(@ID)

    toDelete.erase!
  end

  def assemble
    #START OPERATION
    #Sketchup.active_model.start_operation("Assemble Corner Frame #{@poste_name}", disable_ui:true, next_transparent:false, transparent:false)

    #MAIN FRAME
    mainFrameData = @cornerObjects[0]["FRAME"].data
    mainFrameEntity = @cornerObjects[0]["ENT"]

    ##Place the requested side at the world origin
    moveToOrigin = mainFrameEntity.getConnexionPoint(arg_leftSide:(@data["ANGLE"]["POS"] == "L"), arg_frontSide:false, arg_bottomSide:false)

    if @data["ANGLE"]["POS"] == "L"
      moveToOrigin[0] = 0
    elsif @data["ANGLE"]["POS"] == "R"
      cornerLeftRearTop = mainFrameEntity.bounds.corner(6).to_a.collect{|coord| coord.to_mm}
      cornerRightRearTop = mainFrameEntity.bounds.corner(7).to_a.collect{|coord| coord.to_mm}
      moveToOrigin[0] = cornerRightRearTop[0] - cornerLeftRearTop[0]
    end

    ##Move connection position to origin
    moveToOrigin.collect!{|coord| -coord.round.mm}
    mainFrameEntity.move!(moveToOrigin)

    #DOOR FRAME
    ##Merge Angle Frame and Door Frame if needed
    if @cornerObjects.length == 3
      #Move angle and door frame to connect their positions on Frame
      ##Extract OSS thickness
      angleFrameData = @cornerObjects[1]["FRAME"].data
      angleOSSthickness = PH::CFG.getOCLmaterialData(angleFrameData["MAT"]["OSS"])["Thickness"]
      angleCMP = angleFrameData["FRAME"]["CMP"]

      doorFrameData = @cornerObjects[2]["FRAME"].data
      doorOSSthickness = PH::CFG.getOCLmaterialData(doorFrameData["MAT"]["OSS"])["Thickness"]
      doorCMP = doorFrameData["FRAME"]["CMP"]

      ##Evaluate connexions gap
      angleGap = angleOSSthickness + angleCMP
      doorGap = doorOSSthickness + doorCMP
      connexionGap = angleGap + doorGap
      connexionGap *= -1 if @data["ANGLE"]["POS"]=="R"

      ##Regroup them in a manipulation sub-group
      unifiedFrame = @object.entities.add_group()
      toDelete = unifiedFrame.entities.add_cpoint([0,0,0])
      unifiedFrame.name = "Unified Frames"

      [1,2].each do |currentIndex|
        moveEntity = @cornerObjects[currentIndex]["ENT"].move(unifiedFrame)

        #Remove the original entity
        @cornerObjects[currentIndex]["ENT"].erase!
        @cornerObjects[currentIndex]["ENT"] = moveEntity
      end
      toDelete.erase!

      ##Extract the connecting positions
      angleRearTop = @cornerObjects[1]["ENT"].bounds.corner(@data["ANGLE"]["POS"]=="L" ? 6 : 7).to_a.collect{|coord| coord.to_mm}
      doorRearTop = @cornerObjects[2]["ENT"].bounds.corner(@data["ANGLE"]["POS"]=="L" ? 7 : 6).to_a.collect{|coord| coord.to_mm}

      ##Move and adjust the connexion
      moveToConnect = angleRearTop.each_with_index.map{|value, index| (value - doorRearTop[index]).mm}
      moveToConnect[0] = (moveToConnect[0].to_mm + connexionGap).mm
      @cornerObjects[2]["ENT"].move!(moveToConnect)

      #STUDS
      angleSideName =  (@data["ANGLE"]["POS"]=="L") ? "_Left" : "_Right"
      doorSideName =  (@data["ANGLE"]["POS"]=="L") ? "_Right" : "_Left"

      #Deal with the angle studs
      ##Filter the angle component instance studs
      angleStuds = @cornerObjects[1]["ENT"].entities.to_a.select{|currentEntity| currentEntity.is_a?(Sketchup::ComponentInstance)}
      angleStuds.select!{|currentInstance| currentInstance.definition.name.include? angleSideName}

      ##Delete them
      angleStuds.each {|current| current.erase!}

      #Deal with the door studs
      ##Filter the door component instance studs
      doorStuds = @cornerObjects[2]["ENT"].entities.to_a.select{|currentEntity| currentEntity.is_a?(Sketchup::ComponentInstance)}
      doorStuds.select!{|currentInstance| currentInstance.definition.name.include? doorSideName}

      ##Reduce their height
      studPX = nil
      studFIN = nil

      doorStuds.each do |current|
        #Make a new definition
        cdName = current.definition.name
        current.make_unique
        current.definition.name = "PA#{@ID}|#{cdName.split("|")[-1].split("_")[0]}_Central"

        studPX = current if cdName.include? "PX"
        studFIN = current if cdName.include? "FIN"
      end

      #Resize the stud PX
      ##Find the highest face
      highestFace, altFace = studPX.definition.entities.findFace("Z", 0, ">=")

      ##Altitude of angle frame
      angleBBox = @cornerObjects[1]["ENT"].bounds
      altAngleFrame = (angleBBox.min[-1]-angleBBox.max[-1]).to_mm.round

      #Modify the height
      highestFace.pushpull(altAngleFrame.mm)

      #Resize the stud FIN
      ##Find the highest face
      highestFace, altFace = studFIN.definition.entities.findFace("Z", 0, ">=")

      #Modify the height
      highestFace.pushpull((studPX.bounds.depth.to_mm - studFIN.bounds.depth.to_mm).mm)

      #Adjust the length of the angle XPS items
      ##Filter the door component instance XPS items
      anglePXitems = @cornerObjects[2]["ENT"].entities.to_a.select{|currentEntity| currentEntity.is_a?(Sketchup::ComponentInstance)}
      anglePXitems.select!{|currentInstance| currentInstance.definition.name.include? "BAS PX" or currentInstance.definition.name.include? "XPS PX"}

      anglePXitems.each do |currentPX|
        #Make a new definition
        cdName = currentPX.definition.name
        currentPX.make_unique
        currentPX.definition.name = "PA#{@ID}|#{cdName.split("|")[-1]}"

        #Find the extreme position face
        currentPX_face = nil
        searchLimit = 0
        searchSymbol = ">="
        if @data["ANGLE"]["POS"]=="R"
          searchLimit = @cornerObjects[1]["FRAME"].data["FRAME"]["CMP"]
          searchSymbol = ">"
        end

        currentPX_face, position = currentPX.definition.entities.findFace("X", searchLimit, searchSymbol)

        #Modify the height
        currentPX_face.pushpull(-@cornerObjects[1]["FRAME"].data["FRAME"]["CMP"].mm)
      end

      #CAISSONS CV
      #Filter items of caisson CV
      caisonsObjects = {"CV"=>[], "CVOH"=>[]}
      [1,2].each do |index|
        #Filter the component instance for the caissons
        caisonsObjects["CV"] += @cornerObjects[index]["ENT"].filterItems(["Caisson CV"])
        caisonsObjects["CVOH"] += @cornerObjects[index]["ENT"].filterItems(["Caisson CV Sur-Hauteur"])
      end
      caisonsObjects["CV"] = caisonsObjects["CV"] - caisonsObjects["CVOH"]

      #Split Vert and Horiz to merge frames parts
      caisonsObjectsVH = {"CV"=>{"H"=>[], "V"=>[]}, "CVOH"=> {"H"=>[], "V"=>[]}}
      caisonsObjects.each do |currentKey, currentItems|
        #Deal with H
        currentItems.each do |caissonGroup|
          caissonGroup.entities.to_a.each do |singleItem|
            caisonsObjectsVH[currentKey]["H"] << singleItem if singleItem.definition.name.include?("Horizontal")
            caisonsObjectsVH[currentKey]["V"] << singleItem if singleItem.definition.name.include?("Vertical")
          end
        end
      end

      #Regroup the caissons items
      toDelete = []

      caisonsObjectsVH.each do |currentSet, currentGroup|
        currentGroup.each do |currentAlignment, currentInstances|
          ##Store merge items before merging them
          caisonObjectName = currentInstances.collect{|current| current.definition.name.split("|")[-1]}.uniq[0]
          caisonObjectMat = currentInstances.collect{|current| current.material}.uniq[0]

          #Create container of the objects to merge
          toComponent = @object.entities.add_group()
          toDelete << toComponent.entities.add_cpoint([0,0,0])

          #Merge items
          currentInstances.collect!{|currentItem| currentItem.move(toComponent)}

          ##Get position to place the door item
          angleItemPos = currentInstances[0].bounds.corner(@data["ANGLE"]["POS"]=="L" ? 6 : 7)
          doorItemPos = currentInstances[1].bounds.corner(@data["ANGLE"]["POS"]=="L" ? 7 : 6)

          ##Move and adjust the connexion
          moveToConnect = angleItemPos.to_a.each_with_index.map{|value, index| value - doorItemPos[index]}
          currentInstances[1].move!(moveToConnect)

          #Reduce length of the door item to remove the compriband(CMP) spaces
          currentInstances[1] = currentInstances[1].make_unique
          findSymbol = (@data["ANGLE"]["POS"]=="L" ? "==" : ">")
          faceToPush, drop = currentInstances[1].definition.entities.findFace("X", 0, findSymbol)
          faceToPush.pushpull(-(angleCMP + doorCMP).mm)

          ##Explode Items and save SKP parameters
          ###Explode the old instances
          currentInstances.collect!{|itm| itm.explode}

          #Clean and generate the component instance
          ##Define the Bbox min point
          deleteBBoxMin = toComponent.bounds.min.to_a.collect{|value| value.to_mm}
          deleteBBoxMin[0] += 1

          ##Define the Bbox max point
          deleteBBoxMax = toComponent.bounds.max.to_a.collect{|value| value.to_mm}
          deleteBBoxMax[0] -= 1

          ##Delete middle merge edges
          deleteBBox = Geom::BoundingBox.new()
          [deleteBBoxMin, deleteBBoxMax].each{|currentBBox| deleteBBox.add(currentBBox.collect{|value| value.mm})}

          edgesListing = toComponent.entities.to_a.select{|elem| elem.class == Sketchup::Edge}
          edgesListing.each do |currentEdge|
            #If the edge as not be deleted automatically
            unless currentEdge.deleted?
              #Check if this edge is in the deleting bbox
              vertexStartIn = deleteBBox.contains?(currentEdge.vertices[0])
              vertexEndIn = deleteBBox.contains?(currentEdge.vertices[1])

              #Delete the edge if it s included in the deleting bbox
              currentEdge.erase! if vertexStartIn and vertexEndIn
            end
          end

          #Create Component Instance
          mergeComponent = toComponent.to_component
          mergeComponent.definition.name = "PA#{@ID}|#{caisonObjectName}"
          mergeComponent.material = caisonObjectMat

          #Replace the Merge Component
          ##Define height according the actual set
          heightMoveValue = angleFrameData["FRAME"]["H"] + angleFrameData["FRAME"]["CMPB"] + angleFrameData["FRAME"]["CMP"]
          heightMoveValue += angleFrameData["CV"]["H"] if currentSet == "CVOH"
          vector_mm = [0,0,heightMoveValue.mm]

          ##Move the merge component
          moveMergeTo = Geom::Transformation.new(vector_mm)
          mergeComponent.move!(moveMergeTo)

          #Delete the non merged items
          #currentInstances.each{|currentNonMerge| currentNonMerge.erase!}
        end
      end

      #Clean Construction Points
      #toDelete.each{|temp| temp.erase!}

      ##Delete the angle Frame studs


    end

    #ANGLE FRAME


    '
    #CLEAN/DELETE SECURITY ENTITIES
    @objectPurgeEntities.each {|entityToDelete| entityToDelete.erase! unless entityToDelete.deleted?}
    '

    '
    #MOVE AT THE RIGHT POSITION
    atCoord_mm = @atCoord.collect {|value| value.mm}
    moveTo = Geom::Transformation.new(atCoord_mm)
    @object.move!(moveTo)
    '

    #FINALISE OPERATION
    #commit_result = Sketchup.active_model.commit_operation
    #raise "Assemble Angle Pré-Cadre has been an unsuccessful result when committing it " unless commit_result
  end
end