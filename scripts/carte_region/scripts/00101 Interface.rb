# Carte de région : cadres dessinés à la taille voulue, barres du haut et du bas, liste de choix, boîtes d'aperçu
module CarteRegion
  module_function

  # Cadre « 9 morceaux » (coins de 8 px) étiré à la taille voulue, gardé en cache
  # @return [Bitmap]
  def frame_bitmap(theme, name, width, height, border = 8)
    width = [width.to_i, border * 2].max
    height = [height.to_i, border * 2].max
    key = [theme, name, width, height]
    @frames ||= {}
    bmp = @frames[key]
    return bmp if bmp && !bmp.disposed?

    source_bmp = RPG::Cache.interface(theme_file(theme, name))
    src = Image.new(source_bmp.to_png, true)
    sw = src.width
    sh = src.height
    b = [border, sw / 2, sh / 2].min
    img = Image.new(width, height)
    mw = width - 2 * b
    mh = height - 2 * b
    smw = sw - 2 * b
    smh = sh - 2 * b
    # coins
    img.blt(0, 0, src, Rect.new(0, 0, b, b))
    img.blt(width - b, 0, src, Rect.new(sw - b, 0, b, b))
    img.blt(0, height - b, src, Rect.new(0, sh - b, b, b))
    img.blt(width - b, height - b, src, Rect.new(sw - b, sh - b, b, b))
    # bords et milieu étirés
    img.stretch_blt(Rect.new(b, 0, mw, b), src, Rect.new(b, 0, smw, b)) if mw > 0
    img.stretch_blt(Rect.new(b, height - b, mw, b), src, Rect.new(b, sh - b, smw, b)) if mw > 0
    img.stretch_blt(Rect.new(0, b, b, mh), src, Rect.new(0, b, b, smh)) if mh > 0
    img.stretch_blt(Rect.new(width - b, b, b, mh), src, Rect.new(sw - b, b, b, smh)) if mh > 0
    img.stretch_blt(Rect.new(b, b, mw, mh), src, Rect.new(b, b, smw, smh)) if mw > 0 && mh > 0
    bmp = Bitmap.new(width, height)
    img.copy_to_bitmap(bmp)
    img.dispose
    src.dispose
    return @frames[key] = bmp
  end

  # Calque de cases colorées (cases éclairées, lieux pas encore visités…)
  # @param cells [Array<Array(Integer, Integer)>]
  # @param color [Array(Integer, Integer, Integer, Integer)]
  # @return [Bitmap, nil]
  def cells_bitmap(width, height, cells, color)
    return nil if cells.empty? || width <= 0 || height <= 0

    img = Image.new(width, height)
    col = Color.new(*color.map(&:to_i))
    cells.each { |x, y| img.fill_rect(x * TILE, y * TILE, TILE, TILE, col) }
    bmp = Bitmap.new(width, height)
    img.copy_to_bitmap(bmp)
    img.dispose
    return bmp
  end
end

