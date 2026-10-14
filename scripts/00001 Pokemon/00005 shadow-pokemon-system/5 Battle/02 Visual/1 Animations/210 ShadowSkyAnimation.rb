module UI
  class WeatherSprite
    # Rain of the Shadow Sky, the engine rain falling in the colour of the Shadow type, everything else untouched.
    class ShadowSkyAnimation < RainAnimation
      # Drop the sky rains, under the animation folder
      DROP = 'weather/shadow_sky_drop'

      # Creates all rain drop sprites
      def create_drop_sprite
        super
        @drop_sprites.each { |drop_sprite| drop_sprite.bitmap = RPG::Cache.animation(DROP) }
      end
    end

    register(:shadow_sky, ShadowSkyAnimation)
  end
end
