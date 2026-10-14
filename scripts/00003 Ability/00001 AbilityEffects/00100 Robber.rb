module Battle
  module Effects
    class Ability
      class Robber < Ability
        def on_post_damage_death(handler, hp, target, launcher, skill)
          return unless launcher == @target
          return unless target.battle_stage.any?(&:positive?)

          handler.scene.visual.show_ability(launcher)
          target.battle_stage.each_with_index do |stat_value, index|
            next unless stat_value.positive?
            launcher.set_stat_stage(index, stat_value)
            target.set_stat_stage(index, 0)
          end
          handler.scene.display_message_and_wait("#{launcher.given_name} stole #{target.given_name}'s stat changes!")
        end
      end

      register(:robber, Robber)
    end
  end
end
