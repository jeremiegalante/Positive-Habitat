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
  #Request the Frame Nomenclature
  ids = ["ID", "WT", "MATO", "MATF", "FL", "FH", "FSH", "FC", "FD", "FE", "oVR", "oCS", "oBA", "oRJ"]
  prompts = ["NUM POSTE [#{ids[0]}]",
             "MUR_Epaisseur [#{ids[1]}]",
             "MATIÈRE_Ossature [#{ids[2]}]",
             "MATIÈRE_Finition [#{ids[3]}]",
             "FENÊTRE_Longueur [#{ids[4]}]",
             "FENÊTRE_Hauteur [#{ids[5]}]",
             "FENÊTRE_Sur-Hauteur [#{ids[6]}]",
             "FENÊTRE_Jeu Compribande [#{ids[7]}]",
             "FENÊTRE_Distance Mur Extérieur [#{ids[8]}]",
             "FENÊTRE_Epaisseur [#{ids[9]}]",
             "OPTION_Coffre Vollet [#{ids[10]}]",
             "OPTION_Châpeau Supérieur [#{ids[11]}]",
             "OPTION_Bois/Alu [#{ids[12]}]",
             "OPTION_Avancée Renfort Joues [#{ids[13]}]"]
  defaults = ["0", "400", "TreplisT19","", "3000", "2000", "0", "5", "200", "78", "X", "X", "X", "54"]
  answersArray = UI.inputbox(prompts, defaults, "Paramètres du PréCadre.")

  #Convert to hash answers
  answersHash = Hash[ids.zip(answersArray)]

  #Generate Drawing
  pcPoste = PH::PreCadre.new(answersHash)
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