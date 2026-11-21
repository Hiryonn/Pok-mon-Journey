# Berrydex : la scène (liste des baies, puis fiche en 3 pages : FICHE, CULTURE, COMBAT)
#
# Liste : haut / bas = baie, gauche / droite = 10 baies, A = fiche (baie trouvée), B = quitter
# Fiche : gauche / droite = page, haut / bas = baie trouvée précédente / suivante, B = retour à la liste
# Souris : molette, clic sur une baie (re-clic = fiche), clic droit = retour
module GamePlay
  class Berrydex < BaseCleanUpdate::FrameBalanced
    BD = ::Berrydex
    # Couleurs des textes (0 sombre, 9 blanc)
    DARK = 0
    WHITE = 9
    SMALL = 20
    # Graphismes du Pokédex Horizon (interface_horizon) ; sinon fond uni
    BG = 'horizon/team/fond'
    HEADER = 'horizon/header'
    FOOTER = 'horizon/tcard/button_background'
    # Pastille du bandeau
    TITLE_X = 96
    TITLE_W = 128
    TITLE_Y = 5
    # Carte de gauche, panneau de droite
    CARD_X = 6
    PANEL_X = 136
    PANEL_Y = 32
    ROW_TOP = 4
    ROW_HEIGHT = 16
    ROWS = 10
    # Objet donné à UI::TypeSprite (il lit #type)
    TypeHolder = Struct.new(:type)
    PAGES = [%w[FICHE DATA], %w[CULTURE GROWTH], %w[COMBAT BATTLE]].freeze

    def initialize(start = nil)
      super()
      BD.register_bag
      @list = BD.config.show_unknown == false ? BD.list.select { |db| BD.found?(db) } : BD.list
      @index = [@list.index(start&.to_sym) || 0, 0].max
      @top = 0
      @page = 0
      @mode = :list
    end

    def update_inputs
      return false unless @list
      return update_list_inputs if @mode == :list

      return update_page_inputs
    end

    def update_mouse(_moved)
      return false if @list.empty?

      if Mouse.trigger?(:RIGHT)
        back
        return false
      end
      if Mouse.wheel != 0
        delta = -Mouse.wheel
        Mouse.wheel = 0
        @mode == :list ? select(@index + delta) : jump_found(delta <=> 0)
        return false
      end
      return true unless Mouse.trigger?(:LEFT) && @mode == :list

      row = row_at(Mouse.x, Mouse.y)
      return true unless row

      row == @index ? open_page : select(row)
      return false
    end

    def update_graphics
      return true
    end

    private

    # --- Entrées ---------------------------------------------------------------------
    def update_list_inputs
      if Input.trigger?(:B)
        back
        return false
      end
      return false if @list.empty?

      if Input.trigger?(:A)
        open_page
      elsif Input.repeat?(:DOWN)
        select(@index + 1 > @list.size - 1 ? 0 : @index + 1)
      elsif Input.repeat?(:UP)
        select(@index - 1 < 0 ? @list.size - 1 : @index - 1)
      elsif Input.repeat?(:RIGHT)
        select([@index + ROWS, @list.size - 1].min)
      elsif Input.repeat?(:LEFT)
        select([@index - ROWS, 0].max)
      end
      return false
    end

    def update_page_inputs
      if Input.trigger?(:B)
        back
      elsif Input.repeat?(:RIGHT)
        change_page(1)
      elsif Input.repeat?(:LEFT)
        change_page(-1)
      elsif Input.repeat?(:DOWN)
        jump_found(1)
      elsif Input.repeat?(:UP)
        jump_found(-1)
      end
      return false
    end

    def back
      play_cancel_se
      return @running = false if @mode == :list

      @mode = :list
      refresh
    end

    def open_page
      unless BD.found?(current)
        play_buzzer_se
        return
      end
      play_decision_se
      @mode = :page
      refresh
    end

    def change_page(delta)
      play_cursor_se
      @page = (@page + delta) % PAGES.size
      refresh
    end

    # Baie trouvée suivante / précédente (fiches)
    def jump_found(direction)
      return if direction == 0

      found = @list.each_index.select { |i| BD.found?(@list[i]) }
      return if found.size < 2

      position = found.index(@index) || 0
      play_cursor_se
      @index = found[(position + direction) % found.size]
      refresh
    end

    # @param index [Integer]
    def select(index)
      index = index.clamp(0, [@list.size - 1, 0].max)
      return if index == @index

      play_cursor_se
      @index = index
      refresh
    end

    # @return [Symbol, nil]
    def current
      return @list[@index]
    end

    # @return [Integer, nil] ligne de la liste sous la souris
    def row_at(x, y)
      return nil unless x.between?(PANEL_X, PANEL_X + 177) && y >= PANEL_Y + ROW_TOP

      row = (y - PANEL_Y - ROW_TOP) / ROW_HEIGHT
      return nil if row >= ROWS

      index = @top + row
      return index < @list.size ? index : nil
    end

    # --- Graphismes ------------------------------------------------------------------
    def create_graphics
      super
      create_frame
      create_card
      create_list
      create_page
      refresh
    end

    def stack(x = 0, y = 0)
      return UI::SpriteStack.new(@viewport, x, y, default_cache: :interface)
    end

    # Image de l'interface si elle existe
    def picture(stack, x, y, name)
      return nil unless RPG::Cache.interface_exist?(name)

      return stack.add_sprite(x, y, name)
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
      @title = @frame.add_text(TITLE_X, TITLE_Y, TITLE_W, 16, '', 1, color: WHITE)
      @left_arrow = picture(@frame, TITLE_X - 12, 6, 'quest/arrow_frame_l')
      @right_arrow = picture(@frame, TITLE_X + TITLE_W + 4, 6, 'quest/arrow_frame_r')
      @frame.with_font(SMALL) do
        @counter = @frame.add_text(232, 7, 82, 13, '', 2, color: WHITE)
        @help = @frame.add_text(8, 220, 304, 13, '', 1, color: WHITE)
      end
    end

    def create_card
      @card = stack(CARD_X, PANEL_Y)
      @card.add_sprite(0, 0, BD.file('card'))
      @tag = @card.add_sprite(61, 40, UI::SpriteStack::NO_INITIAL_IMAGE, type: Sprite::WithColor)
      @card_icon = @card.add_sprite(61, 40, UI::SpriteStack::NO_INITIAL_IMAGE, type: UI::ItemSprite)
      @unknown = @card.add_sprite(49, 28, BD.file('unknown'))
      @number = @card.add_text(0, 78, 122, 16, '', 1, color: DARK)
      @name = @card.add_text(0, 94, 122, 16, '', 1, color: DARK)
      @card.with_font(SMALL) do
        @status = @card.add_text(0, 114, 122, 13, '', 1, color: DARK)
        @firmness = @card.add_text(0, 130, 122, 13, '', 1, color: DARK)
      end
      @best_flavor = @card.add_sprite(35, 150, UI::SpriteStack::NO_INITIAL_IMAGE)
      @card.with_font(SMALL) { @best_flavor_text = @card.add_text(35, 150, 52, 14, '', 1, color: WHITE) }
    end

    def create_list
      @list_ui = stack(PANEL_X, PANEL_Y)
      @list_ui.add_sprite(0, 0, BD.file('list'))
      @cursor = @list_ui.add_sprite(0, ROW_TOP - 1, BD.file('cursor'))
      @rows = Array.new(ROWS) do |i|
        y = ROW_TOP + i * ROW_HEIGHT
        found = @list_ui.add_sprite(6, y + 1, BD.file('found'))
        number = @list_ui.add_text(24, y, 34, 16, '', color: WHITE)
        name = @list_ui.add_text(58, y, 114, 16, '', color: WHITE)
        [found, number, name]
      end
    end

    def create_page
      @page_ui = stack(PANEL_X, PANEL_Y)
      @page_ui.add_sprite(0, 0, BD.file('info'))
      @lines = Array.new(4) { |i| @page_ui.add_text(6, 4 + i * 16, 166, 16, '', color: DARK) }
      @pills = BD::FLAVORS.each_with_index.map do |flavor, i|
        x = 6 + (i % 2) * 86
        y = 56 + (i / 2) * 16
        pill = @page_ui.add_sprite(x, y, BD.file("flavor_#{flavor[0]}"))
        label = value = nil
        @page_ui.with_font(SMALL) do
          label = @page_ui.add_text(x, y, 52, 14, BD.tr(flavor[2]), 1, color: WHITE)
          value = @page_ui.add_text(x + 56, y, 26, 14, '', color: DARK)
        end
        [pill, label, value]
      end
      @icons = Array.new(6) { |i| @page_ui.add_sprite(6 + i * 28, 0, UI::SpriteStack::NO_INITIAL_IMAGE) }
      @zone_icons = Array.new(3) { |i| @page_ui.add_sprite(6 + i * 28, 0, UI::SpriteStack::NO_INITIAL_IMAGE) }
      @type = @page_ui.add_sprite(6, 22, UI::SpriteStack::NO_INITIAL_IMAGE, type: UI::TypeSprite)
      @page_ui.with_font(SMALL) do
        @small_lines = Array.new(3) { |i| @page_ui.add_text(6, 0, 166, 13, '', color: DARK) }
        @text = @page_ui.add_text(6, 0, 166, 13, '', color: DARK)
      end
    end

    # --- Mise à jour -----------------------------------------------------------------
    def refresh
      @list_ui.visible = @mode == :list
      @page_ui.visible = @mode == :page
      [@left_arrow, @right_arrow].compact.each { |arrow| arrow.visible = @mode == :page }
      @counter.text = @mode == :page ? "Page #{@page + 1} / #{PAGES.size}" : "#{BD.found_count} / #{BD.list.size}"
      @title.text = @mode == :page ? BD.tr(PAGES[@page]) : 'BERRYDEX'
      @help.text = help_text
      refresh_card
      @mode == :list ? refresh_list : refresh_page
    end

    def help_text
      if @list.empty?
        BD.t('Aucune baie trouvée.   B : Retour', 'No berry found.   B: Back')
      elsif @mode == :list
        BD.t('A : Fiche   < > : 10 baies   B : Quitter', 'A: Data   < >: 10 berries   B: Quit')
      else
        BD.t('< > : Page   Haut / Bas : Baie   B : Retour', '< >: Page   Up / Down: Berry   B: Back')
      end
    end

    def refresh_card
      db = current
      found = db && BD.found?(db)
      @unknown.visible = !found
      @tag.visible = @card_icon.visible = false
      @number.text = db ? "N° #{format('%03d', BD.number(db))}" : ''
      @name.text = found ? data_item(db).name : (db ? '?????' : '')
      @status.text = db ? (found ? BD.t('Trouvée', 'Found') : BD.t('Pas encore trouvée', 'Not found yet')) : ''
      @firmness.text = ''
      @best_flavor.visible = @best_flavor_text.visible = false
      return unless found

      @unknown.visible = false
      show_tag(db)
      item = data_item(db)
      berry = item.berry_data
      @firmness.text = BD.tr(BD::FIRMNESS[berry&.firmness&.to_sym] || ['', '']) if berry
      best = best_flavor(item)
      return unless best

      @best_flavor.set_bitmap(BD.file("flavor_#{best[0]}"), :interface)
      @best_flavor_text.text = BD.tr(best[2])
      @best_flavor.visible = @best_flavor_text.visible = true
    end

    # Étiquette de la baie (64 x 64), ou son icône d'objet
    def show_tag(db)
      if (file = BD.tag_file(db))
        @tag.set_bitmap(file, :interface)
        @tag.set_origin(@tag.width / 2, @tag.height / 2)
        @tag.visible = true
      else
        @card_icon.data = db
        @card_icon.set_origin(@card_icon.width / 2, @card_icon.height / 2)
        @card_icon.zoom = 2
        @card_icon.visible = true
      end
    end

    # Saveur la plus forte
    def best_flavor(item)
      cooking = item.cooking_data
      return nil unless cooking

      best = BD::FLAVORS.max_by { |flavor| cooking.send(flavor[1]).to_i }
      return cooking.send(best[1]).to_i > 0 ? best : nil
    end

    def refresh_list
      @top = @index.clamp(@top, @top + ROWS - 1) == @index ? @top : (@index < @top ? @index : @index - ROWS + 1)
      @top = @top.clamp(0, [@list.size - ROWS, 0].max)
      @cursor.visible = !@list.empty?
      @cursor.y = @list_ui.y + ROW_TOP - 1 + (@index - @top) * ROW_HEIGHT
      @rows.each_with_index do |(icon, number, name), i|
        db = @list[@top + i]
        found = db && BD.found?(db)
        icon.visible = found ? true : false
        number.text = db ? format('%03d', BD.number(db)) : ''
        name.text = db ? (found ? data_item(db).name : '?????') : ''
      end
    end

    def refresh_page
      db = current
      return unless db

      item = data_item(db)
      @lines.each do |line|
        line.text = ''
        line.x = @page_ui.x + 6
      end
      (@small_lines + [@text]).each { |line| line.text = '' }
      @pills.flatten.each { |sprite| sprite.visible = false }
      (@icons + @zone_icons).each { |icon| icon.visible = false }
      @type.visible = false
      case @page
      when 0 then page_data(item)
      when 1 then page_growth(item)
      else page_battle(item)
      end
    end

    # @param line [Text]
    def set_line(line, y, text)
      line.y = @page_ui.y + y - Text::Util::FOY
      line.text = text
      line.visible = true
    end

    # FICHE : taille, fermeté, saveurs, douceur, description
    def page_data(item)
      berry = item.berry_data
      cooking = item.cooking_data
      set_line(@lines[0], 4, BD.t("Taille : #{BD.decimal(berry&.size)} cm", "Size: #{BD.decimal(berry&.size)} cm"))
      firmness = BD.tr(BD::FIRMNESS[berry&.firmness&.to_sym] || ['-', '-'])
      set_line(@lines[1], 20, BD.t("Fermeté : #{firmness}", "Firmness: #{firmness}"))
      set_line(@lines[2], 38, BD.t('Saveurs', 'Flavors'))
      @pills.each_with_index do |(pill, label, value), i|
        pill.visible = label.visible = value.visible = true
        value.text = cooking ? cooking.send(BD::FLAVORS[i][1]).to_i.to_s : '0'
      end
      set_line(@lines[3], 106, BD.t("Douceur : #{cooking&.smoothness.to_i}", "Smoothness: #{cooking&.smoothness.to_i}"))
      @text.y = @page_ui.y + 126 - Text::Util::FOY
      @text.multiline_text = small(item.descr)
    end

    # CULTURE : pousse, récolte, assèchement, météo et lieux favorables
    def page_growth(item)
      berry = item.berry_data
      set_line(@lines[0], 4, BD.t("Pousse : #{berry&.growth.to_i} h", "Growth: #{berry&.growth.to_i} h"))
      harvest = "#{berry&.min_yield.to_i} - #{berry&.max_yield.to_i}"
      set_line(@lines[1], 20, BD.t("Récolte : #{harvest} baies", "Yield: #{harvest} berries"))
      set_line(@lines[2], 36, BD.t("Assèchement : #{berry&.drain_rate.to_i}", "Drain rate: #{berry&.drain_rate.to_i}"))
      weathers = BD.weathers(item.db_symbol)
      set_line(@lines[3], 56, BD.t('Météo favorable', 'Preferred weather'))
      show_icons(@icons, weathers.map { |w| [w, true] }, 74)
      set_line(@small_lines[0], weathers.empty? ? 76 : 100, names(weathers.map { |w| [w, true] }))
      zones = BD.zones(item.db_symbol)
      set_line(@small_lines[1], 118, BD.t('Lieux', 'Places'))
      show_icons(@zone_icons, zones, 134)
      set_line(@small_lines[2], zones.empty? ? 134 : 160, names(zones))
    end

    def show_icons(sprites, entries, y)
      sprites.each_with_index do |sprite, i|
        name, preferred = entries[i]
        file = name && BD.file("weather/#{name}#{preferred ? '' : '_unpref'}")
        next unless file && RPG::Cache.interface_exist?(file)

        sprite.set_bitmap(file, :interface)
        sprite.y = @page_ui.y + y
        sprite.visible = true
      end
    end

    # @param entries [Array<Array(String, Boolean)>]
    def names(entries)
      return BD.t('Inconnu', 'Unknown') if entries.empty?

      return entries.map { |name, preferred| BD.tr(BD::WEATHER_NAMES[name]) + (preferred ? '' : BD.t(' (à éviter)', ' (avoid)')) }.join(', ')
    end

    # COMBAT : Don Naturel (type, puissance), Dégommage, effet
    def page_battle(item)
      berry = item.berry_data
      set_line(@lines[0], 4, BD.t('Don Naturel', 'Natural Gift'))
      type = berry&.natural_gift_type
      if type && type != :__undef__
        @type.data = TypeHolder.new(data_type(type).id)
        @type.y = @page_ui.y + 23
        @type.visible = true
      end
      set_line(@lines[1], 20, '')
      @lines[1].x = @page_ui.x + 44
      @lines[1].text = BD.t("Puissance #{berry&.natural_gift_power.to_i}", "Power #{berry&.natural_gift_power.to_i}")
      set_line(@lines[2], 40, BD.t("Dégommage : #{item.fling_power.to_i}", "Fling: #{item.fling_power.to_i}"))
      set_line(@lines[3], 60, BD.t('Effet', 'Effect'))
      @text.y = @page_ui.y + 78 - Text::Util::FOY
      @text.multiline_text = small(BD.effect_text(item.db_symbol))
    end

    # La petite police n'a pas l'apostrophe typographique
    def small(text)
      return text.to_s.tr('’‘', "''")
    end
  end
end
