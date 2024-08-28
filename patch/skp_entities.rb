#EXTEND Sketchup::Entities CLASS
class Sketchup::Entities
  def findEntity(argClass)
    self.to_a.select{|current_entity| current_entity.class == argClass}
  end

  def findFace(argAxis, argLimit, argSymbol)
    raise "argAxis is not a valid value [X, Y, Z]" unless [0,"X", 1,"Y", 2,"Z"].include? argAxis
    raise "argLimit is not type of Numeric" unless argLimit.class <= Numeric
    raise "argSymbol is not a valid comparator string [<, <=, >, >=, ==, !=]" unless ["<", "<=", ">", ">=", "==", "!="].include? argSymbol

    #Extract Faces form entities
    faces = self.findEntity(Sketchup::Face)

    #Convert axis to value
    argAxis = ["X", "Y", "Z"].index(argAxis) if argAxis.class == String

    #Find the highest face
    validEntities = []
    faces.each do |currentFace|
      #Get face vertices positions on axis
      positionsOnAxis = currentFace.vertices.to_a.collect{|currentVertex| currentVertex.position.to_a[argAxis]}.uniq

      #Find if the vertices match the request
      if positionsOnAxis.length <= 1 and eval("#{positionsOnAxis[-1]}#{argSymbol}#{argLimit}")
        validEntities << [currentFace, positionsOnAxis[-1].mm]
      end
    end

    return validEntities.uniq[-1]
  end
end

