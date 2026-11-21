# Concours : épreuve de jeu d'acteur
#
# 4 prestations. À chaque tour, chaque concurrent choisit une de ses capacités et un des 3 juges (celui du milieu est
# le juge principal). La capacité rapporte ses cœurs d'attrait (0 à 3) et son effet ; si son type est celui du
# concours, l'ambiance du juge monte (5 : public en délire, +8 pour le juge principal, +5 pour les autres), si son
# type s'y oppose, elle baisse. En fin de tour, chaque juge récompense ceux qui se sont présentés à lui
# (seul : +3, à deux : +2, à trois : +1, à quatre : rien). Points : cœurs du tour × 10.
# Une capacité ne peut pas être reprise au tour suivant (sauf effet), ni trois fois de suite.
# Capacités : clé « moves » des réglages (type, cœurs, effet), sinon condition et attrait de Studio.
module Concours
  class ActingScene < GamePlay::BaseCleanUpdate
    WHITE = 10
    DARK = 0
    JUDGE_X = [64, 160, 256].freeze
    JUDGE_Y = 100
    TILE_Y = 126
    MENU_Y = 124
    LEAD = 1
    TYPE_ROWS = { 'cool' => 0, 'beauty' => 1, 'cute' => 2, 'smart' => 3, 'tough' => 4 }.freeze

    # @param entrants [Array<Entrant>]
    # @param type [String]
    # @param rank [String]
    def initialize(entrants, type, rank)
      super()
      @entrants = entrants
      @type = type
      @rank = rank
      @round = 0
      @steps = []
      @wait = 0
      @mode = nil
      @hearts_fx = []
      @jumps = {}
      @judges = Concours.judges.map { |data| data.merge('voltage' => 0, 'times' => 0) }
      @shown_voltage = [0, 0, 0]
      @entrants.each { |entrant| entrant.acting = 0 }
      @state = entrants.map { |entrant| new_state(entrant) }
      @order = (0...entrants.size).sort_by { |i| [-entrants[i].total, rand] }
      @steps << [:intro]
    end

    def update_inputs
      return true if (@wait -= 1) > 0
      return update_choice if @mode
      return true unless @hearts_fx.empty?

      until @steps.empty?
        kind, *args = @steps.shift
        run_step(kind, *args)
        return true if @wait > 0 || @mode || !@hearts_fx.empty?
      end
      @running = false
      return true
    end

    def update_graphics
      @judge_sprites&.each(&:update)
      update_jumps
      update_hearts_fx
      update_cursor_blink
      return true
    end

    def dispose
      super
      @top_viewport&.dispose
    end

    private

    # --- Données ------------------------------------------------------------------------------------------------------
    def new_state(entrant)
      moves = entrant.player ? player_moves(entrant) : npc_moves(entrant)
      return { moves: moves, move: nil, judge: nil, last: nil, two_ago: nil, hearts: 0, shown: 0 }
    end

    def player_moves(entrant)
      list = entrant.pokemon.skills_set.compact.map(&:db_symbol).reject { |sym| sym == :__undef__ }.first(4)
      return list.empty? ? [:tackle] : list
    end

    # Capacités des concurrents : réglées dans Studio, sinon tirées de ce que leur Pokémon apprend
    # (Normal, Méga : 2 du type du concours + 2 neutres ; Ultra : 2 + 1 neutre + 1 opposée ; Master : 2 + 2 opposées)
    def npc_moves(entrant)
      given = Array(entrant.moves).map(&:to_sym).reject { |sym| sym == :__undef__ }
      return given.first(4) unless given.empty?

      pool = entrant.pokemon.skills_set.compact.map(&:db_symbol)
      begin
        form = data_creature_form(entrant.pokemon.db_symbol, entrant.pokemon.form)
        pool += form.move_set.map { |learn| learn.respond_to?(:move) ? learn.move : nil }.compact
      rescue StandardError
        nil
      end
      pool = pool.map(&:to_sym).uniq.reject { |sym| sym == :__undef__ }
      groups = pool.group_by { |sym| Concours.move_relation(Concours.contest_move(sym)[0], @type) }
      wanted = case Concours.rank_index(@rank)
               when 0, 1 then { match: 2, neutral: 2 }
               when 2 then { match: 2, neutral: 1, opposed: 1 }
               else { match: 2, opposed: 2 }
               end
      list = wanted.flat_map { |kind, count| Array(groups[kind]).sample(count) }
      list += (pool - list).sample(4 - list.size) if list.size < 4
      return list.empty? ? [:tackle] : list.first(4)
    end

    def info(move)
      return Concours.contest_move(move)
    end

    def move_name(move)
      return data_move(move).name.to_s
    rescue StandardError
      return move.to_s
    end

    # @return [Array<Symbol>] capacités permises ce tour
    def allowed_moves(index)
      st = @state[index]
      list = st[:moves].dup
      last_effect = st[:last] ? info(st[:last])[2] : nil
      list.delete(st[:last]) if st[:last] && last_effect != 'can_perform_move_twice_in_a_row'
      list.delete(st[:last]) if st[:last] && st[:two_ago] == st[:last]
      return list.empty? ? st[:moves].dup : list
    end

    def player_index
      return @entrants.index(&:player)
    end

    def judge_name(judge)
      return @judges[judge]['name']
    end

    def name(index)
      return @entrants[index].name
    end

    # --- Création -----------------------------------------------------------------------------------------------------
    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport)
      @stack.add_sprite(0, 0, Concours.file('acteur'))
      @judge_sprites = @judges.each_with_index.map do |judge, i|
        sprite = @stack.push_sprite(CharsetSprite.new(@viewport, judge['charset']))
        sprite.set_position(JUDGE_X[i], JUDGE_Y)
        sprite
      end
      @volts = @judges.each_with_index.map do |judge, i|
        x = JUDGE_X[i] - 42
        @stack.add_sprite(x, JUDGE_Y, Concours.file(i == LEAD ? 'plaque_chef' : 'plaque'))
        @stack.with_font(20) { @stack.add_text(x, JUDGE_Y + 2, 84, 12, judge['name'], 1, color: DARK) }
        Array.new(5) do |k|
          cell = @stack.add_sprite(x + 15 + k * 11, JUDGE_Y + 12, Concours.file('ambiance'))
          cell.src_rect.set(0, 0, 10, 10)
          cell
        end
      end
      @tiles = @entrants.each_with_index.map { |entrant, i| create_tile(entrant, i) }
      @reactions = JUDGE_X.map do |x|
        sprite = @stack.add_sprite(x - 13, JUDGE_Y - 76, Concours.file('reactions'))
        sprite.src_rect.set(0, 0, 26, 28)
        sprite.visible = false
        sprite
      end
      @performer = UI::PokemonFaceSprite.new(@viewport)
      @performer.visible = false
      @top_viewport = Viewport.create(:main, @viewport.z + 1)
      create_menu
      refresh_tiles
      Concours.play_bgm(Concours.setting('acting_bgm'))
    end

    def create_tile(entrant, i)
      x = i * 80
      tile = {}
      tile[:back] = @stack.add_sprite(x, TILE_Y, Concours.file(entrant.player ? 'tuile_joueur' : 'tuile'))
      icon = UI::PokemonIconSprite.new(@viewport)
      icon.data = entrant.pokemon
      icon.set_position(x + 20, TILE_Y + 24)
      tile[:icon] = @stack.push_sprite(icon)
      @stack.with_font(20) do
        tile[:name] = @stack.add_text(x + 2, TILE_Y + 2, 76, 12, entrant.name, 1, color: DARK)
        tile[:order] = @stack.add_text(x + 38, TILE_Y + 14, 38, 12, '', 2, color: DARK)
        tile[:hearts] = @stack.add_text(x + 46, TILE_Y + 24, 30, 12, '', 2, color: DARK)
        tile[:score] = @stack.add_text(x + 38, TILE_Y + 34, 38, 12, '', 2, color: DARK)
      end
      tile[:heart] = @stack.add_sprite(x + 56, TILE_Y + 27, Concours.file('coeur'))
      return tile
    end

    def refresh_tiles
      @tiles.each_with_index do |tile, i|
        place = @order.index(i)
        tile[:order].text = place ? Concours.t("n° #{place + 1}", "No. #{place + 1}") : ''
        tile[:hearts].text = @state[i][:shown].to_s
        tile[:score].text = Concours.t("#{@entrants[i].acting} pts", "#{@entrants[i].acting} pts")
      end
      @volts.each_with_index do |cells, j|
        cells.each_with_index { |cell, k| cell.src_rect.x = k < @shown_voltage[j] ? 10 : 0 }
      end
    end

    def create_menu
      @menu = UI::SpriteStack.new(@top_viewport)
      @menu.add_sprite(0, MENU_Y, Concours.file('menu_capacites'))
      @menu_title = @menu.add_text(6, MENU_Y + 3, 308, 16, '', 0, color: WHITE)
      @move_tiles = Array.new(4) do |i|
        x = 4 + (i % 2) * 158
        y = MENU_Y + 20 + (i / 2) * 34
        back = @menu.add_sprite(x, y, Concours.file('capacites'))
        back.src_rect.set(0, 0, 154, 34)
        text = @menu.add_text(x + 6, y + 2, 142, 16, '', 0, color: WHITE)
        kind = @menu.with_font(20) { @menu.add_text(x + 70, y + 19, 78, 12, '', 2, color: DARK) }
        hearts = Array.new(3) { |k| @menu.add_sprite(x + 9 + k * 9, y + 21, Concours.file('coeur')) }
        { back: back, text: text, kind: kind, hearts: hearts, x: x, y: y }
      end
      @move_cursor = @menu.add_sprite(0, 0, Concours.file('curseur_capacite'))
      @effect_text = @menu.with_font(20) { @menu.add_text(10, MENU_Y + 89, 300, 12, '', 0, color: DARK) }
      @effect_text2 = @menu.with_font(20) { @menu.add_text(10, MENU_Y + 100, 300, 12, '', 0, color: DARK) }
      @menu.visible = false
      @judge_ui = UI::SpriteStack.new(@top_viewport)
      @judge_cursor = @judge_ui.add_sprite(0, JUDGE_Y - 62, Concours.file('curseur_juge'))
      @judge_text = @judge_ui.add_text(0, 190, 320, 16, '', 1, color: DARK)
      @judge_ui.visible = false
    end

    # --- Choix du joueur ----------------------------------------------------------------------------------------------
    def start_choice
      index = player_index
      return finish_choice if index.nil?

      @allowed = allowed_moves(index)
      @moves = @state[index][:moves]
      @move_index = @moves.index(@allowed.first) || 0
      @menu.visible = true
      @menu_title.text = if @round < 3
                           Concours.t("Prestation n° #{@round + 1} ! Quelle capacité ?", "Performance no. #{@round + 1}! Which move?")
                         else
                           Concours.t('Dernière prestation ! Choisis bien !', "It's the last performance! Choose your move!")
                         end
      @move_tiles.each_with_index do |tile, i|
        move = @moves[i]
        visible = !move.nil?
        [tile[:back], tile[:text], tile[:kind], *tile[:hearts]].each { |sprite| sprite.visible = visible }
        next unless move

        kind, appeal, = info(move)
        row = @allowed.include?(move) ? TYPE_ROWS[kind] || 0 : 5
        tile[:back].src_rect.y = row * 34
        tile[:text].text = move_name(move)
        relation = { match: ' (+)', opposed: ' (-)' }[Concours.move_relation(kind, @type)].to_s
        tile[:kind].text = Concours.type_name(kind) + relation
        tile[:hearts].each_with_index { |heart, k| heart.visible = k < appeal }
      end
      @mode = :move
      refresh_move_cursor
    end

    def refresh_move_cursor
      tile = @move_tiles[@move_index]
      @move_cursor.set_position(tile[:x] - 2, tile[:y] - 2)
      move = @moves[@move_index]
      effect = info(move)[2]
      text = Concours.effect_text(effect)
      text = Concours.t('Déjà présentée au tour précédent.', 'Already performed last turn.') unless @allowed.include?(move)
      line1, line2 = wrap(text, 60)
      @effect_text.text = line1.to_s
      @effect_text2.text = line2.to_s
    end

    def wrap(text, width)
      lines = ['']
      text.split(' ').each do |word|
        if (lines.last + ' ' + word).strip.size > width
          lines << word
        else
          lines[-1] = (lines.last + ' ' + word).strip
        end
      end
      return lines
    end

    def update_choice
      @mode == :move ? update_move_choice : update_judge_choice
      return true
    end

    def update_move_choice
      if Mouse.trigger?(:LEFT) || mouse_moved?
        hit = @move_tiles.index { |tile| Mouse.x.between?(tile[:x], tile[:x] + 153) && Mouse.y.between?(tile[:y], tile[:y] + 33) }
        if hit && @moves[hit] && hit != @move_index
          @move_index = hit
          play_cursor_se
          refresh_move_cursor
        end
        return confirm_move if hit && Mouse.trigger?(:LEFT)
      end
      size = @moves.size
      if Input.trigger?(:LEFT) || Input.trigger?(:RIGHT)
        target = @move_index ^ 1
        move_cursor_to(target) if target < size
      elsif Input.trigger?(:UP) || Input.trigger?(:DOWN)
        target = (@move_index + 2) % 4
        move_cursor_to(target) if target < size
      elsif Input.trigger?(:A)
        confirm_move
      end
    end

    def move_cursor_to(index)
      play_cursor_se
      @move_index = index
      refresh_move_cursor
    end

    def confirm_move
      move = @moves[@move_index]
      return play_buzzer_se unless @allowed.include?(move)

      Concours.play_se('concours_choix')
      @state[player_index][:move] = move
      @menu.visible = false
      @judge_index ||= LEAD
      @judge_text.text = Concours.t("#{move_name(move)} : à quel juge ? (B : retour)", "#{move_name(move)}: to which Judge? (B: back)")
      @judge_ui.visible = true
      @mode = :judge
      refresh_judge_cursor
    end

    def refresh_judge_cursor
      @judge_cursor.x = JUDGE_X[@judge_index] - 22
    end

    def update_judge_choice
      hit = JUDGE_X.index { |x| Mouse.x.between?(x - 30, x + 30) && Mouse.y.between?(JUDGE_Y - 60, JUDGE_Y + 24) }
      if hit && (mouse_moved? || Mouse.trigger?(:LEFT)) && hit != @judge_index
        @judge_index = hit
        play_cursor_se
        refresh_judge_cursor
      end
      return confirm_judge if hit && Mouse.trigger?(:LEFT)
      return back_to_moves if Input.trigger?(:B) || Mouse.trigger?(:RIGHT)

      if Input.trigger?(:LEFT)
        @judge_index = (@judge_index - 1) % 3
        play_cursor_se
        refresh_judge_cursor
      elsif Input.trigger?(:RIGHT)
        @judge_index = (@judge_index + 1) % 3
        play_cursor_se
        refresh_judge_cursor
      elsif Input.trigger?(:A)
        confirm_judge
      end
    end

    def back_to_moves
      play_cancel_se
      @judge_ui.visible = false
      @menu.visible = true
      @mode = :move
    end

    def confirm_judge
      Concours.play_se('concours_choix')
      @state[player_index][:judge] = @judge_index
      @judge_ui.visible = false
      @mode = nil
      finish_choice
    end

    def mouse_moved?
      position = [Mouse.x, Mouse.y]
      moved = @last_mouse && @last_mouse != position
      @last_mouse = position
      return moved ? true : false
    end

    def update_cursor_blink
      return unless @judge_cursor && @mode == :judge

      @blink = (@blink.to_i + 1) % 40
      @judge_cursor.opacity = @blink < 20 ? 255 : 150
    end

    # --- Choix des concurrents ----------------------------------------------------------------------------------------
    def finish_choice
      @entrants.each_index do |i|
        next if @entrants[i].player

        @state[i][:move] = ai_move(i)
        @state[i][:judge] = ai_judge(i)
      end
      plan_round
    end

    def ai_move(index)
      allowed = allowed_moves(index)
      if @order.first == index && @judges.any? { |judge| judge['voltage'] == 4 }
        matching = allowed.select { |move| Concours.move_relation(info(move)[0], @type) == :match }
        return matching.sample unless matching.empty?
      end
      return allowed.sample
    end

    def ai_judge(index)
      move = @state[index][:move]
      if Concours.move_relation(info(move)[0], @type) == :match
        hot = (0...3).select { |j| @judges[j]['voltage'] == 4 }
        return hot.sample unless hot.empty?
      end
      taken = player_index ? @state[player_index][:judge] : nil
      if taken && rand(100) < Concours.acting_avoid(@rank)
        return ([0, 1, 2] - [taken]).sample
      end

      return rand(3)
    end

    # --- Un tour ------------------------------------------------------------------------------------------------------
    def plan_round
      @prevent_up = @prevent_down = false
      @prev_up = @this_up = nil
      @peak_prev = nil
      @next_first = @next_last = nil
      @shuffle_next = false
      @judges.each { |judge| judge['times'] = 0 }
      @state.each do |st|
        st[:hearts] = 0
        st[:chose] = nil
      end
      @order.each_with_index { |index, turn| perform(index, turn + 1) }
      end_round
    end

    def add_hearts(index, count)
      return if count <= 0

      @state[index][:hearts] += count
      @steps << [:hearts, index, count]
    end

    def msg(text)
      @steps << [:msg, text]
    end

    def bonus(value)
      return Concours.t("+#{value} !", "+#{value}!")
    end

    # @param index [Integer] concurrent
    # @param turn [Integer] ordre de passage (1 à 4)
    def perform(index, turn)
      st = @state[index]
      move = st[:move]
      judge = st[:judge]
      kind, appeal, effect = info(move)
      already = @state.any? { |other| other[:chose] == judge }
      st[:chose] = judge
      @judges[judge]['times'] += 1
      performer = name(index)
      @steps << [:show, index, judge]
      msg(Concours.t("À #{judge_name(judge)}, #{performer} présente #{move_name(move)} !",
                     "To #{judge_name(judge)}, #{performer} performed #{move_name(move)}!"))
      if effect == 'plus_3_if_no_pokemon_chose_judge'
        msg(Concours.t("Si #{performer} est seul à choisir ce juge : #{bonus(3)}",
                       "If #{performer}'s move stands out and doesn't share the same Judge with another Pokémon: +3!"))
      end
      if already
        @steps << [:react, judge, 1, :shudder]
        msg(Concours.t('Oh non ! Quelqu’un s’est déjà présenté à ce juge !', 'Oh, no! Someone already performed for that Judge!'))
      else
        @steps << [:react, judge, 0, :jump]
      end
      add_hearts(index, appeal)
      after_move_effect(index, turn, effect, judge)
      last_effect = st[:last] ? info(st[:last])[2] : nil
      if last_effect == 'double_score_next_turn' && st[:hearts] > 0
        msg(Concours.t("Grâce au tour précédent, #{performer} gagne +#{st[:hearts]} !",
                       "From the previous turn, #{performer} gets +#{st[:hearts]}!"))
        add_hearts(index, st[:hearts])
      end
      @peak_prev = nil
      voltage_reaction(index, judge, kind)
      after_voltage_effect(index, effect)
      st[:two_ago] = st[:last]
      st[:last] = move
      @steps << [:wait, 20] << [:hide]
    end

    def order_word(turn)
      return Concours.t(%w[premier deuxième troisième quatrième][turn - 1], %w[first second third fourth][turn - 1])
    end

    def after_move_effect(index, turn, effect, judge)
      st = @state[index]
      performer = name(index)
      voltage = @judges[judge]['voltage']
      case effect
      when 'random_order'
        @shuffle_next = true
        msg(Concours.t('L’ordre de passage du prochain tour sera tiré au sort !', 'The order of the next turn will be shuffled!'))
      when 'next_1'
        @next_first = index
        @next_last = nil if @next_last == index
        msg(Concours.t("#{performer} passera en premier au prochain tour.", "#{performer} will perform first the next turn."))
      when 'next_4'
        @next_last = index
        @next_first = nil if @next_first == index
        msg(Concours.t("#{performer} passera en dernier au prochain tour.", "#{performer} will perform last the next turn."))
      when 'plus_2_if_first'
        if turn == 1
          msg(Concours.t("Première prestation ! #{bonus(2)}", 'First performance! +2!'))
          add_hearts(index, 2)
        end
      when 'plus_2_if_last'
        if turn == 4
          msg(Concours.t("Dernière prestation ! #{bonus(2)}", 'Last performance! +2!'))
          add_hearts(index, 2)
        end
      when 'can_perform_move_twice_in_a_row'
        if st[:two_ago] != st[:last] || st[:last].nil?
          msg(Concours.t("#{performer} pourra refaire cette capacité !", "#{performer} can perform the same move twice!"))
        end
      when 'increased_voltage_added_to_score'
        if voltage > 0
          msg(Concours.t("L’ambiance s’ajoute aux points ! +#{voltage} !", "The Voltage score is added on! +#{voltage}!"))
          add_hearts(index, voltage)
        end
      when 'prevent_voltage_down_same_turn'
        unless @prevent_down
          @prevent_down = true
          msg(Concours.t('L’ambiance ne peut plus baisser pendant ce tour !', 'The Voltage is prevented from falling!'))
        end
      when 'prevent_voltage_up_same_turn'
        unless @prevent_up
          @prevent_up = true
          msg(Concours.t('L’ambiance ne peut plus monter pendant ce tour !', 'The Voltage is prevented from rising!'))
        end
      when 'higher_score_the_later_performs', 'points_equal_to_order'
        msg(Concours.t("#{performer} passe en #{order_word(turn)} ! +#{turn} !", "#{performer}'s performance is #{order_word(turn)}! +#{turn}!"))
        add_hearts(index, turn)
      when 'lower_voltage_of_all_judges_1'
        unless @prevent_down
          msg(Concours.t('L’ambiance de tous les juges baisse !', 'The Voltage of all the Judges went down!'))
          @judges.each_with_index do |data, j|
            next if data['voltage'] <= 0

            data['voltage'] -= 1
            @steps << [:voltage, j, data['voltage']]
          end
        end
      when 'raise_score_if_voltage_low'
        points = (4 - voltage).abs
        msg(Concours.t("Ambiance basse, plus de points ! +#{points} !", "Higher score earned for low Voltage! +#{points}!"))
        add_hearts(index, points)
      when 'double_score_if_final_turn'
        if turn == 4 && st[:hearts] > 0
          msg(Concours.t("#{performer} passe en dernier ! +#{st[:hearts]} !", "#{performer} performed last! +#{st[:hearts]}!"))
          add_hearts(index, st[:hearts])
        end
      when 'steal_voltage_previous_pokemon'
        if @peak_prev == judge
          previous = name(@order[turn - 2])
          points = judge == LEAD ? 8 : 5
          msg(Concours.t("#{performer} obtient la même note que #{previous} ! +#{points} !",
                         "#{performer} got the same rating as #{previous}, who went before! +#{points}!"))
          add_hearts(index, points)
        end
      when 'plus_3_if_previous_pokemon_hit_max_voltage'
        if @peak_prev
          msg(Concours.t("La prestation suit une ambiance au maximum ! #{bonus(3)}", 'The performance came after the Voltage peaked! +3!'))
          add_hearts(index, 3)
        end
      end
    end

    def voltage_reaction(index, judge, kind)
      @prev_up = @this_up
      @this_up = nil
      data = @judges[judge]
      type_name = Concours.type_name(kind)
      case Concours.move_relation(kind, @type)
      when :match
        return if @prevent_up

        data['voltage'] += 1
        @this_up = judge
        @steps << [:react, judge, 2, :high] << [:se, 'concours_foule']
        msg(Concours.t("Devant cette capacité #{type_name}, l’ambiance de #{judge_name(judge)} monte !",
                       "Upon seeing the #{type_name} move performed, #{judge_name(judge)}'s Voltage went up!"))
        @steps << [:voltage, judge, data['voltage']]
        msg(Concours.t('Le public est de plus en plus enthousiaste !', 'The audience is getting pretty excited!')) if data['voltage'] == 4
        return if data['voltage'] < 5

        points = judge == LEAD ? 8 : 5
        msg(Concours.t("Le public est en délire ! +#{points} !", "The audience is going wild with excitement! +#{points}!"))
        add_hearts(index, points)
        data['voltage'] = 0
        @steps << [:voltage, judge, 0]
        @peak_prev = judge
      when :opposed
        return if @prevent_down || data['voltage'] <= 0

        data['voltage'] -= 1
        @steps << [:react, judge, 1, :shudder]
        msg(Concours.t("Devant cette capacité #{type_name}, l’ambiance de #{judge_name(judge)} baisse...",
                       "Upon seeing the #{type_name} move performed, #{judge_name(judge)}'s Voltage went down!"))
        @steps << [:voltage, judge, data['voltage']]
      end
    end

    def after_voltage_effect(index, effect)
      case effect
      when 'plus_3_if_2_voltage_in_a_row'
        if @this_up && @prev_up == @this_up
          msg(Concours.t("L’ambiance monte deux fois de suite ! #{bonus(3)}", 'The Voltage went up consecutively! +3!'))
          add_hearts(index, 3)
        end
      when 'plus_2_if_voltage_up'
        if @this_up
          msg(Concours.t("Le public est conquis ! #{bonus(2)}", 'It excited the audience! +2!'))
          add_hearts(index, 2)
        end
      end
    end

    def end_round
      # bonus des juges
      3.times do |judge|
        list = @order.select { |i| @state[i][:chose] == judge }
        names = list.map { |i| name(i) }
        case list.size
        when 1
          @steps << [:react, judge, 2, :high]
          msg(Concours.t("#{judge_name(judge)} a été très impressionné par #{names[0]} ! +3 !",
                         "#{judge_name(judge)} was very impressed by #{names[0]}'s performance! +3!"))
          add_hearts(list[0], 3)
        when 2
          @steps << [:react, judge, 0, :jump]
          msg(Concours.t("#{judge_name(judge)} a été conquis par #{names[0]} et #{names[1]} ! +2 !",
                         "#{judge_name(judge)} was strongly impressed by the acting of #{names[0]} and #{names[1]}! +2!"))
          list.each { |i| add_hearts(i, 2) }
        when 3
          @steps << [:react, judge, 0, :jump]
          msg(Concours.t("#{judge_name(judge)} a apprécié #{names[0]}, #{names[1]} et #{names[2]} ! +1 !",
                         "#{judge_name(judge)} was impressed by the performances of #{names[0]}, #{names[1]}, and #{names[2]}! +1!"))
          list.each { |i| add_hearts(i, 1) }
        when 4
          @steps << [:react, judge, 1, :shudder]
          msg(Concours.t("Tout le monde s’est présenté à #{judge_name(judge)}... Ça gâche un peu l’effet.",
                         "Everyone performed for #{judge_name(judge)}... And watered down the Judge's impressions."))
        end
      end
      # effets de fin de tour
      @order.each do |i|
        effect = info(@state[i][:move])[2]
        judge = @state[i][:chose]
        if effect == 'plus_3_if_no_pokemon_chose_judge'
          if @judges[judge]['times'] > 1
            msg(Concours.t("#{name(i)} a choisi le même juge qu’un autre Pokémon... +0.",
                           "#{name(i)} chose the same Judge as another Pokémon! The performance didn't stand out! +0!"))
          else
            msg(Concours.t("#{name(i)} est le seul à avoir choisi ce juge ! +3 !",
                           "#{name(i)} didn't pick the same Judge as anyone else! The performance stood out! +3!"))
            add_hearts(i, 3)
          end
        elsif effect == 'plus_15_if_all_chose_same_judge' && @judges[judge]['times'] >= 4
          msg(Concours.t("#{name(i)} a choisi le même juge que tout le monde ! +15 !",
                         "#{name(i)} chose the same Judge as everyone! +15!"))
          add_hearts(i, 15)
        end
      end
      @order.each do |i|
        next unless info(@state[i][:move])[2] == 'plus_3_if_get_lowest_score'
        next unless @state.all? { |other| @state[i][:hearts] <= other[:hearts] }

        msg(Concours.t("#{name(i)} a le moins de points ! +3 !", "#{name(i)} has the lowest score! +3!"))
        add_hearts(i, 3)
      end
      @steps << [:tally]
      @round += 1
      if @round < 4
        msg(Concours.t('Au prochain tour, les concurrents qui ont le moins de points passeront en premier.',
                       'In the next turn, the lowest-scoring contestants will perform first.'))
        @steps << [:next_round] << [:choose]
      else
        @steps << [:se, 'concours_sifflet']
        msg(Concours.t('Et voilà ! L’épreuve de jeu d’acteur est terminée !', "That's it! Performance judging is now over!"))
      end
    end

    # Points du tour et ordre du suivant
    def tally
      @state.each_with_index do |st, i|
        @entrants[i].acting = @entrants[i].acting.to_i + st[:hearts] * 10
      end
      index = player_index
      return unless index

      hearts = @state[index][:hearts]
      text = if hearts <= 6
               Concours.t("#{name(index)} a attiré l’attention.", "#{name(index)} attracted decent attention.")
             elsif hearts <= 12
               Concours.t("#{name(index)} a attiré beaucoup d’attention !", "#{name(index)} attracted a lot of attention!")
             else
               Concours.t("#{name(index)} a captivé tout le public !", "#{name(index)} commanded total attention!")
             end
      @steps.unshift([:msg, text])
    end

    def next_order
      order = (0...@entrants.size).sort_by { |i| [@entrants[i].total, rand] }
      order.shuffle! if @shuffle_next
      if @next_first
        order.delete(@next_first)
        order.unshift(@next_first)
      end
      if @next_last
        order.delete(@next_last)
        order.push(@next_last)
      end
      @order = order
      @state.each do |st|
        st[:shown] = 0
        st[:hearts] = 0
      end
    end

    # --- Étapes affichées ---------------------------------------------------------------------------------------------
    def run_step(kind, *args)
      case kind
      when :intro then intro
      when :choose then start_choice
      when :wait then @wait = args[0].to_i
      when :msg then display_message(args[0].to_s)
      when :se then Concours.play_se(args[0])
      when :show then show_performer(*args)
      when :hide then @performer.visible = false
      when :react then react(*args)
      when :hearts then show_hearts(*args)
      when :voltage then set_voltage(*args)
      when :tally
        tally
        refresh_tiles
        Concours.play_se('concours_total')
      when :next_round
        next_order
        refresh_tiles
      end
    end

    def intro
      display_message(Concours.t("Montrez des capacités de type #{Concours.type_name(@type)} !",
                                 "Show off the moves that exemplify #{Concours.type_name(@type).downcase}!"))
      display_message(Concours.t('Quatre prestations chacun ! Choisis une capacité, puis le juge à qui la présenter. Les capacités du type du concours font monter l’ambiance (+), celles du type opposé la font baisser (-).',
                                 'Four performances each! Choose a move, then the Judge to perform it for. Moves of the Contest type raise the Voltage (+), opposing types lower it (-).'))
      @steps.unshift([:choose])
    end

    def show_performer(index, judge)
      @performer.data = @entrants[index].pokemon
      @performer.zoom = 0.8
      @performer.set_position(JUDGE_X[judge], JUDGE_Y + 28)
      @performer.z = 50
      @performer.visible = true
      @performer.update if @performer.respond_to?(:update)
      Concours.play_se('concours_foule', 60)
      @current = index
    end

    # @param frame [Integer] 0 : sourire, 1 : grimace, 2 : étoile
    def react(judge, frame, motion)
      sprite = @reactions[judge]
      sprite.src_rect.x = frame * 26
      sprite.visible = true
      @jumps[judge] = { time: 0, motion: motion }
      Concours.play_se(motion == :shudder ? '057-wrong01' : '015-jump01', 60)
      @wait = 24
    end

    def update_jumps
      @jumps.each do |judge, jump|
        jump[:time] += 1
        sprite = @judge_sprites[judge]
        case jump[:motion]
        when :shudder then sprite.x = JUDGE_X[judge] + (Math.sin(jump[:time] * 1.3) * 3).round
        when :high then sprite.y = JUDGE_Y - (Math.sin(jump[:time] * Math::PI / 24) * 14).abs.round
        else sprite.y = JUDGE_Y - (Math.sin(jump[:time] * Math::PI / 12) * 6).abs.round
        end
        next if jump[:time] < 24

        sprite.set_position(JUDGE_X[judge], JUDGE_Y)
        @reactions[judge].visible = false
      end
      @jumps.reject! { |_, jump| jump[:time] >= 24 }
    end

    def set_voltage(judge, value)
      @shown_voltage[judge] = value
      Concours.play_se(value > 0 ? '055-right01' : '057-wrong01', 50)
      refresh_tiles
      @wait = 16
    end

    # Cœurs qui montent du Pokémon vers sa tuile
    def show_hearts(index, count)
      x = @performer.visible ? @performer.x : index * 80 + 40
      count.times do |k|
        sprite = Sprite.new(@top_viewport)
        sprite.set_bitmap(Concours.file('coeur_rouge'), :interface)
        sprite.set_origin(sprite.width / 2, sprite.height / 2)
        sprite.set_position(x + rand(-16..16), JUDGE_Y + 10)
        sprite.visible = false
        @hearts_fx << { sprite: sprite, time: -k * 5, index: index, target: [index * 80 + 44, TILE_Y + 30] }
      end
    end

    def update_hearts_fx
      @hearts_fx.each do |fx|
        fx[:time] += 1
        next if fx[:time] <= 0

        sprite = fx[:sprite]
        sprite.visible = true
        Concours.play_se('concours_coeur', 70) if fx[:time] == 1
        t = (fx[:time] / 20.0).clamp(0, 1)
        sprite.y -= 1 if fx[:time] < 8
        if fx[:time] >= 8
          sprite.x += ((fx[:target][0] - sprite.x) * t * 0.5).round
          sprite.y += ((fx[:target][1] - sprite.y) * t * 0.5).round
        end
        next unless fx[:time] == 24

        @state[fx[:index]][:shown] += 1
        @tiles[fx[:index]][:hearts].text = @state[fx[:index]][:shown].to_s
      end
      done, @hearts_fx = @hearts_fx.partition { |fx| fx[:time] >= 24 }
      done.each { |fx| fx[:sprite].dispose }
    end
  end
end

