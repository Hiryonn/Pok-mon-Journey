# Pokéathlon : Tir au but
#
# Quatre buts (un par équipe, sur chaque bord). On pousse les ballons dans les buts adverses : +1 pour l'équipe qui a
# touché le ballon en dernier, -1 pour l'équipe dont c'est le but. Le ballon doré (dernier tiers du temps) vaut 2.
# Le joueur dirige un de ses trois Pokémon (B : le suivant) ; les autres jouent seuls (un gardien, deux attaquants).
# Force : puissance du tir ; Technique : précision ; Vitesse : course ; Endurance : fatigue.
module Pokeathlon
  module Events
    class Goal < Event
      include Arena
      LEFT = 8
      TOP = 26
      RIGHT = 312
      BOTTOM = 218
      HALF_GOAL = 34
      # But de chaque équipe : centre et côté
      GOALS = [[160, BOTTOM, :bottom], [LEFT, 122, :left], [160, TOP, :top], [RIGHT, 122, :right]].freeze

      private

      def help_text
        return Pokeathlon.t('Flèches / clic : pousser les ballons dans les buts adverses   B : changer', 'Arrows / click: push balls into the other goals   B: switch')
      end

      def setup
        add_sprite('terrain_buts', 0, 22, -100)
        @balls = []
        2.times { |i| add_ball(140 + i * 40, 122, false) }
        @gold_added = false
        @actors = []
        @teams.each do |team|
          gx, gy, = GOALS[team.index]
          list = team.athletes.each_with_index.map do |a, i|
            x = gx + (gx == 160 ? (i - 1) * 40 : (gx < 160 ? 30 + i * 10 : -30 - i * 10))
            y = gy + (gy == 122 ? (i - 1) * 40 : (gy < 122 ? 30 + i * 10 : -30 - i * 10))
            actor = make_actor(a, x, y)
            actor.data[:role] = i == 0 ? :keeper : :striker
            actor
          end
          team.data[:list] = list
          team.data[:sel] = 1
          @actors.concat(list)
        end
        create_cursor
        create_stamina_gauge
      end

      def add_ball(x, y, gold)
        body = Body.new(x, y, gold ? 9 : 7, gold ? 0.7 : 0.5, 0.985)
        sprite = add_sprite(gold ? 'ballon_or' : 'ballon', x, y, 0)
        sprite.set_origin(sprite.bitmap.width / 2, sprite.bitmap.height / 2)
        @balls << { body: body, sprite: sprite, gold: gold, last: nil, cool: 0 }
      end

      def selected
        return player.data[:list][player.data[:sel]]
      end

      def update_play(ctrl)
        if !@gold_added && @time >= time_limit * 2 / 3
          @gold_added = true
          add_ball(160, 122, true)
          popup(160, 100, Pokeathlon.t('Ballon doré !', 'Golden ball!'))
        end
        player.data[:sel] = (player.data[:sel] + 1) % 3 if ctrl.b
        @actors.each do |actor|
          actor == selected ? drive(actor, ctrl) : ai(actor)
          tire(actor, 0.9)
          actor.body.step
          Physics.bound(actor.body, LEFT + 2, TOP + 2, RIGHT - 2, BOTTOM - 2)
        end
        bodies = @actors.map(&:body) + @balls.map { |b| b[:body] }
        Physics.collide(bodies) { |a, b, _force| touch(a, b) }
        @balls.each { |ball| move_ball(ball) }
      end

      # Un Pokémon touche un ballon : il le frappe dans sa direction
      def touch(a, b)
        actor, ball_body = a.owner.is_a?(Actor) ? [a.owner, b] : [b.owner, a]
        return unless actor.is_a?(Actor)

        ball = @balls.find { |bl| bl[:body] == ball_body }
        return unless ball

        ball[:last] = actor.team
        dx = ball_body.x - actor.body.x
        dy = ball_body.y - actor.body.y
        d = Math.hypot(dx, dy)
        return if d == 0

        power = actor.f('power', 1.0, 2.0)
        ball_body.push(dx / d * power, dy / d * power)
        ball_body.limit(5.5)
        Pokeathlon.play_se('push') if actor.team.player?
      end

      def move_ball(ball)
        body = ball[:body]
        body.step
        ball[:cool] -= 1 if ball[:cool] > 0
        GOALS.each_with_index do |(gx, gy, side), team_index|
          inside = case side
                   when :bottom then body.y + body.r >= BOTTOM && (body.x - gx).abs < HALF_GOAL
                   when :top then body.y - body.r <= TOP && (body.x - gx).abs < HALF_GOAL
                   when :left then body.x - body.r <= LEFT && (body.y - gy).abs < HALF_GOAL
                   when :right then body.x + body.r >= RIGHT && (body.y - gy).abs < HALF_GOAL
                   end
          next unless inside

          goal(ball, @teams[team_index])
          return
        end
        Physics.bound(body, LEFT, TOP, RIGHT, BOTTOM, 0.8)
        # coins arrondis : le ballon ne reste pas coincé
        near_x = body.x < LEFT + 26 || body.x > RIGHT - 26
        near_y = body.y < TOP + 26 || body.y > BOTTOM - 26
        if near_x && near_y
          dx = 160 - body.x
          dy = 122 - body.y
          d = Math.hypot(dx, dy)
          body.push(dx / d * 0.18, dy / d * 0.18)
        end
        ball[:still] = (near_x || near_y) && body.speed < 0.4 ? ball[:still].to_i + 1 : 0
        return unless ball[:still] > 240

        body.x = 160.0
        body.y = 122.0
        body.vx = body.vy = 0
        ball[:still] = 0
      end

      def goal(ball, defender)
        value = ball[:gold] ? 2 : 1
        scorer = ball[:last]
        defender.score -= 1
        scorer.score += value if scorer && scorer != defender
        gx, gy, = GOALS[defender.index]
        popup(gx.clamp(30, 290), gy.clamp(40, 200), scorer && scorer != defender ? "+#{value}" : '-1', 9)
        Pokeathlon.play_se(scorer&.player? ? 'cheer' : 'point')
        ball[:body].x = 160.0 + rand(-20..20)
        ball[:body].y = 122.0 + rand(-20..20)
        ball[:body].vx = ball[:body].vy = 0
        ball[:last] = nil
      end

      def ai(actor)
        team = actor.team
        gx, gy, = GOALS[team.index]
        factor = actor.team.player? ? 0.8 : 0.75 + @difficulty * 0.1
        accel = actor.accel * factor
        max = actor.max_speed * factor
        ball = @balls.min_by do |b|
          chasing = @actors.count { |o| o != actor && o.data[:ball] == b }
          b[:body].dist(actor.body) + (b[:gold] ? -40 : 0) + chasing * 60
        end
        actor.data[:ball] = ball
        return unless ball

        bb = ball[:body]
        if actor.data[:role] == :keeper
          # reste entre le ballon le plus proche du but et le but
          danger = @balls.min_by { |b| Math.hypot(b[:body].x - gx, b[:body].y - gy) }[:body]
          tx = gx + (danger.x - gx) * 0.25
          ty = gy + (danger.y - gy) * 0.25
          actor.body.seek(tx, ty, accel, max)
          return
        end
        # attaquant : se place derrière le ballon par rapport au but visé, puis pousse
        target = actor.data[:target_goal] ||= (GOALS.each_index.to_a - [team.index]).sample
        actor.data[:target_goal] = nil if chance(300)
        tgx, tgy, = GOALS[target]
        dx = tgx - bb.x
        dy = tgy - bb.y
        d = Math.hypot(dx, dy).nonzero? || 1
        behind_x = bb.x - dx / d * 14 + ai_error(4)
        behind_y = bb.y - dy / d * 14 + ai_error(4)
        if Math.hypot(behind_x - actor.body.x, behind_y - actor.body.y) > 8
          actor.body.seek(behind_x, behind_y, accel, max)
        else
          actor.body.seek(tgx, tgy, accel, max)
        end
      end

      def update_sprites
        @balls.each do |ball|
          ball[:sprite].set_position(ball[:body].x.round, ball[:body].y.round)
          ball[:sprite].z = ball[:body].y.round + 100
        end
        @actors.each { |actor| draw_actor(actor) }
        draw_cursor(selected)
        draw_stamina(selected)
      end
    end
  end
end
