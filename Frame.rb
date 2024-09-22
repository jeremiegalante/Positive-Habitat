#Load generic Requires
require 'json'

#Load PH Requires
require_relative 'PH'
require_relative 'patch/hash'
require_relative 'EntityObserver'

class PH::Frame
  #INSTANCE VARIABLE
  @ID = nil
  @object = nil
  @objectPurgeEntities = []
  @items = {}
  @atCoord = []
  @data

  #INSTANCE VARIABLE ACCESSORS
  attr_accessor :object
  attr_accessor :data
  attr_reader :items
  attr_reader :ID


  #CONSTRUCTOR
  # Method to create a Frame linked to a Poste NB.
  # @return self
  # @!scope instance
  # @!group Init Method
  # @version 0.30.0
  # @since 0.1.0
  def initialize(argNomenclature={})
    raise "argNomenclature is not type of Hash" unless argNomenclature.is_a? Hash

    #Create the data a default data hash values
    @data = argNomenclature
    @ID = @data.delete("ID")
    @items = {}

    #Check if a frame with the same ID with different nomenclature was previously generated
    modelFrameAD_name = "FRAMES"
    modelFrameAD = Sketchup.active_model.get_attribute(modelFrameAD_name, @ID)
    modelFrameAD = eval(modelFrameAD) unless modelFrameAD.nil?

    isNomenclatureChanged =  (!modelFrameAD.nil? and (eval(modelFrameAD["Data"]) != @data))

    #In case the ID is reused
    if isNomenclatureChanged
      #Erase the SKP poste object with the ID
      modelFrameAD["Entities"].each do |currentEntityPID|
        currentEntity = Sketchup.active_model.find_entity_by_persistent_id(currentEntityPID)
        currentEntity.erase!
      end

      #Empty the Poste from model AD
      Sketchup.active_model.set_attribute(modelFrameAD_name, @ID, nil)

      #Purge unused definitions
      Sketchup.active_model.definitions.purge_unused
    end

    #Generate Frame container
    @object = Sketchup.active_model.active_entities.add_group
    @object.name = "POSTE #{@ID}"
    @objectPurgeEntities = [@object.entities.add_cpoint(Geom::Point3d.new)]
    @atCoord = [0, 0, 0]

    #Get Material data
    ##Get Mat OSS data
    @mat = {}
    @matOSS_Name = @data["MAT"]["OSS"]
    @mat[@matOSS_Name] = PH::CFG.getOCLmaterialData(@matOSS_Name)

    ##Get Mat FIN data
    @matFIN_Name = @data["MAT"]["FIN"]
    @mat[@matFIN_Name] = PH::CFG.getOCLmaterialData(@matFIN_Name) if @matFIN_Name != ""

    #STORE FRAME DIMENSION TO DATA
    supportT = PH::CFG.getOCLmaterialData("3PlisT10")["Thickness"]
    @DIM = {}
    @DIM["L"] = @data["FRAME"]["L"] + 2 * (@data["FRAME"]["CMP"] + @mat[@matOSS_Name]["Thickness"])
    @DIM["W"] = @data["WALL"]["T"]
    @DIM["H"] = PH::CFG.getOCLmaterialData("3PlisT10")["Thickness"] +
                        45 +
                        @data["FRAME"]["CMPB"] +
                        @data["FRAME"]["H"] +
                        @data["FRAME"]["CMP"] +
                        @data["CV"]["H"] +
                        @data["OH"]["H"]
  end


  #INSTANCE DRAWING METHODS
  # Method to draw all the Frame.
  # @return nil
  # @!scope instance
  # @!group Drawing Methods
  # @version 0.30.0
  # @since 0.1.0
  def draw
    #START OPERATION
    Sketchup.active_model.start_operation("Modeling Frame #{@poste_name}", disable_ui:true, next_transparent:false, transparent:false)

    #STORE DATA IN ATTRIBUTE DICTIONARY
    modelFrameAD_name = "FRAMES"
    modelFrameAD = Sketchup.active_model.get_attribute(modelFrameAD_name, @ID)

    #In case the Post ID has been initialize before
    unless modelFrameAD.nil?
      modelFrameAD = eval(modelFrameAD)

      #Delete the empty Object
      @object.erase!

      #Copy the last Poste Frame
      ##Make Copy of the last one
      lastPostFramePID = modelFrameAD["Entities"][-1]
      lastPostFrameOBJ = Sketchup.active_model.find_entity_by_persistent_id(lastPostFramePID)
      @object = lastPostFrameOBJ.copy
      @object.name = lastPostFrameOBJ.name

      ##Offset the copy on Y
      moveVector = [lastPostFrameOBJ.bounds.corner(0).to_a[0],
                    ((@data["WALL"]["T"] + 1000) * modelFrameAD["Entities"].length).mm,
                    0]
      move = Geom::Transformation.new(moveVector)
      @object.move!(move)

      #Add this to its Poste Frames
      modelFrameAD["Entities"] << @object.persistent_id
      Sketchup.active_model.set_attribute(modelFrameAD_name, @ID, modelFrameAD.to_s)

    #Either generate the first one
    else
      #PREPARE DRAWING
      #Create AD content
      modelFrameAD = {}
      modelFrameAD["Data"] = @data.to_s
      modelFrameAD["Entities"] = [@object.persistent_id]

      #Set the new poste position
      nextFrameXvalue = Sketchup.active_model.get_attribute(modelFrameAD_name, "nextFrameX", 0)
      @atCoord[0] = nextFrameXvalue
      nextFrameXvalue += @data["FRAME"]["L"] + 1000
      Sketchup.active_model.set_attribute(modelFrameAD_name, "nextFrameX", nextFrameXvalue)

      #DRAW PRE-CADRE
      draw_precadre

      #DRAW STUDS
      draw_studs

      #DRAW PSE ASSISE
      draw_xps

      #DRAW Coffret/Volet
      draw_CV if @data["CV"]["H"] > 0

      #DRAW FENÊTRE/BOIS
      draw_finishingStuds if @data["MAT"]["FIN"] != ""

      #CLEAN/DELETE SECURITY ENTITIES
      @objectPurgeEntities.each {|entityToDelete| entityToDelete.erase! unless entityToDelete.deleted?}

      #MOVE AT THE RIGHT POSITION
      atCoord_mm = @atCoord.collect {|value| value.mm}
      moveTo = Geom::Transformation.new(atCoord_mm)
      @object.move!(moveTo)

      #ADD ERASE OBSERVER
      #@object.add_observer(PH::EntityObserver.new)

      #UPDATE THE MODEL FRAMES AD
      Sketchup.active_model.set_attribute(modelFrameAD_name, @ID, modelFrameAD.to_s)
    end

    #FINALISE OPERATION
    commit_result = Sketchup.active_model.commit_operation
    raise "Drawing Pré-Cadre has been an unsuccessful result when commiting it " unless commit_result
  end

  # Method to draw the Pré-Cadre.
  # @return [Array<Sketchup::ComponentInstance>] the OCL 'Pré-Cadre' component instances generated.
  # @!scope instance
  # @!group Drawing Methods
  # @version 0.10.0
  # @since 0.5.0
  def draw_precadre
    #Define Face drawing coords
    coordsObjH = {
      "X" => [0, @data["FRAME"]["L"]],
      "Y" => [0, @data["FRAME"]["T"]],
      "Z" => [0, 0]
    }

    coordsObjV = {
      "X" => [0, @data["FRAME"]["T"]],
      "Y" => [0, @data["FRAME"]["T"]],
      "Z" => [0, 0]
    }

    #Define Component Names an instances list
    componentDefinitionName = "P#{@ID}|CADRE FENÊTRE_"
    itemComponentInstances = []

    #Create Pré-Cadre Container for Items
    newGroup = @object.entities.add_group()
    @objectPurgeEntities << newGroup.entities.add_cpoint(Geom::Point3d.new)
    newGroup.name = "Pré-Cadre Fenêtre"

    #Add entities storage to the frame
    @items["PC"] = {}
    '{"NAME":newGroup.name,
                    "GRP":newGroup,
                    "ENT":[]}'

    #Generate Items
    frameV_height = @data["FRAME"]["H"] - 2 * @data["FRAME"]["T"]
    dessousPSEheight = 45 + PH::CFG.getOCLmaterialData("3PlisT10")["Thickness"]

    #Generate Bottom Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObjH, -@data["FRAME"]["T"], argCDname:"#{componentDefinitionName}Bottom", argCIpos:[@data["FRAME"]["CMP"], @data["WALL"]["FD"], dessousPSEheight], argContainer:newGroup)

    #Generate Top Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObjH, -@data["FRAME"]["T"], argCDname:"#{componentDefinitionName}Top", argCIpos:[@data["FRAME"]["CMP"], @data["WALL"]["FD"], dessousPSEheight+@data["FRAME"]["H"]-@data["FRAME"]["T"]], argContainer:newGroup)

    #Generate Left Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObjV, -frameV_height, argCDname:"#{componentDefinitionName}Left", argCIpos:[@data["FRAME"]["CMP"], @data["WALL"]["FD"], dessousPSEheight+@data["FRAME"]["T"]], argContainer:newGroup)

    #Generate Right Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObjV, -frameV_height, argCDname:"#{componentDefinitionName}Right", argCIpos:[@data["FRAME"]["CMP"]+@data["FRAME"]["L"]-@data["FRAME"]["T"], @data["WALL"]["FD"], dessousPSEheight+@data["FRAME"]["T"]], argContainer:newGroup)

    #Store entities
    @items["PC"]["ENT"] = itemComponentInstances

    #Apply OCL material
    itemComponentInstances.each do |currentCI|
      currentCI.material = PH::SKP.getShader("Frame")
    end

    #Apply the Compribande bottom space
    newGroup.move!(Geom::Transformation.new [0, 0, (@data["FRAME"]["CMPB"]).mm])

    return itemComponentInstances
  end

  # Method to draw lateral studs.
  # @return [Array<Sketchup::ComponentInstance>] the OCL Studs component instances generated.
  # @!scope instance
  # @!group Drawing Methods
  # @version 0.10.0
  # @since 0.10.0
  def draw_studs
    #Define Drawing Coords
    matData = PH::CFG.getOCLmaterialData(@data["MAT"]["OSS"])
    coordsObj = {
      "X" => [0, matData["Thickness"]],
      "Y" => [0, @data["WALL"]["T"]],
      "Z" => [0, 0]
    }

    #Define Component Names
    componentDefinitionName = "P#{@ID}|MONTANT PX_"

    #Generate Items
    itemComponentInstances = []

    #Generate Left Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObj, -@DIM["H"], argCDname:"#{componentDefinitionName}Left", argCIpos:[-@mat[@matOSS_Name]["Thickness"], 0, 0], argContainer:@object)

    #Generate Right Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObj, -@DIM["H"], argCDname:"#{componentDefinitionName}Right", argCIpos:[@data["FRAME"]["L"]+@data["FRAME"]["CMP"]+@data["FRAME"]["CMP"], 0, 0], argContainer:@object)

    #Apply OCL material
    itemComponentInstances.each do |currentCI|
      currentCI.material = PH::SKP.getShader(@matOSS_Name)
    end

    @items["STUDS|OSS"] = itemComponentInstances

    #Generate Châpeau if requested
    if @data["CS?"] == "X"
      ##Define Drawing Coords
      chapeau_height = PH::CFG.getOCLmaterialData("3PlisT10")["Thickness"]
      chapeauLength = @data["FRAME"]["L"] + 2*@data["FRAME"]["CMP"] + 2*matData["Thickness"]
      coordsObj = {
        "X" => [0, chapeauLength],
        "Y" => [0, @data["WALL"]["T"]],
        "Z" => [0, 0]
      }

      #Define Component Names
      componentDefinitionName = "P#{@ID}|CHAPEAU"

      #Generate Instance
      itemComponentInstances << PH::SKP.drawOBJ(coordsObj, -chapeau_height, argCDname:componentDefinitionName, argCIpos:[-matData["Thickness"], 0, @DIM["H"]], argContainer:@object)
      itemComponentInstances[-1].material = PH::SKP.getShader("3PlisT10")
      @items["CHA"] = itemComponentInstances[-1]
    end

    return itemComponentInstances
  end

  # Method to draw OCL PSE that makes the lower part that holds the Frame.
  # @param argHeights [Array[3]] the list of 3 PSE steps height.
  # @return [Sketchup::ComponentInstance] the OCL XPS elements component instance generated.
  # @!scope instance
  # @!group Drawing Methods
  # @version 0.10.0
  # @since 0.10.0
  def draw_xps(argHeights:[3,23,45])
    raise "argHeights is not type of Array[3]" unless argHeights.class == Array and argHeights.length == 3
    raise "argHeights is not Numerics Array[3]" unless argHeights[0].is_a? Numeric and argHeights[1].is_a? Numeric and argHeights[2].is_a? Numeric

    componentInstances =[]

    #Evaluate Dimensions
    xps_width = @data["WALL"]["FD"] + @data["FRAME"]["T"]

    #XPS
    ##Define face coordinates
    face_coords = [[0, 0, 0]]
    face_coords << [0, 0 ,argHeights[0].mm]
    face_coords << [0, @data["WALL"]["FD"].mm, argHeights[1].mm]
    face_coords << [0, @data["WALL"]["FD"].mm, argHeights[2].mm]
    face_coords << [0, xps_width.mm, argHeights[2].mm]
    face_coords << [0, xps_width.mm, 0]

    ##Draw face and extrude it
    newGroup = @object.entities.add_group
    newFace = newGroup.entities.add_face(face_coords)
    newFace.reverse!
    newFace.pushpull((@data["FRAME"]["L"]+@data["FRAME"]["CMP"]+@data["FRAME"]["CMP"]).mm)

    ##Transform to OCL Element
    componentInstances << newGroup.to_component
    componentDefinition = componentInstances[-1].definition
    componentDefinition.name = "P#{@ID}|XPS PX"
    @items["XPS|PX"] = componentInstances[-1]

    ##Move at the right place
    bottomHeight = PH::CFG.getOCLmaterialData("3PlisT10")["Thickness"]
    transformation = Geom::Transformation.new([0, 0, bottomHeight.mm])
    componentInstances[-1].move!(transformation)

    ##Set OCL (Open Cut List) Shader
    componentInstances[-1].material = PH::SKP.getShader("FrameXPS")

    #BOTTOM SEATED
    ##Define Drawing Coords
    bottom_height = PH::CFG.getOCLmaterialData("3PlisT10")["Thickness"]
    bottomLength = @data["FRAME"]["L"] + @data["FRAME"]["CMP"] + @data["FRAME"]["CMP"]
    coordsObj = {
      "Y" => [0, @data["WALL"]["T"]],
      "Z" => [0, bottom_height],
      "X" => [0, 0]
    }

    #Generate Instance
    componentInstances << PH::SKP.drawOBJ(coordsObj, bottomLength, argCDname:"P#{@ID}|BAS PX", argContainer:@object)
    componentInstances[-1].material = PH::SKP.getShader("3PlisT10")
    @items["XPS|BOT"] = componentInstances[-1]

    return componentInstances
  end

  # Method to draw OCL CV reservation over the Frame.
  # @return [Sketchup::ComponentInstance] the OCL PSE element component instance generated.
  # @!scope instance
  # @!group Drawing Methods
  # @version 0.10.0
  # @since 0.10.0
  def draw_CV
    #Create Volets Container for Items
    newGroup = @object.entities.add_group()
    @objectPurgeEntities << newGroup.entities.add_cpoint(Geom::Point3d.new)
    newGroup.name = "Caisson CV"

    #Store the created OCL Components
    itemComponentInstances = []

    #Get Seated Material Data
    seatedMatData = PH::CFG.getOCLmaterialData("3PlisT10")

    #Get dimensions to use
    itemsLength = @data["FRAME"]["L"] + @data["FRAME"]["CMP"] + @data["FRAME"]["CMP"]
    supportT = PH::CFG.getOCLmaterialData("3PlisT10")["Thickness"]
    cvAltitude = supportT + 45 +
                 @data["FRAME"]["CMPB"] +
                 @data["FRAME"]["H"] +
                 @data["FRAME"]["CMP"]
    ohAltitude = cvAltitude + @data["CV"]["H"]

    #Define vertical item heights according CV, OH, CS? settings in case of no CS is requested
    ## And no OH is requested withdraw margin from CV height
    ## Or an OH is requested withdraw margin from OH height
    vertHeight = @data["CV"]["H"]
    vertOHheight = @data["OH"]["H"]

    if !@data["CS?"]
      if (@data["OH"]["H"] == 0)
        vertHeight -= @data["CV"]["CMP"]
      else
        vertOHheight -= @data["CV"]["CMP"]
      end
    end

    ##Adjust height in case os CS
    vertOHheight - (( @data["OH"]["H"] == 0 and @data["CS?"] == "X") ? supportT+@data["OH"]["OFF"] : 0)


    #DRAW VOLET HORIZONTAL
    ##Define Drawing Coords
    coordsObj = {
      "Y" => [@data["WALL"]["FD"] + @mat[@matOSS_Name]["Thickness"], @data["WALL"]["T"]],
      "Z" => [0, @mat[@matOSS_Name]["Thickness"]],
      "X" => [0, 0]
    }

    ##Define Component Names
    componentDefinitionName = "P#{@ID}|VOLET_"

    ##Generate Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObj, itemsLength, argCDname:"#{componentDefinitionName}Horizontal", argContainer:newGroup)
    itemComponentInstances[-1].material = PH::SKP.getShader(@matOSS_Name)
    @items["CV|VH"] = itemComponentInstances[-1]

    #DRAW VOLET VERTICAL
    ##Define Drawing Coords
    coordsObj = {
      "Y" => [@data["WALL"]["FD"], @data["WALL"]["FD"] + @mat[@matOSS_Name]["Thickness"]],
      "Z" => [0, vertHeight],
      "X" => [0, 0]
    }

    ##Generate Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObj, itemsLength, argCDname:"#{componentDefinitionName}Vertical", argContainer:newGroup)
    itemComponentInstances[-1].material = PH::SKP.getShader(@matOSS_Name)
    @items["CV|VV"] = itemComponentInstances[-1]

    #Move Volets items to position
    transformation = Geom::Transformation.new([0, 0, cvAltitude.mm])
    newGroup.move!(transformation)


    #DRAW SUR-HAUTEUR
    unless @data["OH"]["H"] == 0
      #Define Component Names
      componentDefinitionName = "P#{@ID}|SUR-HAUTEUR_"

      #Create Sur-Hauteur Container for Items
      newGroup = @object.entities.add_group()
      @objectPurgeEntities << newGroup.entities.add_cpoint(Geom::Point3d.new)
      newGroup.name = "Caisson CV Sur-Hauteur"

      #DRAW SUR-HAUTEUR HORIZONTALE
      ##Define Drawing Coords
      coordsObj = {
        "Y" => [0, @data["WALL"]["FD"] + @mat[@matOSS_Name]["Thickness"]],
        "Z" => [0, seatedMatData["Thickness"]],
        "X" => [0, 0]
      }

      ##Generate Instance
      itemComponentInstances << PH::SKP.drawOBJ(coordsObj, itemsLength, argCDname:"#{componentDefinitionName}Horizontale", argContainer:newGroup)
      itemComponentInstances[-1].material = PH::SKP.getShader("3PlisT10")
      @items["CV|SHH"] = itemComponentInstances[-1]

      #DRAW SUR-HAUTEUR VERTICALE
      ##Define Drawing Coords
      coordsObj = {
        "Y" => [0, @mat[@matOSS_Name]["Thickness"]],
        "Z" => [seatedMatData["Thickness"], vertOHheight],
        "X" => [0, 0]
      }

      ##Generate Instance
      itemComponentInstances << PH::SKP.drawOBJ(coordsObj, itemsLength, argCDname:"#{componentDefinitionName}Vertical", argContainer:newGroup)
      itemComponentInstances[-1].material = PH::SKP.getShader(@matOSS_Name)
      @items["CV|SHV"] = itemComponentInstances[-1]

      #Move Sur-Hauteur to position
      transformation = Geom::Transformation.new([0, 0, ohAltitude.mm])
      newGroup.move!(transformation)
    end
  end

  # Method to draw finishing studs.
  # @return [Array<Sketchup::ComponentInstance>] the OCL finishing Studs component instances generated.
  # @!scope instance
  # @!group Drawing Methods
  # @version 0.12.1
  # @since 0.12.0
  def draw_finishingStuds
    #Get material Data
    matDataFIN = PH::CFG.getOCLmaterialData(@data["MAT"]["FIN"])
    matDataOSS = PH::CFG.getOCLmaterialData(@data["MAT"]["OSS"])
    supportT = PH::CFG.getOCLmaterialData("3PlisT10")["Thickness"]

    #Define Drawing Coords
    offsetBAlu = @data["BA?"] == "X" ? @data["FIN"]["SGAP"] : 0
    studFinWidth = @data["WALL"]["FD"] + @data["FIN"]["EGAP"] - offsetBAlu
    studFinHeight = @data["FRAME"]["H"] +
                    @data["FRAME"]["CMPB"] +
                    @data["FRAME"]["CMP"] +
                    @data["CV"]["H"] -
                    (10 + @data["FIN"]["VGAP"])

    leftPosition = [matDataOSS["Thickness"],
                    0,
                    (supportT + 45) + 10 + @data["FIN"]["VGAP"]]

    rightPosition = [matDataOSS["Thickness"] + @data["FRAME"]["L"] + 2*@data["FRAME"]["CMP"] - matDataFIN["Thickness"],
                     0,
                     (supportT + 45) + 10 + @data["FIN"]["VGAP"]]

    #Define face coordinates
    face_coords = []
    face_coords << [0, @data["WALL"]["FD"]-offsetBAlu, 0]
    face_coords << [0, -@data["FIN"]["EGAP"], -(studFinWidth * 0.1).round]
    face_coords << [0, -@data["FIN"]["EGAP"], studFinHeight]
    face_coords << [0, @data["WALL"]["FD"]-offsetBAlu, studFinHeight]

    #Define Component Names
    componentDefinitionName = "P#{@ID}|MONTANT FIN_"

    #Generate Items
    itemComponentInstances = []

    #Generate Left Instance
    itemComponentInstances << PH::SKP.drawOBJ(face_coords, matDataFIN["Thickness"], argCDname:"#{componentDefinitionName}Left", argCIpos:leftPosition, argContainer:@object)

    #Generate Right Instance
    itemComponentInstances << PH::SKP.drawOBJ(face_coords, matDataFIN["Thickness"], argCDname:"#{componentDefinitionName}Right", argCIpos:rightPosition, argContainer:@object)

    @items["STUDS|FIN"] = itemComponentInstances

    #Apply modifications
    itemComponentInstances.each do |currentCI|
      currentCI.material = PH::SKP.getShader(@matFIN_Name)
    end
  end
end