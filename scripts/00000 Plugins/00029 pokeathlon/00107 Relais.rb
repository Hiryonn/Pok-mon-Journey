# Pokéathlon : Relais (piste ovale vue de dessus)
#
# Chaque équipe court dans son couloir. A (ou clic) maintenu : sprinter (fatigue) ; haut / bas : passer au bord
# intérieur ou extérieur du couloir pour éviter les rochers ; B dans la zone de relais (ligne de départ) : passer le
# relais au Pokémon suivant (reposé). Vitesse : course ; Endurance : fatigue ; Force : sprint. Score : tours courus.
module Pokeathlon
  module Events
    class Relay < Event
      include Arena
      CENTER = [160, 124].freeze
      RX = 138
      RY = 84
      LANE = 11
      ZONE = 0.22

      def score_text(score)
        return format('%.1f', score.to_f)
      end

      private

      def help_text
        return Pokeathlon.t('A : sprinter   Haut / Bas : esquiver   B (zone) : relais', 'A: sprint   Up / Down: dodge   B (zone): hand over')
      end

      def setup
        add_sprite('piste_relais', 0, 22, -100)
        @rocks = []
        @runners = @teams.map do |team|
          sprites = team.athletes.map { |a| sp = add_pokemon(a.pokemon, team.index); sp.visible = false; sp }
          { team: team, dist: 0.0, px: 0.0, side: 0, stun: 0, leg: 0, stamina: team.athletes.map { 1.0 }, sprites: sprites, sprint: false,
            dodge: nil }
        end
        @teams.each_index do |lane|
          6.times do |k|
            angle = 0.6 + k * (Math::PI * 2 - 0.9) / 6 + rand * 0.3
            sprite = add_sprite('rocher', 0, 0, 0)
            sprite.set_origin(6, 8)
            @rocks << { lane: lane, angle: angle, side: rand(2), sprite: sprite }
          end
        end
        create_stamina_gauge
      end

      # Rayon moyen d'un couloir (0 : intérieur)
      def radius_scale(lane, side)
        step = LANE * 2.0 / RX
        return 1.0 - (3 - lane) * step + (side == 1 ? step / 4 : -step / 4)
      end

      def position(lane, side, angle)
        scale = radius_scale(lane, side)
        return [CENTER[0] + Math.cos(angle) * RX * scale, CENTER[1] + Math.sin(angle) * RY * scale]
      end

      # Longueur d'un tour (pour l'avancée en angle)
      def lap_length(lane)
        scale = radius_scale(lane, 0)
        a = RX * scale
        b = RY * scale
        return Math::PI * (3 * (a + b) - Math.sqrt((3 * a + b) * (a + 3 * b)))
      end

      def angle_of(runner)
        return (runner[:dist] % 1.0) * Math::PI * 2 + Math::PI / 2
      end

      def athlete(runner)
        return runner[:team].athletes[runner[:leg]]
      end

      def in_zone?(runner)
        frac = runner[:dist] % 1.0
        return frac < ZONE / (Math::PI * 2) * 2 || frac > 1 - ZONE / (Math::PI * 2) * 2
      end

      def update_play(ctrl)
        @runners.each do |r|
          if r[:team].player?
            r[:sprint] = ctrl.a_hold || ctrl.click_hold
            r[:side] = 0 if ctrl.dy < 0
            r[:side] = 1 if ctrl.dy > 0
            hand_over(r) if ctrl.b
          else
            ai(r)
          end
          run(r)
        end
      end

      def ai(runner)
        stamina = runner[:stamina][runner[:leg]]
        runner[:sprint] = stamina > 0.25 + (3 - @difficulty) * 0.1
        hand_over(runner) if in_zone?(runner) && stamina < 0.45
        rock = next_rock(runner)
        return unless rock

        reaction = 70 - @difficulty * 15
        runner[:dodge] ||= rand(reaction) + 10
        runner[:side] = 1 - rock[:side] if rock_distance(runner, rock) < runner[:dodge]
      end

      def next_rock(runner)
        lane = runner[:team].index
        return @rocks.select { |rk| rk[:lane] == lane && rk[:side] == runner[:side] }.min_by { |rk| rock_distance(runner, rk) }
      end

      # Distance (pixels) jusqu'à un rocher devant
      def rock_distance(runner, rock)
        angle = angle_of(runner)
        diff = (rock[:angle] - angle) % (Math::PI * 2)
        return diff / (Math::PI * 2) * lap_length(runner[:team].index)
      end

      def hand_over(runner)
        return if runner[:leg] >= 0 && !in_zone?(runner)

        best = (0..2).reject { |i| i == runner[:leg] }.max_by { |i| runner[:stamina][i] }
        return if runner[:stamina][best] <= runner[:stamina][runner[:leg]] + 0.1

        runner[:leg] = best
        runner[:stun] = 0
        Pokeathlon.play_se('switch') if runner[:team].player?
      end

      def run(runner)
        ath = athlete(runner)
        stamina = runner[:stamina][runner[:leg]]
        speed = ath.f('speed', 1.3, 2.0)
        speed *= ath.f('power', 1.25, 1.5) if runner[:sprint] && stamina > 0
        speed *= 0.6 if stamina <= 0
        drain = (runner[:sprint] ? 0.006 : 0.0006) * (6 - ath.stat('stamina')) / 3.0
        runner[:stamina][runner[:leg]] = (stamina - drain).clamp(0.0, 1.0)
        (0..2).each { |i| runner[:stamina][i] = (runner[:stamina][i] + 0.0015).clamp(0.0, 1.0) unless i == runner[:leg] }
        if runner[:stun] > 0
          runner[:stun] -= 1
          speed *= 0.2
        end
        before = angle_of(runner)
        runner[:dist] += speed / lap_length(runner[:team].index)
        runner[:px] += speed
        after = angle_of(runner)
        hit = @rocks.find do |rk|
          rk[:lane] == runner[:team].index && rk[:side] == runner[:side] && crossed?(before, after, rk[:angle])
        end
        if hit && runner[:stun] <= 0
          runner[:stun] = 40
          runner[:dodge] = nil
          Pokeathlon.play_se('hit') if runner[:team].player?
        end
        # tours comptés sur le couloir extérieur (même distance pour tous)
        runner[:team].score = (runner[:px] / lap_length(3)).floor(1)
      end

      def crossed?(before, after, angle)
        two_pi = Math::PI * 2
        return ((angle - before) % two_pi) <= ((after - before) % two_pi)
      end

      def update_sprites
        @rocks.each do |rk|
          x, y = position(rk[:lane], rk[:side], rk[:angle])
          rk[:sprite].set_position(x.round, y.round)
          rk[:sprite].z = y.round
        end
        @runners.each do |r|
          angle = angle_of(r)
          x, y = position(r[:team].index, r[:side], angle)
          vx = -Math.sin(angle)
          vy = Math.cos(angle)
          r[:sprites].each_with_index do |sprite, i|
            sprite.visible = i == r[:leg]
            next unless sprite.visible

            sprite.move_to(x, y, vx * 2, vy * 2, 100)
            sprite.opacity = r[:stun] > 0 && (r[:stun] / 3).odd? ? 110 : 255
          end
        end
        player_runner = @runners[0]
        @gauge.src_rect.set(0, 0, (player_runner[:stamina][player_runner[:leg]] * 60).round, 6) if @gauge
      end
    end
  end
end
