# Cueillette Dodrio : la partie (accueil, compte à rebours, jeu, résultats)
module GamePlay
  class DodrioBerryPicking < BaseCleanUpdate
    WHITE = 9
    DARK = 0
    COL_W = 24
    FEET_Y = 234
    CATCH_Y = 178     # hauteur où les têtes attrapent les baies
    TOP_Y = 22
    GROUND_Y = 212
    PECK = 10         # images d'un coup de bec
    COOL = 4          # images avant le coup suivant
    # images de dodrio.png
    IDLE = 0
    RIGHT = 1
    MIDDLE = 2
    LEFT = 3
    TIRED = 4
    HURT = 5

    # @return [Integer] points du joueur (nil : pas joué)
    attr_reader :result

    def initialize(players = nil)
      super()
      @players = (players || Dodrio.setting('players')).to_i.clamp(1, 3)
      @state = :intro
      @result = nil
    end

    def update_inputs
      case @state
      when :intro then input_intro
      when :results then input_results
      end
      return true
    end

    def update_graphics
      @frame = @frame.to_i + 1
      case @state
      when :count then update_count
      when :play then update_play
      when :over then update_over
      end
      return true
    end

    private

    def create_graphics
      super
      @play_bgm = Dodrio.setting('bgm').to_s
      Audio.bgm_play("audio/bgm/#{@play_bgm}") unless @play_bgm.empty?
      show_intro
    end

    def build(background = 'fond_menu')
      @stack&.dispose
      @stack = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @stack.add_sprite(0, 0, Dodrio.file(background))
      yield(@stack) if block_given?
    end

    # --- Accueil ----------------------------------------------------------------------------------------------------
    def show_intro
      @state = :intro
      build do |s|
        s.add_sprite(16, 40, Dodrio.file('panneau'))
        s.add_text(16, 46, 288, 16, Dodrio.t('Cueillette Dodrio', 'Dodrio Berry Picking'), 1, color: DARK)
        s.with_font(20) do
          rules = Dodrio.t(['Gauche, Haut (ou A) et Droite : picorer avec une tête.', 'Attrape les baies avant qu’elles touchent le sol !',
                            "Partie finie après #{Dodrio.setting('max_misses')} baies ratées."],
                           ['Left, Up (or A) and Right: peck with a head.', 'Catch the berries before they hit the ground!',
                            "Game over after #{Dodrio.setting('max_misses')} missed berries."])
          rules.each_with_index { |line, i| s.add_text(26, 68 + i * 14, 268, 13, line, color: DARK) }
          s.add_text(26, 116, 268, 13, Dodrio.t("Record : #{Dodrio.data['record']} points", "Record: #{Dodrio.data['record']} points"), color: DARK)
          s.add_text(26, 138, 268, 13, Dodrio.t('A : commencer   B : quitter', 'A: start   B: quit'), 1, color: DARK)
        end
        @intro_dodrio = s.add_sprite(160, 222, Dodrio.file('dodrio'))
        @intro_dodrio.src_rect.set(0, 0, 64, 56)
        @intro_dodrio.set_origin(32, 56)
      end
    end

    def input_intro
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
      @columns = @players * 2 + 1
      names = Dodrio.npc_names.shuffle
      player_slot = (@players - 1) / 2
      @dodrios = Array.new(@players) do |i|
        player = i == player_slot
        { index: i, player: player, name: player ? $trainer&.name.to_s : names[i % names.size], column: i * 2 + 1,
          peck: 0, peck_col: nil, cool: 0, hurt: 0, points: 0, berries: [0, 0, 0], misses: 0, spawn: rand(20..50) }
      end
      @player = @dodrios[player_slot]
      @berries = []
      @splats = []
      @sparks = []
      @caught = 0
      @level = 0
      @time_left = Dodrio.setting('time').to_i * 60
      build('fond') do |s|
        @marks = [-1, 0, 1].map do |d|
          mark = s.add_sprite(column_x(@player[:column] + d) - 12, CATCH_Y - 18, Dodrio.file('colonne'))
          mark.opacity = 150
          mark
        end
        @dodrios.each do |dodrio|
          sprite = s.add_sprite(column_x(dodrio[:column]), FEET_Y, Dodrio.file('dodrio'))
          sprite.set_origin(32, 56)
          sprite.src_rect.set(0, 0, 64, 56)
          sprite.z = dodrio[:player] ? 30 : 20
          dodrio[:sprite] = sprite
        end
        s.add_sprite(0, 0, Dodrio.file('bandeau')).z = 100
        @squares = Array.new(Dodrio.setting('max_misses').to_i.clamp(1, 20)) do |i|
          sq = s.add_sprite(4 + i * 11, 5, Dodrio.file('cases'))
          sq.src_rect.set(0, 0, 10, 10)
          sq.z = 101
          sq
        end
        @score_text = s.add_text(130, 2, 70, 16, '', 0, color: WHITE)
        @score_text.z = 101
        s.with_font(20) { @others_text = s.add_text(196, 4, 120, 13, '', 2, color: WHITE) }
        @others_text.z = 101
        @big = s.add_text(0, 100, 320, 16, '', 1, color: DARK)
        @big.z = 120
      end
      refresh_hud
      @state = :count
      @count = 0
    end

    def column_x(col)
      return 160 + (col - (@columns - 1) / 2.0) * COL_W
    end

    def update_count
      @count += 1
      if @count % 50 == 1 && @count < 150
        @big.text = (3 - @count / 50).to_s
        Dodrio.play_se('bip')
      elsif @count == 150
        @big.text = Dodrio.t('Partez !', 'Go!')
        Dodrio.play_se('go')
      elsif @count == 180
        @big.text = ''
        @state = :play
      end
      update_dodrios
    end

    def speed
      base = Dodrio.setting('start_speed').to_f + @level * Dodrio.setting('speed_step').to_f
      return [base, Dodrio.setting('max_speed').to_f].min
    end

    def update_play
      player_input
      @dodrios.each do |dodrio|
        ai(dodrio) unless dodrio[:player]
        spawn(dodrio)
      end
      update_berries
      update_dodrios
      update_effects
      if @time_left > 0
        @time_left -= 1
        return finish if @time_left == 0
      end
      finish if @player[:misses] >= Dodrio.setting('max_misses').to_i
    end

    def player_input
      d = @player
      col = nil
      col = d[:column] - 1 if Input.trigger?(:LEFT)
      col = d[:column] + 1 if Input.trigger?(:RIGHT)
      col = d[:column] if Input.trigger?(:UP) || Input.trigger?(:A)
      if Mouse.trigger?(:LEFT)
        mcol = ((Mouse.x - column_x(0) + COL_W / 2) / COL_W).floor
        col = mcol if (mcol - d[:column]).abs <= 1
      end
      peck(d, col) if col
    end

    def peck(dodrio, col)
      return if dodrio[:cool] > 0 || dodrio[:hurt] > 0

      dodrio[:peck] = PECK
      dodrio[:peck_col] = col
      dodrio[:cool] = PECK + COOL
      Dodrio.play_se('peck') if dodrio[:player]
      berry = @berries.select { |b| b[:col] == col && b[:y].between?(CATCH_Y - 14, CATCH_Y + 10) }.max_by { |b| b[:y] }
      catch(dodrio, berry) if berry
    end

    def catch(dodrio, berry)
      @berries.delete(berry)
      berry[:sprite].dispose
      points = Dodrio::BERRIES[berry[:kind]][0]
      dodrio[:points] += points
      dodrio[:berries][berry[:kind]] += 1
      spark(column_x(berry[:col]), berry[:y])
      return refresh_hud unless dodrio[:player]

      Dodrio.play_se('catch')
      @caught += 1
      if (@caught % 10).zero?
        @level += 1
        Dodrio.play_se('level')
      end
      refresh_hud
    end

    # Ordinateur : picore quand une baie de ses colonnes arrive à hauteur (adresse selon la difficulté)
    def ai(dodrio)
      return if dodrio[:cool] > 0 || dodrio[:hurt] > 0

      level = Dodrio.setting('difficulty').to_i.clamp(1, 3)
      target = @berries.select { |b| (b[:col] - dodrio[:column]).abs <= 1 && b[:y].between?(CATCH_Y - 10, CATCH_Y + 8) }.max_by { |b| b[:y] }
      return unless target
      # la baie du voisin (colonne partagée) : moins souvent
      return if target[:owner] != dodrio && rand(100) >= 6 + level * 4

      chance = [10, 16, 26][level - 1] + (target[:owner] == dodrio ? 0 : -4)
      peck(dodrio, target[:col]) if rand(100) < chance
    end

    def spawn(dodrio)
      dodrio[:spawn] -= 1
      return if dodrio[:spawn] > 0

      gap = [(80 - @level * 5), 34].max
      dodrio[:spawn] = rand(gap..(gap + 40))
      col = dodrio[:column] + rand(-1..1)
      # pas deux baies trop proches dans la même colonne
      return if @berries.any? { |b| b[:col] == col && b[:y] < TOP_Y + 40 }

      roll = rand(100)
      kind = roll < Dodrio::BERRIES[0][1] ? 0 : (roll < Dodrio::BERRIES[0][1] + Dodrio::BERRIES[1][1] ? 1 : 2)
      sprite = @stack.add_sprite(0, 0, Dodrio.file('baies'))
      sprite.src_rect.set(kind * 8, 0, 8, 9)
      sprite.set_origin(4, 9)
      sprite.z = 40
      @berries << { col: col, y: TOP_Y.to_f, kind: kind, owner: dodrio, sprite: sprite, wobble: rand(60) }
    end

    def update_berries
      @berries.dup.each do |berry|
        berry[:y] += speed * Dodrio::BERRIES[berry[:kind]][2]
        berry[:sprite].set_position(column_x(berry[:col]) + (Math.sin((@frame + berry[:wobble]) / 6.0) * 0.6).round, berry[:y].round)
        next unless berry[:y] >= GROUND_Y

        @berries.delete(berry)
        berry[:sprite].dispose
        splat(column_x(berry[:col]), berry[:kind])
        owner = berry[:owner]
        owner[:misses] += 1
        owner[:hurt] = 24
        next unless owner[:player]

        Dodrio.play_se('miss')
        refresh_hud
      end
    end

    def splat(x, kind)
      sprite = @stack.add_sprite(x, GROUND_Y + 2, Dodrio.file('ecrase'))
      sprite.src_rect.set(kind * 14, 0, 14, 8)
      sprite.set_origin(7, 8)
      sprite.z = 15
      @splats << [sprite, 40]
    end

    def spark(x, y)
      sprite = @stack.add_sprite(x, y, Dodrio.file('etoile'))
      sprite.set_origin(6, 6)
      sprite.z = 60
      @sparks << [sprite, 14]
    end

    def update_effects
      @splats.reject! do |item|
        item[1] -= 1
        item[0].opacity = (item[1] * 8).clamp(0, 255)
        item[0].dispose if item[1] <= 0
        item[1] <= 0
      end
      @sparks.reject! do |item|
        item[1] -= 1
        item[0].y -= 1
        item[0].opacity = item[1] * 18
        item[0].dispose if item[1] <= 0
        item[1] <= 0
      end
    end

    def update_dodrios
      @dodrios.each do |d|
        d[:peck] -= 1 if d[:peck] > 0
        d[:cool] -= 1 if d[:cool] > 0
        d[:hurt] -= 1 if d[:hurt] > 0
        frame = if @state == :over
                  d[:player] ? TIRED : IDLE
                elsif d[:hurt] > 0
                  HURT
                elsif d[:peck] > 0
                  { -1 => LEFT, 0 => MIDDLE, 1 => RIGHT }[d[:peck_col] - d[:column]]
                else
                  IDLE
                end
        d[:sprite].src_rect.set(frame * 64, 0, 64, 56)
        d[:sprite].x = column_x(d[:column]) + (d[:hurt] > 0 ? (d[:hurt] / 3).even? ? -1 : 1 : 0)
      end
      return unless @marks

      @marks.each { |m| m.opacity = 120 + (Math.sin(@frame / 12.0) * 40).round }
    end

    def refresh_hud
      @squares.each_with_index { |sq, i| sq.src_rect.set(i < @player[:misses] ? 20 : 0, 0, 10, 10) }
      @score_text.text = Dodrio.t("#{@player[:points]} pts", "#{@player[:points]} pts")
      others = @dodrios.reject { |d| d[:player] }.map { |d| "#{d[:name]} #{d[:points]}" }
      @others_text.text = others.join('  ')
    end

    def finish
      @state = :over
      @over = 0
      @big.text = Dodrio.t('Terminé !', 'Finished!')
      Dodrio.play_se('end')
      @berries.each { |b| b[:sprite].dispose }
      @berries.clear
    end

    def update_over
      @over += 1
      update_dodrios
      update_effects
      show_results if @over == 90
    end

    # --- Résultats --------------------------------------------------------------------------------------------------
    def show_results
      @state = :results
      points = @player[:points]
      store = Dodrio.data
      record = points > store['record']
      store['record'] = points if record
      store['played'] += 1
      store['last'] = points
      store['berries'] += @player[:berries].sum
      @result = points
      ranking = @dodrios.sort_by { |d| [-d[:points], d[:player] ? 0 : 1] }
      build do |s|
        s.add_sprite(16, 24, Dodrio.file('panneau'))
        s.add_text(16, 30, 288, 16, Dodrio.t('Résultats', 'Results'), 1, color: DARK)
        ranking.each_with_index do |d, i|
          y = 50 + i * 20
          s.add_text(28, y, 20, 16, "#{i + 1}.", color: DARK)
          s.add_text(46, y, 90, 16, d[:name], color: DARK)
          d[:berries].each_with_index do |count, k|
            berry = s.add_sprite(140 + k * 36, y + 4, Dodrio.file('baies'))
            berry.src_rect.set(k * 8, 0, 8, 9)
            s.with_font(20) { s.add_text(150 + k * 36, y + 2, 26, 13, "×#{count}", color: DARK) }
          end
          s.add_text(248, y, 48, 16, "#{d[:points]}", 2, color: DARK)
        end
        s.with_font(20) do
          s.add_text(28, 116, 264, 13, Dodrio.t("Record : #{store['record']} points", "Record: #{store['record']} points") +
                                       (record ? Dodrio.t('  (nouveau !)', '  (new!)') : ''), color: DARK)
          s.add_text(28, 130, 264, 13, Dodrio.t('A : continuer', 'A: continue'), 1, color: DARK)
        end
        sprite = s.add_sprite(160, 222, Dodrio.file('dodrio'))
        sprite.src_rect.set((ranking.first[:player] ? MIDDLE : TIRED) * 64, 0, 64, 56)
        sprite.set_origin(32, 56)
      end
      @prize_pending = points
    end

    def give_prize(points)
      prize = Dodrio.prize_for(points)
      unless prize
        display_message(Dodrio.t('Pas assez de baies pour un lot cette fois...', 'Not enough berries for a prize this time...'))
        return
      end
      item = prize['item'].to_sym
      count = prize['count']
      $bag.add_item(item, count)
      name = data_item(item).name rescue prize['item']
      display_message(Dodrio.t("#{points} points ! Tu reçois #{count > 1 ? "#{count} " : ''}#{name} !",
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
