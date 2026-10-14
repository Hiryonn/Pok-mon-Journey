module CCPathfinding
  # Lifecycle of one path request: search -> watch -> (reload | wait) -> ...
  # Mirrors the legacy Pathfinding::Request state machine, with the frame
  # budget bug fixed (the budget received is the REMAINING frame budget).
  class Request
    # Character the path is searched for
    # @return [Game_Character]
    attr_reader :character
    # Tell if the request needs an update this frame
    # @return [Boolean]
    attr_reader :need_update

    # @param character [Game_Character] character to give a path to
    # @param goal [Goal::Point, Goal::Character, Goal::Border, Goal::Flee] target of the search
    # @param tries [Integer, Symbol] attempts before giving up, :infinity for unlimited
    # @param solver [Solver] search algorithm bound to this request
    # @param stepper [CursorStepper] move simulator shared with the solver
    # @param on_finish [Proc, nil] called once when the request concludes by itself
    def initialize(character:, goal:, tries:, solver:, stepper:, on_finish: nil)
      @character = character
      @goal = goal
      @solver = solver
      @stepper = stepper
      @on_finish = on_finish
      @concluded = false
      @state = :search
      @remaining_tries = @original_tries = tries
      @failed_since_path = false
      @need_update = true
      @character.path = :pending
      Pathfinding.debug_clear(character.id) if defined?(Pathfinding.debug_clear)
      @solver.start(character.x, character.y, character.z, @stepper.initial_state)
    end

    # Goal of the search, exposed for the scheduler's deadlock detection
    # @return [Object] one of the Goal implementations
    attr_reader :goal

    # Tell if the request is over (legacy convention: the character path is cleared)
    # @return [Boolean]
    def finished?
      return @character.path.nil?
    end

    # Tell if the request failed a search and has not delivered a path since.
    # Stays true through the whole wait -> reload -> search retry cycle, so the
    # scheduler's deadlock bookkeeping is not reset by state transitions.
    # @return [Boolean]
    def failing?
      return @failed_since_path
    end

    # Update the request and return the amount of spent operations
    # @param remaining_budget [Integer] operations left for this frame
    # @param is_first_update [Boolean] first pass of the frame for this request
    # @return [Integer] cost spent
    def update(remaining_budget, is_first_update)
      # The engine is gliding the character (ice/rapids): its grid position
      # crosses tiles it cannot stop on — freeze until the glide settles,
      # mirroring the engine's own `return if @sliding` around path following
      return 1 if @character.respond_to?(:sliding) && @character.sliding

      if @goal.reached?(@character.x, @character.y, @character.z)
        conclude(true)
        return 0
      end

      @need_update ||= is_first_update
      case @state
      when :search then return update_search(remaining_budget)
      when :watch then return update_watch(is_first_update)
      when :wait then return update_wait(is_first_update)
      when :reload then return update_reload(is_first_update)
      else return 1
      end
    end

    private

    # Advance the path search within the allowed node budget
    # @param remaining_budget [Integer] operations left for this frame
    # @return [Integer] cost spent (expanded nodes + 1)
    def update_search(remaining_budget)
      if @goal.check_move(@character.x, @character.y)
        @state = :reload
        return 1
      end

      node_budget = remaining_budget < OPERATION_PER_REQUEST ? remaining_budget : OPERATION_PER_REQUEST
      return 1 if node_budget <= 0

      # Obstacles may move while a search spans several frames: resync the
      # snapshot so the search sees events like the legacy live scan did
      @stepper.refresh_obstacles
      nodes_before = @solver.nodes_expanded
      status = @solver.step_batch(node_budget)
      process_search_result(status)
      return (@solver.nodes_expanded - nodes_before) + 1
    end

    # Transition out of the search state according to the solver status
    # @param status [Symbol] :found, :not_found or :running
    def process_search_result(status)
      return if status == :running

      if status == :found
        @remaining_tries = @original_tries
        @failed_since_path = false
        @state = :watch
        send_path(@solver.path)
        return
      end

      # :not_found
      @failed_since_path = true
      if @remaining_tries == :infinity || (@remaining_tries -= 1) > 0
        @state = :wait
        @retry_countdown = TRY_DELAY
      else
        # Legacy visibility: makers can diagnose unreachable targets in the console
        log_debug("Character ##{@character.id} fail to found path") if defined?(log_debug)
        conclude(false)
      end
    end

    # Watch the followed path for target movement, obstacles or arrival
    # @param is_first_update [Boolean] first pass of the frame for this request
    # @return [Integer] cost spent
    def update_watch(is_first_update)
      return 1 unless is_first_update

      # Only check while the character stands exactly on a tile
      if @character.real_x % 128 + @character.real_y % 128 == 0
        if @goal.check_move(@character.x, @character.y)
          @state = :reload
          return 1
        end

        if stucked?
          @state = :reload
        elsif @goal.reached?(@character.x, @character.y, @character.z)
          conclude(true)
        end
      end

      @need_update = false
      return COST_WATCH
    end

    # Count down the retry delay after a failed search
    # @param is_first_update [Boolean] first pass of the frame for this request
    # @return [Integer] cost spent
    def update_wait(is_first_update)
      return 1 unless is_first_update

      @retry_countdown -= 1
      @state = :reload if @retry_countdown <= 0
      @need_update = false
      return COST_WAIT
    end

    # Restart the search from the character's current situation
    # @param is_first_update [Boolean] first pass of the frame for this request
    # @return [Integer] cost spent
    def update_reload(is_first_update)
      return 1 unless is_first_update

      @character.path = :pending
      @stepper.reset
      @solver.start(@character.x, @character.y, @character.z, @stepper.initial_state)
      @state = :search
      return COST_RELOAD
    end

    # End the request on its own terms and signal the outcome, exactly once.
    # External cancellations (stop_path, eviction, map warp) do not signal.
    # @param success [Boolean] true when the goal was reached
    def conclude(success)
      return if @concluded

      @concluded = true
      @character.stop_path
      @on_finish&.call(success)
    end

    # Convert the found path into move commands and hand it to the character
    # @param path [Array<Integer>] directions from the solver
    def send_path(path)
      Pathfinding.debug_add(@character, @stepper.cursor, path) if defined?(Pathfinding.debug_add)
      @character.define_path((path + [0]).collect { |code| Request.move_command(code) })
    end

    # Replay the remaining commands to detect a fresh obstacle on the path
    # @return [Boolean]
    def stucked?
      route = @character.path
      return true unless route.is_a?(Array)

      # The stepper works on an obstacle snapshot: resync it with the live map
      @stepper.refresh_obstacles

      route_index = @character.move_route_index
      x = @character.x
      y = @character.y
      z = @character.z
      # Same seeding as a fresh legacy Cursor ([bridge, nil, nil]): the search that
      # produced this path used identical assumptions, so the replay cannot be
      # blocked by a sliding/surfing flag the search itself never had
      state = [@character.__bridge, nil, nil]
      last_index = [route.length - 2, route_index + OBSTACLE_DETECTION_RANGE - 1].min
      route[route_index..last_index]&.each do |command|
        step_result = @stepper.step(x, y, z, state, command.code)
        return true unless step_result

        x = step_result[0]
        y = step_result[1]
        z = step_result[2]
        state = step_result[3]
      end

      return false
    end

    class << self
      # Memoized move commands indexed by their code (0..4), engine class at runtime only
      # @param code [Integer] move command code (0 = end of route, 1..4 = directions)
      # @return [RPG::MoveCommand]
      def move_command(code)
        @move_commands ||= Array.new(5) { |index| RPG::MoveCommand.new(index) }
        return @move_commands[code]
      end
    end
  end
end
