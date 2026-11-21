# Pokéathlon : Saut lumineux (vue de côté)
#
# Le Pokémon rebondit sur le trampoline. A (ou clic) au moment où il touche le trampoline : grand saut (Saut), parfait
# si le moment est juste (Technique) ; sinon petit rebond. Gauche / droite : se déplacer en l'air. Traverser une lampe
# allumée l'éteint : 10 points, 20 pour la deuxième du même saut, 30 pour la troisième… Les lampes se rallument.
# Les grands sauts fatiguent (Endurance) ; B sur le trampoline : Pokémon suivant. Les autres équipes sautent sur leur
# propre trampoline (scores en haut).
module Pokeathlon
  module Events
    class Lamp < Event
      FLOOR = 196
      GRAVITY = 0.13
      COLS = 7
      ROWS = [[56, 3], [92, 2], [128, 1]].freeze

      private

      def help_text
        return Pokeathlon.t('A / clic en touchant le trampoline : grand saut   Gauche / Droite   B : changer', 'A / click on landing: big jump   Left / Right   B: switch')
      end

      def setup
        add_sprite('fond_lampes', 0, 22, -100)
        @tramp = add_sprite('trampoline', 0, FLOOR + 2, 10)
        @lamps = []
        ROWS.each_with_index do |(y, _value), row|
          COLS.times do |col|
            x = 34 + col * 42 + (row.odd? ? 21 : 0)
            next if x > 300

            sprite = add_sprite('lampe', x, y, 5)
            sprite.set_origin(8, 8)
            @lamps << { x: x, y: y, lit: true, timer: 0, sprite: sprite }
          end
        end
        @sprites_pk = player.athletes.map { |a| sp = add_pokemon(a.pokemon); sp.visible = false; sp }
        @jumper = { x: 160.0, y: FLOOR.to_f, vx: 0.0, vy: -3.0, leg: 0, press: -99, combo: 0, stamina: [1.0, 1.0, 1.0] }
        @ai = @teams[1..].map { |team| { team: team, timer: rand(40..80), stamina: 1.0 } }
        create_stamina_gauge
        @combo_text = add_text(200, 26, 116, 14, '', 2, 9, 8600)
      end

      def create_stamina_gauge
        @gauge_back = add_sprite('jauge_fond', 4, 206, 8500)
        @gauge = add_sprite('jauge', 6, 208, 8501)
      end

      def athlete
        return player.athletes[@jumper[:leg]]
      end

      def update_play(ctrl)
        j = @jumper
        ath = athlete
        j[:press] = @frame if ctrl.a || ctrl.click
        j[:switch] = true if ctrl.b
        j[:vx] = ctrl.dx * ath.f('speed', 1.4, 2.4) if ctrl.dx != 0
        j[:vx] *= 0.92 if ctrl.dx == 0
        j[:vy] += GRAVITY
        j[:x] = (j[:x] + j[:vx]).clamp(20, 300)
        before_y = j[:y]
        j[:y] += j[:vy]
        if j[:y] >= FLOOR && j[:vy] > 0
          land(j, ath, ctrl)
        else
          check_lamps(j, before_y)
        end
        # appui juste avant d'atterrir : gardé quelques images
        j[:stamina].each_index { |i| j[:stamina][i] = (j[:stamina][i] + 0.0012).clamp(0, 1) unless i == j[:leg] }
        @lamps.each do |lamp|
          next if lamp[:lit]

          lamp[:timer] -= 1
          lamp[:lit] = true if lamp[:timer] <= 0
        end
        @ai.each { |st| ai(st) }
      end

      def land(j, ath, ctrl)
        j[:y] = FLOOR
        if j.delete(:switch)
          j[:leg] = (j[:leg] + 1) % 3
          ath = athlete
          Pokeathlon.play_se('switch')
        end
        window = ath.f('skill', 5, 9)
        early = @frame - j[:press]
        stamina = j[:stamina][j[:leg]]
        if early <= window
          power = ath.f('jump', 5.0, 6.6) * (stamina > 0.2 ? 1.0 : 0.75)
          power += 0.5 if early <= 2
          j[:vy] = -power
          j[:stamina][j[:leg]] = (stamina - ath.f('stamina', 0.16, 0.08)).clamp(0, 1)
          popup(j[:x], FLOOR - 40, Pokeathlon.t('Parfait !', 'Perfect!')) if early <= 2
          Pokeathlon.play_se('jump')
        else
          j[:vy] = -3.0
        end
        j[:press] = -99
        j[:combo] = 0
      end

      def check_lamps(j, before_y)
        top = [before_y, j[:y]].min - 24
        bottom = [before_y, j[:y]].max - 6
        @lamps.each do |lamp|
          next unless lamp[:lit] && (lamp[:x] - j[:x]).abs < 14 && lamp[:y].between?(top, bottom)

          lamp[:lit] = false
          lamp[:timer] = 300
          j[:combo] += 1
          gain = 10 * j[:combo]
          player.score += gain
          popup(lamp[:x], lamp[:y] - 14, "+#{gain}")
          Pokeathlon.play_se('point')
        end
      end

      # Équipes adverses : sauts simulés (lampes éteintes selon les performances)
      def ai(st)
        st[:timer] -= 1
        return if st[:timer] > 0

        ath = st[:team].athletes.max_by { |a| a.stat('jump') }
        st[:timer] = 70 + rand(30)
        tries = (ath.f('jump', 1.0, 2.4) * (0.75 + @difficulty * 0.1) + rand * 1.3).floor
        tries = (tries * 0.7).floor if st[:stamina] < 0.3
        st[:stamina] = (st[:stamina] - 0.05 + (tries.zero? ? 0.1 : 0)).clamp(0, 1)
        tries.times { |k| st[:team].score += 10 * (k + 1) }
      end

      def update_sprites
        j = @jumper
        @sprites_pk.each_with_index do |sp, i|
          sp.visible = i == j[:leg]
          next unless sp.visible

          sp.move_to(j[:x], j[:y], j[:vx], 0, 0)
          sp.face(j[:vx].abs > 0.3 ? (j[:vx] < 0 ? 1 : 2) : 0)
          sp.z = 50
        end
        squash = j[:y] >= FLOOR - 2 ? 3 : 0
        @tramp.y = FLOOR + 2 + squash
        @lamps.each do |lamp|
          lamp[:sprite].src_rect.set(lamp[:lit] ? 0 : 16, 0, 16, 16)
        end
        @gauge.src_rect.set(0, 0, (j[:stamina][j[:leg]] * 60).round, 6)
        @combo_text.text = j[:combo] > 1 ? Pokeathlon.t("Combo × #{j[:combo]}", "Combo × #{j[:combo]}") : ''
      end
    end
  end
end
