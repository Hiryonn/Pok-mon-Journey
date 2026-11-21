# Pokéathlon : Attrape-disques
#
# Des disques tombent sur la plateforme (leur ombre grandit avant l'arrivée). Aller sous le disque et sauter avec A
# (ou clic) juste avant qu'il touche le sol pour l'attraper : 1, 2, 3 ou 5 points selon la bande de la plateforme
# (le disque doré vaut le double). Bousculer les autres peut les faire tomber de la plateforme un moment.
# Saut : portée et durée du saut ; Vitesse : course ; Force : bousculade. B : changer de Pokémon.
module Pokeathlon
  module Events
    class Disc < Event
      include Arena
      BOARD = [39, 30].freeze
      LEFT = 44
      RIGHT = 276
      TOP = 38
      BOTTOM = 200
      BANDS = [[97, 1], [145, 2], [185, 3], [999, 5]].freeze
      STARTS = [[90, 180], [90, 60], [230, 60], [230, 180]].freeze
      FALL = 90

      private

      def help_text
        return Pokeathlon.t('Flèches / clic : courir   A : sauter sous le disque   B : changer', 'Arrows / click: run   A: jump under the disc   B: switch')
      end

      def setup
        add_sprite('fond_disques', 0, 22, -110)
        add_sprite('plateforme_disques', *BOARD, -100)
        @discs = []
        @actors = []
        @teams.each do |team|
          list = team.athletes.map { |a| make_actor(a, *STARTS[team.index]) }
          list.each_with_index { |actor, i| actor.body.active = i == 0 }
          team.data[:list] = list
          team.data[:active] = 0
        end
        create_cursor
        create_stamina_gauge
      end

      def active(team)
        return team.data[:list][team.data[:active]]
      end

      def band_value(y)
        return BANDS.find { |limit, _| y < limit }[1]
      end

      def spawn_disc
        x = rand(LEFT + 14..RIGHT - 14)
        y = rand(TOP + 14..BOTTOM - 14)
        gold = rand(8).zero?
        time = rand(80..130)
        sprite = add_sprite(gold ? 'disque_or' : 'disque', 0, 0, 7000)
        sprite.set_origin(sprite.bitmap.width / 2, sprite.bitmap.height / 2)
        shadow = add_sprite('ombre_disque', 0, 0, 40)
        shadow.set_origin(shadow.bitmap.width / 2, shadow.bitmap.height / 2)
        @discs << { x: x.to_f, y: y.to_f, gold: gold, left: time, total: time, sprite: sprite, shadow: shadow, done: false }
      end

      def update_play(ctrl)
        spawn_disc if @discs.count { |d| !d[:done] } < 2 && chance(30)
        @teams.each do |team|
          actor = active(team)
          team.data[:list].each { |other| rest(other) unless other == actor }
          if actor.data[:fallen].to_i > 0
            actor.data[:fallen] -= 1
            respawn(team, actor) if actor.data[:fallen] <= 0
            next
          end
          actor.data[:air] = actor.data[:air].to_i - 1 if actor.data[:air].to_i > 0
          team.player? ? control_player(actor, ctrl) : ai(team, actor)
          tire(actor, 0.8)
          actor.body.step
          check_fall(actor)
        end
        bodies = @teams.map { |team| active(team).body }.select(&:active)
        Physics.collide(bodies) { |_a, _b, force| Pokeathlon.play_se('push') if force > 2 && chance(2) }
        @discs.each { |disc| update_disc(disc) }
        @discs.reject! { |disc| disc[:done] && disc[:sprite].disposed? }
      end

      def control_player(actor, ctrl)
        drive(actor, ctrl, actor.data[:air].to_i > 0 ? actor.max_speed * 0.6 : actor.max_speed)
        jump(actor) if ctrl.a
        switch(actor.team) if ctrl.b
      end

      def jump(actor)
        return if actor.data[:air].to_i > 0

        actor.data[:air] = actor.f('jump', 18, 28).round
        actor.data[:air_len] = actor.data[:air]
        actor.stamina = (actor.stamina - 0.05).clamp(0, 1)
        Pokeathlon.play_se('jump') if actor.team.player?
      end

      def switch(team)
        list = team.data[:list]
        current = list[team.data[:active]]
        return if current.data[:air].to_i > 0

        nxt_index = (team.data[:active] + 1) % 3
        nxt = list[nxt_index]
        nxt.body.x = current.body.x
        nxt.body.y = current.body.y
        current.body.active = false
        nxt.body.active = true
        team.data[:active] = nxt_index
        Pokeathlon.play_se('switch') if team.player?
      end

      def ai(team, actor)
        disc = @discs.reject { |d| d[:done] }.max_by do |d|
          dist = Math.hypot(d[:x] - actor.body.x, d[:y] - actor.body.y)
          reach = d[:left] * actor.max_speed
          band_value(d[:y]) * (d[:gold] ? 2 : 1) * 30 - dist + (reach > dist ? 40 : -60) + rand * 20
        end
        switch(team) if actor.stamina < 0.2 && chance(30)
        return unless disc

        actor.data[:off] ||= [ai_error(5), ai_error(5)]
        factor = 0.75 + @difficulty * 0.1
        actor.body.seek(disc[:x] + actor.data[:off][0], disc[:y] + actor.data[:off][1], actor.accel * factor, actor.max_speed * factor)
        timing = actor.f('jump', 18, 28) / 2 + ai_error(5)
        if disc[:left] <= timing && Math.hypot(disc[:x] - actor.body.x, disc[:y] - actor.body.y) < 20
          jump(actor)
          actor.data[:off] = nil
        end
      end

      def update_disc(disc)
        return if disc[:done]

        disc[:left] -= 1
        return if disc[:left] > 0

        disc[:done] = true
        catcher = @teams.map { |t| active(t) }.select do |a|
          a.body.active && a.data[:air].to_i > 0 &&
            Math.hypot(a.body.x - disc[:x], a.body.y - disc[:y]) < a.f('jump', 12, 18)
        end.min_by { |a| Math.hypot(a.body.x - disc[:x], a.body.y - disc[:y]) }
        if catcher
          value = band_value(disc[:y]) * (disc[:gold] ? 2 : 1)
          catcher.team.score += value
          popup(disc[:x], disc[:y] - 28, "+#{value}")
          Pokeathlon.play_se(catcher.team.player? ? 'point' : 'push')
        end
        disc[:sprite].dispose
        disc[:shadow].dispose
      end

      def check_fall(actor)
        body = actor.body
        return if body.x.between?(LEFT - 6, RIGHT + 6) && body.y.between?(TOP - 6, BOTTOM + 6)

        actor.data[:fallen] = FALL
        body.active = false
        body.vx = body.vy = 0
        popup(body.x.clamp(30, 290), body.y.clamp(40, 200), Pokeathlon.t('Tombé !', 'Fell!')) if actor.team.player?
      end

      def respawn(team, actor)
        actor.body.x, actor.body.y = STARTS[team.index]
        actor.body.active = true
      end

      def update_sprites
        @teams.each do |team|
          team.data[:list].each_with_index do |actor, i|
            draw_actor(actor)
            next unless i == team.data[:active] && actor.body.active

            air = actor.data[:air].to_i
            next unless air > 0

            height = Math.sin(Math::PI * (1 - air / actor.data[:air_len].to_f)) * 16
            actor.sprite.y -= height.round
          end
        end
        @discs.each do |disc|
          next if disc[:done]

          t = disc[:left] / disc[:total].to_f
          disc[:sprite].set_position(disc[:x].round, (disc[:y] - t * 150).round)
          disc[:shadow].set_position(disc[:x].round, disc[:y].round)
          disc[:shadow].zoom = 1.4 - t
          disc[:shadow].opacity = (255 * (1 - t * 0.7)).round
        end
        actor = active(player)
        draw_cursor(actor)
        draw_stamina(actor)
      end
    end
  end
end
