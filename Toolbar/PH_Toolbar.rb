'''
load "E:/#GITHUB/PH/Toolbar/PH_Toolbar.rb"
load "D:/_GITHUB/PH/Toolbar/PH_Toolbar.rb"

DOC YARD https://yardoc.org/
'''

#Load Sketchup Requires
require "sketchup.rb"

#Load PH Requires
require_relative '../PH'
require_relative '../patch/hash'
require_relative '../Frame'


#NOMENCLATURE DEFINITION
##ID Global
idINFO = {"ID": "NUM POSTE [Integer]",
          "WALL|T": "Epaisseur du Mur [Decimal|400mm]",
          "WALL|FD": "Distance face extérieure [Decimal|200mm]",
          "WALL|RS": "Renfort de montants [Decimal|54mm]"}
defaultINFO = ["0", "400", "200", "54"]

##ID des Matériaux
idMAT = {"MAT|OSS": "Matière Ossature [String|Nom]",
         "MAT|FIN": "Matière Finition"}
defaultMAT = ["TreplisT19", ""]

##ID du Pré-Cadre
idFRAME = {"FRAME|L": "Longueur du Pré-Cadre [Decimal|mm]",
           "FRAME|H": "Hauteur du Pré-Cadre  [Decimal|mm]",
           "FRAME|T": "Epaisseur PSE du Pré-Cadre [Decimal|78mm]",
           "FRAME|OFF": "Espace du Jeu Compribande du Pré-Cadre [Decimal|5mm]"}
defaultFRAME = ["3000", "2500", "78", "5"]

##ID Volet Roulant
idVR = {"VR|H":"Hauteur Volet Roulant [Decimal|180mm]", #
        "VR|VH":"Longueur Volet Horizontal [Decimal|200mm]", #
        "VR|VV":"Longueur Volet Vertical [Decimal|180mm]",
        "VR|OFF":"Marge hauteur Volet Vertical sans Châpeau Supérieur [Decimal|3mm]"}
defaultVR = ["180", "200", "180", "3"]

##ID Sur-Hauteur
idOH = {"OH|H":"Valeur Sur-Hauteur [Decimal|mm]",
        "OH|OFF":"Retrait Montants de la Sur-Hauteur [Decimal|3mm]"}
defaultOH = ["0", "3"]

##ID Options à activer
idOPTIONS = {"VR?":"Activation Coffre Vollet [X]",
             "CS?":"Activation Châpeau Supérieur [X]",
             "BA?":"Activation Bois/Alu [X]",
             "BAS?": "Activation du Support en bas  [X]"}
defaultOPTIONS = ["X", "X", "X", "X"]

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
      currentValue = argValue
      currentValue = "'#{currentValue}'" if currentValue.is_a? String
    end

    stepExe = "hashResult#{currentKey} = #{currentValue}"
    eval(stepExe)
  end

  return hashResult
end

# Method to generate a Hash composed of Nomenclature IDs with values.
# @return [Hash] the ID Hash for Frame generation.
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

#PH TOOLBAR
toolbarPH = UI::Toolbar.new("Frame") {

}

#PRE-CADRE COMMANDS
#Generate Pré-Cadre drawing query
cmd = UI::Command.new("Draw") {
  '''
  #ID DEFINITION
  ##ID Global
  idINFO = {"ID": "NUM POSTE [Integer]",
            "WALL|T": "Epaisseur du Mur [Decimal|400mm]",
            "WALL|FD": "Distance face extérieure [Decimal|200mm]",
            "WALL|RS": "Renfort de montants [Decimal|54mm]"}
  defaultINFO = ["0", "400", "200", "54"]

  ##ID des Matériaux
  idMAT = {"MAT|OSS": "Matière Ossature [String|Nom]",
           "MAT|FIN": "Matière Finition"}
  defaultMAT = ["TreplisT19", ""]

  ##ID du Pré-Cadre
  idFRAME = {"FRAME|L": "Longueur du Pré-Cadre [Decimal|mm]",
             "FRAME|H": "Hauteur du Pré-Cadre  [Decimal|mm]",
             "FRAME|T": "Epaisseur PSE du Pré-Cadre [Decimal|78mm]",
             "FRAME|OFF": "Espace du Jeu Compribande du Pré-Cadre [Decimal|5mm]"}
  defaultFRAME = ["3000", "2500", "78", "5"]

  ##ID Volet Roulant
  idVR = {"VR|H":"Hauteur Volet Roulant [Decimal|180mm]", #
          "VR|VH":"Longueur Volet Horizontal [Decimal|200mm]", #
          "VR|VV":"Longueur Volet Vertical [Decimal|180mm]",
          "VR|OFF":"Marge hauteur Volet Vertical sans Châpeau Supérieur [Decimal|3mm]"}
  defaultVR = ["180", "200", "180", "3"]

  ##ID Sur-Hauteur
  idOH = {"OH|H":"Valeur Sur-Hauteur [Decimal|mm]",
          "OH|OFF":"Retrait Montants de la Sur-Hauteur [Decimal|3mm]"}
  defaultOH = ["0", "3"]

  ##ID Options à activer
  idOPTIONS = {"VR?":"Activation Coffre Vollet [X]",
               "CS?":"Activation Châpeau Supérieur [X]",
               "BA?":"Activation Bois/Alu [X]",
               "BAS?": "Activation du Support en bas  [X]"}
  defaultOPTIONS = ["X", "X", "X", "X"]
  '''

  #Request the Frame Nomenclature
  ids = idINFO.keys + idMAT.keys + idFRAME.keys + idVR.keys + idOH.keys + idOPTIONS.keys
  prompts = idINFO.values + idMAT.values + idFRAME.values + idVR.values + idOH.values + idOPTIONS.values
  defaults = defaultINFO + defaultMAT + defaultFRAME + defaultVR + defaultOH + defaultOPTIONS
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

  #Generate Drawing
  newFrame = PH::Frame.new(frameData)
  newFrame.draw
}

#Command Specs
toolbarPH = toolbarPH.add_item cmd
icon_path = "#{__dir__}/Icons/Frame_Toolbar/frame window 256x256.png"
cmd.small_icon = icon_path
cmd.large_icon = icon_path
cmd.status_bar_text = "NOMENCLATURE commence par 'FRAME_'
SECTIONS sont séparées par un character '_'.
DIMENSIONS sont exprimées en mm.
\n#SECTION PSE:
   - Txx: Largeur/Epaisseur.
   - HWxx: Hauteur des barres horizontales.
   - VWxx: Largeur des barres verticales.
\n#SECTION DIMENSIONS:
   - Lxxxx: Longeur ext du précadre.
   - Txxx: Epaisseur du mur.
   - Hxxxx: Hauteur du précadre.
   - OHxxx: Sur-hauteur du précadre.
   - OFFxx: Distance pour separer le PSE de l'ossature bois (compribande fenetre).
\n#SECTION OPTIONS séparées par un '|':
   - BSO: Présence d'un VR ou BSO necessitant une réservation.
   - MET: Appuis/Bavette de Fenêtre.
   - TOP: Couverture au-dessus du précadre.
\n#SECTION MAT OSSATURE"
cmd.tooltip = "FRAME Nom Nomenclature"
cmd.small_icon = "Frame_Icons_[24x24]_Frame Window.png"
cmd.large_icon = "Frame_Icons_[24x24]_Frame Window.png"

#Add the Frame Command
toolbarPH = toolbarPH.add_item cmd
toolbarPH.show