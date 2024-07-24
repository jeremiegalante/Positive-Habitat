#Load generic Requires
require 'json'

#Load PH Requires
require_relative 'PH'
require_relative 'patch/hash'
require_relative 'Frame'

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
  @data = {}
  @angleData = {}

  #INSTANCE VARIABLE ACCESSORS
  attr_reader :mainObject
  attr_reader :borderObject
  attr_reader :doorObject

  def initialize(argCornerNomenclature)
    raise "argCornerNomenclature is not type of Hash" unless argCornerNomenclature.is_a? Hash

    #BUILD ENTITIES SELECTED DATA
    @data = argCornerNomenclature
    @cornerObjects = []

    PH::SelectionObserver.selection.each_pair do |currentEntity, order|
      #Ignore if no object is given
      unless currentEntity.nil?
        '''
        #Store frame dimension to data
        currentData = PH::Frame.store[currentEntity].data
        @angleData["OBJ_DATA"] = currentData
        raise "The object select has no data memorised." if @angleData["OBJ_DATA"].nil?
        '''

        #Store the current Frame data
        @cornerObjects[order] = {}
        @cornerObjects[order]["ENT"] = currentEntity
        @cornerObjects[order]["FRAME"] = PH::Frame.store[currentEntity]
        @cornerObjects[order]["L"] = @cornerObjects[order]["FRAME"].object_connL
        @cornerObjects[order]["R"] = @cornerObjects[order]["FRAME"].object_connR
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

    #Generate Angle Frame container
    @object = Sketchup.active_model.active_entities.add_group(PH::SelectionObserver.selection.keys)
    @object.name = "PRE-CADRE ANGLE #{@ID}"
    @objectPurgeEntities = [@object.entities.add_cpoint(Geom::Point3d.new)]
    @atCoord = [0, 0, 0]

    #COORDS
    #Initialize the position coordinates
    @atCoord = [0, 0, -5000]

    #Generate a new X position in case this Angle ID hasn't been created before
    if !@@posteXpos.key?(@ID)
      #Update this poste X position
      @@posteXpos[@ID] = @@nextPosteXpos
      @atCoord[0] = @@posteXpos[@ID]

      #And update the next next X position
      @@nextPosteXpos += @cornerObjects[0]["FRAME"].data["FRAME"]["L"] +
                       ( @cornerObjects[1]["FRAME"].data["FRAME"]["L"] * Math.cos(@data["ANGLE"]["VAL"].degrees) ).round(0) +
                         1000
    end

    #Set the Angle X position
    @atCoord[0] = @@posteXpos[@ID]

    #Set the Y Position
    ##Get the frame next position if the Poste has already been generated once
    if @@posteNextYPos.key?(@ID)
      #Get the next position
      @atCoord[1] = @@posteNextYPos[@ID]

    else
      #Update next Frame of the same Pole Y position
      @@posteNextYPos[@ID] = 0
    end

    #Update Angle next Y position
    @@posteNextYPos[@ID] += @cornerObjects[0]["FRAME"].data["WALL"]["T"] +
                          ( @cornerObjects[1]["FRAME"].data["FRAME"]["L"] * Math.sin(@data["ANGLE"]["VAL"].degrees) ).round(0) +
                            1000
  end

  def assemble
    #START OPERATION
    Sketchup.active_model.start_operation("Assemble Corner Frame #{@poste_name}", disable_ui:true, next_transparent:false, transparent:false)

    #POSITION THE MAIN FRAME
    align(@cornerObjects[0]["ENT"], argSideFrom:@cornerObjects[0][@data["ANGLE"]["POS"]])

    #POSITION THE ANGLE FRAME
    align(@cornerObjects[1]["ENT"], argConnectedTo:@cornerObjects[0]["ENT"], argSideFrom:@cornerObjects[1]["L"], argSideTo:@cornerObjects[0][@data["ANGLE"]["POS"]], argRotationAngle:-@data["ANGLE"]["VAL"])#POSITION TH CORNER FRAME

    #POSITION THE DOOR FRAME
    if @cornerObjects.length == 3
      puts "DOOR"
      #align(@cornerObjects[2]["ENT"], argConnectedTo:@cornerObjects[1]["ENT"], argSideFrom:@cornerObjects[2]["L"], argSideTo:@cornerObjects[1][@data["R"]], argRotationAngle:-@data["ANGLE"]["VAL"])
    end

    '''
    #CLEAN/DELETE SECURITY ENTITIES
    @objectPurgeEntities.each {|entityToDelete| entityToDelete.erase! unless entityToDelete.deleted?}
    '''

    '''
    #MOVE AT THE RIGHT POSITION
    atCoord_mm = @atCoord.collect {|value| value.mm}
    moveTo = Geom::Transformation.new(atCoord_mm)
    @object.move!(moveTo)
    '''

    #FINALISE OPERATION
    commit_result = Sketchup.active_model.commit_operation
    raise "Assemble Angle Pré-Cadre has been an unsuccessful result when committing it " unless commit_result
  end

  def align(argEntity, argConnectedTo:nil, argSideFrom:nil, argSideTo:nil, argRotationAngle:0)
    #argMoveTo:[0,0,0]
    raise "argEntity is not type of Sketchup::Entity" unless argEntity.class <= Sketchup::Entity
    raise "argConnectedTo is not type of Sketchup::Entity" unless [NilClass, Sketchup::Group].include? argConnectedTo.class
    raise "argSideFrom is not type of Sketchup::ConstructionPoint" unless [NilClass, Sketchup::Group].include? argSideFrom.class
    raise "argSideTo is not type of Sketchup::ConstructionPoint" unless [NilClass, Sketchup::Group].include? argSideTo.class
    raise "argRotationAngle is not type of Numeric" unless argRotationAngle.class <= Numeric

    #FRAME TYPE BASED ON ENTITY
    isMain = (argEntity == @cornerObjects[0]["ENT"])
    isAngle = (argEntity == @cornerObjects[1]["ENT"])
    isDoor = (@cornerObjects.length == 3) and !isMain and !isAngle

    currentFrameID = isMain ? 0 : (isAngle ? 1 : 2)
    currentFrame = @cornerObjects[currentFrameID]["FRAME"]

    #TRANSFORMATION
    #Initialize to start the final transformation to identity
    finalTransfo = Geom::Transformation.new()

    #MIRROR
    #In case the source and target side aren't the same
    if isAngle and ("L" <=> @data["ANGLE"]["POS"])
      reverseY = Geom::Transformation.scaling(1, -1, 1)
      finalTransfo *= reverseY
    end

    #CONNEXION OBJECT
    currentConnOBJ = currentFrame.object_connL

    #ROTATION
    unless argRotationAngle == 0
      ##Define rotation parameters
      rotationPoint = currentConnOBJ.bounds.max.to_a
      rotationVector = Geom::Vector3d.new(0,0,1)

      rotation = Geom::Transformation.rotation(rotationPoint, rotationVector, argRotationAngle.degrees)
      finalTransfo *= rotation
    end

    #TRANSLATE
    #No connection => origin
    if argConnectedTo.nil?
      moveVector = Geom::Vector3d.new(getWorldPosition(argSideFrom).collect{|value| value.mm}).reverse
      finalTransfo *= Geom::Transformation.translation(moveVector)

    #Connect to destination
    else
      #Get connexion OBJs positions
      currentPosition = getWorldPosition(argSideFrom)
      #puts "FROM #{currentPosition}"
      targetPosition = getWorldPosition(argSideTo)
      #puts "TO #{targetPosition}"

      #Evaluate World position delta
      move = [0,0,0]
      move.each_index{|index| move[index] = targetPosition[index] - currentPosition[index]}

      argEntity.move!(move.collect{|value| -value.mm})
      #moveVector = Geom::Vector3d.new(move.collect{|value| value.mm})
      #finalTransfo *= Geom::Transformation.translation(moveVector)
    end

    #APLLY GLOBAL TRANSFORMATION
    argEntity.transform!(finalTransfo)

    #FRAME MODIFICATIONS
    if isMain

    elsif isAngle
      moveTransfo = Geom::Transformation.translation([0, currentFrame.data["FRAME"]["L"].mm, 0])
      argEntity.transform!(moveTransfo)

    elsif isDoor

    end
  end

  def getWorldPosition(argEntity)
    raise "argEntity is not type of Sketchup::Entity" unless argEntity.class <= Sketchup::Entity

    #Extract the world position from the world matrix
    worldPosition = getWorldMatrix(argEntity)

    #Convert to mm distance
    worldPosition = worldPosition.to_a[12..14].collect{|v| v.to_mm.to_i}

    return worldPosition
  end
  def getWorldMatrix(argEntity)
    raise "argEntity is not type of Sketchup::Entity" unless argEntity.class <= Sketchup::Entity

    #Extract the world matrix from path
    path = getEntityPath(argEntity)
    worldMatrix = path[-2].transformation

    return worldMatrix
  end

  def getEntityPath(argEntity)
    raise "argEntity is not type of Sketchup::Entity" unless argEntity.class <= Sketchup::Entity

    #Initialise path research
    currentParent = argEntity
    path =[]

    #Build the path
    loop do
      #Store the active parent to the path
      path << currentParent

      #Jump to the next parent
      currentParent = currentParent.parent

      #In case of ComponentDefinition connect to the instance
      if currentParent.class == Sketchup::ComponentDefinition
        currentParent = currentParent.instances[-1]
      end

      #Stop when reaching the highest level
      break if currentParent.class == Sketchup::Model
    end

    return path.reverse
  end
end