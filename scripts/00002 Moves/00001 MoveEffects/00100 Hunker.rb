module Battle
  class Move
      class Hunker < Move

        def move_usable_by_user(user, actual_targets)
          return false unless super
          return show_usage_failure(user) && false if user.effects.has?(:hunker)
          return true 
        end


        def deal_effect(user,  actual_target)
          actual_target.each do |target|
            if !target.effects.has?(:hunker)
                target.effects.add(Effects::Hunker.new(logic, target, user, self,3))
                stats.each {|stat,power| logic.stat_change_handler.stat_change_with_process(stat,power, target, user, self)}
            end
          end
        end
        def stats 
            return STATS
        end

        STATS = {dfe: 2, dfs: 2, atk: -2, ats: -2}
      end
      Move.register(:s_hunker, Hunker)
  end
end
