
module PFM
    class Environment
        WEATHER_NAMES = %i[none rain sunny sandstorm hail fog hardsun hardrain strong_winds snow radiance twilight]

        def radiance?
                return current_weather_db_symbol == :radiance
        end
        def twilight?
            return current_weather_db_symbol == :twilight
        end
        def weather_switches
            sw = Yuki::Sw
            return [-1, sw::WT_Rain, sw::WT_Sunset, sw::WT_Sandstorm, sw::WT_Snow, sw::WT_Fog, sw::WT_Snow,  sw::WT_Rain, sw::WT_Sunset]#sw::WT_Radi, sw::WT_Twil
        end


        WEATHER_NAMES = %i[none rain sunny sandstorm hail fog hardsun hardrain strong_winds snow radiance twilight]
    end
end
