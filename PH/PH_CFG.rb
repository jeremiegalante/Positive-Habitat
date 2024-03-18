#load "E:/#Positive Habitat/SU2023/MODULE/PH_CFG.rb"
#Load generic Requires
require 'json'

module PH_CFG
  #@MODULE VARIABLE
  @@configFiles = {
    "materialsOCL":"#{__dir__}/materialsOCL.json"
  }

  #MODULE ACCESSORS
  attr_reader :configFiles

  #MODULE METHODS
  def self.loadJSON(argJSONfilePath)
    raise "argJSONfilePath is not type of String" unless argJSONfilePath.class == String

    #Extract CFG data
    file = File.read(argJSONfilePath)
    json_data = JSON.parse(file)

    return json_data
  end

  def self.loadConfigs
    @@configFiles.each_pair do |currentJSONkey, currentJSONfile|
      #Create instance variable with JSON content
      eval("@@#{currentJSONkey}=#{loadJSON(currentJSONfile)}")

      #Create reading accessor
      eval('''def self.'''+currentJSONkey.to_s+'''; @@'''+currentJSONkey.to_s+'''; end''')
    end

  end
end

PH_CFG.loadConfigs