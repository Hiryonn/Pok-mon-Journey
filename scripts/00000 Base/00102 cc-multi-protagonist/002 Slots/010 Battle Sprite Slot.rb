module CCMultiProtagonist
  # Battle back-sprite domain ($game_actors[1].battler_name).
  class Battle_Sprite_Slot < Slot
    # The unique key identifying this domain.
    # @return [Symbol]
    def key
      return :battle_sprite
    end

    # Read the live value from the game state, duped to decouple from the global.
    # @param game_state [PFM::GameState]
    # @return [String]
    def extract(game_state)
      return game_state.game_actors[1].battler_name.dup
    end

    # Write a value into the live game state.
    # @param value [String]
    # @param game_state [PFM::GameState]
    def apply(value, game_state)
      game_state.game_actors[1].battler_name = value
    end

    # The "empty" value installed when no stored data exists.
    # @param game_state [PFM::GameState]
    # @return [nil]
    def blank(game_state)
      return nil
    end
  end

  SLOT_REGISTRY[:battle_sprite] = Battle_Sprite_Slot.new
end
