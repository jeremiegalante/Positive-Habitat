#EXTEND Sketchup::ConstructionPoint CLASS
class Sketchup::ConstructionPoint
  def getWorldPosition(argParent, argTOmm:true)
    raise "argParent is not type of Sketchup::Entity" unless argParent.class == Sketchup::Group
    raise "argTOmm is not type of Boolean" unless [true, false].include? argTOmm

    #Retrieve parent context point position
    parentPosition = argParent.transformation.to_a[12..14]
    parentPosition.collect!{|value| value.to_mm.to_i} if argTOmm

    #Retrieve and construction point position
    cpPosition = self.position.to_a
    cpPosition.collect!{|value| value.to_mm.to_i} if argTOmm

    #Calculate world position
    worldPosition = [0,0,0]
    worldPosition.each_index{|index| worldPosition[index] = parentPosition[index] + cpPosition[index]}

    return worldPosition
  end
end