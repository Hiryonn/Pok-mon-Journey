module PFM
  class GameState
    # The multi-protagonist manager (plugin cc-multi-protagonist).
    # @return [CCMultiProtagonist::Manager]
    attr_accessor :multi_protagonist

    on_player_initialize(:multi_protagonist) { @multi_protagonist = CCMultiProtagonist::Manager.new(self) }
    on_expand_global_variables(:multi_protagonist) do
      @multi_protagonist ||= CCMultiProtagonist::Manager.new(self)
      @multi_protagonist.game_state = self
    end
  end
end
