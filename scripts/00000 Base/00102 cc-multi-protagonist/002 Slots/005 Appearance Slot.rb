module CCMultiProtagonist
  # Appearance domain: the overworld charset.
  class Appearance_Slot < Slot
    # The unique key identifying this domain.
    # @return [Symbol]
    def key
      return :appearance
    end

    # Read the live value from the game state, duped to decouple from the global.
    # @param game_state [PFM::GameState]
    # @return [String]
    def extract(game_state)
      return game_state.game_player.charset_base.dup
    end

    # Write a value into the live game state.
    # @param value [String]
    # @param game_state [PFM::GameState]
    def apply(value, game_state)
      game_state.game_player.set_appearance_set(value)
    end

    # The "empty" value installed when no stored data exists.
    # @param game_state [PFM::GameState]
    # @return [nil]
    def blank(game_state)
      # nil (not '') so the engine guard "unless @charset_base" skips an invalid charset.
      return nil
    end
  end

  SLOT_REGISTRY[:appearance] = Appearance_Slot.new
end
