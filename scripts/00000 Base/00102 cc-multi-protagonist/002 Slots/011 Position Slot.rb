module CCMultiProtagonist
  # Player physical location (map + tile + facing). Applied last in a switch so its map transfer
  # reads already-swapped domains. blank = nil so a never-visited player stays in place.
  class Position_Slot < Slot
    # The unique key identifying this domain.
    # @return [Symbol]
    def key
      return :position
    end

    # Read the live map and player coordinates, or the destination of a queued warp when one is
    # pending (e.g. a warp issued during a setup): the transfer has not been applied yet, so its
    # destination is the intended position.
    # @param game_state [PFM::GameState]
    # @return [Hash{Symbol => Integer}] the map_id, x, y and direction
    def extract(game_state)
      temp = game_state.game_temp
      return capture_pending_transfer(temp) if temp&.player_transferring

      player = game_state.game_player
      return { map_id: game_state.game_map.map_id, x: player.x, y: player.y, direction: player.direction }
    end

    # Warp the player to the stored position. A nil value (never-visited player) stays in place.
    # @param value [Hash{Symbol => Integer}, nil]
    # @param game_state [PFM::GameState]
    def apply(value, game_state)
      return nil if value.nil?

      Util::Warp.warp(value[:map_id], value[:x], value[:y], value[:direction])
    end

    # The "empty" value installed when no stored data exists (no transfer, stay in place).
    # @param game_state [PFM::GameState]
    # @return [nil]
    def blank(game_state)
      return nil
    end

    private

    # Capture a queued transfer's destination and consume it, so the pending warp does not carry
    # over to the next protagonist when the switch restores it.
    # @param temp [Game_Temp]
    # @return [Hash{Symbol => Integer}]
    def capture_pending_transfer(temp)
      position = { map_id: temp.player_new_map_id, x: temp.player_new_x, y: temp.player_new_y, direction: temp.player_new_direction }
      temp.player_transferring = false
      return position
    end
  end

  SLOT_REGISTRY[:position] = Position_Slot.new
end
