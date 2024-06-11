'''
load "E:/#GITHUB/PH/Toolbar/PH_Toolbar.rb"
load "D:/_GITHUB/PH/Toolbar/PH_Toolbar.rb"

DOC YARD https://yardoc.org/
'''

#Load Sketchup Requires
require "sketchup.rb"
require 'csv'

#Load PH Requires
require_relative '../PH'
require_relative '../patch/hash'
require_relative '../Frame'
require_relative '../CornerFrame'
require_relative '../FileObserver'


#DEFINE POSTES
existingPostes = []

#NOMENCLATURE DEFINITION
idSPLIT = {"NA1": "MENUISERIE -----------------------------------------------",
           "NA2": "COFFRE VOLET --------------------------------------------",
           "NA3": "FINITIONS -------------------------------------------------",
           "NA4": "OPTIONS ---------------------------------------------------"}
defaultSPLIT = ["-------------------------------"]

##SECTION MENUISERIE
idMEN = {"ID": "Numéro de Poste",
         "FRAME|L": "Longueur Menuiserie [mm]",
         "FRAME|H": "Hauteur Menuiserie  [mm]",
         "FRAME|CMP": "Espace Compribande Côté+Haut [mm]",
         "FRAME|CMPB": "Espace Compribande Bas [mm]"}
defaultMEN = ["1", "1000", "2200", "5", "5"]

#SECTION COFFRE VOLLET
idCV = {"CV|H":"Hauteur Coffre Volet [mm]",
        "OH|H":"Sur-Hauteur Coffret/Volet [mm]",
        "OH|OFF":"Retrait Montants de la Sur-Hauteur [mm]",
        "CS?":"Activation Châpeau Supérieur [X]"}
defaultCV = ["180", "0", "2", ""]

#SECTION FINITIONS
idFIN = {"FIN?":"Activation Finition [X]",
         "FIN|EGAP":"Sur-Longueur extérieur Finition [mm]",
         "FIN|SGAP": "Écart entre Finition et Pré-Cadre si Bois/Alu [mm]",
         "FIN|VGAP": "Écart en hauteur Finition (Haut/Bas) [mm]",
         "FIN|UH":"Sous-Hauteur Finition [mm]",
         "BA?":"Activation Bois/Alu [X]"}
defaultFIN = ["X", "64", "17", "1", "30", "X"]

#SECTION OPTIONS
idOPTIONS = {"WALL|T": "Epaisseur du Mur [mm]",
             "WALL|FD": "Distance face extérieure [mm]",
             "FRAME|T": "Epaisseur cadre menuiserie [mm]",
             "MAT|OSS": "Matière Ossature",
             "MAT|FIN": "Matière Finition"}
defaultOPTIONS = ["400", "200", "78", "3PlisT19", "3PlisDouglasT19"]

#PH TOOLBAR
toolbarPH = UI::Toolbar.new("Frame") {}

#PRE-CADRE COMMANDS
#Generate Pré-Cadre drawing query
drawFrameFromMenu = UI::Command.new("Génération Pré-Cadre") {
  #Request the Frame Nomenclature
  ids = idSPLIT.keys[0..0] + idMEN.keys + idSPLIT.keys[1..1] + idCV.keys + idSPLIT.keys[2..2] + idFIN.keys + idSPLIT.keys[3..3] + idOPTIONS.keys
  prompts = idSPLIT.values[0..0] + idMEN.values + idSPLIT.values[1..1] + idCV.values + idSPLIT.values[2..2] + idFIN.values + idSPLIT.values[3..3] + idOPTIONS.values
  defaults = defaultSPLIT + defaultMEN + defaultSPLIT + defaultCV + defaultSPLIT + defaultFIN + defaultSPLIT + defaultOPTIONS
  answersArray = UI.inputbox(prompts, defaults, "Paramètres du Pré-Cadre.")

  #Convert String values to Integer if possible
  answersArray.collect! do |originalValue|
    (originalValue == originalValue.to_i.to_s) ? originalValue.to_i : originalValue
  end

  #Merge answers with default values
  answersMerge = []
  answersArray.each_with_index do |currentVal, currentIndex|
    originalVal = currentVal
    originalVal = defaults[currentIndex] if !ids[currentIndex].to_s.include?("?")
    answersMerge[currentIndex] = (currentVal != "") ? currentVal : originalVal
  end

  #Generate the Frame Hash Data
  frameData = genFrameDataHash(ids, answersMerge)
  frameData.keys.each{|del| frameData.delete(del) if del.include?("NA")}

  #Generate Drawing
  newFrame = PH::Frame.new(frameData)
  newFrame.draw
}

#Command Specs
iconsFolder = "#{__dir__}/Icons/"

toolbarPH = toolbarPH.add_item drawFrameFromMenu
iconName = "[24x24]_Frame Window.png"
drawFrameFromMenu.small_icon = "#{iconsFolder}#{iconName}"
drawFrameFromMenu.large_icon = "#{iconsFolder}#{iconName}"
drawFrameFromMenu.status_bar_text = ""
drawFrameFromMenu.tooltip = "FRAME Nom Nomenclature"
toolbarPH = toolbarPH.add_item drawFrameFromMenu

