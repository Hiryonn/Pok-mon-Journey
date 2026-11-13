# Sac Horizon : éléments de PSDK remplacés par des objets vides
module UI
  module BagHorizon
    # La barre de défilement est dans la liste (même interface que UI::Bag::ScrollBar)
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

    # Le curseur de la liste remplace la flèche de PSDK
    class NoArrow
      def update; end
    end

    # Pas de panneau « large » : la description reste toujours affichée
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
