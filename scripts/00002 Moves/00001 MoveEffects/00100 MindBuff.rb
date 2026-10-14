module Battle
    class Move
        class MindBuff < Move
  
          def move_usable_by_user(user, actual_targets)
            return false unless super
            switchable_allies = logic.alive_battlers_without_check(user.bank).count { |pokemon| pokemon != user && pokemon.party_id == user.party_id }
            return show_usage_failure(user) && false unless switchable_allies > 0
            return show_usage_failure(user) && false if actual_targets.all? {|target| target.effects.has?(:mind_buff)}
            return true 
          end
  
  
          def deal_effect(user,  actual_target)
            actual_target.each do |target|
              if !target.effects.has?(:mind_buff)
                  logic.terrain_effects.add(Effects::MindBuff.new(logic, target, user, self))
                  logic.request_switch(user, nil)
              end
            end
          end
        end
        Move.register(:s_mind_buff, MindBuff)
    end
end
  