#FRAMES CSV COMMAND
#Generate Frame drawing from CSV parsing
drawFramesFromCSV = UI::Command.new("Draw FRAMEs from CSV") {
  #PARSE GENERIC CSV
  #Open the CSV file
  chosenCSV = UI.openpanel("Select the CSV file to generate the Frames", "C:/Program Files/SketchUp/SketchUp 2023/plugins/PH/PH_FRAME.csv", "CSV|*.csv||")
  #csvFile_path = "#{__dir__}/../PH_FRAME.csv"

  CSV.foreach(chosenCSV, :headers => true) do |csvRow|
    #Build te frame variables
    frameIDs = csvRow.collect {|item| item[0]}#[3..-3]
    frameValues = csvRow.collect {|item| item[1]}#[3..-3]
    frameValues.collect! {|val| val == val.to_i.to_s ? val.to_i : val}

    #Build the Frame Data
    nomenclatureData = genFrameDataHash(frameIDs, frameValues)
    nb = csvRow[0].to_i
    backNomID = nomenclatureData["ID"] #Backup ID

    #Draw the Frame
    nb.times do
      nomenclatureData["ID"] = backNomID #Restore ID
      newFrame = PH::Frame.new(nomenclatureData)
      newFrame.draw
    end
  end
}

#Command Specs
toolbarPH = toolbarPH.add_item drawFramesFromCSV
iconName = "[24x24]_Frame CSV.png"
drawFramesFromCSV.small_icon = "#{iconsFolder}#{iconName}"
drawFramesFromCSV.large_icon = "#{iconsFolder}#{iconName}"
drawFramesFromCSV.status_bar_text = "Remplacer le contenu du fichier 'PH_FRAME.csv' dans le dossier du Plugin PH."
drawFramesFromCSV.tooltip = "FRAME from CSV"
toolbarPH = toolbarPH.add_item drawFramesFromCSV


#PRE-CADRE ANGLE COMMANDS
#Generate Pré-Cadre Angle drawing query
drawFrameAngle = UI::Command.new("Draw Pré-Cadre Angle") {
  #ID Global
  idMAIN = {"ANGLE|POS": "Position de l'angle du retour",
            "ANGLE|VAL": "Valeur Trigonometrique de l'angle du retour [°]",
            "OSS|W": "Largeur du poteau d'Angle de renfort [mm]",
            "OSS|ALL": "Hauteur d'Allège sous la fenêtre [mm]",
            "OSS|LIN": "Hauteur de Linteau au-dessus de la fenêtre [mm]",
            "DOOR?":"Activation d'une porte axe principal opposé à l'Angle [X]"}
  defaultMAIN = ["G|D", "90","120", "1000", "450", "X"]

  #Request the Corner Frame Nomenclature
  ids = idMAIN.keys
  prompts = idMAIN.values
  defaults = defaultMAIN
  answersArray = UI.inputbox(prompts, defaults, "Paramètres du Pré-Cadre d'Angle.")

  #Convert String values to Integer if possible
  answersArray.collect! do |originalValue|
    (originalValue == originalValue.to_i.to_s) ? originalValue.to_i : originalValue
  end

  #Generate the Frame Hash Data
  frameData = genFrameDataHash(ids, answersArray)
  frameData.keys.each{|del| frameData.delete(del) if del.include?("NA")}

  #Generate Drawing
  newCorner = PH::CornerFrame.new(frameData)
  newCorner.assemble
}

#Command Specs
toolbarPH = toolbarPH.add_item drawFrameAngle
iconName = "[24x24]_Angle Window.png"
drawFrameAngle.small_icon = "#{iconsFolder}#{iconName}"
drawFrameAngle.large_icon = "#{iconsFolder}#{iconName}"
drawFrameAngle.status_bar_text = "Combiner les PréCadres selectionnés en PréCadres d'angle."
drawFrameAngle.tooltip = "ANGLE FRAME"
toolbarPH = toolbarPH.add_item drawFrameAngle


#GENERATE THE TOOLBAR
toolbarPH.show


#ADDITIVE METHODS
# Method to generate a Hash composed of IDs hashes encapsulated storing the value at the leaf element.
# @param argIDs [Array] the array containing the list of IDs.
# @param argValue [N/A] the value to be stored at the Hash leaf.
# @return [Hash] the Hash of IDs encapsulated.
# @!scope instance
# @version 0.11.0
# @since 0.11.0
def genEncapsulatedHash(argIDs, argValue)
  raise "argIDs is not type of Array" unless argIDs.is_a? Array

  hashResult = {}
  currentKey = ""
  currentValue = {}

  argIDs.each_with_index do |key, index|
    #Update the current key value
    currentKey += "[\"#{key}\"]"

    #Update the value if reaching the leaf to apply value
    if index == argIDs.length-1
      currentValue = argValue.nil? ? "''" : argValue
      currentValue = "'#{currentValue}'" if currentValue.is_a? String
    end

    stepExe = "hashResult#{currentKey} = #{currentValue}"
    eval(stepExe)
  end

  return hashResult
end

# Method to generate a Hash composed of Nomenclature IDs with values.
# @param argIDs [Array] the array containing the list of IDs.
# @param argValues [N/A] the array containing the list of values.
# @return [Hash] the Hash data for Frame generation.
# @!scope instance
# @version 0.11.0
# @since 0.11.0
def genFrameDataHash(argIDs, argValues)
  raise "argIDs is not type of Array" unless argIDs.is_a? Array
  #argIDs.each_with_index{|id, idx| raise "the argIDs[#{idx}] item is not a valid item type of String" unless id.is_a? String}
  raise "argValues is not type of Array" unless argValues.is_a? Array

  #Convert to hash answers and split each param ino sections
  answersHash = Hash[*argIDs.zip(argValues).flatten]
  frameHash = {}

  answersHash.each_pair do |currentParam, currentValue|
    #Convert Symbols to String values
    currentParam = currentParam.to_s if !currentParam.is_a? String

    #In case of nested param
    stepHash = genEncapsulatedHash(currentParam.split("|"), currentValue)
    frameHash.merge_recursively!(stepHash)
  end

  return frameHash
end