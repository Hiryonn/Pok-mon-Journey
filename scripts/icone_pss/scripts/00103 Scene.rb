# Icône PSS : écran où le joueur crée sa photo de profil du mode en ligne (commande creer_icone_pss)
# Même interface que le générateur de personnages (graphismes PE : party_pe, summary_pe, bag_pe), mais indépendant de lui :
#
#   ┌ Icône de profil ───────────────────────── Série A ┐
#   │ [Série     ]   ┌────────┐  Visage                  │
#   │ [Visage    ]◄  │ aperçu │  Peau 1                  │
#   │ [Haut      ]   └────────┘  Yeux 3                  │
#   │ [Coiffure  ]    ┌ carte Peau  ◄ Peau 1 ►  ┐        │
#   │ [Détails   ]    └ carte Yeux  ◄ Yeux 3 ►  ┘        │
#   │ [Chapeau   ]                                       │
#   │ [Accessoire]                                       │
#   │ [Terminer  ]                                       │
#   └ A Autre carte │ X Hasard │ Y Terminer │ B Annuler ─┘
#   ▲▼ catégorie, ◄► change le choix de la carte (au bord jaune), A passe d'une carte à l'autre
module GamePlay
  class IconePssCreation < BaseCleanUpdate::FrameBalanced
    P = ::IconePss
    WHITE = 10
    DARK = 0
    SMALL_FONT = 20
    # Bandes des catégories (planches summary_pe/move_slot_N)
    BAND_X = 2
    BAND_SELECTED_X = 8
    BAND_Y = 27
    BAND_STEP = 23
    # Aperçu (case du sac agrandie) : l'icône de 40x40 est affichée en 80x80
    TILE_X = 116
    TILE_Y = 28
    ICON_ZOOM = 2
    ICON_SIZE = 36
    # Cartes (party_pe/card)
    CARD_X = 154
    CARD_Y = [110, 162].freeze
    CARD_H = 52
    NAV_Y = 214
    # Catégories : [id, texte, planche de la bande, réglages des cartes]
    ROWS = [
      [:serie, :serie, 1, %w[serie]],
      [:face, :face, 5, %w[peau yeux]],
      [:top, :top, 3, %w[haut]],
      [:hair, :hair, 15, %w[coiffure couleur_cheveux]],
      [:details, :details, 12, %w[sourcils frange]],
      [:hat, :hat, 9, %w[chapeau]],
      [:accessory, :accessory, 4, %w[accessoire]],
      [:done, :done, 22, []]
    ].freeze

    # @return [Boolean] le joueur a validé son icône
    attr_reader :done

    # @param cancellable [Boolean] B quitte sans rien changer
    def initialize(cancellable = false)
      super()
      @cancellable = cancellable
      @done = false
      @spec = P.spec ? Marshal.load(Marshal.dump(P.spec)) : P.random_spec
      @index = 0
      @field = 0
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
      return nil
    end

    def dispose
      super
      @owned_textures&.each { |t| t.dispose unless t.disposed? }
    end

    private

    def current_row
      ROWS[@index]
    end

    # @return [Hash] série de l'icône en cours
    def serie
      P.serie_of(@spec['serie'])
    end

    # --- Création -----------------------------------------------------------------
    def create_graphics
      super
      @owned_textures = []
      @stack = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @stack.add_sprite(0, 0, 'party_pe/background')
      title = @stack.add_text(30, 3, 140, 16, text(:title), color: WHITE)
      title.bold = true
      @serie_text = @stack.with_font(SMALL_FONT) { @stack.add_text(190, 5, 124, 13, '', 2, color: WHITE) }
      create_bands
      create_preview
      create_cards
      create_nav
      refresh
      refresh_preview
    end

    def create_bands
      @bands = ROWS.map.with_index do |row, i|
        y = BAND_Y + i * BAND_STEP
        band = @stack.add_sprite(BAND_X, y, "summary_pe/move_slot_#{row[2]}")
        label = @stack.add_text(BAND_X + 12, y + 5, 84, 16, text(row[1]), color: DARK)
        [band, label]
      end
    end

    def create_preview
      tile = @stack.add_sprite(TILE_X, TILE_Y, 'bag_pe/tile')
      tile.zoom = 2
      @preview = Sprite.new(@viewport)
      @preview.zoom = ICON_ZOOM
      @preview.ox = @preview.oy = P::SIZE / 2
      @preview.set_position(TILE_X + 40, TILE_Y + 40)
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
        card[:left] = @stack.add_sprite(CARD_X + 44, y + 18, UI::SpriteStack::NO_INITIAL_IMAGE, :LEFT, type: UI::KeyShortcut)
        card[:right] = @stack.add_sprite(CARD_X + 131, y + 18, UI::SpriteStack::NO_INITIAL_IMAGE, :RIGHT, type: UI::KeyShortcut)
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
        @stack.add_sprite(i * 80 + 8, NAV_Y + 5, UI::SpriteStack::NO_INITIAL_IMAGE, key, type: UI::KeyShortcut)
        @stack.add_text(i * 80 + 24, NAV_Y + 5, 52, 16, label, color: WHITE)
      end
    end

    # --- Choix --------------------------------------------------------------------
    # @return [String, nil] réglage de la carte (nil : pas de carte)
    def key_of(field)
      return current_row[3][field]
    end

    # [liste, index courant] d'une carte ; la valeur -1 est « aucun »
    def choices(field)
      key = key_of(field)
      return [[], 0] unless key

      s = serie
      list =
        case key
        when 'serie' then (P.catalog['series'] || []).map { |x| x['id'] }
        when 'peau' then (0...s['peau'].size).to_a
        when 'yeux' then (0...s['yeux'].size).to_a
        when 'haut' then (0...s['hauts'].size).to_a
        when 'sourcils' then [-1] + (0...s['sourcils'].size).to_a
        when 'coiffure' then (0...s['cheveux'].size).to_a
        when 'couleur_cheveux' then (0...s['cheveux'][@spec['coiffure']]['couleurs'].size).to_a
        when 'frange' then s['frange'].empty? ? [] : [-1] + (0...s['frange'].size).to_a
        when 'accessoire' then [-1] + (0...P.accessories(s).size).to_a
        when 'chapeau' then (0...s['chapeaux'].size).to_a
        else []
        end
      return [list, list.index(@spec[key]) || 0]
    end

    def value_text(field)
      key = key_of(field)
      return '—' unless key

      value = @spec[key]
      s = serie
      case key
      when 'serie' then return s['label']
      when 'peau' then return format(text(:skin), value + 1)
      when 'yeux' then return format(text(:eyes), value + 1)
      when 'sourcils' then return value < 0 ? text(:like_hair) : P.hair_label(value)
      when 'haut' then return P.top_label(value)
      when 'coiffure' then return format(text(:style), value + 1)
      when 'couleur_cheveux' then return P.hair_label(value)
      when 'frange' then return s['frange'].empty? ? '—' : (value < 0 ? text(:none) : P.hair_label(value))
      when 'accessoire' then return value < 0 ? text(:none) : "#{P.accessories(s)[value]['label']} #{value + 1}"
      when 'chapeau' then return format(text(:hat_n), value + 1)
      end
      return '—'
    end

    # @return [String, nil] "#rrggbb" de la pastille d'une carte de couleur
    def hex_of(field)
      key = key_of(field)
      value = @spec[key]
      case key
      when 'sourcils' then return P.hair_hex(value < 0 ? @spec['couleur_cheveux'] : value)
      when 'haut' then return P.top_hex(serie, value)
      when 'couleur_cheveux' then return P.hair_hex(value)
      when 'frange' then return value < 0 ? nil : P.hair_hex(value)
      end
      return nil
    end

    # --- Affichage ----------------------------------------------------------------
    def refresh
      @bands.each_with_index do |(band, label), i|
        band.x = i == @index ? BAND_SELECTED_X : BAND_X
        label.x = band.x + 12
      end
      @serie_text.text = serie['label']
      id = current_row[0]
      done = id == :done
      @cards.each_with_index { |card, field| refresh_card(card, field, done) }
      @done_text.visible = done
      @info_title.text = text(current_row[1])
      @info_lines[0].text = done ? serie['label'] : value_text(0)
      @info_lines[1].text = done ? '' : (key_of(1) ? value_text(1) : '')
      @nav[0].text = done ? text(:validate) : (key_of(1) ? text(:other_card) : '')
    end

    def refresh_card(card, field, hidden)
      hidden ||= key_of(field).nil?
      card.each_value { |sprite| sprite.visible = !hidden }
      return if hidden

      list, index = choices(field)
      card[:bg].src_rect.y = field == @field ? CARD_H : 0
      card[:label].text = text(:"card_#{key_of(field)}")
      card[:value].text = value_text(field)
      card[:count].text = list.size > 1 ? "#{index + 1}/#{list.size}" : ''
      card[:left].visible = card[:right].visible = list.size > 1
      set_icon(card[:icon], field)
    end

    # pastille de couleur (cartes de couleur seulement)
    def set_icon(sprite, field)
      hex = hex_of(field)
      sprite.visible = !hex.nil?
      return unless hex

      sprite.bitmap = swatch(hex)
      sprite.src_rect.set(0, 0, 14, 14)
      sprite.ox = sprite.oy = 7
      sprite.zoom = 1
    end

    def refresh_preview
      old = @preview.bitmap
      texture = P.compose_texture(@spec)
      @preview.bitmap = texture
      @owned_textures << texture if texture
      if old && old != texture && @owned_textures.include?(old)
        @owned_textures.delete(old)
        old.dispose unless old.disposed?
      end
      refresh
    end

    # --- Actions ------------------------------------------------------------------
    def move(delta)
      @index = (@index + delta) % ROWS.size
      @field = 0
      play_cursor_se
      refresh
    end

    def change(delta)
      list, index = choices(@field)
      return play_buzzer_se if list.size <= 1

      @spec[key_of(@field)] = list[(index + delta) % list.size]
      P.fix_spec(@spec)
      play_cursor_se
      refresh_preview
    end

    def action_a
      return finish if current_row[0] == :done
      return play_buzzer_se unless key_of(1)

      @field = 1 - @field
      play_cursor_se
      refresh
    end

    def randomize
      @spec = P.random_spec(@spec['serie'], @spec, {})
      play_decision_se
      refresh_preview
    end

    def finish
      play_decision_se
      P.apply(@spec)
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
      title: ['Icône de profil', 'Profile icon'],
      serie: %w[Série Series], face: %w[Visage Face], top: %w[Haut Top], hair: %w[Coiffure Hair], details: %w[Détails Details],
      accessory: %w[Accessoire Accessory], hat: %w[Chapeau Hat], done: %w[Terminer Done],
      card_serie: %w[Série Series], card_peau: %w[Peau Skin], card_yeux: %w[Yeux Eyes], card_haut: %w[Couleur Color],
      card_sourcils: %w[Sourcils Eyebrows], card_coiffure: %w[Modèle Style], card_couleur_cheveux: %w[Couleur Color],
      card_frange: %w[Frange Bangs],
      card_accessoire: %w[Modèle Style], card_chapeau: %w[Modèle Style],
      skin: ['Peau %d', 'Skin %d'], eyes: ['Yeux %d', 'Eyes %d'], style: ['Coiffure %d', 'Style %d'], hat_n: ['Chapeau %d', 'Hat %d'],
      none: %w[Aucun None], like_hair: ['Comme cheveux', 'Like hair'], random: %w[Hasard Random], cancel: %w[Annuler Cancel], validate: %w[Valider Confirm],
      other_card: ['Autre carte', 'Other card'], confirm: ['Garder cette icône ?', 'Keep this icon?']
    }.freeze

    def text(key)
      fr, en = TEXTS[key]
      return $options && $options.language.to_s != 'fr' ? en : fr
    rescue StandardError
      return fr
    end
  end
end
