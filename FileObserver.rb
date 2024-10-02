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

class PH::SelectionObserver < Sketchup::SelectionObserver
  @@previousSelection = []
  @@orderedSelection = {}

  #CLASS VARIABLE ACCESSORS
  def self.selection; return @@orderedSelection; end

  # In case of selection cleared, method that empty the ordered list of selected entities.
  # @return Hash
  # @version 0.x.x
  # @since 0.x.x
  def onSelectionBulkChange(selection)
    #Convert selection to list
    argCurrentSelection = selection.to_a

    #Find the added or removed entity
    remEntity = (@@previousSelection - argCurrentSelection)[0]
    addEntity = (argCurrentSelection - @@previousSelection)[0]

    #Update previous selection
    @@previousSelection = argCurrentSelection

    #Update ordered selection
    ##In cae of entity adding
    if @@orderedSelection.length <= 2
      unless addEntity.nil?
        (0..2).each do |order|
          unless @@orderedSelection.values.include? order
            @@orderedSelection[addEntity] = order
            break
          end
        end
      end
    end

    ##In case of entity removing
    @@orderedSelection.delete(remEntity) unless remEntity.nil?

    return @@orderedSelection
  end

  def onSelectionCleared(selection)
    #Reinitialise selection memories
    @@previousSelection = []
    @@orderedSelection = {}
  end
end

#Connect selection observer
Sketchup.active_model.selection.add_observer(PH::SelectionObserver.new)