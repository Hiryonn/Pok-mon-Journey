# Pokédex PE : base de l'interface (fond + boutons)
module UI
  module DexPE
    # Base de l'interface (fond + barre de boutons du bas)
    class BaseUI < GenericBaseMultiMode
      # Change le fond affiché
      # @param name [String] nom du fond dans graphics/pokedex/pe/
      def page=(name)
        @background.set_bitmap(DexPE.file(name), :pokedex)
      end

      # Pas de barre de boutons : une bande bleue est dessinée dans le fond à la place
      # @param value [Array<String>]
      def button_texts=(value)
        super
        hide_bottom_buttons
      end

      def hide_win_text
        super
        hide_bottom_buttons
      end

      private

      def hide_bottom_buttons
        @ctrl&.each { |button| button.visible = false }
        @button_background&.visible = false
      end

      def create_background
        @background = add_sprite(0, 0, NO_INITIAL_IMAGE).set_z(-10)
        @background.set_bitmap(DexPE.file(PAGES.first), :pokedex)
        create_background_animation
      end

      # Le fond PE est fixe (pas de défilement comme le fond générique)
      def create_background_animation
        @background_animation = nil
        @on_update_background_animation = nil
      end
    end
  end
end
