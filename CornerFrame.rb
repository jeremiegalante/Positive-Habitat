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
  @cornerObjects = []
  @object
  @data = {}

  #INSTANCE VARIABLE ACCESSORS
  attr_reader :mainObject
  attr_reader :borderObject
  attr_reader :doorObject

  def initialize(argCornerNomenclature)
    raise "argCornerNomenclature is not type of Hash" unless argCornerNomenclature.is_a? Hash

    #Store the selection to manipulate
    PH::SelectionObserver.selection.each_pair do |currentEntity, order|
      order -= 1

      #Ignore if no object is given
      unless currentEntity.nil?
        #Store frame dimension to data
        currentData = PH::Frame.store[currentEntity].data
        @data["OBJ_DATA"] = currentData
        raise "The object select has no data memorised." if @data["OBJ_DATA"].nil?

        #Define Corner Frame objects
        @cornerObjects[order] = {"OBJ" => entity}
        @cornerObjectsArray = []
        @cornerObjectsArray[order] = entity

        #Store object dimensions
        @cornerObjects[order]["L"] = currentData["FRAME"]["L"] + 2*currentData["FRAME"]["OFF"] + PH::CFG.getOCLmaterialData(currentData["MAT"]["OSS"])["Thickness"]
        @cornerObjects[order]["W"] = currentData["WALL"]["T"]

        supportT = PH::CFG.getOCLmaterialData("3PlisT10")["Thickness"]
        @cornerObjects[order]["H"] = supportT + 45 +
                                     currentData["FRAME"]["H"] +
                                     currentData["FRAME"]["OFF"] +
                                     currentData["CV"]["H"] +
                                     currentData["OH"]["H"] +
                                     (( currentData["OH"]["H"] == 0 and currentData["CS?"] == "X") ? supportT+currentData["OH"]["OFF"] : 0)
      end
    end

    #Define Frame Angle data
    @ID = @@posteData.keys[-1].nil? ? 100 : @@posteData.keys[-1] + 1
    @data = argCornerNomenclature
    @@posteData[@ID] = @data

    #Set Position
    currentXPos = @@nextPosteXpos + (@data["ANGLE"]["POS"] == "D") ? @cornerObjects[0]["L"] : 0
    currentYPos = (@@posteNextYPos.keys.include? @ID) ? @@posteNextYPos[@ID] : 0
    @atCoord = [currentXPos, currentYPos, 5000]

    #Update next positions
    @@nextPosteXpos += (currentXPos + 2000)
    @@posteNextYPos[@ID] = currentYPos + @cornerObjects[2]["L"] + 1000

    #Generate Frame container
    @object = Sketchup.active_model.active_entities.add_group
    @object.name = "FRAME ANGLE #{@ID}"
    @objectPurgeEntities = [@object.entities.add_cpoint(Geom::Point3d.new)]

    #Reposition objects
    [@cornerObjects[0]["OBJ"], @cornerObjects[1]["OBJ"], @cornerObjects[2]["OBJ"]].each do |currentEntity|
      #Ignore if no object is given
      unless currentEntity.nil?
        #Delete the unwanted side

        #Move position


        #Get shader with a neutral color
        shaderName = "Neutral"
        shader = Sketchup.active_model.materials[shaderName]
        if shader.nil?
          shader = Sketchup.active_model.materials.add(shaderName)
          shader.color = Sketchup::Color.new([50,50,50,1])
        end

        #DRAW ALLEGE
        #Define current allège face
        translateArray = currentEntity.transformation.to_a[12..14]
        allegeAltitude = -5000
        faceCoords = []
        faceCoords << [translateArray[0], 0, allegeAltitude.mm]
        faceCoords << [translateArray[0]+currentLength.mm, 0, allegeAltitude.mm]
        faceCoords << [translateArray[0]+currentLength.mm, currentThickness.mm, allegeAltitude.mm]
        faceCoords << [translateArray[0], currentThickness.mm, allegeAltitude.mm]

        #Draw face and extrude it
        newGroup = @object.entities.add_group
        newFace = newGroup.entities.add_face(faceCoords)
        newFace.reverse!
        newFace.pushpull(@data["OSS"]["ALL"].mm)
        newGroup.name = "Allège"

        #Set neural shader
        newGroup.material = shader

        #DRAW LINTEL
        #Define current allège face
        lintelAltitude = allegeAltitude + @data["OSS"]["ALL"] + currentHeight
        faceCoords.collect!{|currentCoords| currentCoords[-1] = lintelAltitude.mm}

        #Draw face and extrude it
        newGroup = @object.entities.add_group
        newFace = newGroup.entities.add_face(faceCoords)
        newFace.reverse!
        newFace.pushpull(@data["OSS"]["LIN"].mm)
        newGroup.name = "Linteau"

        #Set neural shader
        newGroup.material = shader
      end
    end


  end
end