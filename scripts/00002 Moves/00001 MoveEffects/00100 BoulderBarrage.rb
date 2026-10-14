module Battle
    class Move
        class BoulderBarrage < MultiHit

          def deal_damage(user, actual_targets)
            @user = user
            @actual_targets = actual_targets
            @nb_hit = 0
            @hit_amount = hit_amount(user, actual_targets)
            @acc_multihit_check = true
            @hit_amount.times.count do |i|
              next(false) unless actual_targets.all?(&:alive?)
              next(false) if user.dead?
              if @nb_hit != 0 
                @acc_multihit_check = false unless !(hit_target = proceed_move_accuracy(user, actual_targets)).empty? || (on_move_failure(user, actual_targets, :accuracy) && false)
              end  
              next(false) unless @acc_multihit_check == true
              @nb_hit += 1
              play_animation(user, actual_targets) if i > 0
              actual_targets.each do |target|
                hp = damages(user, target)
                @logic.damage_handler.damage_change_with_process(hp, target, user, self) do
                  if critical_hit?
                    scene.display_message_and_wait(actual_targets.size == 1 ? parse_text(18, 84) : parse_text_with_pokemon(19, 384, target))
                  else
                    if hp > 0 && i == @hit_amount - 1
                      efficent_message(effectiveness, target)
                    end
                  end
                end
                recoil(hp, user) if recoil?
              end
              next(true)
            end
            @scene.display_message_and_wait(parse_text(18, 33, PFM::Text::NUMB[1] => @nb_hit.to_s))
            return false if user.dead?
            return true
          end

          def hit_amount(user, actual_targets)
            return 3
          end

          def damages(user,target)
            hp_dealt = super
            hp_dealt = hp_dealt * 2 if @nb_hit == 2
            hp_dealt = hp_dealt * 3 if @nb_hit == 3
            return hp_dealt
          end
          
           
    end
        Move.register(:s_boulder_barrage , BoulderBarrage)
        
    end
end