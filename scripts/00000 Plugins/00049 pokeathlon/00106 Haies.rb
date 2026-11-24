# Pokéathlon : Course de haies (vue de côté, 4 couloirs)
#
# Les 3 Pokémon de l'équipe courent l'un après l'autre (relais de 3 tronçons). A (ou clic) : sauter. Sauter au bon
# moment au-dessus d'une haie donne un élan ; la toucher fait trébucher. Vitesse : vitesse de course ; Saut : durée du
# saut ; Technique : marge du saut parfait. Score : temps de l'équipe (le plus petit gagne).
module Pokeathlon
  module Events
    class Hurdle < Event
      LEG = 1200
      HURDLES = (0...8).map { |i| 120 + i * 145 }.freeze
      LANE_Y = [98, 136, 174, 212].freeze
      CAMERA_X = 96

      def score_text(score)
        return '--' if score.to_f <= 0

        return format('%.1f', score)
      end

      private

      def help_text
        return Pokeathlon.t('A / clic : sauter les haies', 'A / click: jump over the hurdles')
      end

      def total
        return LEG * 3
      end

      def setup
        @back = add_sprite('piste_haies', 0, 22, -100)
        @back.src_rect.set(0, 0, 320, 202)
        @runners = @teams.map do |team|
          sprites = team.athletes.map do |a|
            sp = add_pokemon(a.pokemon)
            sp.visible = false
            sp
          end
          { team: team, x: 0.0, v: 0.0, air: 0, air_len: 1, stun: 0, leg: 0, done: false, sprites: sprites, boost: 0, next_jump: nil }
        end
        @hurdle_sprites = Array.new(4) { Array.new(4) { add_sprite('haie', 0, 0, 0) } }
        @lines = Array.new(2) { add_sprite('ligne_relais', 0, 64, -10) }
        @finish = add_sprite('arrivee', 0, 64, -10)
        @map_back = add_sprite('mini_piste', 10, 26, 8500)
        @map_dots = @teams.map { |team| add_sprite("pastille_#{team.index}", 0, 24, 8501) }
        @leg_text = add_text(200, 40, 116, 14, '', 2, 9, 8600)
      end

      def athlete(runner)
        return runner[:team].athletes[runner[:leg].clamp(0, 2)]
      end

      def hurdle_positions
        return (0..2).flat_map { |leg| HURDLES.map { |h| leg * LEG + h } }
      end

      def update_play(ctrl)
        @runners.each do |r|
          next if r[:done]

          ath = athlete(r)
          if r[:team].player?
            jump(r, ath) if ctrl.a || ctrl.click
          else
            ai(r, ath)
          end
          run(r, ath)
        end
      end

      def finished?
        return @runners.all? { |r| r[:done] }
      end

      def end_play
        @runners.each do |r|
          next if r[:done]

          # pas arrivé : temps limite + ce qu'il reste à courir (à 2 pixels par image)
          r[:team].score = (time_limit + (total - r[:x]) / 2.0) / FPS
        end
      end

      def jump(runner, ath)
        return if runner[:air] > 0 || runner[:stun] > 0

        runner[:air_len] = ath.f('jump', 24, 34).round
        runner[:air] = runner[:air_len]
        next_h = hurdle_positions.find { |h| h > runner[:x] }
        if next_h
          dist = next_h - runner[:x]
          ideal = runner[:v] * runner[:air_len] / 2.0
          if (dist - ideal).abs <= ath.f('skill', 6, 14)
            runner[:boost] = 40
            runner[:v] += 0.35
            popup(screen_x(runner[:x]), lane_y(runner) - 34, Pokeathlon.t('Parfait !', 'Perfect!')) if runner[:team].player?
          end
        end
        Pokeathlon.play_se('jump') if runner[:team].player?
      end

      def ai(runner, ath)
        next_h = hurdle_positions.find { |h| h > runner[:x] }
        return unless next_h

        runner[:next_jump] ||= ai_error(12)
        ideal = runner[:v] * ath.f('jump', 24, 34) / 2.0
        return unless next_h - runner[:x] <= ideal + runner[:next_jump]

        jump(runner, ath)
        runner[:next_jump] = nil
      end

      def run(runner, ath)
        vmax = ath.f('speed', 1.7, 2.7)
        if runner[:stun] > 0
          runner[:stun] -= 1
        elsif runner[:boost] > 0
          runner[:boost] -= 1
        else
          runner[:v] = runner[:v] < vmax ? [runner[:v] + 0.025 + 0.006 * ath.stat('speed'), vmax].min : [runner[:v] - 0.02, vmax].max
        end
        before = runner[:x]
        runner[:x] += runner[:v]
        runner[:air] -= 1 if runner[:air] > 0
        hurdle_positions.each do |h|
          next unless before < h && runner[:x] >= h && runner[:air] <= 0

          runner[:v] *= 0.25
          runner[:stun] = 18
          Pokeathlon.play_se('hit') if runner[:team].player?
        end
        leg_end = (runner[:leg] + 1) * LEG
        return unless runner[:x] >= leg_end

        if runner[:leg] >= 2
          runner[:done] = true
          runner[:team].score = @time / FPS.to_f
          popup(screen_x(runner[:x]) - 20, lane_y(runner) - 34, Pokeathlon.t('Arrivé !', 'Finish!')) if runner[:team].player?
        else
          runner[:leg] += 1
          runner[:v] = athlete(runner).f('speed', 1.7, 2.7) * 0.7
          runner[:air] = 0
          runner[:stun] = 0
          Pokeathlon.play_se('switch') if runner[:team].player?
        end
      end

      def camera
        player_runner = @runners[0]
        return [player_runner[:x] - CAMERA_X, 0].max
      end

      def screen_x(x)
        return x - camera
      end

      def lane_y(runner)
        return LANE_Y[runner[:team].index]
      end

      def update_sprites
        cam = camera
        @back.src_rect.x = (cam.round % 64)
        visible = hurdle_positions.select { |h| h > cam - 20 && h < cam + 340 }
        @hurdle_sprites.each_with_index do |pool, lane|
          pool.each_with_index do |sprite, k|
            h = visible[k]
            sprite.visible = !h.nil?
            next unless h

            sprite.set_position((h - cam - 4).round, LANE_Y[lane] - 24)
            sprite.z = LANE_Y[lane] - 1
          end
        end
        [LEG, LEG * 2].each_with_index do |x, i|
          @lines[i].set_position((x - cam).round, 64)
          @lines[i].visible = (x - cam).between?(-10, 330)
        end
        @finish.set_position((total - cam).round, 64)
        @finish.visible = (total - cam).between?(-10, 330)
        @runners.each do |r|
          r[:sprites].each_with_index do |sprite, i|
            sprite.visible = i == r[:leg]
            next unless sprite.visible

            height = r[:air] > 0 ? Math.sin(Math::PI * (1 - r[:air] / r[:air_len].to_f)) * 20 : 0
            sprite.move_to(screen_x(r[:x]), lane_y(r) - height, r[:v], 0, 0)
            sprite.z = lane_y(r) + 10
            sprite.opacity = r[:stun] > 0 && (r[:stun] / 3).odd? ? 110 : 255
          end
        end
        @runners.each_with_index do |r, i|
          @map_dots[i].set_position(10 + (r[:x] / total * 288).round.clamp(0, 288), 24 + i)
        end
        @leg_text.text = Pokeathlon.t("Relais #{@runners[0][:leg] + 1} / 3", "Leg #{@runners[0][:leg] + 1} / 3")
      end
    end
  end
end
