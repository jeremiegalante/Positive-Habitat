#EXTEND Sketchup::Entities CLASS
class Sketchup::Entities
def findFace(argAxis, argLimit, argSymbol)
    raise "argAxis is not a valid value [X, Y, Z]" unless [0,"X", 1,"Y", 2,"Z"].include? argAxis
    raise "argLimit is not type of Numeric" unless argLimit.class <= Numeric
    raise "argSymbol is not a valid comparator string [<, <=, >, >=, ==, !=]" unless ["<", "<=", ">", ">=", "==", "!="].include? argSymbol

    #Extract Faces form entities
    faces = self.to_a.grep(Sketchup::Face)

    #Convert axis to value
    argAxis = ["X", "Y", "Z"].index(argAxis) if argAxis.class == String

    #Find the matching face
    validEntities = []
    faces.each do |currentFace|
      #Get face vertices positions on axis
      positionsOnAxis = currentFace.vertices.to_a.collect{|currentVertex| currentVertex.position.to_a[argAxis].mm.to_i}.uniq

      #Find if the vertices match the request
      if positionsOnAxis.length <= 1 and eval("#{positionsOnAxis[-1]}#{argSymbol}#{argLimit.mm.to_i}")
        validEntities << [currentFace, positionsOnAxis[-1].mm]
      end
    end

    return ((validEntities.length == 1) ? validEntities.uniq[-1] : nil)
  end

  def findFaceBis(argAxis, argLimit, argSymbol)
    raise "argAxis is not a valid value [X, Y, Z]" unless [0,"X", 1,"Y", 2,"Z"].include? argAxis
    raise "argLimit is not type of Numeric" unless argLimit.class <= Numeric
    raise "argSymbol is not a valid comparator string [<, <=, >, >=, ==, !=]" unless ["<", "<=", ">", ">=", "==", "!="].include? argSymbol

    #Extract Faces form entities
    faces = self.to_a.grep(Sketchup::Face)

    #Convert axis to value
    argAxis = ["X", "Y", "Z"].index(argAxis) if argAxis.class == String

    #Find the matching face
    validEntities = []
    faces.each do |currentFace|
      positionsOnAxis = currentFace.bounds.center.to_a.collect{|coord| coord.to_mm}[argAxis]

      #Find if the vertices match the request
      if eval("#{positionsOnAxis}#{argSymbol}#{argLimit}")
        validEntities << [currentFace, positionsOnAxis.mm]
      end
    end

    return validEntities.uniq[-1]
  end
end

