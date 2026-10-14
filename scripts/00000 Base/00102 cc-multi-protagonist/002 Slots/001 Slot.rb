module CCMultiProtagonist
  # Base strategy for one swappable player domain.
  class Slot
    # The unique key identifying this domain.
    # @return [Symbol]
    def key
      raise NotImplementedError, "#{self.class} must implement #key"
    end

    # Read the live value from the game state, duped to decouple from the global.
    # @param game_state [PFM::GameState]
    # @return [Object]
    def extract(game_state)
      raise NotImplementedError, "#{self.class} must implement #extract"
    end

    # Write a value into the live game state.
    # @param value [Object]
    # @param game_state [PFM::GameState]
    def apply(value, game_state)
      raise NotImplementedError, "#{self.class} must implement #apply"
    end

    # The "empty" value installed when no stored data exists.
    # @param game_state [PFM::GameState]
    # @return [Object]
    def blank(game_state)
      raise NotImplementedError, "#{self.class} must implement #blank"
    end
  end
end
