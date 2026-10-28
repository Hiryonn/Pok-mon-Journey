# Sac (GamePlay::Bag) au style de la planche « Bag » fournie
#
# - Onglets de poches en haut (bannières colorées), nom de la poche dans le cadre gris à droite
# - Sac à gauche (il s'ouvre quand on change de poche), liste des objets à droite
#   (cœur rouge = objet favori / raccourci, « x12 » = quantité)
# - Panneau du bas : icône de l'objet dans l'hexagone, nom, quantité (et prix en boutique), description
# - Pas de barre de boutons en bas ; souris : clic sur un objet pour le choisir (re-clic = A),
#   clic droit = retour, clic sur un onglet = changer de poche, molette = défiler
# La logique de PSDK (utiliser, donner, raccourcis, trier, chercher, vendre, combat…) est inchangée.
#
# Graphismes : graphics/interface/bag_bw/
# Pour revenir au sac d'origine : passer ENABLED à false (ou supprimer ce fichier).
module UI
  module BagBW
    # Active ou non le nouveau sac
    ENABLED = true
    # Dossier des graphismes (dans graphics/interface/)
    DIR = 'bag_bw/'
    # Couleurs de texte PSDK (blanc sur fond sombre)
    WHITE = 9
    GREY = 17
    SMALL_FONT = 20
    # Poche PSDK => onglet de la planche
    # (0 Balls, 1 Objets, 2 Soins, 3 Lettres, 4 Baies, 5 CT, 6 marteau, 7 Objets rares, 8 Favoris)
    POCKET_TABS = {1 => 1, 2 => 0, 3 => 5, 4 => 4, 5 => 7, 6 => 2, 7 => 3, 8 => 8}
    # Onglets
    TAB_X = 4
    TAB_STEP = 30
    TAB_Y_ACTIVE = 0
    TAB_Y_INACTIVE = -4
    # Liste des objets
    ROW_X = 106
    ROW_Y = 34
    ROW_HEIGHT = 19
    ROWS = 7
    # Ligne où reste la sélection
    CURSOR = 3

    module_function

    # @param name [String]
    # @return [String]
    def file(name)
      return "#{DIR}#{name}"
    end

    # Base : fond sombre, barre de boutons masquée
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
        @background = add_sprite(0, 0, BagBW.file('background')).set_z(-10)
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
        @tab_ids = pocket_indexes.map { |id| POCKET_TABS[id] || 6 }
        @tab_ids.each_with_index do |tab, i|
          add_sprite(TAB_X + i * TAB_STEP, TAB_Y_INACTIVE, BagBW.file("tab_#{tab}_off")).set_z(1)
        end
        @index = 0
      end

      # @param index [Integer]
      def index=(index)
        @index = index.clamp(0, size - 1)
        @stack.each_with_index do |sprite, i|
          active = i == @index
          sprite.set_bitmap(BagBW.file(active ? "tab_#{@tab_ids[i]}" : "tab_#{@tab_ids[i]}_off"), :interface)
          sprite.y = active ? TAB_Y_ACTIVE : TAB_Y_INACTIVE
        end
      end
    end

    # Nom de la poche (même interface que UI::Bag::WinPocket)
    class PocketName < SpriteStack
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 222, 6, default_cache: :interface)
        add_sprite(0, 0, BagBW.file('name_box')).set_z(1)
        @text = add_text(4, 1, 88, 16, '', 1, color: WHITE)
        @text.z = 2
      end

      # @param text [String]
      def text=(text)
        @text.text = text.to_s
      end
    end

    # Barre de défilement (même interface que UI::Bag::ScrollBar)
    class ScrollBar < SpriteStack
      BASE_X = 313
      BASE_Y = ROW_Y
      HEIGHT = 122
      # @return [Integer]
      attr_reader :index
      # @return [Integer]
      attr_reader :max_index

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, BASE_X, BASE_Y, default_cache: :interface)
        add_sprite(0, 0, BagBW.file('scroll_track')).set_z(1)
        @button = add_sprite(0, 0, BagBW.file('scroll_thumb')).set_z(2)
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
    end

    # Sac : se trémousse et s'ouvre quand on change de poche (même interface que UI::Bag::BagSprite)
    class BagSprite < Sprite
      COORDINATES = [52, 100]
      # @return [Integer]
      attr_reader :index

      # @param viewport [Viewport]
      # @param pocket_indexes [Array<Integer>]
      def initialize(viewport, pocket_indexes)
        super(viewport)
        @pocket_indexes = pocket_indexes
        @index = 0
        @counter = 8
        set_bitmap(BagBW.file('bag_closed'), :interface)
        set_origin(28, 28)
        set_position(*COORDINATES)
        self.z = 1
      end

      # @param value [Integer]
      def index=(value)
        @index = value.clamp(0, @pocket_indexes.size - 1)
      end

      # @param target_index [Integer]
      def animate(target_index)
        @target_index = target_index.clamp(0, @pocket_indexes.size - 1)
        @counter = 0
      end

      def update
        return if done?

        base = COORDINATES.first
        self.x = @counter < 2 ? base - @counter : (@counter < 4 ? base - 4 + @counter : (@counter < 6 ? base + @counter - 4 : base + 8 - @counter))
        self.index = @target_index if @counter == 4
        set_bitmap(BagBW.file(@counter.between?(2, 6) ? 'bag_open' : 'bag_closed'), :interface)
        @counter += 1
        set_bitmap(BagBW.file('bag_closed'), :interface) if done?
      end

      # @return [Boolean]
      def done?
        return @counter >= 8
      end

      # @return [Boolean]
      def mid?
        return @counter == 4
      end
    end

    # Liste des objets (même interface que UI::Bag::ButtonList)
    class ItemList < SpriteStack
      # @return [Integer]
      attr_reader :index

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 0, 0, default_cache: :interface)
        add_sprite(ROW_X, ROW_Y + CURSOR * ROW_HEIGHT, BagBW.file('row_selected')).set_z(1)
        @hearts = []
        @names = []
        @quantities = []
        ROWS.times do |slot|
          y = ROW_Y + slot * ROW_HEIGHT
          @hearts << add_sprite(ROW_X + 4, y + 4, BagBW.file('heart_on')).set_z(2)
          @names << add_text(ROW_X + 18, y + 1, 140, 16, '', color: WHITE)
          with_font(SMALL_FONT) { @quantities << add_text(ROW_X + 150, y + 3, 52, 13, '', 2, color: WHITE) }
        end
        (@names + @quantities).each { |text| text.z = 2 }
        @item_list = []
        @name_list = []
        @index = 0
      end

      def update; end

      # @return [Boolean]
      def done?
        return true
      end

      # @param list [Array<Integer, Symbol>]
      def item_list=(list)
        @item_list = list
        @name_list = list.map { |id| data_item(id).exact_name }
        @name_list << text_get(22, 7)
        refresh
      end

      # @param index [Integer]
      def index=(index)
        @index = index.clamp(0, @item_list.size)
        refresh
      end

      def move_up
        @index += 1
        refresh
      end

      def move_down
        @index -= 1
        refresh
      end

      # @return [Integer] décalage entre la ligne sous la souris et la sélection
      def mouse_delta_index
        slot = row_at(Mouse.x, Mouse.y)
        return slot ? slot - CURSOR : 0
      end

      # Ligne (0..ROWS-1) affichée à cet endroit, ou nil
      # @param mx [Integer]
      # @param my [Integer]
      # @return [Integer, nil]
      def row_at(mx, my)
        return nil unless mx.between?(ROW_X, ROW_X + 205)

        slot = (my - ROW_Y).div(ROW_HEIGHT)
        return nil unless slot.between?(0, ROWS - 1) && @names[slot].visible

        return slot
      end

      private

      def refresh
        ROWS.times do |slot|
          position = @index - CURSOR + slot
          shown = position >= 0 && position < @name_list.size
          @names[slot].visible = shown
          @quantities[slot].visible = shown
          @hearts[slot].visible = false
          next unless shown

          @names[slot].text = @name_list[position].to_s
          id = @item_list[position]
          item = id && data_item(id)
          @quantities[slot].text = item&.is_limited ? "x#{$bag.item_quantity(id)}" : ''
          @hearts[slot].visible = item ? $bag.shortcuts.include?(item.db_symbol) : false
        end
      end
    end

    # La flèche de PSDK est remplacée par la ligne grise de sélection
    class NoArrow
      def update; end
    end

    # Panneau d'infos du bas (même interface que UI::Bag::InfoCompact / InfoWide)
    class InfoPanel < SpriteStack
      # @return [Symbol]
      attr_reader :mode

      # @param viewport [Viewport]
      # @param mode [Symbol] mode du sac
      def initialize(viewport, mode)
        super(viewport, 0, 172, default_cache: :interface)
        @mode = mode
        add_sprite(0, 0, BagBW.file('panel')).set_z(1)
        @icon = add_sprite(12, 15, NO_INITIAL_IMAGE, type: ItemSprite).set_z(2)
        @name = add_text(60, 3, 180, 16, '', color: WHITE)
        @name.bold = true
        with_font(SMALL_FONT) { @quantity = add_text(196, 5, 118, 13, '', 2, color: WHITE) }
        @descr = add_text(60, 19, 254, 16, '', color: WHITE)
        [@name, @quantity, @descr].each { |text| text.z = 2 }
      end

      # @param id [Integer, Symbol, nil] objet affiché (nil = « Fermer le sac »)
      def show_item(id)
        if id.nil? || id == 0
          @icon.visible = false
          @name.text = id.nil? ? text_get(22, 7) : ''
          @quantity.text = ''
          @descr.text = ''
          return
        end

        item = data_item(id)
        @icon.visible = visible
        @icon.data = id
        @name.text = item.exact_name
        parts = []
        parts << parse_text(11, 9, /\[VAR NUM7[^\]]*\]/ => (item.price / 2).to_s) if @mode == :shop
        parts << "x#{$bag.item_quantity(id)}" if item.is_limited
        @quantity.text = parts.join('   ')
        @descr.multiline_text = item.descr.to_s
      end
    end
  end
