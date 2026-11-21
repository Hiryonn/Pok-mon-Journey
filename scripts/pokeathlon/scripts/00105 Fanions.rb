# Pokéathlon : Capture de fanions
#
# Chaque équipe a un Pokémon sur le terrain. On ramasse les fanions en passant dessus (2 + Technique au plus) et on les
# rapporte à sa base (coin de sa couleur) : chaque fanion rapporté = 1 point. Un choc avec un Pokémon plus fort fait
# tomber un fanion. Fatigue en courant (Endurance) ; à la base, B envoie le Pokémon suivant.
module Pokeathlon
  module Events
    class Pennant < Event
      include Arena
      LEFT = 8
      TOP = 26
      RIGHT = 312
      BOTTOM = 218
      BASES = [[30, 196], [30, 48], [290, 48], [290, 196]].freeze
      BASE_RADIUS = 20
      MAX_FLAGS = 9

      def score_text(score)
        return score.to_i.to_s
      end

      private

      def help_text
        return Pokeathlon.t('Flèches / clic : courir   B à la base : changer de Pokémon', 'Arrows / click: run   B at base: switch Pokémon')
      end

      def setup
        add_sprite('terrain_fanions', 0, 0, -100)
        BASES.each_with_index { |(x, y), i| add_sprite("base_#{i}", x - 22, y - 22, -50) }
        @flags = []
        @actors = @teams.map do |team|
          list = team.athletes.map { |a| make_actor(a, *BASES[team.index]) }
          list.each_with_index { |actor, i| actor.body.active = i == 0 }
          team.data[:list] = list
          team.data[:active] = 0
          team.data[:label] = add_text(0, 0, 30, 14, '', 1, 9, 7000)
          list
        end
        5.times { spawn_flag }
        create_cursor
        create_stamina_gauge
      end

      def active(team)
        return team.data[:list][team.data[:active]]
      end

      def spawn_flag
        x = rand(70..250)
        y = rand(60..190)
        sprite = add_sprite('fanion', x, y, 0)
        sprite.set_origin(3, 13)
        @flags << { x: x.to_f, y: y.to_f, sprite: sprite }
      end

      def update_play(ctrl)
        spawn_flag if @flags.size < MAX_FLAGS && chance(45)
        @teams.each do |team|
          actor = active(team)
          team.player? ? control_player(actor, ctrl) : control_ai(team, actor)
          tire(actor, 1.0)
          team.data[:list].each { |other| rest(other) unless other == actor }
          actor.body.step
          Physics.bound(actor.body, LEFT, TOP, RIGHT, BOTTOM)
        end
        bodies = @teams.map { |team| active(team).body }
        Physics.collide(bodies) { |a, b, force| bump(a.owner, b.owner, force) }
        @teams.each { |team| pick_and_bank(team, active(team)) }
      end

      def at_base?(actor)
        bx, by = BASES[actor.team.index]
        return Math.hypot(actor.body.x - bx, actor.body.y - by) < BASE_RADIUS
      end

      def cap(actor)
        return 2 + actor.stat('skill')
      end

      def control_player(actor, ctrl)
        drive(actor, ctrl)
        switch(actor.team) if ctrl.b && at_base?(actor)
      end

      def control_ai(team, actor)
        bx, by = BASES[team.index]
        home = actor.carry >= cap(actor) || (actor.carry > 0 && (actor.stamina < 0.2 || time_left < 5)) ||
               (actor.carry > 2 && @flags.empty?)
        if actor.stamina < 0.25 && actor.carry == 0 && !at_base?(actor)
          home = true
        end
        if home
          actor.body.seek(bx + ai_error(6), by + ai_error(6), actor.accel, actor.max_speed)
          switch(team) if at_base?(actor) && actor.stamina < 0.35
        else
          flag = @flags.min_by { |fl| Math.hypot(fl[:x] - actor.body.x, fl[:y] - actor.body.y) + (rand * 30 * (4 - @difficulty)) }
          actor.body.seek(flag[:x], flag[:y], actor.accel * (0.8 + @difficulty * 0.1), actor.max_speed) if flag
        end
      end

      def switch(team)
        list = team.data[:list]
        current = list[team.data[:active]]
        best = list.each_index.reject { |i| i == team.data[:active] }.max_by { |i| list[i].stamina }
        return unless best && list[best].stamina > current.stamina + 0.1

        nxt = list[best]
        nxt.body.x = current.body.x
        nxt.body.y = current.body.y
        nxt.carry = current.carry
        current.carry = 0
        current.body.active = false
        nxt.body.active = true
        team.data[:active] = best
        Pokeathlon.play_se('switch') if team.player?
      end

      def pick_and_bank(team, actor)
        @flags.reject! do |fl|
          next false if actor.carry >= cap(actor) || Math.hypot(fl[:x] - actor.body.x, fl[:y] - actor.body.y) > actor.body.r + 6

          actor.carry += 1
          fl[:sprite].visible = false
          Pokeathlon.play_se('point') if team.player?
          true
        end
        return unless actor.carry > 0 && at_base?(actor)

        team.score += actor.carry
        popup(actor.body.x, actor.body.y - 30, "+#{actor.carry}")
        Pokeathlon.play_se('cheer') if team.player?
        actor.carry = 0
      end

      # Choc : le plus faible lâche un fanion
      def bump(a, b, force)
        return if force < 1.0 || a.team == b.team

        loser = a.mass * a.body.speed >= b.mass * b.body.speed ? b : a
        return if loser.carry <= 0

        loser.carry -= 1
        sprite = add_sprite('fanion', 0, 0, 0)
        sprite.set_origin(3, 13)
        angle = rand * Math::PI * 2
        x = (loser.body.x + Math.cos(angle) * 24).clamp(LEFT + 10, RIGHT - 10)
        y = (loser.body.y + Math.sin(angle) * 24).clamp(TOP + 10, BOTTOM - 10)
        @flags << { x: x, y: y, sprite: sprite }
        Pokeathlon.play_se('hit')
      end

      def update_sprites
        @flags.each { |fl| fl[:sprite].set_position(fl[:x].round, fl[:y].round); fl[:sprite].z = fl[:y].round + 100 }
        @teams.each do |team|
          team.data[:list].each { |actor| draw_actor(actor) }
          actor = active(team)
          label = team.data[:label]
          label.visible = actor.carry > 0
          label.text = "#{actor.carry}"
          label.set_position(actor.body.x.round - 15, actor.body.y.round - 40 - Text::Util::FOY)
        end
        draw_cursor(active(player))
        draw_stamina(active(player))
      end
    end
  end
end
