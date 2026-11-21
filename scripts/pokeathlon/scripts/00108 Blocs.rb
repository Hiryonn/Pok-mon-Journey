# Pokéathlon : Casse-blocs
#
# Un curseur va et vient sur la jauge : A (ou clic) frappe la pile de blocs. Au centre de la jauge (zone d'autant plus
# large que la Technique est haute) : plusieurs blocs d'un coup (Force) ; à côté : un bloc ; hors zone : raté.
# Chaque coup fatigue (Endurance) ; trop fatigué, le Pokémon est étourdi un moment. B : Pokémon suivant.
# Score : blocs cassés.
module Pokeathlon
  module Events
    class Block < Event
      PANEL_X = 6
      TOWER_X = 76
      BASE_Y = 196
      BLOCK_H = 18
      TOWER_Y = 160
      GAUGE = [14, 34, 172].freeze

      private

      def help_text
        return Pokeathlon.t('A / clic : frapper au centre de la jauge   B : changer de Pokémon', 'A / click: strike in the middle of the gauge   B: switch')
      end

      def setup
        add_sprite('fond_blocs', 0, 22, -100)
        @states = @teams.map do |team|
          { team: team, cursor: rand, dir: 1, fatigue: 0.0, dizzy: 0, leg: 0, lock: 0, shake: 0, aim: nil, offset: 0.0 }
        end
        # joueur : grande pile
        @tower = Array.new(6) { |i| add_sprite('bloc', TOWER_X, TOWER_Y - i * BLOCK_H, 10 + i) }
        @player_sprites = @teams[0].athletes.map do |a|
          sp = add_pokemon(a.pokemon)
          sp.visible = false
          sp
        end
        @gauge_back = add_sprite('jauge_blocs', GAUGE[0], GAUGE[1], 500)
        @zone = add_sprite('zone_blocs', 0, GAUGE[1] + 2, 501)
        @needle = add_sprite('aiguille', 0, GAUGE[1] - 3, 502)
        @fatigue_back = add_sprite('jauge_fond', PANEL_X + 2, 206, 8500)
        @fatigue = add_sprite('jauge', PANEL_X + 4, 208, 8501)
        @dizzy_text = add_text(PANEL_X, 120, 190, 16, Pokeathlon.t('Étourdi !', 'Dizzy!'), 1, 9, 900)
        # adversaires : petits panneaux
        @minis = @teams[1..].each_with_index.map do |team, i|
          y = 26 + i * 66
          add_sprite("panneau_#{team.index}", 204, y, -50)
          icons = team.athletes.map { |a| ic = add_icon(a.pokemon, 216, y + 34); ic.visible = false; ic }
          blocks = Array.new(4) { |k| add_sprite('bloc_petit', 268, y + 46 - k * 10, -40) }
          { icons: icons, blocks: blocks, text: add_text(244, y + 4, 66, 14, '0', 2, 9, -30) }
        end
      end

      def add_icon(pokemon, x, y)
        icon = UI::PokemonIconSprite.new(@viewport)
        icon.data = pokemon
        icon.set_position(x, y)
        @sprites << icon
        return icon
      end

      def athlete(st)
        return st[:team].athletes[st[:leg]]
      end

      def zone_width(ath)
        return ath.f('skill', 0.08, 0.16)
      end

      def update_play(ctrl)
        @states.each do |st|
          ath = athlete(st)
          speed = 0.018 + @time / time_limit.to_f * 0.012
          st[:cursor] += speed * st[:dir]
          if st[:cursor] >= 1 || st[:cursor] <= 0
            st[:dir] = -st[:dir]
            st[:cursor] = st[:cursor].clamp(0, 1)
          end
          st[:fatigue] = [st[:fatigue] - ath.f('stamina', 0.004, 0.008), 0].max
          st[:shake] -= 1 if st[:shake] > 0
          if st[:dizzy] > 0
            st[:dizzy] -= 1
            next
          end
          if st[:lock] > 0
            st[:lock] -= 1
            next
          end
          if st[:team].player?
            strike(st) if ctrl.a || ctrl.click
            switch(st) if ctrl.b
          else
            ai(st)
          end
        end
      end

      def ai(st)
        ath = athlete(st)
        switch(st) if st[:fatigue] > 0.75 && @difficulty >= 2
        st[:aim] ||= 0.5 + ai_error(0.06)
        return unless (st[:cursor] - st[:aim]).abs < 0.02

        strike(st)
        st[:aim] = nil
      end

      def strike(st)
        ath = athlete(st)
        diff = (st[:cursor] - 0.5).abs
        zone = zone_width(ath)
        broken = if diff <= zone / 2 then ath.f('power', 2, 4).round
                 elsif diff <= zone then 1
                 else 0
                 end
        st[:team].score += broken
        st[:fatigue] += ath.f('stamina', 0.3, 0.18)
        st[:shake] = 8
        if st[:fatigue] >= 1
          st[:dizzy] = 90
          st[:fatigue] = 0.6
        end
        return unless st[:team].player?

        if broken > 0
          Pokeathlon.play_se('smash')
          popup(TOWER_X + 20, TOWER_Y - 20, broken > 1 ? Pokeathlon.t("Super ! +#{broken}", "Great! +#{broken}") : '+1')
        else
          Pokeathlon.play_se('miss')
          popup(TOWER_X + 20, TOWER_Y - 20, Pokeathlon.t('Raté', 'Miss'))
        end
      end

      def switch(st)
        st[:leg] = (st[:leg] + 1) % 3
        st[:fatigue] = 0.0
        st[:dizzy] = 0
        st[:lock] = 30
        Pokeathlon.play_se('switch') if st[:team].player?
      end

      def update_sprites
        st = @states[0]
        ath = athlete(st)
        @player_sprites.each_with_index do |sp, i|
          sp.visible = i == st[:leg]
          next unless sp.visible

          sp.zoom = 2
          sp.set_position(TOWER_X + 20 + (st[:shake] > 0 ? (st[:shake].odd? ? 2 : -2) : 0), BASE_Y + 22)
          sp.face(3)
          sp.z = 50
        end
        offset = st[:team].score % 1
        @tower.each_with_index do |blk, i|
          blk.y = TOWER_Y - i * BLOCK_H + (st[:shake] > 4 ? 2 : 0)
          blk.src_rect.set(0, ((st[:team].score + i) % 3) * 18, 40, 18)
        end
        zone = zone_width(ath)
        x0 = GAUGE[0] + 4
        width = GAUGE[2] - 8
        @zone.src_rect.set(0, 0, (zone * 2 * width).round, 8)
        @zone.x = x0 + ((0.5 - zone) * width).round
        @needle.x = x0 + (st[:cursor] * width).round - 3
        @fatigue.src_rect.set(0, 0, ((1 - st[:fatigue].clamp(0, 1)) * 60).round, 6)
        @dizzy_text.visible = st[:dizzy] > 0
        @minis.each_with_index do |mini, i|
          other = @states[i + 1]
          mini[:icons].each_with_index { |ic, k| ic.visible = k == other[:leg] }
          mini[:text].text = other[:team].score.to_s
          mini[:blocks].each_with_index do |blk, k|
            blk.y = 26 + i * 66 + 46 - k * 10 + (other[:shake] > 4 ? 1 : 0)
            blk.src_rect.set(0, ((other[:team].score + k) % 3) * 9, 20, 9)
          end
        end
      end
    end
  end
end
