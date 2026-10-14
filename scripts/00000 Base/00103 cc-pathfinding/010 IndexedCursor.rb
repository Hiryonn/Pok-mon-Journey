module CCPathfinding
  # Cursor with an O(1) blocked-tile snapshot instead of scanning every map
  # event on each simulated step (the legacy hot spot on event-heavy maps).
  # Owners must refresh the snapshot when the world may have changed: every
  # search frame, on reload and before each obstacle replay (Request does all three).
  # Loads after the engine: the superclass is the real Pathfinding::Cursor.
  class IndexedCursor < Pathfinding::Cursor
    # @param character [Game_Character] character the simulation is based on
    def initialize(character)
      super(character)
      # The stock Cursor never inherits the surf state: a surfing character
      # could not plan a single move over water (every SurfTag tile blocked)
      @surfing = true if character.respond_to?(:surfing?) && character.surfing?
      refresh_event_index
    end

    # Rebuild the blocked-tile snapshot from the current map events
    def refresh_event_index
      @blocking_z_by_position = {}
      $game_map.events.each_value do |event|
        next if event.through

        # Position key kept inline here and in event_passable_check? (hot path):
        # both sites must use the same packing
        position = event.x | (event.y << 12)
        (@blocking_z_by_position[position] ||= []).push(event.z)
      end
    end

    private

    # Same rule as the legacy event scan: blocked when a non-through event
    # stands on the tile within one z level (Game_Character#contact? tolerance)
    # @param new_x [Integer] x coordinate of the checked tile
    # @param new_y [Integer] y coordinate of the checked tile
    # @param z [Integer] z coordinate of the moving character
    # @param _game_map [Game_Map] unused, kept for signature compatibility
    # @return [Boolean] if the tile has no event that blocks the way
    def event_passable_check?(new_x, new_y, z, _game_map)
      blocking_z = @blocking_z_by_position[new_x | (new_y << 12)]
      return true unless blocking_z

      return blocking_z.none? { |event_z| (event_z - z).abs <= 1 }
    end

    # The stock simulation Cursor mis-handles two ledge jumps (its move_right
    # tests JumpL and its move_up tests JumpD): the overrides below mirror the
    # REAL engine moves (120 Game_Character_move.rb) so that planned jumps
    # match executed jumps, in all four directions.

    # Move the simulated character right (JumpR ledge fixed)
    def move_right
      @direction = 6
      return if stair_move_right

      y_modifier = slope_check_right
      if passable?(@x, @y + y_modifier, 6)
        if $game_map.system_tag(@x + 1, @y) == JumpR
          jump(2, 0)
          return
        end

        bridge_left_check(@z)
        @x += 1
        @y += y_modifier
        movement_process_end
      else
        @sliding = false
      end
    end

    # Move the simulated character up (JumpU ledge fixed)
    def move_up
      @direction = 8
      if passable?(@x, @y, 8)
        if $game_map.system_tag(@x, @y - 1) == JumpU
          jump(0, -2)
          return
        end

        bridge_down_check(@z)
        @y -= 1
        movement_process_end
      else
        @sliding = false
      end
    end

    # Move the simulated character left (ledge probed at the slope-adjusted
    # position, like the real engine move)
    def move_left
      @direction = 4
      return if stair_move_left

      y_modifier = slope_check_left
      if passable?(@x, @y, 4)
        if $game_map.system_tag(@x - 1, @y + y_modifier) == JumpL
          jump(-2, 0)
          return
        end

        bridge_left_check(@z)
        @x -= 1
        @y += y_modifier
        movement_process_end
      else
        @sliding = false
      end
    end
  end
end
