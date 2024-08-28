#EXTEND Sketchup::Entity CLASS
class Sketchup::AttributeDictionary
  def storeFrameData(argFrame, argName, argValue)
    raise "argFrame is not type of Sketchup::Entity" unless argFrame.class <= Sketchup::Entity
    raise "argName is not type of String" unless argName.class == String

    #In case of a hash parse the sub content
    if argValue.class == Hash
      argValue.each do |currentKey, currentValue|
        newName = argName + "|#{currentKey}"
        self.storeFrameData(argFrame, newName, currentValue)
      end

    #Store the single data
    else
      argFrame.set_attribute("DATA", argName, argValue)
    end
  end

  def getData(argNames)
    raise "argNames is not type of Array" unless argNames.include?.class == Array
    argNames.each{|current| raise "current is not type of String" unless current.class == String}

    fullName = nil
    argNames.each{|subName| fullName.nil? ? fullName = subName : fullName += "|#{subName}"}

    return self[fullName]
  end
end