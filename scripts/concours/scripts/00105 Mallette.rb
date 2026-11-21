# Concours : la Mallette (accessoires par catégorie et fonds)
#   Haut / Bas : catégorie   A ou Droite : parcourir   B : retour (dans la grille) / fermer
module Concours
  class FashionCaseScene < GamePlay::BaseCleanUpdate
    DARK = 0
    WHITE = 10
    COLS = 5
    ROWS = 3
    CELL = 42
    GRID_X = 106
    GRID_Y = 26
    LIST_Y = 26
    LIST_H = 12

    def initialize
      super()
      @tabs = Concours.categories.map { |data| Concours.fetch(data, 'id').to_s } + [:backdrops]
      @tab = 0
      @index = 0
      @top = 0
      @focus = :list
    end

    def update_inputs
      @focus == :list ? update_list : update_grid
      return true
    end

    private

    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport)
      @stack.add_sprite(0, 0, Concours.file('mallette'))
      @stack.add_text(6, 1, 200, 16, Concours.t('Mallette', 'Fashion Case'), color: WHITE)
      @count_text = @stack.add_text(200, 1, 114, 16, '', 2, color: WHITE)
      @list_cursor = @stack.add_sprite(8, LIST_Y, Concours.file('ligne_menu'))
      @stack.with_font(20) do
        @tab_texts = @tabs.each_with_index.map do |tab, i|
          @stack.add_text(12, LIST_Y + i * LIST_H, 84, 13, tab_name(tab), color: DARK)
        end
      end
      @cells = Array.new(COLS * ROWS) do |i|
        x = GRID_X + (i % COLS) * CELL
        y = GRID_Y + (i / COLS) * CELL
        cell = { back: @stack.add_sprite(x, y, Concours.file('case')), icon: @stack.add_sprite(x + 20, y + 20, nil) }
        @stack.with_font(20) { cell[:count] = @stack.add_text(x + 2, y + 27, 36, 13, '', 2, color: DARK) }
        cell
      end
      @grid_cursor = @stack.add_sprite(0, 0, Concours.file('curseur'))
      @name_text = @stack.add_text(108, 186, 204, 16, '', color: DARK)
      @stack.with_font(20) { @info_text = @stack.add_text(108, 202, 204, 13, '', color: DARK) }
      refresh
    end

    def tab_name(tab)
      return Concours.t('Fonds', 'Backdrops') if tab == :backdrops

      data = Concours.categories.find { |c| Concours.fetch(c, 'id').to_s == tab }
      return Concours.local(Concours.fetch(data, 'name'), tab.to_s)
    end

    # @return [Array<String>] accessoires ou fonds de l'onglet
    def entries
      tab = @tabs[@tab]
      return Concours.backdrops.map { |data| Concours.fetch(data, 'id').to_s } if tab == :backdrops

      return Concours.accessories.select { |data| Concours.fetch(data, 'category').to_s == tab }.map { |data| Concours.fetch(data, 'id').to_s }
    end

    def backdrops?
      return @tabs[@tab] == :backdrops
    end

    def owned?(id)
      return backdrops? ? Concours.backdrop?(id) : Concours.accessory_count(id) > 0
    end

    def update_list
      if Input.repeat?(:DOWN)
        change_tab((@tab + 1) % @tabs.size)
      elsif Input.repeat?(:UP)
        change_tab((@tab - 1) % @tabs.size)
      elsif (Input.trigger?(:A) || Input.trigger?(:RIGHT)) && !entries.empty?
        play_decision_se
        @focus = :grid
        @index = 0
        refresh
      elsif Input.trigger?(:B)
        play_cancel_se
        @running = false
      end
    end

    def update_grid
      count = entries.size
      if Input.repeat?(:RIGHT)
        move((@index + 1).clamp(0, count - 1))
      elsif Input.repeat?(:LEFT)
        @index % COLS == 0 ? back_to_list : move(@index - 1)
      elsif Input.repeat?(:DOWN)
        move([@index + COLS, count - 1].min)
      elsif Input.repeat?(:UP)
        move([@index - COLS, 0].max)
      elsif Input.trigger?(:B)
        back_to_list
      end
    end

    def back_to_list
      play_cancel_se
      @focus = :list
      refresh
    end

    def change_tab(tab)
      @tab = tab
      @index = 0
      @top = 0
      play_cursor_se
      refresh
    end

    def move(index)
      return if index == @index

      @index = index
      play_cursor_se
      refresh
    end

    def refresh
      list = entries
      @top = (@index / COLS - ROWS + 1) * COLS if @index >= @top + COLS * ROWS
      @top = (@index / COLS) * COLS if @index < @top
      @list_cursor.y = LIST_Y + @tab * LIST_H
      @list_cursor.opacity = @focus == :list ? 255 : 140
      @cells.each_with_index do |cell, i|
        id = list[@top + i]
        cell.each_value { |s| s.visible = !id.nil? }
        next unless id

        image = backdrops? ? Concours.backdrop_image(id, true) : Concours.accessory_image(id)
        cell[:icon].set_bitmap(image, :interface)
        size = [cell[:icon].width, cell[:icon].height].max
        cell[:icon].zoom = size > 36 ? 36.0 / size : 1
        cell[:icon].set_origin(cell[:icon].width / 2, cell[:icon].height / 2)
        cell[:icon].opacity = owned?(id) ? 255 : 70
        cell[:count].text = backdrops? || !owned?(id) ? '' : "×#{Concours.accessory_count(id)}"
      end
      @grid_cursor.visible = @focus == :grid && !list.empty?
      slot = @index - @top
      @grid_cursor.set_position(GRID_X - 2 + (slot % COLS) * CELL, GRID_Y - 2 + (slot / COLS) * CELL)
      refresh_info(list)
    end

    def refresh_info(list)
      owned_count = list.count { |id| owned?(id) }
      @count_text.text = "#{owned_count}/#{list.size}"
      id = @focus == :grid ? list[@index] : nil
      unless id
        @name_text.text = tab_name(@tabs[@tab])
        @info_text.text = Concours.t('A : parcourir   B : fermer', 'A: browse   B: close')
        return
      end
      if owned?(id)
        @name_text.text = backdrops? ? Concours.backdrop_name(id) : Concours.accessory_name(id)
        @info_text.text = backdrops? ? Concours.t('Fond obtenu', 'Backdrop obtained') : Concours.t("Quantité : #{Concours.accessory_count(id)}", "Quantity: #{Concours.accessory_count(id)}")
      else
        @name_text.text = '?????'
        @info_text.text = Concours.t('Pas encore obtenu', 'Not obtained yet')
      end
    end
  end
end
