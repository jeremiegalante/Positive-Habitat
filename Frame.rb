#Load generic Requires
require 'json'

#Load PH Requires
require_relative 'PH'
require_relative 'patch/hash'

class PH::Frame
  #CLASS VARIABLE
  @@posteXpos = {}
  @@nextPosteXpos = 0
  @@posteNextYPos = {}
  @@posteData = {}
  @@store

  #CLASS VARIABLE ACCESSORS
  def self.posteData; return @@posteData; end
  def self.posteData=(newValue); @@posteData = newValue; end


  #INSTANCE VARIABLE
  @ID = nil
  @object = nil
  @objectPurgeEntities = []
  @atCoord = []
  @data

  #INSTANCE VARIABLE ACCESSORS
  attr_accessor :object
  attr_accessor :data


  #CONSTRUCTOR
  def initialize(argNomenclature={})
    raise "argNomenclature is not type of Hash" unless argNomenclature.is_a? Hash

    #Create the data a default data hash values
    @data = argNomenclature
    @ID = @data.delete("ID")

    #Change the ID in case a Frame already exists with the same ID and not the same data
    @ID = 0
    @@posteData.keys.sort.each do |currentID|
      break if currentID > @ID
      @ID += 1
    end
    #@ID = rand 500..1000 if @@posteData.keys.include? @ID and @@posteData[@ID] != @data

    #Store the new data generated
    @@posteData[@ID] = @data unless @@posteData.keys.include?(@ID)

    #Generate Frame container
    @object = Sketchup.active_model.active_entities.add_group
    @object.name = "POSTE #{@ID}"
    @objectPurgeEntities = [@object.entities.add_cpoint(Geom::Point3d.new)]
    @atCoord = [0, 0, 0]

    #Get Material data
    @mat = {}

    ##Get Mat OSS data
    @matOSS_Name = @data["MAT"]["OSS"]
    @mat[@matOSS_Name] = PH::CFG.getOCLmaterialData(@matOSS_Name)

    ##Get Mat FIN data
    @matFIN_Name = @data["MAT"]["FIN"]
    @mat[@matFIN_Name] = PH::CFG.getOCLmaterialData(@matFIN_Name) if @matFIN_Name != ""

    #SET POSITION
    currentID = @ID.to_s.to_sym

    ##Initialize the position coordinates
    @atCoord = [0, 0, 0]

    ##Generate a new X position in case a Poste hasn't been created before
    if !@@posteXpos.key?(currentID)
      #Update this poste X position
      @@posteXpos[currentID] = @@nextPosteXpos
      @atCoord[0] = @@posteXpos[currentID]

      #And update the next next X position
      @@nextPosteXpos += @data["FRAME"]["L"] + 1000
    end

    ##Set te Poste X position
    @atCoord[0] = @@posteXpos[currentID]

    ##Set the Y Position
    ##Get the frame next position if the Poste has already been generated once
    if @@posteNextYPos.key?(currentID)
      #Get the next position
      @atCoord[1] = @@posteNextYPos[currentID]

    ##Start a new Poste position
    else
      #Update next Frame of the same Pole Y position
      @@posteNextYPos[currentID] = 0
    end

    ##Update Frame next position
    @@posteNextYPos[currentID] += @data["WALL"]["T"] + 1000

    '''
    #STORE DATA IN ATTRIBUTE DICTIONARY
    ##Get the model Attribute Dictionary
    adName = "DATA"
    adDataCurrentModel = Sketchup.active_model.attribute_dictionaries[adName]
    adDataCurrentModel = Sketchup.active_model.attribute_dictionary(adName, true) if adDataCurrentModel.nil?

    ##Get the model Frame Data
    adFrameDataName = "frameData"
    adFrameData = adDataCurrentModel[adFrameDataName]
    if adFrameData.nil?
      #create to Poste data and add it
      adFrameData = {@ID => @data}
    else
      #Just store the it
      adFrameData[@ID] = @data
    end
    '''
  end


  #INSTANCE DRAWING METHODS
  # Method to draw all the Frame.
  # @return nil
  # @!scope instance
  # @!group Drawing Methods
  # @version 0.10.0
  # @since 0.1.0
  def draw
    #START OPERATION
    Sketchup.active_model.start_operation("Modeling Frame #{@poste_name}", disable_ui:true, next_transparent:false, transparent:false)

    #DRAW PRE-CADRE
    draw_precadre

    #DRAW STUDS
    draw_studs

    #DRAW PSE ASSISE
    draw_xps

    #DRAW Coffret/Volet
    draw_CV if @data["CV?"]

    #DRAW FENÊTRE/BOIS
    draw_finishingStuds if @data["MAT"]["FIN"] != ""

    #CLEAN/DELETE SECURITY ENTITIES
    @objectPurgeEntities.each {|entityToDelete| entityToDelete.erase! unless entityToDelete.deleted?}

    #MOVE AT THE RIGHT POSITION
    atCoord_mm = @atCoord.collect {|value| value.mm}
    moveTo = Geom::Transformation.new(atCoord_mm)
    @object.move!(moveTo)

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

    #Generate Items
    frameV_height = @data["FRAME"]["H"] - 2 * @data["FRAME"]["T"]
    dessousPSEheight = 45 + PH::CFG.getOCLmaterialData("3PlisT10")["Thickness"]

    #Generate Bottom Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObjH, -@data["FRAME"]["T"], argCDname:"#{componentDefinitionName}Bottom", argCIpos:[@data["FRAME"]["OFF"], @data["WALL"]["FD"], dessousPSEheight], argContainer:newGroup)

    #Generate Top Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObjH, -@data["FRAME"]["T"], argCDname:"#{componentDefinitionName}Top", argCIpos:[@data["FRAME"]["OFF"], @data["WALL"]["FD"], dessousPSEheight+@data["FRAME"]["H"]-@data["FRAME"]["T"]], argContainer:newGroup)

    #Generate Left Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObjV, -frameV_height, argCDname:"#{componentDefinitionName}Left", argCIpos:[@data["FRAME"]["OFF"], @data["WALL"]["FD"], dessousPSEheight+@data["FRAME"]["T"]], argContainer:newGroup)

    #Generate Right Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObjV, -frameV_height, argCDname:"#{componentDefinitionName}Right", argCIpos:[@data["FRAME"]["OFF"]+@data["FRAME"]["L"]-@data["FRAME"]["T"], @data["WALL"]["FD"], dessousPSEheight+@data["FRAME"]["T"]], argContainer:newGroup)

    #Apply OCL material
    itemComponentInstances.each do |currentCI|
      currentCI.material = PH::SKP.getShader("Frame")
    end

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

    supportT = PH::CFG.getOCLmaterialData("3PlisT10")["Thickness"]
    studHeight = supportT + 45 +
                 @data["FRAME"]["H"] +
                 @data["FRAME"]["OFF"] +
                 @data["CV"]["H"] +
                 @data["OH"]["H"] +
                 (( @data["OH"]["H"] == 0 and @data["CS?"] == "X") ? supportT+@data["OH"]["OFF"] : 0)

    #Define Component Names
    componentDefinitionName = "P#{@ID}|MONTANT PX_"

    #Generate Items
    itemComponentInstances = []

    #Generate Left Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObj, -studHeight, argCDname:"#{componentDefinitionName}Left", argCIpos:[-@mat[@matOSS_Name]["Thickness"], 0, 0], argContainer:@object)

    #Generate Right Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObj, -studHeight, argCDname:"#{componentDefinitionName}Right", argCIpos:[@data["FRAME"]["L"]+2*@data["FRAME"]["OFF"], 0, 0], argContainer:@object)

    #Apply OCL material
    itemComponentInstances.each do |currentCI|
      currentCI.material = PH::SKP.getShader(@matOSS_Name)
    end

    #Generate Châpeau if requested
    if @data["CS?"] == "X"
      ##Define Drawing Coords
      chapeau_height = PH::CFG.getOCLmaterialData("3PlisT10")["Thickness"]
      chapeauLength = @data["FRAME"]["L"] + 2*@data["FRAME"]["OFF"]
      coordsObj = {
        "X" => [0, chapeauLength],
        "Y" => [0, @data["WALL"]["T"]],
        "Z" => [0, 0]
      }

      #Define Component Names
      componentDefinitionName = "P#{@ID}|CHAPEAU"

      #Generate Instance
      itemComponentInstances << PH::SKP.drawOBJ(coordsObj, chapeau_height, argCDname:componentDefinitionName, argCIpos:[0, 0, studHeight-@data["OH"]["OFF"]], argContainer:@object)
      itemComponentInstances[-1].material = PH::SKP.getShader("3PlisT10")
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
    newFace.pushpull((@data["FRAME"]["L"]+2*@data["FRAME"]["OFF"]).mm)

    ##Transform to OCL Element
    componentInstances << newGroup.to_component
    componentDefinition = componentInstances[-1].definition
    componentDefinition.name = "P#{@ID}|XPS PX"

    ##Move at the right place
    bottomHeight = PH::CFG.getOCLmaterialData("3PlisT10")["Thickness"]
    transformation = Geom::Transformation.new([0, 0, bottomHeight.mm])
    componentInstances[-1].move!(transformation)

    ##Set OCL (Open Cut List) Shader
    componentInstances[-1].material = PH::SKP.getShader("FrameXPS")

    #BOTTOM SEATED
    ##Define Drawing Coords
    bottom_height = PH::CFG.getOCLmaterialData("3PlisT10")["Thickness"]
    bottomLength = @data["FRAME"]["L"] + 2*@data["FRAME"]["OFF"]
    coordsObj = {
      "Y" => [0, @data["WALL"]["T"]],
      "Z" => [0, bottom_height],
      "X" => [0, 0]
    }

    #Generate Instance
    componentInstances << PH::SKP.drawOBJ(coordsObj, bottomLength, argCDname:"P#{@ID}|BAS PX", argContainer:@object)
    componentInstances[-1].material = PH::SKP.getShader("3PlisT10")

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
    itemsLength = @data["FRAME"]["L"] + 2*@data["FRAME"]["OFF"]
    supportT = PH::CFG.getOCLmaterialData("3PlisT10")["Thickness"]
    cvAltitude = supportT + 45 +
                 @data["FRAME"]["H"] +
                 @data["FRAME"]["OFF"]
    ohAltitude = cvAltitude + @data["CV"]["H"]

    #Define vertical item heights according CV, OH, CS? settings in case of no CS is requested
    ## And no OH is requested withdraw margin from CV height
    ## Or an OH is requested withdraw margin from OH height
    vertHeight = @data["CV"]["H"]
    vertOHheight = @data["OH"]["H"]

    if !@data["CS?"]
      if (@data["OH"]["H"] == 0)
        vertHeight -= @data["CV"]["OFF"]
      else
        vertOHheight -= @data["CV"]["OFF"]
      end
    end


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

      #DRAW SUR-HAUTEUR VERTICALE
      ##Define Drawing Coords
      coordsObj = {
        "Y" => [0, @mat[@matOSS_Name]["Thickness"]],
        "Z" => [seatedMatData["Thickness"], vertOHheight],
        "X" => [0, 0]
      }

      ##Generate Instance
      itemComponentInstances << PH::SKP.drawOBJ(coordsObj, itemsLength, argCDname:"#{componentDefinitionName}Verticale", argContainer:newGroup)
      itemComponentInstances[-1].material = PH::SKP.getShader(@matOSS_Name)

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
                    @data["FRAME"]["OFF"] +
                    @data["CV"]["H"] -
                    (10 + @data["FIN"]["VGAP"])

    leftPosition = [matDataOSS["Thickness"],
                    0,
                    (supportT + 45) + 10 + @data["FIN"]["VGAP"]]

    rightPosition = [matDataOSS["Thickness"] + @data["FRAME"]["L"] + 2*@data["FRAME"]["OFF"] - matDataFIN["Thickness"],
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

    #Apply modifications
    itemComponentInstances.each do |currentCI|
      currentCI.material = PH::SKP.getShader(@matFIN_Name)
    end
  end


  #CLASS METHODS
  # Method to reinitialise Postes drawing positions.
  # @return nil
  # @!scope class
  # @!group Maintenance
  # @version 0.11.2
  # @since 0.11.2
  def self.initPostesPositions
    @@posteXpos = {}
    @@nextPosteXpos = 0
    @@posteNextYPos = {}
  end
end