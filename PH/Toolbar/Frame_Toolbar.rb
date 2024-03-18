'''
load "E:/#Positive Habitat/PH/Toolbar/Frame_Toolbar.rb"
'''
#Load Sketchup Requires
require "sketchup.rb"

#Load PH Requires
require_relative "../Frame.rb"


#FRAME TOOLBAR
tbFrame = UI::Toolbar.new("Frame") {
  #Reload the Frame RB source file
  load '../Frame.rb'
}

#COMMANDS
#Generate Frame drawing query
cmd = UI::Command.new("Draw") {
  #Request the Frame Nomenclature
  prompts = ["Ossature Mat [OSS]",
             "FRAME Length [L]",
             "FRAME Thickness [T]",
             "FRAME Height [H]",
             "FRAME Over Height [OH]",
             "FRAME PSE Offset [OFF]",
             "FRAME PSE_Thickness [PT]",
             "FRAME PSE_HWidth [PHW]",
             "FRAME PSE_VWidth [PVW]",
             "OPTION_SunScreen [BSO]",
             "OPTION_Metal Seated [MET]",
             "OPTION_Top Covering [TOP]"]
  defaults = ["TreplisT19","2500", "400", "3000", "0", "5", "78", "90","52", "X", "X", ""]
  answersArray = UI.inputbox(prompts, defaults, "Frame Parameters and Options.")

  #Convert to hash answers
  answersHash = {}
  answersArray.each_with_index do |ans_value, ans_index|
    #Extract value Key
    ans_title = prompts[ans_index]
    key = ans_title[ans_title.index("[")+1...-1]

    #Store requested value for key
    puts "#{key} - #{ans_value}"
    answersHash[key] = ans_value
  end

  #Generate Drawing
  frame = Frame.new(argNomenclature=answersHash)
  frame.draw
}

#Command Specs
tbFrame = tbFrame.add_item cmd
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
tbFrame = tbFrame.add_item cmd
tbFrame.show