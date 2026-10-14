module CCPathfinding
  # Stepper port backed by the real engine Cursor (passability + terrain state machine).
  # Engine classes are only referenced at runtime, inside method bodies.
  class CursorStepper
    # @param character [Game_Character] character the simulation is based on
    def initialize(character)
      @character = character
    end

    # Underlying simulation cursor, exposed for Pathfinding.debug_add
    # @return [IndexedCursor]
    def cursor
      @cursor ||= IndexedCursor.new(@character)
      return @cursor
    end

    # Refresh the obstacle snapshot (call when map events may have moved)
    def refresh_obstacles
      cursor.refresh_event_index
    end

    # Stepper state at the character's current situation
    # @return [Array] [bridge, sliding, surfing]
    def initial_state
      return cursor.state
    end

    # Simulate one move and return the arrival situation. When the arrival tile
    # forces a glide (ice, rapids, rocket tiles), the whole glide is settled and
    # the returned position is where the engine will actually stop the character.
    # @param x [Integer] start x coordinate
    # @param y [Integer] start y coordinate
    # @param z [Integer] start z coordinate
    # @param state [Array] stepper state at the start position
    # @param direction [Integer] move direction (1..4, legacy encoding)
    # @return [Array, nil] [new_x, new_y, new_z, new_state], nil when the move is blocked
    def step(x, y, z, state, direction)
      return nil unless cursor.sim_move?(x, y, z, direction, *state)

      return settle_forced_movement(direction)
    end

    # Recreate the cursor from the character's current situation (used on reload)
    def reset
      @cursor = nil
    end

    private

    # The engine forces gliding on ice/rapids/rocket tiles (see
    # Game_Character#update_sliding and can_slide?): unroll the glide so the
    # search only ever works with positions the character can stand on.
    # @param entry_direction [Integer] direction of the move that landed here
    # @return [Array, nil] stable landing tuple, nil when the glide never ends
    def settle_forced_movement(entry_direction)
      return stable_landing if @character.respond_to?(:no_slide) && @character.no_slide

      moving_direction = entry_direction
      slide_param = nil
      visited = nil
      loop do
        tag = $game_map.system_tag(cursor.x, cursor.y)
        # Mirror of @sliding_parameter: refreshed on every slide tile crossed
        slide_param = tag if slide_directions.key?(tag)
        # Mirror of can_slide?: rocket pushes persist over normal floor
        break unless slide_directions.key?(tag) || rocket_tags.include?(slide_param)

        forced = forced_code(tag, slide_param, moving_direction)
        break unless forced

        visited ||= {}
        # (position, push direction) pair identifies a glide state; the forced
        # direction rides the z slot of the packing
        glide_key = CCPathfinding.pack_position(cursor.x, cursor.y, forced)
        # Endless rocket loop: the character would never land, the move is unusable
        return nil if visited[glide_key]

        visited[glide_key] = true
        break unless cursor.sim_move?(cursor.x, cursor.y, cursor.z, forced, *cursor.state)

        moving_direction = forced
      end
      return stable_landing
    end

    # @return [Array] landing tuple with the slide flag cleared (engine stop_slide)
    def stable_landing
      landing_state = cursor.state
      landing_state[1] = false
      return [cursor.x, cursor.y, cursor.z, landing_state]
    end

    # Direction forced by the current tile, or by a sticky rocket push
    # @param tag [Integer] system tag under the cursor
    # @param slide_param [Integer, nil] last slide tag crossed
    # @param moving_direction [Integer] direction of the previous move
    # @return [Integer, nil] forced direction code, nil when nothing forces a move
    def forced_code(tag, slide_param, moving_direction)
      code = slide_directions[tag]
      code = slide_directions[slide_param] if code.nil? && rocket_tags.include?(slide_param)
      return moving_direction if code == :forward

      return code
    end

    # Mirror of Game_Character::SLIDE_TAG_TO_MOVEMENT, built lazily so the file
    # stays loadable without the engine (1 = down, 2 = left, 3 = right, 4 = up)
    # @return [Hash]
    def slide_directions
      @slide_directions ||= begin
        tags = GameData::SystemTags
        {
          tags::TIce => :forward,
          tags::RapidsL => 2, tags::RapidsR => 3, tags::RapidsU => 4, tags::RapidsD => 1,
          tags::RocketL => 2, tags::RocketR => 3, tags::RocketU => 4, tags::RocketD => 1,
          tags::RocketRL => 2, tags::RocketRR => 3, tags::RocketRU => 4, tags::RocketRD => 1,
          tags::MachBike => 1
        }
      end
    end

    # Mirror of Game_Character::ROCKET_TAGS (sticky pushes)
    # @return [Array<Integer>]
    def rocket_tags
      @rocket_tags ||= begin
        tags = GameData::SystemTags
        [tags::RocketL, tags::RocketU, tags::RocketD, tags::RocketR,
         tags::RocketRL, tags::RocketRU, tags::RocketRD, tags::RocketRR]
      end
    end
  end
end
