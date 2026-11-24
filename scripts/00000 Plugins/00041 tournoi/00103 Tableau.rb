# Tournoi : tableau à élimination directe (2 à 16 participants) et déroulement du tournoi
module Tournoi
  # Participant : le joueur, un dresseur de Studio ou une place vide (qualifié d'office)
  Entrant = Struct.new(:kind, :ref, :name) do
    def player?
      kind == :player
    end

    def bye?
      kind == :bye
    end
  end

  class Cup
    MAX_SIZE = 16
    # @return [Hash] données du tournoi (tournois.json)
    attr_reader :data
    # @return [Hash] règles
    attr_reader :rules
    # @return [Array<Array<Entrant>>] rounds[0] : tableau de départ ; rounds[r + 1] : vainqueurs du tour r
    attr_reader :rounds
    # @return [Integer] tour en cours (0 : premier tour)
    attr_reader :round
    # @return [Integer, nil] place du joueur (1 : vainqueur) une fois le tournoi fini
    attr_reader :placement

    # @param data [Hash]
    # @param rules [Hash] règles en plus (commande)
    def initialize(data, rules = {})
      @data = data
      @rules = Tournoi.rules(Tournoi.fetch(data, 'rules'), rules)
      @round = 0
      @placement = nil
      @strength = {}
      @rounds = [build_bracket]
    end

    def id
      return Tournoi.fetch(@data, 'id').to_s
    end

    def name
      text = Tournoi.local(Tournoi.fetch(@data, 'name'))
      return text.empty? ? Tournoi.t('Tournoi', 'Tournament') : text
    end

    def size
      return @rounds.first.size
    end

    # @return [Integer] nombre de tours
    def round_count
      return Math.log2(size).round
    end

    # Nom du tour r (Finale, Demi-finales…)
    def round_name(r = @round)
      left = round_count - r
      return Tournoi.t('Finale', 'Final') if left <= 1
      return Tournoi.t('Demi-finales', 'Semifinals') if left == 2
      return Tournoi.t('Quarts de finale', 'Quarterfinals') if left == 3

      return Tournoi.t('Huitièmes de finale', 'Round of 16')
    end

    def finished?
      return !@placement.nil?
    end

    # Ligue de Triple Triad : « participants » sont des adversaires de Triple Triad (Studio) et les matchs des duels de cartes
    def triple_triad?
      return Tournoi.fetch(@data, 'kind').to_s == 'triple_triad' && defined?(::TripleTriad) ? true : false
    end

    # @return [String] nom d'un adversaire du tableau
    def opponent_name(ref)
      return triple_triad? ? short_name(ref) : Tournoi.trainer_name(ref)
    end

    # Adversaire du joueur au tour en cours (nil : qualifié d'office)
    # @return [Entrant, nil]
    def player_opponent
      pair = current_pairs.find { |a, b| a.player? || b.player? }
      return nil unless pair

      other = pair[0].player? ? pair[1] : pair[0]
      return other.bye? ? nil : other
    end

    # @return [Array<Array<Entrant>>]
    def current_pairs
      return @rounds[@round].each_slice(2).to_a
    end

    # Joue le tour : match du joueur (gagné ou non), les autres se jouent tout seuls
    # @param player_won [Boolean]
    def play_round(player_won)
      winners = current_pairs.map do |a, b|
        next(a) if b.bye?
        next(b) if a.bye?
        next(player_won ? a : b) if a.player?
        next(player_won ? b : a) if b.player?

        simulate(a, b)
      end
      @rounds << winners
      @placement = 2**(round_count - 1 - @round) + 1 unless player_won
      @round += 1
      @placement = 1 if @placement.nil? && @round >= round_count
    end

    # @param a [Entrant]
    # @param b [Entrant]
    # @return [Entrant]
    def simulate(a, b)
      sa = strength(a)**4
      sb = strength(b)**4
      return rand * (sa + sb) < sa ? a : b
    end

    # Niveau moyen des meilleurs Pokémon du dresseur
    def strength(entrant)
      if triple_triad?
        deck = TripleTriad.deck(entrant.ref)
        return @strength[entrant.ref] ||= deck ? (deck[:min_level].to_i + (deck[:max_level] || 9).to_i) / 2.0 + 1 : 5.0
      end
      return @strength[entrant.ref] ||= begin
        levels = data_trainer(entrant.ref).party.map { |encounter| encounter.to_creature.level }.sort.reverse
        levels = levels.first(@rules['pick'].to_i)
        levels.empty? ? 1.0 : levels.sum.to_f / levels.size + 1
      rescue StandardError
        10.0
      end
    end

    private

    def build_bracket
      refs = Array(Tournoi.fetch(@data, 'participants')).map { |value| Tournoi.trainer_ref(value) }
      if triple_triad?
        refs = Array(Tournoi.fetch(@data, 'participants')).map(&:to_s).uniq.select { |ref| TripleTriad.deck(ref) }
      else
        refs = refs.compact.uniq.select { |ref| Tournoi.trainer_exists?(ref) && !data_trainer(ref).party.empty? }
      end
      entrants = refs.map { |ref| Entrant.new(:trainer, ref, short_name(ref)) }
      entrants.shuffle! if Tournoi.fetch(@data, 'shuffle') != false
      entrants = entrants.first(MAX_SIZE - 1)
      player = Entrant.new(:player, nil, $trainer.name.to_s)
      position = Tournoi.fetch(@data, 'shuffle') == false ? 0 : rand(entrants.size + 1)
      entrants.insert(position, player)
      size = 2
      size *= 2 while size < entrants.size
      pairs = size / 2
      slots = Array.new(size) { Entrant.new(:bye, nil, '—') }
      # une place vide par match au plus : les premiers remplissent un côté de chaque match, les suivants l'autre
      entrants.each_with_index do |entrant, i|
        slots[i < pairs ? i * 2 : (i - pairs) * 2 + 1] = entrant
      end
      return slots
    end

    def short_name(ref)
      return (TripleTriad.deck(ref) || {})[:name].to_s.then { |n| n.empty? ? ref.to_s : n } if triple_triad?

      name = data_trainer(ref).name.to_s
      return name.empty? ? Tournoi.trainer_name(ref) : name
    rescue StandardError
      return ref.to_s
    end
  end

  # Écran du tableau : il mène tout le tournoi (sélection, combats, résultats)
  class BracketScene < GamePlay::BaseCleanUpdate
    include TintedScene
    WHITE = 10
    TOP = 22
    AREA_H = 214
    SLOT_H = 13
    # @return [Cup]
    attr_reader :cup

    # @param cup [Cup]
    def initialize(cup)
      super()
      @cup = cup
      @flow_done = false
      @blink = 0
      @line_sprites = []
      @slot_sprites = []
      @__display_message_proc = proc { update_graphics }
    end

    def update_inputs
      return true if @flow_done

      @flow_done = true
      run
      @running = false
      return false
    end

    def update_graphics
      @bg.update
      @blink = (@blink + 1) % 40
      @blinking&.each { |sprite| sprite.opacity = @blink < 20 ? 255 : 150 }
      return true
    end

    private

    def create_viewport
      super
      create_tinted_viewports(Tournoi.tone)
    end

    def create_graphics
      super
      @bg = AnimatedLayer.new(@back_viewport, 'bg', Tournoi.setting('speed').to_f)
      @back = UI::SpriteStack.new(@back_viewport)
      @back.add_sprite(0, 0, Tournoi.file('shade'))
      @back.add_sprite(0, 2, Tournoi.file('top_bar'))
      @stack = UI::SpriteStack.new(@viewport)
      @title = @stack.add_text(4, 1, 312, 16, '', color: WHITE)
      @round_text = @stack.add_text(4, 1, 312, 16, '', 2, color: WHITE)
      Tournoi.play_bgm(Tournoi.setting('bracket_bgm'))
      refresh
    end

    # --- Dessin du tableau ----------------------------------------------------------------------------------------------
    def refresh
      @title.text = @cup.name
      @round_text.text = @cup.finished? ? '' : @cup.round_name
      (@line_sprites + @slot_sprites).each(&:dispose)
      @line_sprites = []
      @slot_sprites = []
      @blinking = []
      cols = @cup.round_count + 1
      col_w = 316 / cols
      slot_w = [col_w - 8, 110].min
      (0..@cup.round_count).each do |r|
        count = @cup.size / 2**r
        entrants = @cup.rounds[r] || Array.new(count)
        entrants.each_with_index { |entrant, k| draw_slot(entrant, r, k, count, col_w, slot_w) }
      end
      draw_lines(col_w, slot_w)
      draw_champion_label(col_w, slot_w)
    end

    def slot_pos(r, k, count, col_w)
      x = 2 + r * col_w
      y = TOP + ((k + 0.5) * AREA_H / count).round - SLOT_H / 2
      return x, y
    end

    def draw_slot(entrant, r, k, count, col_w, slot_w)
      x, y = slot_pos(r, k, count, col_w)
      out = entrant && eliminated?(entrant, r)
      state = entrant.nil? || entrant.bye? || out ? 2 : 0
      state = 1 if entrant&.player?
      body = Sprite.new(@viewport)
      body.bitmap = RPG::Cache.interface(Tournoi.file('slot'))
      body.src_rect.set(0, state * SLOT_H, slot_w - 1, SLOT_H)
      body.set_position(x, y)
      cap = Sprite.new(@viewport)
      cap.bitmap = body.bitmap
      cap.src_rect.set(149, state * SLOT_H, 1, SLOT_H)
      cap.set_position(x + slot_w - 1, y)
      @slot_sprites.push(body, cap)
      return unless entrant

      text = UI::SpriteStack.new(@viewport)
      label = text.with_font(20) { text.add_text(x + 3, y, slot_w - 5, 13, fit(entrant.name, slot_w - 6), color: WHITE) }
      label.opacity = out || entrant.bye? ? 120 : 255
      @slot_sprites << label
      return unless r == @cup.round && !@cup.finished?

      pair = @cup.current_pairs[k / 2]
      @blinking.push(body, cap) if pair&.any?(&:player?)
    end

    # Nom raccourci pour tenir dans la case
    def fit(name, width)
      max = (width / 5.2).floor
      name = name.to_s
      return name.size <= max ? name : "#{name[0, [max - 1, 1].max]}."
    end

    # L'entrant a perdu au tour r (il n'est pas au tour suivant)
    def eliminated?(entrant, r)
      following = @cup.rounds[r + 1]
      return false unless following

      return following.none? { |other| other.equal?(entrant) }
    end

    def draw_lines(col_w, slot_w)
      (0...@cup.round_count).each do |r|
        count = @cup.size / 2**r
        entrants = @cup.rounds[r] || Array.new(count)
        entrants.each_slice(2).with_index do |(a, b), m|
          xa, ya = slot_pos(r, m * 2, count, col_w)
          _xb, yb = slot_pos(r, m * 2 + 1, count, col_w)
          ya += SLOT_H / 2
          yb += SLOT_H / 2
          start_x = xa + slot_w
          mid_x = xa + slot_w + (col_w - slot_w) / 2
          end_x = xa + col_w
          winner = @cup.rounds[r + 1]&.at(m)
          lit_a = winner && a && winner.equal?(a)
          lit_b = winner && b && winner.equal?(b)
          line(start_x, ya, mid_x - start_x, 1, lit_a)
          line(start_x, yb, mid_x - start_x, 1, lit_b)
          line(mid_x, ya, 1, (yb - ya) / 2 + 1, lit_a)
          line(mid_x, ya + (yb - ya) / 2, 1, (yb - ya) - (yb - ya) / 2 + 1, lit_b)
          line(mid_x, ya + (yb - ya) / 2, end_x - mid_x, 1, winner)
        end
      end
    end

    def line(x, y, w, h, lit)
      return if w <= 0 || h <= 0

      sprite = Sprite.new(@viewport)
      sprite.bitmap = RPG::Cache.interface(Tournoi.file('pixel'))
      sprite.src_rect.set(lit ? 1 : 0, 0, 1, 1)
      sprite.set_position(x, y)
      sprite.zoom_x = w
      sprite.zoom_y = h
      @line_sprites << sprite
    end

    def draw_champion_label(col_w, slot_w)
      x, y = slot_pos(@cup.round_count, 0, 1, col_w)
      text = UI::SpriteStack.new(@viewport)
      label = text.with_font(20) { text.add_text(x, y - 14, slot_w, 13, Tournoi.t('Vainqueur', 'Winner'), 1, color: WHITE) }
      @slot_sprites << label
    end

    # --- Déroulement ----------------------------------------------------------------------------------------------------
    def run
      display_message(format(Tournoi.t('Bienvenue au tournoi « %s » !', 'Welcome to the %s!'), @cup.name))
      until @cup.finished?
        opponent = @cup.player_opponent
        refresh
        if opponent.nil?
          display_message(format(Tournoi.t('%s : vous êtes qualifié d’office pour le tour suivant !', '%s: you advance to the next round!'), @cup.round_name))
          @cup.play_round(true)
          next
        end
        display_message(format(Tournoi.t('%s : %s contre %s !', '%s: %s versus %s!'), @cup.round_name, $trainer.name, @cup.opponent_name(opponent.ref)))
        won = play_match(opponent)
        Tournoi.play_bgm(Tournoi.setting('bracket_bgm'))
        @cup.play_round(won)
        refresh
        unless won
          display_message(format(Tournoi.t('Vous êtes éliminé… (%s)', 'You have been eliminated... (%s)'), place_text(@cup.placement)))
          break
        end
        display_message(Tournoi.t('Victoire ! Vous passez au tour suivant.', 'Victory! You advance to the next round.')) unless @cup.finished?
      end
      finish
    end

    # @return [Boolean] match gagné
    def play_match(opponent)
      return play_triad_match(opponent) if @cup.triple_triad?

      rules = @cup.rules
      Tournoi.heal($actors) if rules['heal']
      unless $actors.any? { |pokemon| Tournoi.able?(pokemon) }
        display_message(Tournoi.t('Vous n’avez plus de Pokémon en état de se battre…', 'You have no Pokémon able to battle...'))
        return false
      end
      match = Match.new(opponent.ref, rules)
      team = match.select_team(self)
      return false if team.nil? || team.empty?

      match.start(self)
      return match.won?
    end

    # Ligue de Triple Triad : choix de la main puis duel ; une égalité est rejouée (3 fois au plus)
    # @return [Boolean] duel gagné
    def play_triad_match(opponent)
      extra = Array(Tournoi.fetch(@cup.data, 'triad_rules')).map(&:to_sym)
      3.times do
        result = TripleTriad.play_deck(self, opponent.ref, extra_rules: extra)
        return true if result == GamePlay::TripleTriadDuel::WIN
        return false unless result == GamePlay::TripleTriadDuel::DRAW
      end
      return false
    end

    def finish
      cup = @cup
      record = Tournoi.record(cup.id)
      record['played'] += 1
      record['last'] = cup.placement
      record['best'] = cup.placement if record['best'].to_i == 0 || cup.placement < record['best']
      if cup.placement == 1
        record['won'] += 1
        display_message(format(Tournoi.t('Félicitations ! Vous remportez le tournoi « %s » !', 'Congratulations! You won the %s!'), cup.name))
      end
      Tournoi.heal($actors) if cup.rules['heal'] && !cup.triple_triad?
      give_rewards(cup)
      switch = Tournoi.fetch(cup.data, 'switch').to_i
      $game_switches[switch] = true if switch > 0 && cup.placement == 1
      variable = Tournoi.fetch(cup.data, 'variable').to_i
      $game_variables[variable] = cup.placement if variable > 0
    end

    def give_rewards(cup)
      Array(Tournoi.fetch(cup.data, 'rewards')).each do |reward|
        place = Tournoi.fetch(reward, 'place').to_i
        next if place > 0 && cup.placement > place

        item = Tournoi.fetch(reward, 'item').to_s
        count = [Tournoi.fetch(reward, 'count').to_i, 1].max
        if Tournoi.item_exists?(item)
          $bag.add_item(item.to_sym, count)
          display_message(format(Tournoi.t('Vous recevez : %s x%d !', 'You received: %s x%d!'), Tournoi.item_name(item), count))
        end
        money = Tournoi.fetch(reward, 'money').to_i
        next if money <= 0

        PFM.game_state.add_money(money)
        display_message(format(Tournoi.t('Vous recevez %d ₽ !', 'You received $%d!'), money))
      end
    end

    def place_text(place)
      return Tournoi.t('vainqueur', 'winner') if place == 1
      return Tournoi.t('finaliste', 'finalist') if place == 2
      return Tournoi.t('demi-finaliste', 'semifinalist') if place == 3
      return Tournoi.t('quart de finaliste', 'quarterfinalist') if place == 5

      return format(Tournoi.t('%de place', 'top %d'), place)
    end
  end

  module_function

  # Lance un tournoi
  # @param id [Symbol, String]
  # @param rules [Hash] règles en plus
  # @return [Integer, nil] place du joueur (1 : vainqueur), nil si le tournoi n'existe pas
  def start_cup(id, rules = {})
    data = tournament(id)
    unless data
      log_error("Tournoi : tournoi inconnu #{id}") if respond_to?(:log_error, true)
      return nil
    end
    cup = Cup.new(data, rules)
    if !cup.triple_triad? && $actors.none? { |pokemon| able?(pokemon) }
      $scene.display_message(t('Il vous faut au moins un Pokémon en état de se battre.', 'You need at least one Pokémon able to battle.'))
      return nil
    end
    bgm = $game_system.playing_bgm
    $scene.call_scene(BracketScene, cup)
    $game_system.bgm_play(bgm) if bgm
    @last_cup = cup.id
    return cup.placement
  end

  # @return [String, nil]
  def last_cup
    return @last_cup
  end
end
