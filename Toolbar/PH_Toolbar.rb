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
require_relative '../FileObserver'


#DEFINE POSTES
existingPostes = []

#NOMENCLATURE DEFINITION
idSPLIT = {"NA1": "INFOS BASIQUES --------------------------------------------------------------",
           "NA2": "COFFRET VOLET ---------------------------------------------------------------",
           "NA3": "OPTIONS ------------------------------------------------------------------------",
           "NA4": "AUTRES -------------------------------------------------------------------------"}
defaultSPLIT = ["-------------------------------"]

##ID Global
idINFO = {"ID": "NUM POSTE [Integer]",
          "WALL|T": "Epaisseur du Mur [Decimal|400mm]",
          "WALL|FD": "Distance face extérieure [Decimal|200mm]",
          "WALL|RS": "Renfort de montants [Decimal|54mm]"}
defaultINFO = ["0", "400", "200", "54"]

##ID des Matériaux
idMAT = {"MAT|OSS": "Matière Ossature [String|Nom]",
         "MAT|FIN": "Matière Finition [String|Nom]"}
defaultMAT = ["3PlisT19", "3PlisDouglasT19"]

##ID du Pré-Cadre
idFRAME = {"FRAME|L": "Longueur du Pré-Cadre [Decimal|mm]",
           "FRAME|H": "Hauteur du Pré-Cadre  [Decimal|mm]"}
defaultFRAME = ["3000", "2500"]

##ID Coffret Volet
idCV = {"CV|H":"Hauteur Coffret/Volet [Decimal|180mm]",
        "CV|L":"Largeur de devant le Coffret/Volet [Decimal|200mm]",
        "CV|VH":"Profonfondeur Coffret/Volet [Decimal|200mm]"}
defaultCV = ["180", "200", "180"]

##ID Sur-Hauteur
idOH = {"OH|H":"Sur-Hauteur Coffret/Volet [Decimal|mm]",
        "OH|OFF":"Retrait Montants de la Sur-Hauteur [Decimal|3mm]"}
defaultOH = ["0", "3"]

##ID Options à activer
idOPTIONS = {"CV?":"Activation Coffret Volet [X]",
             "CS?":"Activation Châpeau Supérieur [X]",
             "BA?":"Activation Bois/Alu [X]",
             "BAS?":"Activation du Support en bas [X]"}
defaultOPTIONS = ["X", "", "X", "X"]

##Infos secondaires
idSECOND = {"FRAME|T": "Epaisseur PSE du Pré-Cadre [Decimal|78mm]",
            "FRAME|OFF": "Espace du Jeu Compribande du Pré-Cadre [Decimal|5mm]",
            "MAT|OFF": "Écart de hauteur montant Ossature et Finition [Decimal|10mm]",
            "MAT|GAP": "Écart entre la Finition et le Pré-Cadre si Bois/Alu [Decimal|17mm]",
            "CV|OFF": "Décalage Coffret Volet Vert et Montant sans CS [Decimal|3mm]"}
defaultSECOND = ["78", "5", "10", "17", "3"]

#PH TOOLBAR
toolbarPH = UI::Toolbar.new("Frame") {}

#PRE-CADRE COMMANDS
#Generate Pré-Cadre drawing query
drawFrameFromMenu = UI::Command.new("Draw") {
  #Request the Frame Nomenclature
  ids = idSPLIT.keys[0..0] + idINFO.keys + idMAT.keys + idFRAME.keys + idSPLIT.keys[1..1] + idCV.keys + idOH.keys + idSPLIT.keys[2..2] + idOPTIONS.keys + idSPLIT.keys[3..3] + idSECOND.keys
  prompts = idSPLIT.values[0..0] + idINFO.values + idMAT.values + idFRAME.values + idSPLIT.values[1..1] + idCV.values + idOH.values + idSPLIT.values[2..2] + idOPTIONS.values + idSPLIT.values[3..3] + idSECOND.values
  defaults = defaultSPLIT + defaultINFO + defaultMAT + defaultFRAME + defaultSPLIT + defaultCV + defaultOH + defaultSPLIT + defaultOPTIONS + defaultSPLIT + defaultSECOND
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