# Pokéathlon : Pousse-cercle
#
# Trois cercles se déplacent sur le terrain : rester dedans rapporte des points chaque seconde (petit cercle 3, moyen 2,
# grand 1, pour chaque Pokémon de l'équipe dedans). On pousse les autres pour les en sortir (Force : poids, Vitesse :
# élan, Endurance : fatigue). Le joueur dirige un de ses trois Pokémon (B : le suivant) ; les deux autres restent
# dans le cercle le plus proche.
module Pokeathlon
  module Events
    class Circle < Event
      include Arena
      LEFT = 8
      TOP = 26
      RIGHT = 312
      BOTTOM = 218
      CIRCLES = [[20, 3], [30, 2], [42, 1]].freeze
      STARTS = [[160, 200], [30, 120], [160, 44], [290, 120]].freeze

      private

      def help_text
        return Pokeathlon.t('Flèches / clic : pousser   B : changer de Pokémon   Petit cercle = 3 points', 'Arrows / click: push   B: switch   Small circle = 3 points')
      end

      def setup
        add_sprite('terrain_cercles', 0, 22, -100)
        @circles = CIRCLES.each_with_index.map do |(radius, value), i|
          sprite = add_sprite("cercle_#{i}", 0, 0, -50)
          sprite.set_origin(sprite.bitmap.width / 2, sprite.bitmap.height / 2)
          angle = rand * Math::PI * 2
          { x: 100.0 + i * 60, y: 90.0 + (i % 2) * 60, r: radius, value: value, vx: Math.cos(angle) * 0.35, vy: Math.sin(angle) * 0.35,
            sprite: sprite }
        end
        @actors = []
        @teams.each do |team|
          sx, sy = STARTS[team.index]
          list = team.athletes.each_with_index.map { |a, i| make_actor(a, sx + (i - 1) * 22, sy) }
          team.data[:list] = list
          team.data[:sel] = 0
          @actors.concat(list)
        end
        create_cursor
        create_stamina_gauge
      end

      def selected
        return player.data[:list][player.data[:sel]]
      end

      def update_play(ctrl)
        @circles.each { |c| move_circle(c) }
        player.data[:sel] = (player.data[:sel] + 1) % 3 if ctrl.b
        @actors.each do |actor|
          if actor == selected
            drive(actor, ctrl)
          else
            ai(actor)
          end
          tire(actor, 0.8)
          actor.body.mass = actor.mass * (actor.stamina < 0.15 ? 0.7 : 1.0)
          actor.body.step
          Physics.bound(actor.body, LEFT, TOP, RIGHT, BOTTOM)
        end
        Physics.collide(@actors.map(&:body)) { |_a, _b, force| Pokeathlon.play_se('push') if force > 2.5 && chance(3) }
        score_tick if @time % FPS == 0
      end

      def move_circle(circle)
        circle[:x] += circle[:vx]
        circle[:y] += circle[:vy]
        circle[:vx] = -circle[:vx] if circle[:x] - circle[:r] < LEFT + 20 || circle[:x] + circle[:r] > RIGHT - 20
        circle[:vy] = -circle[:vy] if circle[:y] - circle[:r] < TOP + 20 || circle[:y] + circle[:r] > BOTTOM - 20
        return unless chance(240)

        angle = rand * Math::PI * 2
        speed = 0.25 + @time / time_limit.to_f * 0.35
        circle[:vx] = Math.cos(angle) * speed
        circle[:vy] = Math.sin(angle) * speed
      end

      def value_at(x, y)
        return @circles.select { |c| Math.hypot(c[:x] - x, c[:y] - y) <= c[:r] }.map { |c| c[:value] }.max.to_i
      end

      def score_tick
        @actors.each do |actor|
          value = value_at(actor.body.x, actor.body.y)
          next if value <= 0

          actor.team.score += value
          popup(actor.body.x, actor.body.y - 28, "+#{value}") if actor.team.player?
        end
      end

      # Ordinateur : vise un cercle (le plus rentable pas trop loin), avec un peu d'erreur
      def ai(actor)
        actor.data[:goal] = nil if chance(150 + @difficulty * 60)
        actor.data[:goal] ||= @circles.max_by do |c|
          crowd = @actors.count { |o| o != actor && Math.hypot(o.body.x - c[:x], o.body.y - c[:y]) < c[:r] }
          c[:value] * 40 - Math.hypot(c[:x] - actor.body.x, c[:y] - actor.body.y) * 0.4 - crowd * 45 + rand * 30
        end
        c = actor.data[:goal]
        actor.data[:off] ||= [ai_error(c[:r] * 0.6), ai_error(c[:r] * 0.6)]
        tx = c[:x] + actor.data[:off][0]
        ty = c[:y] + actor.data[:off][1]
        factor = actor.team.player? ? 0.85 : 0.75 + @difficulty * 0.1
        actor.body.seek(tx, ty, actor.accel * factor, actor.max_speed * factor)
      end

      def update_sprites
        @circles.each { |c| c[:sprite].set_position(c[:x].round, c[:y].round) }
        @actors.each { |actor| draw_actor(actor) }
        draw_cursor(selected)
        draw_stamina(selected)
      end
    end
  end
end
