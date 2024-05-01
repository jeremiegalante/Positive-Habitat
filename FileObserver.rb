require_relative 'Frame'

class PH::FileObserver < Sketchup::AppObserver
  def onNewModel(model)
    #Reset the Frame Positions
    PH::Frame.initPostesPositions
  end
  def onOpenModel(model)
    #Reset the Frame Positions
    PH::Frame.initPostesPositions
  end
end

#Connect file observer
Sketchup.add_observer(PH::FileObserver.new)