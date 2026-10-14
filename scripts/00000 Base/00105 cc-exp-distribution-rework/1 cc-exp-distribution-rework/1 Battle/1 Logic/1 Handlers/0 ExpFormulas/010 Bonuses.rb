module Battle
  class Logic
    class ExpHandler
      class BaseFormula
        # Whether the trainer battle bonus is active
        # @return [Boolean]
        def trainer_bonus?
          return false
        end

        # Whether the trade bonus is active
        # @return [Boolean]
        def trade_bonus?
          return false
        end

        # Whether the Lucky Egg bonus is active
        # @return [Boolean]
        def lucky_egg_bonus?
          return false
        end

        # Whether the evolution bonus is active
        # @return [Boolean]
        def evolution_bonus?
          return false
        end

        # Whether the loyalty bonus is active
        # @return [Boolean]
        def loyalty_bonus?
          return false
        end

        # Whether the EXP Charm item bonus is active
        # @return [Boolean]
        def experience_charm_bonus?
          return false
        end
      end
    end
  end
end
