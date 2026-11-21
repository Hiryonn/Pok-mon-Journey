# Pokéathlon : moteur des épreuves (équipes, commandes, physique, sprites, bandeau)
#
# Une épreuve (classe dérivée de Pokeathlon::Event) :
#   setup            crée le décor et les acteurs
#   update_play(c)   une image de jeu (c : commandes du joueur, Pokeathlon::Ctrl)
#   finished?        fin avant le temps (ex. : tous arrivés)
#   score_text(s)    affichage d'un score
# Déroulement : compte à rebours (3, 2, 1, Partez !), jeu jusqu'à la fin du temps, « Terminé ! », puis done.
# Les équipes 1 à 3 sont jouées par l'ordinateur (difficulté du réglage difficulty).
module Pokeathlon
  FPS = 60

  # Pokémon d'une équipe, avec ses performances du jour
  class Athlete
    attr_reader :pokemon, :team, :index, :perf

    def initialize(pokemon, team, index)
      @pokemon = pokemon
      @team = team
      @index = index
      @perf = Pokeathlon.performance(pokemon)
    end

    # @return [Integer] étoiles (1 à 5)
    def stat(name)
      return @perf[name.to_s].to_i.clamp(1, 5)
    end

    # Valeur entre lo (1 étoile) et hi (5 étoiles)
    def f(name, lo, hi)
      return lo + (hi - lo) * (stat(name) - 1) / 4.0
    end

    def name
      return @pokemon.given_name
    end
  end

  # Équipe : nom, couleur, 3 athlètes, score
  class Team
    attr_reader :index, :name, :athletes
    attr_accessor :score, :data

    def initialize(index, name, pokemons)
      @index = index
      @name = name
      @athletes = pokemons.each_with_index.map { |pk, i| Athlete.new(pk, self, i) }
      @score = 0
      @data = {}
    end

    def player?
      return @index == 0
    end

    def color
      return TEAM_COLORS[@index]
    end
  end

  # Commandes du joueur pour une image
  class Ctrl
    attr_reader :dx, :dy, :a, :a_hold, :b, :b_hold, :mouse_x, :mouse_y, :click, :click_hold, :a_release

    def self.read(previous = nil)
      ctrl = new
      ctrl.read(previous)
      return ctrl
    end

    def read(previous)
      @dx = (Input.press?(:RIGHT) ? 1 : 0) - (Input.press?(:LEFT) ? 1 : 0)
      @dy = (Input.press?(:DOWN) ? 1 : 0) - (Input.press?(:UP) ? 1 : 0)
      @a = Input.trigger?(:A)
      @a_hold = Input.press?(:A)
      @a_release = previous&.a_hold && !@a_hold
      @b = Input.trigger?(:B)
      @b_hold = Input.press?(:B)
      @mouse_x = Mouse.x
      @mouse_y = Mouse.y
      @click = Mouse.trigger?(:LEFT)
      @click_hold = Mouse.press?(:LEFT)
      @a_release ||= previous&.click_hold && !@click_hold
    end

    # Direction choisie au clavier
    def dir?
      return @dx != 0 || @dy != 0
    end
  end

  # Corps rond pour la physique vue de dessus
  class Body
    attr_accessor :x, :y, :vx, :vy, :r, :mass, :friction, :owner, :active, :last_touch

    def initialize(x, y, r, mass = 1.0, friction = 0.9)
      @x = x.to_f
      @y = y.to_f
      @vx = 0.0
      @vy = 0.0
      @r = r
      @mass = mass
      @friction = friction
      @active = true
    end

    def speed
      return Math.hypot(@vx, @vy)
    end

    # Avance vers (tx, ty) avec une accélération et une vitesse maximale
    def seek(tx, ty, accel, max)
      dx = tx - @x
      dy = ty - @y
      dist = Math.hypot(dx, dy)
      return if dist < 1

      push(dx / dist * accel, dy / dist * accel)
      limit(max)
    end

    def push(ax, ay)
      @vx += ax
      @vy += ay
    end

    # Limite la vitesse (en douceur au-dessus : un Pokémon bousculé garde son élan un moment)
    def limit(max)
      s = speed
      return if s <= max || s == 0

      target = [max, s * 0.9].max
      @vx = @vx / s * target
      @vy = @vy / s * target
    end

    def step
      @x += @vx
      @y += @vy
      @vx *= @friction
      @vy *= @friction
    end

    def dist(other)
      return Math.hypot(other.x - @x, other.y - @y)
    end
  end

  module Physics
    module_function

    # Chocs entre corps ronds (masse : qui pousse qui)
    # @yieldparam a [Body]
    # @yieldparam b [Body]
    # @yieldparam force [Float] vitesse du choc
    def collide(bodies)
      list = bodies.select(&:active)
      list.each_with_index do |a, i|
        list[(i + 1)..].each do |b|
          dx = b.x - a.x
          dy = b.y - a.y
          dist = Math.hypot(dx, dy)
          min = a.r + b.r
          next if dist >= min || dist == 0

          nx = dx / dist
          ny = dy / dist
          overlap = min - dist
          total = a.mass + b.mass
          a.x -= nx * overlap * b.mass / total
          a.y -= ny * overlap * b.mass / total
          b.x += nx * overlap * a.mass / total
          b.y += ny * overlap * a.mass / total
          rel = (a.vx - b.vx) * nx + (a.vy - b.vy) * ny
          next if rel <= 0

          impulse = 1.6 * rel / total
          a.vx -= impulse * b.mass * nx
          a.vy -= impulse * b.mass * ny
          b.vx += impulse * a.mass * nx
          b.vy += impulse * a.mass * ny
          yield(a, b, rel) if block_given?
        end
      end
    end

    # Garde un corps dans un rectangle (rebond)
    def bound(body, left, top, right, bottom, bounce = 0.5)
      if body.x - body.r < left
        body.x = left + body.r
        body.vx = body.vx.abs * bounce
      elsif body.x + body.r > right
        body.x = right - body.r
        body.vx = -body.vx.abs * bounce
      end
      if body.y - body.r < top
        body.y = top + body.r
        body.vy = body.vy.abs * bounce
      elsif body.y + body.r > bottom
        body.y = bottom - body.r
        body.vy = -body.vy.abs * bounce
      end
    end
  end

  # Sprite d'un Pokémon sur le terrain (sprite de la carte : 4 directions, 4 pas)
  class PokemonSprite < ::Sprite
    attr_reader :pokemon

    # @param viewport [Viewport]
    # @param pokemon [PFM::Pokemon]
    # @param team [Integer, nil] couleur de l'anneau (nil : aucun)
    def initialize(viewport, pokemon, team = nil)
      super(viewport)
      @pokemon = pokemon
      self.bitmap = RPG::Cache.character(pokemon.character_name)
      @fw = bitmap.width / 4
      @fh = bitmap.height / 4
      set_origin(@fw / 2, @fh - 4)
      @dir = 0
      @step = 0.0
      @frame = 0
      if team
        @ring = ::Sprite.new(viewport)
        @ring.bitmap = RPG::Cache.interface(Pokeathlon.file("anneau_#{team}"))
        @ring.set_origin(@ring.bitmap.width / 2, @ring.bitmap.height / 2 + 1)
      end
      @marker = nil
      show(0, 0)
    end

    # @param dir [Integer] 0 bas, 1 gauche, 2 droite, 3 haut
    def show(dir, frame)
      @dir = dir
      @frame = frame % 4
      src_rect.set(@frame * @fw, @dir * @fh, @fw, @fh)
    end

    # Place le sprite et l'anime selon son déplacement
    def move_to(x, y, vx = 0, vy = 0, z_base = 0)
      dist = Math.hypot(vx, vy)
      if dist > 0.15
        @dir = vx.abs > vy.abs ? (vx < 0 ? 1 : 2) : (vy < 0 ? 3 : 0)
        @step += dist / 6.0
      else
        @step = 0 if @step % 2 < 0.5
      end
      show(@dir, @step.floor)
      set_position(x.round, y.round)
      self.z = z_base + y.round
      return unless @ring

      @ring.set_position(x.round, y.round)
      @ring.z = self.z - 1
      @ring.visible = visible
    end

    def face(dir)
      show(dir, @frame)
    end

    def visible=(value)
      super
      @ring.visible = value if @ring
    end

    def opacity=(value)
      super
      @ring.opacity = value if @ring
    end

    def dispose
      @ring&.dispose
      super
    end
  end

  # Épreuve
  class Event
    attr_reader :id, :teams, :frame, :viewport
    # Images du compte à rebours
    COUNTDOWN = 3 * FPS + 30
    FINISH = 100

    # @param viewport [Viewport]
    # @param teams [Array<Team>]
    # @param id [String]
    def initialize(viewport, teams, id)
      @viewport = viewport
      @teams = teams
      @id = id
      @setting = Pokeathlon.event_setting(id)
      @difficulty = Pokeathlon.setting('difficulty').to_i.clamp(1, 3)
      @frame = 0
      @time = 0
      @phase = :countdown
      @sprites = []
      @popups = []
      @ctrl = nil
      @done = false
      @teams.each { |team| team.score = 0; team.data = {} }
      setup
      create_hud
      update_hud
    end

    def done?
      return @done
    end

    # @return [Integer] durée en images
    def time_limit
      return (@setting['time'].to_f * FPS).round.clamp(10 * FPS, 300 * FPS)
    end

    # Temps restant en secondes
    def time_left
      return [(time_limit - @time) / FPS.to_f, 0].max
    end

    def player
      return @teams[0]
    end

    # Une image
    def update
      @frame += 1
      case @phase
      when :countdown then update_countdown
      when :play then update_playing
      when :finish then update_finish
      end
      update_popups
      update_hud
    end

    # Classement : équipes du meilleur au moins bon
    def ranking
      lower = LOWER_IS_BETTER.include?(@id)
      return @teams.sort_by { |team| [lower ? team.score : -team.score, team.index] }
    end

    def score_text(score)
      return score.to_i.to_s
    end

    def dispose
      @sprites.each { |s| s.dispose unless s.disposed? }
      @sprites.clear
      @popups.each { |p| p[0].dispose unless p[0].disposed? }
      @popups.clear
    end

    private

    # --- À définir dans les épreuves --------------------------------------------------------------------------------
    def setup; end

    def update_play(_ctrl); end

    def finished?
      return false
    end

    # Dernière image du jeu (scores finaux)
    def end_play; end

    # Bulle d'aide en bas (commandes)
    def help_text
      return ''
    end

    # --- Déroulement ------------------------------------------------------------------------------------------------
    def update_countdown
      update_sprites
      left = COUNTDOWN - @frame
      @big.visible = true
      if left > 30
        n = (left - 30) / FPS + 1
        @big.bitmap = RPG::Cache.interface(Pokeathlon.file("compte_#{n.clamp(1, 3)}"))
      else
        @big.bitmap = RPG::Cache.interface(Pokeathlon.file('partez'))
      end
      @big.set_origin(@big.bitmap.width / 2, @big.bitmap.height / 2)
      @big.zoom = 1.0 + (((left - 30) % FPS) / FPS.to_f) * 0.3 if left > 30
      Pokeathlon.play_se('pokeathlon_bip') if left > 30 && (left - 30) % FPS == 0
      return unless left <= 0

      @big.visible = false
      @phase = :play
      Pokeathlon.play_se('pokeathlon_go')
    end

    def update_playing
      @ctrl = Ctrl.read(@ctrl)
      update_play(@ctrl)
      update_sprites
      @time += 1
      return unless @time >= time_limit || finished?

      end_play
      @phase = :finish
      @finish_frame = @frame
      @big.bitmap = RPG::Cache.interface(Pokeathlon.file('termine'))
      @big.set_origin(@big.bitmap.width / 2, @big.bitmap.height / 2)
      @big.zoom = 1
      @big.visible = true
      Pokeathlon.play_se('pokeathlon_fin')
    end

    def update_finish
      update_sprites
      @done = true if @frame - @finish_frame >= FINISH
    end

    def update_sprites; end

    # --- Aides ------------------------------------------------------------------------------------------------------
    def add_sprite(file, x = 0, y = 0, z = 0)
      sprite = ::Sprite.new(@viewport)
      sprite.bitmap = RPG::Cache.interface(Pokeathlon.file(file)) if file
      sprite.set_position(x, y)
      sprite.z = z
      @sprites << sprite
      return sprite
    end

    def add_text(x, y, w, h, text, align = 0, color = 9, z = 5000)
      t = ::Text.new(0, @viewport, x, y - Text::Util::FOY, w, h, text.to_s, align, nil, color)
      t.z = z
      @sprites << t
      return t
    end

    def add_pokemon(pokemon, team = nil)
      sprite = PokemonSprite.new(@viewport, pokemon, team)
      @sprites << sprite
      return sprite
    end

    # Petit texte qui monte (« +1 »)
    def popup(x, y, text, color = 9)
      t = ::Text.new(0, @viewport, x - 30, y - Text::Util::FOY, 60, 16, text.to_s, 1, nil, color)
      t.z = 6000
      @popups << [t, 40]
    end

    def update_popups
      @popups.each do |entry|
        entry[1] -= 1
        entry[0].y -= 0.5
        entry[0].opacity = (entry[1] * 255 / 20).clamp(0, 255)
      end
      @popups.reject! do |entry|
        next false if entry[1] > 0

        entry[0].dispose
        true
      end
    end

    # Chance à chaque image (événement moyen toutes les n images)
    def chance(frames)
      return rand(frames.to_i.clamp(1, 100_000)).zero?
    end

    # Erreur de l'ordinateur selon la difficulté (plus petit = plus précis)
    def ai_error(scale)
      return (rand * 2 - 1) * scale * (4 - @difficulty) / 2.0
    end

    # --- Bandeau ----------------------------------------------------------------------------------------------------
    def create_hud
      @hud = add_sprite('bandeau', 0, 0, 9000)
      @hud_scores = @teams.map do |team|
        x = 4 + team.index * 62 + (team.index >= 2 ? 72 : 0)
        add_sprite("pastille_#{team.index}", x, 3, 9001)
        add_text(x + 14, 4, 46, 14, '', 0, 9, 9002)
      end
      @hud_time = add_text(130, 4, 60, 14, '', 1, 9, 9002)
      @help = add_text(0, 226, 320, 14, help_text, 1, 9, 9002)
      @help_bg = add_sprite('aide', 0, 224, 9000)
      @help_bg.visible = @help.visible = !help_text.empty?
      @big = add_sprite(nil, 160, 120, 9500)
      @big.visible = false
    end

    def update_hud
      @teams.each_with_index { |team, i| @hud_scores[i].text = score_text(team.score) }
      left = time_left.ceil
      @hud_time.text = format('%<m>d:%<s>02d', m: left / 60, s: left % 60)
    end
  end

  module_function

  # Bruitages (audio/se de RPG Maker XP)
  SOUNDS = {
    'bip' => '002-system02', 'go' => '055-right01', 'fin' => '059-applause01', 'hit' => '040-knock01',
    'jump' => '015-jump01', 'point' => '056-right02', 'miss' => '057-wrong01', 'smash' => '048-explosion01',
    'throw' => '062-swing01', 'push' => '045-push01', 'switch' => '032-switch01', 'cheer' => '060-cheer01'
  }.freeze

  def play_se(name)
    file = SOUNDS[name.to_s.sub('pokeathlon_', '')] || name.to_s
    Audio.se_play("audio/se/#{file}")
  rescue StandardError
    nil
  end

  # Épreuves : identifiant -> classe
  def event_class(id)
    name = { 'hurdle' => :Hurdle, 'pennant' => :Pennant, 'relay' => :Relay, 'block' => :Block, 'circle' => :Circle,
             'goal' => :Goal, 'snow' => :Snow, 'lamp' => :Lamp, 'disc' => :Disc, 'ring' => :Ring }[id.to_s]
    return name && Events.const_defined?(name) ? Events.const_get(name) : nil
  end

  module Events; end
end
