#Load generic Requires
require 'json'

#Load PH Requires
require_relative 'PH'

class PH::PreCadre
  #DRAWING DATA
  @@baseCoord = [0,0,0]
  @@currentCoord = [0,0,0]

  #Pré_Cadre SKP Object
  @object = nil
  @objectPurgeEntities = []

  #Pré-Cadre IDs
  @poste_id =nil
  @poste_name = nil
  @skp_object = nil

  #INSTANCE VARIABLE
  @nomenclature = nil

  #Dimensions
  @wall_thickness = nil
  @win_length = nil
  @win_height = nil
  @win_overHeight = nil
  @offset = nil

  #Options
  @vr = false
  @hat_cup = false
  @hat_bottom = true

  #Finish material
  @matName = nil
  @mat = nil
  @matFinName = nil
  @matFin = nil


  #CONSTRUCTOR
  def initialize(argNomenclature)
    raise "argNomenclature is not type of Hash" unless argNomenclature.is_a? Hash

    #Set Poste attributes
    @nomenclature = argNomenclature
    @nomenclature.each_pair do |nom_key, nom_value|
      case nom_key
        when "ID"; @poste_id = nom_value.to_i, @poste_name = "POSTE #{nom_value}"
        when "WT"; @wall_thickness = nom_value.to_i
        when "MATO"; @matName=nom_value; @mat = PH::CFG.getOCLmaterialData(nom_value)
        when "MATF"; @matFinName=nom_value; @matFin = PH::CFG.getOCLmaterialData(nom_value)
        when "FL"; @win_length = nom_value.to_i
        when "FH"; @win_height = nom_value.to_i
        when "FSH"; @win_overHeight = nom_value.to_i
        when "FC"; @offset = nom_value.to_i
        when "FD"; @win_extDistance = nom_value.to_i
        when "FE"; @pc_thickness = nom_value.to_i
        when "VR"; @vr = nom_value == "" ? false : true
        when "CS"; @cup_hat = nom_value == "" ? false : true
      end
    end

    #Generate Windows Poste Container
    @object = Sketchup.active_model.active_entities.add_group
    @objectPurgeEntities = [@object.entities.add_cpoint(Geom::Point3d.new)]
    @object.name = @poste_name

  end


  #INSTANCE DRAWING METHODS
  def draw
    #START OPERATION
    Sketchup.active_model.start_operation("Modeling Frame #{@poste_name}", disable_ui:true, next_transparent:false, transparent:false)

    #DRAW PRE-CADRE
    ##Define Drawing Coords
    coordsObjH = {
      "X" => [0, @win_length],
      "Y" => [0, @pc_thickness],
      "Z" => [0, 0]
    }

    coordsObjV = {
      "X" => [0, @pc_thickness],
      "Y" => [0, @pc_thickness],
      "Z" => [0, 0]
    }

    ##Define Component Names
    componentDefinitionHname = "CF_HB_L#{@win_length}T#{@pc_thickness}H#{@pc_thickness}"
    componentDefinitionVheight = @win_height - 2 * @pc_thickness
    componentDefinitionVname = "CF_VB_L#{@pc_thickness}T#{@pc_thickness}H#{componentDefinitionVheight}"
    componentInstanceName = "#{@poste_name}_Cadre Fenêtre"

    ##Create Pré-Cadre Container for Items
    newGroup = @object.entities.add_group()
    @objectPurgeEntities << newGroup.entities.add_cpoint(Geom::Point3d.new)
    newGroup.name = "Cadre Fenêtre"

    ##Generate Items
    itemComponentInstances = []
    dessousPSEheight = 45 + PH::CFG.getOCLmaterialData("SupportT10")["Thickness"]

    ##Generate Bottom Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObjH, -@pc_thickness, argCIname:"#{componentInstanceName} Bas", argCDname:componentDefinitionHname, argCIpos:[@offset, @win_extDistance, dessousPSEheight], argContainer:newGroup)
    itemComponentInstances[-1].name = "#{componentInstanceName} Bas"

    ##Generate Top Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObjH, -@pc_thickness, argCIname:"#{componentInstanceName} Haut", argCDname:componentDefinitionHname, argCIpos:[@offset, @win_extDistance, dessousPSEheight+@win_height-@pc_thickness], argContainer:newGroup)
    itemComponentInstances[-1].name = "#{componentInstanceName} Haut"

    ##Generate Left Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObjV, -componentDefinitionVheight, argCIname:"#{componentInstanceName} Gauche", argCDname:componentDefinitionVname, argCIpos:[@offset, @win_extDistance, dessousPSEheight+@pc_thickness], argContainer:newGroup)
    itemComponentInstances[-1].name = "#{componentInstanceName} Gauche"

    ##Generate Right Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObjV, -componentDefinitionVheight, argCIname:"#{componentInstanceName} Droit", argCDname:componentDefinitionVname, argCIpos:[@offset+@win_length-@pc_thickness, @win_extDistance, dessousPSEheight+@pc_thickness], argContainer:newGroup)
    itemComponentInstances[-1].name = "#{componentInstanceName} Droit"

    ##Rename and convert to OCL
    itemComponentInstances.each do |currentCI|
      currentCI.name = "Poste0"
      PH::SKP.toOCL(currentCI, "PreCadre")
    end


    #DRAW STUDS
    ##Define Drawing Coords
    coordsObj = {
      "X" => [0, @mat["Thickness"]],
      "Y" => [0, @wall_thickness],
      "Z" => [0, 0]
    }
    montantHeight = @win_height + @win_overHeight + 45 + (@cup_hat ? PH::CFG.getOCLmaterialData("SupportT10")["Thickness"] + @offset : 0) + (@vr ? 188 : 0)

    ##Define Component Names
    componentDefinitionName = "MONTANT_W#{@wall_thickness}T#{@mat["Thickness"]}H#{montantHeight}"
    componentInstanceName = "#{@poste_name}_Montant"

    ##Generate Items
    itemComponentInstances = []

    ##Generate Left Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObj, -montantHeight, argCDname:componentDefinitionName, argCIpos:[-(@mat["Thickness"]), 0, 0], argContainer:@object)
    itemComponentInstances[-1].name = "#{componentInstanceName} Gauche"

    ##Generate Right Instance
    itemComponentInstances << PH::SKP.drawOBJ(coordsObj, -montantHeight, argCDname:componentDefinitionName, argCIpos:[@win_length+2*@offset, 0, 0], argContainer:@object)
    itemComponentInstances[-1].name = "#{componentInstanceName} Droit"

    ##Rename and convert to OCL
    itemComponentInstances.each do |currentCI|
      PH::SKP.toOCL(currentCI, @matName)
    end

    #Generate Chapeau if requested
    if @cup_hat
      #Define Drawing Coords
      cupHatLength = @win_length + 2*@offset + 2*@mat["Thickness"]
      cupHatLengthThickness = PH::CFG.getOCLmaterialData("SupportT10")["Thickness"]
      coordsObj = {
        "Y" => [0, @wall_thickness],
        "Z" => [0, cupHatLengthThickness],
        "X" => [0, 0]
      }

      #Define Component Names
      componentDefinitionName = "CHAPEAU_L#{@wall_thickness}W#{@mat["Thickness"]}T#{montantHeight}"
      componentInstanceName = "#{@poste_name}_Chapeau"

      #Generate Instance
      itemComponentInstance = PH::SKP.drawOBJ(coordsObj, cupHatLength, argCIname:componentInstanceName, argCDname:componentDefinitionName, argCIpos:[-(@mat["Thickness"]), 0, montantHeight], argContainer:@object)
      PH::SKP.toOCL(itemComponentInstance, "SupportT10")
      itemComponentInstance.name = componentInstanceName
    end


    #DRAW DESSOUS
    ##Get Seated Material Height
    seatedMatData = PH::CFG.getOCLmaterialData("SupportT10")

    ##Define Drawing Coords
    coordsObj = {
      "Y" => [0, @wall_thickness],
      "Z" => [0, seatedMatData["Thickness"]],
      "X" => [0, 0]
    }

    ##Define Component Names
    componentDefinitionName = "DESSOUS_L#{@win_length}W#{@wall_thickness}T#{seatedMatData["Thickness"]}"
    componentInstanceName = "#{@poste_name}_Dessous"

    #Generate Instance
    itemComponentInstance = PH::SKP.drawOBJ(coordsObj, @win_length+2*@offset, argCIname:componentInstanceName, argCDname:componentDefinitionName, argContainer:@object)
    PH::SKP.toOCL(itemComponentInstance, "SupportT10")
    itemComponentInstance.name = componentInstanceName


    #DRAW PSE ASSISE
    draw_pse_sat


    #DRAW VR
    if @vr
      #Create Volets Container for Items
      newGroup = @object.entities.add_group()
      @objectPurgeEntities << newGroup.entities.add_cpoint(Geom::Point3d.new)
      newGroup.name = "Volets"

      #DRAW VOLET HORIZONTAL
      ##Define Drawing Coords
      coordsObj = {
        "Y" => [@win_extDistance + @mat["Thickness"], @wall_thickness],
        "Z" => [0, @mat["Thickness"]],
        "X" => [0, 0]
      }

      ##Define Component Names
      componentDefinitionName = "VOLETH_L#{@win_length+2*@offset}W#{@wall_thickness - @win_extDistance - @mat["Thickness"]}T#{@mat["Thickness"]}"
      componentInstanceName = "#{@poste_name}_Volet Horizontal"

      ##Generate Instance
      itemComponentInstance = PH::SKP.drawOBJ(coordsObj, @win_length+2*@offset, argCIname:componentInstanceName, argCDname:componentDefinitionName, argContainer:newGroup)
      PH::SKP.toOCL(itemComponentInstance, @matName)
      itemComponentInstance.name = componentInstanceName

      #DRAW VOLET VERTICAL
      ##Define Drawing Coords
      coordsObj = {
        "Y" => [@win_extDistance, @win_extDistance + @mat["Thickness"]],
        "Z" => [0, 188],
        "X" => [0, 0]
      }

      ##Define Component Names
      componentDefinitionName = "VOLETV_L#{@win_length+2*@offset}H#{188}T#{@mat["Thickness"]}"
      componentInstanceName = "#{@poste_name}_Volet Vertical"

      ##Generate Instance
      itemComponentInstance = PH::SKP.drawOBJ(coordsObj, @win_length+2*@offset, argCIname:componentInstanceName, argCDname:componentDefinitionName, argContainer:newGroup)
      PH::SKP.toOCL(itemComponentInstance, @matName)
      itemComponentInstance.name = componentInstanceName

      #Move Volets to position
      transformation = Geom::Transformation.new([0, 0, (45+@win_height+@offset+seatedMatData["Thickness"]).mm])
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
          "Y" => [0, @win_extDistance + @mat["Thickness"]],
          "Z" => [0, seatedMatData["Thickness"]],
          "X" => [0, 0]
        }

        ##Define Component Names
        componentDefinitionName = "VOLET-OH-H_L#{@win_length+2*@offset}W#{@win_extDistance + @mat["Thickness"]}T#{seatedMatData["Thickness"]}"
        componentInstanceName = "#{@poste_name}_Sur-Hauteur Horizontale"

        ##Generate Instance
        itemComponentInstance = PH::SKP.drawOBJ(coordsObj, @win_length+2*@offset, argCIname:componentInstanceName, argCDname:componentDefinitionName, argContainer:newGroup)
        PH::SKP.toOCL(itemComponentInstance, "SupportT10")
        itemComponentInstance.name = componentInstanceName

        #DRAW VOLET VERTICAL
        ##Define Drawing Coords
        coordsObj = {
          "Y" => [0, @mat["Thickness"]],
          "Z" => [seatedMatData["Thickness"], @win_overHeight],
          "X" => [0, 0]
        }

        ##Define Component Names
        componentDefinitionName = "VOLET-OH-V_L#{@win_length+2*@offset}H#{@win_overHeight-seatedMatData["Thickness"]}T#{@mat["Thickness"]}"
        componentInstanceName = "#{@poste_name}_Sur-Hauteur Verticale"

        ##Generate Instance
        itemComponentInstance = PH::SKP.drawOBJ(coordsObj, @win_length+2*@offset, argCIname:componentInstanceName, argCDname:componentDefinitionName, argContainer:newGroup)
        PH::SKP.toOCL(itemComponentInstance, @matName)
        itemComponentInstance.name = componentInstanceName

        #Move Sur-Hauteur to position
        transformation = Geom::Transformation.new([0, 0, (45+@win_height+@offset+seatedMatData["Thickness"]+190).mm])
        newGroup.move!(transformation)
        newGroup.explode
      end
    end

    #CLEAN/DELETE SECURITY ENTITIES
    @objectPurgeEntities.each {|entityToDelete| entityToDelete.erase! unless entityToDelete.deleted?}

    #FINALISE OPERATION
    commit_result = Sketchup.active_model.commit_operation
    raise "Drawing Pré-Cadre has been an unsuccessful result when commiting it " unless commit_result
  end

  def draw_pse_sat(argWidth:@win_extDistance+@pc_thickness, argSteepLength:@win_extDistance, argWindowThickness:@pc_thickness, argHeights:[3,23,45])
    raise "argWidth is not type of Numeric" unless argWidth.is_a? Numeric
    raise "argSteepLength is not type of Numeric" unless argSteepLength.is_a? Numeric
    raise "argWindowThickness is not type of Numeric" unless argWindowThickness.is_a? Numeric
    raise "argHeights is not type of Array[3]" unless argHeights.class == Array and argHeights.length == 3
    raise "argHeights is not Numerics Array[3]" unless argHeights[0].is_a? Numeric and argHeights[1].is_a? Numeric and argHeights[2].is_a? Numeric

    #Extract Component Definition from name
    ocl_CDname = "ASSISE PSE_L#{@win_length}T#{argSteepLength}"
    ocl_CIname = "#{@poste_name}_Assise PSE"
    ocl_componentDefinition = Sketchup.active_model.definitions[ocl_CDname]

    #PSE ASSISE
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
      newFace.pushpull((@win_length + 2*@offset).mm)

      #Transform to OCL Element
      ocl_componentInstance = newGroup.to_component

      #Convert to Definition
      ocl_componentDefinition = ocl_componentInstance.definition
      ocl_componentDefinition.name = ocl_CDname

      #Instanciate existing Windows Plate
    else
      transformation = Geom::Transformation.new([0,0,0])
      ocl_componentInstance = argContainer.entities.add_instance(ocl_componentDefinition, transformation)
    end

    #Move at the right place
    bottomHeight = PH::CFG.getOCLmaterialData("SupportT10")["Thickness"]
    transformation = Geom::Transformation.new([0, 0, bottomHeight.mm])
    ocl_componentInstance.move!(transformation)

    #Set OCL (Open Cut List) Shader
    ocl_componentInstance.material = PH::SKP.getShader("WindowPSE")
    ocl_componentInstance.name = "#{@poste_name} PSE"

    return ocl_componentInstance
  end

  def to_s
    return "POSTE#{@poste_id}_WT#{@wall_thickness}_FL#{}FL#{@win_length}FH#{@win_height}FSH#{@win_overHeight}_FC#{@offset}FD#{@win_extDistance}FE#{@pc_thickness}_#{@mat}|#{@matFin}"
  end
end