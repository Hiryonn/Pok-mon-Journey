module Battle 
    class Move
        class Nightfall < Move
            #set spd to -1 in PS
            def deal_effect(user, actual_targets)
                if $env.current_weather_db_symbol != weather
                    scene.display_message_and_wait(weather_cancel_text)
                    logic.weather_change_handler.weather_change(:none, 0)
                end
            end

            def weather
                return :none
            end

            def weather_cancel_text
                return parse_text(400002, 28)
            end
        end
        Move.register(:s_nightfall, Nightfall)

    end
end
