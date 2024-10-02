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

    @entityAD_name = "DATA"
    @modelFrameAD_name = "FRAMES"

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
        @cornerObjects[order]["AD"] = currentEntity.attribute_dictionaries["DATA"].to_h
        currentPostID = currentEntity.name.split(" ")[-1].to_i
        @cornerObjects[order]["DATA"] = eval(Sketchup.active_model.get_attribute(@modelFrameAD_name, currentPostID))["Data"]
        @cornerObjects[order]["DATA"] = eval(@cornerObjects[order]["DATA"])
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
    mainFrameData = @cornerObjects[0]["DATA"]
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
    entityAD_name = "DATA"

    ##Merge Angle Frame and Door Frame if needed
    if @cornerObjects.length == 3
      #Move angle and door frame to connect their positions on Frame
      ##Extract OSS thickness
      angleFrameData = @cornerObjects[1]["DATA"]
      angleOSSthickness = PH::CFG.getOCLmaterialData(angleFrameData["MAT"]["OSS"])["Thickness"]
      angleCMP = angleFrameData["FRAME"]["CMP"]

      doorFrameData = @cornerObjects[2]["DATA"]
      doorOSSthickness = PH::CFG.getOCLmaterialData(doorFrameData["MAT"]["OSS"])["Thickness"]
      doorCMP = doorFrameData["FRAME"]["CMP"]

      ##Evaluate connexions gap
      angleGap = angleOSSthickness + angleCMP
      doorGap = doorOSSthickness + doorCMP
      connexionGap = angleGap + doorGap
      connexionGap *= -1 if @data["ANGLE"]["POS"]=="L"

      #Stick them together
      ##Localise stick positions
      angleStickSide = @data["ANGLE"]["POS"]=="L" ? "LBT" : "RBT"
      doorStickSide = @data["ANGLE"]["POS"]=="L" ? "RBT" : "LBT"

      ##Apply it
      stickFrames(@cornerObjects[1]["ENT"], @cornerObjects[2]["ENT"], doorStickSide, angleStickSide, argOffset=[connexionGap,0,0])


      #STUDS
      #Angle Connexion Studs
      ##Retrieve the entities
      angleFrame_StudsPID = eval(@cornerObjects[1]["ENT"].get_attribute(entityAD_name, "STUDS|OSS", "")) +
                            eval(@cornerObjects[1]["ENT"].get_attribute(entityAD_name, "STUDS|FIN", ""))
      angleFrame_Studs = Sketchup.active_model.find_entity_by_persistent_id(angleFrame_StudsPID)

      ##Delete the connexion Studs
      angleDeleteSideName = (@data["ANGLE"]["POS"]=="R") ? "_Left" : "_Right"
      angleFrame_Studs.each do |currentCI|
        currentCI.erase! if currentCI.definition.name.include? angleDeleteSideName
      end


      #Door Connexion Studs
      ##Retrieve the Stud entities
      doorFrame_StudsPID = eval(@cornerObjects[2]["ENT"].get_attribute(entityAD_name, "STUDS|OSS", "")) +
                           eval(@cornerObjects[2]["ENT"].get_attribute(entityAD_name, "STUDS|FIN", ""))
      doorFrame_Studs = Sketchup.active_model.find_entity_by_persistent_id(doorFrame_StudsPID)

      ##Filter connexion Studs to modify on the center side
      doorFrame_sideStuds_Partname = (@data["ANGLE"]["POS"]=="L") ? "_Left" : "_Right"
      doorFrame_sideStuds_CI = doorFrame_Studs.select{|current| current.definition.name.include? doorFrame_sideStuds_Partname}

      ##Evaluate the PushPull value
      angleFrameHighest = @cornerObjects[1]["ENT"].bounds.depth.to_mm

      ##Duplicate the CD before modifying them
      doorFrame_sideStuds_CI.collect! do |currentCI|
        pushPullValue = angleFrameHighest.to_i - (angleFrameData["FRAME"]["CMP"] + angleFrameData["FRAME"]["CMPB"])

        #Make duplication
        newCI = currentCI.make_unique
        newCD = newCI.definition
        newCD.name = "PA#{@ID}|#{newCD.name.split("|")[-1].split("_")[0]}_Central"

        #Alter FIN stud height
        if newCD.name.include? "FIN"
          pushPullValue -= angleFrameData["OH"]["H"]
          #pushPullValue -= 55
        end

          #PushPull the highest faces
        inbetweenStudHighestFace = newCD.entities.findFace("Z", 0, ">")[0]
        inbetweenStudHighestFace.pushpull(-pushPullValue.mm)

        #Call the new Component Instance to collect it
        newCI
      end


      #ANGLE PX RESIZE
      ##Retrieve the XPS items
      angleFrame_XPSpid = eval(@cornerObjects[1]["ENT"].get_attribute(entityAD_name, "XPS|PX", 0)) +
                          eval(@cornerObjects[1]["ENT"].get_attribute(entityAD_name, "XPS|BOT", 0))
      angleFrame_XPS = Sketchup.active_model.find_entity_by_persistent_id(angleFrame_XPSpid)

      ##Evaluate the PushPull value
      gapValue = angleFrameData["FRAME"]["CMP"]
      gapValue *= -1 if (@data["ANGLE"]["POS"] == "L")

      ##Duplicate the CD before modifying them
      angleFrame_XPS.collect! do |currentCI|
        #Make duplication
        newCI = currentCI.make_unique
        newCD = newCI.definition
        newCD.name = "PA#{@ID}|#{newCD.name.split("|")[-1]}"

        #PushPull the highest faces
        borderFace = newCD.entities.findFace("X", 0, "==")[0]
        borderFace.pushpull(-gapValue.mm)

        #Call the new Component Instance to collect it
        newCI
      end

      exit









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
          searchLimit = angleFrameData["FRAME"]["CMP"]
          searchSymbol = ">"
        end

        currentPX_face, position = currentPX.definition.entities.findFace("X", searchLimit, searchSymbol)

        #Modify the height
        currentPX_face.pushpull(-angleFrameData["FRAME"]["CMP"].mm)
      end

      #CAISSONS CV
      #Split Vert and Horiz to merge frames parts
      ##Get angle/door AD
      angle_entityAD = @cornerObjects[1]["AD"]
      puts
      door_entityAD = @cornerObjects[2]["AD"]

      ["CHA", "XPS|PX", "XPS|BOT"]
      ##Build Caisson CV data
      caisonsObjectsVH = {"CV"=>{"H"=>[angle_entityAD["CV|VH"],
                                       door_entityAD["CV|VH"]],
                                 "V"=>[angle_entityAD["CV|VV"],
                                       door_entityAD["CV|VV"]]},
                          "CVOH"=> {"H"=>[angle_entityAD["CV|SHH"],
                                          door_entityAD["CV|SHH"]],
                                    "V"=>[angle_entityAD["CV|SHV"],
                                          door_entityAD["CV|SHV"]]},
                          'NO'=> {"CHA"=>[angle_entityAD["CHA"],
                                          door_entityAD["CHA"]],
                                  "XPS|PX"=>[angle_entityAD["XPS|PX"],
                                          door_entityAD["XPS|PX"]],
                                  "XPS|BOT"=>[angle_entityAD["XPS|BOT"],
                                          door_entityAD["XPS|BOT"]]
                          }
      }

      ##Reterieve objects from PID
      stop = 0
      caisonsObjectsVH.each_pair do |cvKey, cvContent|
        cvObjects = cvContent.collect do |alignKey, alignValue|
            #Convert PID string to value
            alignValue.collect!{|current| eval(current.to_s).nil? ? "".to_i : eval(current.to_s)[-1].to_i}

            #Convert to object
            alignValue.collect!{|current| Sketchup.active_model.find_entity_by_persistent_id(current)}

            #Update value with object extracted from persistent ID
            caisonsObjectsVH[cvKey][alignKey] = alignValue
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

          #Move UP merge elements
          toComponent.move!([0, 0, 55.mm])

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

  def mergeFrames(argEntity1, argEntity2)

  end

  def stickFrames(argEntityFix, argEntityToMove, argFixPosition, argMovePosition, argOffset=[0,0,0])
    bboxAngles = ["LFB", "RFB", "LBB", "RBB", "LFT", "RFT", "LBT", "RBT"]
    raise "argEntityFix is not type of Sketchup::Entity" unless argEntityFix.is_a? Sketchup::Entity
    raise "argEntityToMove is not type of Sketchup::Entity" unless argEntityToMove.is_a? Sketchup::Entity
    raise "argCorner is not a valid String #{bboxAngles}" unless bboxAngles.include? argFixPosition
    raise "argCorner is not a valid String #{bboxAngles}" unless bboxAngles.include? argMovePosition
    raise "argOffset is not a valid Array[3]" unless argOffset.is_a? Array and argOffset.length == 3

    #Convert positions to bbox angle value
    cornerPositionsInd = [argFixPosition, argMovePosition].collect do |currentPosition|
      bboxAngleNum = nil
      case currentPosition
        when "LFB"; bboxAngleNum = 0
        when "RFB"; bboxAngleNum = 1
        when "LBB"; bboxAngleNum = 2
        when "RBB"; bboxAngleNum = 3
        when "LFT", bboxAngleNum = 4
        when "RFT"; bboxAngleNum = 5
        when "LBT"; bboxAngleNum = 6
        when "RBT"; bboxAngleNum = 7
      end

      #Call value to return
      bboxAngleNum
    end

    #Get the sides stick positions
    postionFrom = argEntityToMove.bounds.corner(cornerPositionsInd[1]).to_a.collect{|coord| coord.to_mm}
    postionTo = argEntityFix.bounds.corner(cornerPositionsInd[0]).to_a.collect{|coord| coord.to_mm}

    ##Move and adjust the connexion
    moveToConnect = postionTo.each_with_index.map{|value, index| (value - postionFrom[index] + argOffset[index]).mm}
    argEntityToMove.move!(moveToConnect)
  end

  def getStickPoint(argDrawingelement, argCorner, argWorldPosation:false, argToMM:true)
    raise "argDrawingelement is not type of Sketchup::Drawingelement" unless argDrawingelement.is_a? Sketchup::Drawingelement
    raise "argCorner is not a valid Integer (0..7)" unless argCorner.is_a? Integer and (0..7).include? argCorner
    raise "argWorldPosation is not type of Boolean" unless [true, false].include? argWorldPosation
    raise "argToMM is not type of Boolean" unless [true, false].include? argToMM

    # CORNERS LFB RRT
    # - 0 = [0, 0, 0] (left front bottom)
    # - 1 = [1, 0, 0] (right front bottom)
    # - 2 = [0, 1, 0] (left back bottom)
    # - 3 = [1, 1, 0] (right back bottom)
    # - 4 = [0, 0, 1] (left front top)
    # - 5 = [1, 0, 1] (right front top)
    # - 6 = [0, 1, 1] (left back top)
    # - 7 = [1, 1, 1] (right back top)


    #Get the local context position
    resultPosition = argDrawingelement.bounds.corner(argCorner)

    if argWorldPosation
      ##TO FILL##
    end

    #Convert values to mm
    resultPosition.collect!{|currentValue| currentValue.to_mm} if argToMM

    return resultPosition
  end
end