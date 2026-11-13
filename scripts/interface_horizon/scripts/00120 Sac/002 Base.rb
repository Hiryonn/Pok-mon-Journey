# Sac Horizon : fond (couleur, motif qui défile, dégradé), barre de boutons masquée
module UI
  module BagHorizon
    class BaseUI < GenericBase
      # Faux bouton : le sac de PSDK manipule encore ses boutons (recherche, souris)
      FakeButton = Struct.new(:visible) do
        def set_press(_value); end

        def simple_mouse_in?(*_args)
          return false
        end

        def text=(_value); end

        def key=(_value); end
      end

      # @return [Array<FakeButton>]
      def ctrl
        @fake_ctrl ||= Array.new(4) { FakeButton.new(false) }
      end

      # @param value [Array<String>]
      def button_texts=(value)
        super
        hide_bottom_buttons
      end

      def hide_win_text
        super
        hide_bottom_buttons
      end

      # Le motif défile vers la gauche
      def update_background_animation
        return unless @panorama

        @panorama_x = (@panorama_x - PANORAMA_SPEED) % @panorama.first.width
        @panorama.each_with_index { |sprite, i| sprite.x = (i * sprite.width - @panorama_x).round }
      end

      private

      def create_background
        @background = add_sprite(0, 0, BagHorizon.file('background')).set_z(-10)
        name = PANORAMA_DARK_AT_NIGHT && night? ? 'panorama_dark' : 'panorama'
        @panorama = Array.new(3) { |i| add_sprite(0, 0, BagHorizon.file(name)).set_z(-9) }
        @panorama_x = 0
        update_background_animation
        add_sprite(0, 0, BagHorizon.file('grad')).set_z(-8)
      end

      def night?
        return $env.respond_to?(:night?) && $env.night?
      rescue StandardError
        return false
      end

      def create_background_animation
        @background_animation = nil
        @on_update_background_animation = nil
      end

      def hide_bottom_buttons
        @ctrl&.each { |button| button.visible = false }
        @button_background&.visible = false
      end
    end
  end
end
