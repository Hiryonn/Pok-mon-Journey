# Interface Horizon : PC de stockage (GamePlay::PokemonStorage), en pleine largeur
#
# - bandeau et pied de page sur toute la largeur (la plaque du titre reste centrée)
# - la boîte est décalée de la moitié de la largeur gagnée, l'équipe et le résumé sont collés au bord droit
# Le point (0, 0) de la scène est le coin haut gauche de TOUT l'écran (voir Ecran.adapter, gauche: true).
module UI
  module StorageLarge
    # @return [Boolean]
    def self.wide?
      return defined?(::Ecran) && ::Ecran.grand? ? true : false
    end

    # @return [Integer] largeur gagnée par rapport à 320
    def self.extra
      return wide? ? ::Ecran.logique_largeur - 320 : 0
    end

    # Décale les positions fixes (constantes) du PC une fois pour toutes
    def self.patch_constants
      return if @patched || !wide?

      @patched = true
      e = extra
      replace(UI::Storage::Cursor, :BOX_INITIAL_POSITION, [17 + e / 2, 42])
      replace(UI::Storage::Cursor, :PARTY_POSITIONS, UI::Storage::Cursor::PARTY_POSITIONS.map { |x, y| [x + e, y] })
      replace(UI::Storage::Summary, :POSITION, UI::Storage::Summary::POSITION.map { |x, y| [x + e, y] })
    end

    # @param owner [Module]
    # @param name [Symbol]
    # @param value [Object]
    def self.replace(owner, name, value)
      owner.send(:remove_const, name)
      owner.const_set(name, value)
    end

    # Composition : cadre et groupes de sprites décalés
    module CompositionLarge
      private

      def create_box_stack
        super
        @box_stack.set_position(StorageLarge.extra / 2, 0) if StorageLarge.wide?
      end

      def create_party_stack
        super
        @party_stack.set_position(StorageLarge.extra, 0) if StorageLarge.wide?
      end

      def create_frames
        super
        return unless StorageLarge.wide?

        e = StorageLarge.extra
        width = 320 + e
        plate = 152
        px = (width - plate) / 2
        pieces = [[0, 0, px, 28, 10, 0, 70, 28], [px, 0, plate, 28, 84, 0, plate, 28],
                  [px + plate, 0, width - px - plate, 28, 240, 0, 70, 28], [0, 214, width, 26, 0, 214, 320, 26]]
        # Le fond du cadre est l'avant-dernier sprite ajouté (le dernier est la séparation boîte / équipe)
        @stack[-2].bitmap = ::Ecran.composer('pc/frame', :interface, width, pieces)
        @frame_split.x += e / 2
      end

      def create_modes
        super
        @mode_indicator.x += StorageLarge.extra / 2 if StorageLarge.wide?
      end

      def create_arrows
        super
        return unless StorageLarge.wide?

        @arrow_left.x += StorageLarge.extra / 2
        @arrow_right.x += StorageLarge.extra / 2
      end
    end
  end

  module StorageLarge
    # Curseur : la position « nom de la boîte » suit le décalage de la boîte
    module CursorLarge
      def select_box=(select_box)
        super
        self.x += StorageLarge.extra / 2 if select_box && StorageLarge.wide?
      end
    end
  end

  module Storage
    class Composition
      prepend StorageLarge::CompositionLarge
    end

    class Cursor
      prepend StorageLarge::CursorLarge
    end
  end
end

module GamePlay
  class PokemonStorage
    # La scène occupe tout l'écran
    # @return [Boolean]
    def origine_gauche?
      return UI::StorageLarge.wide?
    end

    module Large
      def initialize(*args)
        UI::StorageLarge.patch_constants
        super
      end
    end

    prepend Large
  end
end
