# Générateur de personnages : écran où le joueur crée son personnage (commande personnaliser_joueur)
#
#   ┌ Personnalise ton personnage ───────────────────────┐
#   │ Genre        ◄ Garçon ►   │                        │
#   │ Peau         ◄ Claire ►   │      (aperçu animé,     │
#   │ Coiffure     ◄ Coiffure 2 │       tourne sur        │
#   │   Couleur    ◄ ■ Brun ►   │       lui-même)         │
#   │ …                         │                        │
#   │ Au hasard / Terminer      │                        │
#   └ ▲▼ choisir  ◄► changer  A valider ─────────────────┘
module GamePlay
  class GenerateurPersonnage < BaseCleanUpdate::FrameBalanced
    G = ::Generateur
    ROW_X = 10
    ROW_Y = 24
    ROW_H = 14
    VALUE_X = 76
    VALUE_W = 108
    PREVIEW_X = 252
    PREVIEW_Y = 118
    # couleurs de l'écran
    BG = Color.new(30, 30, 40)
    PANEL = Color.new(44, 43, 56)
    CURSOR = Color.new(101, 98, 248, 150)

    # @return [Boolean] le joueur a validé son personnage
    attr_reader :done

    # @param cancellable [Boolean] B quitte sans rien changer
    def initialize(cancellable = false)
      super()
      @cancellable = cancellable
      @done = false
      @spec = G.spec ? Marshal.load(Marshal.dump(G.spec)) : G.random_spec
      @index = 0
      @frame = 0
    end

    def update_inputs
      if Input.repeat?(:UP)
        move(-1)
      elsif Input.repeat?(:DOWN)
        move(1)
      elsif Input.repeat?(:LEFT)
        change(-1)
      elsif Input.repeat?(:RIGHT)
        change(1)
      elsif Input.trigger?(:A)
        action_a
      elsif Input.trigger?(:B)
        action_b
      end
      return false
    end

    def update_graphics
      @frame += 1
      return unless @preview&.bitmap && !@preview.bitmap.disposed?

      fw = @preview.bitmap.width / 4
      fh = @preview.bitmap.height / 4
      direction = [0, 1, 3, 2][(@frame / 120) % 4] # bas, gauche, haut, droite
      @preview.src_rect.set((@frame / 10 % 4) * fw, direction * fh, fw, fh)
      @preview.ox = fw / 2
      @preview.oy = fh
    end

    def dispose
      super
      @owned_textures&.each { |t| t.dispose unless t.disposed? }
    end

    private

    def create_graphics
      super
      @owned_textures = []
      panel(0, 0, filled(320, 240, BG))
      panel(4, 20, filled(186, 202, PANEL))
      panel(194, 20, filled(122, 202, PANEL))
      @cursor = Sprite.new(@viewport)
      @cursor.bitmap = filled(182, ROW_H, CURSOR)
      @preview = Sprite.new(@viewport)
      @preview.set_position(PREVIEW_X, PREVIEW_Y)
      @preview.zoom = 2
      @texts = UI::SpriteStack.new(@viewport)
      @texts.add_text(8, 2, 304, 16, text(:title), 0, color: 10)
      @swatches = []
      @rows = rows.map.with_index do |_row, i|
        y = ROW_Y + i * ROW_H
        swatch = Sprite.new(@viewport)
        swatch.set_position(VALUE_X + 10, y + 3)
        @swatches << swatch
        @texts.with_font(20) do
          [@texts.add_text(ROW_X, y, 70, 13, '', 0, color: 10), @texts.add_text(VALUE_X, y, VALUE_W, 13, '', 1, color: 10)]
        end
      end
      @texts.with_font(20) { @texts.add_text(8, 224, 304, 13, text(@cancellable ? :help_cancel : :help), 1, color: 10) }
      refresh
      refresh_preview
    end

    def panel(x, y, bitmap)
      sprite = Sprite.new(@viewport)
      sprite.set_position(x, y)
      sprite.bitmap = bitmap
      return sprite
    end

    # --- Lignes -------------------------------------------------------------------
    # @return [Array<Array>] [id, libellé, catégorie (pièces)]
    def rows
      [
        [:gender, text(:gender)], [:skin, text(:skin)],
        [:part, text(:hair), 'hair'], [:color, text(:color), 'hair'],
        [:part, text(:top), 'top'], [:color, text(:color), 'top'],
        [:part, text(:bottom), 'bottom'], [:color, text(:color), 'bottom'],
        [:part, text(:hat), 'hat'], [:color, text(:color), 'hat'],
        [:part, text(:bag), 'bag'], [:color, text(:color), 'bag'],
        [:random, text(:random)], [:done, text(:done)]
      ]
    end

    def options
      @options = nil if @options_gender != @spec['gender']
      @options_gender = @spec['gender']
      @options ||= G.options(@spec['gender'])
    end

    # choix d'une ligne : [liste, index courant]
    def choices(row)
      id, _label, cat = row
      case id
      when :gender then [%w[m f], %w[m f].index(@spec['gender']) || 0]
      when :skin then [options['skins'], options['skins'].index(@spec['skin']) || 0]
      when :part
        list = G.keys(options, cat)
        list = [nil] + list if G::OPTIONAL.include?(cat)
        [list, list.index(@spec[cat] && @spec[cat]['key']) || 0]
      when :color
        part = @spec[cat]
        return [[], 0] unless part

        list = (options[cat][part['key']] || []) + G::FREE_COLORS.map { |hex| "tint:#{hex}" }
        current = part['tint'] ? "tint:#{part['tint']}" : part['color']
        [list, list.index(current) || 0]
      else [[], 0]
      end
    end

    def value_text(row)
      id, _label, cat = row
      case id
      when :gender then @spec['gender'] == 'f' ? text(:girl) : text(:boy)
      when :skin then G.skin_label(@spec['skin'])
      when :part
        part = @spec[cat]
        return text(:none) unless part

        cat == 'hair' ? format(text(:style), part['key']) : G.label(part['key'])
      when :color
        part = @spec[cat]
        return '—' unless part

        part['tint'] ? text(:free) : G.color_label(part['color'])
      else ''
      end
    end

    def swatch_hex(row)
      id, _label, cat = row
      return G.skin_hex(@spec['skin']) if id == :skin
      return nil unless id == :color && (part = @spec[cat])

      return part['tint'] || G.color_hex(part['color'])
    end

    def refresh
      rows.each_with_index do |row, i|
        label, value = @rows[i]
        label.text = row[1]
        list, = choices(row)
        arrows = list.size > 1 && %i[gender skin part color].include?(row[0])
        value.text = arrows ? "◄ #{value_text(row)} ►" : value_text(row)
        hex = swatch_hex(row)
        @swatches[i].visible = !hex.nil?
        @swatches[i].bitmap = swatch(hex) if hex
      end
      @cursor.set_position(6, ROW_Y + @index * ROW_H)
    end

    def refresh_preview
      old = @preview.bitmap
      texture = G.compose_texture('walk', @spec)
      @preview.bitmap = texture
      @owned_textures << texture if texture
      if old && old != texture && @owned_textures.include?(old)
        @owned_textures.delete(old)
        old.dispose unless old.disposed?
      end
      update_graphics
    end

    # --- Actions ------------------------------------------------------------------
    def move(delta)
      @index = (@index + delta) % rows.size
      play_cursor_se
      refresh
    end

    def change(delta)
      row = rows[@index]
      list, index = choices(row)
      return play_buzzer_se if list.size <= 1

      value = list[(index + delta) % list.size]
      id, _label, cat = row
      case id
      when :gender
        @spec['gender'] = value
        fix_spec
      when :skin then @spec['skin'] = value
      when :part
        if value.nil?
          @spec[cat] = nil
        else
          colors = options[cat][value] || ['']
          old = @spec[cat]
          @spec[cat] = { 'key' => value, 'color' => old && colors.include?(old['color']) ? old['color'] : colors.first }
          @spec[cat]['tint'] = old['tint'] if old && old['tint']
        end
      when :color
        part = @spec[cat]
        if value.start_with?('tint:')
          part['tint'] = value.sub('tint:', '')
        else
          part.delete('tint')
          part['color'] = value
        end
      end
      play_cursor_se
      refresh
      refresh_preview
    end

    # garde les choix valables après un changement de genre
    def fix_spec
      opts = options
      @spec['skin'] = opts['skins'].first unless opts['skins'].include?(@spec['skin'])
      G::CATS.each do |cat|
        part = @spec[cat]
        next if part.nil? && G::OPTIONAL.include?(cat)

        map = opts[cat] || {}
        if part && map[part['key']]
          part['color'] = map[part['key']].first unless map[part['key']].include?(part['color'])
        elsif G::OPTIONAL.include?(cat) || map.empty?
          @spec[cat] = nil
        else
          key = G.keys(opts, cat).first
          @spec[cat] = { 'key' => key, 'color' => map[key].first }
        end
      end
    end

    def action_a
      case rows[@index][0]
      when :random
        @spec = G.random_spec(@spec['gender'])
        play_decision_se
        refresh
        refresh_preview
      when :done
        play_decision_se
        G.apply(@spec)
        @done = true
        @running = false
      else
        change(1)
      end
    end

    def action_b
      return play_buzzer_se unless @cancellable

      play_cancel_se
      @running = false
    end

    # --- Images -------------------------------------------------------------------
    def filled(width, height, color)
      img = Image.new(width, height)
      img.fill_rect(0, 0, width, height, color)
      texture = Texture.new(width, height)
      img.copy_to_bitmap(texture)
      img.dispose
      @owned_textures << texture
      return texture
    end

    def swatch(hex)
      @swatch_cache ||= {}
      return @swatch_cache[hex] if @swatch_cache[hex]

      value = hex.to_s.delete('#')
      color = value.match?(/\A\h{6}\z/) ? Color.new(value[0, 2].hex, value[2, 2].hex, value[4, 2].hex) : Color.new(128, 128, 128)
      img = Image.new(8, 8)
      img.fill_rect(0, 0, 8, 8, Color.new(20, 20, 26))
      img.fill_rect(1, 1, 6, 6, color)
      texture = Texture.new(8, 8)
      img.copy_to_bitmap(texture)
      img.dispose
      @owned_textures << texture
      return @swatch_cache[hex] = texture
    end

    TEXTS = {
      title: ['Personnalise ton personnage', 'Customize your character'],
      gender: %w[Genre Gender], skin: %w[Peau Skin], hair: %w[Coiffure Hair], color: ['  Couleur', '  Color'],
      top: %w[Haut Top], bottom: %w[Bas Bottom], hat: %w[Chapeau Hat], bag: %w[Sac Bag],
      random: ['Au hasard', 'Random'], done: %w[Terminer Done], boy: %w[Garçon Boy], girl: %w[Fille Girl],
      none: %w[Aucun None], style: ['Coiffure %s', 'Style %s'], free: ['Couleur libre', 'Custom color'],
      help: ['▲▼ : choisir   ◄► : changer   A : valider', '▲▼: select   ◄►: change   A: confirm'],
      help_cancel: ['▲▼ : choisir   ◄► : changer   A : valider   B : annuler', '▲▼: select   ◄►: change   A: confirm   B: cancel']
    }.freeze

    def text(key)
      fr, en = TEXTS[key]
      return $options && $options.language.to_s != 'fr' ? en : fr
    rescue StandardError
      return fr
    end
  end
end
