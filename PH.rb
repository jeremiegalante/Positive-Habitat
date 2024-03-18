require "sketchup.rb"
require "extensions.rb"
require 'json'

PH_loader = SketchupExtension.new "PH Plugin", "PH/Toolbar/Frame_Toolbar.rb"
PH_loader.copyright= "Positive Habitat"
PH_loader.creator= "Jérémie Galante"
PH_loader.version = "0.12"
PH_loader.description = "Première version pour tester la constrction des Précadres corrigée"
Sketchup.register_extension PH_loader, true