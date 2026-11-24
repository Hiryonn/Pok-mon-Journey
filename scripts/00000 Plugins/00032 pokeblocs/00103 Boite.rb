# Pokéblocs : la Boîte Pokébloc
#   Haut / Bas : choisir un Pokébloc (Gauche / Droite : page)   A : Donner / Jeter   B : fermer
module Pokeblocs
  class CaseScene < GamePlay::BaseCleanUpdate
    DARK = 0
    WHITE = 10
    ROWS = 11
    ROW_H = 18
    LIST_X = 132
    LIST_Y = 30

    def initialize
      super()
      @index = 0
      @top = 0
    end

    def update_inputs
      if @check_empty
        @check_empty = false
        if Pokeblocs.blocks.empty?
          display_message(Pokeblocs.t('La Boîte Pokébloc est vide.', 'The Pokéblock Case is empty.'))
          @running = false
          return false
        end
      end
      count = Pokeblocs.blocks.size
      if Input.repeat?(:DOWN) && count > 0
        move((@index + 1) % count)
      elsif Input.repeat?(:UP) && count > 0
        move((@index - 1) % count)
      elsif Input.repeat?(:RIGHT) && count > 0
        move([@index + ROWS, count - 1].min)
      elsif Input.repeat?(:LEFT) && count > 0
        move([@index - ROWS, 0].max)
      elsif Input.trigger?(:A) && count > 0
        play_decision_se
        choose
      elsif Input.trigger?(:B)
        play_cancel_se
        @running = false
      end
      return true
    end

    private

    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport)
      @stack.add_sprite(0, 0, Pokeblocs.file('boite'))
      @stack.add_text(6, 1, 200, 16, Pokeblocs.t('Boîte Pokébloc', 'Pokéblock Case'), color: WHITE)
      @count_text = @stack.add_text(214, 1, 100, 16, '', 2, color: WHITE)
      @cursor = @stack.add_sprite(LIST_X, LIST_Y, Pokeblocs.file('ligne'))
      @rows = Array.new(ROWS) do |i|
        y = LIST_Y + i * ROW_H
        { icon: @stack.add_sprite(LIST_X + 3, y + 1, nil),
          name: @stack.add_text(LIST_X + 22, y + 2, 120, 16, '', color: DARK),
          level: @stack.add_text(LIST_X + 136, y + 2, 38, 16, '', 2, color: DARK) }
      end
      @big = @stack.add_sprite(12, 126, nil)
      @level_text = @stack.add_text(64, 132, 56, 16, '', color: DARK)
      @feel_text = @stack.add_text(64, 150, 56, 16, '', color: DARK)
      @stack.with_font(20) do
        @flavor_texts = Array.new(5) do |i|
          @stack.add_text(12 + (i % 2) * 54, 182 + (i / 2) * 15, 52, 13, '', color: DARK)
        end
      end
      @check_empty = true
      refresh
    end

    def move(index)
      return if index == @index

      @index = index
      play_cursor_se
      refresh
    end

    def refresh
      list = Pokeblocs.blocks
      @index = @index.clamp(0, [list.size - 1, 0].max)
      @top = @index if @index < @top
      @top = @index - ROWS + 1 if @index >= @top + ROWS
      @top = 0 if list.size <= ROWS
      cap = Pokeblocs.capacity
      @count_text.text = cap > 0 ? "#{list.size}/#{cap}" : list.size.to_s
      @rows.each_with_index do |row, i|
        block = list[@top + i]
        row.each_value { |sprite| sprite.visible = !block.nil? }
        next unless block

        row[:icon].set_bitmap(Pokeblocs.icon(block), :interface)
        row[:name].text = Pokeblocs.name(block)
        row[:level].text = Pokeblocs.t("Nv.#{Pokeblocs.level(block)}", "Lv.#{Pokeblocs.level(block)}")
      end
      @cursor.visible = !list.empty?
      @cursor.y = LIST_Y + (@index - @top) * ROW_H
      refresh_detail(list[@index])
    end

    def refresh_detail(block)
      ([@big, @level_text, @feel_text] + @flavor_texts).each { |s| s.visible = !block.nil? }
      return unless block

      @big.set_bitmap(Pokeblocs.big_icon(block), :interface)
      @level_text.text = Pokeblocs.t("Niv. #{Pokeblocs.level(block)}", "Lv. #{Pokeblocs.level(block)}")
      @feel_text.text = Pokeblocs.t("Douc. #{block['feel']}", "Feel #{block['feel']}")
      names = Pokeblocs.fr? ? %w[Épicé Sec Sucré Amer Acide] : %w[Spicy Dry Sweet Bitter Sour]
      @flavor_texts.each_with_index { |text, i| text.text = "#{names[i]} #{block['flavors'][i]}" }
    end

    def choose
      block = Pokeblocs.blocks[@index]
      return unless block

      choice = display_message(Pokeblocs.t("Que faire avec ce #{Pokeblocs.name(block)} ?", "What do you want to do with the #{Pokeblocs.name(block)}?"),
                               1, Pokeblocs.t('Donner', 'Give'), Pokeblocs.t('Jeter', 'Toss'), Pokeblocs.t('Retour', 'Back'))
      case choice
      when 0 then give(block)
      when 1 then toss(block)
      end
    end

    def give(block)
      if $actors.none? { |pokemon| !pokemon.egg? }
        display_message(Pokeblocs.t('Il n’y a pas de Pokémon.', 'There is no Pokémon.'))
        return
      end
      call_scene(ConditionScene, block)
      refresh
      @check_empty = true if Pokeblocs.blocks.empty?
    end

    def toss(block)
      choice = display_message(Pokeblocs.t("Jeter le #{Pokeblocs.name(block)} ?", "Throw away the #{Pokeblocs.name(block)}?"), 1,
                               Pokeblocs.t('Oui', 'Yes'), Pokeblocs.t('Non', 'No'))
      return unless choice == 0

      Pokeblocs.remove(block)
      display_message(Pokeblocs.t("Le #{Pokeblocs.name(block)} a été jeté.", "The #{Pokeblocs.name(block)} was thrown away."))
      refresh
      @check_empty = true if Pokeblocs.blocks.empty?
    end
  end
end
