# Magasins : éléments communs aux écrans (fenêtres, argent qui défile, barre du bas, quantité, choix)
module UI
  module Magasin
    WHITE = 9
    DARK = 0
    SMALL = 20

    # Fenêtre de gauche : un titre et une valeur qui défile doucement vers sa nouvelle valeur
    class CounterWindow < SpriteStack
      # @return [Integer] valeur visée
      attr_reader :target

      def initialize(viewport, x, y, label, formatter)
        super(viewport, x, y, default_cache: :interface)
        add_sprite(0, 0, ::Magasins.file('window'))
        with_font(SMALL) { @label = add_text(6, 3, 100, 13, label, color: DARK) }
        @value_text = add_text(6, 16, 100, 16, '', 2, color: DARK)
        @formatter = formatter
        @shown = nil
        @target = 0
      end

      def label=(text)
        @label.text = text.to_s
      end

      # @param value [Integer]
      # @param instant [Boolean] sans défilement
      def set(value, instant: false)
        @target = value.to_i
        @shown = @target if instant || @shown.nil?
        refresh
      end

      # Défilement : l'argent monte ou descend en quelques images
      def update
        return if @shown.nil? || @shown == @target

        speed = [::Magasins.config.money_speed.to_i, 1].max
        step = [((@target - @shown).abs / speed.to_f).ceil, 1].max
        @shown += @target > @shown ? [step, @target - @shown].min : -[step, @shown - @target].min
        refresh
      end

      def rolling?
        return !@shown.nil? && @shown != @target
      end

      private

      def refresh
        @value_text.text = @formatter.call(@shown.to_i)
      end
    end

    # Barre du bas (celle du sac Horizon) : icône et texte (description ou phrase du vendeur)
    class InfoBar < SpriteStack
      ICON_CENTER = 24

      def initialize(viewport)
        super(viewport, 0, 193, default_cache: :interface)
        add_sprite(0, 0, 'bag_horizon/info')
        @icon = add_sprite(12, 12, UI::SpriteStack::NO_INITIAL_IMAGE)
        with_font(SMALL) { @text = add_text(46, 4, 266, 13, '', color: WHITE) }
      end

      # @param entry [Hash, nil] article dont on montre l'icône (nil : pas d'icône)
      # @param text [String]
      def show(entry, text)
        if entry
          ::Magasins.draw_icon(@icon, entry, x + ICON_CENTER - 16, y + ICON_CENTER - 16)
        else
          @icon.visible = false
        end
        @text.multiline_text = text.to_s.tr('’‘', "''")
      end
    end

    # Petite boîte de la quantité : « x3      600 P »
    class QuantityBox < SpriteStack
      def initialize(viewport, x = 208, y = 168)
        super(viewport, x, y, default_cache: :interface)
        add_sprite(0, 0, ::Magasins.file('quantity'))
        @qty = add_text(8, 3, 40, 16, '', color: DARK)
        @total = add_text(40, 3, 62, 16, '', 2, color: DARK)
        self.visible = false
      end

      def show(qty, total_text)
        @qty.text = "x#{qty}"
        @total.text = total_text
        self.visible = true
      end
    end

    # Boîte de choix (Oui / Non, Acheter / Vendre / Quitter)
    class ChoiceBox < SpriteStack
      # @return [Integer]
      attr_reader :index
      # @return [Array<String>]
      attr_reader :choices

      def initialize(viewport, choices, right = 316, bottom = 190)
        width = 64
        height = 8 + choices.size * 16
        super(viewport, right - width, bottom - height, default_cache: :interface)
        frame = add_sprite(0, 0, ::Magasins.file('choice'))
        frame.zoom_y = height / 40.0
        @choices = choices
        choices.each_with_index { |c, i| add_text(14, 4 + i * 16, 48, 16, c, color: DARK) }
        @arrow = add_sprite(6, 9, ::Magasins.file('arrow'))
        @index = 0
      end

      def index=(value)
        @index = value % @choices.size
        @arrow.y = y + 9 + @index * 16
      end

      # @return [Integer, nil] ligne sous la souris
      def hovered
        my = Mouse.y - y - 4
        return nil unless Mouse.x.between?(x, x + 63) && my >= 0

        row = my / 16
        return row < @choices.size ? row : nil
      end
    end
  end
end

module Magasins
  module_function

  # Icône d'un article (objet ou Pokémon) centrée dans une case de 32 x 32 à x, y
  def draw_icon(sprite, entry, x, y)
    if pokemon?(entry)
      creature = data_creature(fetch(entry, :species).to_s.to_sym)
      file = PFM::Pokemon.icon_filename(creature.id, fetch(entry, :form).to_i, false, fetch(entry, :shiny) == true, false)
      sprite.set_bitmap(file, :b_icon)
      size = sprite.bitmap.height
      sprite.src_rect.set(0, 0, size, size)
    else
      sprite.set_bitmap(data_item(fetch(entry, :item).to_s.to_sym).icon, :icon)
      size = sprite.bitmap.height
      sprite.src_rect.set(0, 0, sprite.bitmap.width, size)
    end
    sprite.set_position(x + (32 - sprite.src_rect.width) / 2, y + (32 - size) / 2)
    sprite.visible = true
  rescue StandardError
    sprite.visible = false
  end
end

