#Load generic Requires
require 'json'

#Load PH Requires
require_relative 'PH'
require_relative 'patch/core/hash'

class PH::PreCadre
  #DRAWING DATA
  @@currentCoord = [0,0,0]
  @@frames = {}

  #Pré_Cadre SKP Object
  @object = nil
  @objectPurgeEntities = []

  #INSTANCE VARIABLE
  @data


  #CONSTRUCTOR
  def initialize(argNomenclature={})
    raise "argNomenclature is not type of Hash" unless argNomenclature.is_a? Hash


    #Create the data a default data hash values
    @data = argNomenclature

    #Add a new frame and set the requested position
    posteID = "#{@data["ID"]}"
    @@frames.key?("#{@data["ID"]}") ? @@frames[posteID] += 1 : @@frames[posteID] = 1

    #Update the current coord
    ##Update the poste position
    @@currentCoord[0] = @data["ID"]-1 * 3000

    ##Update the frame position
    @@currentCoord[1] = @@frames[posteID] * 1000

    #Generate Frame container
    @object = Sketchup.active_model.active_entities.add_group
    @object.name = "POSTE #{@data["ID"]}"
    @objectPurgeEntities = [@object.entities.add_cpoint(Geom::Point3d.new)]

    #Get Material data
    @mat = {}

    ##Get Mat OSS data
    @matOSS_Name = @data["MAT"]["OSS"]
    @mat[@matOSS_Name] = PH::CFG.getOCLmaterialData(@matOSS_Name)

    ##Get Mat FIN data
    @matFIN_Name = @data["MAT"]["FIN"]
    @mat[@matFIN_Name] = PH::CFG.getOCLmaterialData(@matFIN_Name) if @matFIN_Name != ""

    #Set option status
    ["VR", "CS", "BA"].each do |option|
      @data[option] = (@data[option] == "X")
    end
  end


  #INSTANCE DRAWING METHODS
  def draw
    #START OPERATION
    Sketchup.active_model.start_operation("Modeling Frame #{@poste_name}", disable_ui:true, next_transparent:false, transparent:false)

    #DRAW PRE-CADRE
    draw_precadre

    #DRAW STUDS
    draw_side_studs

    #DRAW DESSOUS
    draw_dessous

    #DRAW PSE ASSISE
    draw_pse_sat

    #DRAW VR
    draw_VR if @data["VR"]

    #DRAW FENÊTRE/BOIS
    draw_joues_reinforcement("PliDouglasT19") if @data["RS"] != 0

    #CLEAN/DELETE SECURITY ENTITIES
    @objectPurgeEntities.each {|entityToDelete| entityToDelete.erase! unless entityToDelete.deleted?}

    #MOVE AT THE RIGHT POSITION
    '''
    moveTo = Geom::Transformation.new(@@currentCoord)
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
  # @version
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
    componentDefinitionName = "P#{@data["ID"]}|FRAME PSE_"
    itemComponentInstances = []

    #Create Pré-Cadre Container for Items
    newGroup = @object.entities.add_group()
    @objectPurgeEntities << newGroup.entities.add_cpoint(Geom::Point3d.new)
    newGroup.name = "Pré-Cadre Fenêtre"

    #Generate Items
    frameV_height = @data["FRAME"]["H"] - 2 * (@data["FRAME"]["T"] + @data["FRAME"]["OFF"])
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
  # @return [Array<Sketchup::ComponentInstance>] the OCL 'Montant' component instances generated.
  # @!scope instance
  # @!group Drawing Methods
  # @version
  # @since 0.5.0
  def draw_side_studs
    #Define Drawing Coords
    coordsObj = {
      "X" => [0, @mat[@matOSS_Name]["Thickness"]],
      "Y" => [0, @data["WALL"]["T"]],
      "Z" => [0, 0]
    }
    cs_height = PH::CFG.getOCLmaterialData("SupportT10")["Thickness"]
    montantHeight = @data["FRAME"]["H"] + @data["OH"]["H"] + 55 + (@data["CS"] ? cs_height + @data["FRAME"]["OFF"] : 0) + (@data["VR"] ? 188 : 0)

    ##Define Component Names
    componentDefinitionName = "FRAME PSE_"

    ##Generate Items
    itemComponentInstances = []

    ##Generate Left Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObj, -montantHeight, argCDname:"#{componentDefinitionName}Left", argCIpos:[-@mat[@matOSS_Name]["Thickness"], 0, 0], argContainer:@object)

    ##Generate Right Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObj, -montantHeight, argCDname:"#{componentDefinitionName}Right", argCIpos:[@data["FRAME"]["L"]+2*@data["FRAME"]["OFF"], 0, 0], argContainer:@object)

    ##Rename and convert to OCL
    itemComponentInstances.each do |currentCI|
      currentCI.material = PH::SKP.getShader(@matOSS_Name)
    end

    #Generate Châpeau if requested
    if @data["CS"]
      #Define Drawing Coords
      cs_height = PH::CFG.getOCLmaterialData("SupportT10")["Thickness"]
      cupHatLength = @data["FRAME"]["L"] + 2*@data["FRAME"]["OFF"] + 2* @mat[@matOSS_Name]["Thickness"]
      cupHatLengthThickness = PH::CFG.getOCLmaterialData("SupportT10")["Thickness"]
      coordsObj = {
        "Y" => [0, @data["WALL"]["T"]],
        "Z" => [0, cupHatLengthThickness],
        "X" => [0, 0]
      }

      #Define Component Names
      componentDefinitionName = "CHAPEAU_L#{@wall_thickness}W#{@mat["Thickness"]}T#{montantHeight}"
      componentInstanceName = "#{@poste_name}_Chapeau"

      #Generate Instance
      itemComponentInstance = PH::SKP.drawOBJ(coordsObj, cupHatLength, argCIname:componentInstanceName, argCDname:componentDefinitionName, argCIpos:[-@mat[@matOSS_Name]["Thickness"], 0, montantHeight], argContainer:@object)
      itemComponentInstance.material = PH::SKP.getShader("SupportT10")
    end

    return itemComponentInstances
  end

  # Method to draw OCL bottom lower element that makes the Frame seated.
  # @return [Sketchup::ComponentInstance] the OCL 'Dessous' component instance generated.
  # @!scope instance
  # @!group Drawing Methods
  # @version
  # @since 0.5.0
  def draw_dessous
    #Get Seated Material Height
    seatedMatData = PH::CFG.getOCLmaterialData("SupportT10")

    #Define Drawing Coords
    coordsObj = {
      "Y" => [0, @data["WALL"]["T"]],
      "Z" => [0, seatedMatData["Thickness"]],
      "X" => [0, 0]
    }

    #Define Component Names
    componentDefinitionName = "DESSOUS_L#{@data["FRAME"]["L"]}W#{@data["FRAME"]["T"]}T#{seatedMatData["Thickness"]}"
    componentInstanceName = "#{@poste_name}_Dessous"

    #Generate Instance
    componentInstance = PH::SKP.drawOBJ(coordsObj, @data["FRAME"]["L"]+2*@data["FRAME"]["OFF"], argCIname:componentInstanceName, argCDname:componentDefinitionName, argContainer:@object)
    componentInstance.material = PH::SKP.getShader("SupportT10")

    return componentInstance
  end

  # Method to draw OCL PSE that makes the lower part that holds the Frame.
  # @param argWidth [Numeric] the distance from the front side to the frame rear in mm.
  # @param argSteepLength [Numeric] the distance of the steep length in mm.
  # @param argWindowThickness [Numeric] the distance of the Frame thickness in mm.
  # @param argHeights [Array[3]] the list of 3 PSE steps height.
  # @return [Sketchup::ComponentInstance] the OCL PSE element component instance generated.
  # @!scope instance
  # @!group Drawing Methods
  # @version
  # @since 0.4.0
  def draw_pse_sat(argWidth:@data["WALL"]["FD"]+@data["FRAME"]["T"], argSteepLength:@data["WALL"]["FD"], argWindowThickness:@data["FRAME"]["T"], argHeights:[3,23,45])
    raise "argWidth is not type of Numeric" unless argWidth.is_a? Numeric
    raise "argSteepLength is not type of Numeric" unless argSteepLength.is_a? Numeric
    raise "argWindowThickness is not type of Numeric" unless argWindowThickness.is_a? Numeric
    raise "argHeights is not type of Array[3]" unless argHeights.class == Array and argHeights.length == 3
    raise "argHeights is not Numerics Array[3]" unless argHeights[0].is_a? Numeric and argHeights[1].is_a? Numeric and argHeights[2].is_a? Numeric

    #Extract Component Definition from name
    #Define Length


    #Define Component Names
    ocl_Cname = "XPS PX"
    ocl_CDname = "#{ocl_Cname}#{@data["FRAME"]["L"]}"
    #ocl_CDname = "ASSISE PSE_L#{@win_length}T#{argSteepLength}"
    ocl_componentDefinition = Sketchup.active_model.definitions[ocl_CDname]
    ocl_CIname = "POSTE#{@data["ID"]}_#{ocl_Cname}"

    #Create item from data
    ocl_componentInstance = nil

    if ocl_componentDefinition.nil?
      #Evaluate Dimensions
      width = argSteepLength + argWindowThickness

      #Define face coordinates
      face_coords = [[0, 0, 0]]
      face_coords << [0, 0 ,argHeights[0].mm]
      face_coords << [0, argSteepLength.mm, argHeights[1].mm]
      face_coords << [0, argSteepLength.mm, argHeights[2].mm]
      face_coords << [0, width.mm, argHeights[2].mm]
      face_coords << [0, width.mm, 0]

      #Draw face and extrude it
      newGroup = @object.entities.add_group
      newFace = newGroup.entities.add_face(face_coords)
      newFace.reverse!
      newFace.pushpull((@data["FRAME"]["L"]+2*@data["FRAME"]["OFF"]).mm)

      #Transform to OCL Element
      ocl_componentInstance = newGroup.to_component

      #Convert to Definition
      ocl_componentDefinition = ocl_componentInstance.definition
      ocl_componentDefinition.name = ocl_CDname

    #Instanciate existing PSE
    else
      transformation = Geom::Transformation.new([0,0,0])
      ocl_componentInstance = @object.entities.add_instance(ocl_componentDefinition, transformation)
    end

    #Move at the right place
    bottomHeight = PH::CFG.getOCLmaterialData("SupportT10")["Thickness"]
    transformation = Geom::Transformation.new([0, 0, bottomHeight.mm])
    ocl_componentInstance.move!(transformation)

    #Set OCL (Open Cut List) Shader
    ocl_componentInstance.material = PH::SKP.getShader("WindowPSE")
    ocl_componentInstance.name = ocl_CIname

    return ocl_componentInstance
  end

  # Method to draw OCL VR reservation over the Frame.
  # @return [Sketchup::ComponentInstance] the OCL PSE element component instance generated.
  # @!scope instance
  # @!group Drawing Methods
  # @version
  # @since 0.5.0
  def draw_VR
    #Create Volets Container for Items
    newGroup = @object.entities.add_group()
    @objectPurgeEntities << newGroup.entities.add_cpoint(Geom::Point3d.new)
    newGroup.name = "Volets"

    #Store the created OCL Components
    itemComponentInstances = []

    #Get Seated Material Height
    seatedMatData = PH::CFG.getOCLmaterialData("SupportT10")

    #DRAW VOLET HORIZONTAL
    ##Define Drawing Coords
    coordsObj = {
      "Y" => [@data["WALL"]["FD"] + @mat[@matOSS_Name]["Thickness"], @data["WALL"]["T"]],
      "Z" => [0, @mat[@matOSS_Name]["Thickness"]],
      "X" => [0, 0]
    }

    ##Define Component Names
    componentDefinitionName = "VOLETH_L#{@data["FRAME"]["L"]+2*@data["FRAME"]["OFF"]}W#{@data["WALL"]["T"] - @data["WALL"]["FD"] - @mat[@matOSS_Name]["Thickness"]}T#{@mat[@matOSS_Name]["Thickness"]}"
    componentInstanceName = "POSTE#{@data["ID"]}_Volet Horizontal"

    ##Generate Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObj, @data["FRAME"]["L"]+2*@data["FRAME"]["OFF"], argCIname:componentInstanceName, argCDname:componentDefinitionName, argContainer:newGroup)
    itemComponentInstances[-1].material = PH::SKP.getShader(@matOSS_Name)

    #DRAW VOLET VERTICAL
    ##Define Drawing Coords
    coordsObj = {
      "Y" => [@data["WALL"]["FD"], @data["WALL"]["FD"] + @mat[@matOSS_Name]["Thickness"]],
      "Z" => [0, 188],
      "X" => [0, 0]
    }

    ##Define Component Names
    componentDefinitionName = "VOLETV_L#{@data["FRAME"]["L"]+2*@data["FRAME"]["OFF"]}H#{188}T#{@mat[@matOSS_Name]["Thickness"]}"
    componentInstanceName = "POSTE#{@data["ID"]}_Volet Vertical"

    ##Generate Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObj, @data["FRAME"]["L"]+2*@data["FRAME"]["OFF"], argCIname:componentInstanceName, argCDname:componentDefinitionName, argContainer:newGroup)
    itemComponentInstances[-1].material = PH::SKP.getShader(@matOSS_Name)

    #Move Volets to position
    transformation = Geom::Transformation.new([0, 0, (45+@data["FRAME"]["H"]+@data["FRAME"]["OFF"]+seatedMatData["Thickness"]).mm])
    newGroup.move!(transformation)

    #DRAW SUR-HAUTEUR
    unless @win_overHeight == 0
      #Create Sur-Hauteur Container for Items
      newGroup = @object.entities.add_group()
      @objectPurgeEntities << newGroup.entities.add_cpoint(Geom::Point3d.new)
      newGroup.name = "Volets Sur-Hauteur"

      #DRAW SUR-HAUTEUR HORIZONTAL
      ##Define Drawing Coords
      coordsObj = {
        "Y" => [0, @data["WALL"]["FD"] + @mat[@matOSS_Name]["Thickness"]],
        "Z" => [0, seatedMatData["Thickness"]],
        "X" => [0, 0]
      }

      ##Define Component Names
      componentDefinitionName = "VOLET-OH-H_L#{@data["FRAME"]["L"]+2*@data["FRAME"]["OFF"]}W#{@data["WALL"]["FD"] + @mat[@matOSS_Name]["Thickness"]}T#{seatedMatData["Thickness"]}"
      componentInstanceName = "POSTE#{@data["ID"]}_Sur-Hauteur Horizontale"

      ##Generate Instance
      itemComponentInstances << PH::SKP.drawOBJ(coordsObj, @data["FRAME"]["L"]+2*@data["FRAME"]["OFF"], argCIname:componentInstanceName, argCDname:componentDefinitionName, argContainer:newGroup)
      itemComponentInstances[-1].material = PH::SKP.getShader("SupportT10")

      #DRAW VOLET VERTICAL
      ##Define Drawing Coords
      coordsObj = {
        "Y" => [0, @mat[@matOSS_Name]["Thickness"]],
        "Z" => [seatedMatData["Thickness"], @data["OH"]["H"]],
        "X" => [0, 0]
      }

      ##Define Component Names
      componentDefinitionName = "VOLET-OH-V_L#{@data["FRAME"]["L"]+2*@data["FRAME"]["OFF"]}H#{@data["OH"]["H"]-seatedMatData["Thickness"]}T#{@mat[@matOSS_Name]["Thickness"]}"
      componentInstanceName = "POSTE#{@data["ID"]}_Sur-Hauteur Verticale"

      ##Generate Instance
      itemComponentInstances << PH::SKP.drawOBJ(coordsObj, @data["FRAME"]["L"]+2*@data["FRAME"]["OFF"], argCIname:componentInstanceName, argCDname:componentDefinitionName, argContainer:newGroup)
      itemComponentInstances[-1].material = PH::SKP.getShader(@matOSS_Name)

      #Move Sur-Hauteur to position
      transformation = Geom::Transformation.new([0, 0, (45+@data["FRAME"]["H"]+@data["FRAME"]["OFF"]+seatedMatData["Thickness"]+190).mm])
      newGroup.move!(transformation)
      newGroup.explode
    end
  end

  # Method to draw reinforcement Joues latérales with Douglas.
  # @param argMaterial [String] the material deinined in the OCL configuration JSON file.
  # @return [Array<Sketchup::ComponentInstance>] the OCL component instances generated.
  # @!scope instance
  # @!group Drawing Methods
  # @version
  # @since 0.5.0
  def draw_joues_reinforcement(argMatrialName, argSteepLength:@data["WALL"]["FD"], argHeights:[3,23,45])
    raise "argMatrialName is not type of String" unless argMatrialName.is_a? String
    raise "argSteepLength is not type of Numeric" unless argSteepLength.is_a? Numeric
    raise "argHeights is not type of Array[3]" unless argHeights.class == Array and argHeights.length == 3
    raise "argHeights is not Numerics Array[3]" unless argHeights[0].is_a? Numeric and argHeights[1].is_a? Numeric and argHeights[2].is_a? Numeric

    #Define Drawing Coords
    montantWidth = @data["WALL"]["FD"] + @data["RS"] - (@data["BA"] ? 20 : 0)
    montantThickness = PH::CFG.getOCLmaterialData(argMatrialName)["Thickness"]
    montantHeight = @data["FRAME"]["H"] + (@data["RS"] ? 188 : 0) + ((@data["CS"] or @data["VR"]) ? 10 : 0) + 47
    montantAltitude = argHeights[0]+PH::CFG.getOCLmaterialData("SupportT10")["Thickness"]

    #Extract Component Definition from name
    ocl_CDname = "MONTANT REIN_W#{montantWidth}T#{montantThickness}H#{montantHeight}#{@data["BA"] ? "_+BA" : ""}"
    ocl_componentDefinition = Sketchup.active_model.definitions[ocl_CDname]
    ocl_CIname = "#{@poste_name}_Montant Renforcé#{@data["BA"] ? " Bois/Alu" : ""}"

    #Create item from data
    ocl_componentInstance = nil

    if ocl_componentDefinition.nil?
      #Define face coordinates
      face_coords = [[0, -@data["RS"].mm, 0]]
      face_coords << [0, 0, 0]
      face_coords << [0, (montantWidth-@data["RS"]).mm, ((argHeights[1]-argHeights[0]) * (montantWidth-@data["RS"]) / argSteepLength).mm]
      face_coords << [0, (montantWidth-@data["RS"]).mm, montantHeight.mm]
      face_coords << [0, -@data["RS"].mm, montantHeight.mm]


      #Draw face and extrude it
      newGroup = @object.entities.add_group
      newFace = newGroup.entities.add_face(face_coords)
      newFace.reverse!
      newFace.pushpull(montantThickness.mm)

      #Move Altitude
      altitude = Geom::Transformation.new([@mat["Thickness"].mm,0,montantAltitude.mm])
      newGroup.move!(altitude)

      #Transform to OCL Element
      ocl_componentInstance = newGroup.to_component

      #Convert to Definition
      ocl_componentDefinition = ocl_componentInstance.definition
      ocl_componentDefinition.name = ocl_CDname

    #Instanciate existing PSE
    else
      transformation = Geom::Transformation.new([(@win_length-montantThickness).mm,0,0])
      ocl_componentInstance = @object.entities.add_instance(ocl_componentDefinition, transformation)
    end

    #Add the right Instance
    transformation = Geom::Transformation.new([@win_length.mm, 0, montantAltitude.mm])
    componentinstances = [ocl_componentInstance]
    componentinstances << @object.entities.add_instance(ocl_componentInstance.definition, transformation)

    #Set OCL (Open Cut List) Shader
    componentinstances.each_with_index do |currentInstance, index|
      currentInstance.material = PH::SKP.getShader(argMatrialName)
      currentInstance.name = ocl_CIname + (index == 1 ? " Gauche" : " Droit")
    end

    return componentinstances
  end

  def to_s
    return "POSTE#{@poste_id}_WT#{@wall_thickness}_FL#{@win_length}FH#{@win_height}FSH#{@win_overHeight}_FC#{@offset}FD#{@win_extDistance}FE#{@pc_thickness}_#{@mat}|#{@matFin}"
  end
end