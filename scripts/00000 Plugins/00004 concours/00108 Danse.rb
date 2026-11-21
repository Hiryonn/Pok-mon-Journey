# Concours : épreuve de danse
#
# Chaque concurrent mène la danse à son tour (2 morceaux de 8 secondes chacun). Sur la première moitié du morceau,
# le danseur principal place ses pas sur le rythme ; sur la seconde, les autres doivent refaire les mêmes pas au
# même moment. Pas : saut (haut), devant (bas), gauche, droite (flèches du clavier ou touches à l'écran).
# Points : +2 par pas excellent, +1 par pas bien (le danseur principal est noté sur le rythme de ses pas).
# Chances des concurrents et du danseur principal : réglage « dance » (par rang).
module Concours
  class DanceScene < GamePlay::BaseCleanUpdate
    WHITE = 10
    DARK = 0
    RUN = 480
    HALF = 240
    FIRST_SLOT = 30
    SLOT = 15
    SLOTS = 13
    RUNS_PER_LEAD = 2
    EXCELLENT = 3
    GOOD = 7
    WINDOW = 12
    INTRO = 100
    TRACK_X = 4
    TRACK_Y = 160
    # Pas : saut, devant, gauche, droite
    MOVES = %i[jump front left right].freeze
    KEYS = { UP: :jump, DOWN: :front, LEFT: :left, RIGHT: :right }.freeze
    # Touches à l'écran : [pas, x]
    BUTTONS = [[:left, 44], [:jump, 104], [:front, 164], [:right, 224]].freeze
    BUTTON_Y = 204
    # Places : principal, puis les trois autres
    PLACES = [[160, 152, 1.0], [56, 132, 0.75], [264, 132, 0.75], [160, 104, 0.6]].freeze
    MAX_MOVES = [3, 4, 4, 5].freeze

    # @param entrants [Array<Entrant>]
    # @param rank [String]
    def initialize(entrants, rank)
      super()
      @entrants = entrants
      @rank = rank
      @run = -1
      @t = 0
      @phase = :start
      @lead_moves = []
      @targets = []
      @anims = Array.new(entrants.size) { nil }
      @notes = []
      @slides = []
      @entrants.each { |entrant| entrant.dance = 0 }
      @timing = Concours.dance_rates('timing', rank)
      @lead_rates = Concours.dance_rates('lead', rank)
    end

    def update_inputs
      case @phase
      when :start then start_dance
      when :intro then update_intro
      when :run then update_run
      when :end then end_dance
      end
      return true
    end

    def update_graphics
      update_slides
      update_anims
      update_notes
      update_buttons
      return true
    end

    def dispose
      super
      @markers&.each(&:dispose)
      @notes&.each { |note| note[:sprite].dispose }
      @top_viewport&.dispose
    end

    private

    # --- Création -----------------------------------------------------------------------------------------------------
    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport)
      @stack.add_sprite(0, 0, Concours.file('danse'))
      @dancers = @entrants.map do
        sprite = UI::PokemonFaceSprite.new(@viewport)
        @stack.push_sprite(sprite)
      end
      @entrants.each_with_index { |entrant, i| @dancers[i].data = entrant.pokemon }
      @stack.add_sprite(TRACK_X, TRACK_Y, Concours.file('piste'))
      @markers = []
      @cursor = @stack.add_sprite(TRACK_X, TRACK_Y - 4, Concours.file('curseur_danse'))
      @cursor.set_origin(2, 0)
      @cursor.z = 6
      @buttons = BUTTONS.map do |move, x|
        sprite = @stack.add_sprite(x, BUTTON_Y, Concours.file('touches'))
        sprite.src_rect.set(MOVES.index(move) * 52, 0, 52, 30)
        sprite
      end
      @pressed = Array.new(BUTTONS.size, 0)
      @title = @stack.add_text(4, 1, 312, 16, '', 0, color: WHITE)
      @score = @stack.add_text(4, 1, 312, 16, '', 2, color: WHITE)
      @top_viewport = Viewport.create(:main, @viewport.z + 1)
      @banner = UI::SpriteStack.new(@top_viewport)
      @banner_text = @banner.add_text(0, 60, 320, 16, '', 1, color: WHITE)
      place_dancers(0, false)
      Concours.play_bgm(Concours.setting('dance_bgm'))
    end

    # @return [Integer] concurrent qui mène la danse
    def lead_index
      return (@run / RUNS_PER_LEAD).clamp(0, @entrants.size - 1)
    end

    def lead
      return @entrants[lead_index]
    end

    def player_index
      return @entrants.index(&:player)
    end

    # Place les danseurs (le principal devant au milieu)
    def place_dancers(lead, slide)
      others = (0...@entrants.size).to_a.reject { |i| i == lead }
      # le Pokémon du joueur reste bien visible (au premier rang à gauche)
      others = others.partition { |i| @entrants[i].player }.flatten
      order = [lead] + others
      order.each_with_index do |index, place|
        x, y, zoom = PLACES[place]
        sprite = @dancers[index]
        sprite.z = 10 - place * 2 + (place == 0 ? 20 : 0)
        if slide
          @slides << { sprite: sprite, from: [sprite.x, sprite.y, sprite.zoom_x || 1], to: [x, y, zoom], time: 0 }
        else
          sprite.set_position(x, y)
          sprite.zoom = zoom
        end
        @anims[index] = nil
      end
    end

    def update_slides
      @slides.each do |slide|
        slide[:time] += 1
        t = (slide[:time] / 30.0).clamp(0, 1)
        from = slide[:from]
        to = slide[:to]
        slide[:sprite].set_position((from[0] + (to[0] - from[0]) * t).round, (from[1] + (to[1] - from[1]) * t).round)
        slide[:sprite].zoom = from[2] + (to[2] - from[2]) * t
      end
      @slides.reject! { |slide| slide[:time] >= 30 }
    end

    # --- Déroulé ------------------------------------------------------------------------------------------------------
    def start_dance
      display_message(Concours.t('Chacun mène la danse à son tour, pendant deux morceaux.',
                                 'Everyone takes a turn leading the dance, for two tracks each.'))
      display_message(Concours.t('Quand un autre mène, refais ses pas sur la partie rose de la piste, au même moment ! Flèches : haut pour sauter, bas pour avancer, gauche, droite.',
                                 'When someone else leads, repeat their steps on the pink part of the track, right on time! Arrows: up to jump, down to step forward, left, right.'))
      next_run
    end

    def next_run
      @run += 1
      return @phase = :end if @run >= @entrants.size * RUNS_PER_LEAD

      new_lead = (@run % RUNS_PER_LEAD).zero?
      place_dancers(lead_index, true) if new_lead && @run > 0
      @markers.each(&:dispose)
      @markers.clear
      @lead_moves = []
      @targets = []
      @t = -INTRO
      @phase = :intro
      name = lead.name
      @title.text = Concours.t("Danseur principal : #{name}", "Lead dancer: #{name}")
      @banner_text.text = if lead.player
                            Concours.t("À toi de mener la danse ! Place tes pas sur la partie bleue.",
                                       'Your turn to lead! Place your steps on the blue part.')
                          else
                            Concours.t("#{name} mène la danse !", "#{name} leads the dance!")
                          end
      @lead_moves = plan_lead unless lead.player
      refresh_score
    end

    def update_intro
      @t += 1
      @banner_text.visible = @t < -30
      Concours.play_se('040-knock01', 60) if @t >= -30 && (@t % 15).zero?
      return unless @t >= 0

      @banner_text.visible = false
      @phase = :run
    end

    def end_dance
      player = @entrants[player_index] if player_index
      display_message(Concours.t("#{Concours.setting('mc_name')} : Bravo à tous nos danseurs !",
                                 "#{Concours.setting('mc_name')}: Let's hear it for all our dancers!"))
      if player
        display_message(Concours.t("#{player.name} a obtenu #{player.dance} points de danse !",
                                   "#{player.name} earned #{player.dance} dance points!"))
      end
      @running = false
    end

    def refresh_score
      player = @entrants[player_index] if player_index
      @score.text = player ? Concours.t("Points : #{player.dance}", "Points: #{player.dance}") : ''
    end

    # --- Danseur principal (concurrent) -------------------------------------------------------------------------------
    # @return [Array<Array(Integer, Symbol)>] pas : [image du morceau, pas]
    def plan_lead
      rapid, edges, different = @lead_rates
      count = MAX_MOVES[Concours.rank_index(@rank)] - rand(2)
      slot = rand(100) < edges ? 0 : rand(0..4)
      move = MOVES.sample
      list = []
      while list.size < count && slot < SLOTS
        list << [FIRST_SLOT + slot * SLOT, move]
        slot += rand(100) < rapid ? 2 : rand(3..5)
        slot = SLOTS - 1 if list.size == count - 1 && slot < SLOTS && rand(100) < edges
        move = rand(100) < different ? (MOVES - [move]).sample : MOVES.sample
      end
      return list
    end

    # --- Morceau ------------------------------------------------------------------------------------------------------
    def update_run
      @t += 1
      @cursor.x = track_x(@t)
      Concours.play_se('040-knock01', 40) if (@t % 30).zero? && @t < RUN
      @t < HALF ? update_lead_half : update_copy_half
      return unless @t >= RUN

      @targets.each { |target| target[:done] ||= grade(target[:dancer], :miss) }
      next_run
    end

    def track_x(time)
      return TRACK_X + 2 + (time.clamp(0, RUN) * 307 / RUN)
    end

    def update_lead_half
      if lead.player
        move = pressed_move
        player_lead_step(move) if move
      else
        @lead_moves.each do |time, move|
          next unless time == @t

          perform(lead_index, move)
          add_marker(time, move)
          grade(lead_index, npc_timing)
        end
      end
      return unless @t == HALF - 1

      # cibles des autres danseurs
      @entrants.each_index do |index|
        next if index == lead_index

        @lead_moves.each { |time, move| @targets << { dancer: index, time: time + HALF, move: move, done: false } }
      end
    end

    def player_lead_step(move)
      return unless @t.between?(FIRST_SLOT - WINDOW, FIRST_SLOT + (SLOTS - 1) * SLOT + WINDOW)

      slot = ((@t - FIRST_SLOT) / SLOT.to_f).round.clamp(0, SLOTS - 1)
      time = FIRST_SLOT + slot * SLOT
      perform(lead_index, move)
      if @lead_moves.any? { |other, _| (other - time).abs < SLOT * 2 }
        return grade(lead_index, :miss)
      end

      @lead_moves << [time, move]
      add_marker(time, move)
      gap = (@t - time).abs
      grade(lead_index, gap <= EXCELLENT ? :excellent : (gap <= GOOD ? :good : :miss))
    end

    def update_copy_half
      move = pressed_move
      player_copy(move) if move && player_index != lead_index
      @targets.each do |target|
        next if target[:done]

        if target[:dancer] == player_index
          if @t > target[:time] + WINDOW
            target[:done] = true
            grade(target[:dancer], :miss)
          end
        elsif @t == target[:time]
          target[:done] = true
          npc_copy(target)
        end
      end
    end

    def player_copy(move)
      target = @targets.select { |tg| tg[:dancer] == player_index && !tg[:done] }.min_by { |tg| (tg[:time] - @t).abs }
      perform(player_index, move)
      return unless target && (target[:time] - @t).abs <= WINDOW

      target[:done] = true
      gap = (target[:time] - @t).abs
      result = if move != target[:move]
                 :miss
               elsif gap <= EXCELLENT
                 :excellent
               elsif gap <= GOOD
                 :good
               else
                 :miss
               end
      grade(player_index, result)
      light_marker(target[:time]) unless result == :miss
    end

    def npc_copy(target)
      result = npc_timing
      move = target[:move]
      if rand(100) >= @timing[2]
        result = :miss
        move = (MOVES - [move]).sample
      end
      perform(target[:dancer], move)
      grade(target[:dancer], result)
    end

    # @return [Symbol] :excellent, :good ou :miss
    def npc_timing
      roll = rand(100)
      return :excellent if roll < @timing[0]
      return :good if roll < @timing[0] + @timing[1]

      return :miss
    end

    # @return [Symbol, nil] pas demandé par le joueur (clavier ou touche à l'écran)
    def pressed_move
      KEYS.each do |key, move|
        if Input.trigger?(key)
          press_button(move)
          return move
        end
      end
      return nil unless Mouse.trigger?(:LEFT)

      BUTTONS.each_with_index do |(move, x), i|
        next unless Mouse.x.between?(x, x + 51) && Mouse.y.between?(BUTTON_Y, BUTTON_Y + 29)

        @pressed[i] = 8
        return move
      end
      return nil
    end

    def press_button(move)
      index = BUTTONS.index { |button, _| button == move }
      @pressed[index] = 8 if index
    end

    def update_buttons
      @buttons.each_with_index do |sprite, i|
        @pressed[i] -= 1 if @pressed[i] > 0
        sprite.src_rect.y = @pressed[i] > 0 ? 30 : 0
      end
    end

    # --- Pas et notes -------------------------------------------------------------------------------------------------
    def add_marker(time, move)
      [time, time + HALF].each_with_index do |at, copy|
        sprite = Sprite.new(@viewport)
        sprite.set_bitmap(Concours.file('pas'), :interface)
        sprite.src_rect.set(MOVES.index(move) * 16, 0, 16, 16)
        sprite.set_position(track_x(at) - 8, TRACK_Y + 10)
        sprite.opacity = copy == 1 ? 120 : 255
        sprite.z = 5
        @markers << sprite
      end
    end

    def light_marker(time)
      sprite = @markers.find { |marker| marker.x == track_x(time) - 8 && marker.opacity < 255 }
      sprite.opacity = 255 if sprite
    end

    def perform(index, move)
      @anims[index] = { move: move, time: 0, base: [@dancers[index].x, @dancers[index].y] } unless @anims[index]
      @anims[index][:move] = move
      @anims[index][:time] = 0
      Concours.play_se('015-jump01', 50) if move == :jump && index == player_index
    end

    def update_anims
      @anims.each_with_index do |anim, index|
        next unless anim

        anim[:time] += 1
        sprite = @dancers[index]
        wave = Math.sin(anim[:time] * Math::PI / 12)
        x, y = anim[:base]
        case anim[:move]
        when :jump then sprite.set_position(x, y - (wave * 12).round)
        when :front then sprite.set_position(x, y + (wave * 5).round)
        when :left then sprite.set_position(x - (wave * 10).round, y)
        when :right then sprite.set_position(x + (wave * 10).round, y)
        end
        next if anim[:time] < 12

        sprite.set_position(x, y)
        @anims[index] = nil
      end
    end

    # @param result [Symbol] :excellent, :good ou :miss
    def grade(index, result)
      entrant = @entrants[index]
      entrant.dance += { excellent: 2, good: 1 }[result].to_i
      image = case result
              when :excellent then 'note_excellent'
              when :good then Concours.fr? ? 'note_bien' : 'note_good'
              else Concours.fr? ? 'note_rate' : 'note_miss'
              end
      sprite = Sprite.new(@top_viewport)
      sprite.set_bitmap(Concours.file(image), :interface)
      sprite.set_origin(sprite.width / 2, sprite.height)
      sprite.zoom = 0.75 if index != lead_index
      sprite.set_position(@dancers[index].x, @dancers[index].y - (index == lead_index ? 84 : 64))
      @notes << { sprite: sprite, time: 0 }
      if index == player_index
        Concours.play_se(result == :miss ? '057-wrong01' : '055-right01', 60)
        refresh_score
      end
      return true
    end

    def update_notes
      @notes.each do |note|
        note[:time] += 1
        note[:sprite].y -= 1 if note[:time] < 10
        note[:sprite].opacity = (255 - [note[:time] - 20, 0].max * 20).clamp(0, 255)
      end
      done, @notes = @notes.partition { |note| note[:time] >= 34 }
      done.each { |note| note[:sprite].dispose }
    end
  end
end
