module CCMultiProtagonist
  # Bag domain ($bag).
  class Bag_Slot < Slot
    # The unique key identifying this domain.
    # @return [Symbol]
    def key
      return :bag
    end

    # Read the live value from the game state, duped to decouple from the global.
    # @param game_state [PFM::GameState]
    # @return [PFM::Bag]
    def extract(game_state)
      return game_state.bag.dup
    end

    # Write a value into the live game state.
    # @param value [PFM::Bag]
    # @param game_state [PFM::GameState]
    def apply(value, game_state)
      $bag = game_state.bag = value
    end

    # The "empty" value installed when no stored data exists.
    # @param game_state [PFM::GameState]
    # @return [PFM::Bag]
    def blank(game_state)
      return PFM::Bag.new
    end
  end

  SLOT_REGISTRY[:bag] = Bag_Slot.new
end
