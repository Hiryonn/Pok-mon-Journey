# Poffin : la boîte à poffins (commande nourrir_poffin)
#   Boîte   : haut / bas choisit un poffin (liste à gauche, saveurs à droite), A le donne à un Pokémon,
#             X change le tri (ordre de cuisson, niveau, douceur, nom), B quitte
#   Donner  : haut / bas / gauche / droite change de Pokémon ; le pentagone montre ses conditions et, en plus clair, ce que le poffin
#             lui apporterait ; A donne le poffin, B revient à la boîte
# Le poffin mangé disparaît de la boîte. Un Pokémon qui a déjà tout le lustre (255), ou aucune condition à gagner, n'en veut plus.
module GamePlay
  class PoffinBox < BaseCleanUpdate::FrameBalanced
    P = ::Poffin
    DARK = 0
    WHITE = 9
    SMALL_FONT = 20
    SX = P::SCREEN_X
    SY = P::SCREEN_Y
    # Boîte (dans l'écran de 256x192) : liste, saveurs
    LIST_X = 18
    LIST_Y = 36
    ROW_H = 18
    ROWS = 5
    LIST_TEXT_W = 94
    DETAIL_X = 154
    # Anneau de chaque saveur (épicé, sec, doux, amer, acide) : rouge, bleu clair, rose, jaune, vert
    FLAVOR_RINGS = [1, 2, 4, 5, 3].freeze
    # Pentagone (dans l'écran) : centre et rayon de la planche, rayon à zéro
    CENTER = [128, 113].freeze
    RADIUS = 68
    MIN_RADIUS = 4
    PENTAGON_COLOR = [240, 120, 224].freeze
    PREVIEW_COLOR = [255, 200, 255].freeze
    # Boutons des conditions (haut, droite, bas à droite, bas à gauche, gauche) : couleur et position
    LABELS = [['rouge', 96, 18], ['bleu', 192, 78], ['rose', 192, 150], ['jaune', 0, 150], ['vert', 0, 78]].freeze
    # Tris
    SORTS = %i[date level smooth name].freeze

    # @return [Boolean] au moins un poffin a été mangé
    attr_reader :fed

    def initialize
      super()
      @state = :box
      @index = 0
      @offset = 0
      @sort = 0
      @pokemon_index = 0
      @fed = false
      @message = nil
      @blink = 0
      @view = sorted
    end

    def update_inputs
      @state == :box ? update_box : update_give
      return false
    end

    def update_graphics
      @blink = (@blink + 1) % 40
      refresh_buttons if @state == :give
      return nil
    end

    private

    # @return [Array<Hash>] les poffins, dans l'ordre du tri
    def sorted
      list = P.inventory.each_with_index.to_a
      case SORTS[@sort]
      when :level then list.sort_by! { |p, i| [-p['level'].to_i, -p['smoothness'].to_i, i] }
      when :smooth then list.sort_by! { |p, i| [-p['smoothness'].to_i, -p['level'].to_i, i] }
      when :name then list.sort_by! { |p, i| [P.short_name(p), i] }
      end
      return list.map(&:first)
    end

    # @return [Array<PFM::Pokemon>]
    def party
      return ($actors || ($pokemon_party && $pokemon_party.actors) || []).to_a
    end

    # --- Boîte ---------------------------------------------------------------------------
    def update_box
      if Input.repeat?(:UP)
        move(-1)
      elsif Input.repeat?(:DOWN)
        move(1)
      elsif Input.trigger?(:A)
        start_give
      elsif Input.trigger?(:X)
        @sort = (@sort + 1) % SORTS.size
        @view = sorted
        @index = 0
        @offset = 0
        @message = text(:sorted) + text(SORTS[@sort])
        play_cursor_se
        refresh_box
      elsif Input.trigger?(:B)
        play_cancel_se
        @running = false
      end
    end

    def move(delta)
      return play_buzzer_se if @view.empty?

      @index = (@index + delta) % @view.size
      @offset = @index if @index < @offset
      @offset = @index - ROWS + 1 if @index >= @offset + ROWS
      @offset = 0 if @view.size <= ROWS
      @message = nil
      play_cursor_se
      refresh_box
    end

    def start_give
      return play_buzzer_se if @view.empty?
      return play_buzzer_se if party.empty?

      @state = :give
      @pokemon_index = 0
      @message = nil
      play_decision_se
      show_screen(:give)
      refresh_give
    end

    # --- Donner ----------------------------------------------------------------------------
    def update_give
      if Input.repeat?(:LEFT) || Input.repeat?(:UP)
        change_pokemon(-1)
      elsif Input.repeat?(:RIGHT) || Input.repeat?(:DOWN)
        change_pokemon(1)
      elsif Input.trigger?(:A)
        feed
      elsif Input.trigger?(:B)
        play_cancel_se
        @state = :box
        show_screen(:box)
        refresh_box
      end
    end

    def change_pokemon(delta)
      return if party.size <= 1

      @pokemon_index = (@pokemon_index + delta) % party.size
      @message = nil
      play_cursor_se
      refresh_give
    end

    def feed
      pokemon = party[@pokemon_index]
      poffin = @view[@index]
      result = pokemon && poffin && P.feed(pokemon, poffin)
      unless result
        @message = text(:refuse)
        play_buzzer_se
        return refresh_give
      end
      real = P.inventory.index { |item| item.equal?(poffin) }
      P.inventory.delete_at(real) if real
      @fed = true
      @view = sorted
      @index = @index.clamp(0, [@view.size - 1, 0].max)
      @offset = 0
      @message = "#{pokemon.given_name} : #{gains_text(result)}"
      play_decision_se
      @state = :box
      show_screen(:box)
      refresh_box
    end

    # @param result [Hash] { gains:, sheen: }
    # @return [String] ex. « +5 Épicé  +2 Lustre »
    def gains_text(result)
      parts = result[:gains].each_with_index.reject { |gain, _| gain <= 0 }.map { |gain, i| "+#{gain} #{P.flavor_name(P::FLAVORS[i])}" }
      parts << "+#{result[:sheen]} #{text(:sheen)}" if result[:sheen] > 0
      return parts.join('  ')
    end

    # --- Création ----------------------------------------------------------------------------
    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @stack.add_sprite(0, 0, 'poffin/fond')
      @screens = {box: @stack.add_sprite(SX, SY, 'poffin/boite_fond'), give: @stack.add_sprite(SX, SY, 'poffin/conditions_fond')}
      create_box_sprites
      create_give_sprites
      @hint = @stack.with_font(SMALL_FONT) { @stack.add_text(0, 220, 320, 14, '', 1, color: DARK) }
      show_screen(:box)
      refresh_box
    end

    def create_box_sprites
      @selection = @stack.add_sprite(SX + LIST_X - 4, SY + LIST_Y, 'poffin/texte_long')
      @row_icons = Array.new(ROWS) { |i| @stack.add_sprite(SX + LIST_X + 2, SY + LIST_Y + i * ROW_H + 1, 'poffin/mini_1') }
      @row_texts = Array.new(ROWS) do |i|
        @stack.with_font(SMALL_FONT) { @stack.add_text(SX + LIST_X + 20, SY + LIST_Y + i * ROW_H + 2, LIST_TEXT_W, 14, '', color: DARK) }
      end
      @rings = P::FLAVORS.each_index.map do |i|
        @stack.add_sprite(SX + DETAIL_X + 3, SY + LIST_Y + i * ROW_H + 2, "poffin/anneau_#{FLAVOR_RINGS[i]}")
      end
      @values = P::FLAVORS.each_index.map do |i|
        @stack.with_font(SMALL_FONT) { @stack.add_text(SX + DETAIL_X + 16, SY + LIST_Y + i * ROW_H + 3, 20, 14, '', 2, color: DARK) }
      end
      @up = @stack.add_sprite(SX + 118, SY + 22, 'poffin/haut_1')
      @down = @stack.add_sprite(SX + 118, SY + 128, 'poffin/bas_1')
      @title = @stack.with_font(SMALL_FONT) { @stack.add_text(SX, SY + 3, 256, 14, '', 1, color: DARK) }
      @oval = @stack.with_font(SMALL_FONT) { @stack.add_text(SX + 76, SY + 162, 104, 14, '', 1, color: DARK) }
      @box_group = [@selection, @up, @down, @title, @oval] + @row_icons + @row_texts + @rings + @values
    end

    def create_give_sprites
      @preview_shape = Shape.new(@viewport, :convex, 5)
      @preview_shape.color = Color.new(*PREVIEW_COLOR)
      @shape = Shape.new(@viewport, :convex, 5)
      @shape.color = Color.new(*PENTAGON_COLOR)
      @buttons = LABELS.map { |color, x, y| @stack.add_sprite(SX + x, SY + y, "poffin/bouton_#{color}_4") }
      @label_names = LABELS.map { |_, x, y| @stack.with_font(SMALL_FONT) { @stack.add_text(SX + x, SY + y + 3, 64, 14, '', 1, color: DARK) } }
      @label_values = LABELS.map { |_, x, y| @stack.with_font(SMALL_FONT) { @stack.add_text(SX + x, SY + y + 15, 64, 14, '', 1, color: DARK) } }
      @name = @stack.with_font(SMALL_FONT) { @stack.add_text(SX + 4, SY + 4, 88, 14, '', color: WHITE) }
      @count = @stack.with_font(SMALL_FONT) { @stack.add_text(SX + 164, SY + 4, 88, 14, '', 2, color: WHITE) }
      @sheen_text = @stack.with_font(SMALL_FONT) { @stack.add_text(SX + 78, SY + 172, 100, 14, '', 1, color: DARK) }
      @give_group = [@preview_shape, @shape, @name, @count, @sheen_text] + @buttons + @label_names + @label_values
    end

    # @param name [Symbol] :box ou :give
    def show_screen(name)
      @screens[:box].visible = name == :box
      @screens[:give].visible = name == :give
      @box_group.each { |element| element.visible = name == :box }
      @give_group.each { |element| element.visible = name == :give }
    end

    # --- Affichage ---------------------------------------------------------------------------
    def refresh_box
      @title.text = "#{text(:title)} (#{@view.size})"
      @hint.text = @message || text(:hint_box)
      ROWS.times do |i|
        poffin = @view[@offset + i]
        @row_texts[i].text = poffin ? P.short_name(poffin) : (i.zero? && @view.empty? ? text(:none) : '')
        @row_icons[i].visible = poffin ? true : false
        @row_icons[i].set_bitmap(icon_of(poffin), :interface) if poffin
      end
      @selection.visible = !@view.empty?
      @selection.set_position(SX + LIST_X - 4, SY + LIST_Y + (@index - @offset) * ROW_H)
      @up.visible = @offset > 0
      @down.visible = @offset + ROWS < @view.size
      poffin = @view[@index]
      P::FLAVORS.each_index do |i|
        @values[i].text = poffin ? poffin['flavors'][i].to_s : ''
        @rings[i].visible = poffin ? true : false
      end
      @oval.text = poffin ? "#{text(:smooth)} #{poffin['smoothness']}" : ''
    end

    # @param poffin [Hash]
    # @return [String]
    def icon_of(poffin)
      return poffin['kind'] == 'burnt' ? 'poffin/mini_brule' : "poffin/mini_#{poffin['tier']}"
    end

    # Le Pokémon choisi : pentagone, conditions, lustre
    def refresh_give
      pokemon = party[@pokemon_index]
      poffin = @view[@index]
      return unless pokemon && poffin

      current = P.conditions(pokemon)
      effect = P.effect(pokemon, poffin)
      gains = effect ? effect[:gains] : [0] * 5
      LABELS.each_index do |i|
        @label_names[i].text = P::CONDITION_NAMES[i][P.language_index]
        value = current[i].to_i
        @label_values[i].text = gains[i] > 0 ? "#{value} +#{gains[i]}" : value.to_s
      end
      5.times do |i|
        @shape.set_point(i, *point(i, current[i].to_i))
        @preview_shape.set_point(i, *point(i, current[i].to_i + gains[i]))
      end
      @name.text = pokemon.given_name.to_s
      @count.text = "#{@pokemon_index + 1}/#{party.size}"
      sheen = P.sheen(pokemon)
      @sheen_text.text = "#{text(:sheen)} #{sheen}#{effect && effect[:sheen] > 0 ? " +#{effect[:sheen]}" : ''}"
      @hint.text = @message || (effect ? text(:hint_give) : text(:refuse))
    end

    # @param index [Integer] sommet (0 = haut, puis dans le sens des aiguilles d'une montre)
    # @param value [Integer] condition
    # @return [Array<Integer>] point à l'écran
    def point(index, value)
      radius = MIN_RADIUS + (RADIUS - MIN_RADIUS) * value.clamp(0, P::MAX_CONDITION).to_f / P::MAX_CONDITION
      angle = -Math::PI / 2 + index * 2 * Math::PI / 5
      return [(SX + CENTER[0] + Math.cos(angle) * radius).round, (SY + CENTER[1] + Math.sin(angle) * radius).round]
    end

    # Boutons des conditions : clignotent doucement
    def refresh_buttons
      state = @blink < 20 ? 1 : 2
      @buttons.each_with_index { |button, i| button.set_bitmap("poffin/bouton_#{LABELS[i][0]}_#{state}", :interface) if @button_state != state }
      @button_state = state
    end

    TEXTS = {
      title: ['Boîte à poffins', 'Poffin Case'],
      hint_box: ['A : donner   X : trier   B : quitter', 'A: give   X: sort   B: quit'],
      hint_give: ['A : donner ce poffin   B : retour', 'A: give this poffin   B: back'],
      none: ['Aucun poffin', 'No poffins'],
      refuse: ['Il n\'en veut pas.', 'It doesn\'t want it.'],
      sorted: ['Tri : ', 'Sorted by: '],
      date: ['ordre de cuisson', 'cooking order'],
      level: ['niveau', 'level'],
      smooth: ['douceur', 'smoothness'],
      name: ['nom', 'name'],
      sheen: ['Lustre', 'Sheen']
    }.freeze

    # @param key [Symbol]
    # @return [String]
    def text(key)
      value = TEXTS[key][P.language_index]
      return key == :smooth ? value.capitalize : value
    end
  end
end
