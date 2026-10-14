module CCMultiProtagonist
  # Money domain.
  class Money_Slot < Slot
    # The unique key identifying this domain.
    # @return [Symbol]
    def key
      return :money
    end

    # Read the live value from the game state.
    # @param game_state [PFM::GameState]
    # @return [Integer]
    def extract(game_state)
      return game_state.money
    end

    # Write a value into the live game state.
    # @param value [Integer]
    # @param game_state [PFM::GameState]
    def apply(value, game_state)
      game_state.money = value
    end

    # The "empty" value installed when no stored data exists.
    # @param game_state [PFM::GameState]
    # @return [Integer]
    def blank(game_state)
      return 0
    end
  end

  SLOT_REGISTRY[:money] = Money_Slot.new
end