end

module GamePlay
  class Bag
    # Habillage du sac (la logique de PSDK reste inchangée)
    module BWStyle
      public

      # Souris : clic sur un objet, clic droit pour revenir
      def update_mouse(moved)
        return false if @animation
        return false if update_bw_list_click

        return super
      end

      private

      def create_base_ui
        @base_ui = UI::BagBW::BaseUI.new(@viewport, button_texts)
      end

      def create_pocket_ui
        @pocket_ui = UI::BagBW::Tabs.new(@viewport, @pocket_indexes)
        @pocket_ui.index = @socket_index
        @pocket_name = UI::BagBW::PocketName.new(@viewport)
        update_pocket_name
      end

      def create_scroll_bar
        @scroll_bar = UI::BagBW::ScrollBar.new(@viewport)
        update_scroll_bar
      end

      def create_bag_sprite
        @bag_sprite = UI::BagBW::BagSprite.new(@viewport, @pocket_indexes)
        @bag_sprite.index = @socket_index
      end

      def create_item_list
        @item_button_list = UI::BagBW::ItemList.new(@viewport)
        update_item_button_list
      end

      def create_arrow
        @arrow = UI::BagBW::NoArrow.new
      end

      def create_info
        @info_compact = UI::BagBW::InfoPanel.new(@viewport, @mode)
        @info_wide = UI::BagBW::InfoPanel.new(@viewport, @mode)
        update_info_visibility
        update_info
      end

      def create_shadow
        @shadows = %i[enabled disabled].to_h do |key|
          sprite = Sprite.new(@viewport).set_bitmap(UI::BagBW.file('shadow'), :interface).set_z(3)
          sprite.visible = false
          [key, sprite]
        end
      end

      # Le cadre de PSDK (bandeau « SAC ») n'existe pas dans ce design
      def create_frame; end

      # @return [Boolean] true si le clic a été utilisé
      def update_bw_list_click
        return false if @searching

        if Mouse.trigger?(:RIGHT)
          action_b
          return true
        end
        return false unless Mouse.trigger?(:LEFT)

        slot = @item_button_list.row_at(Mouse.x, Mouse.y)
        return false unless slot

        delta = slot - UI::BagBW::CURSOR
        delta == 0 ? action_a : update_mouse_delta_index(delta)
        return true
      end
    end
    prepend BWStyle if UI::BagBW::ENABLED
  end
end
