'''
load "E:/#GITHUB/PH/Toolbar/PH_Toolbar.rb"
'''

#Load Sketchup Requires
require "sketchup.rb"

#Load PH Requires
require_relative '../PH'
require_relative "../PH_PreCadre"


#PH TOOLBAR
toolbarPH = UI::Toolbar.new("Frame") {
  #Reload the Frame RB source file
  load '../Frame.rb'
}

#PRE-CADRE COMMANDS
#Generate Pré-Cadre drawing query
cmd = UI::Command.new("Draw") {
  #ID DEFINITION
  ##ID Global
  idINFO = {"ID": "NUM POSTE [Integer]",
            "WALL|T": "Epaisseur du Mur [Decimal|400mm]",
            "WALL|FD": "Distance face extérieure [Decimal|200mm]"}

  ##ID des Matériaux
  idMAT = {"MAT|OSS": "Matière Ossature [String|Nom]",
           "MAT|FIN": "Matière Finition"}

  ##ID du Pré-Cadre
  idFRAME = {"FRAME|L": "Longueur du Pré-Cadre [Decimal|mm]",
             "FRAME|H": "Hauteur du Pré-Cadre  [Decimal|mm]",
             "FRAME|T": "Epaisseur PSE du Pré-Cadre [Decimal|78mm]",
             "FRAME|OFF": "Espace du Jeu Compribande du Pré-Cadre [Decimal|5mm]"}

  ##ID Volet Roulant
  idVR = {"H":"Hauteur Volet Roulant [Decimal|200mm]", #
          "VH":"Longueur Volet Horizontal [Decimal|200mm]", #
          "VV":"Longueur Volet Vertical [Decimal|160mm]"}

  ##ID Sur-Hauteur
  idOH = {"OH|H":"Valeur Sur-Hauteur [Decimal|mm]",
          "OH|OFF":"Retrait Montants de la Sur-Hauteur [Decimal|3mm]"}

  ##ID Options à activer
  idOPTIONS = {"VR":"Activation Coffre Vollet [X]",
               "CS":"Activation Châpeau Supérieur [X]",
               "BA":"Activation Bois/Alu [X]"}

  #Request the Frame Nomenclature
  ids = idINFO.keys + idMAT.keys + idFRAME.keys + idVR.keys + idOH.keys + idOPTIONS.keys
  prompts = idINFO.values + idMAT.values + idFRAME.values + idVR.values + idOH.values + idOPTIONS.values
  defaults = ["0", "400", "200", "TreplisT19", "", "3000", "2500", "50", "5", "200", "200", "160", "0", "3", "X", "X", "X"]
  defaultAnswerArray = [rand(100..200).to_s, "400", "200", "TreplisT19", "", "", "", "", "5", "200", "200", "160", "0", "3", "", "", ""]
  answersArray = UI.inputbox(prompts, defaults, "Paramètres du Pré-Cadre.")

  #Convert String values to Integer if possible
  answersArray.collect! do |originalValue|
    (originalValue == originalValue.to_i.to_s) ? originalValue.to_i : originalValue
  end

  #Merge answers with default values
  answersMerge = []
  answersArray.each_with_index do |currentVal, currentIndex|
    answersMerge[currentIndex] = (currentVal != "") ? currentVal : defaultAnswerArray[currentIndex]
  end

  #Split Hash into sections
  def createHirarchy(argKeys, argValue)
    raise "argKeys is not type of Array" unless argKeys.is_a? Array

    hashResult = {}
    currentKey = ""
    currentValue = {}

    argKeys.each_with_index do |key, index|
      #Update the current key value
      currentKey += "[\"#{key}\"]"

      #Update the value if reaching the leaf to apply value
      if index == argKeys.length-1
        currentValue = argValue
        currentValue = "'#{currentValue}'" if currentValue.is_a? String
      end

      stepExe = "hashResult#{currentKey} = #{currentValue}"
      eval(stepExe)
    end

    return hashResult
  end

  #Convert to hash answers and split each param ino sections
  answersHash = Hash[*ids.zip(answersMerge).flatten]
  preCadreHash = {}

  answersHash.each_pair do |currentParam, currentValue|
    #Convert Symbols to String values
    currentParam = currentParam.to_s if !currentParam.is_a? String

    #In case of nested param
    stepHash = createHirarchy(currentParam.split("|"), currentValue)
    preCadreHash.merge!(stepHash)
  end
  puts preCadreHash

  #Generate Drawing
  pcPoste = PH::PreCadre.new(preCadreHash)
  pcPoste.draw
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