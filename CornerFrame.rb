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
#require_relative 'patch/skp_definition'
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
          pushPullValue -= 31
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
      gapValue = angleFrameData["FRAME"]["CMP"] + doorFrameData["FRAME"]["CMP"]
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


      #CAISSONS CV
      ##Build Caisson CV data
      caisonsObjectsTags = ["CV|VH", "CV|VV", "CV|SHH", "CV|SHV", "CHA"]
      caisonsObjectsVH = {}
      caisonsObjectsTags.each do |currentTag|
        #Grab the entity PID that match the tag on both angle and door frames
        [1,2].each do |cuurrentIndex|
          #Grab the item from entity PersistantID
          frameItem_persistantID = @cornerObjects[cuurrentIndex]["ENT"].get_attribute(entityAD_name, currentTag, 0)
          frameItem_instance = Sketchup.active_model.find_entity_by_persistent_id(eval(frameItem_persistantID))[-1]

          #In case of frame type
          case cuurrentIndex
          #Door frame
          when 2
            #Delete it
            frameItem_instance.erase! unless frameItem_instance.nil?

          #Angle frame
          when 1
            #Backup data and duplicate the instance
            oldFrameItem_definition = frameItem_instance.definition
            oldFrameItem_material = frameItem_instance.material
            frameItem_instance = frameItem_instance.make_unique

            #Update the instance and definition data
            frameItem_definition = frameItem_instance.definition
            frameItem_definition.name = "PA#{@ID}|#{oldFrameItem_definition.name.split("|")[-1]}"

            #Extend the good side face
            searchValue = (@data["ANGLE"]["POS"]=="L") ? @cornerObjects[1]["DATA"]["FRAME"]["L"].round(0) * 0.75 : 0
            searchSymbol = (@data["ANGLE"]["POS"]=="L") ? ">=" : "<="

            faceToExtend = frameItem_definition.entities.findFaceBis("X", searchValue, searchSymbol)[0]
            faceToExtend.pushpull(@cornerObjects[2]["DATA"]["FRAME"]["L"].mm)

          end
        end
      end

      exit

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