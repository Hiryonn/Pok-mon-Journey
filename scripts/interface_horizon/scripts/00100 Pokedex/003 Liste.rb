# Pokédex Horizon : liste des Pokémon (lignes, défilement, compteurs)
module UI
  module DexPE
    # Ligne de la liste : hexagone avec l'icône, numéro, nom et pastilles capturés / rencontrés
    class Row < SpriteStack
      # Largeur et hauteur d'une ligne
      WIDTH = 212
      HEIGHT = 38
      # Position des pastilles dans la ligne
      PILL_X = 166
      PILL_CAUGHT_Y = 4
      PILL_SEEN_Y = 20
      # Zone du numéro et du nom
      TEXT_X = 36
      TEXT_WIDTH = 128

      # @param viewport [Viewport]
      # @param x [Integer]
      # @param y [Integer]
      def initialize(viewport, x, y)
        super(viewport, x, y, default_cache: :pokedex)
        create_sprites
        @selected = nil
        @unseen = nil
      end

      # Affiche une entrée du Pokédex
      # @param view [GamePlay::Dex::CreatureView]
      # @param number [Integer] numéro dans le Pokédex courant
      # @param caught_count [Integer] nombre de captures de l'espèce
      # @param seen_count [Integer] nombre de rencontres de l'espèce
      # @param selected [Boolean] si la ligne est sélectionnée
      def set_entry(view, number, caught_count, seen_count, selected)
        seen = view.displayed?
        apply_look(selected, !seen)
        @number.text = format('N°%03d', number)
        @name.text = seen ? view.pokemon.name : '???'
        @icon.visible = seen
        @icon.data = view.pokemon if seen
        [@pill_caught, @pill_seen, @caught_count, @seen_count].each { |sprite| sprite.visible = seen }
        @caught_count.text = caught_count.to_s
        @seen_count.text = seen_count.to_s
      end

      private

      # Change le fond et la couleur des textes selon l'état
      # @param selected [Boolean]
      # @param unseen [Boolean]
      def apply_look(selected, unseen)
        return if @selected == selected && @unseen == unseen

        @selected = selected
        @unseen = unseen
        name = DexPE.file(selected ? 'row_selected' : (unseen ? 'row_unseen' : 'row'))
        @background.set_bitmap(name, :pokedex)
        @background.bitmap = ::Ecran.tranches(name, 130, 160, WIDTH + DexPE.extra, :pokedex) if DexPE.wide?
        color = selected ? DARK : WHITE
        @number.load_color(color)
        @name.load_color(color)
      end

      def create_sprites
        @background = add_background(DexPE.file('row'))
        extra = DexPE.extra
        @icon = add_sprite(17, 19, NO_INITIAL_IMAGE, type: PokemonIconSprite)
        # Numéro et nom centrés dans la bande, entre l'hexagone (x 34) et les pastilles (x 166)
        with_font(SMALL_FONT) { @number = add_text(TEXT_X, 5, TEXT_WIDTH + extra, 13, '', 1, color: WHITE) }
        @name = add_text(TEXT_X, 18, TEXT_WIDTH + extra, 16, '', 1, color: WHITE)
        @pill_caught = add_sprite(PILL_X + extra, PILL_CAUGHT_Y, DexPE.file('pill_caught'))
        @pill_seen = add_sprite(PILL_X + extra, PILL_SEEN_Y, DexPE.file('pill_seen'))
        with_font(SMALL_FONT) do
          @caught_count = add_text(PILL_X + extra + 12, PILL_CAUGHT_Y + 1, 26, 13, '0', 1, color: WHITE)
          @seen_count = add_text(PILL_X + extra + 12, PILL_SEEN_Y + 1, 26, 13, '0', 1, color: WHITE)
        end
      end
    end

    # Barre de défilement verticale (même interface que UI::Dex::ScrollBar)
    class ScrollBar < SpriteStack
      # @return [Integer]
      attr_reader :index
      # @return [Integer]
      attr_reader :max_index
      BASE_X = 316
      BASE_Y = 34
      # Course du curseur (hauteur de la piste - hauteur du curseur)
      HEIGHT = 164

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, DexPE.left + DexPE.extra + BASE_X, BASE_Y, default_cache: :pokedex)
        add_background(DexPE.file('scroll_track'))
        @button = add_sprite(0, 0, DexPE.file('scroll_thumb'))
        @index = 0
        @max_index = 1
      end

      # @param value [Integer]
      def index=(value)
        @index = value.clamp(0, @max_index)
        @button.y = BASE_Y + HEIGHT * @index / @max_index
      end

      # @param value [Integer]
      def max_index=(value)
        @max_index = value <= 0 ? 1 : value
        self.index = 0
      end

      # @return [Integer, nil]
      def mouse_index
        return nil unless simple_mouse_in?

        return drag_mouse_index
      end

      # @return [Integer]
      def drag_mouse_index
        _, local_y = translate_mouse_coords
        return (local_y * @max_index / HEIGHT).clamp(0, @max_index)
      end
    end

    # Compteurs globaux « PRIS » / « VUS » en haut à gauche de la liste
    class Counters < SpriteStack
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, DexPE.left, 34, default_cache: :pokedex)
        with_font(SMALL_FONT) do
          add_text(2, 4, 44, 13, ext_text(9000, 21), 2, color: WHITE)
          add_text(2, 20, 44, 13, ext_text(9000, 20), 2, color: WHITE)
          @caught = add_text(59, 6, 26, 13, '0', 1, color: WHITE)
          @seen = add_text(59, 22, 26, 13, '0', 1, color: WHITE)
        end
      end

      # @param seen [Integer]
      # @param caught [Integer]
      def update_counts(seen, caught)
        @seen.text = seen.to_s
        @caught.text = caught.to_s
      end
    end

    # Composition de l'état « liste » (même interface que UI::Dex::DexListComposition)
    class ListComposition < SpriteStack
      # Nombre de lignes visibles
      BUTTON_COUNT = 5
      # Position de la première ligne et écart entre deux lignes
      ROW_X = 104
      ROW_Y = 32
      ROW_STEP = 36
      # Index de la ligne où reste la sélection quand la liste défile
      CURSOR_SLOT = 2
      # @return [ScrollBar]
      attr_reader :scrollbar
      # @return [Array<Row>]
      attr_reader :buttons
      # @return [Counters]
      attr_reader :seen_got

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport)
        @buttons = Array.new(BUTTON_COUNT) { |slot| Row.new(viewport, DexPE.left + ROW_X, ROW_Y + slot * ROW_STEP) }
        @scrollbar = ScrollBar.new(viewport)
        @seen_got = Counters.new(viewport)
        # Cadre d'origine de PSDK, gardé pour la carte (état 2)
        @map_frame = Sprite.new(viewport)
        @map_frame.set_bitmap('frame', :pokedex)
      end

      def update; end

      # @return [Boolean]
      def done?
        return true
      end

      # @param state [Integer] 0 = liste, 1 = infos, 2 = carte
      def change_state(state)
        list = state == 0
        @buttons.each { |row| row.visible = list }
        @scrollbar.visible = list
        @seen_got.visible = list
        @map_frame.visible = state == 2
      end

      # @param selected_creatures [Array<Studio::Dex::CreatureInfo>]
      # @param pokemonlist [PFM::Pokemon]
      # @param index [Integer]
      # @param visible [Boolean]
      # @param presenter [GamePlay::Dex::Presenter]
      def update_list(selected_creatures, pokemonlist, index, visible, presenter)
        size = selected_creatures.size
        update_scrollbar(size, index, visible)
        base_index = calc_base_index(size, index)
        @buttons.each_with_index do |row, slot|
          position = base_index + slot
          creature = selected_creatures[position]
          row.visible = (visible && creature && position >= 0) ? true : false
          next unless row.visible

          presenter.configure_creature(pokemonlist, creature)
          view = presenter.view_for(pokemonlist)
          caught_count, seen_count = presenter.pe_entry_counts(pokemonlist)
          row.set_entry(view, presenter.pe_dex_number(pokemonlist, position), caught_count, seen_count, position == index)
        end
      end

      # @param seen [Integer]
      # @param caught [Integer]
      def update_seen_got(seen, caught)
        @seen_got.update_counts(seen, caught)
      end

      # Premier index affiché : la sélection reste sur la ligne du milieu, sans laisser de trou en haut ou en bas
      # @param size [Integer]
      # @param index [Integer]
      # @return [Integer]
      def calc_base_index(size, index)
        return 0 if size <= BUTTON_COUNT

        return (index - CURSOR_SLOT).clamp(0, size - BUTTON_COUNT)
      end

      # @return [Integer, nil]
      def mouse_hovered_slot
        @buttons.each_with_index do |row, slot|
          return slot if row.visible && row.simple_mouse_in?
        end
        return nil
      end

      private

      def update_scrollbar(size, index, visible)
        @scrollbar.visible = visible && size > 1
        return unless @scrollbar.visible

        @scrollbar.max_index = size - 1
        @scrollbar.index = index
      end
    end
  end
end
