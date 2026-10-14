module Battle
  module Effects
    class Ability
      class DeathsWitness < Ability
        def on_post_damage_death(handler, hp, target, launcher, skill)
          return if @target.dead? || target == @target

          if handler.logic.stat_change_handler.stat_increasable?(:spd, @target)
            handler.scene.visual.show_ability(@target)
            handler.scene.display_message_and_wait(
              parse_text_with_pokemon(400003, 30, @target)
            )
            handler.logic.stat_change_handler.stat_change_with_process(:spd, 1, @target)
          end
        end
      end
      register(:deaths_witness, DeathsWitness)
    end
  end
end
