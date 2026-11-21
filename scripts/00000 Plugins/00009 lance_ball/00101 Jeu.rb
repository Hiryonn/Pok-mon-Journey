# Lance-Ball : la partie
module GamePlay
  class LanceBallScene < BaseCleanUpdate
    WHITE = 9
    DARK = 0
    # cachettes : [x, y (pied), :bush / :tree]
    SPOTS = [[46, 92, :bush], [118, 78, :tree], [204, 86, :bush], [278, 100, :tree], [74, 156, :tree], [164, 140, :bush],
             [252, 168, :bush], [300, 150, :bush]].freeze
    FIELD = [14, 54, 306, 200].freeze
    REST = [160, 222].freeze   # balle posée sur le lance-balle
    FLIGHT = 26                # durée du vol
    HIT = 13                   # rayon de capture
    NEAR = 28                  # rayon d'étourdissement

    attr_reader :result

    def initialize(count = nil)
      super()
      @count = (count || LanceBall.setting('count')).to_i.clamp(1, 6)
      @difficulty = LanceBall.setting('difficulty').to_i.clamp(1, 3)
      @state = :intro
      @frame = 0
      @result = nil
    end

    def update_inputs
      case @state
      when :title then input_title
      when :results then input_results
      end
      return true
    end

    def update_graphics
      @frame += 1
      case @state
      when :intro then update_intro
      when :play then update_play
      when :over then update_over
      end
      return true
    end

    private

    def create_graphics
      super
      bgm = LanceBall.setting('bgm').to_s
      Audio.bgm_play("audio/bgm/#{bgm}") unless bgm.empty?
      show_title
    end

    def reset_stack
      @stack&.dispose
      @stack = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @stack.add_sprite(0, 0, LanceBall.file('fond'))
    end

    def sprite(name, x, y, z = 0, cell: nil)
      sp = @stack.add_sprite(x, y, LanceBall.file(name))
      sp.z = z
      if cell
        sp.src_rect.set(cell[0] * 32, cell[1] * 32, 32, 32)
        sp.set_origin(16, 16)
      end
      return sp
    end

    # --- Accueil ----------------------------------------------------------------------------------------------------
    def show_title
      @state = :title
      reset_stack
      sprite('panneau', 32, 40, 10)
      t = @stack.add_text(32, 52, 256, 16, LanceBall.t('Lance-Ball', 'Ball Launch'), 1, color: WHITE)
      t.z = 11
      lines = LanceBall.t(["#{@count} Pokémon se cachent dans le pré.", 'Flèches / souris : viser   A / clic : lancer',
                           'Touché quand il se montre : capturé !', 'Une balle sur une cachette le fait sortir.'],
                          ["#{@count} Pokémon are hiding in the meadow.", 'Arrows / mouse: aim   A / click: throw',
                           'Hit one while it shows up to catch it!', 'A ball on a hiding spot makes it come out.'])
      @stack.with_font(20) do
        lines.each_with_index { |line, i| @stack.add_text(46, 76 + i * 14, 228, 13, line, color: WHITE).z = 11 }
        @stack.add_text(46, 140, 228, 13, LanceBall.t("Record : #{LanceBall.data['record']} points", "High score: #{LanceBall.data['record']} points"), color: WHITE).z = 11
        @stack.add_text(46, 162, 228, 13, LanceBall.t('A : commencer   B : quitter', 'A: start   B: quit'), 1, color: WHITE).z = 11
      end
      @stack.add_sprite(64, 196, LanceBall.file('lanceur')).z = 5
    end

    def input_title
      if Input.trigger?(:B) || Mouse.trigger?(:RIGHT)
        play_cancel_se
        return @running = false
      end
      return unless Input.trigger?(:A) || Mouse.trigger?(:LEFT)

      play_decision_se
      start_game
    end

    # --- Partie -----------------------------------------------------------------------------------------------------
    def start_game
      reset_stack
      @spots = SPOTS.map do |x, y, kind|
        spot = { x: x, y: y, kind: kind, shake: 0 }
        if kind == :tree
          spot[:sprite] = sprite('cachettes', x, y - 14, y, cell: [0, 2])
          spot[:top] = sprite('cachettes', x, y - 38, y + 1, cell: [0, 1])
        else
          spot[:sprite] = sprite('cachettes', x, y - 14, y, cell: [0, 0])
        end
        spot
      end
      free = (0...@spots.size).to_a.shuffle
      @mons = LanceBall.make_pokemon(@count).each_with_index.map do |pk, i|
        sp = @stack.push_sprite(::Sprite.new(@viewport))
        sp.bitmap = RPG::Cache.character(pk.character_name) rescue RPG::Cache.character('000')
        fw = sp.bitmap.width / 4
        fh = sp.bitmap.height / 4
        sp.set_origin(fw / 2, fh - 2)
        sp.visible = false
        fx = sprite('etoiles', 0, 0, 900, cell: [0, 0])
        fx.visible = false
        { pokemon: pk, sprite: sp, fw: fw, fh: fh, fx: fx, spot: free[i % free.size], state: :hidden,
          timer: rand(40..140) + i * 20, x: 0.0, y: 0.0, tx: 0, ty: 0, dir: 0, step: 0.0 }
      end
      @mons.each { |m| place_hidden(m) }
      @launcher = @stack.add_sprite(64, 196, LanceBall.file('lanceur'))
      @launcher.z = 950
      @rest_ball = sprite('balles', *REST, 951, cell: [0, 0])
      @reticle = sprite('cercles', 160, 120, 960, cell: [0, 0])
      @aim = [160.0, 120.0]
      @balls = []
      @effects = []
      @popups = []
      @cool = 0
      @pull = 0
      @streak = 0
      @caught = 0
      @score = 0
      @golden = false
      @time = LanceBall.setting('time').to_i.clamp(10, 600) * 60
      @time_max = @time
      @stack.add_sprite(0, 0, LanceBall.file('barre')).z = 1000
      @gauge = @stack.add_sprite(38, 8, LanceBall.file('jauge'))
      @gauge.z = 1001
      @stack.with_font(20) do
        @caught_text = @stack.add_text(166, 3, 70, 13, '', 0, color: WHITE)
        @score_text = @stack.add_text(236, 3, 80, 13, '', 2, color: WHITE)
      end
      @caught_text.z = @score_text.z = 1001
      @banner = @stack.add_sprite(96, 96, LanceBall.file('texte_ready1'))
      @banner.z = 1100
      @banner_text = @stack.add_text(0, 104, 320, 16, '', 1, color: WHITE)
      @banner_text.z = 1101
      refresh_hud
      @state = :intro
      @intro = 0
    end

    def banner(name, fr)
      if LanceBall.fr?
        @banner.visible = false
        @banner_text.text = fr
      else
        @banner.set_bitmap(LanceBall.file("texte_#{name}"), :interface)
        @banner.visible = true
        @banner_text.text = ''
      end
    end

    def hide_banner
      @banner.visible = false
      @banner_text.text = ''
    end

    def update_intro
      @intro += 1
      case @intro
      when 1 then banner('ready1', 'Prêt.')
      when 30 then banner('ready2', 'Prêt..')
      when 60 then banner('ready3', 'Prêt...')
      when 90
        banner('start', 'Partez !')
        LanceBall.play_se('go')
      when 130
        hide_banner
        @state = :play
      end
      LanceBall.play_se('bip') if [1, 30, 60].include?(@intro)
      update_spots
    end

    def update_play
      update_aim
      update_balls
      @mons.each { |m| update_mon(m) }
      update_spots
      update_effects
      @time -= 1
      refresh_hud if (@time % 6).zero?
      return finish(:timeup) if @time <= 0

      finish(:finish) if @caught >= @mons.size
    end

    # --- Viser et lancer --------------------------------------------------------------------------------------------
    def update_aim
      speed = Input.press?(:B) ? 1.5 : 3.2
      @aim[0] += speed if Input.press?(:RIGHT)
      @aim[0] -= speed if Input.press?(:LEFT)
      @aim[1] += speed if Input.press?(:DOWN)
      @aim[1] -= speed if Input.press?(:UP)
      if (Mouse.respond_to?(:moved) && Mouse.moved) || Mouse.trigger?(:LEFT)
        @aim = [Mouse.x.to_f, Mouse.y.to_f]
      end
      @aim[0] = @aim[0].clamp(FIELD[0], FIELD[2])
      @aim[1] = @aim[1].clamp(FIELD[1], FIELD[3])
      @reticle.set_position(@aim[0].round, @aim[1].round)
      @reticle.src_rect.set(((@frame / 6) % 6) * 32, 0, 32, 32)
      @cool -= 1 if @cool > 0
      if @pull > 0
        @pull -= 1
        @rest_ball.y = REST[1] + (6 - @pull)
        throw_ball if @pull.zero?
      elsif @cool.zero? && (Input.trigger?(:A) || Mouse.trigger?(:LEFT))
        @pull = 6
      end
      @rest_ball.visible = @cool.zero? || @pull > 0
      @rest_ball.src_rect.set(0, (@golden ? 1 : 0) * 32, 32, 32)
    end

    def throw_ball
      LanceBall.play_se('throw')
      gold = @golden
      shadow = sprite('objets', *REST, 500, cell: [3, 0])
      ball = sprite('balles', *REST, 970, cell: [0, gold ? 1 : 0])
      @balls << { from: REST.dup, to: @aim.map(&:round), t: 0, sprite: ball, shadow: shadow, gold: gold }
      @cool = 22
    end

    def update_balls
      @balls.reject! do |b|
        b[:t] += 1
        r = b[:t] / FLIGHT.to_f
        x = b[:from][0] + (b[:to][0] - b[:from][0]) * r
        y = b[:from][1] + (b[:to][1] - b[:from][1]) * r
        height = Math.sin(Math::PI * r) * 46
        b[:sprite].set_position(x.round, (y - height).round)
        b[:sprite].zoom = 1.2 - 0.45 * r
        b[:sprite].src_rect.set(((b[:t] / 3) % 6) * 32, (b[:gold] ? 1 : 0) * 32, 32, 32)
        b[:shadow].set_position(x.round, y.round + 2)
        b[:shadow].zoom = 0.6 + 0.4 * r
        next false if b[:t] < FLIGHT

        b[:sprite].dispose
        b[:shadow].dispose
        land(b)
        true
      end
    end

    def land(ball)
      x, y = ball[:to]
      hit_r = ball[:gold] ? HIT + 6 : HIT
      target = @mons.select { |m| visible?(m) }.min_by { |m| Math.hypot(m[:x] - x, m[:y] - 10 - y) }
      dist = target ? Math.hypot(target[:x] - x, target[:y] - 10 - y) : 999
      dist -= 4 if target && %i[sleep dizzy].include?(target[:state])
      if target && dist <= hit_r
        return capture(target, ball[:gold])
      end

      @streak = 0
      @golden = false
      effect('cercles', x, y, 1, 6, 4)
      if target && dist <= NEAR && target[:state] != :dizzy
        target[:state] = :dizzy
        target[:timer] = 70
        LanceBall.play_se('dizzy')
        return
      end
      spot = @spots.index { |s| Math.hypot(s[:x] - x, s[:y] - 14 - y) <= 20 }
      if spot
        @spots[spot][:shake] = 16
        @mons.select { |m| m[:state] == :hidden && m[:spot] == spot }.each { |m| pop_out(m, true) }
      end
      effect('nuages', x, y, 0, 5, 4)
      LanceBall.play_se('miss')
    end

    def capture(mon, gold)
      mon[:state] = :caught
      mon[:sprite].visible = false
      mon[:fx].visible = false
      @caught += 1
      @streak += 1
      points = LanceBall.setting('catch_points').to_i * (gold ? 2 : 1)
      @score += points
      effect('objets', mon[:x], mon[:y] - 10, 0, 1, 10, start: 5)
      effect('nuages', mon[:x], mon[:y] - 10, 2, 5, 5)
      popup(mon[:x], mon[:y] - 30, "+#{points}")
      LanceBall.play_se('catch')
      if @streak >= 3 && !@golden
        @golden = true
        LanceBall.play_se('gold')
        popup(160, 190, LanceBall.t('Balle dorée !', 'Golden ball!'))
      elsif gold
        @golden = false
        @streak = 0
      end
      refresh_hud
    end

    # --- Pokémon ----------------------------------------------------------------------------------------------------
    def visible?(mon)
      return %i[out run sleep dizzy].include?(mon[:state])
    end

    def place_hidden(mon)
      spot = @spots[mon[:spot]]
      mon[:x] = spot[:x].to_f
      mon[:y] = spot[:y].to_f
      mon[:sprite].visible = false
      mon[:fx].visible = false
    end

    def free_spot(except)
      used = @mons.select { |m| %i[hidden run].include?(m[:state]) }.map { |m| m[:spot] }
      choices = (0...@spots.size).to_a - [except] - used
      choices = (0...@spots.size).to_a - [except] if choices.empty?
      return choices.sample
    end

    def pop_out(mon, startled = false)
      spot = @spots[mon[:spot]]
      side = rand(2).zero? ? -1 : 1
      mon[:x] = (spot[:x] + side * 20).clamp(FIELD[0] + 6, FIELD[2] - 6).to_f
      mon[:y] = (spot[:y] + 2).to_f
      mon[:sprite].visible = true
      effect('apparition', mon[:x], mon[:y] - 12, 0, 3, 5)
      LanceBall.play_se('pop')
      roll = rand(100)
      if startled || roll < 35 + @difficulty * 10
        start_run(mon)
      elsif roll < 88
        mon[:state] = :out
        mon[:timer] = [110 - @difficulty * 20, 40].max + rand(30)
      else
        mon[:state] = :sleep
        mon[:timer] = 200
      end
    end

    def start_run(mon)
      target = free_spot(mon[:spot])
      mon[:state] = :run
      mon[:spot] = target
      mon[:tx] = @spots[target][:x]
      mon[:ty] = @spots[target][:y]
    end

    def update_mon(mon)
      case mon[:state]
      when :hidden
        mon[:timer] -= 1
        @spots[mon[:spot]][:shake] = 10 if mon[:timer] == 30
        pop_out(mon) if mon[:timer] <= 0
      when :out, :sleep
        mon[:timer] -= 1
        hide(mon) if mon[:timer] <= 0
        mon[:step] = 0
      when :dizzy
        mon[:timer] -= 1
        if mon[:timer] <= 0
          mon[:state] = :out
          mon[:timer] = 20
        end
      when :run
        speed = 0.8 + @difficulty * 0.35
        dx = mon[:tx] - mon[:x]
        dy = mon[:ty] - mon[:y]
        d = Math.hypot(dx, dy)
        if d <= speed
          hide(mon)
        else
          mon[:x] += dx / d * speed
          mon[:y] += dy / d * speed
          mon[:dir] = dx.abs > dy.abs ? (dx < 0 ? 1 : 2) : (dy < 0 ? 3 : 0)
          mon[:step] += speed / 6.0
        end
      end
      draw_mon(mon)
    end

    def hide(mon)
      mon[:state] = :hidden
      mon[:timer] = rand(60..160) - @difficulty * 10
      @spots[mon[:spot]][:shake] = 12
      place_hidden(mon)
    end

    def draw_mon(mon)
      sp = mon[:sprite]
      return unless sp.visible

      frame = mon[:state] == :sleep ? 0 : mon[:step].floor % 4
      dir = %i[sleep dizzy].include?(mon[:state]) ? 0 : mon[:dir]
      sp.src_rect.set(frame * mon[:fw], dir * mon[:fh], mon[:fw], mon[:fh])
      sp.set_position(mon[:x].round, mon[:y].round)
      sp.z = mon[:y].round + 2
      fx = mon[:fx]
      case mon[:state]
      when :dizzy, :sleep
        fx.visible = true
        fx.set_bitmap(LanceBall.file(mon[:state] == :sleep ? 'zzz' : 'etoiles'), :interface)
        fx.src_rect.set(((@frame / 8) % 4) * 32, 0, 32, 32)
        fx.set_position(mon[:x].round, mon[:y].round - mon[:fh] + 4)
      else
        fx.visible = false
      end
    end

    def update_spots
      @spots.each do |spot|
        frame = spot[:shake] > 0 ? 1 + (spot[:shake] / 3) % 3 : 0
        spot[:shake] -= 1 if spot[:shake] > 0
        row = spot[:kind] == :tree ? 2 : 0
        spot[:sprite].src_rect.set(frame * 32, row * 32, 32, 32)
        spot[:top]&.src_rect&.set(frame * 32, 32, 32, 32)
      end
    end

    # --- Effets -----------------------------------------------------------------------------------------------------
    # @param row [Integer] ligne de l'image ; frames : nombre d'images ; speed : images de jeu par image
    def effect(name, x, y, row, frames, speed, hold = 0, start: 0)
      sp = sprite(name, x.round, y.round, 990, cell: [start, row])
      @effects << { sprite: sp, row: row, frames: frames, speed: speed, t: 0, hold: hold, start: start }
    end

    def popup(x, y, text)
      txt = @stack.add_text(x.round - 40, y.round, 80, 16, text, 1, color: WHITE)
      txt.z = 1050
      @popups << [txt, 40]
    end

    def update_effects
      @effects.reject! do |e|
        e[:t] += 1
        index = e[:t] / e[:speed]
        if index >= e[:frames] + e[:hold]
          e[:sprite].dispose
          next true
        end
        e[:sprite].src_rect.set((e[:start] + [index, e[:frames] - 1].min) * 32, e[:row] * 32, 32, 32)
        false
      end
      @popups.reject! do |p|
        p[1] -= 1
        p[0].y -= 1 if p[1].even?
        p[0].opacity = (p[1] * 10).clamp(0, 255)
        p[0].dispose if p[1] <= 0
        p[1] <= 0
      end
    end

    def refresh_hud
      @gauge.src_rect.set(0, 0, (120.0 * @time / @time_max).round.clamp(0, 120), 4)
      @caught_text.text = LanceBall.t("Capturés #{@caught}/#{@mons.size}", "Caught #{@caught}/#{@mons.size}")
      @score_text.text = "#{@score} pts"
    end

    # --- Fin ------------------------------------------------------------------------------------------------------
    def finish(kind)
      @state = :over
      @over = 0
      bonus = kind == :finish ? (@time / 60) * LanceBall.setting('time_points').to_i : 0
      @bonus = bonus
      @score += bonus
      refresh_hud
      if kind == :finish
        banner('finish', 'Terminé !')
      else
        banner('timeup', 'Temps écoulé !')
      end
      @balls.each { |b| b[:sprite].dispose; b[:shadow].dispose }
      @balls.clear
      LanceBall.play_se('end')
    end

    def update_over
      @over += 1
      update_effects
      update_spots
      show_results if @over == 100
    end

    def show_results
      @state = :results
      store = LanceBall.data
      record = @score > store['record']
      store['record'] = @score if record
      store['played'] += 1
      store['last'] = @score
      store['caught'] += @caught
      @result = @score
      caught = @mons.select { |m| m[:state] == :caught }.map { |m| m[:pokemon] }
      reset_stack
      sprite('panneau', 32, 24, 10)
      @stack.add_text(32, 34, 256, 16, LanceBall.t('Résultats', 'Results'), 1, color: WHITE).z = 11
      @stack.with_font(20) do
        rows = [[LanceBall.t('Pokémon capturés', 'Pokémon caught'), "#{caught.size} / #{@mons.size}"],
                [LanceBall.t('Bonus de temps', 'Time bonus'), "#{@bonus}"],
                [LanceBall.t('Score', 'Score'), "#{@score}"],
                [LanceBall.t('Record', 'High score'), "#{store['record']}#{record ? LanceBall.t(' (nouveau !)', ' (new!)') : ''}"]]
        rows.each_with_index do |(a, b), i|
          @stack.add_text(50, 58 + i * 15, 120, 13, a, color: WHITE).z = 11
          @stack.add_text(170, 58 + i * 15, 100, 13, b, 2, color: WHITE).z = 11
        end
        @stack.add_text(50, 150, 220, 13, LanceBall.t('A : continuer', 'A: continue'), 1, color: WHITE).z = 11
      end
      strip = @stack.add_sprite(32, 180, LanceBall.file('cases'))
      strip.z = 12
      caught.first(6).each_with_index do |pk, i|
        icon = @stack.push(32 + 20 + i * 25, 180 + 26, nil, type: UI::PokemonIconSprite)
        icon.data = pk
        icon.z = 13
      end
      @score.to_s.rjust(4, '0')[-4..].chars.each_with_index do |ch, i|
        digit = @stack.add_sprite(32 + 192 + i * 13, 180 + 18, LanceBall.file('chiffres'))
        digit.src_rect.set(ch.to_i * 16, 0, 16, 32)
        digit.zoom = 0.75
        digit.z = 13
      end
      @prize_pending = @score
    end

    def give_prize(points)
      prize = LanceBall.prize_for(points)
      unless prize
        display_message(LanceBall.t('Pas de lot cette fois... Réessaie !', 'No prize this time... Try again!'))
        return
      end
      item = prize['item'].to_sym
      count = prize['count']
      $bag.add_item(item, count)
      name = data_item(item).name rescue prize['item']
      display_message(LanceBall.t("#{points} points ! Tu reçois #{count > 1 ? "#{count} " : ''}#{name} !",
                                  "#{points} points! You got #{count > 1 ? "#{count} " : ''}#{name}!"))
    end

    def input_results
      if @prize_pending
        points = @prize_pending
        @prize_pending = nil
        return give_prize(points)
      end
      return unless Input.trigger?(:A) || Input.trigger?(:B) || Mouse.trigger?(:LEFT)

      play_decision_se
      @running = false
    end
  end
end
