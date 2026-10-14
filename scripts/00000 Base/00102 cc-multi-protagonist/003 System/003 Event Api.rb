module CCMultiProtagonist
  # Mixed into the RMXP Interpreter: event scripts run in its binding, so `protagonists` is callable
  # directly from a "Script" event command.
  module EventApi
    # @return [CCMultiProtagonist::Manager] the live multi-protagonist manager
    def protagonists
      return PFM.game_state.multi_protagonist
    end
  end
end

class Interpreter
  include CCMultiProtagonist::EventApi
end
