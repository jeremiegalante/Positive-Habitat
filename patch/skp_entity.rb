#EXTEND Sketchup::Entity CLASS
class Sketchup::Entity
  def self.getWorldPosition
    #Extract the world position from the world matrix
    worldPosition = PH::CornerFrame.getWorldMatrix(self)

    #Convert to mm distance
    worldPosition = worldPosition.to_a[12..14].collect{|v| v.to_mm.to_i}

    return worldPosition
  end

  def self.getWorldMatrix
    #Extract the world matrix from path
    path = PH::CornerFrame.getEntityPath(self)
    worldMatrix = path[-1].transformation

    return worldMatrix
  end

  def getEntityPath
    currentParent = self
    path = []

    #Build the path
    while currentParent.class != Sketchup::Model
      #Store the active parent to the path
      path << currentParent

      #Jump to the next parent
      currentParent = currentParent.parent

      #In case of ComponentDefinition connect to the instance
      if currentParent.class == Sketchup::ComponentDefinition
        currentParent = currentParent.instances[-1]
      end
    end

    return path.reverse
  end

  def getConnexionPointWC(arg_leftSide:true, arg_backSide:true, arg_bottomSide:false, argRotationAngle:0)
    #raise "arg_entity is not type of Sketchup::Drawingelement" unless arg_entity.class <= Sketchup::Drawingelement
    raise "arg_leftSide is not type of Boolean" unless [true, false].include? arg_leftSide
    raise "argRotationAngle is not type of Numeric" unless argRotationAngle.class <= Numeric

    #Apply connexion modifications according rotation
    unless argRotationAngle.between?(-90, 90)
      arg_leftSide = !arg_leftSide
      arg_backSide = !arg_backSide
    end

    #Define the requested corner values
    bbCorner = [arg_leftSide ? 0 : 1, arg_backSide ? 1 : 0, arg_bottomSide ? 0 : 1]

    '''
    https://ruby.sketchup.com/Geom/BoundingBox.html#corner-instance_method
      0 = [0, 0, 0] (left front bottom)
      1 = [1, 0, 0] (right front bottom)
      2 = [0, 1, 0] (left back bottom)
      3 = [1, 1, 0] (right back bottom)
      4 = [0, 0, 1] (left front top)
      5 = [1, 0, 1] (right front top)
      6 = [0, 1, 1] (left back top)
      7 = [1, 1, 1] (right back top)
    '''
    #Get the requested corner index number
    bbIndex = nil
    case bbCorner
      when [0,0,0]; bbIndex = 0
      when [1,0,0]; bbIndex = 1
      when [0,1,0]; bbIndex = 2
      when [1,1,0]; bbIndex = 3
      when [0,0,1]; bbIndex = 4
      when [1,0,1]; bbIndex = 5
      when [0,1,1]; bbIndex = 6
      when [1,1,1]; bbIndex = 7
    end

    return self.bounds.corner(bbIndex).to_a.collect{|coord| coord.to_mm}
  end
end