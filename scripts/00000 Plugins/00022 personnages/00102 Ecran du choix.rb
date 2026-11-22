# Personnages : écran du choix du héros (commande choisir_heros)
#
#   ┌ Choisis ton héros ──────────────── 1 / 3 ┐
#   │                                          │
#   │   ◄          [ image du héros ]       ►  │
#   │                                          │
#   │                  Nom                     │
#   │              description                 │
#   └ ◄► Changer │ A Choisir │ B Retour ────────┘
module GamePlay
  class ChoixHeros < BaseCleanUpdate::FrameBalanced
    WHITE = 10
    DARK = 0
    SMALL_FONT = 20
    # Zone de l'image du héros (centre, bas de l'image)
    IMAGE_X = 160
    IMAGE_BOTTOM = 150
    IMAGE_MAX_H = 118
    IMAGE_MAX_W = 200
    TEXTS = {
      title: ['Choisis ton héros', 'Choose your hero'], change: %w[Changer Change], choose: %w[Choisir Choose], back: %w[Retour Back]
    }.freeze

    # @return [Hash, nil] héros choisi
    attr_reader :chosen

    # @param cancellable [Boolean]
    def initialize(cancellable = false)
      super()
      @cancellable = cancellable
      @heroes = Personnages.heroes
      current = Personnages.current_hero_id
      @index = [@heroes.index { |h| h['id'].to_s == current.to_s } || 0, 0].max
      @frame = 0
      @chosen = nil
    end

    def update_inputs
      if Input.repeat?(:LEFT)
        move(-1)
      elsif Input.repeat?(:RIGHT)
        move(1)
      elsif Input.trigger?(:A)
        play_decision_se
        @chosen = @heroes[@index]
        @running = false
      elsif Input.trigger?(:B)
        return play_buzzer_se unless @cancellable

        play_cancel_se
        @running = false
      end
      return false
    end

    def update_graphics
      @frame += 1
      animate_charset
      # flèches qui bougent un peu
      offset = (@frame / 15).even? ? 0 : 2
      @arrow_left.x = 16 - offset
      @arrow_right.x = 296 + offset
    end

    private

    # @param key [Symbol]
    def text(key)
      return TEXTS[key][$options&.language == 'fr' ? 0 : 1]
    rescue StandardError
      return TEXTS[key].first
    end

    def move(delta)
      return if @heroes.size < 2

      @index = (@index + delta) % @heroes.size
      play_cursor_se
      refresh
    end

    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @stack.add_sprite(0, 0, 'party_pe/background')
      title = @stack.add_text(30, 3, 200, 16, text(:title), color: WHITE)
      title.bold = true
      @counter = @stack.with_font(SMALL_FONT) { @stack.add_text(190, 5, 124, 13, '', 2, color: WHITE) }
      @image = Sprite.new(@viewport)
      @arrow_left = @stack.add_text(16, 80, 12, 16, '◄', 1, color: WHITE)
      @arrow_right = @stack.add_text(296, 80, 12, 16, '►', 1, color: WHITE)
      @name = @stack.add_text(20, IMAGE_BOTTOM + 8, 280, 16, '', 1, color: WHITE)
      @name.bold = true
      @desc = @stack.with_font(SMALL_FONT) { [@stack.add_text(20, IMAGE_BOTTOM + 26, 280, 13, '', 1, color: WHITE), @stack.add_text(20, IMAGE_BOTTOM + 39, 280, 13, '', 1, color: WHITE)] }
      nav = [['◄►', text(:change)], ['A', text(:choose)]]
      nav << ['B', text(:back)] if @cancellable
      @stack.with_font(SMALL_FONT) { @stack.add_text(8, 222, 304, 13, nav.map { |k, l| "#{k} #{l}" }.join('   │   '), 1, color: WHITE) }
      refresh
    end

    def refresh
      hero = @heroes[@index] || {}
      many = @heroes.size > 1
      @arrow_left.visible = @arrow_right.visible = many
      @counter.text = many ? "#{@index + 1} / #{@heroes.size}" : ''
      @name.text = hero['name'].to_s
      lines = wrap(hero['description'].to_s, 46)
      @desc.each_with_index { |t, i| t.text = lines[i] || '' }
      refresh_image(hero)
    end

    # @param str [String]
    # @param width [Integer] caractères par ligne
    # @return [Array<String>]
    def wrap(str, width)
      lines = ['']
      str.split(/\s+/).each do |word|
        if (lines.last + ' ' + word).strip.size > width && !lines.last.empty?
          lines << word
        else
          lines[-1] = (lines.last + ' ' + word).strip
        end
      end
      return lines.first(2)
    end

    # Image de présentation (graphics/battlers) ou personnage de la carte agrandi
    def refresh_image(hero)
      @charset = nil
      picture = hero['picture'].to_s
      if !picture.empty? && RPG::Cache.battler_exist?(picture)
        bmp = RPG::Cache.battler(picture)
        zoom = [IMAGE_MAX_H.to_f / bmp.height, IMAGE_MAX_W.to_f / bmp.width, 2.0].min
        @image.bitmap = bmp
        @image.src_rect.set(0, 0, bmp.width, bmp.height)
        @image.zoom = zoom
        @image.set_origin(bmp.width / 2, bmp.height)
      elsif (file = Personnages.hero_charset_file(hero))
        bmp = RPG::Cache.character(file)
        @charset = bmp
        @image.bitmap = bmp
        @image.zoom = [IMAGE_MAX_H.to_f / (bmp.height / 4), 3.0].min.floor.clamp(1, 3)
        animate_charset
      else
        @image.bitmap = nil
      end
      @image.set_position(IMAGE_X, IMAGE_BOTTOM)
    rescue StandardError => e
      log_error("Personnages : image du héros (#{e.message})") if respond_to?(:log_error, true)
      @image.bitmap = nil
    end

    def animate_charset
      return unless @charset && @image.bitmap.equal?(@charset)

      fw = @charset.width / 4
      fh = @charset.height / 4
      direction = [0, 1, 3, 2][(@frame / 120) % 4]
      @image.src_rect.set((@frame / 10 % 4) * fw, direction * fh, fw, fh)
      @image.set_origin(fw / 2, fh)
    end
  end
end
