module Battle
  class Logic
    class WeatherChangeHandler
      # Announces the Shadow Sky, whose lines live in the dialog file of the plugin rather than in
      # the table of the engine, which only knows the weathers it ships.
      module ShadowSkyMessagePatch
        private

        # Show the weather message
        # @param last_weather [Symbol]
        # @param current_weather [Symbol]
        def show_weather_message(last_weather, current_weather)
          return super unless last_weather == :shadow_sky || current_weather == :shadow_sky
          return if last_weather == current_weather

          key = current_weather == :shadow_sky ? :shadow_sky_appeared : :shadow_sky_faded
          @scene.display_message_and_wait(PFM::ShadowTexts.message(key))
        end
      end

      prepend ShadowSkyMessagePatch
    end
  end
end
