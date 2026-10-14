module Battle
  module Effects
    class Weather
      # Is it a shadowy aura?
      # @return [Boolean]
      def shadow_sky?
        return current_weather_db_symbol == :shadow_sky
      end
    end
  end
end
