module Battle
  class Move
        class CleanUp < Move
          def move_usable_by_user(user, actual_targets)
            return false unless super
            return show_usage_failure(user) && false if !logic.bank_effects[user.bank].has? {|e| e.entry_hazard?}
            return true 
          end

          def deal_effect(user,  actual_target)
            target_bank = actual_target.map(&:bank).first
            if enemy_poke?(user)
              @logic.scene.display_message_and_wait(parse_text_with_pokemon(400002,122, user))
            else
              @logic.scene.display_message_and_wait(parse_text_with_pokemon(400002,119, user))
            end
            if logic.bank_effects[user.bank].has?{|e| e.class == Effects::StealthRock} && !logic.bank_effects[target_bank].has?{|e| e.class ==  Effects::StealthRock}
              logic.add_bank_effect(Effects::StealthRock.new(logic,target_bank, self)) 
            end
            if logic.bank_effects[user.bank].has?{|e| e.class == Effects::StickyWeb} && !logic.bank_effects[target_bank].has?{|e| e.class ==  Effects::StickyWeb}
              logic.add_bank_effect(Effects::StickyWeb.new(logic,target_bank, user))
            end
            if logic.bank_effects[user.bank].has?{|e| e.class == Effects::SmoulderingEmbers} && !logic.bank_effects[target_bank].has?{|e| e.class ==  Effects::SmoulderingEmbers}
              logic.add_bank_effect(Effects::SmoulderingEmbers.new(logic,target_bank,self)) 
            end
            if logic.bank_effects[user.bank].has?{|e| e.class == Effects::Spikes} 
              target_effect = nil
               logic.bank_effects[user.bank].each {|e| target_effect = e if e.class == Effects::Spikes}
              get_power = target_effect.power
              if !logic.bank_effects[target_bank].has?{|e| e.class ==  Effects::Spikes}
                logic.add_bank_effect(Effects::Spikes.new(logic,target_bank,)) 
                get_power -= 1
              end
              spikes_effect = logic.bank_effects[target_bank]&.get(:spikes)
              get_power.times{spikes_effect.empower}                
            end
            if logic.bank_effects[user.bank].has?{|e| e.class == Effects::ToxicSpikes} 
              target_effect = nil
              logic.bank_effects[user.bank].each {|e| target_effect = e if e.class == Effects::ToxicSpikes}
              get_power = target_effect.power
              if !logic.bank_effects[target_bank].has?{|e| e.class ==  Effects::ToxicSpikes}
                spikes_effect = logic.add_bank_effect(Effects::ToxicSpikes.new(logic,target_bank)) 
                get_power -= 1
              end
              spikes_effect = logic.bank_effects[target_bank]&.get(:toxic_spikes)
              get_power.times{spikes_effect.empower}                
            end
            user.effects.each { |e| e.kill if e.entry_hazard? }
            logic.bank_effects.each_with_index do |bank_effect, bank_index| 
            logic.bank_effects[user.bank].each { |e| e.kill if e.entry_hazard? }
            end
          end

          def enemy_poke?(pokemon)
            return false unless $scene.is_a?(Battle::Scene)
            return false unless pokemon
            return pokemon.bank != 0 if pokemon.is_a?(PFM::PokemonBattler)
            return pokemon.position.nil? || pokemon.position < 0
          end
          
          def calc_factor(target)
            type = [self.type]
            @effectiveness = -1
            n = calc_type_n_multiplier(target, :type1, type) * calc_type_n_multiplier(target, :type2, type) * calc_type_n_multiplier(target, :type3, type)
            return n
          end
        end
      Move.register(:s_clean_up, CleanUp)
  end
end