module UI
  module CarteRegion
    WHITE = 9
    DARK = 0
    SMALL = 20
    M = ::CarteRegion

    # Cadre posé sur un SpriteStack
    module Framed
      def add_frame(theme, name, width, height)
        sprite = add_sprite(0, 0, UI::SpriteStack::NO_INITIAL_IMAGE)
        sprite.bitmap = M.frame_bitmap(theme, name, width, height)
        return sprite
      end

      # Bandeau de titre en haut d'une fenêtre (thèmes qui en ont un, comme Horizon)
      def add_title_band(theme, width)
        return nil unless M.theme_has?(theme, 'title')

        sprite = add_sprite(3, 3, UI::SpriteStack::NO_INITIAL_IMAGE)
        sprite.bitmap = M.frame_bitmap(theme, 'title', width - 6, 18, 4)
        return sprite
      end
    end

    # Barre du haut : nom de la région à gauche, mode à droite, progression au milieu
    class TopBar < SpriteStack
      include Framed
      HEIGHT = 20

      def initialize(viewport, theme, width)
        super(viewport, 0, 0, default_cache: :interface)
        add_frame(theme, 'bar_top', width, HEIGHT)
        if M.centered_header?(theme)
          # Horizon : région dans l'onglet sombre du milieu, progression à gauche, mode à droite
          tab = (width * 140 / 320.0).round
          left = (width - tab) / 2
          @region = add_text(left, 3, tab, 16, '', 1, color: WHITE)
          with_font(SMALL) do
            @info = add_text(6, 5, left - 10, 13, '', 0, color: WHITE)
            @mode = add_text(left + tab + 4, 5, left - 10, 13, '', 2, color: WHITE)
          end
        else
          @region = add_text(8, 3, width / 2, 16, '', color: WHITE)
          @mode = add_text(width / 2, 3, width / 2 - 8, 16, '', 2, color: WHITE)
          with_font(SMALL) { @info = add_text(0, 5, width, 13, '', 1, color: WHITE) }
        end
      end

      def region=(text)
        @region.text = text.to_s
      end

      def mode=(text)
        @mode.text = text.to_s
      end

      def info=(text)
        @info.text = text.to_s
      end
    end

    # Barre du bas : lieu sous le curseur et quartier
    class BottomBar < SpriteStack
      include Framed
      HEIGHT = 26

      def initialize(viewport, theme, width, screen_height)
        super(viewport, 0, screen_height - HEIGHT, default_cache: :interface)
        add_frame(theme, 'bar_bottom', width, HEIGHT)
        @name = add_text(8, 7, width - 120, 16, '', color: WHITE)
        with_font(SMALL) { @detail = add_text(width - 150, 9, 142, 13, '', 2, color: WHITE) }
      end

      def set(name, detail)
        @name.text = name.to_s
        @detail.text = detail.to_s
      end
    end

    # Petite boîte des touches (deux lignes qui changent toutes les 3 secondes)
    class ButtonHints < SpriteStack
      include Framed
      WIDTH = 132

      def initialize(viewport, theme, right, bottom)
        super(viewport, right - WIDTH, bottom - 38, default_cache: :interface)
        @frame = add_frame(theme, 'box', WIDTH, 36)
        @frame.opacity = 200
        with_font(SMALL) do
          @line1 = add_text(8, 5, WIDTH - 16, 13, '', color: WHITE)
          @line2 = add_text(8, 18, WIDTH - 16, 13, '', color: WHITE)
        end
        @hints = []
        @page = 0
        @counter = 0
      end

      def hints=(list)
        @hints = list.compact
        @page = 0 if @page * 2 >= @hints.size
        @counter = 0
        refresh
      end

      def update
        return if @hints.size <= 2

        @counter += 1
        return if @counter < 180

        @counter = 0
        @page = (@page + 1) % ((@hints.size + 1) / 2)
        refresh
      end

      private

      def refresh
        self.visible = !@hints.empty? && @shown != false
        @line1.text = @hints[@page * 2].to_s
        @line2.text = @hints[@page * 2 + 1].to_s
      end

      public

      def shown=(value)
        @shown = value
        self.visible = value && !@hints.empty?
      end
    end

    # Liste de choix (titre, lignes, défilement) ; garde la dernière ligne choisie
    class ChoiceList < SpriteStack
      include Framed
      ROW = 16
      attr_reader :index, :items

      # @param items [Array<String>]
      def initialize(viewport, theme, title, items, max_rows, screen_w, top, bottom, index = 0)
        @items = items
        @rows = [[items.size, max_rows.to_i].min, 1].max
        width = [[items.map { |s| s.to_s.size * 6 + 32 }.max.to_i, title.to_s.size * 6 + 24, 120].max, screen_w - 40].min
        height = @rows * ROW + 12 + (title.to_s.empty? ? 0 : 18)
        x = screen_w - width - 8
        y = [bottom - height - 4, top + 4].max
        super(viewport, x, y, default_cache: :interface)
        @theme = theme
        @width = width
        add_frame(theme, 'box', width, height)
        add_title_band(theme, width) unless title.to_s.empty?
        @list_y = 6
        unless title.to_s.empty?
          with_font(SMALL) { add_text(8, 6, width - 28, 13, title, color: WHITE) }
          @list_y = 22
        end
        @select = add_sprite(4, @list_y, UI::SpriteStack::NO_INITIAL_IMAGE)
        @select.bitmap = M.frame_bitmap(theme, 'select', width - 8, ROW, 3)
        @texts = Array.new(@rows) { |i| add_text(10, @list_y + i * ROW + 1, width - 20, ROW, '', color: WHITE) }
        @up = add_sprite(width - 16, @list_y - 6, M.theme_file(theme, 'arrow_up'))
        @down = add_sprite(width - 16, @list_y + @rows * ROW + 1, M.theme_file(theme, 'arrow_down'))
        @top = 0
        self.index = index.clamp(0, [items.size - 1, 0].max)
      end

      def index=(value)
        @index = value
        @top = @index if @index < @top
        @top = @index - @rows + 1 if @index >= @top + @rows
        @texts.each_with_index { |t, i| t.text = @items[@top + i].to_s }
        @select.y = y + @list_y + (@index - @top) * ROW
        @select.visible = !@items.empty?
        @up.visible = @top > 0
        @down.visible = @top + @rows < @items.size
      end

      # @return [Symbol, Integer, nil] :cancel, index choisi, ou nil
      def update_inputs
        return nil if @items.empty? && !Input.trigger?(:B)

        if Input.repeat?(:DOWN)
          self.index = (@index + 1) % @items.size
          return :move
        elsif Input.repeat?(:UP)
          self.index = (@index - 1) % @items.size
          return :move
        elsif Input.repeat?(:RIGHT) && @items.size > @rows
          self.index = [@index + @rows, @items.size - 1].min
          return :move
        elsif Input.repeat?(:LEFT) && @items.size > @rows
          self.index = [@index - @rows, 0].max
          return :move
        elsif Input.trigger?(:A)
          return @index
        elsif Input.trigger?(:B)
          return :cancel
        end
        return nil
      end

      def update_mouse
        if Mouse.wheel != 0
          self.index = (@index - (Mouse.wheel <=> 0)).clamp(0, [@items.size - 1, 0].max)
          Mouse.wheel = 0
          return :move
        end
        return :cancel if Mouse.trigger?(:RIGHT)
        return nil unless Mouse.trigger?(:LEFT)

        mx = Mouse.x - x
        my = Mouse.y - y - @list_y
        return :cancel unless mx.between?(0, @width) && my >= 0 && my < @rows * ROW

        row = @top + my / ROW
        return nil if row >= @items.size
        return row if row == @index

        self.index = row
        return :move
      end
    end

    # Boîte d'aperçu (monte du bas de l'écran) : titre, météo, image, texte, lieux voisins
    class PreviewBox < SpriteStack
      include Framed
      LINE = 13

      def initialize(viewport, theme, screen_w, bottom)
        super(viewport, 6, bottom, default_cache: :interface)
        @theme = theme
        @width = screen_w - 12
        @bottom = bottom
        @frame = add_sprite(0, 0, UI::SpriteStack::NO_INITIAL_IMAGE)
        add_title_band(theme, @width)
        @title = add_text(10, 4, @width - 50, 16, '', color: WHITE)
        @weather = add_sprite(@width - 26, 4, UI::SpriteStack::NO_INITIAL_IMAGE)
        @weather_text = nil
        with_font(SMALL) { @weather_text = add_text(@width - 130, 7, 100, 13, '', 2, color: WHITE) }
        @image = add_sprite(10, 26, UI::SpriteStack::NO_INITIAL_IMAGE)
        with_font(SMALL) { @body = add_text(10, 25, @width - 20, LINE, '', color: WHITE) }
        @lines = []
        self.visible = false
        @target_y = bottom
        @height = 0
      end

      attr_reader :height

      # @param title [String]
      # @param body [Array<String>] lignes (déjà coupées) ; texte coupé automatiquement si String
      # @param image [String, nil] image du lieu
      # @param weather [Symbol, nil]
      def show(title, body, image: nil, weather: nil, max_lines: 8, footer: nil)
        @title.text = title.to_s
        image_w = 0
        if image
          @image.set_bitmap(image, :interface)
          @image.visible = true
          zoom = [M::PREVIEW_IMAGE_W.to_f / @image.bitmap.width, 1.0].min
          @image.zoom = zoom
          image_w = (@image.bitmap.width * zoom).round + 8
        else
          @image.visible = false
        end
        set_weather(weather)
        @body.x = x + 10 + image_w
        @body.width = @width - 20 - image_w
        lines = body.is_a?(Array) ? body : wrap(body.to_s, @body.width)
        lines = lines.first(max_lines)
        lines << footer if footer
        @body.text = lines.join("\n")
        text_h = [lines.size, 1].max * LINE
        content = [text_h, image ? (@image.bitmap.height * @image.zoom_y).round : 0].max
        @height = 30 + content + 8
        @frame.bitmap = M.frame_bitmap(@theme, 'box', @width, @height)
        @target_y = @bottom - @height - 2
        self.visible = true
        return @height
      end

      def set_weather(weather)
        if weather && RPG::Cache.interface_exist?(M.icon_file("weather_#{weather}"))
          @weather.set_bitmap(M.icon_file("weather_#{weather}"), :interface)
          @weather.visible = true
          @weather_text.text = M.weather_text(weather)
        else
          @weather.visible = false
          @weather_text.text = ''
        end
      end

      # Coupe le texte en lignes à la largeur de la boîte
      def wrap(text, width)
        out = []
        text.split("\n").each do |para|
          line = ''
          para.split(' ').each do |word|
            test = line.empty? ? word : "#{line} #{word}"
            if @body.text_width(test) > width && !line.empty?
              out << line
              line = word
            else
              line = test
            end
          end
          out << line
        end
        return out
      end

      # Place la boîte (animation : ratio 0 = cachée, 1 = montée)
      def slide(ratio)
        set_position(x, (@bottom + (@target_y - @bottom) * ratio).round)
      end

      def hide
        self.visible = false
        set_position(x, @bottom)
      end
    end

    # Fiche détaillée d'un lieu (A dans l'aperçu) : Pokémon sauvages par type, progression
    class ExtendedPanel < SpriteStack
      include Framed
      ICON = 32

      def initialize(viewport, theme, x, y, width, height)
        super(viewport, x, y, default_cache: :interface)
        @theme = theme
        @width = width
        @height = height
        add_frame(theme, 'box', width, height)
        add_title_band(theme, width)
        @title = add_text(10, 4, width - 20, 16, '', color: WHITE)
        with_font(SMALL) do
          @tab = add_text(10, 7, width - 20, 13, '', 2, color: WHITE)
          @hint = add_text(10, height - 18, width - 20, 13, '', 1, color: WHITE)
        end
        @dynamic = []
        @page = 0
        self.visible = false
      end

      def dispose_dynamic
        @dynamic.each(&:dispose)
        @dynamic.clear
      end

      def dispose
        dispose_dynamic
        super
      end

      # @param zone_id [Integer]
      # @param pages [Array<Array(String, Array)>] [titre de la page, rencontres [[type, [[sym, forme]]]]]
      def open(title, zone_id, worldmap_id)
        @zone_id = zone_id
        @worldmap_id = worldmap_id
        @title.text = title
        @encounters = M.encounters(zone_id)
        @art = M.zone_image(zone_id)
        @pages = (@art ? [M.t('Lieu', 'Place')] : []) + @encounters.map(&:first) + [M.t('Progression', 'Progress')]
        @page = 0
        @scroll = 0
        self.visible = true
        refresh
      end

      def update_inputs
        if Input.repeat?(:RIGHT) || Input.repeat?(:R)
          @page = (@page + 1) % @pages.size
          @scroll = 0
          refresh
          return :move
        elsif Input.repeat?(:LEFT) || Input.repeat?(:L)
          @page = (@page - 1) % @pages.size
          @scroll = 0
          refresh
          return :move
        elsif Input.repeat?(:DOWN) && @scroll < @max_scroll.to_i
          @scroll += 1
          refresh
          return :move
        elsif Input.repeat?(:UP) && @scroll > 0
          @scroll -= 1
          refresh
          return :move
        elsif Input.trigger?(:B) || Input.trigger?(:A)
          return :close
        end
        return nil
      end

      private

      def per_row
        return (@width - 20) / (ICON + 4)
      end

      def refresh
        dispose_dynamic
        @tab.text = "#{@pages[@page]}  (#{@page + 1}/#{@pages.size})"
        @hint.text = M.t('Gauche / droite : changer de page   B : retour', 'Left / right: change page   B: back')
        page = @art ? @page - 1 : @page
        if page < 0
          draw_art
        elsif page < @encounters.size
          draw_species(@encounters[page][1])
        else
          draw_progress
        end
      end

      # Image du lieu en grand (réduite si elle ne tient pas)
      def draw_art
        @max_scroll = 0
        sprite = Sprite.new(viewport).set_bitmap(@art, :interface)
        zoom = [(@width - 20).to_f / sprite.bitmap.width, (@height - 50).to_f / sprite.bitmap.height, 1.0].min
        sprite.zoom = zoom
        sprite.set_position(x + (@width - sprite.bitmap.width * zoom) / 2, y + 26 + (@height - 50 - sprite.bitmap.height * zoom) / 2)
        @dynamic << sprite
      end

      def draw_species(list)
        rows = (list.size + per_row - 1) / per_row
        visible_rows = (@height - 60) / (ICON + 12)
        @max_scroll = [rows - visible_rows, 0].max
        @scroll = @scroll.clamp(0, @max_scroll)
        list.each_with_index do |(sym, form), i|
          row = i / per_row - @scroll
          next if row < 0 || row >= visible_rows

          col = i % per_row
          sx = x + 10 + col * (ICON + 4)
          sy = y + 26 + row * (ICON + 12)
          draw_creature(sym, form, sx, sy)
        end
      end

      def draw_creature(sym, form, sx, sy)
        seen = M.species_seen?(sym)
        caught = M.species_caught?(sym)
        sprite = Sprite::WithColor.new(viewport)
        begin
          creature = data_creature(sym)
          sprite.set_bitmap(PFM::Pokemon.icon_filename(creature.id, form, false, false, false), :b_icon)
          size = sprite.bitmap.height
          sprite.src_rect.set(0, 0, size, size)
          sprite.set_position(sx + (ICON - size) / 2, sy + (ICON - size) / 2)
          sprite.color = [0, 0, 0, 1] unless seen
        rescue StandardError
          sprite.set_bitmap(M.icon_file('unknown'), :interface)
          sprite.set_position(sx + 8, sy + 8)
        end
        @dynamic << sprite
        if caught
          ball = Sprite.new(viewport).set_bitmap(M.icon_file('caught'), :interface)
          ball.set_position(sx + ICON - 8, sy + ICON - 8)
          @dynamic << ball
        end
        name = seen ? (data_creature(sym).name rescue sym.to_s) : '???'
        @dynamic << small_text(sx - 2, sy + ICON, ICON + 4, name.to_s[0, 8], 1)
      end

      def small_text(tx, ty, width, str, align)
        text = Text.new(SMALL, viewport, tx, ty - Text::Util::FOY, width, 13, str, align, nil, WHITE)
        text.draw_shadow = true
        return text
      end

      def draw_progress
        @max_scroll = 0
        lines = []
        species = @encounters.flat_map { |_, list| list.map(&:first) }.uniq
        lines << [M.t('Pokémon vus', 'Pokémon seen'), species.count { |s| M.species_seen?(s) }, species.size] unless species.empty?
        lines << [M.t('Pokémon capturés', 'Pokémon caught'), species.count { |s| M.species_caught?(s) }, species.size] unless species.empty?
        berries = M.berries(@worldmap_id)[@zone_id]
        lines << [M.t('Baies prêtes', 'Ripe berries'), berries.count { |b| b[:stage] >= 4 }, berries.size] unless berries.empty?
        lines += M.progress(@worldmap_id).map { |label, done, total| ["#{M.t('Région', 'Region')} : #{label}", done, total] }
        lines.each_with_index { |line, i| draw_bar(line, y + 30 + i * 24) }
      end

      def draw_bar((label, done, total), by)
        @dynamic << small_text(x + 12, by, @width - 120, label, 0)
        pct = M.percent(done, total)
        @dynamic << small_text(x + @width - 112, by, 100, "#{done}/#{total} (#{pct} %)", 2)
        bg = Sprite.new(viewport).set_bitmap(M.icon_file('progress'), :interface)
        bg.src_rect.set(0, 0, 100, 6)
        bg.set_position(x + 12, by + 13)
        fill = Sprite.new(viewport).set_bitmap(M.icon_file('progress'), :interface)
        fill.src_rect.set(0, 6, pct, 6)
        fill.set_position(x + 12, by + 13)
        bg.zoom_x = fill.zoom_x = (@width - 24) / 100.0
        @dynamic << bg << fill
      end
    end
  end
end
