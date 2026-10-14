module Battle 
    class Logic 
        class WeatherChangeHandler 
            # Mapping between weather symbol & message_id
            WEATHER_SYM_TO_MSG = {none: 0, rain: 2, sunny: 1, sandstorm: 3, hail: 4, fog: 5, hardsun: 6, hardrain: 7, strong_winds: 8, snow: 9, radiance: 10, twilight: 11}
        
            def show_weather_message(last_weather, current_weather)
                return if last_weather == current_weather
                @scene.display_message_and_wait(parse_text(400001, WEATHER_SYM_TO_MSG[current_weather]))
            end
        
        end
    end
end