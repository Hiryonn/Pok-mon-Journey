# Pokéathlon : déroulement d'une coupe
#
# Choix de la coupe -> choix des 3 Pokémon -> présentation des équipes -> pour chaque épreuve : présentation, épreuve,
# classement et points -> résultat final (bonus de l'équipe première, points Pokéathlon gagnés, médailles).
# Points d'une épreuve : points de la place (rank_points) + score / score de la médaille × score_points (au plus
# le double). Tout se fait au clavier (A, B, flèches) ou à la souris.
module Pokeathlon
  module_function

  # Ouvre le Pokéathlon (choix de la coupe, ou coupe imposée)
  def open(course_id = nil)
    $scene.call_scene(GamePlay::PokeathlonScene, course_id)
  end

  # Points d'une épreuve pour une équipe
  def event_points(event_id, rank, score)
    ranks = Array(setting('rank_points')).map(&:to_i)
    points = ranks[rank].to_i
    medal = event_setting(event_id)['medal'].to_f
    return points if medal <= 0 || score.to_f <= 0

    ratio = LOWER_IS_BETTER.include?(event_id.to_s) ? medal / score.to_f : score.to_f / medal
    return points + (ratio.clamp(0, 2) * setting('score_points').to_i).round
  end

  # Équipes adverses tirées au hasard
  # @return [Array<Team>]
  def random_opponents
    list = opponents.shuffle.first(3)
    list << DEFAULT_OPPONENTS.sample while list.size < 3
    return list.each_with_index.map do |entry, i|
      pokemons = Array(fetch(entry, 'team')).first(3).map { |sp| make_pokemon(sp) }.compact
      pokemons << make_pokemon(:pikachu) while pokemons.size < 3
      Team.new(i + 1, localized(fetch(entry, 'name')), pokemons)
    end
  end

  def make_pokemon(species)
    data = data_creature(species.to_sym)
    return nil unless data && data.db_symbol != :__undef__

    return PFM::Pokemon.new(data.db_symbol, 30)
  rescue StandardError
    return nil
  end
end

