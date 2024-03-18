'''
load "E:/#Positive Habitat/PH/Frame.rb"
frame = Frame.new(argNomenclature="FRAME|T78HW97VW52_L2500T400H3000OH500LI45OFF5_BSO|MET|TOP_TreplisT19")
frame.draw
'''

#Load generic Requires
require 'json'

#Load PH Requires
require_relative 'PH_CFG'
require_relative 'PH_SKP'

class Frame
  @id =nil
  @currentCoord = [0,0,0]

  #@INSTANCE VARIABLE
  @name = ""
  @object = nil

  #Dimensions
  @length = nil
  @thickness = nil
  @height = nil
  @over_height = nil
  @lintel = nil
  @allege = nil
  @offset = nil

  #Frame PSE Dimensions
  @pse = {
    "T":0,
    "HW":0,
    "VW":0
  }

  #Options
  @bso = false
  @vr = false
  @met_seated = false
  @top = false
  @bot = false

  #Finish material
  @matName = nil
  @matThickness = nil

  #Position attribute
  @currentPosition = [0, 0, 0]
  @@otherFramePosition = nil
  @@sameNextPosition = nil
  #updatePositions


  #@INSTANCE ACCESSORS
  attr_reader :object
  attr_reader :name
  attr_reader :length
  attr_reader :thickness
  attr_reader :height

  #CONSTRUTOR
  def initialize(argNomenclature=nil, argDrawCoord=[0,0,0])
    raise "argNomenclature is not type of String or Hash" unless [String, Hash].include? argNomenclature.class
    raise "argDrawCoord is not type of Array" unless argDrawCoord.class == Array
    raise "argDrawCoord is not type of Array[3]" unless argDrawCoord.length == 3

    #Convert Hash Nomenclature to String
    if argNomenclature.is_a? Hash
      #Initialise PSE attribute
      @pse = {"T":0, "HW":0, "VW":0}

      #Parse each parameter items and set attributes
      argNomenclature.each do |key, value|
        case key
          when "L"; @length = value
          when "T"; @thickness = value
          when "H"; @height = value
          when "OH"; @over_height = value
          when "OFF"; @offset = value
          when "PT"; @pse[:T] = value
          when "PHW"; @pse[:HW] = value
          when "PVW"; @pse[:VW] = value
          when "BSO"; @bso = (value == "X" ? true : false)
          when "MET"; @met_seated = (value == "X" ? true : false)
          when "TOP"; @top = (value == "X" ? true : false)
          when "BOT"; @bottom = (value == "X" ? true : false)
        end
      end

      #Define option String
      "#{@bso ? "|BSO|" : ""}#{@met_seated ? "|MET|" : ""}#{@top ? "|TOP|" : ""}#{@bottom ? "|BOT|" : ""}"

      #Define Nomenclature name
      argNomenclature = "FRAME|T#{@pse[:T]}HW#{@pse[:HW]}VW#{@pse[:VW]}_L#{@length}T#{@thickness}H#{@height}OH#{@over_height}LI45OFF#{@offset}_#{@bso ? "BSO|" : ""}|MET|TOP_TreplisT19"
      puts argNomenclature
    end

    #Benerate an object if a Nomenclature is given
    if argNomenclature.is_a? String
      #Split Nomenclature Segments
      id_segments = argNomenclature.split("_")

      #Set Frame Name
      @name = "#{id_segments[1]}_#{id_segments[2]}_#{id_segments[3]}"
      @object = Sketchup.active_model.entities.add_group
      @toDelete = @object.entities.add_cpoint(Geom::Point3d.new)
      @object.name = argNomenclature

      #Extract Opening Dimensions
      ##Pre set over height value
      @over_height = 0

      ##Parse frame PSE segments dimension

      @pse = {
        "T":0,
        "HW":0,
        "VW":0
      }


      id_segments[0].scan(/[A-Z]+\d+/).each do |currentDim|
        #Extract from nomenclature
        dim = currentDim.scan(/\d+/)[0].scan(/\d+/).first.to_i
        case currentDim.scan(/[A-Z]/).join
          when "T"; @pse[:T] = dim
          when "HW"; @pse[:HW] = dim
          when "VW"; @pse[:VW] = dim
        end
      end

      ##Parse name parameters
      id_segments[1].scan(/[A-Z]+\d+/).each do |currentDim|
        dim = currentDim.scan(/\d+/)[0].scan(/\d+/).first.to_i
        case currentDim.scan(/[A-Z]/).join
          when "L"; @length = dim
          when "T"; @thickness = dim
          when"H"; @height = dim
          when"OH"; @over_height = dim
          when "LI"; @lintel = dim
          when "AL"; @allege = dim
          when "OFF"; @offset = dim
        end
      end

      #Extract Options
      id_segments[2].split("|").each do |current_option|
        case current_option
          when "BSO"; @bso = true
          when "MET"; @met_seated = true
          when "VR"; @vr = true
          when "TOP"; @top = true
          when "BOT"; @bottom = true
        end
      end
    end

    #Set drawing Position
    @currentCoord = argDrawCoord

    #Load JSON configs
    @matName = id_segments[-1]
    PH_CFG.loadConfigs
    @matThickness = PH_CFG.materialsOCL[@matName]["Thickness"]
  end


  #INSTANCE DRAWING METHODS
  def draw
    #DRAWING Studs
    #Store entities to delete
    postDelete = @object.entities.to_a
    entityToDelete = @object.entities.add_cpoint(Geom::Point3d.new)
    postDelete.each{|current| current.erase! if !current.is_a? Sketchup::Face}

    #Create first Stud
    draw_stud(argContainer:@object, argEndPosition:false)

    #Create second Stud
    draw_stud(argContainer:@object, argEndPosition:true)

    #Create seated plate
    draw_seated(argLength:@length, argContainer:@object, argHeight:PH_CFG.materialsOCL["SupportT10"]["Thickness"])

    #Create PSE Seated
    draw_seated_pse(argContainer:@object) if @met_seated

    #Draw SunScreen if needed
    draw_sunscreen(argContainer:@object, argWidth:((@bso or @vr) ? 200 : 0), argHeight:((@bso or @vr) ? 200 : 0), argOverHeight:@over_height)

    #Draw Frame PSE
    draw_frame_pse(argContainer:@object)

    #Delete group preservation entity
    entityToDelete.erase!
  end

  def draw_stud(argContainer:Sketchup.active_model, argEndPosition:false)
    raise "argContainer does note contain Sketchup::Entities to draw elements" unless argContainer.entities.class == Sketchup::Entities
    raise "argEndPosition is not type of Boolean [true, false]" unless [true, false].include? argEndPosition

    #Extract Existing Component Definition
    oclMatThickness = PH_CFG.materialsOCL[@matName]["Thickness"]
    ocl_CDname = "STUD_L#{@thickness}T#{oclMatThickness}H#{@height}"
    ocl_componentDefinition = Sketchup.active_model.definitions[ocl_CDname]

    #Setup face coordinates
      objCoordinates = {
        "X" => [0, @matThickness],
        "Y" => [0, @thickness],
        "Z" => [0, nil],
      }

    #Set position placement transformation
    moveVector = Geom::Vector3d.new(argEndPosition ? (@length-@matThickness).mm : 0, 0, 0)
    moveTransfo = Geom::Transformation.translation(moveVector)

    #Generate OBJ OCL component
    componentInstance = PH_SKP.drawOBJ(objCoordinates, -@height, argOBJName:"STUD_Left", argCDname:ocl_componentDefinition, argContainer:argContainer)
    componentInstance.move!(moveTransfo)
    componentInstance.material = PH_SKP.getShader(@matName)


    '''
    #Generate Component Definition in case of no definition is given and place an instance
    if ocl_componentDefinition.nil?
      #Create a Frame group if the container is Sketchup root
      newGroup = argContainer.entities.add_group
      cPoint_ToDelete = newGroup.entities.add_cpoint(Geom::Point3d.new)

      #Generate Stud ground surface
      new_face_coords =[[0,0,0],
                        [@matThickness.mm, 0, 0],
                        [@matThickness.mm, @thickness.mm, 0],
                        [0, @thickness.mm, 0]]
      new_face = newGroup.entities.add_face(new_face_coords)

      #Clean and extrude generated surface
      cPoint_ToDelete.erase!
      new_face.reverse!
      new_face.pushpull(@height.mm)

      #Transform to OCL Element
      ocl_componentInstance = newGroup.to_component

      #Extract definition
      ocl_componentDefinition = ocl_componentInstance.definition
      ocl_componentDefinition.name = ocl_CDname

    else
      #Move it at the desired position
      endPosition = [0, 0, 0]
      endPosition[0] = (@length-matThickness).mm if argEndPosition
      transformation = Geom::Transformation.new(endPosition)

      ocl_componentInstance = argContainer.entities.add_instance(ocl_componentDefinition, transformation)
    end

    #Apply the OCL shader
    ocl_componentInstance.name = ""
    ocl_componentInstance.material = PH_SKP.getShader(@matName)
    '''

    return componentInstance
  end

  def draw_seated(argLength:@length, argContainer:Sketchup.active_model, argWidth:275, argHeight:10)
    raise "argLength is not type of Numeric" unless argLength.is_a? Numeric
    raise "argWidth is not type of Numeric" unless argWidth.is_a? Numeric
    raise "argContainer does note contain Sketchup::Entities to draw elements" unless argContainer.entities.class == Sketchup::Entities
    raise "argHeight is not type of Numeric" unless argHeight.is_a? Numeric

    #Extract Component Definition from name
    ocl_CDname = "SEATED_L#{argLength}W#{argWidth}T#{argHeight}"
    ocl_componentDefinition = Sketchup.active_model.definitions[ocl_CDname]

    #Create item from data
    ocl_componentInstance = nil

    if ocl_componentDefinition.nil?
      #Rtrieve stud CFG data
      studThickness = @matThickness

      #Define face coordinates
      face_coords = []
      face_coords << [studThickness.mm, 0 ,0]
      face_coords << [(argLength-studThickness).mm, 0 ,0]
      face_coords << [(argLength-studThickness).mm, argWidth.mm ,0]
      face_coords << [studThickness.mm, argWidth.mm ,0]

      #Draw face and extrude it
      newGroup = argContainer.entities.add_group
      newFace = newGroup.entities.add_face(face_coords)
      newFace.reverse!
      newFace.pushpull(argHeight.mm)

      #Transform to OCL Element
      ocl_componentInstance = newGroup.to_component
      ocl_componentInstance.material = PH_SKP.getShader(@matName)

      #Convert to Definition
      ocl_componentDefinition = ocl_componentInstance.definition
      ocl_componentDefinition.name = ocl_CDname

    #Instanciate existing Windows Plate
    else
      transformation = Geom::Transformation.new([0,0,0])
      ocl_componentInstance = argContainer.entities.add_instance(ocl_componentDefinition, transformation)
    end

    '''
    #Move at the right place
    move = Geom::Transformation.new([0, 0, 0])
    ocl_componentInstance.move!(move)
    '''

    #Set OCL (Open Cut List) Shader
    ocl_componentInstance.material = PH_SKP.getShader("SupportT10")

    return ocl_componentInstance
  end

  def draw_seated_pse(argLength:@length, argContainer:Sketchup.active_model, argWidth:275, argSteepLength:200, argWindowThickness:75, argSeatedHeight:10)
    raise "argLength is not type of Numeric" unless argLength.is_a? Numeric
    raise "argContainer does note contain Sketchup::Entities to draw elements" unless argContainer.entities.class == Sketchup::Entities
    raise "argWidth is not type of Numeric" unless argWidth.is_a? Numeric
    raise "argSteepLength is not type of Numeric" unless argSteepLength.is_a? Numeric
    raise "argWindowThickness is not type of Numeric" unless argWindowThickness.is_a? Numeric
    raise "argSeatedHeight is not type of Numeric" unless argSeatedHeight.is_a? Numeric

    #Extract Component Definition from name
    ocl_CDname = "SEATED PSE_L#{argLength}W#{argWidth}T#{argWindowThickness}"
    ocl_componentDefinition = Sketchup.active_model.definitions[ocl_CDname]

    #Adjust dimensions
    tudThickness = PH_CFG.materialsOCL[@matName]["Thickness"]
    argLength -= 2 * tudThickness

    #Define replacement transformation
    move = Geom::Transformation.new([tudThickness.mm, 0, argSeatedHeight.mm])

    #Create item from data
    ocl_componentInstance = nil

    if ocl_componentDefinition.nil?
      #Define Dimensions
      startHeight = 3
      steepHeight = 21
      pseHeight = 45

      #Evaluate Dimensions
      width = argSteepLength + argWindowThickness

      #Define face coordinates
      face_coords = [[0, 0, 0]]
      face_coords << [0, 0 ,startHeight.mm]
      face_coords << [0, argSteepLength.mm ,(startHeight+steepHeight).mm]
      face_coords << [0, argSteepLength.mm ,(startHeight+pseHeight).mm]
      face_coords << [0, width.mm ,(startHeight+pseHeight).mm]
      face_coords << [0, width.mm ,0]

      #Draw face and extrude it
      newGroup = argContainer.entities.add_group
      newFace = newGroup.entities.add_face(face_coords)
      newFace.reverse!
      newFace.pushpull(argLength.mm)

      #Transform to OCL Element
      ocl_componentInstance = newGroup.to_component
      '''ocl_componentInstance.material = PH_SKP.getShader(@matName)'''

      #Convert to Definition
      ocl_componentDefinition = ocl_componentInstance.definition
      ocl_componentDefinition.name = ocl_CDname

    #Instanciate existing Windows Plate
    else
      transformation = Geom::Transformation.new([0,0,0])
      ocl_componentInstance = argContainer.entities.add_instance(ocl_componentDefinition, transformation)
      '''ocl_componentInstance.material = @matName'''
    end

    #Move at the right place
    ocl_componentInstance.move!(move)

    #Set OCL (Open Cut List) Shader
    ocl_componentInstance.material = PH_SKP.getShader("WindowPSE")

    return ocl_componentInstance
  end

  def draw_sunscreen(argLength:@length, argContainer:Sketchup.active_model, argWidth:200, argHeight:200, argOverHeight:@over_height)
    raise "argLength is not type of Numeric" unless argLength.is_a? Numeric
    raise "argContainer does note contain Sketchup::Entities to draw elements" unless argContainer.entities.class == Sketchup::Entities
    raise "argWidth is not type of Numeric" unless argWidth.is_a? Numeric
    raise "argHeight is not type of Numeric" unless argHeight.is_a? Numeric
    raise "argOverHeight is not type of Numeric" unless argOverHeight.is_a? Numeric

    #Define if the is an over height
    hasOverHeight = (argOverHeight <= 0 ? false : true)

    if argWidth != 0 and argHeight != 0
      #Extract Component Definition from name
      ocl_CDname = "SUNSCREEN_L#{argLength}W#{argWidth}H#{argHeight}"

      ##Add sunscreen options to nomenclature name
      if @bso or @vr or @over_height or @top
        ocl_CDname += "+"
        ocl_CDname += "SS|" if @bso or @vr
        ocl_CDname += "OH|" if @over_height
        ocl_CDname += "TOP|" if @top
      end

      ##Remove the last Sunscreen separator from name
      ocl_CDname = ocl_CDname[0...-1]


      #SUN SCREEN
      #Define and extract infos
      plateName = @matName #"TreplisT19"
      plateThickness = PH_CFG.materialsOCL[plateName]["Thickness"]
      studThickness = PH_CFG.materialsOCL[@matName]["Thickness"]
      separatorPlateThickness = PH_CFG.materialsOCL["SupportT10"]["Thickness"]

      #Generic Infos
      sunScreenL = argLength - 2*studThickness
      drawZcoord = argHeight + argOverHeight

      #Create the SunScreen Drawing Group
      sunScreenEntitiesToDelete = []

      sunScreenGrp = argContainer.entities.add_group
      sunScreenGrp.name = ocl_CDname
      sunScreenEntitiesToDelete << sunScreenGrp.entities.add_cpoint(Geom::Point3d.new)

      #Grab existing component definition
      ocl_componentInstance = nil

      #CREATE HPLATE
      #Define Component Name
      ocl_componentName = "#{ocl_CDname}_HPLATE"
      ocl_componentDefinition = Sketchup.active_model.definitions[ocl_componentName]

      #Create Entity
      if ocl_componentDefinition.nil?
        #Define face coordinates
        face_coords = []
        face_coords << [studThickness.mm, (@thickness - argWidth).mm, -drawZcoord.mm]
        face_coords << [studThickness.mm, @thickness.mm, -drawZcoord.mm]
        face_coords << [studThickness.mm, @thickness.mm, -(drawZcoord - plateThickness).mm]
        face_coords << [studThickness.mm, (@thickness - argWidth).mm, -(drawZcoord - plateThickness).mm]

        #Draw face and extrude it
        newGroup = sunScreenGrp.entities.add_group
        newFace = newGroup.entities.add_face(face_coords)
        newFace.pushpull(sunScreenL.mm)
        ocl_componentInstance = PH_SKP.toComponentInstance(newGroup, "#{ocl_CDname}_HPLATE")

      #Instanciate existing Windows Plate
      else
        transformation = Geom::Transformation.new([0,0,0])
        ocl_componentInstance = sunScreenGrp.entities.add_instance(ocl_componentDefinition, transformation)
      end

      #Set material
      ocl_componentInstance.material = PH_SKP.getShader(plateName)

      #CREATE VPLATE
      #Define Component Name
      ocl_componentName = "#{ocl_CDname}_VPLATE"
      ocl_componentDefinition = Sketchup.active_model.definitions[ocl_componentName]

      #Create Entity
      if ocl_componentDefinition.nil?
        #Define face coordinates
        face_coords = []
        face_coords << [studThickness.mm, (@thickness - argWidth).mm, -drawZcoord.mm]
        face_coords << [studThickness.mm, (@thickness - argWidth - studThickness).mm, -drawZcoord.mm]
        face_coords << [studThickness.mm, (@thickness - argWidth - studThickness).mm, -(drawZcoord-(argHeight-separatorPlateThickness)).mm]
        face_coords << [studThickness.mm, (@thickness - argWidth).mm, -(drawZcoord-(argHeight-separatorPlateThickness)).mm]

        #Draw face and extrude it
        newGroup = sunScreenGrp.entities.add_group
        newFace = newGroup.entities.add_face(face_coords)
        newFace.reverse!
        newFace.pushpull(sunScreenL.mm)
        ocl_componentInstance = PH_SKP.toComponentInstance(newGroup, "#{ocl_CDname}_VPLATE")

      #Instanciate existing Windows Plate
      else
        transformation = Geom::Transformation.new([0,0,0])
        ocl_componentInstance = sunScreenGrp.entities.add_instance(ocl_componentDefinition, transformation)
      end

      #Set material
      ocl_componentInstance.material = PH_SKP.getShader(plateName)

      #CREATE OVER HEIGHT
      if hasOverHeight
        #DRAW OVER HEIGHT HPLATE
        ocl_componentName = "#{ocl_CDname}_OH#HPLATE"
        ocl_componentDefinition = Sketchup.active_model.definitions[ocl_componentName]

        if ocl_componentDefinition.nil?
          #Define face coordinates
          face_coords = []
          face_coords << [studThickness.mm, 0, -argOverHeight.mm]
          face_coords << [studThickness.mm, argWidth.mm, -argOverHeight.mm]
          face_coords << [studThickness.mm, argWidth.mm, -(argOverHeight+separatorPlateThickness).mm]
          face_coords << [studThickness.mm, 0, -(argOverHeight+separatorPlateThickness).mm]

          #Draw face and extrude it
          newGroup = sunScreenGrp.entities.add_group
          newFace = newGroup.entities.add_face(face_coords)
          newFace.pushpull(-sunScreenL.mm)
          ocl_componentInstance = PH_SKP.toComponentInstance(newGroup, "#{ocl_CDname}_OH#HPLATE")

        #Instanciate existing Windows OHPlate
        else
          transformation = Geom::Transformation.new([0,0,0])
          ocl_componentInstance = sunScreenGrp.entities.add_instance(ocl_componentDefinition, transformation)
        end

        #Set material
        ocl_componentInstance.material = PH_SKP.getShader("SupportT10")

        #DRAW OVER HEIGHT VPLATE
        #Set height correction in case of OH and TOP requested
        topCorrection = @top ? separatorPlateThickness : 0

        #Define Component Name
        ocl_componentName = "#{ocl_CDname}_OH#VPLATE"
        ocl_componentDefinition = Sketchup.active_model.definitions[ocl_componentName]

        if ocl_componentDefinition.nil?
          #Define face coordinates
          face_coords = []
          face_coords << [studThickness.mm, 0, -topCorrection.mm]
          face_coords << [studThickness.mm, studThickness.mm, -topCorrection.mm]
          face_coords << [studThickness.mm, studThickness.mm, -argOverHeight.mm]
          face_coords << [studThickness.mm, 0, -argOverHeight.mm]

          #Draw face and extrude it
          newGroup = sunScreenGrp.entities.add_group
          newFace = newGroup.entities.add_face(face_coords)
          newFace.reverse!
          newFace.pushpull(sunScreenL.mm)
          ocl_componentInstance = PH_SKP.toComponentInstance(newGroup, "#{ocl_CDname}_OH#VPLATE")

        #Instanciate existing Windows OHPlate
        else
          transformation = Geom::Transformation.new([0,0,0])
          ocl_componentInstance = sunScreenGrp.entities.add_instance(ocl_componentDefinition, transformation)
        end

        #Set material
        ocl_componentInstance.material = PH_SKP.getShader(plateName)
      end

      #Move sunscreen entities at definitive position
      moveVector = Geom::Vector3d.new(0, 0, @height.mm)
      moveTransfo = Geom::Transformation.translation(moveVector)
      sunScreenGrp.transform!(moveTransfo)

      #Delete construction entities
      sunScreenEntitiesToDelete.each do |currentToDelete|
        currentToDelete.erase!
      end

      #CREATE SUNSCREEN TOP
      if @top
        ocl_componentName = "#{ocl_CDname}_TOP"
        ocl_componentDefinition = Sketchup.active_model.definitions[ocl_componentName]

        if ocl_componentDefinition.nil?
          #Define face coordinates
          face_coords = []
          face_coords << [studThickness.mm, 0, 0]
          face_coords << [studThickness.mm, @thickness.mm, 0]
          face_coords << [studThickness.mm, @thickness.mm, -separatorPlateThickness.mm]
          face_coords << [studThickness.mm, 0, -separatorPlateThickness.mm]

          #Draw face and extrude it
          newGroup = sunScreenGrp.entities.add_group
          newFace = newGroup.entities.add_face(face_coords)
          newFace.pushpull(-sunScreenL.mm)
          ocl_componentInstance = PH_SKP.toComponentInstance(newGroup, ocl_componentName)

        #Instanciate existing Windows OHPlate
        else
          transformation = Geom::Transformation.new([0,0,0])
          ocl_componentInstance = sunScreenGrp.entities.add_instance(ocl_componentDefinition, transformation)
        end

        #Set material
        ocl_componentInstance.material = PH_SKP.getShader("SupportT10")
      end
    end
  end

  def draw_frame_pse(argLength:@length, argContainer:Sketchup.active_model, argThickness:@pse[:T], argVWidth:@pse[:VW], argHWidth:@pse[:HW], argOffset:@offset, argStudMatName:@matName, argFontDistance:200, argAltitude:PH_CFG.materialsOCL["SupportT10"]["Thickness"]+48)
    raise "argLength is not type of Numeric" unless argLength.is_a? Numeric
    raise "argContainer does note contain Sketchup::Entities to draw elements" unless argContainer.entities.class == Sketchup::Entities
    raise "argThickness is not type of Numeric" unless argThickness.is_a? Numeric
    raise "argVWidth is not type of Numeric" unless argVWidth.is_a? Numeric
    raise "argHWidth is not type of Numeric" unless argHWidth.is_a? Numeric
    raise "argOffset is not type of Numeric" unless argOffset.is_a? Numeric
    #raise "argSideDistance is not type of Numeric" unless argSideDistance.is_a? Numeric
    raise "argStudMatName is not type of String" unless argStudMatName.is_a? String
    raise "argFontDistance is not type of Numeric" unless argFontDistance.is_a? Numeric
    raise "argAltitude is not type of Numeric" unless argAltitude.is_a? Numeric

    componentInstances =[]
    argSideDistance = PH_CFG.materialsOCL["TreplisT19"]["Thickness"]+@offset

    #CREATE HPSE FRAME
    #Setup face coordinates
    frame_height = @height - (200 + @over_height)
    frame_topPosition = frame_height - argOffset
    frame_length = @length - 2*argSideDistance

    objCoordinates = {
      "Y" => [0, argThickness],
      "Z" => [0, argHWidth],
      "X" => [0, nil],
    }

    #Generate BOTTOM component
    ##Set position placement transformation
    moveVector = Geom::Vector3d.new(argSideDistance.mm, argFontDistance.mm, argAltitude.mm)
    moveTransfo = Geom::Transformation.translation(moveVector)

    ##Generate OBJ OCL component
    ocl_CDname = "FRAME PSE H_L#{argLength}T#{argThickness}|V#{argVWidth}H#{argHWidth}"
    componentInstances << PH_SKP.drawOBJ(objCoordinates, frame_length, argOBJName:"FRAME PSE_Bottom", argCDname:ocl_CDname, argContainer:argContainer)
    componentInstances[-1].move!(moveTransfo)

    #Generate TOP component
    ##Set position placement transformation
    moveVector = Geom::Vector3d.new(argSideDistance.mm, argFontDistance.mm, (frame_topPosition-argHWidth).mm)
    moveTransfo = Geom::Transformation.translation(moveVector)

    ##Generate OBJ OCL component
    ocl_CDname = "FRAME PSE H_L#{argLength}T#{argThickness}|V#{argVWidth}H#{argHWidth}"
    componentInstances << PH_SKP.drawOBJ(objCoordinates, frame_length, argOBJName:"FRAME PSE_Bottom", argCDname:ocl_CDname, argContainer:argContainer)
    componentInstances[-1].move!(moveTransfo)

    #CREATE VPSE FRAME
    #Setup face coordinates
    pseVheight =(frame_height - argAltitude - 2*argHWidth - argOffset)

    objCoordinates = {
      "Y" => [0, argThickness],
      "X" => [0, argVWidth],
      "Z" => [0, nil],
    }

    #Generate LEFT component
    ##Set position placement transformation
    moveVector = Geom::Vector3d.new(argSideDistance.mm, argFontDistance.mm, (argAltitude+argHWidth).mm)
    moveTransfo = Geom::Transformation.translation(moveVector)

    ##Generate OBJ OCL component
    ocl_CDname = "FRAME PSE V_L#{argLength}T#{argThickness}|V#{argVWidth}H#{argHWidth}"
    componentInstances << PH_SKP.drawOBJ(objCoordinates, -pseVheight, argOBJName:"FRAME PSE_Left", argCDname:ocl_CDname, argContainer:argContainer)
    componentInstances[-1].move!(moveTransfo)

    #Generate RIGHT component
    ##Set position placement transformation
    moveVector = Geom::Vector3d.new((@length-(argSideDistance+argVWidth)).mm, argFontDistance.mm, (argAltitude+argHWidth).mm)
    moveTransfo = Geom::Transformation.translation(moveVector)

    ##Generate OBJ OCL component
    ocl_CDname = "FRAME PSE V_L#{argLength}T#{argThickness}|V#{argVWidth}H#{argHWidth}"
    componentInstances << PH_SKP.drawOBJ(objCoordinates, -pseVheight, argOBJName:"FRAME PSE_Right", argCDname:ocl_CDname, argContainer:argContainer)
    componentInstances[-1].move!(moveTransfo)

    #Set components materiel generated for OCL
    componentInstances.each{|currentInstance| currentInstance.material = PH_SKP.getShader("FramePSE")}
  end

  def to_s
    return @id
  end
end