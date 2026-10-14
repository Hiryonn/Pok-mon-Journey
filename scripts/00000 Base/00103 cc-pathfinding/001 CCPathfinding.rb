# cc-pathfinding: clean A* rework of the PSDK pathfinding system.
# Pure-Ruby core (Solver + ports), engine access isolated in adapters.
module CCPathfinding
  # Total node/operation budget for one frame (legacy value)
  OPERATION_PER_FRAME = 150
  # Node budget for a single request within one frame (legacy value)
  OPERATION_PER_REQUEST = 50
  # Scheduling cost of a reload step (legacy value)
  COST_RELOAD = 15
  # Scheduling cost of a watch step (legacy value)
  COST_WATCH = 9
  # Scheduling cost of a wait step (legacy value)
  COST_WAIT = 1
  # Frames to wait between two path searches after a failure (legacy value)
  TRY_DELAY = 60
  # Number of path commands checked ahead for obstacles (legacy value)
  OBSTACLE_DETECTION_RANGE = 9
  # Move directions: 1 = down, 2 = left, 3 = right, 4 = up (legacy encoding)
  DIRECTIONS = [1, 2, 3, 4]
  # Hard cap of expanded nodes per search, bounds the no-path worst case
  DEFAULT_NODE_CAP = 10_000

  module_function

  # Pack a position into a single integer (12 bits x, 12 bits y, rest z).
  # Wider than the legacy 10-bit encoding: supports MapLinker worlds up to 4096 tiles.
  # @param x [Integer] x coordinate (0..4095)
  # @param y [Integer] y coordinate (0..4095)
  # @param z [Integer] z coordinate
  # @return [Integer] the packed position
  def pack_position(x, y, z)
    return x | (y << 12) | (z << 24)
  end

  # Extract the x coordinate from a packed position
  # @param position [Integer] value produced by pack_position
  # @return [Integer]
  def unpack_x(position)
    return position & 0xFFF
  end

  # Extract the y coordinate from a packed position
  # @param position [Integer] value produced by pack_position
  # @return [Integer]
  def unpack_y(position)
    return (position >> 12) & 0xFFF
  end

  # Extract the z coordinate from a packed position
  # @param position [Integer] value produced by pack_position
  # @return [Integer]
  def unpack_z(position)
    return position >> 24
  end

  # Multiplier applied to the heuristic (weighted A*). 1 = admissible, optimal
  # paths (default). Higher values trade bounded path suboptimality for far
  # fewer expanded nodes on uniform terrain.
  # @return [Integer, Float]
  def heuristic_weight
    @heuristic_weight ||= 1
    return @heuristic_weight
  end

  # Set the heuristic weight (maker-facing tuning knob)
  # @param value [Integer, Float] 1 keeps optimal paths, higher is greedier
  def heuristic_weight=(value)
    @heuristic_weight = value
  end

  # Lazily created scheduler singleton (composition root)
  # @return [Scheduler]
  def scheduler
    @scheduler ||= Scheduler.new
    return @scheduler
  end
end
