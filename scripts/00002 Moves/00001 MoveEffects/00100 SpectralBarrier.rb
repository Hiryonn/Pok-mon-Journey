module Battle
    class Move
        class SpectralBarrier < Move
  
          def move_usable_by_user(user, actual_targets)
            return false unless super
            return show_usage_failure(user) && false if actual_targets.all? {|target| target.effects.has?(:spectral_barrier)}
            return true 
          end
  
  
          def deal_effect(user,  actual_target)
            turn_count = logic.field_terrain == :psychic_terrain ? 3 : 5
            actual_target.each do |target|
              if !target.effects.has?(:spectral_barrier)
                logic.bank_effects[user.bank].add(Effects::SpectralBarrier.new(logic, user.bank, 0, turn_count))
                @scene.display_message_and_wait(parse_text_with_pokemon(400002, 125, user))
                  hp = target.max_hp/4
                  logic.damage_handler.damage_change(hp,user)
              end
            end
          end
        end
        Move.register(:s_spectral_barrier, SpectralBarrier)
    end
  end
  