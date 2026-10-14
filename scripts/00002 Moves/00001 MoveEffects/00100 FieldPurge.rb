module Battle
    class Move
        class FieldPurge < Defog
            private
            # Function that deals the effect to the pokemon
            # @param user [PFM::PokemonBattler] user of the move
            # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
            def deal_effect(user, actual_targets)
              if $env.current_weather_db_symbol != weather
                logic.weather_change_handler.weather_change(:none, 0)
              end
              user.effects.each { |e| e.kill if e.rapid_spin_affected? }
              logic.bank_effects.each_with_index do |bank_effect, bank_index|
                bank_effect.each do |e|
                  e.kill if e.rapid_spin_affected?
                  e.kill if bank_index != user.bank && effects_to_kill.include?(e.name)
                end
              end
              scene.display_message_and_wait(weather_cancel_text)
            end
            # The type of weather the Move can cancel
            # @return [Symbol]
            def weather
              return :none
            end
            # The message displayed when the right weather is canceled
            # @return [String]
            def weather_cancel_text
              return parse_text(400002, 31)
            end
        end
          Move.register(:s_field_purge, FieldPurge)
    end
end