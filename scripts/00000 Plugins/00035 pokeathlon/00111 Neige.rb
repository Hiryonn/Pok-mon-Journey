# Pokéathlon : Bataille de neige
#
# Chaque équipe tient un bord du terrain (le joueur en bas). Gauche / droite : déplacer le Pokémon choisi (B : le
# suivant) ; haut / bas : choisir la cible ; A : lancer (ou clic : lancer vers ce point). Un Pokémon touché est étourdi
# un moment et rapporte 1 point au lanceur. Les coéquipiers lancent seuls, moins souvent.
# Force : vitesse de la boule ; Technique : précision ; Endurance : temps entre deux lancers ; Vitesse : esquive.
module Pokeathlon
  module Events
    class Snow < Event
      include Arena
      # Bord de chaque équipe : axe de déplacement (:x / :y), position fixe, limites
      SIDES = [[:x, 204, 60, 260], [:y, 22, 50, 194], [:x, 40, 60, 260], [:y, 298, 50, 194]].freeze

      private

      def help_text
        return Pokeathlon.t('Gauche / Droite : bouger   Haut / Bas : cible   A : lancer   B : changer', 'Left / Right: move   Up / Down: target   A: throw   B: switch')
      end

      def setup
        add_sprite('terrain_neige', 0, 22, -100)
        @balls = []
        @actors = []
        @teams.each do |team|
          axis, fixed, lo, hi = SIDES[team.index]
          list = team.athletes.each_with_index.map do |a, i|
            pos = lo + (hi - lo) * (i + 0.5) / 3
            x, y = axis == :x ? [pos, fixed] : [fixed, pos]
            actor = make_actor(a, x, y)
            actor.cool = 60 + rand(60)
            actor
          end
          team.data[:list] = list
          team.data[:sel] = 1
          @actors.concat(list)
        end
        @target_index = 0
        @target_mark = add_sprite('cible', 0, 0, 8000)
        @target_mark.set_origin(@target_mark.bitmap.width / 2, @target_mark.bitmap.height / 2)
        create_cursor
        create_stamina_gauge
      end

      def selected
        return player.data[:list][player.data[:sel]]
      end

      def opponents
        return @actors.reject { |a| a.team.player? }
      end

      def update_play(ctrl)
        player.data[:sel] = (player.data[:sel] + 1) % 3 if ctrl.b
        if ctrl.dy != 0 && @frame % 8 == 0
          @target_index = (@target_index + ctrl.dy) % opponents.size
        end
        @actors.each do |actor|
          actor.cool -= 1 if actor.cool > 0
          actor.dazed -= 1 if actor.dazed > 0
          if actor == selected
            control_player(actor, ctrl)
          else
            ai(actor)
          end
          keep_on_side(actor)
          actor.stamina = 1 - (actor.cool / 120.0).clamp(0, 1)
        end
        @balls.each { |ball| move_ball(ball) }
        @balls.reject! { |ball| ball[:done] && (ball[:sprite].dispose || true) && (ball[:shadow].dispose || true) }
      end

      def control_player(actor, ctrl)
        axis, = SIDES[0]
        speed = actor.f('speed', 1.2, 2.2)
        actor.body.vx = ctrl.dx * speed if axis == :x
        if ctrl.click && actor.cool <= 0 && actor.dazed <= 0
          throw_ball(actor, ctrl.mouse_x, ctrl.mouse_y)
        elsif ctrl.a && actor.cool <= 0 && actor.dazed <= 0
          target = opponents[@target_index % opponents.size]
          lead = 10
          throw_ball(actor, target.body.x + target.body.vx * lead, target.body.y + target.body.vy * lead)
        end
      end

      def keep_on_side(actor)
        axis, fixed, lo, hi = SIDES[actor.team.index]
        body = actor.body
        if axis == :x
          body.x = (body.x + body.vx).clamp(lo, hi)
          body.y = fixed
          body.vy = 0
        else
          body.y = (body.y + body.vy).clamp(lo, hi)
          body.x = fixed
          body.vx = 0
        end
        body.vx *= 0.8
        body.vy *= 0.8
      end

      def ai(actor)
        axis, = SIDES[actor.team.index]
        speed = actor.f('speed', 1.2, 2.2) * (0.7 + @difficulty * 0.1)
        # esquive : une boule va tomber près de lui
        danger = @balls.find { |b| !b[:done] && b[:team] != actor.team && Math.hypot(b[:tx] - actor.body.x, b[:ty] - actor.body.y) < 18 && b[:left] < 25 + @difficulty * 8 }
        if danger && actor.dazed <= 0
          away = axis == :x ? (actor.body.x < danger[:tx] ? -1 : 1) : (actor.body.y < danger[:ty] ? -1 : 1)
          axis == :x ? actor.body.vx = away * speed : actor.body.vy = away * speed
        elsif chance(50)
          actor.data[:wander] = rand(-1..1)
        end
        if actor.data[:wander] && !danger
          axis == :x ? actor.body.vx = actor.data[:wander] * speed * 0.5 : actor.body.vy = actor.data[:wander] * speed * 0.5
        end
        return if actor.cool > 0 || actor.dazed > 0

        rate = actor.team.player? ? 90 : 70 - @difficulty * 10
        return unless chance(rate)

        targets = @actors.reject { |o| o.team == actor.team || o.dazed > 0 }
        target = targets.min_by { |o| o.body.dist(actor.body) + rand * 160 }
        return unless target

        throw_ball(actor, target.body.x + target.body.vx * 12, target.body.y + target.body.vy * 12)
      end

      def throw_ball(actor, tx, ty)
        spread = actor.f('skill', 16, 4)
        tx += (rand * 2 - 1) * spread
        ty += (rand * 2 - 1) * spread
        dist = Math.hypot(tx - actor.body.x, ty - actor.body.y)
        speed = actor.f('power', 2.4, 4.0)
        frames = (dist / speed).ceil.clamp(8, 120)
        sprite = add_sprite('boule', 0, 0, 7000)
        sprite.set_origin(4, 4)
        shadow = add_sprite('ombre_boule', 0, 0, 50)
        shadow.set_origin(4, 2)
        @balls << { team: actor.team, x0: actor.body.x, y0: actor.body.y - 10, tx: tx, ty: ty, total: frames, left: frames,
                    sprite: sprite, shadow: shadow, done: false, owner: actor }
        actor.cool = actor.f('stamina', 80, 40).round
        Pokeathlon.play_se('throw') if actor.team.player?
      end

      def move_ball(ball)
        return if ball[:done]

        ball[:left] -= 1
        return unless ball[:left] <= 0

        ball[:done] = true
        hit = @actors.find do |o|
          o.team != ball[:team] && o.dazed <= 0 && Math.hypot(o.body.x - ball[:tx], o.body.y - ball[:ty]) < 13
        end
        return unless hit

        hit.dazed = 90
        ball[:team].score += 1
        popup(hit.body.x, hit.body.y - 30, '+1') if ball[:team].player?
        Pokeathlon.play_se('hit') if ball[:team].player? || hit.team.player?
      end

      def update_sprites
        @actors.each { |actor| draw_actor(actor) }
        @balls.each do |ball|
          t = 1 - ball[:left] / ball[:total].to_f
          x = ball[:x0] + (ball[:tx] - ball[:x0]) * t
          y = ball[:y0] + (ball[:ty] - ball[:y0]) * t
          height = Math.sin(Math::PI * t) * [ball[:total] * 0.8, 40].min
          ball[:sprite].set_position(x.round, (y - height).round)
          ball[:shadow].set_position(x.round, y.round)
        end
        target = opponents[@target_index % opponents.size]
        @target_mark.set_position(target.body.x.round, (target.body.y - 8).round)
        @target_mark.angle = (@frame * 3) % 360
        draw_cursor(selected)
        draw_stamina(selected)
      end
    end
  end
end
