# Pokémon Obscurs : capacités Obscures et Ciel Obscur
#   s_shadow_basic    dégâts (Choc / Rafale / Vague / Tempête / Feu / Foudre / Froid / Coup / Rush Obscur...)
#   s_shadow_recoil   Fin Obscure : contrecoup de la moitié des PV restants
#   s_shadow_sky      Ciel Obscur : météo de 5 tours (les capacités Obscures sont renforcées, les Pokémon normaux
#                     perdent 1/16 de leurs PV à chaque tour)
#   s_shadow_half     Moitié Obscure : tous les Pokémon perdent la moitié de leurs PV
#   s_shadow_cantflee Blocage Obscur : les adversaires ne peuvent plus fuir ni être changés
#   s_shadow_stat     Brume / Panique / Baisse Obscure : baisses de stats et statuts de Studio
#   s_shadow_defog    Mue Obscure : retire Protection, Mur Lumière, Rune Protect... des deux côtés
# Efficacité : réglages shadow_vs_normal (×2) et shadow_vs_shadow (×0,5), sans bonus du même type.
module Battle
  class Move
    # Règles communes aux capacités Obscures
    module ShadowMove
      def type_modifier(user, target)
        return shadow_multiplier(target)
      end

      private

      def shadow_multiplier(target)
        return Obscurs.number(target.shadow? ? 'shadow_vs_shadow' : 'shadow_vs_normal')
      end

      def calc_stab(user, types)
        return 1
      end

      def calc_type_n_multiplier(target, type_to_check, types)
        return 1 unless type_to_check == :type1

        result = shadow_multiplier(target)
        @effectiveness *= result if @effectiveness >= 0
        return result
      end
    end

    class ShadowBasic < Basic
      include ShadowMove
    end
    Move.register(:s_shadow_basic, ShadowBasic)

    class ShadowRecoil < RecoilMove
      include ShadowMove

      def recoil_factor
        return 2
      end

      def recoil_applies_on_user_hp?
        return true
      end
    end
    Move.register(:s_shadow_recoil, ShadowRecoil)

    class ShadowStat < StatusStat
      include ShadowMove
    end
    Move.register(:s_shadow_stat, ShadowStat)

    class ShadowCantSwitch < CantSwitch
      include ShadowMove
    end
    Move.register(:s_shadow_cantflee, ShadowCantSwitch)

    class ShadowSky < Move
      include ShadowMove

      private

      def move_usable_by_user(user, targets)
        return false unless super

        handler = @logic.weather_change_handler
        return show_usage_failure(user) && false unless handler.weather_appliable?(:shadow_sky)

        return true
      end

      def deal_effect(user, actual_targets)
        @logic.weather_change_handler.weather_change(:shadow_sky, Obscurs.setting('shadow_sky_turns').to_i)
      end
    end
    Move.register(:s_shadow_sky, ShadowSky)

    class ShadowHalf < Move
      include ShadowMove

      private

      def deal_damage(user, actual_targets)
        @logic.all_alive_battlers.each do |battler|
          next if battler.hp <= 1

          @logic.damage_handler.damage_change((battler.hp / 2).clamp(1, battler.hp - 1), battler)
        end
        @scene.display_message_and_wait(Obscurs.t('Les PV de tous les Pokémon ont été divisés par deux !',
                                                  "Each Pokémon's HP was halved!"))
        return true
      end
    end
    Move.register(:s_shadow_half, ShadowHalf)

    class ShadowDefog < Move
      include ShadowMove
      SHADOW_SHED = %i[light_screen reflect safeguard mist aurora_veil].freeze

      private

      def deal_effect(user, actual_targets)
        removed = false
        @logic.bank_effects.each do |bank_effect|
          bank_effect.each do |effect|
            next unless SHADOW_SHED.include?(effect.name)

            effect.kill
            removed = true
          end
        end
        return unless removed

        @scene.display_message_and_wait(Obscurs.t('Les protections ont disparu !', 'The barriers vanished!'))
      end
    end
    Move.register(:s_shadow_defog, ShadowDefog)
  end

  module Effects
    # Ciel Obscur
    class ShadowSky < Weather
      def on_end_turn_event(logic, scene, battlers)
        return logic.weather_change_handler.weather_change(:none, 0) if $env.decrease_weather_duration

        scene.visual.show_weather_animation(:shadow_sky)
        return if logic.weather_effects_disabled?

        scene.display_message_and_wait(Obscurs.t('Le Ciel Obscur fait souffrir les Pokémon !', 'The shadowy aura is hurting the Pokémon!'))
        battlers.each do |battler|
          next if battler.dead? || battler.shadow?
          next if battler.has_ability?(:magic_guard) || battler.effects.has?(:out_of_reach_base)

          logic.damage_handler.damage_change((battler.max_hp / 16).clamp(1, Float::INFINITY), battler)
        end
      end

      def mod1_multiplier(user, target, move)
        return Obscurs.number('shadow_sky_boost') if move.is_a?(Battle::Move::ShadowMove)

        return 1
      end
    end
    Weather.register(:shadow_sky, ShadowSky)
  end

  class Logic
    class WeatherChangeHandler
      module ObscursMessages
        private

        def show_weather_message(last_weather, current_weather)
          if current_weather == :shadow_sky && last_weather != :shadow_sky
            return @scene.display_message_and_wait(Obscurs.t('Un ciel obscur recouvre le terrain !', 'A shadowy aura filled the sky!'))
          elsif last_weather == :shadow_sky && current_weather == :none
            return @scene.display_message_and_wait(Obscurs.t('Le Ciel Obscur s’est dissipé.', 'The shadowy aura faded away!'))
          end

          super
        end
      end
      prepend ObscursMessages
    end
  end
end

# Météo : Ciel Obscur après la neige
PFM::Environment::WEATHER_NAMES << :shadow_sky unless PFM::Environment::WEATHER_NAMES.include?(:shadow_sky)

module PFM
  class Environment
    def shadow_sky?
      return current_weather_db_symbol == :shadow_sky
    end

    module ObscursWeather
      # Le Ciel Obscur ne reste pas sur la carte après le combat
      def apply_weather(id, duration = nil)
        sky = PFM::Environment::WEATHER_NAMES.index(:shadow_sky)
        old = @weather
        super
        @weather = old if (id == :shadow_sky || id == sky) && old != sky
      end
    end
    prepend ObscursWeather
  end
end
