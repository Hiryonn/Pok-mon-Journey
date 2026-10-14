module Battle
  class Logic
    class ExpHandler
      class Gen8Formula < Gen7Formula
        # Whether the EXP Charm item bonus is active
        # @return [Boolean]
        def experience_charm_bonus?
          return true
        end
      end
    end
  end
end
