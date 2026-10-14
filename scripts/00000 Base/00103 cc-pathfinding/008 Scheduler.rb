module CCPathfinding
  # Frame-budgeted round-robin over the active path requests.
  # Same scheduling semantics as the legacy Pathfinding.update, with the
  # remaining-budget computation fixed (the legacy passed the amount already
  # consumed, starving the first request of each frame).
  class Scheduler
    # Active path requests
    # @return [Array<Request>]
    attr_reader :requests

    def initialize
      @requests = []
      @last_request_index = 0
      @operation_per_frame = OPERATION_PER_FRAME
      @warned_deadlocks = {}
    end

    # Set the per-frame operation budget (maker-facing tuning knob)
    # @return [Integer]
    attr_writer :operation_per_frame

    # Register a path request for a character, replacing any existing one
    # @param character [Game_Character] character looking for a path
    # @param target_descriptor [Array] legacy [type, to, radius]
    # @param tries [Integer, Symbol] attempts before giving up, :infinity for unlimited
    # @param tags [Symbol] name of the Pathfinding::TagsWeight constant to use
    # @param on_finish [Proc, nil] called once when the request concludes by itself
    # @return [Boolean] if the request was added
    def add_request(character, target_descriptor, tries, tags, on_finish: nil)
      remove_request(character)
      goal = Goal.build(*target_descriptor)
      # Fail loudly like legacy did: a silent failure would leave the caller's
      # move_route_forcing flag set forever and block the interpreter
      raise ArgumentError, "unknown pathfinding target type: #{target_descriptor.first.inspect}" unless goal

      stepper = CursorStepper.new(character)
      cost_model = MapCostModel.new(tags)
      solver = Solver.new(
        stepper: stepper, cost_model: cost_model, goal: goal,
        node_cap: map_node_cap, heuristic_weight: CCPathfinding.heuristic_weight
      )
      @requests.push(
        Request.new(character: character, goal: goal, tries: tries, solver: solver, stepper: stepper, on_finish: on_finish)
      )

      return true
    end

    # Remove the request bound to a character
    # @param character [Game_Character] character to pop out
    # @return [Boolean] if a request was removed
    def remove_request(character)
      old_length = @requests.length
      @requests.delete_if { |request| request.character == character }
      @last_request_index = 0
      return old_length > @requests.length
    end

    # Stop and remove every request
    def clear
      @requests.clone.each { |request| request.character.stop_path }
      @requests.clear
      @last_request_index = 0
    end

    # Spread the frame budget over the requests, resuming where the last frame stopped
    def update
      return if @requests.empty?

      request_index = @last_request_index
      operation_counter = 0
      first_update = true
      need_update = true
      while operation_counter < @operation_per_frame
        current_request = @requests[request_index]
        break unless current_request

        cost = current_request.update(@operation_per_frame - operation_counter, first_update)
        # A zero-cost request that stays in the list must not livelock the loop
        operation_counter += cost > 0 ? cost : 1
        need_update ||= current_request.need_update
        if current_request.finished?
          # stop_path clears the character flags; removal is our own bookkeeping
          current_request.character.stop_path
          remove_request(current_request.character)
        end

        next unless (request_index += 1) >= @requests.length

        request_index = 0
        break if !need_update || @requests.empty?

        first_update = false
        need_update = false
      end
      @last_request_index = request_index
      detect_swap_deadlocks
    end

    private

    # Warn once per pair of requests that target the tile occupied by each
    # other and both fail: the deterministic swap deadlock that silently
    # blocked the interpreter with the legacy system.
    # Candidacy uses Request#failing? (persistent through the retry cycle) and
    # pairs are keyed by object identity (engine character ids are not unique).
    def detect_swap_deadlocks
      active_pairs = {}
      candidates = @requests.select { |request| request.failing? && !request.finished? && deadlock_eligible?(request.goal) }
      candidates.combination(2) do |first, second|
        next unless mutually_covering?(first, second)

        active_pairs[[first.character.object_id, second.character.object_id].sort] = [first, second]
      end
      @warned_deadlocks.keep_if { |key, _flag| active_pairs.key?(key) }
      active_pairs.each do |key, (first, second)|
        next if @warned_deadlocks[key]

        @warned_deadlocks[key] = true
        log_error("Pathfinding: swap deadlock between character ##{first.character.id} " \
                  "and character ##{second.character.id} " \
                  '(each one targets the tile occupied by the other, no path can exist)')
      end
    end

    # Only goals that point at a position can express a swap (flee/border cannot)
    # @param goal [Object] one of the Goal implementations
    # @return [Boolean]
    def deadlock_eligible?(goal)
      return goal.is_a?(Goal::Point) || goal.is_a?(Goal::Character)
    end

    # Tell if each request's goal is satisfied exactly where the other character stands
    # @param first [Request]
    # @param second [Request]
    # @return [Boolean]
    def mutually_covering?(first, second)
      return covers_other?(first.goal, second.character) && covers_other?(second.goal, first.character)
    end

    # Character goals require target IDENTITY (proximity would flag two
    # characters merely chasing the same third one); point goals probe the position
    # @param goal [Object] one of the Goal implementations
    # @param other_character [Game_Character] the other request's character
    # @return [Boolean]
    def covers_other?(goal, other_character)
      return goal.target_character.equal?(other_character) if goal.is_a?(Goal::Character)

      return goal.reached?(other_character.x, other_character.y, other_character.z)
    end

    # Position-keyed dedup already bounds any search by the map area; this cap
    # only guards pathological cases and can never truncate a legitimate search
    # @return [Integer] map area times the number of z levels
    def map_node_cap
      return $game_map.width * $game_map.height * 8
    end
  end
end
