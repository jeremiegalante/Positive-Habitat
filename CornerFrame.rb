#Load generic Requires
require 'json'

#Load PH Requires
require_relative 'PH'
#require_relative 'patch/hash'
#require_relative 'patch/constructionPoint'
require_relative 'Frame'
require_relative 'patch/skp_drawingElement'
require_relative 'patch/skp_entities'
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
        @cornerObjects[order]["COPY"] = @object.entities.add_instance(currentEntity.definition, currentEntity.transformation)
        @cornerObjects[order]["FRAME"] = PH::Frame.store[currentEntity]
      end
    end

    #ID GENERATION
    #Change the ID in case a Frame already exists with the same ID and not the same data
    @ID = 10
    @@posteData.keys.sort.each do |currentID|
      break if currentID > @ID
      @ID += 10 if @@posteData[currentID] != @data
    end

    #DATA
    #Store the new data generated
    @@posteData[@ID] = @data unless @@posteData.keys.include?(@ID)

    toDelete.erase!
  end

  def assemble
    #START OPERATION
    Sketchup.active_model.start_operation("Assemble Corner Frame #{@poste_name}", disable_ui:true, next_transparent:false, transparent:false)

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

    #ANGLE FRAME
    #toAlign = nil

    #DOOR FRAME
    ##Merge Angle Frame and Door Frame if needed
    if @cornerObjects.length == 3
      #Find the door Pré-cadre
      'doorFramePC = nil
      @cornerObjects[2]["ENT"].entities.each do |current_entity|
        if current_entity.class == Sketchup::Group and current_entity.name == "Pré-Cadre Fenêtre"
          doorFramePC = current_entity
          break
        end
      end'

      #Extract the connecting positions
      angleRightRearTop = @cornerObjects[1]["ENT"].bounds.corner(7).to_a.collect{|coord| coord.to_mm}
      doorLeftRearTop = @cornerObjects[2]["ENT"].bounds.corner(6).to_a.collect{|coord| coord.to_mm}

      #Move angle and door frame to connect their positions on Frame
      ##Extract OSS thickness
      angleFrameData = @cornerObjects[1]["FRAME"].data
      angleOSSthickness = PH::CFG.getOCLmaterialData(angleFrameData["MAT"]["OSS"])["Thickness"]
      angleCMP = angleFrameData["FRAME"]["CMP"]

      doorFrameData = @cornerObjects[2]["FRAME"].data
      doorOSSthickness = PH::CFG.getOCLmaterialData(doorFrameData["MAT"]["OSS"])["Thickness"]
      doorCMP = doorFrameData["FRAME"]["CMP"]

      ##Move and adjust the connexion
      moveToConnect = angleRightRearTop.each_with_index.map{|value, index| (value - doorLeftRearTop[index]).mm}
      moveToConnect[0] = (moveToConnect[0].to_mm - ((angleOSSthickness + angleCMP)  + (doorOSSthickness + doorCMP))).mm
      @cornerObjects[2]["ENT"].move!(moveToConnect)

      ##Regroup them in a manipulation sub-group
      unifiedFrame = @object.entities.add_group(@cornerObjects[1]["ENT"], @cornerObjects[2]["ENT"])
      unifiedFrame.name = "Unified Angle/Door Frames"

      #STUDS
      l_name = "_Left"
      r_name = "_Right"

      #Deal with the angle right studs
      ##Filter the angle component instance studs
      angleStuds = @cornerObjects[1]["FRAME"].items["STUDS|OSS"] + @cornerObjects[1]["FRAME"].items["STUDS|FIN"]
      angleStuds.select! do |current|
        cdName = current.definition.name
        current.class == Sketchup::ComponentInstance and cdName.include? r_name
      end

      ##Delete them
      angleStuds.each {|current| current.erase!}

      #Deal with the door left studs
      ##Filter the door component instance studs
      doorStuds = @cornerObjects[2]["FRAME"].items["STUDS|OSS"] + @cornerObjects[2]["FRAME"].items["STUDS|FIN"]
      doorStuds.select! do |current|
        cdName = current.definition.name
        current.class == Sketchup::ComponentInstance and cdName.include? l_name
      end

      ##Reduce their height
      doorStuds.each do |current|
        #Make a new definition
        cdName = current.definition.name
        current.make_unique
        current.definition.name = "PA#{@ID}|#{cdName.split("|")[-1].split("_")[0]}_Central"

        #Find the highest face
        highestFace, altFace = current.definition.entities.findFace("Z", 0, ">=")

        #Altitude of angle frame
        angleBBox = @cornerObjects[1]["ENT"].bounds
        altAngleFrame = (angleBBox.min[-1]-angleBBox.max[-1]).to_mm.round

        #Modify the height
        highestFace.pushpull(altAngleFrame.mm)
      end

      #Adjust the length of the angle XPS items
      angleXPSitems = [@cornerObjects[1]["FRAME"].items["XPS|BOT"], @cornerObjects[1]["FRAME"].items["XPS|PX"]]

      angleXPSitems.each do |currentXPS|
        #Make a new definition
        cdName = currentXPS.definition.name
        currentXPS.make_unique
        currentXPS.definition.name = "PA#{@ID}|#{cdName.split("|")[-1]}"

        #Find the rightest face
        currentXPS_face, position = currentXPS.definition.entities.findFace("X", 1, ">")

        #Modify the height
        currentXPS_face.pushpull(-@cornerObjects[1]["FRAME"].data["FRAME"]["CMP"].mm)
      end

      #Merge the Caissons
      caisonsObjects = {"CH"=>[@cornerObjects[1]["FRAME"].items["CV|VH"], @cornerObjects[2]["FRAME"].items["CV|VH"]],
                        "CV"=>[@cornerObjects[1]["FRAME"].items["CV|VV"], @cornerObjects[2]["FRAME"].items["CV|VV"]]}

      ##Parse CVs
      caisonsObjects.each do |currentSetName, currentObjects|
        #Merge the horizontal elements together
        mergeGrp = unifiedFrame.entities.add_group(currentObjects[0], currentObjects[1])

        #Isolate edges betseen two face with the same orientation
        mergeEdges = mergeGrp.entities.to_a.collect{|current| current.class == Sketchup::Edge}

        mergeEdges.select! do |currentEdge|
          #Grab the connected faces
          currentFaces = currentEdge.faces

          #Get the faces normals
          faceNormals = currentFaces.collect{|currentFace| currentFace.normal.normalize}.compact

          #Check that we have an unused edge
          currentFaces.length == 2 and faceNormals.length == 1
        end

        #Delete non usefull edges
        mergeEdges.edge{|edgeToDelete| edgeToDelete.erase!}

        #Recreate an OCL object
      end









      ##Delete the angle Frame studs


    end

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
    commit_result = Sketchup.active_model.commit_operation
    raise "Assemble Angle Pré-Cadre has been an unsuccessful result when committing it " unless commit_result
  end

  def align(argFrame, argConnectedFrom:nil, argConnectedTo:nil, argRotationAngle:0)
    #argMoveTo:[0,0,0]
    raise "argFrame is not type of Sketchup::Entity" unless argFrame.class <= Sketchup::Entity
    raise "argConnectedFrom is not not type of (L, R)" unless ["L", "R"].include? argConnectedFrom
    raise "argConnectedTo is not type of Sketchup::Entity" unless ["L", "R"].include? argConnectedTo
    raise "argRotationAngle is not type of Numeric" unless argRotationAngle.class <= Numeric

    #FRAME TYPE BASED ON ENTITY
    isMain = (argFrame == @cornerObjects[0]["ENT"])
    isAngle = (argFrame == @cornerObjects[1]["ENT"])
    isDoor = (@cornerObjects.length == 3) and !isMain and !isAngle

    currentFrameID = isMain ? 0 : (isAngle ? 1 : 2)
    #currentFrame = @cornerObjects[currentFrameID]["FRAME"]


    #TRANSLATE
    #Get the destination position
    tgtCPointIn = nil
    tgtCPoint = nil

    #Grab world positions
    tgtPosition = [0,0,0]
    unless argConnectedTo.nil?
      tgtPosition = argCPointTo.getWorldPosition(argConnectedTo, argTOmm:false)
      puts argCPointTo.getWorldPosition(argConnectedTo, argTOmm:true)
    end

    srcPosition = argCPointFrom.getWorldPosition(argFrame, argTOmm:false)
    puts argCPointFrom.getWorldPosition(argFrame, argTOmm:true)

    #Move Frame
    move_value = [0,0,0]
    move_value.each_index{|index| move_value[index] = tgtPosition[index] - srcPosition[index]}
    move_vector = Geom::Transformation.new(move_value)
    argFrame.move!(move_vector)

    #ROTATION
    unless argRotationAngle == 0
      ##Define rotation parameters
      rotationPoint = argSideFrom.position
      rotationVector = Geom::Vector3d.new(0,0,1)

      rotation = Geom::Transformation.rotation(rotationPoint, rotationVector, argRotationAngle.degrees)
      finalTransfo *= rotation
    end


    '''
    #Connection Object
    currentConnOBJ = ConstructionPoint.new(argSideFrom, argFrame)
    srcPosition = currentConnOBJ.getWorldPosition().collect{|value| value.mm}

    #No connection => origin
    if argConnectedTo.nil?
      moveVector = Geom::Vector3d.new(srcPosition.collect{|value| -value})
      finalTransfo *= Geom::Transformation.translation(moveVector)

    #Connect to destination
    else
      #Get target connexion OBJs positions
      targetPosition = argSideTo.getWorldPosition(argConnectedTo).collect{|value| value.mm}

      #Evaluate World position delta
      move = [0,0,0]
      move.each_index{|index| move[index] = targetPosition[index] - srcPosition[index]}

      #argFrame.move!(move.collect{|value| -value.mm})
      moveVector = Geom::Vector3d.new(move.collect{|value| value.mm})
      finalTransfo *= Geom::Transformation.translation(moveVector)
    end
    '''

    #FRAME MODIFICATIONS
    if isMain

    elsif isAngle
      '''
      moveTransfo = Geom::Transformation.translation([0, currentFrame.data["FRAME"]["L"].mm, 0])
      argFrame.transform!(moveTransfo)
      '''

    elsif isDoor

    end
  end
end