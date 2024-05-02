require_relative 'Frame'

class PH::FileObserver < Sketchup::AppObserver
  def onNewModel(model)
    #Reset the Frame Positions
    PH::Frame.initPostesPositions
  end
  def onOpenModel(model)
    #Reset the Frame Positions
    PH::Frame.initPostesPositions

    #Reload Frame data positions
    skpAD = Sketchup.active_model.attribute_dictionary("data", create_if_empty)
    skpAD[posteID] = @data
  end
end

#Connect file observer
Sketchup.add_observer(PH::FileObserver.new)