#EXTEND Sketchup::Entity CLASS
class Sketchup::Drawingelement
  def getConnexionPoint(arg_leftSide:true, arg_frontSide:true, arg_bottomSide:true, argRotationAngle:0)
    raise "arg_leftSide is not type of Boolean" unless [true, false].include? arg_leftSide
    raise "arg_frontSide is not type of Boolean" unless [true, false].include? arg_frontSide
    raise "arg_bottomSide is not type of Boolean" unless [true, false].include? arg_bottomSide
    raise "argRotationAngle is not type of Numeric" unless argRotationAngle.class <= Numeric
  
    #Apply connexion modifications according rotation
    unless argRotationAngle.between?(-90, 90)
      arg_leftSide = !arg_leftSide
      arg_frontSide = !  arg_frontSide
    end
  
    #Define the requested corner values
    bbCorner = [arg_leftSide ? 0 : 1,   arg_frontSide ? 0 : 1, arg_bottomSide ? 0 : 1]
  
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