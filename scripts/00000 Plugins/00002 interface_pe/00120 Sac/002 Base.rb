# Sac PE : base de l'interface
module UI
  module BagPE
    # Base : fond, barre de boutons masquée
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

      def update_background_animation; end

      private

      def create_background
        @background = add_sprite(0, 0, BagPE.file('background')).set_z(-10)
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