module GamePlay
  # Écran commun des magasins : fond (la carte derrière), argent, barre du bas
  class MagasinBase < BaseCleanUpdate::FrameBalanced
    M = ::Magasins
    WHITE = 9
    DARK = 0
    SMALL = 20

    # @param shop_id [Symbol, String]
    def initialize(shop_id)
      super()
      @shop = M.shop(shop_id)
      @currency = M.shop_currency(@shop || {})
      M.check_restock(@shop) if @shop
      @state = :browse
    end

    def update_graphics
      @money&.update
      @counter&.update
      return true
    end

    def dispose
      super
      @snapshot&.dispose
    end

    private

    def create_graphics
      super
      create_background
    end

    # La carte derrière l'écran (comme dans le magasin) ; sinon le fond du Pokédex Horizon
    def create_background
      @background = Sprite.new(@viewport)
      if @__last_scene.respond_to?(:snap_to_bitmap)
        @snapshot = @__last_scene.snap_to_bitmap
        @background.bitmap = @snapshot
        return
      end
      raise 'pas de carte'
    rescue StandardError
      @snapshot = nil
      name = RPG::Cache.interface_exist?('horizon/team/fond') ? 'horizon/team/fond' : 'bag_horizon/background'
      @background.set_bitmap(name, :interface)
    end

    def stack(x = 0, y = 0)
      return UI::SpriteStack.new(@viewport, x, y, default_cache: :interface)
    end

    def amount(value)
      return M.amount_text(@currency, value)
    end

    def create_money_window
      @money = UI::Magasin::CounterWindow.new(@viewport, 4, 4, M.currency_name(@currency), ->(v) { amount(v) })
      @money.set(M.funds(@currency), instant: true)
    end

    def create_info
      @info = UI::Magasin::InfoBar.new(@viewport)
      @quantity = UI::Magasin::QuantityBox.new(@viewport)
    end

    # --- Choix --------------------------------------------------------------------------------------
    def open_choice(choices, &block)
      @choice&.dispose
      @choice = UI::Magasin::ChoiceBox.new(@viewport, choices)
      @choice_callback = block
      @previous_state = @state
      @state = :choice
    end

    def close_choice
      @choice&.dispose
      @choice = nil
    end

    def update_choice_inputs
      if Input.repeat?(:UP) || Input.repeat?(:DOWN)
        play_cursor_se
        @choice.index += Input.repeat?(:UP) ? -1 : 1
      elsif Input.trigger?(:A)
        play_decision_se
        choose(@choice.index)
      elsif Input.trigger?(:B)
        play_cancel_se
        choose(@choice.choices.size - 1)
      end
      return false
    end

    def update_choice_mouse
      row = @choice.hovered
      @choice.index = row if row && row != @choice.index
      if Mouse.trigger?(:LEFT) && row
        play_decision_se
        choose(row)
      elsif Mouse.trigger?(:RIGHT)
        play_cancel_se
        choose(@choice.choices.size - 1)
      end
      return false
    end

    def choose(index)
      callback = @choice_callback
      close_choice
      @state = @previous_state
      callback&.call(index)
    end

    # --- Message (A pour continuer) -----------------------------------------------------------------
    def show_message(text, entry = nil, &block)
      @info.show(entry, text)
      @message_callback = block
      @state = :message
    end

    def update_message_inputs
      return false unless Input.trigger?(:A) || Input.trigger?(:B) || Mouse.trigger?(:LEFT) || Mouse.trigger?(:RIGHT)

      play_decision_se
      callback = @message_callback
      @message_callback = nil
      @state = :browse
      callback ? callback.call : after_message
      return false
    end

    def after_message; end

    # --- Quantité -----------------------------------------------------------------------------------
    # @param min [Integer] 0 pour pouvoir retirer du panier
    def open_quantity(entry, start, min, max, &block)
      @qty_entry = entry
      @qty_value = start.clamp(min, [max, min].max)
      @qty_min = min
      @qty_max = [max, min].max
      @qty_callback = block
      @state = :quantity
      refresh_quantity
    end

    def refresh_quantity
      @quantity.show(@qty_value, amount(M.price(@qty_shop || @shop, @qty_entry) * @qty_value))
    end

    def update_quantity_inputs
      delta = 0
      delta = 1 if Input.repeat?(:UP)
      delta = -1 if Input.repeat?(:DOWN)
      delta = 10 if Input.repeat?(:RIGHT)
      delta = -10 if Input.repeat?(:LEFT)
      if delta != 0
        value = (@qty_value + delta).clamp(@qty_min, @qty_max)
        # haut / bas font le tour
        value = @qty_min if delta == 1 && @qty_value == @qty_max
        value = @qty_max if delta == -1 && @qty_value == @qty_min
        if value != @qty_value
          play_cursor_se
          @qty_value = value
          refresh_quantity
        end
      elsif Input.trigger?(:A)
        play_decision_se
        finish_quantity(@qty_value)
      elsif Input.trigger?(:B)
        play_cancel_se
        finish_quantity(nil)
      end
      return false
    end

    def update_quantity_mouse
      if Mouse.wheel != 0
        @qty_value = (@qty_value + (Mouse.wheel <=> 0)).clamp(@qty_min, @qty_max)
        Mouse.wheel = 0
        play_cursor_se
        refresh_quantity
      elsif Mouse.trigger?(:LEFT)
        play_decision_se
        finish_quantity(@qty_value)
      elsif Mouse.trigger?(:RIGHT)
        play_cancel_se
        finish_quantity(nil)
      end
      return false
    end

    def finish_quantity(value)
      @quantity.visible = false
      @state = :browse
      callback = @qty_callback
      @qty_callback = nil
      callback&.call(value)
    end

    # Joue le son d'achat de PSDK
    def play_buy_se
      $game_system.se_play($data_system.shop_se)
    rescue StandardError
      play_decision_se
    end
  end
end
