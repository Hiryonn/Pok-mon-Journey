module Battle
  module Effects
    class Ability
      class DivineBlessing < Ability

        WEATHERS = %i[hardsun hardrain strong_winds radiance]

        def on_switch_event(handler, who, with)
          if with == @target
            weather_handler = handler.logic.weather_change_handler
            return unless weather_handler.weather_appliable?(env)
            handler.scene.visual.show_ability(with)
            weather_handler.weather_change(env, nil)
            handler.scene.visual.show_rmxp_animation(with, anim)
          else
            if who == @target
              return unless $env.current_weather_db_symbol == env
              return if handler.logic.all_alive_battlers.any? { |battler| primal_weather_ability?(battler) && battler != @target }
              handler.logic.weather_change_handler.weather_change(:none, 0)
              handler.scene.display_message_and_wait(parse_text(400001, 14))
            end
          end
        end
        # Function called after damages were applied and when target died (post_damage_death)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage_death(handler, hp, target, launcher, skill)
          return if target != @target
          return unless $env.radiance?
          return if handler.logic.all_alive_battlers.any? { |battler| primal_weather_ability?(battler) && battler != @target }
          handler.logic.weather_change_handler.weather_change(:none, 0)
          handler.scene.display_message_and_wait(parse_text(400001, 14))
        end
        # Function called after the weather was changed (on_post_weather_change)
        # @param handler [Battle::Logic::WeatherChangeHandler]
        # @param weather_type [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog
        # @param last_weather [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog
        def on_post_weather_change(handler, weather_type, last_weather)
          return if WEATHERS.include?($env.current_weather_db_symbol)
          handler.scene.visual.show_ability(@target)
          handler.logic.weather_change_handler.weather_change(env, nil)
          handler.scene.visual.show_rmxp_animation(@target, anim)
        end
        private
        # Weather concerned
        # @return [Symbol] weather symbol
        def env
          return :radiance
        end
        # Weather setting ability
        # @return [Symbol] ability db_symbol
        def primal_weather_ability?(pokemon)
          return pokemon.ability_db_symbol == :divine_blessing
        end
        # Weather setup animation id
        # @return [Integer] id
        def anim
          return 492
        end
      end
      register(:divine_blessing,  DivineBlessing)
    end
  end
end
