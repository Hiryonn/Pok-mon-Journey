module Battle
  class Logic
    class ExpHandler
      class Gen7Formula < BaseFormula
        # Divisor used in the base experience calculation
        # @return [Integer]
        def divisor
          return 5
        end

        # Whether the trade bonus is active
        # @return [Boolean]
        def trade_bonus?
          return true
        end

        # Whether the Lucky Egg bonus is active
        # @return [Boolean]
        def lucky_egg_bonus?
          return true
        end

        # Whether the evolution bonus is active
        # @return [Boolean]
        def evolution_bonus?
          return true
        end

        # Whether the loyalty bonus is active
        # @return [Boolean]
        def loyalty_bonus?
          return true
        end

        # Loyalty value above which the loyalty bonus is applied
        # @return [Integer]
        def loyalty_threshold
          return 220
        end

        # Whether Pokemon at max level can still gain effort values
        # @return [Boolean]
        def max_level_gains_ev?
          return true
        end

        # Offset added after level scaling
        # @return [Integer]
        def experience_offset
          return 1
        end

        # Level multiplier using power 2.5 scaling.
        # Formula: ((2L + 10) / (L + Lr + 10))^2.5
        # where L = enemy level, Lr = receiver level
        # @param enemy_level [Integer] the level of the defeated enemy Pokemon
        # @param receiver_level [Integer] the level of the Pokemon receiving experience
        # @return [Float] the level multiplier
        def calculate_level_multiplier(enemy_level, receiver_level)
          numerator = 2.0 * enemy_level + 10
          denominator = enemy_level + receiver_level + 10
          return (numerator / denominator)**2.5
        end
      end
    end
  end
end
