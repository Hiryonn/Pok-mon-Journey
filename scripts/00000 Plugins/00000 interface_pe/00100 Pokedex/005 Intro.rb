# Pokédex PE : animation d'ouverture
module UI
  module DexPE
    # Animation d'ouverture : l'appareil apparaît, s'ouvre puis laisse place au Pokédex
    class Intro
      # Durée totale (secondes)
      DURATION = 0.9
      # Centre de l'appareil à l'écran
      CENTER = [160, 128]

      # @param viewport [Viewport]
      def initialize(viewport)
        @background = Sprite.new(viewport)
        @background.set_bitmap(DexPE.file('intro_bg'), :pokedex)
        @device = Sprite.new(viewport)
        @device.set_bitmap(DexPE.file('device_closed'), :pokedex)
        @device.set_origin(28, 28)
        @device.set_position(*CENTER)
        @background.z = 20_000
        @device.z = 20_001
        @opened = false
        self.progress = 0
        @animation = Yuki::Animation.scalar(DURATION, self, :progress=, 0.0, 1.0)
        @animation.start
        Audio.se_play('audio/se/se_gui_pokedex_open') rescue nil
      end

      def update
        return if @disposed

        @animation.update
        dispose if @animation.done?
      end

      # @return [Boolean]
      def done?
        return @disposed == true
      end

      # Passe directement à la fin
      def skip
        dispose
      end

      # @param value [Float] avancement de 0 à 1
      def progress=(value)
        return if @disposed

        if value < 0.35
          zoom = 0.5 + 1.5 * (value / 0.35)
          opacity = 255
        elsif value < 0.6
          open_device
          zoom = 2 + 0.2 * ((value - 0.35) / 0.25)
          opacity = 255
        else
          open_device
          fade = (value - 0.6) / 0.4
          zoom = 2.2 + 2 * fade
          opacity = (255 * (1 - fade)).to_i
        end
        @device.zoom = zoom
        @device.opacity = opacity
        @background.opacity = opacity
      end

      private

      def open_device
        return if @opened

        @opened = true
        @device.set_bitmap(DexPE.file('device_open'), :pokedex)
      end

      def dispose
        return if @disposed

        @disposed = true
        @device.dispose unless @device.disposed?
        @background.dispose unless @background.disposed?
      end
    end
  end
end
