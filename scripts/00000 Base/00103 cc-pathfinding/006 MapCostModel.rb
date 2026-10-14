module CCPathfinding
  # Cost model port reading the legacy tag weight strategies at runtime.
  class MapCostModel
    # @param tags_weight_name [Symbol] name of a Pathfinding::TagsWeight constant
    def initialize(tags_weight_name)
      @tags_weight_name = tags_weight_name
    end

    # Weight of the tile at the given coordinates
    # @param x [Integer] x coordinate of the tile
    # @param y [Integer] y coordinate of the tile
    # @return [Integer] weight of the tile's system tag
    def cost(x, y)
      return weights[$game_map.system_tag(x, y)]
    end

    private

    # Resolve the weight table, with the legacy fallback semantics
    # @return [Hash] tag id to weight (unknown strategy name falls back to DEFAULT)
    def weights
      return @weights if @weights

      if Pathfinding::TagsWeight.const_defined?(@tags_weight_name)
        @weights = Pathfinding::TagsWeight.const_get(@tags_weight_name)
      else
        @weights = Pathfinding::TagsWeight::DEFAULT
      end
      return @weights
    end
  end
end
