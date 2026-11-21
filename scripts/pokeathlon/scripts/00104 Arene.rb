# Pokéathlon : outils des épreuves vues de dessus (Capture de fanions, Pousse-cercle, Tir au but, Bataille de neige,
# Attrape-disques, Anneau)
#
# Acteur : un athlète sur le terrain (corps rond + sprite). Le joueur dirige l'acteur choisi (flèches, ou clic de la
# souris : il va vers le point cliqué) ; B change de Pokémon quand l'épreuve le permet.
module Pokeathlon
  class Actor
    attr_reader :athlete, :body, :sprite
    attr_accessor :stamina, :state, :timer, :target, :carry, :dazed, :cool, :data

    def initialize(athlete, body, sprite)
      @athlete = athlete
      @body = body
      @sprite = sprite
      @stamina = 1.0
      @state = :idle
      @timer = 0
      @carry = 0
      @dazed = 0
      @cool = 0
      @data = {}
    end

    def team
      return @athlete.team
    end

    def stat(name)
      return @athlete.stat(name)
    end

    def f(name, lo, hi)
      return @athlete.f(name, lo, hi)
    end

    # Vitesse maximale (Vitesse, fatigue)
    def max_speed(lo = 1.1, hi = 2.3)
      tired = @stamina < 0.15 ? 0.55 : 1.0
      return f('speed', lo, hi) * tired
    end

    def accel
      return f('speed', 0.18, 0.32)
    end

    # Masse (Force)
    def mass
      return f('power', 0.9, 1.8)
    end
  end

  module Arena
    private

    # Crée un acteur
    def make_actor(athlete, x, y, radius = 9, friction = 0.86)
      body = Body.new(x, y, radius, athlete.f('power', 0.9, 1.8), friction)
      sprite = add_pokemon(athlete.pokemon, athlete.team.index)
      actor = Actor.new(athlete, body, sprite)
      body.owner = actor
      return actor
    end

    # Le joueur dirige un acteur (flèches ou souris)
    def drive(actor, ctrl, max = actor.max_speed, accel = actor.accel)
      if ctrl.dir?
        actor.target = nil
        len = Math.hypot(ctrl.dx, ctrl.dy)
        actor.body.push(ctrl.dx / len * accel, ctrl.dy / len * accel)
        actor.body.limit(max)
      elsif ctrl.click || ctrl.click_hold
        actor.target = [ctrl.mouse_x, ctrl.mouse_y]
      end
      return unless actor.target

      actor.body.seek(*actor.target, accel, max)
      actor.target = nil if Math.hypot(actor.target[0] - actor.body.x, actor.target[1] - actor.body.y) < 4
    end

    # Fatigue : se vide en bougeant, se remplit au repos (Endurance)
    def tire(actor, moving_cost = 1.0)
      drain = 0.0012 * moving_cost * (6 - actor.stat('stamina')) / 3.0
      if actor.body.speed > 0.4
        actor.stamina = (actor.stamina - drain * actor.body.speed).clamp(0.0, 1.0)
      else
        actor.stamina = (actor.stamina + 0.004).clamp(0.0, 1.0)
      end
    end

    # Repos des Pokémon sur le banc
    def rest(actor)
      actor.stamina = (actor.stamina + actor.f('stamina', 0.003, 0.006)).clamp(0.0, 1.0)
    end

    # Met à jour le sprite d'un acteur
    def draw_actor(actor, z_base = 100)
      body = actor.body
      actor.sprite.visible = body.active
      actor.sprite.move_to(body.x, body.y, body.vx, body.vy, z_base)
      actor.sprite.opacity = actor.dazed > 0 && (actor.dazed / 4).odd? ? 120 : 255
    end

    # Flèche au-dessus du Pokémon dirigé par le joueur
    def create_cursor
      @cursor = add_sprite('curseur', 0, 0, 8000)
      @cursor.set_origin(@cursor.bitmap.width / 2, @cursor.bitmap.height)
    end

    def draw_cursor(actor)
      return unless @cursor

      @cursor.visible = actor && actor.body.active
      return unless @cursor.visible

      @cursor.set_position(actor.body.x.round, (actor.body.y - 28 + Math.sin(@frame / 6.0) * 2).round)
    end

    # Jauge d'endurance du Pokémon dirigé (en bas à gauche)
    def create_stamina_gauge
      @gauge_back = add_sprite('jauge_fond', 4, 206, 8500)
      @gauge = add_sprite('jauge', 6, 208, 8501)
    end

    def draw_stamina(actor)
      return unless @gauge && actor

      w = (actor.stamina * 60).round.clamp(0, 60)
      @gauge.src_rect.set(0, 0, w, 6)
    end
  end
end
