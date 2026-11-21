# Poké Récré : mini-jeux de X / Y (images de tools/poke_recre/build_xy.py)
#
# Cueille-Baies (Berry Picker) : trois Pokémon pensent à une baie ; prends la bonne baie en bas et donne-la au bon
#   Pokémon. Gauche / Droite : choisir, A : prendre puis donner, B : reposer (ou à la souris).
# Jongle-Tête (Head It) : des pelotes tombent ; Gauche / Droite pour se placer, A pour sauter et les renvoyer de la
#   tête. Les pelotes roses (« ! ») valent plus, les combos aussi ; à la fin, une pelote géante.
# Une partie dure game_time secondes. Étoiles : berry_stars (baies données) et head_stars (points), 5 seuils.
# Résultat (scene.result) : { points:, stars: } ; Poké Récré donne alors des Pofiteroles (et parfois une décoration).
# Commandes : cueille_baies(index) et jongle_tete(index) (00102 Commandes.rb).
module GamePlay
  # Base commune : accueil, compte à rebours, chrono, score, résultats
  class PokeRecreMiniGame < BaseCleanUpdate::FrameBalanced
    P = ::PokeRecre
    WHITE = 9
    DARK = 0
    SMALL = 20
    DIGIT_W = 30
    DIGIT_H = 42
    # @return [Hash, nil] { points:, stars: } (nil : pas joué)
    attr_reader :result

    # @param pokemon [PFM::Pokemon, nil]
    def initialize(pokemon = nil)
      super()
      @pokemon = pokemon && !pokemon.egg? ? pokemon : P.party.first
      @state = :intro
      @points = 0
      @frame = 0
      @result = nil
    end

    def update_inputs
      case @state
      when :intro then input_intro
      when :play then input_play
      when :results then input_results
      end
      return false
    end

    def update_graphics
      @frame += 1
      case @state
      when :count then update_count
      when :play
        @time_left -= 1
        update_play
        refresh_hud
        finish if @time_left <= 0
      when :results then update_results
      end
      return true
    end

    private

    # À définir : key ('cueille'), title ([fr, en]), rules ([[fr...], [en...]]), folder, stars_setting,
    # start_play, input_play, update_play
    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @stack.add_sprite(0, 0, P.file("#{folder}/fond"))
      create_scene
      create_hud
      create_panel
      show_intro
    end

    def create_scene; end

    def create_hud
      @hud = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @score_digits = Array.new(3) do |i|
        sprite = @hud.add_sprite(8 + i * 19, 6, P.file("#{folder}/chiffres"))
        sprite.zoom = 0.6
        sprite.src_rect.set(0, 0, DIGIT_W, DIGIT_H)
        sprite.z = 80
        sprite
      end
      @hud.with_font(SMALL) do
        @time_text = @hud.add_text(220, 6, 92, 16, '', 2, color: WHITE)
      end
      @time_text.z = 80
      refresh_hud
    end

    def refresh_hud
      text = @points.clamp(0, 999).to_s
      @score_digits.each_with_index do |sprite, i|
        digit = text[i]
        sprite.visible = !digit.nil?
        sprite.src_rect.x = digit.to_i * DIGIT_W if digit
      end
      seconds = ((@time_left || 0) / 60.0).ceil
      @time_text.text = P.t("Temps : #{seconds}", "Time: #{seconds}")
    end

    def create_panel
      @panel = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @panel.add_sprite(10, 44, P.file('party'))
      @panel_title = @panel.add_text(20, 51, 280, 16, '', 1, color: DARK)
      @panel_lines = []
      @panel.with_font(SMALL) do
        5.times { |i| @panel_lines << @panel.add_text(26, 76 + i * 16, 268, 13, '', 1, color: DARK) }
      end
      @stars = Array.new(5) do |i|
        star = @panel.add_sprite(84 + i * 32, 140, P.file('cueille/notes'))
        star.src_rect.set(64, 0, 32, 42)
        star
      end
      @panel.each { |sprite| sprite.z = 90 }
      @big = @stack.add_sprite(160, 120, P.file("#{folder}/chiffres"))
      @big.src_rect.set(0, 0, DIGIT_W, DIGIT_H)
      @big.set_origin(DIGIT_W / 2, DIGIT_H / 2)
      @big.z = 95
      @big.visible = false
    end

    def panel(title, lines, stars = nil)
      @panel.visible = true
      @panel_title.text = title
      @panel_lines.each_with_index { |text, i| text.text = lines[i].to_s }
      @stars.each_with_index do |star, i|
        star.visible = !stars.nil?
        star.opacity = stars && i < stars ? 255 : 70
      end
    end

    # --- Accueil ----------------------------------------------------------------------------------------------------
    def show_intro
      @state = :intro
      lines = P.t(*rules) + ['', P.t("Record : #{P.data['records'][key].to_i}   A : Jouer   B : Quitter",
                                     "Record: #{P.data['records'][key].to_i}   A: Play   B: Quit")]
      panel(P.t(*title), lines)
    end

    def input_intro
      if Input.trigger?(:B) || Mouse.trigger?(:right)
        play_cancel_se
        return @running = false
      end
      return unless Input.trigger?(:A) || Mouse.trigger?(:left)

      play_decision_se
      @panel.visible = false
      @state = :count
      @count = 180
      @time_left = [P.setting('game_time').to_i, 10].max * 60
      start_play
      refresh_hud
    end

    def update_count
      @count -= 1
      @big.visible = @count > 0
      @big.src_rect.x = ((@count / 60) + 1) * DIGIT_W
      @big.zoom = 1.5 + (@count % 60) / 60.0
      return if @count > 0

      @state = :play
    end

    # --- Fin --------------------------------------------------------------------------------------------------------
    def stars_for(points)
      return Array(P.setting(stars_setting)).count { |needed| points >= needed.to_i }
    end

    def finish
      @state = :results
      @time_left = 0
      refresh_hud
      stars = stars_for(@points)
      data = P.data
      record = @points > data['records'][key].to_i
      data['records'][key] = @points if record
      data['plays'][key] = data['plays'][key].to_i + 1
      @result = { points: @points, stars: stars }
      Audio.se_play('audio/se/poke_recre_pet', 100, 120)
      lines = [P.t("#{score_label} : #{@points}", "#{score_label} : #{@points}")]
      lines << (record ? P.t('Nouveau record !', 'New record!') : P.t("Record : #{data['records'][key]}", "Record: #{data['records'][key]}"))
      lines << ''
      lines << P.t('A : Continuer', 'A: Continue')
      panel(P.t('Terminé !', 'Finished!'), lines, stars)
      @results_wait = 30
    end

    def score_label
      return P.t('Points', 'Points')
    end

    def update_results
      @results_wait -= 1 if @results_wait > 0
    end

    def input_results
      return if @results_wait > 0
      return unless Input.trigger?(:A) || Input.trigger?(:B) || Mouse.trigger?(:left)

      play_decision_se
      @running = false
    end

    def pokemon_sprite(pokemon, x, y)
      sprite = UI::PokemonFaceSprite.new(@viewport)
      sprite.data = pokemon
      sprite.set_position(x, y)
      return sprite
    rescue StandardError
      return nil
    end

    # Effet qui monte et s'efface : [sprite, âge, dx, dy, vie]
    def float(sprite, dx, dy, life = 40)
      (@floats ||= []) << [sprite, 0, dx, dy, life]
    end

    def update_floats
      (@floats ||= []).reject! do |entry|
        sprite, age, dx, dy, life = entry
        entry[1] = age + 1
        sprite.x += dx
        sprite.y += dy
        sprite.opacity = 255 * (life - age) / life
        next false if age < life

        sprite.dispose
        true
      end
    end
  end

  # --- Cueille-Baies ------------------------------------------------------------------------------------------------
  class PokeRecreBerryPicker < PokeRecreMiniGame
    BERRY = 24
    BERRY_ZOOM = 1.25
    BERRY_X = 24
    BERRY_STEP = 28
    BERRY_Y = 214
    MON_X = [62, 160, 258].freeze
    MON_Y = 176
    PATIENCE = 8 * 60

    private

    def key = 'cueille'
    def folder = 'cueille'
    def stars_setting = 'berry_stars'
    def score_label = P.t('Baies données', 'Berries given')
    def title = ['Cueille-Baies', 'Berry Picker']

    def rules
      [['Chaque Pokémon pense à une baie.', 'Gauche / Droite : choisir une baie, A : la prendre,',
        'puis choisir le Pokémon et A : la lui donner.'],
       ['Each Pokémon thinks of a Berry.', 'Left / Right: choose a Berry, A: take it,', 'then choose the Pokémon and A: give it.']]
    end

    def create_scene
      party = P.party
      party = [@pokemon] + (party - [@pokemon]) if @pokemon
      party = [@pokemon] if party.empty? && @pokemon
      @mons = MON_X.each_with_index.map do |x, i|
        pokemon = party[i % [party.size, 1].max]
        sprite = pokemon && pokemon_sprite(pokemon, x, MON_Y)
        sprite&.z = 35
        bubble = @stack.add_sprite(x + 4, 22, P.file('cueille/bulle'))
        bubble.zoom = 0.75
        berry = @stack.add_sprite(x + 14, 27, P.file('cueille/baies'))
        berry.src_rect.set(0, 0, BERRY, BERRY)
        berry.zoom = 1.25
        bubble.z = 20
        berry.z = 21
        { x: x, sprite: sprite, bubble: bubble, berry: berry, wish: nil, wait: 0, patience: 0 }
      end
      pile = @stack.add_sprite(160, 240, P.file('cueille/tas'))
      pile.set_origin(pile.bitmap.width / 2, pile.bitmap.height)
      pile.z = 5
      @stack.add_sprite(0, 240 - 30, P.file('cueille/herbe')).z = 36
      @berries = Array.new(10) do |i|
        sprite = @stack.add_sprite(BERRY_X + i * BERRY_STEP + BERRY / 2, BERRY_Y, P.file('cueille/baies'))
        sprite.src_rect.set(i * BERRY, 0, BERRY, BERRY)
        sprite.zoom = BERRY_ZOOM
        sprite.set_origin(BERRY / 2, BERRY / 2)
        sprite.z = 40
        sprite
      end
      @pointer = @stack.add_sprite(0, 0, P.file('main/pointe'))
      @pointer.src_rect.set(0, 0, 32, 32)
      @pointer.set_origin(8, 2)
      @pointer.z = 70
      @held = @stack.add_sprite(0, 0, P.file('cueille/baies'))
      @held.src_rect.set(0, 0, BERRY, BERRY)
      @held.set_origin(BERRY / 2, BERRY / 2)
      @held.zoom = BERRY_ZOOM
      @held.z = 69
      @held.visible = false
      @mons.each { |mon| show_wish(mon) }
      @cursor = 0
      @picked = nil
      refresh_pointer
    end

    def start_play
      @mons.each { |mon| new_wish(mon) }
    end

    # Baies possibles : 5 au début, toutes après 10 baies données
    def kinds
      return @points >= 10 ? 10 : 5
    end

    def new_wish(mon)
      taken = @mons.map { |other| other[:wish] }
      choices = (0...kinds).to_a - taken
      mon[:wish] = (choices.empty? ? (0...kinds).to_a : choices).sample
      mon[:patience] = PATIENCE
      show_wish(mon)
    end

    def show_wish(mon)
      visible = !mon[:wish].nil? && mon[:wait] <= 0
      mon[:bubble].visible = mon[:berry].visible = visible
      mon[:berry].src_rect.x = mon[:wish].to_i * BERRY
      mon[:bubble].opacity = mon[:berry].opacity = mon[:patience] < 120 && (@frame / 8).odd? ? 140 : 255
    end

    def input_play
      count = @picked ? @mons.size : 10
      if Input.repeat?(:RIGHT)
        @cursor = (@cursor + 1) % count
        play_cursor_se
      elsif Input.repeat?(:LEFT)
        @cursor = (@cursor - 1) % count
        play_cursor_se
      end
      mouse_play
      if Input.trigger?(:B) && @picked
        play_cancel_se
        drop
      elsif Input.trigger?(:A)
        @picked ? give(@mons[@cursor]) : pick(@cursor)
      end
      refresh_pointer
    end

    def mouse_play
      return unless Mouse.trigger?(:left)

      berry = @berries.index { |sprite| (Mouse.x - sprite.x).abs <= 14 && (Mouse.y - sprite.y).abs <= 14 }
      return pick(berry) if berry && Mouse.y > 190

      mon = @mons.index { |m| (Mouse.x - m[:x]).abs <= 46 && Mouse.y.between?(20, MON_Y) }
      give(@mons[mon]) if mon && @picked
    end

    def pick(index)
      @picked = index
      @cursor = @mons.index { |mon| mon[:wish] == index } || 1
      play_decision_se
      @held.src_rect.x = index * BERRY
      @held.visible = true
    end

    def drop
      @cursor = @picked || 0
      @picked = nil
      @held.visible = false
    end

    def give(mon)
      return if mon[:wait] > 0

      if mon[:wish] == @picked
        @points += 1
        Audio.se_play('audio/se/poke_recre_eat', 90)
        note = @stack.add_sprite(mon[:x] + rand(-20..20), MON_Y - 80, P.file('cueille/notes'))
        note.src_rect.set(rand(2) * 32, 0, 32, 42)
        note.z = 60
        float(note, rand(-5..5) / 10.0, -1.2)
        mon[:wish] = nil
        mon[:wait] = 20
      else
        play_buzzer_se
        puff = @stack.add_sprite(mon[:x] - 16, MON_Y - 90, P.file('cueille/nuage'))
        puff.z = 60
        float(puff, 0, -0.5, 30)
        mon[:wait] = 30
      end
      show_wish(mon)
      drop
    end

    def update_play
      update_floats
      @mons.each do |mon|
        if mon[:wait] > 0
          mon[:wait] -= 1
          new_wish(mon) if mon[:wait] == 0 && mon[:wish].nil?
        elsif (mon[:patience] -= 1) <= 0
          puff = @stack.add_sprite(mon[:x] + 10, 30, P.file('cueille/nuage'))
          puff.z = 60
          float(puff, 0, -0.5, 30)
          mon[:wish] = nil
          mon[:wait] = 30
        end
        show_wish(mon)
      end
      @berries.each_with_index { |sprite, i| sprite.y = BERRY_Y - (i == @cursor && !@picked ? 4 + (@frame / 10) % 2 * 2 : 0) }
    end

    def refresh_pointer
      if @picked
        mon = @mons[@cursor]
        @pointer.set_position(mon[:x] + 6, MON_Y - 50)
        @held.set_position(mon[:x], MON_Y - 50)
      else
        sprite = @berries[@cursor]
        @pointer.set_position(sprite.x + 4, sprite.y - 2)
      end
    end
  end

  # --- Jongle-Tête --------------------------------------------------------------------------------------------------
  class PokeRecreHeadIt < PokeRecreMiniGame
    FEET_Y = 232
    HEAD = 66          # hauteur de la tête au-dessus des pieds
    JUMP_FRAMES = 26
    JUMP_HEIGHT = 46
    SPEED = 4
    BALL_W = 32
    BALL_H = 44
    GRAVITY = 0.12
    GIANT_TIME = 8 * 60

    private

    def key = 'jongle'
    def folder = 'jongle'
    def stars_setting = 'head_stars'
    def title = ['Jongle-Tête', 'Head It']

    def rules
      [['Gauche / Droite : se placer, A : sauter.', 'Renvoie les pelotes de la tête ! Les roses (!) valent',
        '3 points ; enchaîne pour des combos.'],
       ['Left / Right: move, A: jump.', 'Head the balls of yarn! Pink ones (!) are worth', '3 points; chain them for combos.']]
    end

    def create_scene
      @x = 160.0
      @jump = 0
      @balls = []
      @combo = 0
      @spawn = 60
      @giant = nil
      @mon = pokemon_sprite(@pokemon, @x, FEET_Y) if @pokemon
      @mon&.z = 40
      @stack.with_font(SMALL) { @combo_text = @stack.add_text(4, 24, 120, 16, '', color: WHITE) }
      @combo_text.z = 80
    end

    def start_play; end

    def head_y
      lift = @jump > 0 ? Math.sin(Math::PI * (JUMP_FRAMES - @jump) / JUMP_FRAMES) * JUMP_HEIGHT : 0
      return FEET_Y - HEAD - lift
    end

    def input_play
      if Mouse.moved
        @x = Mouse.x.to_f
      else
        @x -= SPEED if Input.press?(:LEFT)
        @x += SPEED if Input.press?(:RIGHT)
      end
      @x = @x.clamp(24, 296)
      return unless @jump <= 0 && (Input.trigger?(:A) || Mouse.trigger?(:left))

      @jump = JUMP_FRAMES
    end

    def update_play
      update_floats
      @jump -= 1 if @jump > 0
      @mon&.set_position(@x.round, (head_y + HEAD).round)
      spawn_ball
      @balls.reject! { |ball| update_ball(ball) }
      update_giant
      @combo_text.text = @combo >= 2 ? P.t("Combo ×#{@combo}", "Combo ×#{@combo}") : ''
    end

    def spawn_ball
      return if @time_left < GIANT_TIME
      return if (@spawn -= 1) > 0

      elapsed = [P.setting('game_time').to_i * 60 - @time_left, 0].max
      @spawn = [70 - elapsed / 60, 30].max + rand(20)
      color = rand(100) < 20 ? 0 : [1, 2, 3].sample
      sprite = @stack.add_sprite(0, 0, P.file('jongle/pelotes'))
      sprite.src_rect.set(0, color * BALL_H, BALL_W, BALL_H)
      sprite.set_origin(BALL_W / 2, BALL_H - 8)
      sprite.z = 50
      mark = nil
      if color == 0
        mark = @stack.add_sprite(0, 0, P.file('jongle/attention'))
        mark.zoom = 0.4
        mark.z = 51
      end
      @balls << { sprite: sprite, mark: mark, color: color, x: rand(30..290).to_f, y: -10.0, vx: 0.0,
                  vy: 0.6 + rand * 0.4, hit: false, age: 0 }
    end

    # @return [Boolean] true si la pelote est partie
    def update_ball(ball)
      ball[:age] += 1
      ball[:vy] += ball[:hit] ? GRAVITY : GRAVITY / 4
      ball[:x] += ball[:vx]
      ball[:y] += ball[:vy]
      if !ball[:hit] && ball[:vy] > 0 && touches_head?(ball[:x], ball[:y], 26)
        ball[:hit] = true
        ball[:vy] = -5.5 - rand
        ball[:vx] = (ball[:x] - @x) / 8.0 + rand(-10..10) / 10.0
        @combo += 1
        gain = (ball[:color] == 0 ? 3 : 1) + @combo / 5
        @points += gain
        Audio.se_play('audio/se/poke_recre_pet', 90, 100 + [@combo * 4, 60].min)
        rainbow if (@combo % 10).zero?
      end
      frame = ball[:hit] ? 3 + (ball[:age] / 6) % 3 : (ball[:age] / 10) % 3
      frame = (ball[:age] / 10) % 3 if ball[:color] == 3
      ball[:sprite].src_rect.x = frame * BALL_W
      ball[:sprite].set_position(ball[:x].round, ball[:y].round)
      ball[:mark]&.set_position(ball[:x].round + 6, ball[:y].round - 50)
      gone = ball[:y] > 250 || (ball[:hit] && ball[:y] < -40)
      if ball[:y] > 250 && !ball[:hit]
        @combo = 0
      end
      return false unless gone

      ball[:sprite].dispose
      ball[:mark]&.dispose
      return true
    end

    def touches_head?(x, y, reach)
      return @jump > 0 && (x - @x).abs <= reach && (y - head_y).abs <= 14
    end

    def rainbow
      arc = @stack.add_sprite(160, 70, P.file('jongle/arc'))
      arc.set_origin(arc.bitmap.width / 2, arc.bitmap.height / 2)
      arc.z = 10
      float(arc, 0, 0, 90)
    end

    # Pelote géante : les dernières secondes, chaque coup de tête vaut 5 points
    def update_giant
      return if @time_left > GIANT_TIME

      unless @giant
        sprite = @stack.add_sprite(0, 0, P.file('jongle/geante'))
        sprite.src_rect.set(0, 0, 64, 96)
        sprite.set_origin(32, 80)
        sprite.z = 52
        @giant = { sprite: sprite, x: 160.0, y: -40.0, vx: 0.0, vy: 0.5, hits: 0, cool: 0 }
      end
      g = @giant
      g[:vy] += GRAVITY / 3
      g[:x] = (g[:x] + g[:vx]).clamp(32, 288)
      g[:vx] = -g[:vx] if g[:x] <= 32 || g[:x] >= 288
      g[:y] += g[:vy]
      g[:cool] -= 1 if g[:cool] > 0
      if g[:cool] <= 0 && g[:vy] > 0 && touches_head?(g[:x], g[:y], 40)
        g[:vy] = -4.0
        g[:vx] = (g[:x] - @x) / 10.0
        g[:hits] += 1
        g[:cool] = 20
        @points += 5
        Audio.se_play('audio/se/poke_recre_pet', 100, 80)
      end
      g[:y] = 250 if g[:y] > 250
      g[:sprite].src_rect.x = [g[:hits], 2].min * 64
      g[:sprite].set_position(g[:x].round, g[:y].round)
    end
  end
end
