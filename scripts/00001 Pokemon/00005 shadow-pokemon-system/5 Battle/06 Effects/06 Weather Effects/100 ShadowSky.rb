module Battle
  module Effects
    class Weather
      # Class describing the Shadow Sky weather effect, which hurts everything that is not Shadow.
      class ShadowSky < Weather
        # Fraction of its max HP a battler loses to the shadow sky each turn.
        # @return [Integer]
        DAMAGE_FACTOR = 16
        # Multiplier the shadow sky gives to the power of a Shadow move, which the game never announces.
        # @return [Float]
        SHADOW_MOVE_MULTIPLIER = 1.5

        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return logic.weather_change_handler.weather_change(:none, 0) if $env.decrease_weather_duration

          scene.visual.show_weather_animation(:shadow_sky)
          return if logic.weather_effects_disabled?

          scene.display_message_and_wait(PFM::ShadowTexts.message(:shadow_sky_continues))
          battlers.each do |battler|
            next if battler.dead?
            next if battler.shadow?
            next if battler.effects.has?(:out_of_reach_base)

            scene.display_message_and_wait(PFM::ShadowTexts.creature_message(:shadow_sky_damage, battler))
            logic.damage_handler.damage_change((battler.max_hp / DAMAGE_FACTOR).clamp(1, Float::INFINITY), battler)
          end
        end

        # Give the move mod1 mutiplier (before the +2 in the formula)
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def mod1_multiplier(user, target, move)
          return 1 if @logic.weather_effects_disabled?
          return SHADOW_MOVE_MULTIPLIER if move.type_shadow?

          return 1
        end
      end

      register(:shadow_sky, ShadowSky)
    end
  end
end
