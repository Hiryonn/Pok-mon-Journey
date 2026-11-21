# Triple Triad : le duel (plateau 3x3, ou 4x4 avec des cases bloquées pour la variante Tetra)
module GamePlay
  class TripleTriadDuel < BaseCleanUpdate::FrameBalanced
    TT = ::TripleTriad
    # Résultat : 1 victoire, 2 défaite, 3 égalité
    WIN = 1
    LOSE = 2
    DRAW = 3

    # @return [Integer]
    attr_reader :result
    # @return [Array<Symbol>] cartes gagnées / perdues par le joueur
    attr_reader :won_cards, :lost_cards

    # @param opponent_name [String]
    # @param player_hand [Array<Symbol>] 5 cartes du joueur
    # @param opponent_hand [Array<Symbol>] 5 cartes de l'adversaire
    # @param rules [Array<Symbol>]
    def initialize(opponent_name, player_hand, opponent_hand, rules = [])
      super()
      @opponent_name = opponent_name.to_s
      @rules = rules
      @start_hands = [player_hand.map(&:to_sym), opponent_hand.map(&:to_sym)]
      @result = DRAW
      @won_cards = []
      @lost_cards = []
      @state = :start
      @rounds = 0
      @tetra = @rules.include?(:tetra)
      @size = @tetra ? 4 : 3
    end

    def update_inputs
      case @state
      when :start then start_game
      when :choose_card then update_choose_card
      when :choose_cell then update_choose_cell
      when :opponent then update_opponent
      when :finish then finish_game
      end
      return false
    end

    def update_graphics
      @blink = (@blink || 0) + 1
      @cursor.src_rect.y = (@blink / 20).even? ? 0 : @cursor.bitmap.height / 2 if @cursor.visible
      return true
    end

    private

    def create_graphics
      super
      @background = Sprite.new(@viewport).set_bitmap(TT.file(@tetra ? 'tetra_background' : 'background'), :interface)
      @block_sprites = Array.new(@size * @size) do |cell|
        sprite = Sprite.new(@viewport)
        sprite.set_bitmap(TT.file('tetra_block'), :interface) if @tetra
        sprite.set_position(*cell_position(cell))
        sprite.visible = false
        next sprite
      end
      @element_sprites = Array.new(@size * @size) do |cell|
        sprite = Sprite.new(@viewport).set_bitmap(TT.file('element'), :interface)
        sprite.set_position(*cell_position(cell))
        sprite.visible = false
        next sprite
      end
      @element_texts = UI::SpriteStack.new(@viewport)
      @names = UI::SpriteStack.new(@viewport)
      @names.add_text(6, 2, 100, 16, PFM.game_state.trainer.name.to_s, 0, color: 10)
      @names.add_text(214, 2, 100, 16, @opponent_name, 2, color: 10)
      score_x = @tetra ? [26, 262] : [38, 258]
      @scores = [UI::TripleTriad::Score.new(@viewport, score_x[0], 200), UI::TripleTriad::Score.new(@viewport, score_x[1], 200)]
      @card_pool = []
      @cursor = Sprite.new(@viewport).set_bitmap(TT.file('cursor'), :interface)
      @cursor.src_rect.height = @cursor.bitmap.height / 2
      @cursor.visible = false
      @cursor.z = 200
    end

    # --- Partie ---------------------------------------------------------------
    def start_game
      @rounds += 1
      @game = TT::Game.new(@rules)
      @origin = Array.new(@game.cells)
      @hands = @start_hands.map { |list| list.map { |s| TT::Card.get(s) } } unless @sudden_hands
      @hands = @sudden_hands if @sudden_hands
      @sudden_hands = nil
      @card_pool.each(&:dispose)
      @card_pool = []
      @hand_sprites = @hands.each_with_index.map do |hand, owner|
        hand.map do |card|
          sprite = UI::TripleTriad::CardSprite.new(@viewport)
          sprite.set(card, owner, owner == 1 && !@game.rule?(:open))
          @card_pool << sprite
          sprite
        end
      end
      @board_sprites = Array.new(@game.cells)
      @block_sprites.each_with_index { |sprite, cell| sprite.visible = @game.blocked[cell] }
      show_elements
      layout_hands
      update_scores
      Graphics.sort_z
      if @rounds == 1
        game_name = @tetra ? 'Tetra' : 'Triple Triad'
        display_message(TT.t("#{game_name} contre #{@opponent_name} !", "#{game_name} against #{@opponent_name}!"))
        display_message(rules_text) unless rules_text.empty?
      else
        display_message(TT.t('Mort subite ! On rejoue avec les cartes possédées.', 'Sudden death! Play again with the cards you own.'))
      end
      @turn = rand(2)
      display_message(@turn == 0 ? TT.t('Tu commences !', 'You go first!') : TT.t("#{@opponent_name} commence.", "#{@opponent_name} goes first."))
      @hand_index = 0
      @cell_index = @game.free_cells.min_by { |c| ((c % @size) * 2 - (@size - 1))**2 + ((c / @size) * 2 - (@size - 1))**2 } || 0
      next_turn(false)
    end

    # @return [String]
    def rules_text
      names = { open: TT.t('Ouvert', 'Open'), same: TT.t('Pareil', 'Same'), samewall: TT.t('Pareil mur', 'Same Wall'),
                plus: 'Plus', elements: TT.t('Éléments', 'Elements'), random: TT.t('Hasard', 'Random'),
                suddendeath: TT.t('Mort subite', 'Sudden Death'), tetra: TT.t('Tetra (plateau 4x4)', 'Tetra (4x4 board)') }
      list = @rules.filter_map { |rule| names[rule] }
      return '' if list.empty?

      return TT.t("Règles : #{list.join(', ')}.", "Rules: #{list.join(', ')}.")
    end

    def show_elements
      @element_texts.dispose
      @element_texts = UI::SpriteStack.new(@viewport)
      @element_labels = {}
      @element_sprites.each_with_index do |sprite, cell|
        type = @game.elements[cell]
        sprite.visible = !type.nil?
        next unless type

        x, y = cell_position(cell)
        @element_texts.with_font(20) { @element_labels[cell] = @element_texts.add_text(x, y + 17, cell_w, 13, data_type(type).name.to_s, 1, color: 10) }
      end
    end

    # @param switch [Boolean] change de joueur
    def next_turn(switch = true)
      @turn = 1 - @turn if switch
      return @state = :finish if @game.full? || @hands.all?(&:empty?)
      # Tetra : un joueur sans carte passe son tour
      return next_turn if @hands[@turn].empty?

      if @turn == 0
        @hand_index = @hand_index.clamp(0, @hands[0].size - 1)
        @state = :choose_card
        layout_hands
        place_cursor_on_hand
      else
        @cursor.visible = false
        layout_hands
        @wait = 30
        @state = :opponent
      end
    end

    # --- Joueur ---------------------------------------------------------------
    def update_choose_card
      size = @hands[0].size
      if Input.repeat?(:UP) || Input.repeat?(:DOWN)
        @hand_index = (@hand_index + (Input.repeat?(:UP) ? -1 : 1)) % size
        play_cursor_se
        layout_hands
        place_cursor_on_hand
      elsif Input.trigger?(:A)
        play_decision_se
        @state = :choose_cell
        @cell_index = @game.free_cells.include?(@cell_index) ? @cell_index : @game.free_cells.first
        place_cursor_on_cell
      elsif Input.trigger?(:B)
        play_buzzer_se
      end
      update_mouse_hand
    end

    def update_choose_cell
      if Input.repeat?(:LEFT) && @cell_index % @size > 0
        @cell_index -= 1
      elsif Input.repeat?(:RIGHT) && @cell_index % @size < @size - 1
        @cell_index += 1
      elsif Input.repeat?(:UP) && @cell_index >= @size
        @cell_index -= @size
      elsif Input.repeat?(:DOWN) && @cell_index < @size * (@size - 1)
        @cell_index += @size
      elsif Input.trigger?(:A)
        return play_buzzer_se unless @game.free_cells.include?(@cell_index)

        play_decision_se
        @cursor.visible = false
        return play_card(0, @hand_index, @cell_index)
      elsif Input.trigger?(:B)
        play_cancel_se
        @state = :choose_card
        return place_cursor_on_hand
      else
        return update_mouse_cell
      end
      play_cursor_se
      place_cursor_on_cell
    end

    def update_mouse_hand
      return unless Mouse.trigger?(:LEFT)

      @hand_sprites[0].each_with_index do |sprite, index|
        next unless sprite.simple_mouse_in?

        @hand_index = index
        layout_hands
        place_cursor_on_hand
        @state = :choose_cell
        @cell_index = @game.free_cells.first
        return place_cursor_on_cell
      end
    end

    def update_mouse_cell
      return unless Mouse.trigger?(:LEFT)

      (@size * @size).times do |cell|
        x, y = cell_position(cell)
        next unless Mouse.x.between?(x, x + cell_w) && Mouse.y.between?(y, y + cell_h)
        return play_buzzer_se unless @game.free_cells.include?(cell)

        @cursor.visible = false
        return play_card(0, @hand_index, cell)
      end
    end

    # --- Adversaire -----------------------------------------------------------
    def update_opponent
      return @wait -= 1 if @wait > 0

      index, cell = @game.best_move(@hands[1], 1)
      play_card(1, index, cell)
    end

    # --- Pose et captures -----------------------------------------------------
    # @param owner [Integer]
    # @param index [Integer] carte de la main
    # @param cell [Integer]
    def play_card(owner, index, cell)
      card = @hands[owner].delete_at(index)
      sprite = @hand_sprites[owner].delete_at(index)
      sprite.hidden = false
      sprite.owner = owner
      move_sprite(sprite, *cell_position(cell))
      @board_sprites[cell] = sprite
      @element_labels[cell]&.visible = false # le nom du type ne passe pas par-dessus la carte
      @origin[cell] = owner
      flips = @game.place(cell, card, owner)
      announce = flips.map(&:last).uniq & %i[same plus combo]
      announce.each do |kind|
        text = { same: TT.t('Pareil !', 'Same!'), plus: 'Plus !', combo: 'Combo !' }[kind]
        display_message(text)
      end
      flips.each { |c, _| flip_sprite(@board_sprites[c], owner) }
      update_scores
      @hand_index = 0 if owner == 0
      next_turn
    end

    # Déplacement de la main vers la case
    def move_sprite(sprite, x, y)
      sx = sprite.x
      sy = sprite.y
      8.times do |i|
        t = (i + 1) / 8.0
        sprite.set_position((sx + (x - sx) * t).round, (sy + (y - sy) * t).round)
        Graphics.update
      end
    end

    # Capture : la carte clignote puis change de couleur
    def flip_sprite(sprite, owner)
      play_cursor_se
      4.times do |i|
        sprite.visible = i.odd?
        3.times { Graphics.update }
      end
      sprite.owner = owner
      sprite.visible = true
      Graphics.update
    end

    def update_scores
      2.times { |owner| @scores[owner].value = points(owner) }
    end

    # --- Positions ------------------------------------------------------------
    # @return [Array<Integer>]
    def cell_position(cell)
      return TT::TETRA_BOARD_X + (cell % 4) * cell_w, TT::TETRA_BOARD_Y + (cell / 4) * cell_h if @tetra

      return TT::BOARD_X + (cell % 3) * cell_w, TT::BOARD_Y + (cell / 3) * cell_h
    end

    def cell_w
      return @tetra ? TT::TETRA_CELL_W : TT::CELL_W
    end

    def cell_h
      return @tetra ? TT::TETRA_CELL_H : TT::CELL_H
    end

    # Points d'un joueur : cartes possédées sur le plateau et dans la main (Tetra : plateau seulement)
    def points(owner)
      return @game.owned(owner) if @tetra

      return @game.owned(owner) + @hands[owner].size
    end

    def layout_hands
      @hand_sprites.each_with_index do |sprites, owner|
        sprites.each_with_index do |sprite, index|
          x = (@tetra ? TT::TETRA_HAND_X : TT::HAND_X)[owner]
          x += TT::HAND_PICK_OFFSET * (owner == 0 ? 1 : -1) if owner == 0 && index == @hand_index && %i[choose_card choose_cell].include?(@state)
          sprite.set_position(x, TT::HAND_Y + index * TT::HAND_STEP)
        end
      end
    end

    def place_cursor_on_hand
      sprite = @hand_sprites[0][@hand_index]
      return @cursor.visible = false unless sprite

      @cursor.set_position(sprite.x - 2, sprite.y - 2)
      @cursor.visible = true
    end

    def place_cursor_on_cell
      x, y = cell_position(@cell_index)
      @cursor.set_position(x - 2, y - 2)
      @cursor.visible = true
    end

    # --- Fin ------------------------------------------------------------------
    def finish_game
      @cursor.visible = false
      player = points(0)
      opponent = points(1)
      if player == opponent && @game.rule?(:suddendeath) && @rounds < 5
        prepare_sudden_death
        return @state = :start
      end
      @result = player > opponent ? WIN : (player < opponent ? LOSE : DRAW)
      display_message(case @result
                      when WIN then TT.t("Tu as gagné ! (#{player} - #{opponent})", "You won! (#{player} - #{opponent})")
                      when LOSE then TT.t("Tu as perdu… (#{player} - #{opponent})", "You lost... (#{player} - #{opponent})")
                      else TT.t("Égalité ! (#{player} - #{opponent})", "It's a draw! (#{player} - #{opponent})")
                      end)
      trade_cards
      @running = false
      @state = :done
    end

    # Mort subite : chacun reprend les cartes qu'il possède
    def prepare_sudden_death
      owned = [[], []]
      @game.board.each { |slot| owned[slot.owner] << slot.card if slot }
      2.times { |owner| owned[owner].concat(@hands[owner]) }
      @sudden_hands = owned.map { |cards| cards.first(TT::HAND_SIZE) }
      @board_sprites.compact.each(&:dispose)
      @card_pool -= @board_sprites.compact
    end

    # Échange de cartes selon la règle (une seule carte par défaut)
    def trade_cards
      return if @result == DRAW || @game.rule?(:trade_none)

      if @game.rule?(:trade_direct)
        @game.board.each_with_index do |slot, cell|
          next if slot.nil? || slot.owner == @origin[cell]

          slot.owner == 0 ? @won_cards << slot.card.db_symbol : @lost_cards << slot.card.db_symbol
        end
      elsif @game.rule?(:trade_all)
        @result == WIN ? @won_cards.concat(@start_hands[1]) : @lost_cards.concat(@start_hands[0])
      elsif @result == WIN
        @won_cards << choose_prize
      else
        @lost_cards << @start_hands[0].max_by { |s| TT::Card.get(s).total }
      end
      @lost_cards.each { |s| TT.remove(s) }
      @won_cards.each { |s| TT.add(s) }
      @won_cards.each { |s| display_message(TT.t("Tu gagnes la carte #{TT::Card.get(s).name} !", "You got the #{TT::Card.get(s).name} card!")) }
      @lost_cards.each { |s| display_message(TT.t("#{@opponent_name} prend ta carte #{TT::Card.get(s).name}…", "#{@opponent_name} took your #{TT::Card.get(s).name} card...")) }
    end

    # Le joueur choisit une carte de l'adversaire
    # @return [Symbol]
    def choose_prize
      @card_pool.each { |sprite| sprite.visible = false }
      cards = @start_hands[1].map { |s| TT::Card.get(s) }
      sprites = cards.each_with_index.map do |card, i|
        sprite = UI::TripleTriad::CardSprite.new(@viewport)
        sprite.set(card, 1)
        sprite.set_position(50 + i * 46, 96)
        sprite
      end
      Graphics.sort_z
      index = 0
      display_message(TT.t('Choisis une carte à gagner.', 'Choose a card to win.'))
      loop do
        Graphics.update
        @cursor.set_position(sprites[index].x - 2, sprites[index].y - 2)
        @cursor.visible = true
        update_graphics
        if Input.repeat?(:LEFT) || Input.repeat?(:RIGHT)
          index = (index + (Input.repeat?(:LEFT) ? -1 : 1)) % sprites.size
          play_cursor_se
        elsif Input.trigger?(:A)
          play_decision_se
          break
        end
        sprites.each_with_index do |sprite, i|
          next unless Mouse.trigger?(:LEFT) && sprite.simple_mouse_in?

          index = i
        end
      end
      @cursor.visible = false
      sprites.each(&:dispose)
      return cards[index].db_symbol
    end
  end
end
