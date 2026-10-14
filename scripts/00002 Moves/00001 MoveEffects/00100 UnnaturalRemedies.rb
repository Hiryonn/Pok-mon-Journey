module Battle
  class Move
      class UnnaturalRemedies < Move

        def move_usable_by_user(user, actual_targets)
          return false unless super
          return show_usage_failure(user) && false if actual_targets.all? {|target| target.effects.has?(:unnatural_remedies)}
          return true 
        end


        def deal_effect(user, actual_target)
          actual_target.each do |target|
            if !target.effects.has?(:unnatural_remedies)
                target.effects.add(Effects::UnnaturalRemedies.new(logic, target, user, self))
                scene.logic.status_change_handler.status_change(:poison, target) if !states.include?(Configs.states.symbol(target.status))
            end
          end
        end
        def states 
          STATES 
        end

        STATES = %i[poison]
      end
      Move.register(:s_unnatural_remedies, UnnaturalRemedies)
  end
end
