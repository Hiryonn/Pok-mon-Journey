module CCMultiProtagonist
  # PC storage domain: boxes, battle boxes, current indices and Let's Go follower.
  class Storage_Slot < Slot
    # The unique key identifying this domain.
    # @return [Symbol]
    def key
      return :storage
    end

    # Read the live value from the game state as a portable snapshot.
    # @param game_state [PFM::GameState]
    # @return [CCMultiProtagonist::State]
    def extract(game_state)
      return game_state.storage.export_state
    end

    # Write a snapshot into the live game state.
    # @param value [CCMultiProtagonist::State]
    # @param game_state [PFM::GameState]
    def apply(value, game_state)
      game_state.storage.import_state(value)
    end

    # The "empty" value installed when no stored data exists (a fresh, full PC).
    # @param game_state [PFM::GameState]
    # @return [CCMultiProtagonist::State]
    def blank(game_state)
      return PFM::Storage.blank_state(game_state)
    end
  end

  SLOT_REGISTRY[:storage] = Storage_Slot.new
end
