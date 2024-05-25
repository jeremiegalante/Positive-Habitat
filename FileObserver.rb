require_relative 'Frame'

class PH::FileObserver < Sketchup::AppObserver
  # Method to reinitialise Postes drawing positions when a new model is created.
  # @return nil
  # @version 0.11.2
  # @since 0.11.2
  def onNewModel(argModel)
    #Reset the Frame Positions
    PH::Frame.initPostesPositions
  end

  # Method to load to the PH Plugin the model Postes drawing positions when a new model is opened.
  # @return nil
  # @version 0.11.2
  # @since 0.11.2
  def onOpenModel(argModel)
    #Reset the Frame Positions
    PH::Frame.initPostesPositions

    #Reload Frame data positions
    framedataAD = argModel.attribute_dictionary("data", false)
    PH::Frame.posteData = framedataAD
  end

  # Method to save to a model attribute dictionary the PH Plugin model Postes drawing positions when the model is saved.
  # @return nil
  # @version 0.11.2
  # @since 0.11.2
  def onSaveModel(argModel)
    #Get or create the AD
    framedataAD = argModel.attribute_dictionary("data", true)

    #Store the pré-cadres data
    framedataAD = PH::Frame.posteData
  end
end

#Connect file observer
Sketchup.add_observer(PH::FileObserver.new)