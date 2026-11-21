# Sac de frappe : l'écran du jeu (aux couleurs de l'interface Horizon)
#
# En haut, la salle : le Pokémon (de dos) devant le sac. En bas, le bandeau : étoiles du dernier coup, score et nombre
# de coups, jauge avec la flèche qui va et vient. A fige la flèche : le Pokémon s'élance, frappe, et le sac balance
# d'autant plus que le coup est bon (5 étoiles au centre, une de moins tous les 8 pixels, au moins 1).
module GamePlay
  class SacDeFrappe < BaseCleanUpdate::FrameBalanced
    S = ::SacDeFrappe
    WHITE = 9
    DARK = 0
    SMALL = 20
    # Jauge : demi-largeur utile (pixels), pixels par étoile perdue, étoiles max / min
    BAR_LEFT_SIZE = 64
    SCORE_DISTANCE = 8
    MAX_SCORE = 5
    MIN_SCORE = 1
    # Sac : vitesses (degrés par seconde) et angles atteints selon le coup
    BAG_SPEEDS = [80, 120, 160].freeze
    BAG_ANGLES = [0, 16, 32, 64].freeze
    # Pokémon : vitesse (pixels par seconde) et distance de l'élan ; pause entre deux mouvements (secondes)
    POKEMON_SPEED = 320
    POKEMON_DISTANCE = 32
    WAIT_TIME = 0.2
    # Positions (graphismes : tools/sac_de_frappe/build_assets.py)
    HUD_Y = 148
    BAG_X = 180
    BAG_Y = 12
    POKEMON_X = 112
    POKEMON_Y = 172
    STAR_Y = 155
    BAR_X = 148
    BAR_Y = 198
    ARROW_Y = 183

    # @return [Integer, nil] score final (nil : partie arrêtée)
    attr_reader :result

    # @param pokemon [PFM::Pokemon]
    # @param rounds [Integer] nombre de coups
    # @param can_cancel [Boolean] B arrête la partie
    # @param title [String, nil] titre du bandeau
    # @param bag [String, nil] sac (SacDeFrappe::BAGS ; nil : le sac d'origine)
    def initialize(pokemon, rounds = 10, can_cancel = true, title = nil, bag = nil)
      super()
      @bag_name = bag
      @pokemon = pokemon
      @rounds = rounds.to_i.clamp(1, 99)
      @can_cancel = can_cancel
      @title = title
      @result = nil
      @score = 0
      @last_score = 0
      @shots = 0
      @end_game = false
      @time = 0.0
      @arrow_speed = [S.setting('arrow_speed').to_f, 40.0].max
      @right = false
      # Sac
      @next_angle = 0
      @last_angle = 0
      @angle_direction = 1
      @bag_speed_index = 0
      @bag_animating = false
      @bag_wait = 0
      @score_computed = true
      # Pokémon
      @pokemon_animating = false
      @pokemon_wait = 0
      @pokemon_x = POKEMON_X.to_f
    end

    def update_inputs
      return false if @end_game

      if Input.trigger?(:B) && @can_cancel
        play_cancel_se
        choice = display_message(S.t("Arrêter l'entraînement ?", 'Stop training?'), 1, S.t('Oui', 'Yes'), S.t('Non', 'No'))
        if choice == 0
          @result = nil
          @running = false
        end
        @last_clock = nil
        return false
      end
      punch if (Input.trigger?(:A) || Mouse.trigger?(:LEFT)) && @last_score == 0
      return true
    end

    def update_graphics
      dt = clock
      @time += dt
      @pokemon_sprite&.update
      update_arrow(dt) unless @end_game
      update_animation(dt)
      finish if @end_game && !animating?
      return true
    end

    private

    # Temps écoulé depuis la dernière image (secondes)
    def clock
      now = Graphics.current_time
      dt = @last_clock ? (now - @last_clock).to_f : 0.0
      @last_clock = now
      return dt.clamp(0.0, 0.1)
    end

    # --- Jauge -----------------------------------------------------------------------------------
    def arrow_middle
      return BAR_X + @bar.width / 2 - @arrow.width / 2
    end

    def update_arrow(dt)
      @right = true if @arrow_x <= arrow_middle - BAR_LEFT_SIZE
      @right = false if @arrow_x >= arrow_middle + BAR_LEFT_SIZE
      @arrow_x += (@right ? @arrow_speed : -@arrow_speed) * dt
      @arrow.x = @arrow_x.round
    end

    # A : fige la flèche et calcule le coup
    def punch
      distance = BAR_LEFT_SIZE - (@arrow_x - arrow_middle).abs
      @last_score = [((distance - BAR_LEFT_SIZE) / SCORE_DISTANCE.to_f + MAX_SCORE).round, MIN_SCORE].max
      @arrow.visible = false
    end

    # --- Animation -------------------------------------------------------------------------------
    def animating?
      return @pokemon_animating || @bag_animating
    end

    def update_animation(dt)
      start_animation if !animating? && @last_score != 0 && @score_computed
      update_bag(dt) if @bag_animating
      update_pokemon(dt) if @pokemon_animating
    end

    def start_animation
      from_max = @last_score - MAX_SCORE
      @next_angle = case from_max
                    when 0 then BAG_ANGLES[3]
                    when -1 then BAG_ANGLES[2]
                    when -2 then BAG_ANGLES[1]
                    else BAG_ANGLES[0]
                    end
      @angle_direction = 1
      @bag_speed_index = from_max == 0 ? 2 : 0
      @pokemon_animating = true
      @pokemon_speed = POKEMON_SPEED.to_f
      @pokemon_x = @pokemon_x.floor.to_f
      @pokemon_target = @pokemon_x + POKEMON_DISTANCE
      @score_computed = false
    end

    def update_bag(dt)
      return if @bag_wait > @time

      angle = @bag.angle
      angle = @next_angle if reached?(angle, @next_angle, @angle_direction)
      if angle == @next_angle
        if @next_angle == 0
          if @bag_speed_index > 0
            @next_angle = -BAG_ANGLES[-2]
          else
            @bag_animating = false
          end
        else
          @next_angle = @next_angle < 0 ? BAG_ANGLES[-3] : 0
          @bag_wait = @time + WAIT_TIME - 0.001
          compute_score unless @score_computed
        end
        @angle_direction = @next_angle > angle ? 1 : -1
      else
        # La vitesse baisse à chaque passage au milieu
        @bag_speed_index -= 1 if (@last_angle < 0) != (angle < 0) && @bag_speed_index != 0
        @last_angle = angle
        angle += BAG_SPEEDS[@bag_speed_index] * @angle_direction * dt
      end
      @bag.angle = angle
    end

    def update_pokemon(dt)
      return if @pokemon_wait > @time

      @pokemon_x += @pokemon_speed * dt
      if reached?(@pokemon_x, @pokemon_target, @pokemon_speed)
        @pokemon_x = @pokemon_target
        if @pokemon_speed > 0
          # Le coup touche le sac
          hit_se
          if @next_angle == 0
            compute_score
          else
            @bag_animating = true
          end
          @pokemon_speed /= -2
          @pokemon_target = @pokemon_x - POKEMON_DISTANCE
          @pokemon_wait = @time + WAIT_TIME - 0.001
        else
          @pokemon_animating = false
        end
      end
      @pokemon_sprite.x = @pokemon_x.floor if @pokemon_sprite
    end

    # >= qui marche aussi dans le sens négatif
    def reached?(value, target, sign)
      return sign < 0 ? value <= target : value >= target
    end

    # Le score compte quand le sac s'arrête en l'air pour la première fois
    def compute_score
      @shots += 1
      @end_game = true if @shots >= @rounds
      @score += @last_score
      play_se(S.setting('perfect_se')) if @last_score == MAX_SCORE
      show_stars(@last_score)
      @last_score = 0
      @score_computed = true
      @arrow.visible = !@end_game
      refresh_texts
    end

    def hit_se
      list = Array(S.setting('hit_se'))
      index = case @last_score - MAX_SCORE
              when -1, 0 then 2
              when -2 then 1
              else 0
              end
      play_se(list[index] || list.last)
    end

    def play_se(name)
      return if name.to_s.empty?

      Audio.se_play(name.to_s)
    rescue StandardError
      nil
    end

    # Fin : le score s'affiche puis la scène se ferme
    def finish
      return if @finished

      @finished = true
      @help.text = ''
      display_message(S.t("Score final : #{@score} !", "Final score: #{@score}!"))
      @result = @score
      @running = false
    end

    # --- Graphismes ------------------------------------------------------------------------------
    def create_graphics
      super
      @base = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @base.add_sprite(0, 0, 'horizon/team/fond') if RPG::Cache.interface_exist?('horizon/team/fond')
      @base.add_sprite(0, 0, S.file('bg'))
      @bag = @base.add_sprite(BAG_X, BAG_Y, S.bag_file(@bag_name))
      @bag.set_origin(@bag.width / 2, 0)
      @bag.y = BAG_Y - [@bag.height - 128, 0].max # les sacs de X / Y sont un peu plus longs
      @bag.angle = 0
      create_pokemon
      @base.add_sprite(0, 0, 'horizon/header') if RPG::Cache.interface_exist?('horizon/header')
      @base.add_sprite(0, HUD_Y, S.file('hud'))
      @base.add_sprite(0, 214, 'horizon/tcard/button_background') if RPG::Cache.interface_exist?('horizon/tcard/button_background')
      @base.add_text(80, 5, 160, 16, (@title || S.t('Sac de frappe', 'Punching bag')).upcase, 1, color: WHITE)
      @stars = Array.new(MAX_SCORE) do |i|
        cx = 4 + 312 * (2 * i + 1) / 10
        [@base.add_sprite(cx - 12, STAR_Y, S.file('star_empty')), @base.add_sprite(cx - 12, STAR_Y, S.file('star'))]
      end
      @bar = @base.add_sprite(BAR_X, BAR_Y, S.file('bar'))
      @arrow = @base.add_sprite(0, ARROW_Y, S.file('arrow'))
      @arrow_x = (arrow_middle - BAR_LEFT_SIZE).to_f
      @arrow.x = @arrow_x.round
      @score_text = @base.add_text(12, HUD_Y + 36, 92, 16, '', color: DARK)
      @shots_text = @base.add_text(12, HUD_Y + 48, 92, 16, '', color: DARK)
      @base.with_font(SMALL) do
        help = @can_cancel ? S.t('A : Frapper    B : Arrêter', 'A: Punch    B: Stop') : S.t('A : Frapper', 'A: Punch')
        @help = @base.add_text(8, 220, 304, 13, help, 1, color: WHITE)
      end
      show_stars(0)
      refresh_texts
    end

    def create_pokemon
      @pokemon_sprite = UI::PokemonBackSprite.new(@viewport)
      @pokemon_sprite.data = @pokemon
      @pokemon_sprite.set_position(POKEMON_X, POKEMON_Y)
    rescue StandardError => e
      log_error("Sac de frappe : sprite du Pokémon (#{e.message})") if respond_to?(:log_error, true)
      @pokemon_sprite = nil
    end

    def show_stars(count)
      @stars.each_with_index { |(_, star), i| star.visible = i < count }
    end

    def refresh_texts
      @score_text.text = S.t("Score : #{@score}", "Score: #{@score}")
      @shots_text.text = S.t("Coups : #{@shots}/#{@rounds}", "Hits: #{@shots}/#{@rounds}")
    end
  end
end
