module Battle
    class Move
        class Bloodlust < Basic
            STATS = {atk: 1, spd: 1}  

  
            def multi_turn?
              return true
            end

            def on_move_failure(user, targets, reason)
              effect = user.effects.get(:force_next_move_base)
              return if effect.nil?
              return effect.kill unless effect.triggered?
            end
          

          def deal_effect(user, actual_targets)
            effect = user.effects.get(:force_next_move_base)
              if effect 
                logic.scene.display_message_and_wait(parse_text_with_pokemon(400002, 94, user)) if effect.triggered?
                user.battle_stage[0] -= 1 if effect.triggered?
                user.battle_stage[2] -= 1 if effect.triggered?
                logic.status_change_handler.status_change_with_process(:confusion, user, nil, self) if effect.triggered? && !user.confused?
              else
                if !user.effects.has?(:bloodlust)
                  user.effects.add(Effects::Bloodlust.new(logic, user, user, self, 3)) 
                  logic.scene.display_message_and_wait(parse_text_with_pokemon(400002, 88, user)) 
                  stats.each {|stat, power| logic.stat_change_handler.stat_change_with_process(stat,power,user,user, self)}
                end
                user.effects.add(Effects::ForceNextMoveBase.new(logic, user, self, actual_targets, 3))
              end
          end

          def stats 
            return STATS
          end

          def usage_message(user)
            if !user.effects.has?(:bloodlust)
              super
            else
              if user.effects.get(:bloodlust).count_left == 2
                return scene.display_message_and_wait(parse_text_with_pokemon(400002,91, user))
              end
            end
          end
        end

          
        Move.register(:s_bloodlust, Bloodlust)  
        public
    end
end
  