# Générateur de personnages : écran où le joueur crée son personnage (commande personnaliser_joueur)
# Graphismes de l'interface PE (graphics/interface/party_pe, summary_pe, bag_pe) :
#
#   ┌ Personnage ─────────────────────────────── Garçon ┐
#   │ [Corps    ]   ┌────────┐  Coiffure                 │
#   │ [Coiffure ]◄  │ aperçu │  Modèle 2 / 12            │
#   │ [Haut     ]   └────────┘  Brun                     │
#   │ [Bas      ]    ┌ carte Modèle  ◄ Coiffure 2 ► ┐    │
#   │ [Chapeau  ]    └ carte Couleur ◄ Brun ►       ┘    │
#   │ [Sac      ]                                        │
#   │ [Terminer ]                                        │
#   └ A Couleur │ X Hasard │ Y Terminer │ B Annuler ─────┘
#   ▲▼ catégorie, ◄► change le modèle ou la couleur (carte au bord jaune), A passe de l'un à l'autre
module GamePlay
  class GenerateurPersonnage < BaseCleanUpdate::FrameBalanced
    G = ::Generateur
    WHITE = 10
    DARK = 0
    SMALL_FONT = 20
    # Bandes des catégories (planches summary_pe/move_slot_N)
    BAND_X = 2
    BAND_SELECTED_X = 8
    BAND_Y = 27
    BAND_STEP = 26
    # Aperçu (case du sac agrandie)
    TILE_X = 116
    TILE_Y = 28
    # Cartes Modèle / Couleur (party_pe/card)
    CARD_X = 154
    CARD_Y = [110, 162].freeze
    CARD_H = 52
    NAV_Y = 214

    # @return [Boolean] le joueur a validé son personnage
    attr_reader :done

    # @param cancellable [Boolean] B quitte sans rien changer
    def initialize(cancellable = false)
      super()
      @cancellable = cancellable
      @done = false
      @spec = G.spec ? Marshal.load(Marshal.dump(G.spec)) : G.random_spec
      @index = 0
      @field = 0
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
      elsif Input.trigger?(:X)
        randomize
      elsif Input.trigger?(:Y)
        finish
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

    # --- Lignes -------------------------------------------------------------------
    # [id, libellé, catégorie, planche de la bande]
    def rows
      @rows_list ||= [
        [:body, text(:body), nil, 1], [:part, text(:hair), 'hair', 5], [:part, text(:top), 'top', 3],
        [:part, text(:bottom), 'bottom', 15], [:part, text(:hat), 'hat', 12], [:part, text(:bag), 'bag', 4],
        [:done, text(:done), nil, 22]
      ]
    end

    def current_row
      rows[@index]
    end

    # --- Création -----------------------------------------------------------------
    def create_graphics
      super
      @owned_textures = []
      @stack = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @stack.add_sprite(0, 0, 'party_pe/background')
      title = @stack.add_text(30, 3, 140, 16, text(:title), color: WHITE)
      title.bold = true
      @gender_text = @stack.with_font(SMALL_FONT) { @stack.add_text(190, 5, 124, 13, '', 2, color: WHITE) }
      create_bands
      create_preview
      create_cards
      create_nav
      refresh
      refresh_preview
    end

    def create_bands
      @bands = rows.map.with_index do |row, i|
        y = BAND_Y + i * BAND_STEP
        band = @stack.add_sprite(BAND_X, y, "summary_pe/move_slot_#{row[3]}")
        label = @stack.add_text(BAND_X + 12, y + 5, 84, 16, row[1], color: DARK)
        [band, label]
      end
    end

    def create_preview
      tile = @stack.add_sprite(TILE_X, TILE_Y, 'bag_pe/tile')
      tile.zoom = 2
      @preview = Sprite.new(@viewport)
      @preview.zoom = 2
      @preview.set_position(TILE_X + 40, TILE_Y + 72)
      @info_title = @stack.add_text(TILE_X + 88, TILE_Y + 4, 112, 16, '', color: DARK)
      @info_lines = @stack.with_font(SMALL_FONT) do
        [@stack.add_text(TILE_X + 88, TILE_Y + 24, 112, 13, '', color: DARK),
         @stack.add_text(TILE_X + 88, TILE_Y + 38, 112, 13, '', color: DARK)]
      end
    end

    def create_cards
      @cards = CARD_Y.map do |y|
        card = { bg: @stack.add_sprite(CARD_X, y, 'party_pe/card') }
        card[:bg].src_rect.height = CARD_H
        card[:icon] = Sprite.new(@viewport)
        card[:icon].set_position(CARD_X + 22, y + 26)
        card[:label] = @stack.add_text(CARD_X + 46, y + 2, 98, 16, '', color: WHITE)
        card[:left] = @stack.add_sprite(CARD_X + 44, y + 18, NO_INITIAL_IMAGE, :LEFT, type: UI::KeyShortcut)
        card[:right] = @stack.add_sprite(CARD_X + 131, y + 18, NO_INITIAL_IMAGE, :RIGHT, type: UI::KeyShortcut)
        card[:value] = @stack.add_text(CARD_X + 60, y + 18, 71, 16, '', 1, color: WHITE)
        card[:count] = @stack.with_font(SMALL_FONT) { @stack.add_text(CARD_X + 46, y + 31, 54, 13, '', 1, color: WHITE) }
        card
      end
      @done_text = @stack.add_text(CARD_X, CARD_Y[0] + 30, 151, 16, text(:confirm), 1, color: DARK)
    end

    def create_nav
      keys = [[:A, ''], [:X, text(:random)], [:Y, text(:done)], [:B, text(:cancel)]]
      @nav = keys.map.with_index do |(key, label), i|
        next nil if key == :B && !@cancellable

        bg = @stack.add_sprite(i * 80, NAV_Y, 'party_pe/nav_button')
        bg.src_rect.set(0, 0, 80, 23)
        @stack.add_sprite(i * 80 + 8, NAV_Y + 5, NO_INITIAL_IMAGE, key, type: UI::KeyShortcut)
        @stack.add_text(i * 80 + 24, NAV_Y + 5, 52, 16, label, color: WHITE)
      end
    end

    # --- Choix --------------------------------------------------------------------
    def options
      @options = nil if @options_gender != @spec['gender']
      @options_gender = @spec['gender']
      @options ||= G.options(@spec['gender'])
    end

    # [liste, index courant] d'une carte (0 : modèle / genre, 1 : couleur / peau)
    def choices(field)
      id, _label, cat = current_row
      case id
      when :body
        return [%w[m f], %w[m f].index(@spec['gender']) || 0] if field == 0

        [options['skins'], options['skins'].index(@spec['skin']) || 0]
      when :part
        if field == 0
          list = G.keys(options, cat)
          list = [nil] + list if G::OPTIONAL.include?(cat)
          return [list, list.index(@spec[cat] && @spec[cat]['key']) || 0]
        end
        part = @spec[cat]
        return [[], 0] unless part

        list = options[cat][part['key']] || []
        [list, list.index(part['color']) || 0]
      else [[], 0]
      end
    end

    def value_text(field)
      id, _label, cat = current_row
      if id == :body
        return field == 0 ? gender_text : G.skin_label(@spec['skin'])
      end

      part = @spec[cat]
      return field == 0 ? text(:none) : '—' unless part
      return G.color_label(part['color']) if field == 1

      cat == 'hair' ? format(text(:style), part['key']) : G.label(part['key'])
    end

    def gender_text
      @spec['gender'] == 'f' ? text(:girl) : text(:boy)
    end

    # --- Affichage ----------------------------------------------------------------
    def refresh
      @bands.each_with_index do |(band, label), i|
        band.x = i == @index ? BAND_SELECTED_X : BAND_X
        label.x = band.x + 12
      end
      @gender_text.text = gender_text
      id, label, = current_row
      done = id == :done
      @cards.each_with_index { |card, field| refresh_card(card, field, done) }
      @done_text.visible = done
      @info_title.text = label
      if done
        @info_lines[0].text = gender_text
        @info_lines[1].text = G.skin_label(@spec['skin'])
      else
        @info_lines[0].text = value_text(0)
        @info_lines[1].text = value_text(1)
      end
      @nav[0].text = done ? text(:validate) : (@field == 0 ? text(:color) : text(:model))
    end

    def refresh_card(card, field, hidden)
      card.each_value { |sprite| sprite.visible = !hidden }
      return if hidden

      list, index = choices(field)
      card[:bg].src_rect.y = field == @field ? CARD_H : 0
      card[:label].text = current_row[0] == :body ? text(field == 0 ? :gender : :skin) : text(field == 0 ? :model : :color)
      card[:value].text = value_text(field)
      card[:count].text = list.size > 1 ? "#{index + 1}/#{list.size}" : ''
      card[:left].visible = card[:right].visible = list.size > 1
      set_icon(card[:icon], field)
    end

    # hexagone : la pièce seule (modèle) ou la couleur
    def set_icon(sprite, field)
      id, _label, cat = current_row
      if field == 1
        hex = id == :body ? G.skin_hex(@spec['skin']) : (@spec[cat] && G.color_hex(@spec[cat]['color']))
        sprite.bitmap = swatch(hex)
        sprite.src_rect.set(0, 0, 14, 14)
        sprite.ox = sprite.oy = 7
        sprite.visible = !hex.nil?
        return
      end
      texture = id == :body ? @preview.bitmap : part_texture(cat)
      sprite.visible = !texture.nil?
      return unless texture

      sprite.bitmap = texture
      fw = texture.width / 4
      fh = texture.height / 4
      sprite.src_rect.set(0, 0, fw, fh)
      sprite.ox = fw / 2
      sprite.oy = fh / 2 + 2
    end

    # @return [Texture, nil] image de la marche d'une pièce seule
    def part_texture(cat)
      choice = @spec[cat]
      return nil unless choice

      entry = G.resolve('walk', cat, @spec['gender'], choice)
      return nil unless entry

      @part_cache ||= {}
      return @part_cache[entry['file']] if @part_cache.key?(entry['file'])

      path = "#{G::PARTS_DIR}/#{entry['file']}.png"
      return @part_cache[entry['file']] = nil unless File.exist?(path)

      img = Image.new(path)
      texture = Texture.new(img.width, img.height)
      img.copy_to_bitmap(texture)
      img.dispose
      @owned_textures << texture
      return @part_cache[entry['file']] = texture
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
      refresh
    end

    # --- Actions ------------------------------------------------------------------
    def move(delta)
      @index = (@index + delta) % rows.size
      @field = 0
      play_cursor_se
      refresh
    end

    def change(delta)
      list, index = choices(@field)
      return play_buzzer_se if list.size <= 1

      value = list[(index + delta) % list.size]
      id, _label, cat = current_row
      if id == :body
        if @field == 0
          @spec['gender'] = value
          fix_spec
        else
          @spec['skin'] = value
        end
      elsif @field == 0
        if value.nil?
          @spec[cat] = nil
        else
          colors = options[cat][value] || ['']
          old = @spec[cat]
          @spec[cat] = { 'key' => value, 'color' => old && colors.include?(old['color']) ? old['color'] : colors.first }
        end
      else
        @spec[cat]['color'] = value
      end
      play_cursor_se
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
      return finish if current_row[0] == :done

      @field = 1 - @field
      play_cursor_se
      refresh
    end

    def randomize
      @spec = G.random_spec(@spec['gender'])
      play_decision_se
      refresh_preview
    end

    def finish
      play_decision_se
      G.apply(@spec)
      @done = true
      @running = false
    end

    def action_b
      return play_buzzer_se unless @cancellable

      play_cancel_se
      @running = false
    end

    # --- Images -------------------------------------------------------------------
    def swatch(hex)
      @swatch_cache ||= {}
      return @swatch_cache[hex] if @swatch_cache[hex]

      value = hex.to_s.delete('#')
      color = value.match?(/\A\h{6}\z/) ? Color.new(value[0, 2].hex, value[2, 2].hex, value[4, 2].hex) : Color.new(128, 128, 128)
      img = Image.new(14, 14)
      img.fill_rect(0, 0, 14, 14, Color.new(57, 59, 67))
      img.fill_rect(1, 1, 12, 12, color)
      texture = Texture.new(14, 14)
      img.copy_to_bitmap(texture)
      img.dispose
      @owned_textures << texture
      return @swatch_cache[hex] = texture
    end

    TEXTS = {
      title: %w[Personnage Character],
      body: %w[Corps Body], hair: %w[Coiffure Hair], top: %w[Haut Top], bottom: %w[Bas Bottom],
      hat: %w[Chapeau Hat], bag: %w[Sac Bag], done: %w[Terminer Done],
      gender: %w[Genre Gender], skin: %w[Peau Skin], model: %w[Modèle Style], color: %w[Couleur Color],
      random: %w[Hasard Random], cancel: %w[Annuler Cancel], validate: %w[Valider Confirm],
      confirm: ['Garder ce personnage ?', 'Keep this character?'],
      boy: %w[Garçon Boy], girl: %w[Fille Girl], none: %w[Aucun None], style: ['Coiffure %s', 'Style %s']
    }.freeze

    def text(key)
      fr, en = TEXTS[key]
      return $options && $options.language.to_s != 'fr' ? en : fr
    rescue StandardError
      return fr
    end
  end
end
