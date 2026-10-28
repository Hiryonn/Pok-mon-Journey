# Sac (GamePlay::Bag) en grille, d'après l'exemple fourni
#
# - Bandeau : « Sac : <poche> » et l'argent ; onglets des poches (l'onglet actif garde sa pointe)
# - Grille d'objets : case grise avec l'icône, la quantité en haut à gauche, un cœur si favori
# - Panneau du bas : nom et quantité, icône dans l'hexagone, description (X l'affiche / le cache)
# Déplacements : haut / bas = ligne, gauche / droite = case ; au bord de la grille, gauche / droite
# change de poche. Souris : clic sur une case (re-clic = A), clic sur un onglet, molette, clic droit = retour.
# Pas de barre de boutons en bas. Utiliser, donner, raccourcis, trier, chercher, vendre, combat…
# restent ceux de PSDK.
#
# Graphismes : graphics/interface/bag_pe/
# Pour revenir au sac d'origine : passer ENABLED à false (ou supprimer ce fichier).
module UI
  module BagPE
    # Active ou non le nouveau sac
    ENABLED = true
    # Dossier des graphismes (dans graphics/interface/)
    DIR = 'bag_pe/'
    WHITE = 9
    SMALL_FONT = 20
    # Couleur du nom de la poche dans le titre
    POCKET_COLOR = [0xf0, 0xa0, 0x40]
    # Poche PSDK => onglet de la planche
    # (0 Balls, 1 Objets, 2 Soins, 3 Lettres, 4 Baies, 5 CT, 6 marteau, 7 Objets rares, 8 Favoris)
    POCKET_TABS = {1 => 1, 2 => 0, 3 => 5, 4 => 4, 5 => 7, 6 => 2, 7 => 3, 8 => 8}
    # Onglets : position, écart, hauteur sans la pointe
    TAB_X = 4
    TAB_Y = 22
    TAB_STEP = 29
    TAB_HEIGHT = 24
    # Grille
    COLUMNS = 7
    CELL = 44
    GRID_X = 8
    GRID_Y = 54
    # Lignes visibles avec / sans le panneau d'infos
    ROWS_WITH_PANEL = 2
    ROWS_FULL = 4
    PANEL_Y = 150

    module_function

    # @param name [String]
    # @return [String]
    def file(name)
      return "#{DIR}#{name}"
    end

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

    # Onglets des poches (même interface que UI::Bag::PocketList)
    class Tabs < SpriteStack
      # @return [Integer]
      attr_reader :index

      # @param viewport [Viewport]
      # @param pocket_indexes [Array<Integer>]
      def initialize(viewport, pocket_indexes)
        super(viewport, 0, 0, default_cache: :interface)
        pocket_indexes.each_with_index do |id, i|
          add_sprite(TAB_X + i * TAB_STEP, TAB_Y, BagPE.file("tab_#{POCKET_TABS[id] || 6}")).set_z(1)
        end
        @index = 0
      end

      # L'onglet actif garde sa pointe, les autres sont coupés au carré
      # @param index [Integer]
      def index=(index)
        @index = index.clamp(0, size - 1)
        @stack.each_with_index do |sprite, i|
          sprite.src_rect.set(0, 0, 28, i == @index ? 28 : TAB_HEIGHT)
        end
      end
    end

    # Titre « Sac : <poche> » et argent (même interface que UI::Bag::WinPocket)
    class Title < SpriteStack
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 0, 0, default_cache: :interface)
        @label = add_text(6, 3, 60, 16, "#{text_get(14, 2)} : ", color: WHITE)
        @pocket = add_text(6, 3, 150, 16, '', color: WHITE)
        @pocket.fill_color = Color.new(*POCKET_COLOR)
        add_sprite(224, 3, BagPE.file('money_box'))
        @money = add_text(228, 3, 84, 16, '', 2, color: WHITE)
        refresh_money
      end

      # @param text [String] nom de la poche
      def text=(text)
        @pocket.text = text.to_s
        @pocket.x = @label.x + @label.real_width
        @pocket.fill_color = Color.new(*POCKET_COLOR)
        refresh_money
      end

      def refresh_money
        money = PFM.game_state&.money.to_i
        @money.text = begin
          parse_text(11, 9, /\[VAR NUM7[^\]]*\]/ => money.to_s)
        rescue StandardError
          money.to_s
        end
      end
    end

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

    # Une case de la grille
    class Cell < SpriteStack
      # @param viewport [Viewport]
      # @param x [Integer]
      # @param y [Integer]
      def initialize(viewport, x, y)
        super(viewport, x, y, default_cache: :interface)
        add_sprite(0, 0, BagPE.file('tile')).set_z(1)
        @icon = add_sprite(4, 4, NO_INITIAL_IMAGE, type: ItemSprite).set_z(2)
        @heart = add_sprite(27, 2, BagPE.file('heart_on')).set_z(3)
        with_font(SMALL_FONT) { @quantity = add_text(3, 2, 30, 13, '', color: WHITE) }
        @quantity.z = 3
      end

      # @param id [Integer, Symbol, nil] objet (nil = case vide)
      def item=(id)
        self.visible = !id.nil?
        return if id.nil?

        item = data_item(id)
        @icon.data = id
        @quantity.text = item.is_limited ? $bag.item_quantity(id).to_s : ''
        @heart.visible = $bag.shortcuts.include?(item.db_symbol)
      end
    end

    # Grille des objets (même interface que UI::Bag::ButtonList)
    class ItemGrid
      # @return [Integer]
      attr_reader :index

      # @param viewport [Viewport]
      def initialize(viewport)
        @cells = Array.new(ROWS_FULL * COLUMNS) do |i|
          Cell.new(viewport, GRID_X + (i % COLUMNS) * CELL, GRID_Y + (i / COLUMNS) * CELL)
        end
        @cursor = Sprite.new(viewport).set_bitmap(BagPE.file('tile_cursor'), :interface)
        @cursor.z = 4
        @item_list = []
        @index = 0
        @top_row = 0
        @rows = ROWS_WITH_PANEL
      end

      def update; end

      # @return [Boolean]
      def done?
        return true
      end

      # @param list [Array<Integer, Symbol>]
      def item_list=(list)
        @item_list = list
        refresh
      end

      # @param index [Integer]
      def index=(index)
        @index = index.clamp(0, [@item_list.size - 1, 0].max)
        refresh
      end

      def move_up
        self.index = @index + 1
      end

      def move_down
        self.index = @index - 1
      end

      # Nombre de lignes visibles (2 avec le panneau, 4 sans)
      # @param rows [Integer]
      def rows=(rows)
        @rows = rows
        refresh
      end

      # @return [Integer] décalage entre la case sous la souris et la sélection
      def mouse_delta_index
        position = position_at(Mouse.x, Mouse.y)
        return position ? position - @index : 0
      end

      # Index de l'objet sous la souris, ou nil
      # @param mx [Integer]
      # @param my [Integer]
      # @return [Integer, nil]
      def position_at(mx, my)
        col = (mx - GRID_X).div(CELL)
        row = (my - GRID_Y).div(CELL)
        return nil unless col.between?(0, COLUMNS - 1) && row.between?(0, @rows - 1)

        position = (@top_row + row) * COLUMNS + col
        return position < @item_list.size ? position : nil
      end

      private

      def refresh
        row = @index / COLUMNS
        @top_row = row if row < @top_row
        @top_row = row - @rows + 1 if row >= @top_row + @rows
        @top_row = 0 if @top_row.negative?
        @cells.each_with_index do |cell, i|
          slot_row = i / COLUMNS
          position = (@top_row + slot_row) * COLUMNS + i % COLUMNS
          cell.item = slot_row < @rows ? @item_list[position] : nil
        end
        @cursor.visible = !@item_list.empty?
        @cursor.set_position(GRID_X - 2 + (@index % COLUMNS) * CELL, GRID_Y - 2 + (row - @top_row) * CELL)
      end
    end

    # Panneau d'infos du bas (même interface que UI::Bag::InfoCompact)
    class InfoPanel < SpriteStack
      # @return [Symbol]
      attr_reader :mode

      # @param viewport [Viewport]
      # @param mode [Symbol] mode du sac
      def initialize(viewport, mode)
        super(viewport, 0, PANEL_Y, default_cache: :interface)
        @mode = mode
        add_sprite(0, 0, BagPE.file('panel_header')).set_z(5)
        add_sprite(0, 22, BagPE.file('panel')).set_z(5)
        @name = add_text(6, 2, 230, 16, '', color: WHITE)
        @trash = add_sprite(290, 4, BagPE.file('trash')).set_z(6)
        @heart = add_sprite(304, 4, BagPE.file('heart_on')).set_z(6)
        @icon = add_sprite(12, 37, NO_INITIAL_IMAGE, type: ItemSprite).set_z(6)
        with_font(SMALL_FONT) { @price = add_text(196, 25, 118, 13, '', 2, color: WHITE) }
        @descr = add_text(60, 25, 254, 16, '', color: WHITE)
        [@name, @price, @descr].each { |text| text.z = 6 }
      end

      # @param id [Integer, Symbol, nil] objet affiché (nil = rien)
      def show_item(id)
        if id.nil? || id == 0
          [@icon, @heart, @trash].each { |sprite| sprite.visible = false }
          @name.text = ''
          @price.text = ''
          @descr.text = ''
          return
        end

        item = data_item(id)
        @icon.visible = @trash.visible = visible
        @icon.data = id
        @name.text = item.is_limited ? "#{item.exact_name} x#{$bag.item_quantity(id)}" : item.exact_name
        @heart.visible = visible && $bag.shortcuts.include?(item.db_symbol)
        @price.text = @mode == :shop ? parse_text(11, 9, /\[VAR NUM7[^\]]*\]/ => (item.price / 2).to_s) : ''
        @descr.y = @price.text.empty? ? @y + 25 - Text::Util::FOY : @y + 39 - Text::Util::FOY
        @descr.multiline_text = item.descr.to_s
      end
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

