# Poffin : la cuisson (commande cuisiner_poffin)
#
#   1. Baies   : haut / bas choisit une baie du sac, A l'ajoute (4 au plus), B retire la dernière (ou quitte), Y passe à la cuisson
#   2. Cuisson : A lance la cuisson ; on tourne la pâte avec les flèches (haut, droite, bas, gauche, haut...), dans un sens ou dans l'autre.
#                Trop lentement : le feu monte (anneau bleu, jaune, rouge) et le poffin finit par brûler.
#                Trop vite : la pâte déborde. Pendant ce temps la pâte grossit, puis « FINI ! ».
#   3. Résultat : le poffin est ajouté à la liste du joueur (A pour continuer).
module GamePlay
  class PoffinCooking < BaseCleanUpdate::FrameBalanced
    P = ::Poffin
    WHITE = 9
    DARK = 0
    SMALL_FONT = 20
    SX = P::SCREEN_X
    SY = P::SCREEN_Y
    # Cases des baies (dans l'écran) : deux à gauche, deux à droite du pot
    SLOT_POSITIONS = [[8, 26], [8, 58], [168, 26], [168, 58]].freeze
    SLOT_FILES = %w[case_rouge case_bleue case_jaune case_verte].freeze
    # Liste des baies (dans l'écran) : cadre blanc de la planche
    LIST_X = 36
    LIST_Y = 92
    LIST_W = 184
    ROW_H = 18
    ROWS = 5
    # Pâte et cuillère : centre de la nappe et rayon de la cuillère
    CENTER_X = SX + 128
    CENTER_Y = SY + 96
    SPOON_RADIUS = 46
    # Un quart de tour de cuillère = 90 degrés
    QUARTER = Math::PI / 2
    # Fenêtre de mesure de l'allure (images) = 1 seconde
    WINDOW = 60

    # @return [Hash, nil] le poffin cuisiné (nil : rien cuisiné)
    attr_reader :poffin

    def initialize
      super()
      @state = :select
      @berries = P.available_berries
      @chosen = []
      @index = 0
      @offset = 0
      @poffin = nil
    end

    def update_inputs
      case @state
      when :select then update_select
      when :ready then update_ready
      when :cooking then update_cooking_inputs
      when :result then update_result
      end
      return false
    end

    def update_graphics
      update_cooking if @state == :cooking
      update_spoon
      @blink = ((@blink || 0) + 1) % 60
      @start_button.visible = @state == :ready && @blink < 40
      return nil
    end

    private

    # --- 1. Choix des baies -------------------------------------------------------------
    def update_select
      if Input.repeat?(:UP)
        move(-1)
      elsif Input.repeat?(:DOWN)
        move(1)
      elsif Input.trigger?(:A)
        add_berry
      elsif Input.trigger?(:B)
        remove_berry
      elsif Input.trigger?(:Y) || Input.trigger?(:X)
        go_ready
      end
    end

    def move(delta)
      return play_buzzer_se if @berries.empty?

      @index = (@index + delta) % @berries.size
      @offset = @index if @index < @offset
      @offset = @index - ROWS + 1 if @index >= @offset + ROWS
      @offset = 0 if @berries.size <= ROWS
      play_cursor_se
      refresh_select
    end

    # @return [Integer] combien de fois cette baie est déjà choisie
    def chosen_count(symbol)
      return @chosen.count(symbol)
    end

    def add_berry
      symbol = @berries[@index]
      return play_buzzer_se if symbol.nil? || @chosen.size >= P::MAX_BERRIES || chosen_count(symbol) >= P.berry_count(symbol)

      @chosen << symbol
      play_decision_se
      refresh_select
    end

    def remove_berry
      if @chosen.empty?
        play_cancel_se
        @running = false
      else
        @chosen.pop
        play_cancel_se
        refresh_select
      end
    end

    def go_ready
      return play_buzzer_se if @chosen.empty?

      @recipe = P.recipe(@chosen)
      @state = :ready
      play_decision_se
      show_screen(:cooking)
      @hint.text = text(:hint_ready)
      @top.text = ''
    end

    # --- 2. Cuisson ----------------------------------------------------------------------
    def update_ready
      if Input.trigger?(:A)
        start_cooking
      elsif Input.trigger?(:B)
        play_cancel_se
        @state = :select
        show_screen(:select)
        refresh_select
      end
    end

    def start_cooking
      @chosen.each { |symbol| consume(symbol) }
      @state = :cooking
      @frame = 0
      @heat = P::HEAT_START
      @good = 0
      @burn = 0
      @spills = 0
      @over_frames = 0
      @steps = []
      @direction = nil
      @spoon_angle = 0.0
      @spoon_target = 0.0
      @burnt = false
      play_decision_se
      @hint.text = text(:hint_cooking)
      refresh_cooking
    end

    def consume(symbol)
      $bag.remove_item(symbol, 1) if $bag
    rescue StandardError
      nil
    end

    DIRECTIONS = %i[UP RIGHT DOWN LEFT].freeze

    # Chaque pression d'une flèche voisine de la précédente (dans un sens ou dans l'autre) est un quart de tour
    def update_cooking_inputs
      DIRECTIONS.each_with_index do |key, dir|
        next unless Input.trigger?(key)

        step = @direction ? ((dir - @direction) % 4) : 1
        if step == 1 || step == 3
          @steps << @frame
          @spoon_target += (step == 1 ? 1 : -1) * QUARTER
        end
        @direction = dir
      end
    end

    # @return [Float] quarts de tour par seconde sur la dernière seconde
    def pace
      @steps.shift while @steps.first && @steps.first < @frame - WINDOW
      return @steps.size * 60.0 / [WINDOW, @frame + 1].min
    end

    def update_cooking
      @frame += 1
      speed = pace
      if speed < P::PACE_MIN
        @heat = [@heat + P::HEAT_UP, 100.0].min
        @over_frames = 0
      elsif speed > P::PACE_MAX
        @over_frames += 1
        if (@over_frames % P::SPILL_INTERVAL).zero? && @spills < P::MAX_SPILLS
          @spills += 1
          play_buzzer_se
        end
        @heat = [@heat - P::HEAT_DOWN, 0.0].max
      else
        @heat = [@heat - P::HEAT_DOWN, 0.0].max
        @good += 1
        @over_frames = 0
      end
      @burn += 1 if @heat >= P::HEAT_BURN
      @burnt = @burn >= P::BURN_LIMIT
      refresh_cooking
      finish_cooking if @burnt || @frame >= P::DURATION
    end

    def finish_cooking
      ratio = @good.fdiv([@frame, 1].max)
      @poffin = P.make(@recipe, ratio, @spills, @burnt)
      @state = :result
      show_result
    end

    # --- 3. Résultat ---------------------------------------------------------------------
    def update_result
      return unless Input.trigger?(:A) || Input.trigger?(:B)

      P.add(@poffin)
      play_decision_se
      @running = false
    end

    # --- Création --------------------------------------------------------------------------
    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @stack.add_sprite(0, 0, 'poffin/fond')
      @screens = {
        select: @stack.add_sprite(SX, SY, 'poffin/fond_liste'),
        cooking: @stack.add_sprite(SX, SY, 'poffin/nappe')
      }
      @screens[:cooking].visible = false
      create_slots
      create_cooking_sprites
      create_texts
      show_screen(:select)
      refresh_select
    end

    def create_slots
      @slot_sprites = SLOT_POSITIONS.each_with_index.map do |(x, y), i|
        @stack.add_sprite(SX + x, SY + y, "poffin/#{SLOT_FILES[i]}")
      end
      @slot_texts = SLOT_POSITIONS.map do |(x, y)|
        @stack.with_font(SMALL_FONT) { @stack.add_text(SX + x + 4, SY + y + 8, 72, 14, '', 1, color: DARK) }
      end
    end

    def create_cooking_sprites
      @ring = @stack.add_sprite(SX + 10, SY, 'poffin/feu_bleu')
      @dough = @stack.add_sprite(CENTER_X, CENTER_Y, 'poffin/pate_beige_1')
      @spoon = @stack.add_sprite(CENTER_X, CENTER_Y, 'poffin/cuillere')
      @arrow = @stack.add_sprite(SX + 150, SY + 8, 'poffin/fleche_verte')
      @arrow.zoom = 0.5
      @result_sprite = @stack.add_sprite(CENTER_X, CENTER_Y - 10, 'poffin/pofin_1')
      @start_button = @stack.add_sprite(CENTER_X - 48, SY + 150, 'poffin/bouton_start')
      @done_button = @stack.add_sprite(CENTER_X - 64, SY + 150, 'poffin/bouton_fini')
      [@dough, @result_sprite].each { |sprite| sprite.ox = sprite.width / 2 if sprite.respond_to?(:width) }
      [@ring, @dough, @spoon, @arrow, @result_sprite, @start_button, @done_button].each { |sprite| sprite.visible = false }
    end

    def create_texts
      @top = @stack.with_font(SMALL_FONT) { @stack.add_text(0, 5, 320, 14, '', 1, color: DARK) }
      @hint = @stack.with_font(SMALL_FONT) { @stack.add_text(0, 220, 320, 14, '', 1, color: DARK) }
      @list_texts = Array.new(ROWS) do |i|
        [@stack.with_font(SMALL_FONT) { @stack.add_text(SX + LIST_X, SY + LIST_Y + i * ROW_H, LIST_W - 36, 14, '', color: DARK) },
         @stack.with_font(SMALL_FONT) { @stack.add_text(SX + LIST_X + LIST_W - 36, SY + LIST_Y + i * ROW_H, 36, 14, '', 2, color: DARK) }]
      end
      @info_texts = Array.new(4) { |i| @stack.with_font(SMALL_FONT) { @stack.add_text(SX + 20, SY + 62 + i * 18, 216, 14, '', 1, color: DARK) } }
    end

    # --- Affichage -----------------------------------------------------------------------
    # @param name [Symbol] :select ou :cooking
    def show_screen(name)
      @screens[:select].visible = name == :select
      @screens[:cooking].visible = name == :cooking
      @slot_sprites.each { |sprite| sprite.visible = name == :select }
      @slot_texts.each { |t| t.visible = name == :select }
      @list_texts.each { |row| row.each { |t| t.visible = name == :select } }
      @info_texts.each { |t| t.visible = false }
      @ring.visible = @dough.visible = @spoon.visible = @arrow.visible = name == :cooking
      @result_sprite.visible = @done_button.visible = false
      @hint.text = text(:hint_select) if name == :select
    end

    def refresh_select
      SLOT_POSITIONS.size.times do |i|
        symbol = @chosen[i]
        @slot_texts[i].text = symbol ? P.berry_name(symbol) : ''
      end
      ROWS.times do |i|
        symbol = @berries[@offset + i]
        name, count = @list_texts[i]
        if symbol
          selected = @offset + i == @index
          name.text = "#{selected ? '> ' : '  '}#{P.berry_name(symbol)}"
          count.text = "x#{P.berry_count(symbol) - chosen_count(symbol)}"
        else
          name.text = i.zero? && @berries.empty? ? text(:no_berries) : ''
          count.text = ''
        end
      end
      preview = P.recipe(@chosen)
      @top.text = @chosen.empty? ? text(:title) : flavors_text(preview[:flavors])
    end

    # @param flavors [Array<Integer>]
    # @return [String] ex. « Épicé 12  Sec 0 ... »
    def flavors_text(flavors)
      return P::FLAVORS.each_index.map { |i| "#{P.flavor_name(P::FLAVORS[i])} #{flavors[i]}" }.join('  ')
    end

    def refresh_cooking
      speed = pace
      ring = @heat >= P::HEAT_RED ? 'feu_rouge' : (@heat >= P::HEAT_YELLOW ? 'feu_jaune' : 'feu_bleu')
      @ring.set_bitmap("poffin/#{ring}", :interface) if @ring_name != ring
      @ring_name = ring
      progress = @frame.to_f / P::DURATION
      color = @burn > 0 ? 'grise' : (@heat >= P::HEAT_RED ? 'orange' : 'beige')
      size = progress < 0.34 ? 1 : (progress < 0.67 ? 2 : 3)
      dough = "poffin/pate_#{color}_#{size}"
      if @dough_name != dough
        @dough.set_bitmap(dough, :interface)
        @dough.ox = @dough.width / 2
        @dough.oy = @dough.height / 2
      end
      @dough_name = dough
      @dough.zoom = 2
      arrow = speed < P::PACE_MIN ? 'fleche_bleue' : 'fleche_verte'
      @arrow.set_bitmap("poffin/#{arrow}", :interface) if @arrow_name != arrow
      @arrow_name = arrow
      @arrow.visible = speed <= P::PACE_MAX
      @top.text = format(text(:time), [(P::DURATION - @frame) / 60, 0].max)
    end

    # La cuillère tourne vers l'angle voulu
    def update_spoon
      return unless @state == :cooking || @state == :ready

      @spoon_angle = 0.0 if @spoon_angle.nil?
      @spoon_target = 0.0 if @spoon_target.nil?
      @spoon_angle += (@spoon_target - @spoon_angle) * 0.35
      @spoon.set_position(CENTER_X + Math.sin(@spoon_angle) * SPOON_RADIUS - 16, CENTER_Y - Math.cos(@spoon_angle) * SPOON_RADIUS - 28)
    end

    def show_result
      show_screen(:cooking)
      @ring.visible = @arrow.visible = @spoon.visible = @dough.visible = false
      @done_button.visible = true
      if @poffin['kind'] == 'burnt'
        @result_sprite.set_bitmap('poffin/pate_grise_3', :interface)
        @result_sprite.zoom = 2
      else
        @result_sprite.set_bitmap("poffin/pofin_#{@poffin['tier']}", :interface)
        @result_sprite.zoom = 1
      end
      @result_sprite.ox = @result_sprite.width / 2
      @result_sprite.oy = @result_sprite.height / 2
      @result_sprite.visible = true
      @top.text = P.name(@poffin)
      @hint.text = @poffin['kind'] == 'burnt' ? text(:burnt) : "#{flavors_text(@poffin['flavors'])}   #{text(:smooth)} #{@poffin['smoothness']}"
    end

    TEXTS = {
      title: ['Choisis jusqu\'à 4 baies', 'Pick up to 4 berries'],
      no_berries: ['Aucune baie dans le sac', 'No berries in the bag'],
      hint_select: ['A : ajouter   B : retirer / quitter   Y : cuisiner', 'A: add   B: remove / quit   Y: cook'],
      hint_ready: ['A : commencer   B : retour', 'A: start   B: back'],
      hint_cooking: ['Tourne avec les flèches (haut, droite, bas, gauche...)', 'Stir with the arrow keys (up, right, down, left...)'],
      time: ['Temps : %d', 'Time: %d'],
      burnt: ['Le poffin a brûlé... (A)', 'The poffin got burnt... (A)'],
      smooth: ['Douceur', 'Smoothness']
    }.freeze

    # @param key [Symbol]
    # @return [String]
    def text(key)
      return TEXTS[key][P.language_index]
    end
  end
end
