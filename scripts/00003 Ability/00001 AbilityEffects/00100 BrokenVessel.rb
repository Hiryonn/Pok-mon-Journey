module Battle
  module Effects
        class Ability 
          class BrokenVessel < Ability
            def on_post_damage(handler, hp, target, launcher, skill)
                return if target != @target || launcher == target

                if target.hp_rate <= 0.5
                    handler.scene.visual.show_ability(target)
                    handler.scene.display_message_and_wait(
                        parse_text_with_pokemon(400003, 27, target)
                    )
                    if handler.logic.stat_change_handler.stat_increasable?(:atk, target)
                        handler.logic.stat_change_handler.stat_change_with_process(:atk, 1, target)
                    end
                    if handler.logic.stat_change_handler.stat_increasable?(:ats, target)
                        handler.logic.stat_change_handler.stat_change_with_process(:ats, 1, target)
                    end
                    if handler.logic.stat_change_handler.stat_increasable?(:spd, target)
                        handler.logic.stat_change_handler.stat_change_with_process(:spd, 1, target)
                    end
                    if handler.logic.stat_change_handler.stat_decreasable?(:dfe, target)
                        handler.logic.stat_change_handler.stat_change_with_process(:dfe, -1, target)
                    end
                    if handler.logic.stat_change_handler.stat_decreasable?(:dfs, target)
                        handler.logic.stat_change_handler.stat_change_with_process(:dfs, -1, target)
                    end      
                end
            end
          end
          register(:broken_vessel, BrokenVessel)
        end
  end
end