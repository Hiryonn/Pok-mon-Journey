module Battle
  module Effects
        class Ability 
          class AdrenalineRush < Ability
            def initialize(logic, target, db_symbol)
                super
                @activated = false
                @healing = false
            end

            def on_post_damage(handler, hp, target, launcher, skill)
                return if target != @target || launcher == target
                if @activated == false && target.hp_rate <= 0.33
                    handler.scene.visual.show_ability(target)
                    if handler.logic.stat_change_handler.stat_increasable?(:atk, target)
                        handler.logic.stat_change_handler.stat_change_with_process(:atk, 2, target)
                        @activated = true
                        @healing = true
                    end  
                end
            end

            def on_end_turn_event(logic, scene, battlers)
                return unless battlers.include?(@target)
                return if @target.dead?
                return unless @healing

                if @target.hp_rate <= 0.5
                    heal_amount = (@target.max_hp / 8.0).floor
                    @target.hp += heal_amount
                    scene.display_message_and_wait(parse_text_with_pokemon(400003, 0, @target))
                else
                    scene.display_message_and_wait(parse_text_with_pokemon(400003, 3, @target))
                    logic.stat_change_handler.stat_change_with_process(:atk, -2, @target)
                    @healing = false
                    @activated = false
                end
            end
          end
          register(:adrenaline_rush, AdrenalineRush)
        end
  end
end