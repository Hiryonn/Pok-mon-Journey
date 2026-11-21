# Casino JP : la scène de la machine à sous (commande casino_jp)
#
#   ┌ machine (257x192, centrée) ─────────────────────────┐
#   │ texte du haut (état de la partie)                    │
#   │   [rouleau] [rouleau] [rouleau]                      │
#   │ CREDIT 00120            PAYOUT 00010                 │
#   │ touches                                              │
#   └──────────────────────────────────────────────────────┘
# Haut / bas : mise (1 à 3 jetons) ; A : lancer, puis arrêter les rouleaux un par un ; B : quitter (entre deux parties).
module GamePlay
  class CasinoJpScene < BaseCleanUpdate::FrameBalanced
    C = ::CasinoJp
    WHITE = 9
    SMALL_FONT = 20
    # Position de la machine
    MX = 31
    MY = 24
    # Fenêtres des rouleaux (dans la machine) : x de chaque rouleau, y, largeur
    REEL_X = [73, 113, 153].freeze
    REEL_Y = 48
    REEL_W = 32
    # Cadre des rouleaux (36x76) : 2 pixels de plus de chaque côté
    FRAME_MARGIN = 2
    # Chiffres : x de la première case (CREDIT, PAYOUT), y, pas
    DIGITS_X = [82, 186].freeze
    DIGITS_Y = 146
    DIGITS_STEP = 8
    DIGITS_COUNT = 5
    # Images affichées par rouleau : de la case n + 2 (en haut) à n - 1 (en bas)
    SLOTS = 4
    # Image du gain affichée derrière la machine (images) et vitesse de décompte des jetons
    WIN_FLASH = 90
    COUNT_STEP = 1

    # @param speed [Integer] vitesse des rouleaux
    def initialize(speed = 2)
      super()
      @pixels_per_frame = [speed.to_i, 1].max * C::SPEED_UNIT
      @bet = [C::BETS.last, C.coins].min
      @bet = C::BETS.first if @bet < C::BETS.first
      @state = :idle
      @free = false
      @positions = [0.0, 0.0, 0.0]
      @stops = []
      @targets = []
      @payout = 0
      @pending = 0
      @message = :bet
    end

    def update_inputs
      case @state
      when :idle then update_idle
      when :spinning then update_spinning
      end
      return false
    end

    def update_graphics
      advance_reels if @state == :spinning
      count_coins if @pending > 0
      @flash -= 1 if @flash && @flash > 0
      @win_bg.visible = @flash && @flash > 0 ? true : false
      refresh
      return nil
    end

    private

    # --- Touches ------------------------------------------------------------------
    def update_idle
      if Input.trigger?(:A)
        start_spin
      elsif Input.repeat?(:UP)
        change_bet(1)
      elsif Input.repeat?(:DOWN)
        change_bet(-1)
      elsif Input.trigger?(:B)
        play_cancel_se
        @running = false
      end
    end

    def update_spinning
      return unless Input.trigger?(:A)

      stop_reel
    end

    def change_bet(delta)
      return play_buzzer_se if @free

      bets = C::BETS.select { |b| b <= [C.coins, C::BETS.first].max }
      index = bets.index(@bet) || 0
      value = bets[(index + delta).clamp(0, bets.size - 1)]
      return play_buzzer_se if value == @bet

      @bet = value
      play_cursor_se
      @message = :bet
    end

    # --- Partie --------------------------------------------------------------------
    def start_spin
      return if @pending > 0

      cost = @free ? 0 : @bet
      if C.coins < cost
        @message = :broke
        return play_buzzer_se
      end
      C.coins = C.coins - cost
      @free = false
      @outcome = C.draw_outcome
      @stops = []
      @targets = []
      @payout = 0
      @state = :spinning
      @message = :spin
      @flash = 0
      play_se(C::SE_START)
    end

    def stop_reel
      reel = @targets.size
      return if reel >= 3

      @targets << C.stop_for(@positions[reel], @outcome, @targets)
      play_se(C::SE_STOP)
    end

    # Les rouleaux tournent ; celui dont l'arrêt est demandé s'arrête sur sa case
    def advance_reels
      step = @pixels_per_frame.to_f / C::CELL
      3.times do |reel|
        if @stops[reel]
          next
        elsif @targets[reel]
          @positions[reel] += step
          if @positions[reel] >= @targets[reel]
            @positions[reel] = @targets[reel].to_f
            @stops[reel] = @targets[reel]
          end
        else
          @positions[reel] += step
        end
      end
      finish_spin if (0..2).all? { |reel| @stops[reel] }
    end

    def finish_spin
      @state = :idle
      symbol = C.line_symbol(@stops)
      if symbol == C::REPLAY
        @free = true
        @message = :replay
      elsif symbol
        @payout = C.payout(symbol, @bet)
        @pending = @payout
        @message = :win
        @flash = WIN_FLASH
        play_se(C::SE_WIN)
      else
        @message = :lose
      end
      @message = :broke if C.coins < C::BETS.first && !@free && @pending == 0
      @bet = [@bet, C.coins].min if !@free && C.coins >= C::BETS.first
      @bet = C::BETS.first if @bet < C::BETS.first
    end

    # Les jetons gagnés arrivent un à un (A les ajoute tout de suite)
    def count_coins
      step = Input.press?(:A) ? @pending : [COUNT_STEP, @pending].min
      C.coins = C.coins + step
      @pending -= step
      @pending = 0 if C.coins >= C::MAX_COINS
    end

    # --- Création ------------------------------------------------------------------
    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @stack.add_sprite(0, 0, 'casino_jp/fond')
      @win_bg = @stack.add_sprite(0, 0, 'casino_jp/fond_gain')
      @win_bg.visible = false
      @stack.add_sprite(MX, MY, 'casino_jp/machine')
      create_reels
      create_digits
      create_texts
      refresh
    end

    def create_reels
      @symbol_textures = {}
      @reel_sprites = REEL_X.map do |x|
        sprites = Array.new(SLOTS) do
          sprite = Sprite.new(@viewport)
          sprite.visible = false
          sprite
        end
        @stack.add_sprite(MX + x - FRAME_MARGIN, MY + REEL_Y - FRAME_MARGIN, 'casino_jp/grille')
        sprites
      end
      @reel_ids = Array.new(3) { Array.new(SLOTS) }
    end

    def create_digits
      @digit_sprites = DIGITS_X.map do |x|
        Array.new(DIGITS_COUNT) { |i| @stack.add_sprite(MX + x + 1 + i * DIGITS_STEP, MY + DIGITS_Y, 'casino_jp/nv') }
      end
      @digit_values = [nil, nil]
    end

    def create_texts
      @top_text = @stack.with_font(SMALL_FONT) { @stack.add_text(MX + 8, MY + 6, 241, 14, '', 1, color: WHITE) }
      @bottom_text = @stack.with_font(SMALL_FONT) { @stack.add_text(MX + 4, MY + 177, 249, 14, text(:keys), 1, color: WHITE) }
      @shown_message = nil
    end

    # --- Affichage -----------------------------------------------------------------
    def refresh
      refresh_reels
      show_number(0, C.coins)
      show_number(1, @payout)
      message = [@message, @bet, @free]
      return if @shown_message == message

      @shown_message = message
      @top_text.text = message_text
    end

    def message_text
      case @message
      when :bet then format(text(:bet), @bet)
      when :win then format(text(:win), @payout)
      else text(@message)
      end
    end

    # Rouleaux : les cases défilent vers le bas, la case du milieu est celle de la ligne gagnante
    def refresh_reels
      3.times do |reel|
        position = @positions[reel]
        base = position.floor
        fraction = position - base
        SLOTS.times do |slot|
          place_symbol(reel, slot, C.symbol_at(base + 2 - slot), -34 + C::CELL * (slot + fraction))
        end
      end
    end

    # @param y [Float] position de la case dans la fenêtre (peut dépasser en haut et en bas : la case est coupée)
    def place_symbol(reel, slot, symbol, y)
      sprite = @reel_sprites[reel][slot]
      top_cut = [0, -y.round].max
      height = C::CELL - top_cut - [0, y.round + C::CELL - C::WINDOW_HEIGHT].max
      if height <= 0
        sprite.visible = false
        return
      end
      if @reel_ids[reel][slot] != symbol
        sprite.bitmap = symbol_texture(symbol)
        @reel_ids[reel][slot] = symbol
      end
      sprite.src_rect.set(2, top_cut, REEL_W, height)
      sprite.set_position(MX + REEL_X[reel], MY + REEL_Y + [y.round, 0].max)
      sprite.visible = true
    end

    def symbol_texture(symbol)
      return @symbol_textures[symbol] ||= RPG::Cache.interface("casino_jp/s#{symbol}")
    end

    # Chiffres lumineux ; les cases de tête restent éteintes
    def show_number(slot, value)
      return if @digit_values[slot] == value

      @digit_values[slot] = value
      digits = value.to_i.clamp(0, 99_999).to_s.rjust(DIGITS_COUNT, ' ')
      @digit_sprites[slot].each_with_index do |sprite, i|
        sprite.bitmap = RPG::Cache.interface("casino_jp/#{digits[i] == ' ' ? 'nv' : "n#{digits[i]}"}")
      end
    end

    def play_se(name)
      Audio.se_play("audio/se/#{name}") if name
    rescue StandardError
      nil
    end

    TEXTS = {
      bet: ['A : lancer (mise %d)', 'A: play (bet %d)'],
      spin: ['A : arrêter les rouleaux', 'A: stop the reels'],
      win: ['Gagné ! %d jetons', 'You win! %d coins'],
      lose: ['Perdu... A : rejouer', 'No luck... A: play again'],
      replay: ['Replay ! Partie gratuite (A)', 'Replay! Free game (A)'],
      broke: ["Plus assez de jetons (B : quitter)", 'Not enough coins (B: quit)'],
      keys: ['Haut/Bas : mise    A : jouer    B : quitter', 'Up/Down: bet    A: play    B: quit']
    }.freeze

    # @param key [Symbol]
    # @return [String]
    def text(key)
      fr, en = TEXTS[key]
      return $options && $options.language.to_s != 'fr' ? en : fr
    rescue StandardError
      return fr
    end
  end
end
