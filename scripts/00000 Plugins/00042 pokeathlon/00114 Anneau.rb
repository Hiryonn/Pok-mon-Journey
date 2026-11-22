# Pokéathlon : Anneau (sumo)
#
# Un Pokémon de chaque équipe sur l'anneau, sans barrière. Flèches : se déplacer ; A maintenu puis relâché (ou clic
# vers un point) : charge, d'autant plus forte qu'elle est longue (Force). Faire tomber un adversaire rapporte 1 point ;
# le Pokémon tombé est remplacé par le suivant de son équipe. Saut : se rattraper au bord ; Endurance : fatigue ;
# Vitesse : déplacements. B : changer de Pokémon (au centre de l'anneau).
module Pokeathlon
  module Events
    class Ring < Event
      include Arena
      CENTER = [160, 126].freeze
      RADIUS = 74
      RESPAWN = 70

      private

      def help_text
        return Pokeathlon.t('Flèches : bouger   A maintenu puis relâché / clic : charger   B : changer', 'Arrows: move   Hold then release A / click: charge   B: switch')
      end

      def setup
        add_sprite('fond_anneau', 0, 22, -110)
        ring = add_sprite('anneau_sumo', CENTER[0], CENTER[1], -100)
        ring.set_origin(ring.bitmap.width / 2, ring.bitmap.height / 2)
        @actors = []
        @teams.each do |team|
          list = team.athletes.map { |a| make_actor(a, *start_pos(team.index), 10, 0.93) }
          list.each_with_index { |actor, i| actor.body.active = i == 0 }
          team.data[:list] = list
          team.data[:active] = 0
          team.data[:wait] = 0
        end
        @charge_back = add_sprite('jauge_fond', 120, 206, 8500)
        @charge = add_sprite('jauge', 122, 208, 8501)
        create_cursor
        create_stamina_gauge
      end

      def start_pos(index)
        angle = Math::PI / 2 + index * Math::PI / 2
        return [CENTER[0] + Math.cos(angle) * RADIUS * 0.55, CENTER[1] + Math.sin(angle) * RADIUS * 0.55]
      end

      def active(team)
        return team.data[:list][team.data[:active]]
      end

      def update_play(ctrl)
        @teams.each do |team|
          if team.data[:wait] > 0
            team.data[:wait] -= 1
            enter(team) if team.data[:wait] <= 0
            next
          end
          actor = active(team)
          team.data[:list].each { |other| rest(other) unless other == actor }
          actor.dazed -= 1 if actor.dazed > 0
          actor.data[:touch_time] = actor.data[:touch_time].to_i - 1
          if actor.data[:dash].to_i > 0
            actor.data[:dash] -= 1
          else
            team.player? ? control_player(actor, ctrl) : ai(actor)
          end
          tire(actor, 0.3)
          actor.body.mass = actor.mass * (actor.stamina < 0.15 ? 0.75 : 1.0)
          edge_grip(actor)
          actor.body.step
        end
        bodies = @teams.reject { |t| t.data[:wait] > 0 }.map { |t| active(t).body }
        Physics.collide(bodies) do |a, b, force|
          a.owner.data[:toucher] = b.owner.team
          b.owner.data[:toucher] = a.owner.team
          a.owner.data[:touch_time] = b.owner.data[:touch_time] = 120
          knock(a, b, force)
          Pokeathlon.play_se('hit') if force > 2.5 && (a.owner.team.player? || b.owner.team.player?)
        end
        @teams.each { |team| check_out(team) if team.data[:wait] <= 0 }
      end

      def control_player(actor, ctrl)
        if actor.data[:charging]
          actor.data[:charge] = [actor.data[:charge].to_f + 1 / 40.0, 1.0].min
          dir = ctrl.dir? ? [ctrl.dx, ctrl.dy] : nil
          actor.data[:dir] = dir if dir
          actor.body.vx *= 0.8
          actor.body.vy *= 0.8
          if ctrl.a_release || !(ctrl.a_hold || ctrl.click_hold)
            dash(actor, *(actor.data[:dir] || facing(actor)))
          end
        elsif ctrl.a
          actor.data[:charging] = true
          actor.data[:charge] = 0.0
        elsif ctrl.click
          dash_to(actor, ctrl.mouse_x, ctrl.mouse_y, 0.8)
        else
          drive(actor, ctrl, actor.max_speed(0.9, 1.9), actor.accel * 0.8)
        end
        switch(actor.team) if ctrl.b && Math.hypot(actor.body.x - CENTER[0], actor.body.y - CENTER[1]) < RADIUS * 0.4
      end

      def facing(actor)
        speed = actor.body.speed
        return [actor.body.vx / speed, actor.body.vy / speed] if speed > 0.1

        return [CENTER[0] - actor.body.x, CENTER[1] - actor.body.y]
      end

      def dash(actor, dx, dy)
        len = Math.hypot(dx, dy)
        actor.data[:charging] = false
        return if len == 0

        power = actor.f('power', 5.0, 8.0) * (0.35 + 0.65 * actor.data[:charge].to_f)
        actor.body.push(dx / len * power, dy / len * power)
        actor.data[:dash] = 18
        actor.stamina = (actor.stamina - 0.08).clamp(0, 1)
        actor.data[:charge] = 0.0
        Pokeathlon.play_se('push') if actor.team.player?
      end

      def dash_to(actor, x, y, charge)
        actor.data[:charge] = charge
        dash(actor, x - actor.body.x, y - actor.body.y)
      end

      # Au bord, le Pokémon se rattrape (Saut)
      def edge_grip(actor)
        dist = Math.hypot(actor.body.x - CENTER[0], actor.body.y - CENTER[1])
        return unless dist > RADIUS - 12

        grip = actor.f('jump', 0.02, 0.06)
        actor.body.push((CENTER[0] - actor.body.x) / dist * grip, (CENTER[1] - actor.body.y) / dist * grip)
      end

      def ai(actor)
        body = actor.body
        dist_center = Math.hypot(body.x - CENTER[0], body.y - CENTER[1])
        factor = 0.75 + @difficulty * 0.1
        if dist_center > RADIUS * 0.75
          body.seek(*CENTER, actor.accel * factor, actor.max_speed(0.9, 1.9))
          actor.data[:charging] = false
          return
        end
        target = @teams.reject { |t| t == actor.team || t.data[:wait] > 0 }.map { |t| active(t) }.min_by { |o| o.body.dist(body) }
        return unless target

        if actor.data[:charging]
          actor.data[:charge] = [actor.data[:charge].to_f + 1 / 40.0, 1.0].min
          body.vx *= 0.8
          body.vy *= 0.8
          if actor.data[:charge] >= actor.data[:want].to_f
            dash(actor, target.body.x + ai_error(10) - body.x, target.body.y + ai_error(10) - body.y)
          end
        elsif body.dist(target.body) < 64 && actor.stamina > 0.1 && chance(20 - @difficulty * 4)
          actor.data[:charging] = true
          actor.data[:charge] = 0.0
          actor.data[:want] = 0.3 + rand * 0.6
        else
          body.seek(target.body.x, target.body.y, actor.accel * factor, actor.max_speed(0.9, 1.9) * factor)
        end
      end

      # Choc : celui qui fonce repousse l'autre (Force contre Endurance)
      def knock(a, b, force)
        return if force < 1.5

        hitter, target = a.speed >= b.speed ? [a, b] : [b, a]
        dx = target.x - hitter.x
        dy = target.y - hitter.y
        d = Math.hypot(dx, dy).nonzero? || 1
        strength = force * hitter.owner.f('power', 0.5, 0.9) / target.owner.f('stamina', 1.0, 1.5)
        target.push(dx / d * strength, dy / d * strength)
        target.owner.data[:dash] = 12
      end

      def check_out(team)
        actor = active(team)
        dist = Math.hypot(actor.body.x - CENTER[0], actor.body.y - CENTER[1])
        return unless dist > RADIUS + 4

        toucher = actor.data[:touch_time].to_i > 0 ? actor.data[:toucher] : nil
        if toucher && toucher != team
          toucher.score += 1
          popup(actor.body.x.clamp(30, 290), actor.body.y.clamp(40, 200), toucher.player? ? '+1' : Pokeathlon.t('Tombé !', 'Out!'))
        end
        Pokeathlon.play_se(team.player? ? 'miss' : 'point')
        actor.body.active = false
        actor.data[:charging] = false
        team.data[:wait] = RESPAWN
        team.data[:active] = (team.data[:active] + 1) % 3
      end

      def enter(team)
        actor = active(team)
        actor.body.x, actor.body.y = start_pos(team.index)
        actor.body.vx = actor.body.vy = 0
        actor.body.active = true
        actor.data[:touch_time] = 0
      end

      def switch(team)
        list = team.data[:list]
        current = list[team.data[:active]]
        nxt_index = (team.data[:active] + 1) % 3
        nxt = list[nxt_index]
        nxt.body.x = current.body.x
        nxt.body.y = current.body.y
        current.body.active = false
        nxt.body.active = true
        team.data[:active] = nxt_index
        Pokeathlon.play_se('switch')
      end

      def update_sprites
        @teams.each do |team|
          team.data[:list].each do |actor|
            draw_actor(actor)
            # chute : le Pokémon rapetisse
            actor.sprite.zoom = 1
          end
        end
        actor = active(player)
        draw_cursor(player.data[:wait] > 0 ? nil : actor)
        draw_stamina(actor)
        @charge.src_rect.set(0, 0, (actor.data[:charge].to_f * 60).round, 6)
        @charge.visible = @charge_back.visible = actor.data[:charging] ? true : false
      end
    end
  end
end
