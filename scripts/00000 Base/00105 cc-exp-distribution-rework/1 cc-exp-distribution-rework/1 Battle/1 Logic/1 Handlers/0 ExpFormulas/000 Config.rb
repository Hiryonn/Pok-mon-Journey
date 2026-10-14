module Battle
  class Logic
    class ExpHandler
      class BaseFormula
        # Divisor used in the base experience calculation
        # @return [Integer]
        def divisor
          return 7
        end

        # Whether Pokemon at max level can still gain effort values
        # @return [Boolean]
        def max_level_gains_ev?
          return false
        end

        # Loyalty value above which the loyalty bonus is applied
        # @return [Integer]
        def loyalty_threshold
          return 255
        end

        # Value of the trainer multiplier
        # @return [Float]
        def trainer_multiplier_value
          return 1.5
        end

        # Value of the trade multiplier
        # @return [Float]
        def trade_multiplier_value
          return 1.5
        end

        # Value of the Lucky Egg multiplier
        # @return [Float]
        def lucky_egg_multiplier_value
          return 1.5
        end

        # Value of the evolution multiplier
        # @return [Float]
        def evolution_multiplier_value
          return 1.2
        end

        # Value of the loyalty multiplier
        # @return [Float]
        def loyalty_multiplier_value
          return 1.2
        end

        # Value of the EXP Charm multiplier
        # @return [Float]
        def experience_charm_multiplier_value
          return 1.5
        end

        # Value of the fought multiplier when the receiver did not participate
        # @return [Float]
        def fought_multiplier_value
          return 0.5
        end

        # Offset added after level scaling (0 for flat formulas, 1 for scaled formulas)
        # @return [Integer]
        def experience_offset
          return 0
        end
      end
    end
  end
end
