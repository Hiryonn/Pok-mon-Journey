# Sac Horizon : liste des objets
module UI
  module BagHorizon
    # Une ligne de la liste
    class Row < SpriteStack
      # @param viewport [Viewport]
      # @param x [Integer]
      # @param y [Integer]
      def initialize(viewport, x, y)
        super(viewport, x, y, default_cache: :interface)
        @name = add_text(8, 0, LIST_WIDTH - 60, 16, '', color: WHITE)
        @quantity = add_text(LIST_WIDTH - 50, 0, 40, 16, '', 2, color: WHITE)
        @register = add_sprite(LIST_WIDTH - 82, 2, BagHorizon.file('register'))
        @register.src_rect.set(0, 0, 28, 12)
        [@name, @quantity].each { |text| text.z = 7 }
        @register.z = 7
      end

      # @param id [Integer, Symbol, nil] objet
      # @param close [Boolean] ligne « Fermer le sac »
      # @param selected [Boolean]
      def set(id, close, selected)
        shown = !(id.nil? && !close)
        self.visible = shown
        return unless shown

        color = selected ? DARK : WHITE
        @name.load_color(color)
        @quantity.load_color(color)
        if close
          @name.text = text_get(22, 7)
          @quantity.text = ''
          @register.visible = false
          return
        end

        item = data_item(id)
        @name.text = item.exact_name
        @quantity.text = item.is_limited ? "x #{$bag.item_quantity(id)}" : ''
        @register.visible = $bag.shortcuts.include?(item.db_symbol)
      end
    end

    # Liste des objets (même interface que UI::Bag::ButtonList)
    class ItemList
      # @return [Integer]
      attr_reader :index

      # @param viewport [Viewport]
      def initialize(viewport)
        @box = Sprite.new(viewport).set_bitmap(BagHorizon.file('list'), :interface)
        @box.set_position(LIST_X, LIST_Y)
        @box.z = 5
        @cursor = Sprite.new(viewport).set_bitmap(BagHorizon.file('cursor'), :interface)
        @cursor.z = 6
        @rows = Array.new(ROWS) { |i| Row.new(viewport, LIST_X, row_y(i)) }
        @track = Sprite.new(viewport).set_bitmap(BagHorizon.file('slider_track'), :interface)
        @track.set_position(LIST_X + LIST_WIDTH + 1, LIST_Y + 4)
        @track.z = 5
        @slider = Sprite.new(viewport).set_bitmap(BagHorizon.file('slider'), :interface)
        @slider.z = 6
        @item_list = []
        @index = 0
        @top = 0
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

      # @param index [Integer] (la dernière ligne, après les objets, est « Fermer le sac »)
      def index=(index)
        @index = index.clamp(0, @item_list.size)
        refresh
      end

      # Le sac de PSDK change @index puis appelle move_up (objet suivant) / move_down (précédent)
      def move_up
        self.index = @index + 1
      end

      def move_down
        self.index = @index - 1
      end

      # @return [Integer] décalage entre la ligne sous la souris et la sélection
      def mouse_delta_index
        position = position_at(Mouse.x, Mouse.y)
        return position ? position - @index : 0
      end

      # Ligne (index) sous la souris, ou nil
      # @return [Integer, nil]
      def position_at(mx, my)
        return nil unless mx.between?(LIST_X, LIST_X + LIST_WIDTH - 1)

        row = (my - LIST_Y - ROW_TOP).div(ROW_HEIGHT)
        return nil unless row.between?(0, ROWS - 1)

        position = @top + row
        return position <= @item_list.size ? position : nil
      end

      private

      # @param i [Integer]
      def row_y(i)
        return LIST_Y + ROW_TOP + i * ROW_HEIGHT
      end

      def refresh
        count = @item_list.size + 1
        @top = @index if @index < @top
        @top = @index - ROWS + 1 if @index >= @top + ROWS
        @top = @top.clamp(0, [count - ROWS, 0].max)
        @rows.each_with_index do |row, i|
          position = @top + i
          row.set(@item_list[position], position == @item_list.size, position == @index)
        end
        @cursor.set_position(LIST_X - 2, row_y(@index - @top) - 4)
        @track.visible = @slider.visible = count > ROWS
        track_h = @track.bitmap.height - @slider.bitmap.height
        @slider.set_position(@track.x - 1, @track.y + (count > 1 ? track_h * @index / (count - 1) : 0))
      end
    end
  end
end
