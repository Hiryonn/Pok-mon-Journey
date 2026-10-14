module Battle
  module Effects
    class Status
      class Poison < Status
                
        attr_accessor :double_healing

        def initialize(logic,target,status)
            super
            @double_healing = false
        end
        # Prevent poison from being applied twice
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != self.target
          return if status != :poison && status != :toxic
          return handler.prevent_change do
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 249, target))
          end
        end
        # Apply poison effect on end of turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(target)
          return if target.dead?
          return if target.has_ability?(:magic_guard)
          if target.has_ability?(:poison_heal)
            scene.visual.show_ability(target, true)
            logic.damage_handler.heal(target, poison_effect)
            scene.visual.hide_ability(target)
            return
          end
          if target.effects.has?(:unnatural_remedies)
            @double_healing = false  
            battlers.each do |enemy| 
              @double_healing = true if enemy.bank != 0 && (enemy.poisoned? || enemy.toxiced?)
            end
            logic.damage_handler.heal(target, remedies_effect) if @double_healing == false
            logic.damage_handler.heal(target, poison_effect) if @double_healing == true
            return
          end
          scene.display_message_and_wait(parse_text_with_pokemon(19, 243, target))
          scene.visual.show_rmxp_animation(target, 469 + status_id)
          logic.damage_handler.damage_change(poison_effect, target)
          nil
        end
        # Function giving the name of the effect
        # @return [Symbol]
        def name
          :poison
        end
        private
        # Return the Poison effect on HP of the Pokemon
        # @return [Integer] number of HP loosen
        def poison_effect
          return (target.max_hp / 8).clamp(1, Float::INFINITY)
        end
        def remedies_effect
          return (target.max_hp / 16).clamp(1, Float::INFINITY)
        end
      end
      register(:poison, Poison)
    end
  end
end