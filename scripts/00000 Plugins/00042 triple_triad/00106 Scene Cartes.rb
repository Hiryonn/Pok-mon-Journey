# Triple Triad : liste de cartes (choix de la main, collection, boutique, vente)
module GamePlay
  class TripleTriadCards < BaseCleanUpdate::FrameBalanced
    TT = ::TripleTriad
    ROWS = 10
    ROW_H = 16
    LIST_X = 24
    LIST_Y = 23

    # @return [Array<Symbol>, nil] main choisie (mode :hand), nil si abandon
    attr_reader :hand

    # @param mode [Symbol] :hand (choisir 5 cartes), :view (collection), :shop (acheter), :sell (vendre)
    # @param list [Array<Symbol>, nil] cartes en vente (mode :shop)
    def initialize(mode = :view, list = nil)
      super()
      TT.reload if PSDK_CONFIG.debug?
      @mode = mode
      @shop_list = list
      @hand = nil
      @chosen = []
      @index = 0
      @top = 0
      refresh_entries
    end

    def update_inputs
      return false if @entries.empty? && leave_empty

      if Input.repeat?(:UP) || Input.repeat?(:DOWN)
        move(Input.repeat?(:UP) ? -1 : 1)
      elsif Input.repeat?(:LEFT) || Input.repeat?(:RIGHT)
        move(Input.repeat?(:LEFT) ? -ROWS : ROWS)
      elsif Input.trigger?(:A)
        action_a
      elsif Input.trigger?(:B)
        action_b
      elsif Input.trigger?(:Y) && @mode == :hand
        auto_hand
      else
        return update_mouse_list
      end
      return false
    end

    private

    def create_graphics
      super
      Sprite.new(@viewport).set_bitmap(TT.file('deck_background'), :interface)
      @list_cursor = Sprite.new(@viewport).set_bitmap(TT.file('list_cursor'), :interface)
      @texts = UI::SpriteStack.new(@viewport)
      @title = @texts.add_text(20, 3, 280, 16, '', 0, color: 10)
      @rows = Array.new(ROWS) do |i|
        [@texts.add_text(LIST_X + 2, LIST_Y + i * ROW_H, 104, 16, '', 0, color: 10),
         @texts.add_text(LIST_X + 104, LIST_Y + i * ROW_H, 38, 16, '', 2, color: 10)]
      end
      @preview = UI::TripleTriad::CardSprite.new(@viewport)
      @preview.set_position(220, 28)
      @info = Array.new(5) { |i| @texts.add_text(184, 82 + i * 16, 112, 16, '', 1, color: 10) }
      @help = @texts.with_font(20) { @texts.add_text(28, 196, 264, 13, '', 0, color: 10) }
      @help2 = @texts.with_font(20) { @texts.add_text(28, 212, 264, 13, '', 0, color: 10) }
      @hand_sprites = Array.new(TT::HAND_SIZE) do |i|
        sprite = UI::TripleTriad::CardSprite.new(@viewport)
        sprite.set_position(42 + i * 48, 188)
        sprite.visible = false
        sprite
      end
      refresh
    end

    # --- Données --------------------------------------------------------------
    def refresh_entries
      @entries = case @mode
                 when :shop then (@shop_list || default_shop).uniq.sort_by { |s| data_creature(s).id }
                 else TT.owned
                 end
      @index = @index.clamp(0, [@entries.size - 1, 0].max)
    end

    # Boutique par défaut : Pokémon vus dans le Pokédex
    def default_shop
      list = (TT.config.shop || []).map(&:to_sym).reject { |s| TT.excluded?(s) }
      return list unless list.empty?

      return TT.all_species.select { |s| PFM.game_state.pokedex.creature_seen?(s) }
    end

    # @return [Integer] exemplaires encore disponibles (mode :hand)
    def available(symbol)
      return TT.count(symbol) - @chosen.count(symbol)
    end

    # --- Affichage ------------------------------------------------------------
    def refresh
      @top = @index - ROWS + 1 if @index >= @top + ROWS
      @top = @index if @index < @top
      @rows.each_with_index do |(name, right), i|
        symbol = @entries[@top + i]
        name.text = symbol ? TT::Card.get(symbol).name : ''
        right.text = symbol ? row_value(symbol) : ''
      end
      @list_cursor.visible = !@entries.empty?
      @list_cursor.set_position(LIST_X - 2, LIST_Y + 1 + (@index - @top) * ROW_H)
      refresh_preview
      refresh_bottom
    end

    # @return [String]
    def row_value(symbol)
      case @mode
      when :shop then "#{TT::Card.get(symbol).price}$"
      when :sell then "#{TT::Card.get(symbol).sell_price}$"
      when :hand then "x#{available(symbol)}"
      else "x#{TT.count(symbol)}"
      end
    end

    def refresh_preview
      symbol = @entries[@index]
      @preview.visible = !symbol.nil?
      return @info.each { |text| text.text = '' } unless symbol

      card = TT::Card.get(symbol)
      @preview.set(card, 0)
      @info[0].text = card.name
      @info[1].text = data_type(card.type).name.to_s
      @info[2].text = TT.t("Niveau #{card.level + 1}", "Level #{card.level + 1}")
      @info[3].text = TT.t("Possédées : #{TT.count(symbol)}", "Owned: #{TT.count(symbol)}")
      @info[4].text = @mode == :shop ? TT.t("Prix : #{card.price}$", "Price: #{card.price}$") : ''
    end

    def refresh_bottom
      money = PFM.game_state.money
      case @mode
      when :hand
        @title.text = TT.t("Choisis #{TT::HAND_SIZE} cartes (#{@chosen.size}/#{TT::HAND_SIZE})", "Choose #{TT::HAND_SIZE} cards (#{@chosen.size}/#{TT::HAND_SIZE})")
        @hand_sprites.each_with_index do |sprite, i|
          symbol = @chosen[i]
          sprite.visible = !symbol.nil?
          sprite.set(TT::Card.get(symbol), 0) if symbol
        end
        @help.text = ''
        @help2.text = ''
      when :shop
        @title.text = TT.t("Boutique de cartes — #{money}$", "Card shop — #{money}$")
        @help.text = TT.t('A : acheter    B : quitter', 'A: buy    B: quit')
        @help2.text = TT.t("Cartes : #{TT.total_count}", "Cards: #{TT.total_count}")
      when :sell
        @title.text = TT.t("Vendre des cartes — #{money}$", "Sell cards — #{money}$")
        @help.text = TT.t('A : vendre    B : quitter', 'A: sell    B: quit')
        @help2.text = ''
      else
        @title.text = TT.t("Mes cartes Triple Triad (#{TT.total_count})", "My Triple Triad cards (#{TT.total_count})")
        @help.text = TT.t('Haut / bas : carte    Gauche / droite : page', 'Up / down: card    Left / right: page')
        @help2.text = TT.t('B : quitter', 'B: quit')
      end
    end

    # --- Actions --------------------------------------------------------------
    def move(delta)
      return if @entries.empty?

      new_index = (@index + delta).clamp(0, @entries.size - 1)
      new_index = (@index + delta) % @entries.size if delta.abs == 1
      return if new_index == @index

      @index = new_index
      play_cursor_se
      refresh
    end

    def action_a
      symbol = @entries[@index]
      return play_buzzer_se unless symbol

      case @mode
      when :hand then add_to_hand(symbol)
      when :shop then buy(symbol)
      when :sell then sell(symbol)
      else play_buzzer_se
      end
    end

    def action_b
      if @mode == :hand && !@chosen.empty?
        play_cancel_se
        @chosen.pop
        return refresh
      end
      if @mode == :hand
        choice = display_message(TT.t('Abandonner le duel ?', 'Give up the duel?'), 1, TT.t('Oui', 'Yes'), TT.t('Non', 'No'))
        return unless choice == 0
      end
      play_cancel_se
      @running = false
    end

    def add_to_hand(symbol)
      return play_buzzer_se if available(symbol) <= 0 || @chosen.size >= TT::HAND_SIZE

      play_decision_se
      @chosen << symbol
      refresh
      confirm_hand if @chosen.size == TT::HAND_SIZE
    end

    # Y : les 5 meilleures cartes
    def auto_hand
      pool = TT.owned.flat_map { |s| [s] * TT.count(s) }.sort_by { |s| -TT::Card.get(s).total }
      @chosen = pool.first(TT::HAND_SIZE)
      play_decision_se
      refresh
      confirm_hand if @chosen.size == TT::HAND_SIZE
    end

    def confirm_hand
      choice = display_message(TT.t('Jouer avec ces cartes ?', 'Play with these cards?'), 1, TT.t('Oui', 'Yes'), TT.t('Non', 'No'))
      if choice == 0
        @hand = @chosen.dup
        @running = false
      else
        @chosen.pop
        refresh
      end
    end

    def buy(symbol)
      card = TT::Card.get(symbol)
      return display_message(TT.t("Tu n'as pas assez d'argent.", "You don't have enough money.")) if PFM.game_state.money < card.price

      choice = display_message(TT.t("Acheter #{card.name} pour #{card.price}$ ?", "Buy #{card.name} for #{card.price}$?"), 1, TT.t('Oui', 'Yes'), TT.t('Non', 'No'))
      return unless choice == 0

      PFM.game_state.add_money(-card.price)
      TT.add(symbol)
      play_decision_se
      refresh
    end

    def sell(symbol)
      card = TT::Card.get(symbol)
      choice = display_message(TT.t("Vendre #{card.name} pour #{card.sell_price}$ ?", "Sell #{card.name} for #{card.sell_price}$?"), 1, TT.t('Oui', 'Yes'), TT.t('Non', 'No'))
      return unless choice == 0

      TT.remove(symbol)
      PFM.game_state.add_money(card.sell_price)
      play_decision_se
      refresh_entries
      refresh
    end

    # Liste vide : message puis sortie
    # @return [Boolean]
    def leave_empty
      display_message(@mode == :shop ? TT.t("Il n'y a rien à vendre ici.", 'Nothing for sale here.') : TT.t("Tu n'as aucune carte.", 'You have no cards.'))
      @running = false
      return true
    end

    def update_mouse_list
      return true unless Mouse.trigger?(:LEFT)

      ROWS.times do |i|
        next unless Mouse.x.between?(LIST_X, LIST_X + 146) && Mouse.y.between?(LIST_Y + i * ROW_H, LIST_Y + (i + 1) * ROW_H - 1)
        next unless @entries[@top + i]

        if @index == @top + i
          action_a
        else
          @index = @top + i
          play_cursor_se
          refresh
        end
        return false
      end
      return true
    end
  end
end
