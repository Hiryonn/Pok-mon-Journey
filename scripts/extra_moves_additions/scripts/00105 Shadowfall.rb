# Shadowfall (s_extra_shadowfall) : crée la météo « Ciel Sombre » (Dark Overcast).
#   - 5 tours (réglage ExtraMovesAdditions::DARK_OVERCAST_TURNS), ne reste pas sur la carte après le combat
#   - les capacités de type Ténèbres sont renforcées de 50 %
#   - Lune, Synthèse et Rayon Lune (s_heal_weather) soignent deux fois moins
#   - Spectre / Ombre Portée Force (Phantom Force, Shadow Force) frappent tout de suite, sans tour de préparation
#   - Lance-Soleil et Lame Solaire (s_solar_beam) échouent
# Le modèle est le Ciel Obscur du plugin Obscurs. Chaque ajout est protégé : si un nom du moteur diffère, l'effet est ignoré
# et l'erreur écrite dans le journal, le combat continue.
module ExtraMovesAdditions
  DARK_OVERCAST_TURNS = 5
  DARK_OVERCAST_BOOST = 1.5

  module_function

  def dark_overcast?
    return $env.current_weather_db_symbol == :dark_overcast
  rescue StandardError
    return false
  end
end

module Battle
  class Move
    # Shadowfall : (dégâts éventuels,) puis Ciel Sombre. La hausse de critique se règle dans Studio (movecriticalRate = 2).
    class ExtraDarkOvercast < Basic
      private

      def deal_damage(user, actual_targets)
        return true if status?

        return super
      end

      def move_usable_by_user(user, targets)
        return false unless super

        handler = @logic.weather_change_handler
        return show_usage_failure(user) && false unless handler.weather_appliable?(:dark_overcast)

        return true
      end

      def deal_effect(user, actual_targets)
        super
        @logic.weather_change_handler.weather_change(:dark_overcast, ExtraMovesAdditions::DARK_OVERCAST_TURNS)
      end
    end
    Move.register(:s_extra_shadowfall, ExtraDarkOvercast)

    # Lance-Soleil / Lame Solaire échouent sous le Ciel Sombre
    module DarkOvercastSolarFail
      private

      def move_usable_by_user(user, targets)
        return false unless super

        if ExtraMovesAdditions.dark_overcast? && %i[solar_beam solar_blade].include?(db_symbol)
          return show_usage_failure(user) && false
        end

        return true
      end
    end
    prepend DarkOvercastSolarFail

    # Spectre / Ombre Portée Force : pas de tour de préparation
    if const_defined?(:TwoTurnBase)
      module DarkOvercastInstantHit
        def shortcut?(*args)
          return true if ExtraMovesAdditions.dark_overcast? && %i[phantom_force shadow_force].include?(db_symbol)

          return super
        end
      end
      TwoTurnBase.prepend(DarkOvercastInstantHit)
    end

    # Lune / Synthèse / Rayon Lune : soin divisé par deux
    if const_defined?(:HealWeather)
      module DarkOvercastHealPenalty
        def proceed(*args, &block)
          Thread.current[:extra_dark_heal] = ExtraMovesAdditions.dark_overcast?
          return super
        ensure
          Thread.current[:extra_dark_heal] = false
        end
      end
      HealWeather.prepend(DarkOvercastHealPenalty)
    end
  end

  class Logic
    class DamageHandler
      module DarkOvercastHeal
        def heal(target, hp, *args, **kwargs, &block)
          hp = [hp / 2, 1].max if Thread.current[:extra_dark_heal] && hp.is_a?(Integer)
          return super(target, hp, *args, **kwargs, &block)
        end
      end
      prepend DarkOvercastHeal
    end

    class WeatherChangeHandler
      module DarkOvercastMessages
        private

        def show_weather_message(last_weather, current_weather)
          if current_weather == :dark_overcast && last_weather != :dark_overcast
            return @scene.display_message_and_wait(ExtraMovesAdditions.text('Le ciel s’assombrit !', 'The sky turned dark!'))
          elsif last_weather == :dark_overcast && current_weather == :none
            return @scene.display_message_and_wait(ExtraMovesAdditions.text('Le ciel s’éclaircit.', 'The dark clouds cleared.'))
          end

          super
        end
      end
      prepend DarkOvercastMessages
    end
  end

  module Effects
    class DarkOvercast < Weather
      def on_end_turn_event(logic, scene, battlers)
        return logic.weather_change_handler.weather_change(:none, 0) if $env.decrease_weather_duration
      end

      def mod1_multiplier(user, target, move)
        type = GameData::Type[move.definitive_type(user, target)]
        return ExtraMovesAdditions::DARK_OVERCAST_BOOST if type && type.db_symbol == :dark

        return 1
      rescue StandardError
        return 1
      end
    end
    Weather.register(:dark_overcast, DarkOvercast)
  end
end

# Météo : Ciel Sombre ajouté à la liste des météos
PFM::Environment::WEATHER_NAMES << :dark_overcast unless PFM::Environment::WEATHER_NAMES.include?(:dark_overcast)

module PFM
  class Environment
    def dark_overcast?
      return current_weather_db_symbol == :dark_overcast
    end

    module ExtraDarkOvercastWeather
      # Le Ciel Sombre ne reste pas sur la carte après le combat
      def apply_weather(id, duration = nil)
        sky = PFM::Environment::WEATHER_NAMES.index(:dark_overcast)
        old = @weather
        super
        @weather = old if (id == :dark_overcast || id == sky) && old != sky
      end
    end
    prepend ExtraDarkOvercastWeather
  end
end
