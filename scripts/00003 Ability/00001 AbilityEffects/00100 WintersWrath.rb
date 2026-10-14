module Battle
  module Effects
    class Ability
      class WintersWrath < Ability
        def on_post_damage_death(handler, hp, target, launcher, skill)
          # return unless launcher == @target
          # return if target == @target || hp > 0
          return unless skill&.type_ice?

          weather_handler = handler.logic.weather_change_handler
          return unless weather_handler.weather_appliable?(:hail)

          handler.scene.visual.show_ability(@target)
          weather_handler.weather_change(:hail, nil)
          handler.scene.display_message_and_wait(parse_text_with_pokemon(18, 1080, @target)) # "A fierce snowstorm is raging!"
        end

        def sp_atk_multiplier(user, target, move)
          return 1 unless user == @target
          return 1 unless @logic.weather_effect.db_symbol == :hail

          return 1.2
        end
      end

      register(:winters_wrath, WintersWrath)
    end
  end
end
