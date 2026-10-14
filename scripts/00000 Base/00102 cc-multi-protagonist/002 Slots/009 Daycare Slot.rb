module CCMultiProtagonist
  # Daycare domain ($daycare).
  class Daycare_Slot < Slot
    # The unique key identifying this domain.
    # @return [Symbol]
    def key
      return :daycare
    end

    # Read the live value from the game state, duped to decouple from the global.
    # @param game_state [PFM::GameState]
    # @return [PFM::Daycare]
    def extract(game_state)
      return game_state.daycare.dup
    end

    # Write a value into the live game state and rebind it to the game state.
    # @param value [PFM::Daycare]
    # @param game_state [PFM::GameState]
    def apply(value, game_state)
      $daycare = game_state.daycare = value
      value.game_state = game_state
    end

    # The "empty" value installed when no stored data exists.
    # @param game_state [PFM::GameState]
    # @return [PFM::Daycare]
    def blank(game_state)
      return PFM.daycare_class.new(game_state)
    end
  end

  SLOT_REGISTRY[:daycare] = Daycare_Slot.new
end
