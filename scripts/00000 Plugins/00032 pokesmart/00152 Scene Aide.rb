# PokeSmart : scène de l'appli Aide (interface fixe à part du téléphone, aux couleurs du Pokédex Horizon)
#
# Haut / bas : tutoriel       Gauche / droite : rubrique       A : page suivante (puis tutoriel suivant)
# L / R : page précédente / suivante       B : quitter
# Souris : clic sur un tutoriel, clic sur la page = page suivante, molette = tutoriel, clic droit = quitter
# Chaque page peut avoir une image d'exemple (graphics/interface/aide/, voir HELP_IMAGE_DIR).
module GamePlay
  class Aide < BaseCleanUpdate::FrameBalanced
    PS = UI::PokeSmart
    DARK = 0
    WHITE = 9
    SMALL = 20
    BG = 'horizon/team/fond'
    HEADER = 'horizon/header'
    FOOTER = 'horizon/tcard/button_background'
    LIST_X = 6
    LIST_Y = 32
    LIST_W = 104
    ROW_HEIGHT = 22
    ROWS = 8
    CARD_X = 116
    CARD_W = 198
    IMAGE_H = 96
    TEXT_X = 6

    # @param category [Symbol, nil] id de la rubrique à ouvrir
    def initialize(category = nil)
      super()
      @categories = PS.help_categories
      @category = [@categories.index { |c| c[:id].to_s == category.to_s } || 0, 0].max
      @topic = 0
      @top = 0
      @page = 0
    end

    def update_inputs
      if Input.trigger?(:B)
        play_cancel_se
        @running = false
      elsif Input.trigger?(:A)
        next_page
      elsif Input.trigger?(:L)
        turn_page(-1)
      elsif Input.trigger?(:R)
        turn_page(1)
      elsif Input.repeat?(:DOWN)
        select_topic(@topic + 1 >= topics.size ? 0 : @topic + 1)
      elsif Input.repeat?(:UP)
        select_topic(@topic - 1 < 0 ? topics.size - 1 : @topic - 1)
      elsif Input.repeat?(:RIGHT)
        change_category(1)
      elsif Input.repeat?(:LEFT)
        change_category(-1)
      end
      return false
    end

    def update_mouse(_moved)
      if Mouse.trigger?(:RIGHT)
        play_cancel_se
        @running = false
        return false
      end
      if Mouse.wheel != 0
        delta = -Mouse.wheel
        Mouse.wheel = 0
        select_topic((@topic + (delta <=> 0)).clamp(0, topics.size - 1))
        return false
      end
      return true unless Mouse.trigger?(:LEFT)

      row = row_at(Mouse.x, Mouse.y)
      if row
        select_topic(row)
      elsif Mouse.x >= CARD_X && Mouse.y.between?(LIST_Y, 210)
        next_page
      end
      return false
    end

    def update_graphics
      return true
    end

    private

    # @return [Hash] rubrique affichée
    def category
      return @categories[@category]
    end

    # @return [Array<Hash>] tutoriels de la rubrique
    def topics
      return category[:topics]
    end

    # @return [Hash] tutoriel sélectionné
    def topic
      return topics[@topic]
    end

    # @return [Array] pages du tutoriel
    def pages
      return topic[:pages]
    end

    # @return [Integer, nil] tutoriel sous la souris
    def row_at(x, y)
      return nil unless x.between?(LIST_X, LIST_X + LIST_W - 1) && y >= LIST_Y

      row = (y - LIST_Y) / ROW_HEIGHT
      return nil if row >= ROWS || (y - LIST_Y) % ROW_HEIGHT >= ROW_HEIGHT - 2

      index = @top + row
      return index < topics.size ? index : nil
    end

    def select_topic(index)
      return if index == @topic

      play_cursor_se
      @topic = index
      @page = 0
      refresh
    end

    def change_category(delta)
      return if @categories.size < 2

      play_cursor_se
      @category = (@category + delta) % @categories.size
      @topic = @top = @page = 0
      refresh
    end

    # @param delta [Integer]
    def turn_page(delta)
      target = @page + delta
      return play_buzzer_se if target < 0 || target >= pages.size

      play_cursor_se
      @page = target
      refresh
    end

    # Page suivante ; après la dernière, premier écran du tutoriel suivant
    def next_page
      if @page + 1 < pages.size
        play_decision_se
        @page += 1
        refresh
      elsif @topic + 1 < topics.size
        play_decision_se
        @topic += 1
        @page = 0
        refresh
      else
        play_buzzer_se
      end
    end

    # --- Graphismes --------------------------------------------------------------------
    def create_graphics
      super
      create_frame
      create_rows
      create_card
      refresh
    end

    def stack(x = 0, y = 0)
      return UI::SpriteStack.new(@viewport, x, y, default_cache: :interface)
    end

    def picture(stack, x, y, name)
      return nil unless RPG::Cache.interface_exist?(name)

      return stack.add_sprite(x, y, name)
    end

    # @return [Bitmap] rectangle plein (cases de la liste, fiche)
    def box(width, height, color, border)
      bitmap = Bitmap.new(width, height)
      bitmap.fill_rect(0, 0, width, height, border)
      bitmap.fill_rect(1, 1, width - 2, height - 2, color)
      bitmap.update
      return bitmap
    end

    def create_frame
      @frame = stack
      unless picture(@frame, 0, 0, BG)
        bg = @frame.add_sprite(0, 0, UI::SpriteStack::NO_INITIAL_IMAGE)
        bg.bitmap = Bitmap.new(320, 240)
        bg.bitmap.fill_rect(0, 0, 320, 240, Color.new(229, 243, 250))
        bg.bitmap.update
      end
      picture(@frame, 0, 0, HEADER)
      picture(@frame, 0, 214, FOOTER)
      @title = @frame.add_text(96, 5, 128, 16, '', 1, color: WHITE)
      @left_arrow = picture(@frame, 84, 6, 'quest/arrow_frame_l')
      @right_arrow = picture(@frame, 228, 6, 'quest/arrow_frame_r')
      @frame.with_font(SMALL) do
        @app = @frame.add_text(6, 7, 80, 13, '', color: WHITE)
        @counter = @frame.add_text(232, 7, 82, 13, '', 2, color: WHITE)
        @help = @frame.add_text(8, 220, 304, 13, '', 1, color: WHITE)
      end
    end

    def create_rows
      @normal = box(LIST_W, ROW_HEIGHT - 2, Color.new(244, 250, 253), Color.new(150, 185, 205))
      @selected = box(LIST_W, ROW_HEIGHT - 2, Color.new(70, 130, 190), Color.new(40, 90, 150))
      @rows = Array.new(ROWS) do |i|
        row = stack(LIST_X, LIST_Y + i * ROW_HEIGHT)
        bg = row.add_sprite(0, 0, UI::SpriteStack::NO_INITIAL_IMAGE)
        bg.bitmap = @normal
        name = row.add_text(6, 1, LIST_W - 10, 16, '', color: DARK)
        name_selected = row.add_text(6, 1, LIST_W - 10, 16, '', color: WHITE)
        { stack: row, bg: bg, name: name, name_selected: name_selected }
      end
    end

    def create_card
      @card = stack(CARD_X, LIST_Y)
      bg = @card.add_sprite(0, 0, UI::SpriteStack::NO_INITIAL_IMAGE)
      bg.bitmap = box(CARD_W, 178, Color.new(250, 252, 254), Color.new(150, 185, 205))
      @card_title = @card.add_text(TEXT_X, 4, CARD_W - 12, 16, '', color: DARK)
      @image_frame = @card.add_sprite(TEXT_X, 24, UI::SpriteStack::NO_INITIAL_IMAGE)
      @image_frame.bitmap = box(CARD_W - 12, IMAGE_H + 2, Color.new(220, 232, 240), Color.new(150, 185, 205))
      @image = @card.add_sprite(TEXT_X + 1, 25, UI::SpriteStack::NO_INITIAL_IMAGE)
      @card.with_font(SMALL) do
        @card_text = @card.add_text(TEXT_X, 26, CARD_W - 12, 13, '', color: DARK)
        @card_text_low = @card.add_text(TEXT_X, 24 + IMAGE_H + 6, CARD_W - 12, 13, '', color: DARK)
        @card_page = @card.add_text(CARD_W - 60, 162, 54, 13, '', 2, color: DARK)
      end
    end

    # --- Mise à jour -------------------------------------------------------------------
    def refresh
      arrows = @categories.size > 1
      [@left_arrow, @right_arrow].compact.each { |arrow| arrow.visible = arrows }
      @title.text = PS.help_text(category[:name]).upcase
      @app.text = PS.help_text(PS::HELP_TITLE)
      @counter.text = "#{@category + 1} / #{@categories.size}"
      @help.text = if PS.french?
                     'Haut/Bas : tutoriel   </> : rubrique   A : suite   B : quitter'
                   else
                     'Up/Down: tutorial   </>: section   A: next   B: quit'
                   end
      refresh_rows
      refresh_card
    end

    def refresh_rows
      @top = @topic if @topic < @top
      @top = @topic - ROWS + 1 if @topic >= @top + ROWS
      @top = @top.clamp(0, [topics.size - ROWS, 0].max)
      @rows.each_with_index do |row, i|
        entry = topics[@top + i]
        row[:stack].visible = !entry.nil?
        next unless entry

        selected = @top + i == @topic
        row[:bg].bitmap = selected ? @selected : @normal
        label = small(PS.help_text(entry[:name]))
        row[:name].text = label
        row[:name_selected].text = label
        row[:name].visible = !selected
        row[:name_selected].visible = selected
      end
    end

    def refresh_card
      page = pages[@page]
      @card_title.text = small(PS.help_text(topic[:name]))
      @card_page.text = "#{@page + 1} / #{pages.size}"
      name = PS.help_image(page)
      has_image = name && RPG::Cache.interface_exist?(name)
      @image_frame.visible = @image.visible = has_image ? true : false
      @image.set_bitmap(name, :interface) if has_image
      text = small(PS.help_text(page))
      @card_text.visible = !has_image
      @card_text_low.visible = has_image ? true : false
      (has_image ? @card_text_low : @card_text).multiline_text = text
    end

    # La petite police n'a pas l'apostrophe typographique
    def small(text)
      return text.to_s.tr('’‘', "''")
    end
  end
end
