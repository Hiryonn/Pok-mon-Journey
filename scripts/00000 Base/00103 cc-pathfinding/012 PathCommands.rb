# New pathfinding API, one intent per method, running on the cc-pathfinding
# engine. Lives alongside the legacy find_path (untouched). Migration:
#   find_path(to: [x, y], radius: r)                    -> path_to(x, y, radius: r)
#   find_path(to: character)                            -> chase(character)
#   find_path(to: character, type: :Character_Reject)   -> flee_from(character)
#   find_path(to: :north, type: :Border)                -> path_to_border(:north)
# In events, follow the call with the "Wait for Move's Completion" command to
# block the interpreter until the arrival (or wait_character_move_completion).
module CCPathfinding
  # Number of attempts before giving up a search (same default as legacy)
  TRY_COUNT = 5

  # Intent methods available on every character
  module CharacterPathCommands
    # Walk to a tile
    # @param x [Integer] x coordinate to reach
    # @param y [Integer] y coordinate to reach
    # @param radius [Integer] distance from the tile to consider it as reached
    # @param tries [Integer, Symbol] attempts before giving up, :infinity for unlimited
    # @param running [Boolean] use the running state, restored on arrival
    # @return [Boolean] if the search was engaged
    def path_to(x, y, radius: 0, tries: CCPathfinding::TRY_COUNT, running: false, &on_finish)
      return cc_engage_path([:Coords, [x, y], radius], tries, running, on_finish)
    end

    # Follow a character, re-pathing when it moves. The default radius of 1 is
    # required to catch a blocking character: its own tile cannot be entered.
    # @param target [Game_Character] character to follow
    # @param radius [Integer] distance from the target to consider it as reached
    # @param tries [Integer, Symbol] attempts before giving up (unlimited: a chase is long-lived)
    # @param running [Boolean] use the running state, restored on arrival
    # @return [Boolean] if the search was engaged
    def chase(target, radius: 1, tries: :infinity, running: false, &on_finish)
      return cc_engage_path([:Character, target, radius], tries, running, on_finish)
    end

    # Move away from a character. Finishes immediately when already far enough.
    # @param target [Game_Character] character to flee from
    # @param distance [Integer] Manhattan distance to put between self and the target
    # @param tries [Integer, Symbol] attempts before giving up, :infinity for unlimited
    # @param running [Boolean] use the running state, restored on arrival
    # @return [Boolean] if the search was engaged
    def flee_from(target, distance: 6, tries: CCPathfinding::TRY_COUNT, running: false, &on_finish)
      return cc_engage_path([:Character_Reject, target, distance], tries, running, on_finish)
    end

    # Walk to a map border
    # @param border [Symbol] :north, :south, :east or :west
    # @param radius [Integer] distance from the border to consider it as reached
    # @param tries [Integer, Symbol] attempts before giving up, :infinity for unlimited
    # @param running [Boolean] use the running state, restored on arrival
    # @return [Boolean] if the search was engaged
    def path_to_border(border, radius: 0, tries: CCPathfinding::TRY_COUNT, running: false, &on_finish)
      return cc_engage_path([:Border, border, radius], tries, running, on_finish)
    end

    private

    # Same bookkeeping as the legacy find_path: these flags are read by
    # Game_Character#update and by the interpreter's waiting_event?
    # @param descriptor [Array] [type, to, radius] target descriptor
    # @param tries [Integer, Symbol] attempts before giving up
    # @param running [Boolean] use the running state
    # @param on_finish [Proc, nil] called once with true (goal reached) or false (gave up)
    # @return [Boolean] always true (add_request raises on invalid targets)
    def cc_engage_path(descriptor, tries, running, on_finish)
      # Capture the pre-pathfinding flag only on a FRESH engage: re-engaging an
      # already-driven character (unguarded parallel event re-issuing a chase)
      # must not capture our own forced state as the value to restore
      @move_route_forcing_path_finder = @move_route_forcing if @path.nil?
      # One pathfinding system per character at a time: evict a legacy request
      Pathfinding.remove_request(self)
      CCPathfinding.scheduler.add_request(self, descriptor, tries, :DEFAULT, on_finish: on_finish)
      @move_route_forcing = true
      @move_type_custom_special_result = true
      enter_in_path_running_state if running
      return true
    end
  end
end

Game_Character.include(CCPathfinding::CharacterPathCommands)
