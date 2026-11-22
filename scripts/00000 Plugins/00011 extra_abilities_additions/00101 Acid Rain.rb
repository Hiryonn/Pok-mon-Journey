# Pluie Acide (météo ajoutée pour le talent Acid Cloud) : 5 tours, blesse (1/16 des PV) tous les Pokémon sauf les Poison.
# Modèle : le Ciel Obscur du plugin Obscurs. Elle ne reste pas sur la carte après le combat.
module Battle
  module Effects
    class AcidRain < Weather
      def on_end_turn_event(logic, scene, battlers)
        return logic.weather_change_handler.weather_change(:none, 0) if $env.decrease_weather_duration

        scene.visual.show_weather_animation(:rain) rescue nil
        return if logic.weather_effects_disabled?

        scene.display_message_and_wait(ExtraAbilitiesAdditions.text("La pluie acide blesse les Pokémon !", "The acid rain is hurting the Pokémon!"))
        battlers.each do |battler|
          next if battler.dead? || battler.type_poison?
          next if battler.has_ability?(:magic_guard) || battler.effects.has?(:out_of_reach_base)

          logic.damage_handler.damage_change((battler.max_hp / 16).clamp(1, Float::INFINITY), battler)
        end
      end
    end
    Weather.register(:acid_rain, AcidRain)
  end

  class Logic
    class WeatherChangeHandler
      module AcidRainMessages
        private

        def show_weather_message(last_weather, current_weather)
          if current_weather == :acid_rain && last_weather != :acid_rain
            return @scene.display_message_and_wait(ExtraAbilitiesAdditions.text('Une pluie acide se met à tomber !', 'Acid rain started to fall!'))
          elsif last_weather == :acid_rain && current_weather == :none
            return @scene.display_message_and_wait(ExtraAbilitiesAdditions.text('La pluie acide s’est arrêtée.', 'The acid rain stopped.'))
          end

          super
        end
      end
      prepend AcidRainMessages
    end
  end
end

PFM::Environment::WEATHER_NAMES << :acid_rain unless PFM::Environment::WEATHER_NAMES.include?(:acid_rain)

module PFM
  class Environment
    def acid_rain?
      return current_weather_db_symbol == :acid_rain
    end

    module ExtraAcidRainWeather
      # La Pluie Acide ne reste pas sur la carte après le combat
      def apply_weather(id, duration = nil)
        sky = PFM::Environment::WEATHER_NAMES.index(:acid_rain)
        old = @weather
        super
        @weather = old if (id == :acid_rain || id == sky) && old != sky
      end
    end
    prepend ExtraAcidRainWeather
  end
end
