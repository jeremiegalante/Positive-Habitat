#Load generic Requires
require 'json'

#Load PH Requires
require_relative 'PH'
require_relative 'patch/hash'

class PH::Frame
  #DRAWING DATA
  @@nextCoord = [0,0,0]
  @@frames = {}
  @@frames_data = {}

  #Pré_Cadre SKP Object
  @object = nil
  @objectPurgeEntities = []
  @atCoord = []

  #INSTANCE VARIABLE
  @data


  #CONSTRUCTOR
  def initialize(argNomenclature={})
    raise "argNomenclature is not type of Hash" unless argNomenclature.is_a? Hash

    #Create the data a default data hash values
    @data = argNomenclature
    posteID = @data["ID"]

    #Generate Frame container
    @object = Sketchup.active_model.active_entities.add_group
    @object.name = "POSTE #{posteID}"
    @objectPurgeEntities = [@object.entities.add_cpoint(Geom::Point3d.new)]
    @atCoord = []

    #Get Material data
    @mat = {}

    ##Get Mat OSS data
    @matOSS_Name = @data["MAT"]["OSS"]
    @mat[@matOSS_Name] = PH::CFG.getOCLmaterialData(@matOSS_Name)

    ##Get Mat FIN data
    @matFIN_Name = @data["MAT"]["FIN"]
    @mat[@matFIN_Name] = PH::CFG.getOCLmaterialData(@matFIN_Name) if @matFIN_Name != ""

    #Set option status
    ["VR?", "CS?", "BA?", "BAS?"].each do |option|
      @data[option] = (@data[option] != "")
    end

    '''
    #In case of an existing POSTE has already been generated compare their datas
    if @@frames.key?(posteID)
      #Incase of the same datas
      if @@frames_data[posteID] == @data
        #Update the current coord based on the precedent one
        ##Update the Xaxis Poste position
        @atCoord[0] = @@nextCoord[0]
        @@nextCoord[0] = @atCoord[0] + @data["FRAME"]["L"] + 1000

        ##Update the Yaxis frame position
        @atCoord[1] = @@nextCoord[1]
        @@nextCoord[1] = @atCoord[1] + 1000

        ##Set the Zaxis to neutral altitude position
        @atCoord[2] = @@nextCoord[2]

        #Store this one in generation
        @@frames[posteID] << @object

        #Cast an ERROR if the Poste Data do not match with the one added
      else
        raise "A different Frame has already been generated with the POSIE num #{posteID}" if @@frames_data[posteID] != @data
      end

      #Either store a new one
    else
      @@frames[posteID] = [@object]
      @@frames_data[posteID] = @data
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

    #DRAW VR
    draw_VR if @data["VR"]

    #DRAW FENÊTRE/BOIS
    #draw_studs_reinforcement("PliDouglasT19") if @data["RS"] != 0

    #CLEAN/DELETE SECURITY ENTITIES
    @objectPurgeEntities.each {|entityToDelete| entityToDelete.erase! unless entityToDelete.deleted?}

    #MOVE AT THE RIGHT POSITION
    '''
    atCoord_mm = @atCoord.collect {|value| value.mm}
    moveTo = Geom::Transformation.new(atCoord_mm)
    @object.move!(moveTo)
    '''

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
    componentDefinitionName = "P#{@data["ID"]}|CADRE FENÊTRE_"
    itemComponentInstances = []

    #Create Pré-Cadre Container for Items
    newGroup = @object.entities.add_group()
    @objectPurgeEntities << newGroup.entities.add_cpoint(Geom::Point3d.new)
    newGroup.name = "Pré-Cadre Fenêtre"

    #Generate Items
    frameV_height = @data["FRAME"]["H"] - 2 * @data["FRAME"]["T"]
    dessousPSEheight = 45 + PH::CFG.getOCLmaterialData("SupportT10")["Thickness"]

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

    supportT = PH::CFG.getOCLmaterialData("SupportT10")["Thickness"]
    studHeight = supportT + 45 +
                 @data["FRAME"]["H"] +
                 @data["FRAME"]["OFF"] +
                 @data["VR"]["H"] +
                 @data["OH"]["H"] +
                 (( (@data["OH"]["H"] == 0) and @data["CS"]) ? supportT : 0)

    #Define Component Names
    componentDefinitionName = "P#{@data["ID"]}|MONTANT PX_"

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
    if @data["CS"]
      #Define Drawing Coords
      cupHatLength = @data["FRAME"]["L"] + 2*@data["FRAME"]["OFF"]
      coordsObj = {
        "Y" => [0, @data["WALL"]["T"]],
        "Z" => [-3, -(supportT+3)],
        "X" => [0, 0]
      }

      #Define Component Names
      componentDefinitionName = "P#{@data["ID"]}|CHAPEAU"

      #Generate Instance
      itemComponentInstances << PH::SKP.drawOBJ(coordsObj, -cupHatLength, argCDname:componentDefinitionName, argCIpos:[0, 0, studHeight], argContainer:@object)
      itemComponentInstances[-1].material = PH::SKP.getShader("SupportT10")
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
    componentDefinition.name = "P#{@data["ID"]}|XPS PX"

    ##Move at the right place
    bottomHeight = PH::CFG.getOCLmaterialData("SupportT10")["Thickness"]
    transformation = Geom::Transformation.new([0, 0, bottomHeight.mm])
    componentInstances[-1].move!(transformation)

    ##Set OCL (Open Cut List) Shader
    componentInstances[-1].material = PH::SKP.getShader("FrameXPS")

    #BOTTOM SEATED
    ##Define Drawing Coords
    bottom_height = PH::CFG.getOCLmaterialData("SupportT10")["Thickness"]
    bottomLength = @data["FRAME"]["L"] + 2*@data["FRAME"]["OFF"]
    coordsObj = {
      "Y" => [0, @data["WALL"]["T"]],
      "Z" => [0, bottom_height],
      "X" => [0, 0]
    }

    #Generate Instance
    componentInstances << PH::SKP.drawOBJ(coordsObj, bottomLength, argCDname:"P#{@data["ID"]}|BAS PX", argContainer:@object)
    componentInstances[-1].material = PH::SKP.getShader("SupportT10")

    return componentInstances
  end

  # Method to draw OCL VR reservation over the Frame.
  # @return [Sketchup::ComponentInstance] the OCL PSE element component instance generated.
  # @!scope instance
  # @!group Drawing Methods
  # @version 0.10.0
  # @since 0.10.0
  def draw_VR
    #Create Volets Container for Items
    newGroup = @object.entities.add_group()
    @objectPurgeEntities << newGroup.entities.add_cpoint(Geom::Point3d.new)
    newGroup.name = "Caisson VR"

    #Store the created OCL Components
    itemComponentInstances = []

    #Get Seated Material Data
    seatedMatData = PH::CFG.getOCLmaterialData("SupportT10")

    #Get dimensions to use
    itemsLength = @data["FRAME"]["L"] + 2*@data["FRAME"]["OFF"]
    supportT = PH::CFG.getOCLmaterialData("SupportT10")["Thickness"]
    vrAltitude = supportT + 45 +
                 @data["FRAME"]["H"] +
                 @data["FRAME"]["OFF"]
    ohAltitude = vrAltitude + @data["VR"]["H"]

    #Define vertical item heights according VR, OH, CS? settings in case of no CS is requested
    ## And no OH is requested withdraw margin from VR height
    ## Or an OH is requested withdraw margin from OH height
    vertHeight = @data["VR"]["H"]
    vertOHheight = @data["OH"]["H"]

    if !@data["CS?"]
      if (@data["OH"]["H"] == 0)
        vertHeight -= @data["VR"]["OFF"]
      else
        vertOHheight -= @data["VR"]["OFF"]
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
    componentDefinitionName = "P#{@data["ID"]}|VOLET_"

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
    transformation = Geom::Transformation.new([0, 0, vrAltitude.mm])
    newGroup.move!(transformation)


    #DRAW SUR-HAUTEUR
    unless @data["OH"]["H"] == 0
      #Define Component Names
      componentDefinitionName = "P#{@data["ID"]}|SUR-HAUTEUR_"

      #Create Sur-Hauteur Container for Items
      newGroup = @object.entities.add_group()
      @objectPurgeEntities << newGroup.entities.add_cpoint(Geom::Point3d.new)
      newGroup.name = "Caisson VR Sur-Hauteur"

      #DRAW SUR-HAUTEUR HORIZONTALE
      ##Define Drawing Coords
      coordsObj = {
        "Y" => [0, @data["WALL"]["FD"] + @mat[@matOSS_Name]["Thickness"]],
        "Z" => [0, seatedMatData["Thickness"]],
        "X" => [0, 0]
      }

      ##Generate Instance
      itemComponentInstances << PH::SKP.drawOBJ(coordsObj, itemsLength, argCDname:"#{componentDefinitionName}Horizontale", argContainer:newGroup)
      itemComponentInstances[-1].material = PH::SKP.getShader("SupportT10")

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

    #DRAW CHAPEAU SUPERIEUR
    if @data["CS?"]
      ##Define Drawing Coords
      chapeau_height = PH::CFG.getOCLmaterialData("SupportT10")["Thickness"]
      chapeauLength = @data["FRAME"]["L"] + 2*@data["FRAME"]["OFF"] + 2*@mat[@matOSS_Name]["Thickness"]
      coordsObj = {
        "X" => [0, chapeauLength],
        "Y" => [0, @data["WALL"]["T"]],
        "Z" => [0, 0]
      }

      #Generate Instance
      itemComponentInstances << PH::SKP.drawOBJ(coordsObj, chapeau_height, argCDname:"P#{@data["ID"]}|CHAPEAU", argCIpos:[-@mat[@matOSS_Name]["Thickness"], 0, ohAltitude+@data["OH"]["H"]+chapeau_height], argContainer:@object)
      itemComponentInstances[-1].material = PH::SKP.getShader("SupportT10")
    end
  end
end