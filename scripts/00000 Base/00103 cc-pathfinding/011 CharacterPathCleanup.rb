module CCPathfinding
  # Fixes the legacy Game_Character#clear_path: the move_route_forcing restore
  # was gated on a path having been DELIVERED (define_path). A request giving up
  # without ever finding a path left move_route_forcing stuck at true, crashing
  # move_type_custom on route-less characters (the player) and blocking the
  # interpreter forever on events. Restore is now gated on find_path having
  # captured the flag, which happens on every request.
  module CharacterPathCleanup
    private

    def clear_path
      @move_route_index = @move_route_index_path_finder if @move_route_index_path_finder
      @move_route_forcing = @move_route_forcing_path_finder unless @move_route_forcing_path_finder.nil?
      @move_route_index_path_finder = @path = @move_route_forcing_path_finder = nil
      leave_path_running_state
    end
  end
end

Game_Character.prepend(CCPathfinding::CharacterPathCleanup)