module GamePlay
  class Bag
    # Habillage du sac (la logique de PSDK reste inchangée)
    module PEStyle
      public

      # Souris : clic sur une case, clic droit pour revenir
      def update_mouse(moved)
        return false if @animation
        return false if update_pe_grid_click

        return super
      end

      private

      def create_base_ui
        @base_ui = UI::BagPE::BaseUI.new(@viewport, button_texts)
      end

      def create_pocket_ui
        @pocket_ui = UI::BagPE::Tabs.new(@viewport, @pocket_indexes)
        @pocket_ui.index = @socket_index
        @pocket_name = UI::BagPE::Title.new(@viewport)
        update_pocket_name
      end

      def create_scroll_bar
        @scroll_bar = UI::BagPE::NoScrollBar.new
      end

      def update_scroll_bar
        @scroll_bar.max_index = @last_index
        @scroll_bar.index = @index
      end

      def create_bag_sprite
        @bag_sprite = UI::BagPE::NoBagSprite.new
      end

      def create_item_list
        @item_button_list = UI::BagPE::ItemGrid.new(@viewport)
        update_item_button_list
      end

      def create_arrow
        @arrow = UI::BagPE::NoArrow.new
      end

      def create_info
        @info_compact = UI::BagPE::InfoPanel.new(@viewport, @mode)
        @info_wide = UI::BagPE::NoInfo.new(@mode)
        update_info_visibility
        update_info
      end

      # X affiche / cache le panneau ; sans panneau la grille montre plus de lignes
      def update_info_visibility
        super
        @item_button_list.rows = @compact_mode == :enabled ? UI::BagPE::ROWS_WITH_PANEL : UI::BagPE::ROWS_FULL
      end

      def create_shadow
        @shadows = %i[enabled disabled].to_h do |key|
          sprite = Sprite.new(@viewport).set_bitmap(UI::BagPE.file('shadow'), :interface).set_z(3)
          sprite.visible = false
          [key, sprite]
        end
      end

      # Le cadre de PSDK (bandeau « SAC ») n'existe pas dans ce design
      def create_frame; end

      # Dernier index sélectionnable (la grille n'a pas de case « Fermer le sac »)
      # @return [Integer]
      def pe_last_item
        return [@item_list.size - 1, 0].max
      end

      # Gauche / droite : case précédente / suivante ; au bord de la grille, poche voisine
      def update_socket_input
        dir = Input.repeat?(:LEFT) ? -1 : (Input.repeat?(:RIGHT) ? 1 : 0)
        return true if dir == 0

        col = @index % UI::BagPE::COLUMNS
        at_edge = dir < 0 ? col == 0 : (col == UI::BagPE::COLUMNS - 1 || @index >= pe_last_item)
        play_cursor_se
        if at_edge
          return false if @searching

          change_pocket((@socket_index + dir) % (@last_socket_index + 1))
        else
          pe_select(@index + dir)
        end
        return false
      end

      # Haut / bas : ligne précédente / suivante
      def update_list_input
        dir = Input.repeat?(:UP) ? -1 : (Input.repeat?(:DOWN) ? 1 : 0)
        return true if dir == 0

        target = @index + dir * UI::BagPE::COLUMNS
        target = pe_last_item if dir > 0 && target > pe_last_item && @index / UI::BagPE::COLUMNS < pe_last_item / UI::BagPE::COLUMNS
        return false if target.negative? || target > pe_last_item

        play_cursor_se
        pe_select(target)
        return false
      end

      # Molette : une ligne par cran
      def update_mouse_index
        pe_select((@index - Mouse.wheel * UI::BagPE::COLUMNS).clamp(0, pe_last_item))
        Mouse.wheel = 0
        return false
      end

      # @param index [Integer]
      def pe_select(index)
        @index = index.clamp(0, pe_last_item)
        update_item_button_list
        update_info
        @scroll_bar.index = @index
      end

      # @return [Boolean] true si le clic a été utilisé
      def update_pe_grid_click
        return false if @searching

        if Mouse.trigger?(:RIGHT)
          action_b
          return true
        end
        return false unless Mouse.trigger?(:LEFT)

        position = @item_button_list.position_at(Mouse.x, Mouse.y)
        return false unless position

        position == @index ? action_a : pe_select(position)
        return true
      end
    end
    prepend PEStyle if UI::BagPE::ENABLED
  end
end
