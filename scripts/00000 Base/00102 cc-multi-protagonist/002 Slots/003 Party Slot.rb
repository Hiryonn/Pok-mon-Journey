module CCMultiProtagonist
  # Party domain ($actors).
  class Party_Slot < Slot
    # The unique key identifying this domain.
    # @return [Symbol]
    def key
      return :party
    end

    # Read the live value from the game state, duped to decouple from the global.
    # @param game_state [PFM::GameState]
    # @return [Array<PFM::Pokemon>]
    def extract(game_state)
      # compact (non-mutating) returns a fresh array without nils: a read must not
      # normalize the live party in place.
      return game_state.actors.compact
    end

    # Write a value into the live game state.
    # @param value [Array<PFM::Pokemon>]
    # @param game_state [PFM::GameState]
    def apply(value, game_state)
      $actors = game_state.actors = value
    end

    # The "empty" value installed when no stored data exists.
    # @param game_state [PFM::GameState]
    # @return [Array]
    def blank(game_state)
      return []
    end
  end

  SLOT_REGISTRY[:party] = Party_Slot.new
end
