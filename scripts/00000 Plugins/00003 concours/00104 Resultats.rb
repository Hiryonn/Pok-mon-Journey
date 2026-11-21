# Concours : écran des résultats
# Barres de l'épreuve visuelle (habillage + condition), de la danse et du jeu d'acteur, places, projecteur sur le gagnant
module Concours
  class ResultsScene < GamePlay::BaseCleanUpdate
    DARK = 0
    WHITE = 10
    ROW_X = 4
    ROW_Y = 24
    ROW_H = 36
    BAR_X = 49
    BAR_W = 216
    # @return [Array<Entrant>] classement
    attr_reader :ranking

    def initialize(type, rank, entrants)
      super()
      @type = type
      @rank = rank
      @entrants = entrants
      @ranking = Concours.ranking(entrants)
      best = @ranking.first.total
      @scale = best > 0 ? BAR_W.to_f / best : 0
      @state = :intro
      @wait = 30
      @phase = 0
    end

    def update_inputs
      return true if (@wait -= 1) > 0

      case @state
      when :intro then intro
      when :bars then update_bars
      when :places then update_places
      when :winner then update_winner
      when :end then @running = false
      end
      return true
    end

    def update_graphics
      @icons&.each(&:update)
      @face&.update
      if @spark_t
        @spark_t += 1
        update_sparkles
      end
      return true
    end

    private

    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport)
      @stack.add_sprite(0, 0, Concours.file('resultats'))
      Concours.add_banner(@stack, @type, @rank, left: Concours.t('Résultats', 'Results'), right: Concours.contest_name(@type, @rank))
      @rows = @entrants.each_with_index.map { |entrant, i| create_row(entrant, i) }
      @shade = @stack.add_sprite(0, 0, Concours.file('projecteur'))
      @shade.opacity = 0
      @face = @stack.push(360, 150, nil, type: UI::PokemonFaceSprite)
      @face.visible = false
      @sparkles = Array.new(8) do |i|
        sprite = @stack.add_sprite(0, 0, Concours.file('etincelles'))
        sprite.src_rect.set((i % 6) * 24, 0, 24, 24)
        sprite.set_origin(12, 12)
        sprite.visible = false
        sprite
      end
      Concours.play_bgm(Concours.setting('results_bgm'))
    end

    def create_row(entrant, index)
      x = ROW_X
      y = ROW_Y + index * ROW_H
      row = { entrant: entrant }
      @stack.add_sprite(x, y, Concours.file('ligne'))
      icon = @stack.push(x + 23, y + 12, nil, type: UI::PokemonIconSprite)
      icon.data = entrant.pokemon
      (@icons ||= []) << icon
      @stack.add_text(x + 50, y + 3, 110, 16, entrant.name, color: DARK)
      @stack.add_text(x + 160, y + 3, 110, 16, entrant.trainer, color: DARK)
      row[:bars] = Array.new(3) do |k|
        bar = @stack.add_sprite(x + BAR_X, y + 20, Concours.file('barres'))
        bar.src_rect.set(0, k * 4, 0, 4)
        bar.visible = false
        bar
      end
      row[:place] = @stack.add_sprite(x + 290, y + 2, Concours.file('places'))
      row[:place].visible = false
      return row
    end

    def intro
      display_message(Concours.t('Voici les résultats de chaque épreuve !', "And now, it's time to announce the results of the individual categories!"))
      @state = :bars
      start_phase(0)
    end

    PHASE_TEXTS = [
      ['D’abord, les résultats de l’épreuve visuelle !', 'First, the results of the Visual Competition!'],
      ['Ensuite, les résultats de l’épreuve de danse !', "Next, let's have the results of the Dance Competition!"],
      ['Enfin, les résultats de l’épreuve de jeu d’acteur !', 'And finally, here are the results of the Acting Competition!']
    ].freeze

    def points(entrant, phase)
      return [entrant.visual, entrant.dance, entrant.acting][phase].to_i
    end

    def start_phase(phase)
      @phase = phase
      display_message(Concours.t(*PHASE_TEXTS[phase]))
      @rows.each do |row|
        offset = (0...phase).sum { |k| (points(row[:entrant], k) * @scale).round }
        bar = row[:bars][phase]
        bar.x = ROW_X + BAR_X + offset
        bar.src_rect.width = 0
        bar.visible = true
      end
      @grow = 0
      Concours.play_se('concours_roulement')
      Concours.play_se('concours_total')
    end

    def update_bars
      @grow += 2
      done = true
      @rows.each do |row|
        target = (points(row[:entrant], @phase) * @scale).round
        width = [@grow, target].min
        row[:bars][@phase].src_rect.width = width
        done = false if width < target
      end
      return unless done

      Concours.play_se('concours_total_fin')
      @wait = 40
      if @phase < 2
        start_phase(@phase + 1)
      else
        @state = :places
        @place = 3
        @wait = 30
      end
    end

    # Places de la 4e à la 1re
    def update_places
      entrant = @ranking[@place]
      row = @rows.find { |r| r[:entrant].equal?(entrant) }
      row[:place].src_rect.set(0, @place * 14, 14, 14)
      row[:place].visible = true
      Concours.play_se('concours_choix')
      @wait = 40
      @place -= 1
      return if @place >= 0

      winner = @ranking.first
      display_message(Concours.t("#{Concours.setting('mc_name')} : Le gagnant est... l’entrée n° #{winner.number} !",
                                 "#{Concours.setting('mc_name')}: The winner is... Entry number #{winner.number}!"))
      Concours.play_bgm(Concours.setting('winner_bgm'))
      @face.data = winner.pokemon
      @face.set_position(380, 160)
      @face.visible = true
      @state = :winner
      @time = 0
      @wait = 1
    end

    # Étincelles autour du gagnant (elles apparaissent tour à tour et scintillent)
    SPARKLE_SPOTS = [[-62, -50], [58, -58], [-78, 4], [74, -6], [-50, 46], [64, 40], [-14, -72], [12, 62]].freeze

    def update_sparkles
      @sparkles.each_with_index do |sprite, i|
        t = @spark_t - i * 4
        next sprite.visible = false if t < 0

        dx, dy = SPARKLE_SPOTS[i]
        phase = (t % 48) / 48.0
        sprite.visible = true
        sprite.set_position(160 + dx, 150 + dy + (Math.sin((t + i * 7) / 10.0) * 2).round)
        sprite.opacity = (120 + 135 * Math.sin(phase * Math::PI)).round
        sprite.zoom = 0.7 + 0.4 * Math.sin(phase * Math::PI) if sprite.respond_to?(:zoom=)
      end
    end

    def update_winner
      @time += 1
      @spark_t ||= 0 if @time > 24
      @shade.opacity = (@time * 12).clamp(0, 255)
      @face.x = [380 - @time * 8, 160].max
      if @time == 30
        Audio.se_play(@ranking.first.pokemon.cry) rescue nil
      elsif @time == 40
        winner = @ranking.first
        display_message(Concours.t("#{winner.trainer} et #{winner.name} ! Félicitations !", "#{winner.trainer} and #{winner.name}! Congratulations!"))
        @state = :end
        @wait = 60
      end
    end
  end
end
