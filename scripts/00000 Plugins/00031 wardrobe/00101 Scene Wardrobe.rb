# Wardrobe : la salle d'essayage (commande ouvrir_wardrobe)
#   Haut / bas choisit une tenue : le héros l'essaie dans l'alcôve (aperçu), la description s'affiche
#   A enfile la tenue : le rideau se ferme, le héros change, le rideau se rouvre
#   B quitte
# La première ligne, « Ma tenue », est l'apparence d'origine du héros. Un marqueur rose indique ce qu'il porte.
module GamePlay
  class Wardrobe < BaseCleanUpdate::FrameBalanced
    W = ::Wardrobe
    DARK = 0
    WHITE = 9
    FONT = 20
    SMALL_FONT = 18
    # Panneau de droite
    PANEL_X = 142
    LIST_X = 152
    LIST_Y = 46
    ROW_H = 22
    ROWS = 6
    DESCRIPTION_Y = 186
    LINE_H = 15
    # Alcôve : bord droit et haut du rideau, sol et centre pour le héros
    CURTAIN_RIGHT = 132
    CURTAIN_Y = 87
    CURTAIN_WIDTHS = [105, 94, 80, 70, 55, 39, 28, 20, 12].freeze
    HERO_X = 73
    HERO_FLOOR = 184
    HERO_ZOOM = 2

    # @return [Boolean] le héros a changé de tenue
    attr_reader :changed

    def initialize
      super()
      @tick = 0
      @changed = false
      @index = 0
      @offset = 0
      @state = :browse
      @curtain = CURTAIN_WIDTHS.size
      @message = nil
      @previews = {}
      @rows = build_rows
    end

    def update_inputs
      return false unless @state == :browse

      if Input.repeat?(:UP)
        move(-1)
      elsif Input.repeat?(:DOWN)
        move(1)
      elsif Input.trigger?(:A)
        start_change
      elsif Input.trigger?(:B)
        play_cancel_se
        dispose_previews
        @running = false
      end
      return false
    end

    def update_graphics
      @tick += 1
      case @state
      when :closing then update_closing
      when :changing then update_changing
      when :opening then update_opening
      end
      return nil
    end

    private

    # @return [Array<Hash>] { outfit: Hash ou nil } : « Ma tenue » puis les tenues possédées
    def build_rows
      return [{outfit: nil}] + W.owned_outfits.map { |outfit| {outfit: outfit} }
    end

    # --- Choix -------------------------------------------------------------------------------
    def move(delta)
      return if @rows.size <= 1

      @index = (@index + delta) % @rows.size
      @offset = @index if @index < @offset
      @offset = @index - ROWS + 1 if @index >= @offset + ROWS
      @offset = 0 if @rows.size <= ROWS
      @message = nil
      play_cursor_se
      refresh_list
      refresh_preview
    end

    # @return [Boolean] la ligne est ce que porte le héros
    def current?(row)
      worn = W.worn_item
      return row[:outfit] ? row[:outfit]['item'].to_s == worn.to_s : worn.nil?
    end

    def start_change
      row = @rows[@index]
      return play_buzzer_se if current?(row)

      @target = row
      @message = nil
      @wait = 0
      @state = :closing
      play_decision_se
    end

    # --- Animation du rideau -----------------------------------------------------------------
    def update_closing
      return unless (@tick % 2).zero?

      @curtain -= 1
      show_curtain
      return if @curtain > 1

      @state = :changing
      @wait = 24
      switch_outfit
    end

    def update_changing
      @wait -= 1
      @state = :opening if @wait <= 0
    end

    def update_opening
      return unless (@tick % 2).zero?

      @curtain += 1
      show_curtain
      return if @curtain < CURTAIN_WIDTHS.size

      @state = :browse
      @message = text(:done)
      refresh_list
    end

    # Le héros change vraiment (rideau fermé)
    def switch_outfit
      outfit = @target[:outfit]
      done = outfit ? W.wear(outfit) : W.restore
      @changed = true if done
      @previews.each_value { |texture| dispose_texture(texture) }
      @previews = {}
      refresh_preview
      refresh_list
    end

    # --- Création ----------------------------------------------------------------------------
    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @stack.add_sprite(0, 0, 'wardrobe/fond')
      @hero = @stack.add_sprite(HERO_X, HERO_FLOOR, 'wardrobe/marqueur')
      @hero.visible = false
      @curtain_sprite = @stack.add_sprite(CURTAIN_RIGHT - CURTAIN_WIDTHS[0], CURTAIN_Y, 'wardrobe/rideau_1')
      @curtain_sprite.visible = false
      @title = @stack.with_font(FONT) { @stack.add_text(PANEL_X + 8, 22, 164, 16, W.tab_name, 1, color: DARK) }
      @cursor = @stack.add_sprite(LIST_X, LIST_Y, 'wardrobe/curseur')
      @row_texts = Array.new(ROWS) do |i|
        @stack.with_font(FONT) { @stack.add_text(LIST_X + 6, LIST_Y + i * ROW_H + 3, 130, 16, '', color: DARK) }
      end
      @markers = Array.new(ROWS) { |i| @stack.add_sprite(LIST_X + 144, LIST_Y + i * ROW_H + 7, 'wardrobe/marqueur') }
      @up = @stack.add_sprite(PANEL_X + 78, 39, 'wardrobe/fleche_haut')
      @down = @stack.add_sprite(PANEL_X + 78, LIST_Y + ROWS * ROW_H + 1, 'wardrobe/fleche_bas')
      @lines = Array.new(3) do |i|
        @stack.with_font(SMALL_FONT) { @stack.add_text(LIST_X + 4, DESCRIPTION_Y + i * LINE_H, 156, 14, '', color: DARK) }
      end
      @hint = @stack.with_font(SMALL_FONT) { @stack.add_text(0, 223, PANEL_X, 14, '', 1, color: WHITE) }
      refresh_list
      refresh_preview
    end

    # --- Affichage ---------------------------------------------------------------------------
    def show_curtain
      @curtain_sprite.visible = @curtain < CURTAIN_WIDTHS.size
      return unless @curtain_sprite.visible

      @curtain_sprite.set_bitmap("wardrobe/rideau_#{@curtain}", :interface)
      @curtain_sprite.set_position(CURTAIN_RIGHT - CURTAIN_WIDTHS[@curtain - 1], CURTAIN_Y)
      @hero.visible = false if @curtain <= 2
    end

    def refresh_list
      ROWS.times do |i|
        row = @rows[@offset + i]
        @row_texts[i].text = row ? row_name(row) : ''
        @markers[i].visible = row ? current?(row) : false
      end
      @cursor.set_position(LIST_X, LIST_Y + (@index - @offset) * ROW_H)
      @up.visible = @offset > 0
      @down.visible = @offset + ROWS < @rows.size
      description = row_description(@rows[@index])
      lines = W.wrap(description)
      @lines.each_with_index { |line, i| line.text = lines[i].to_s }
      @hint.text = @message || text(:hint)
    end

    # @param row [Hash]
    # @return [String]
    def row_name(row)
      return row[:outfit] ? W.name_of(row[:outfit]) : text(:base)
    end

    # @param row [Hash]
    # @return [String]
    def row_description(row)
      return row[:outfit] ? W.description_of(row[:outfit]) : text(:base_description)
    end

    # Le héros essaie la tenue choisie dans l'alcôve
    def refresh_preview
      return unless W.ready?

      row = @rows[@index]
      key = row[:outfit] ? row[:outfit]['item'].to_s : ''
      @previews[key] ||= begin
        base = W.base_spec
        spec = row[:outfit] ? W.build_spec(base, row[:outfit]) : base
        Generateur.compose_texture('walk', spec)
      rescue StandardError => e
        log_error("Wardrobe : aperçu impossible (#{e.message})") if respond_to?(:log_error, true)
        nil
      end
      texture = @previews[key]
      @hero.visible = !texture.nil? && @state != :changing && @curtain >= CURTAIN_WIDTHS.size - 1
      return unless texture

      width = texture.width / 4
      height = texture.height / 4
      @hero.bitmap = texture
      @hero.src_rect.set(0, 0, width, height)
      @hero.zoom_x = HERO_ZOOM
      @hero.zoom_y = HERO_ZOOM
      @hero.set_position(HERO_X - width * HERO_ZOOM / 2, HERO_FLOOR - height * HERO_ZOOM)
    end

    def dispose_previews
      @previews.each_value { |texture| dispose_texture(texture) }
      @previews = {}
    end

    # @param texture [Object, nil]
    def dispose_texture(texture)
      texture.dispose if texture.respond_to?(:dispose) && !(texture.respond_to?(:disposed?) && texture.disposed?)
    end

    TEXTS = {
      hint: ['A : enfiler   B : quitter', 'A: wear   B: leave'],
      done: ['Tenue enfilée !', 'Outfit on!'],
      base: ['Ma tenue', 'My look'],
      base_description: ['Ton apparence d\'origine.', 'Your original look.']
    }.freeze

    # @param key [Symbol]
    # @return [String]
    def text(key)
      return TEXTS[key][W.language_index]
    end
  end
end
