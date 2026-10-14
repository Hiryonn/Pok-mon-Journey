module Battle
    class Move
        #cannot work without SilkBall_Dependancies.rb
        class SilkBall < Move


    # Function that deals the damage to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_damage(user, actual_targets)
        return true if status?
        raise 'Badly configured move, it should have positive power' if power < 0
        successful_damages = actual_targets.map do |target|
          hp = damages(user, target)
          damage_handler = @logic.damage_handler
          damage_handler.damage_change_with_process(hp, target, user, self) do
            scene.display_message_and_wait(actual_targets.size == 1 ? parse_text(18, 84) : parse_text_with_pokemon(19, 384, target)) if critical_hit?
            efficent_message(effectiveness, target) if hp > 0
          end
          recoil(hp, user) if recoil? && damage_handler.instance_variable_get(:@reason).nil?
          next(false) if damage_handler.instance_variable_get(:@reason)
          next(true)
        end
        new_targets = actual_targets.map.with_index { |target, index| successful_damages[index] && target }.select { |target| target }
        actual_targets.clear.concat(new_targets)
        return successful_damages.include?(true)
      end
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        if !status? && user.can_be_lowered_or_canceled?(target = actual_targets.find { |t| t.has_ability?(:shield_dust) })
          @scene.visual.show_ability(target) if data.effect_chance > 0 && target.alive?
          return false
        end
        n = 1
        scene.logic.each_effects(user).each do |e|
          n *= e.effect_chance_modifier(self)
        end
        return bchance?((effect_chance * n) / 100.0) && super
      end
            def fainted_this_turn?(target)
                return true if target.dead?
            end

            def deal_effect(user, actual_targets)
                if effect_usable_by_user(user, actual_targets) == true
                    actual_targets.each do |target|
                        if fainted_this_turn?(target)
                            bank = actual_targets.map(&:bank).first
                            @logic.add_bank_effect(Effects::StickyWeb.new(@logic, bank, user))
                            @scene.display_message_and_wait(parse_text_with_pokemon(400002, 7, target))           
                        end
                    end
                end

            end

            def effect_usable_by_user(user, targets)
                return false unless super
                target_bank = user.bank == 1 ? 0 : 1
                if @logic.bank_effects[target_bank]&.get(:sticky_web)
                  return false
                end
                return true
            end
 
        end
        Move.register(:s_silk_ball , SilkBall)
        
    end
end