module GamePlay
  class PokeathlonScene < BaseCleanUpdate
    WHITE = 9
    DARK = 0

    # @param course_id [String, nil] coupe imposée
    def initialize(course_id = nil)
      super()
      @forced_course = course_id && Pokeathlon.course(course_id)
      @courses = Pokeathlon.available_courses
      @courses = Pokeathlon.courses.first(1) if @courses.empty?
      @index = 0
      @state = nil
      @picked = []
      @party = $actors.reject(&:egg?)
      @result = nil
    end

    # @return [Hash, nil] résultat (pour les commandes d'évent) : { course:, rank:, points: }
    attr_reader :result

    def update_inputs
      case @state
      when :course then input_course
      when :team then input_team
      when :teams, :event_intro, :event_result, :final then input_next
      when :event then nil
      end
      return true
    end

    def update_graphics
      @event&.update
      if @state == :event && @event&.done?
        finish_event
      end
      @icons&.each { |icon| icon.update if icon.respond_to?(:update) }
      return true
    end

    private

    def create_graphics
      super
      @event_viewport = Viewport.create(:main, 10_000)
      @play_bgm = Pokeathlon.setting('menu_bgm').to_s
      Audio.bgm_play("audio/bgm/#{@play_bgm}") unless @play_bgm.empty?
      if @party.size < 3
        @state = :none
        build { |s| title(s, Pokeathlon.t('Pokéathlon', 'Pokéathlon')) }
        display_message(Pokeathlon.t('Il faut au moins 3 Pokémon (hors Œufs) pour participer.', 'You need at least 3 Pokémon (no Eggs) to take part.'))
        @running = false
        return
      end
      @forced_course ? start_team(@forced_course) : show_course
    end

    # --- Construction des écrans -------------------------------------------------------------------------------------
    def build
      @stack&.dispose
      @icons = []
      @stack = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @stack.add_sprite(0, 0, Pokeathlon.file('fond_menu'))
      yield(@stack)
    end

    def title(stack, text)
      stack.add_sprite(0, 0, Pokeathlon.file('titre'))
      stack.add_text(0, 4, 320, 16, text, 1, color: WHITE)
    end

    def help(stack, text)
      stack.add_sprite(0, 222, Pokeathlon.file('aide'))
      stack.with_font(20) { stack.add_text(0, 224, 320, 14, text, 1, color: WHITE) }
    end

    def icon(stack, pokemon, x, y)
      sprite = stack.push(x, y, nil, type: UI::PokemonIconSprite)
      sprite.data = pokemon
      @icons << sprite
      return sprite
    end

    # 5 étoiles : pleines (valeur), vides jusqu'au maximum de l'espèce
    def stars(stack, x, y, value, max)
      5.times do |i|
        frame = i < value ? 0 : (i < max ? 1 : 2)
        star = stack.add_sprite(x + i * 9, y, Pokeathlon.file('etoile'))
        star.src_rect.set(frame * 9, 0, 9, 9)
      end
    end

    # --- Coupe -------------------------------------------------------------------------------------------------------
    ROWS = 5

    def show_course
      @state = :course
      @top = @top.to_i
      @top = @index if @index < @top
      @top = @index - ROWS + 1 if @index >= @top + ROWS
      build do |s|
        title(s, Pokeathlon.t('Pokéathlon : choisis une coupe', 'Pokéathlon: choose a course'))
        s.add_text(220, 4, 96, 16, "#{Pokeathlon.points} pts", 2, color: WHITE)
        @course_rows = @courses[@top, ROWS].each_with_index.map do |course, i|
          y = 28 + i * 38
          bg = s.add_sprite(10, y, Pokeathlon.file('ligne'))
          sel = s.add_sprite(10, y, Pokeathlon.file('ligne_sel'))
          s.add_sprite(16, y + 7, Pokeathlon.course_icon(course))
          s.add_text(44, y + 3, 170, 16, Pokeathlon.localized(course['name']), color: DARK)
          s.with_font(20) do
            s.add_text(44, y + 19, 250, 13, course['events'].map { |e| Pokeathlon.event_name(e) }.join(' · '), color: DARK)
          end
          wins = Pokeathlon.data['wins'][course['id']].to_i
          s.add_sprite(280, y + 9, Pokeathlon.file('medaille')) if wins > 0
          [bg, sel]
        end
        if @courses.size > ROWS
          s.add_sprite(298, 23, Pokeathlon.file('fleche_haut')) if @top > 0
          s.add_sprite(298, 215, Pokeathlon.file('fleche_bas')) if @top + ROWS < @courses.size
        end
        help(s, Pokeathlon.t('A : choisir   B : quitter', 'A: choose   B: quit'))
      end
      refresh_course
    end

    def refresh_course
      @course_rows.each_with_index do |(bg, sel), i|
        sel.visible = @top + i == @index
        bg.visible = !sel.visible
      end
    end

    def input_course
      if Input.trigger?(:B) || Mouse.trigger?(:RIGHT)
        play_cancel_se
        return @running = false
      end
      if Mouse.trigger?(:LEFT)
        row = (Mouse.y - 28) / 38
        if Mouse.y >= 28 && row.between?(0, [@courses.size - @top, ROWS].min - 1) && Mouse.x.between?(10, 310)
          return start_team(@courses[@top + row]) if @top + row == @index

          @index = @top + row
          play_cursor_se
          return refresh_course
        end
      end
      return start_team(@courses[@index]) if Input.trigger?(:A)

      delta = (Input.repeat?(:DOWN) ? 1 : 0) - (Input.repeat?(:UP) ? 1 : 0)
      if delta == 0 && Mouse.respond_to?(:wheel) && Mouse.wheel.to_i != 0
        delta = Mouse.wheel > 0 ? -1 : 1
        Mouse.wheel = 0
      end
      return if delta == 0

      @index = (@index + delta) % @courses.size
      play_cursor_se
      return show_course unless @index.between?(@top, @top + ROWS - 1)

      refresh_course
    end

    # --- Équipe ------------------------------------------------------------------------------------------------------
    def start_team(course)
      play_decision_se
      @course = course
      @picked = []
      @cursor = 0
      @state = :team
      build_team
    end

    def build_team
      build do |s|
        title(s, Pokeathlon.t("#{Pokeathlon.localized(@course['name'])} : choisis 3 Pokémon", "#{Pokeathlon.localized(@course['name'])}: pick 3 Pokémon"))
        @team_rows = @party.each_with_index.map do |pk, i|
          y = 26 + i * 32
          bg = s.add_sprite(6, y, Pokeathlon.file('case'))
          sel = s.add_sprite(6, y, Pokeathlon.file('case_sel'))
          icon(s, pk, 22, y + 15)
          s.add_text(40, y + 7, 90, 16, pk.given_name, color: DARK)
          num = s.add_sprite(124, y + 8, Pokeathlon.file('numero'))
          [bg, sel, num]
        end
        s.add_sprite(152, 26, Pokeathlon.file('panneau_perf'))
        @perf_name = s.add_text(160, 30, 150, 16, '', 1, color: WHITE)
        @perf_stack = UI::SpriteStack.new(@viewport, default_cache: :interface)
        Pokeathlon::STATS.each_with_index do |stat, i|
          s.add_text(162, 52 + i * 18, 70, 16, Pokeathlon.stat_name(stat), color: WHITE)
        end
        s.with_font(20) do
          s.add_text(160, 146, 150, 13, Pokeathlon.t('Épreuves :', 'Events:'), color: WHITE)
          @course['events'].each_with_index do |e, i|
            s.add_text(160, 160 + i * 13, 150, 13, "· #{Pokeathlon.event_name(e)}", color: WHITE)
          end
        end
        help(s, Pokeathlon.t('A : choisir / retirer   START ou 3 choisis : valider   B : retour', 'A: pick / remove   START or 3 picked: confirm   B: back'))
      end
      refresh_team
    end

    def refresh_team
      @team_rows.each_with_index do |(bg, sel, num), i|
        sel.visible = i == @cursor
        bg.visible = !sel.visible
        order = @picked.index(i)
        num.visible = !order.nil?
        num.src_rect.set(order.to_i * 14, 0, 14, 14) if order
      end
      pk = @party[@cursor]
      @perf_name.text = pk.given_name
      @perf_stack.dispose
      @perf_stack = UI::SpriteStack.new(@viewport, default_cache: :interface)
      perf = Pokeathlon.performance(pk)
      species = Pokeathlon.species_performance(pk.db_symbol, pk.form)
      Pokeathlon::STATS.each_with_index do |stat, i|
        stars(@perf_stack, 240, 55 + i * 18, perf[stat], species['max'][i])
      end
    end

    def input_team
      if Input.trigger?(:B) || Mouse.trigger?(:RIGHT)
        play_cancel_se
        @perf_stack&.dispose
        return @forced_course ? (@running = false) : show_course
      end
      if Mouse.trigger?(:LEFT)
        row = (Mouse.y - 26) / 32
        if row.between?(0, @party.size - 1) && Mouse.x.between?(6, 146)
          @cursor = row
          return toggle_pick
        end
      end
      return toggle_pick if Input.trigger?(:A)
      return confirm_team if Input.trigger?(:START) && @picked.size == 3

      delta = (Input.repeat?(:DOWN) ? 1 : 0) - (Input.repeat?(:UP) ? 1 : 0)
      return if delta == 0

      @cursor = (@cursor + delta) % @party.size
      play_cursor_se
      refresh_team
    end

    def toggle_pick
      if @picked.include?(@cursor)
        @picked.delete(@cursor)
        play_cancel_se
      elsif @picked.size < 3
        @picked << @cursor
        play_decision_se
      else
        play_buzzer_se
      end
      refresh_team
      confirm_team if @picked.size == 3
    end

    def confirm_team
      names = @picked.map { |i| @party[i].given_name }.join(', ')
      choice = display_message(Pokeathlon.t("Participer avec #{names} ?", "Take part with #{names}?"), 1,
                               Pokeathlon.t('Oui', 'Yes'), Pokeathlon.t('Non', 'No'))
      return unless choice == 0

      @perf_stack&.dispose
      @perf_stack = nil
      start_course
    end

    # --- Équipes et épreuves -----------------------------------------------------------------------------------------
    def start_course
      @teams = [Pokeathlon::Team.new(0, $trainer&.name || Pokeathlon.t('Toi', 'You'), @picked.map { |i| @party[i] })] +
               Pokeathlon.random_opponents
      @totals = Array.new(4, 0)
      @event_index = 0
      @state = :teams
      build do |s|
        title(s, Pokeathlon.localized(@course['name']))
        @teams.each_with_index do |team, i|
          x = 10 + (i % 2) * 154
          y = 32 + (i / 2) * 90
          s.add_sprite(x, y, Pokeathlon.file("equipe_#{i}"))
          s.add_text(x + 6, y + 3, 136, 16, team.name, color: WHITE)
          team.athletes.each_with_index { |a, k| icon(s, a.pokemon, x + 26 + k * 46, y + 50) }
        end
        help(s, Pokeathlon.t('A : commencer', 'A: start'))
      end
    end

    def input_next
      return unless Input.trigger?(:A) || Mouse.trigger?(:LEFT)

      play_decision_se
      case @state
      when :teams then show_event_intro
      when :event_intro then start_event
      when :event_result
        @event_index += 1
        @event_index >= @course['events'].size ? show_final : show_event_intro
      when :final then @running = false
      end
    end

    def current_event_id
      return @course['events'][@event_index]
    end

    def show_event_intro
      id = current_event_id
      @state = :event_intro
      cfg = Pokeathlon.event_setting(id)
      record = Pokeathlon.data['records'][id]
      build do |s|
        title(s, "#{@event_index + 1} / #{@course['events'].size} · #{Pokeathlon.event_name(id)}")
        s.add_sprite(10, 28, Pokeathlon.file('panneau_epreuve'))
        s.add_text(20, 34, 280, 16, Pokeathlon.event_name(id), 1, color: WHITE)
        s.with_font(20) do
          lines = Pokeathlon.event_description(id).scan(/.{1,52}(?:\s|$)/).map(&:strip)
          lines.first(6).each_with_index { |l, i| s.add_text(20, 56 + i * 13, 280, 13, l, color: WHITE) }
          s.add_text(20, 140, 280, 13, Pokeathlon.t('Performances utiles : ', 'Useful stats: ') +
                     Pokeathlon::EVENT_STATS[id].map { |st| Pokeathlon.stat_name(st) }.join(', '), color: WHITE)
          s.add_text(20, 156, 280, 13, Pokeathlon.t("Durée : #{cfg['time']} s", "Time: #{cfg['time']} s"), color: WHITE)
          ev_class = Pokeathlon.event_class(id)
          fmt = ev_class ? ev_class.allocate : nil
          rec_text = record ? (fmt ? fmt.score_text(record) : record.to_s) : '--'
          s.add_text(20, 172, 280, 13, Pokeathlon.t("Record : #{rec_text}   Médaille : #{cfg['medal']}   Couronne : #{cfg['crown']}",
                                                    "Record: #{rec_text}   Medal: #{cfg['medal']}   Crown: #{cfg['crown']}"), color: WHITE)
        end
        @teams[0].athletes.each_with_index do |a, k|
          icon(s, a.pokemon, 110 + k * 50, 206)
        end
        help(s, Pokeathlon.t('A : commencer l’épreuve', 'A: start the event'))
      end
    end

    def start_event
      id = current_event_id
      klass = Pokeathlon.event_class(id)
      @stack&.dispose
      @stack = nil
      @state = :event
      bgm = Pokeathlon.setting('event_bgm').to_s
      Audio.bgm_play("audio/bgm/#{bgm}") unless bgm.empty?
      @event = klass.new(@event_viewport, @teams, id)
    end

    def finish_event
      id = current_event_id
      ranking = @event.ranking
      scores = @teams.map(&:score)
      @event.dispose
      @event = nil
      @event_points = Array.new(4, 0)
      ranking.each_with_index do |team, rank|
        pts = Pokeathlon.event_points(id, rank, team.score)
        @event_points[team.index] = pts
        @totals[team.index] += pts
      end
      new_record = record(id, scores[0])
      Audio.bgm_play("audio/bgm/#{@play_bgm}") unless @play_bgm.to_s.empty?
      show_event_result(id, ranking, scores, new_record)
    end

    # Record et médailles de l'épreuve
    def record(id, score)
      store = Pokeathlon.data
      store['events_played'][id] = store['events_played'][id].to_i + 1
      best = store['records'][id]
      return false unless Pokeathlon.better?(id, score, best)

      store['records'][id] = score
      return true
    end

    def show_event_result(id, ranking, scores, new_record)
      @state = :event_result
      fmt = Pokeathlon.event_class(id).allocate
      build do |s|
        title(s, Pokeathlon.t("Résultats : #{Pokeathlon.event_name(id)}", "Results: #{Pokeathlon.event_name(id)}"))
        ranking.each_with_index do |team, rank|
          y = 32 + rank * 40
          s.add_sprite(10, y, Pokeathlon.file("rang_#{team.index}"))
          s.add_sprite(16, y + 8, Pokeathlon.file('places')).src_rect.set(rank * 20, 0, 20, 20)
          s.add_text(42, y + 4, 120, 16, team.name, color: WHITE)
          s.add_text(160, y + 4, 70, 16, fmt.score_text(scores[team.index]), 2, color: WHITE)
          s.add_text(236, y + 4, 70, 16, "+#{@event_points[team.index]}", 2, color: WHITE)
        end
        award = Pokeathlon.award(id, scores[0])
        msg = new_record ? Pokeathlon.t('Nouveau record !', 'New record!') : ''
        msg += award == :crown ? Pokeathlon.t(' Couronne !', ' Crown!') : (award == :medal ? Pokeathlon.t(' Médaille !', ' Medal!') : '')
        s.add_text(10, 196, 300, 16, msg.strip, 1, color: WHITE)
        help(s, Pokeathlon.t('A : continuer', 'A: continue'))
      end
      Pokeathlon.play_se('cheer') if ranking.first == @teams[0]
    end

    def show_final
      @state = :final
      bonus = Pokeathlon.setting('first_bonus').to_i
      order = (0..3).sort_by { |i| [-@totals[i], i] }
      @totals[order.first] += bonus
      order = (0..3).sort_by { |i| [-@totals[i], i] }
      rank = order.index(0)
      earned = @totals[0]
      Pokeathlon.add_points(earned)
      store = Pokeathlon.data
      store['played'] += 1
      if rank == 0
        store['wins'][@course['id']] = store['wins'][@course['id']].to_i + 1
        @teams[0].athletes.each { |a| a.pokemon.athlon_medals << @course['id'] unless a.pokemon.athlon_medals.include?(@course['id']) }
      end
      @result = { course: @course['id'], rank: rank + 1, points: earned }
      build do |s|
        title(s, Pokeathlon.t('Résultat final', 'Final results'))
        order.each_with_index do |index, r|
          team = @teams[index]
          y = 32 + r * 40
          s.add_sprite(10, y, Pokeathlon.file("rang_#{index}"))
          s.add_sprite(16, y + 8, Pokeathlon.file('places')).src_rect.set(r * 20, 0, 20, 20)
          s.add_text(42, y + 4, 140, 16, team.name, color: WHITE)
          s.add_text(200, y + 4, 106, 16, "#{@totals[index]} pts", 2, color: WHITE)
        end
        s.with_font(20) do
          s.add_text(10, 194, 300, 13, Pokeathlon.t("Bonus de la première place : #{bonus}", "First place bonus: #{bonus}"), 1, color: WHITE)
          s.add_text(10, 207, 300, 13, Pokeathlon.t("Points Pokéathlon gagnés : #{earned}", "Pokéathlon points earned: #{earned}"), 1, color: WHITE)
        end
        help(s, Pokeathlon.t('A : terminer', 'A: finish'))
      end
      me = Pokeathlon.setting('win_me').to_s
      Audio.me_play("audio/me/#{me}") if rank == 0 && !me.empty?
      Pokeathlon.play_se('cheer') if rank == 0
    end

    public

    def dispose
      @event&.dispose
      @perf_stack&.dispose
      super
      @event_viewport&.dispose
    end
  end
end
