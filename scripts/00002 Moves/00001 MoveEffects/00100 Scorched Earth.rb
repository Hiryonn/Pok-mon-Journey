module Battle
  class Move
      class ScorchedEarth < Basic


          def deal_effect(user,  actual_target)
            actual_target.each do |target|
              bank = actual_target.map(&:bank).first
              if !(effect = @logic.bank_effects[bank]&.get(:smouldering_embers))
                logic.add_bank_effect(Effects::SmoulderingEmbers.new(@logic, bank, self))
                logic.scene.display_message_and_wait(parse_text_with_pokemon(400002, 62, target)) 
              end
            end
          end

          def calc_sp_def(user, target)
            ph_move = false
            result = calc_sp_def_basis(user, target, ph_move)
            result = (result * calc_def_stat_modifier(user, target, ph_move)).floor
            logic.each_effects(user, target) do |e|
              result = (result * e.sp_def_multiplier(user, target, self)).floor
            end
            return result
          end

          
      end
      Move.register(:s_scorched_earth, ScorchedEarth)
  end
end
