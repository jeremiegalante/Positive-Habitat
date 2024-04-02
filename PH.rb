require 'json'

module PH
  #MODULE VARIABLES
  @@preCadreID = 0
  @@materialsOCL = {}

  #MODULE ACCESSORS
  attr_accessor :preCadreID

  #NESTED CFG MODULE
  module CFG
    #@MODULE VARIABLE
    @@configFiles = {
      "materialsOCL":"#{__dir__}/materialsOCL.json"
    }
    @CFGloaded = false

    #MODULE ACCESSORS
    attr_reader :configFiles

    #MODULE METHODS
    def self.loadJSON(argJSONfilePath)
      raise "argJSONfilePath is not type of String" unless argJSONfilePath.class == String

      #Extract CFG data
      file = File.read(argJSONfilePath)
      json_data = JSON.parse(file)

      return json_data
    end

    def self.loadConfigs
      @@configFiles.each_pair do |currentJSONkey, currentJSONfile|
        #Create replace Filename with JSON content
        @@configFiles[currentJSONkey] = loadJSON(currentJSONfile)
      end

      @CFGloaded = true
    end

    def self.getOCLmaterialData(argMatName)
      raise "argMatName is not type of String" unless argMatName.class == String

      PH::CFG.loadConfigs unless @CFGloaded

      return @@configFiles[:materialsOCL][argMatName]
    end
  end

  #NESTED SKP MODULE
  '''
  load "E:/#Positive Habitat/PH/PH.rb"
  coordsCOMP = {
    "X" => [1000,2000],
    "Y" => [0,100],
    "Z" => [500,1500]
  }
  objCI = PH::SKP.drawOBJ(coordsCOMP, 5000, argCIname:"CIname", argCDname:"CDname")
  PH::SKP.toOCL(objCI, "PreCadre")
  '''
  module SKP
    def self.drawOBJ(argOBJvalues, argExtrudeVal, argCIname:"", argCDname:nil , argCIpos:[0,0,0], argContainer:Sketchup.active_model)
      raise "argOBJvalues is not type of Hash" unless argOBJvalues.class == Hash
      raise "argOBJvalues Hash as not X as Key" unless argOBJvalues.keys.include? "X"
      raise "argOBJvalues Hash as not an Array as X Key value" unless argOBJvalues["X"].is_a? Array
      raise "argOBJvalues Hash as not an Array[2] as X Key value" unless argOBJvalues["X"].length == 2
      raise "argOBJvalues Hash as not an Array as Y Key value" unless argOBJvalues["Y"].is_a? Array
      raise "argOBJvalues Hash as not an Array[2] as Y Key value" unless argOBJvalues["Y"].length == 2
      raise "argOBJvalues Hash as not an Array as Z Key value" unless argOBJvalues["Z"].is_a? Array
      raise "argOBJvalues Hash as not an Array[2] as Z Key value" unless argOBJvalues["Z"].length == 2
      raise "argExtrudeVal is not type of Numeric" unless argExtrudeVal.is_a? Numeric
      raise "argCIname is not type of String" unless argCIname.class == String
      raise "argCDname is not type of String" unless argCDname.nil? or argCDname.class == String
      raise "argCIpos is not type of Array[3]" unless argCIpos.is_a? Array and argCIpos.length == 3
      raise "argContainer does note contain Sketchup::Entities to draw elements" unless argContainer.entities.class == Sketchup::Entities


      #Try to get the component definition from name
      componentDefinition = argCDname.nil? ? nil : Sketchup.active_model.definitions[argCDname]

      #Crete Entities if
      # No component definition (stand alone OBJ only) is requested
      # The component definition requested doesn't exists
      objectCI = nil
      transformation = Geom::Transformation.new(argCIpos.collect{|value| value.mm})

      if componentDefinition.nil?
        #Dimension order
        order = argOBJvalues.keys

        #Define order values
        valuesAtTiming = {
          0 => {"X" => 0,
                "Y" => 0,
                "Z" => 0},
          1 => {"X" => order.index("X")==0 ? -1 : 0,
                "Y" => order.index("Y")==0 ? -1 : 0,
                "Z" => order.index("Z")==0 ? -1 : 0},
          2 => {"X" => order.index("X")<2 ? -1 : 0,
                "Y" => order.index("Y")<2 ? -1 : 0,
                "Z" => order.index("Z")<2 ? -1 : 0},
          3 => {"X" => order.index("X")==1 ? -1 : 0,
                "Y" => order.index("Y")==1 ? -1 : 0,
                "Z" => order.index("Z")==1 ? -1 : 0}
        }

        #Define face coordinates
        face_coords = []
        face_coords << [(argOBJvalues["X"][valuesAtTiming[0]["X"]]).mm, (argOBJvalues["Y"][valuesAtTiming[0]["Y"]]).mm, (argOBJvalues["Z"][valuesAtTiming[0]["Z"]]).mm]
        face_coords << [(argOBJvalues["X"][valuesAtTiming[1]["X"]]).mm, (argOBJvalues["Y"][valuesAtTiming[1]["Y"]]).mm, (argOBJvalues["Z"][valuesAtTiming[1]["Z"]]).mm]
        face_coords << [(argOBJvalues["X"][valuesAtTiming[2]["X"]]).mm, (argOBJvalues["Y"][valuesAtTiming[2]["Y"]]).mm, (argOBJvalues["Z"][valuesAtTiming[2]["Z"]]).mm]
        face_coords << [(argOBJvalues["X"][valuesAtTiming[3]["X"]]).mm, (argOBJvalues["Y"][valuesAtTiming[3]["Y"]]).mm, (argOBJvalues["Z"][valuesAtTiming[3]["Z"]]).mm]

        #Draw face and extrude it
        newGroup = argContainer.entities.add_group
        newFace = newGroup.entities.add_face(face_coords)
        newFace.pushpull(argExtrudeVal.mm)

        #Convert to Component Instance and set CD name
        newGroup.name = argCIname
        objectCI = newGroup.to_component
        objectCI.definition.name = argCDname

        #Move to requested position
        objectCI.move!(transformation)

      #Or instantiate component
      else
        objectCI = argContainer.entities.add_instance(componentDefinition, transformation)
      end

      #Set Component Instance Name
      objectCI.name = argCIname

      return objectCI
    end

    def self.getShader(argID)
      raise "argID is not type of String" unless argID.class == String

      #Try to grab the SKP material or create it from CFG if it wasn't done before
      oclShader = Sketchup.active_model.materials[argID]

      if oclShader.nil?
        oclShader = Sketchup.active_model.materials.add(argID)
        oclShader.color = Sketchup::Color.new(PH::CFG.getOCLmaterialData(argID)["OCL_RGBA"])
      end

      return oclShader
    end

    def self.toOCL(argComponentInstance, argOCLshaderName)
      raise "argComponentInstance is not type of String" unless argComponentInstance.is_a? Sketchup::ComponentInstance
      raise "argOCLshaderName is not type of String" unless argOCLshaderName.is_a? String

      #Set material
      argComponentInstance.material = PH::SKP.getShader(argOCLshaderName)

      '''
      #Set Definition end Instance Names
      componentDefinition = argComponentInstance.definition

      #Reinitialise Instance Names
      argComponentInstance.name = ""
      '''
    end

    '''
    def self.toComponentInstance(argObjGrp, argComponentName)
      raise "argObjGrp is not type of Sketchup::Group" unless argObjGrp.is_a? Sketchup::Group
      raise "argComponentName is not type of String" unless argComponentName.is_a? String

      componentInstance = argObjGrp.to_component
      componentInstance.name = argComponentName

      return componentInstance
    end
  '''
  end
end

PH::CFG.loadConfigs