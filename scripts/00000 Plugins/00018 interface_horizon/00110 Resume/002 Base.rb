# Résumé PE : base de l'interface
module UI
  module SummaryPE
    # Base de l'interface : grille animée + barre de boutons du bas
    class BaseUI < GenericBaseMultiMode
      # Vitesse de défilement de la grille (pixels par seconde) et taille d'une case
      GRID_SPEED = 5
      GRID_SIZE = 12

      # Pas de barre de boutons en bas : le bandeau du haut et les touches suffisent
      # @param value [Array<String>]
      def button_texts=(value)
        super
        hide_bottom_buttons
      end

      def hide_win_text
        super
        hide_bottom_buttons
      end

      def update_background_animation
        # Graphics.current_time est un Time dans PSDK 26.x (un nombre dans d'autres versions) : to_f couvre les deux
        step = (Graphics.current_time.to_f * GRID_SPEED).to_i % GRID_SIZE
        @background.set_position(-step, step - GRID_SIZE)
      end

      private

      def create_background
        @background = add_sprite(0, -GRID_SIZE, SummaryPE.file('grid')).set_z(-10)
        if SummaryPE.wide?
          width = SummaryPE.full_width + 2 * GRID_SIZE
          pieces = (0...width).step(GRID_SIZE).map { |x| [x, 0, [GRID_SIZE, width - x].min, 256, 0, 0, [GRID_SIZE, width - x].min, 256] }
          @background.bitmap = ::Ecran.composer(SummaryPE.file('grid'), :interface, width, pieces)
        end
      end

      def hide_bottom_buttons
        @ctrl&.each { |button| button.visible = false }
        @button_background&.visible = false
      end

      def create_background_animation
        @background_animation = nil
        @on_update_background_animation = nil
      end
    end
  end
end
