module CCMultiProtagonist
  # Pokedex domain ($pokedex).
  class Pokedex_Slot < Slot
    # The unique key identifying this domain.
    # @return [Symbol]
    def key
      return :pokedex
    end

    # Read the live value from the game state, duped to decouple from the global.
    # @param game_state [PFM::GameState]
    # @return [PFM::Pokedex]
    def extract(game_state)
      return game_state.pokedex.dup
    end

    # Write a value into the live game state.
    # @param value [PFM::Pokedex]
    # @param game_state [PFM::GameState]
    def apply(value, game_state)
      $pokedex = game_state.pokedex = value
    end

    # The "empty" value installed when no stored data exists.
    # @param game_state [PFM::GameState]
    # @return [PFM::Pokedex]
    def blank(game_state)
      return PFM::Pokedex.new
    end
  end

  SLOT_REGISTRY[:pokedex] = Pokedex_Slot.new
end
