# Sac PE : grille des objets
module UI
  module BagPE
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
  end
end
