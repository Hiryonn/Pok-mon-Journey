module Battle
  class Logic
    class ExpHandler
      class Gen6Formula < BaseFormula
        # Whether the trainer battle bonus is active
        # @return [Boolean]
        def trainer_bonus?
          return true
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
          return 102
        end

        # Whether Pokemon at max level can still gain effort values
        # @return [Boolean]
        def max_level_gains_ev?
          return true
        end
      end
    end
  end
end
