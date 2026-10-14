module CCPathfinding
  # Goal port: decides when a search is over and guides A* with an admissible heuristic.
  module Goal
    module_function

    # Build a goal from the legacy target descriptor [type, to, radius].
    # Engine globals are only touched here, at runtime.
    # @param type [Symbol] :Coords, :Character, :Character_Reject or :Border
    # @param to [Array<Integer>, Game_Character, Symbol] target data matching the type
    # @param radius [Integer] distance from the target to consider it as reached
    # @return [Point, Character, Flee, Border, nil] nil when the type is unknown
    def build(type, to, radius)
      case type
      when :Coords
        x = to[0] + Yuki::MapLinker.get_OffsetX
        y = to[1] + Yuki::MapLinker.get_OffsetY
        return Point.new(x, y, to[2], radius)
      when :Character
        return Character.new(to, radius)
      when :Character_Reject
        return Flee.new(to, radius)
      when :Border
        # A garbage border value made the legacy goal instantly "reached" (silent no-op)
        raise ArgumentError, "invalid border for pathfinding: #{to.inspect} (expected :north, :south, :east or :west)" unless %i[north south east west].include?(to)

        return Border.new(
          to, radius,
          map_width: $game_map.width, map_height: $game_map.height,
          offset_x: Yuki::MapLinker.get_OffsetX, offset_y: Yuki::MapLinker.get_OffsetY
        )
      else
        return nil
      end
    end

    # Shared reload rule for goals that track a moving character.
    # Legacy thresholds: far targets (> 15 tiles) only trigger on a > 10 tiles drift
    module MovingTargetTracking
      # Tell if the target moved enough to require a search reload
      # @param x [Integer] x coordinate of the requesting character
      # @param y [Integer] y coordinate of the requesting character
      # @return [Boolean]
      def check_move(x, y)
        character = @character
        if (character.x - x).abs + (character.y - y).abs > 15
          if (@stored_x - character.x).abs + (@stored_y - character.y).abs > 10
            @stored_x = character.x
            @stored_y = character.y
            return true
          end

          return false
        end

        return @stored_x != (@stored_x = character.x) || @stored_y != (@stored_y = character.y)
      end
    end

    # Fixed-coordinates goal (legacy Target::Coords)
    class Point
      # @param x [Integer] target x coordinate (MapLinker offset already applied)
      # @param y [Integer] target y coordinate (MapLinker offset already applied)
      # @param z [Integer, nil] target z coordinate (kept for parity, unused)
      # @param radius [Integer] reach tolerance in Manhattan distance
      def initialize(x, y, z, radius)
        @x = x
        @y = y
        @z = z
        @radius = radius
      end

      # Tell if the goal is reached at the given position (z ignored on purpose: legacy parity)
      # @param x [Integer] x coordinate to test
      # @param y [Integer] y coordinate to test
      # @param _z [Integer] z coordinate to test
      # @return [Boolean]
      def reached?(x, y, _z)
        return ((@x - x).abs + (@y - y).abs) <= @radius
      end

      # Admissible remaining-cost lower bound (Manhattan minus radius, coefficient 1)
      # @param x [Integer] x coordinate of the evaluated node
      # @param y [Integer] y coordinate of the evaluated node
      # @return [Integer]
      def heuristic(x, y)
        distance = (@x - x).abs + (@y - y).abs - @radius
        return distance > 0 ? distance : 0
      end

      # Tell if the target moved enough to require a search reload
      # @param _x [Integer] x coordinate of the requesting character
      # @param _y [Integer] y coordinate of the requesting character
      # @return [Boolean] always false: fixed coordinates never move
      def check_move(_x, _y)
        return false
      end
    end

    # Live character goal (legacy Target::Character)
    class Character
      # @param character [Game_Character] character to reach
      # @param radius [Integer] reach tolerance in Manhattan distance
      def initialize(character, radius)
        @character = character
        @radius = radius
        @stored_x = character.x
        @stored_y = character.y
      end

      # Character being chased, exposed for the scheduler's deadlock identity check
      # @return [Game_Character]
      def target_character
        return @character
      end

      # Tell if the goal is reached at the given position, against the LIVE target position
      # @param x [Integer] x coordinate to test
      # @param y [Integer] y coordinate to test
      # @param _z [Integer] z coordinate to test
      # @return [Boolean]
      def reached?(x, y, _z)
        return ((@character.x - x).abs + (@character.y - y).abs) <= @radius
      end

      # Uses the stored reference (maintained by check_move), not the live position:
      # a stable goal keeps the A* priority ordering consistent within one search;
      # target drift beyond the legacy thresholds triggers a reload anyway
      # @param x [Integer] x coordinate of the evaluated node
      # @param y [Integer] y coordinate of the evaluated node
      # @return [Integer]
      def heuristic(x, y)
        distance = (@stored_x - x).abs + (@stored_y - y).abs - @radius
        return distance > 0 ? distance : 0
      end

      include MovingTargetTracking
    end

    # Map border goal (legacy Target::Border)
    class Border
      # @param border [Symbol] :north, :south, :east or :west
      # @param radius [Integer] distance from the border to consider it as reached
      # @param map_width [Integer] width of the current map
      # @param map_height [Integer] height of the current map
      # @param offset_x [Integer] MapLinker x offset
      # @param offset_y [Integer] MapLinker y offset
      def initialize(border, radius, map_width:, map_height:, offset_x: 0, offset_y: 0)
        @border = border
        case border
        when :north
          @value = radius + offset_y
        when :west
          @value = radius + offset_x
        when :south
          @value = map_height - radius - 1 - offset_y
        when :east
          @value = map_width - radius - 1 - offset_x
        end
      end

      # Tell if the goal is reached at the given position
      # @param x [Integer] x coordinate to test
      # @param y [Integer] y coordinate to test
      # @param _z [Integer] z coordinate to test
      # @return [Boolean]
      def reached?(x, y, _z)
        case @border
        when :north then return y <= @value
        when :south then return y >= @value
        when :east then return x >= @value
        when :west then return x <= @value
        end

        return true
      end

      # Admissible remaining-cost lower bound: straight distance to the border line
      # @param x [Integer] x coordinate of the evaluated node
      # @param y [Integer] y coordinate of the evaluated node
      # @return [Integer]
      def heuristic(x, y)
        case @border
        when :north then distance = y - @value
        when :south then distance = @value - y
        when :east then distance = @value - x
        when :west then distance = x - @value
        else return 0
        end

        return distance > 0 ? distance : 0
      end

      # Tell if the target moved enough to require a search reload
      # @param _x [Integer] x coordinate of the requesting character
      # @param _y [Integer] y coordinate of the requesting character
      # @return [Boolean] always false: a border never moves
      def check_move(_x, _y)
        return false
      end
    end

    # Flee-a-character goal (legacy Target::Character_Reject).
    # No directional objective: null heuristic (degenerates to Dijkstra).
    class Flee
      # @param character [Game_Character] character to flee from
      # @param radius [Integer] distance beyond which the flee is accomplished
      def initialize(character, radius)
        @character = character
        @radius = radius
        @stored_x = character.x
        @stored_y = character.y
      end

      # Tell if the position is strictly beyond the flee radius
      # @param x [Integer] x coordinate to test
      # @param y [Integer] y coordinate to test
      # @param _z [Integer] z coordinate to test
      # @return [Boolean]
      def reached?(x, y, _z)
        return ((@character.x - x).abs + (@character.y - y).abs) > @radius
      end

      # No directional lower bound exists when fleeing
      # @param _x [Integer] x coordinate of the evaluated node
      # @param _y [Integer] y coordinate of the evaluated node
      # @return [Integer] always 0
      def heuristic(_x, _y)
        return 0
      end

      include MovingTargetTracking
    end
  end
end
