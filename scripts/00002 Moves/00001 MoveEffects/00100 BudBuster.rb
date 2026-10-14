module Battle
  class Move
      class BudBuster < Basic

        def move_usable_by_user(user, actual_targets)
          return false unless super
          return true 
        end


        def deal_effect(user,  actual_target)
          actual_target.each do |target|
            user.effects.add(Effects::BudBuster.new(logic, user, user, self,2))
          end
        end
      end
      Move.register(:s_bud_buster, BudBuster)
  end
end
