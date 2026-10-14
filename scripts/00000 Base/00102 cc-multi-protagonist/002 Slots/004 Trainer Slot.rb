module CCMultiProtagonist
  # Trainer domain ($trainer): name, id, badges, play time, gender.
  class Trainer_Slot < Slot
    # The unique key identifying this domain.
    # @return [Symbol]
    def key
      return :trainer
    end

    # Read the live value from the game state, duped to decouple from the global.
    # @param game_state [PFM::GameState]
    # @return [PFM::Trainer]
    def extract(game_state)
      return game_state.trainer.dup
    end

    # Write a value into the live game state and sync the gender switch.
    # @param value [PFM::Trainer]
    # @param game_state [PFM::GameState]
    def apply(value, game_state)
      $trainer = game_state.trainer = value
      game_state.game_switches[Yuki::Sw::Gender] = value.playing_girl
    end

    # The "empty" value installed when no stored data exists.
    # @param game_state [PFM::GameState]
    # @return [PFM::Trainer]
    def blank(game_state)
      return PFM::Trainer.new
    end
  end

  SLOT_REGISTRY[:trainer] = Trainer_Slot.new
end
