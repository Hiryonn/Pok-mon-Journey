# Sac PE : éléments de PSDK remplacés par des objets vides
module UI
  module BagPE
    # Pas de barre de défilement dans ce design (même interface que UI::Bag::ScrollBar)
    class NoScrollBar
      attr_accessor :index, :max_index, :visible
    end

    # Pas de sac dessiné : PSDK change alors de poche sans animation
    class NoBagSprite
      attr_accessor :index

      def initialize
        @index = 0
      end

      # @return [Boolean] toujours caché
      def visible
        return false
      end

      def visible=(_value); end

      def animate(_target); end

      def update; end

      # @return [Boolean]
      def done?
        return true
      end

      # @return [Boolean]
      def mid?
        return false
      end
    end

    # La flèche de PSDK est remplacée par le cadre orange de la case
    class NoArrow
      def update; end
    end

    # Panneau « large » : rien, X sert à cacher le panneau pour voir plus de lignes
    class NoInfo
      attr_accessor :visible
      attr_reader :mode

      def initialize(mode)
        @mode = mode
      end

      def show_item(_id); end
    end
  end
end
