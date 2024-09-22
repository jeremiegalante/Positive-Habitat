class PH::EntityObserver < Sketchup::EntityObserver
  # Method to remove entity from the Poste list in Model Attribute Dictionary.
  # @return nil
  # @version 1.0.0
  # @since 1.0.0
  def onEraseEntity(argEntity)
    #Etract entities recorded in AD
    posteInd = argEntity.name.scan(/\d/).join("")
    modelFrameAD_name = "FRAMES"
    modelFrameAD = Sketchup.active_model.get_attribute(modelFrameAD_name, posteInd)

    deleted?

    #Remove to matching Entity
    modelFrameAD["Entities"].delete_if{|currentPID| Sketchup.active_model.find_entity_by_persistent_id(currentPID) == argEntity}
    Sketchup.active_model.set_attribute(modelFrameAD_name, posteInd, modelFrameAD.to_s)
  end
end