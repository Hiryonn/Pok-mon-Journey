module CCPathfinding
  # Incremental A* over an abstract grid graph.
  # Knows nothing about the game engine: only the three ports.
  # visited doubles as the backtrace store: {packed position => direction | parent << 4}.
  # Seen-at-insertion semantics (no reopening), matching the legacy dedup behavior.
  class Solver
    # Directions of the path, filled when step_batch returns :found
    # @return [Array<Integer>, nil]
    attr_reader :path
    # Number of nodes expanded since start
    # @return [Integer]
    attr_reader :nodes_expanded

    # @param stepper [#step, #initial_state] simulates one move on the map
    # @param cost_model [#cost] gives the weight of an arrival tile
    # @param goal [#reached?, #heuristic] decides termination and guides the search
    # @param node_cap [Integer] maximum nodes expanded before giving up
    # @param heuristic_weight [Integer, Float] 1 keeps optimal paths, higher is greedier
    def initialize(stepper:, cost_model:, goal:, node_cap: DEFAULT_NODE_CAP, heuristic_weight: 1)
      @stepper = stepper
      @cost_model = cost_model
      @goal = goal
      @node_cap = node_cap
      @heuristic_weight = heuristic_weight
      @open = BinaryHeap.new
      @visited = {}
      @nodes_expanded = 0
      @path = nil
    end

    # Reset the search and seed it with the start position
    # @param x [Integer] start x coordinate
    # @param y [Integer] start y coordinate
    # @param z [Integer] start z coordinate
    # @param state [Object] opaque stepper state at the start position
    def start(x, y, z, state)
      @open.clear
      @visited.clear
      @path = nil
      @nodes_expanded = 0
      @visited[CCPathfinding.pack_position(x, y, z)] = -1
      # Node: [g, x, y, z, state, last_direction]
      @open.push(@heuristic_weight * @goal.heuristic(x, y), [0, x, y, z, state, -1])
    end

    # Expand up to node_budget nodes
    # @param node_budget [Integer] maximum nodes to expand during this call
    # @return [Symbol] :found, :not_found or :running
    def step_batch(node_budget)
      spent = 0
      while spent < node_budget
        return :not_found if @open.empty? || @nodes_expanded >= @node_cap

        node = @open.pop
        if @goal.reached?(node[1], node[2], node[3])
          @path = backtrace(node[1], node[2], node[3])
          return :found
        end
        expand(node)
        @nodes_expanded += 1
        spent += 1
      end

      return :running
    end

    private

    # Open the unseen neighbors of a node in the four directions
    # @param node [Array] [g, x, y, z, state, last_direction]
    def expand(node)
      g = node[0]
      x = node[1]
      y = node[2]
      z = node[3]
      state = node[4]
      last_direction = node[5]
      parent_code_base = CCPathfinding.pack_position(x, y, z) << 4
      DIRECTIONS.each do |direction|
        step_result = @stepper.step(x, y, z, state, direction)
        next unless step_result

        new_x = step_result[0]
        new_y = step_result[1]
        new_z = step_result[2]
        position = CCPathfinding.pack_position(new_x, new_y, new_z)
        next if @visited.key?(position)

        @visited[position] = direction | parent_code_base
        new_g = g + @cost_model.cost(new_x, new_y) - (last_direction == direction ? 1 : 0)
        priority = new_g + @heuristic_weight * @goal.heuristic(new_x, new_y)
        @open.push(priority, [new_g, new_x, new_y, new_z, step_result[3], direction])
      end
    end

    # Rebuild the direction list by walking the visited codes back to the start
    # @param x [Integer] x coordinate of the reached position
    # @param y [Integer] y coordinate of the reached position
    # @param z [Integer] z coordinate of the reached position
    # @return [Array<Integer>] directions from the start to the reached position
    def backtrace(x, y, z)
      path = []
      code = @visited[CCPathfinding.pack_position(x, y, z)]
      until code == -1
        path.unshift(code & 0xF)
        code = @visited[code >> 4]
      end

      return path
    end
  end
end
