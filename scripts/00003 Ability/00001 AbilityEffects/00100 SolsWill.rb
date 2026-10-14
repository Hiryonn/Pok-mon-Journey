module Battle
  module Effects
    class Ability
      class SolsWill < Ability
        WEATHERS = %i[hardsun hardrain wind]

        def on_damage_prevention(handler, hp, target, launcher, skill)
          return if target != @target

          if %i[rain_dance sunny_day hail sandstorm].include?(skill&.db_symbol)
            return handler.prevent_change do
              handler.scene.visual.show_ability(target)
              handler.scene.display_message_and_wait(parse_text_with_pokemon(18, temps, target))
            end
          end

          return unless typeskill(skill) && env?
          return unless launcher&.can_be_lowered_or_canceled?

          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(18, prevent, target))
          end
        end

        def on_switch_event(handler, who, with)
          if with == @target
            weather_handler = handler.logic.weather_change_handler
            return unless weather_handler.weather_appliable?(env)

            handler.scene.visual.show_ability(with)
            weather_handler.weather_change(env, nil)
            handler.scene.visual.show_rmxp_animation(with, anim)
          elsif who == @target
            handler.logic.weather_change_handler.weather_change(:none, 0)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(18, msg, who))
          end
        end

        def on_weather_prevention(handler, weather_type, last_weather)
          return if WEATHERS.include?(weather_type)

          return handler.prevent_change do
            handler.scene.visual.show_ability(@target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(18, temps, target))
          end
        end

        private

        def env?
          @logic.weather_effect.symbol == :hardsun
        end

        def typeskill(skill)
          skill&.type == data_type(:water).id
        end

        def env
          :hardsun
        end

        def anim
          493 
        end

        def msg
          145 
        end

        def temps
          149 
        end

        def prevent
          146 
        end
      end

      register(:sols_will, SolsWill)
    end
  end
end
