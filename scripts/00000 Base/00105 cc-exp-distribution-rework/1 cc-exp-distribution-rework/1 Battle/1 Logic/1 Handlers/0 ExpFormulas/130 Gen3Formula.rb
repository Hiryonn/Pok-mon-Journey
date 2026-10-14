module Battle
  class Logic
    class ExpHandler
      class Gen3Formula < Gen2Formula
        # Whether Pokemon at max level can still gain effort values
        # @return [Boolean]
        def max_level_gains_ev?
          return false
        end
      end
    end
  end
end
