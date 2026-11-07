# Enhanced Battle UI — page d'infos d'un Pokémon en combat
#
# Dresseur et tour, Pokémon (icône, PV, types), talent et objet (Pokémon du joueur), niveau et statut,
# dernière attaque utilisée, modifications de stats (flèches), effets en cours avec les tours restants
# et la description de l'effet choisi.
module BattleUI
  module EBUI
    class BattlerInfo < UI::SpriteStack
      # Positions (les cases fixes sont dessinées dans info_bg.png par tools/build_assets.py : LAYOUT)
      POKE_BOX = [12, 30]
      LV_BOX = [12, 60]
      USED_BOX = [162, 60]
      STAT_ROWS = [12, 82, 14]
      EFFECTS = [162, 82, 15]
      EFFECT_ROWS = 4
      SLIDER = [305, 82, 60]
      DESC_BOX = [162, 148]
      # Statistiques : méthode de niveau (et nombre de points)
      STAT_STAGES = %i[atk_stage dfe_stage ats_stage dfs_stage spd_stage acc_stage eva_stage critical].freeze

      # @return [Integer] effet choisi
      attr_reader :effect_index

      # @param viewport [Viewport]
      # @param logic [Battle::Logic]
      def initialize(viewport, logic)
        super(viewport)
        @logic = logic
        @effect_index = 0
        @effect_top = 0
        @effects = []
        create_sprites
      end

      # @param battler [PFM::PokemonBattler]
      # @param has_neighbours [Boolean] flèches gauche / droite
      def show_battler(battler, has_neighbours)
        @battler = battler
        @effects = collect_effects(battler)
        @effect_index = @effect_top = 0
        own = battler.bank == 0
        @owner.text = EBUI.owner_name(@logic, battler)
        @turn.text = format(EBUI.text(:turn), $game_temp.battle_turn.to_i + 1)
        @arrows.each { |arrow| arrow.visible = has_neighbours }
        refresh_pokemon(battler, own)
        refresh_extra(battler, own || EBUI::SHOW_FOE_ABILITY)
        refresh_stats(battler)
        refresh_effects
      end

      # Haut / bas dans la liste des effets
      # @return [Boolean] le choix a changé
      def update_input
        return false if @effects.size <= 1

        last = @effect_index
        @effect_index -= 1 if Input.repeat?(:UP)
        @effect_index += 1 if Input.repeat?(:DOWN)
        @effect_index = @effect_index.clamp(0, @effects.size - 1)
        return false if last == @effect_index

        refresh_effects
        return true
      end

      private

      def create_sprites
        add_sprite(0, 0, EBUI.file('info_bg'))
        create_header
        create_pokemon
        create_extra
        create_stats
        create_effects
      end

      def create_header
        add_sprite(4, 15, EBUI.file('info_owner'), 1, 2, type: SpriteSheet).sy = 0
        add_sprite(256, 15, EBUI.file('info_owner'), 1, 2, type: SpriteSheet).sy = 1
        @arrows = [add_sprite(2, 36, EBUI.file('info_arrows'), rect: [0, 0, 6, 11]),
                   add_sprite(312, 36, EBUI.file('info_arrows'), rect: [6, 0, 6, 11])]
        with_font(EBUI::SMALL_FONT) do
          @owner = add_text(8, 14, 56, 13, '', 0, color: EBUI::WHITE)
          @turn = add_text(258, 14, 60, 13, '', 1, color: EBUI::DARK)
          @help = add_text(0, 202, 320, 13, EBUI.text(:info_help), 1, color: EBUI::WHITE)
        end
      end

      def create_pokemon
        x, y = POKE_BOX
        @icon = add_sprite(x + 1, y - 6, nil, false, type: UI::PokemonIconSprite)
        with_font(EBUI::SMALL_FONT) { @name = add_text(x + 28, y, 50, 13, '', 0, color: EBUI::DARK) }
        @hp_bar = add_sprite(x + 28, y + 14, EBUI.file('info_hp'))
        @gender = add_sprite(x + 79, y - 4, EBUI.file('info_gender'), 2, 1, type: SpriteSheet)
        @type1 = add_sprite(x + 87, y, nil, type: UI::Type1Sprite)
        @type2 = add_sprite(x + 87, y + 15, nil, type: UI::Type2Sprite)
        lx, ly = LV_BOX
        @status = add_sprite(lx + 48, ly + 4, nil, type: UI::StatusSprite)
        ux, uy = USED_BOX
        with_font(EBUI::SMALL_FONT) do
          @level = add_text(lx + 5, ly + 1, 40, 13, '', 0, color: EBUI::WHITE)
          @hp = add_text(lx + 76, ly + 1, 50, 13, '', 2, color: EBUI::WHITE)
          @used = add_text(ux + 5, uy + 1, 140, 13, '', 0, color: EBUI::WHITE)
        end
      end

      def create_extra
        @extra = Array.new(2) do |i|
          row = add_sprite(162, 31 + i * 14, EBUI.file('info_extra_row'))
          with_font(EBUI::SMALL_FONT) do
            label = add_text(166, 30 + i * 14, 50, 13, EBUI.text(i == 0 ? :ability : :item), 0, color: EBUI::WHITE)
            value = add_text(206, 30 + i * 14, 104, 13, '', 0, color: EBUI::DARK)
            next [row, label, value]
          end
        end
      end

      def create_stats
        x, y, pitch = STAT_ROWS
        names = EBUI.text(:stats)
        @stat_marks = Array.new(8) do |row|
          ry = y + row * pitch
          with_font(EBUI::SMALL_FONT) { add_text(x + 4, ry - 1, 54, 13, names[row], 0, color: EBUI::WHITE) }
          dots = row == 7 ? 3 : 6
          Array.new(dots) do |i|
            [add_sprite(x + 62 + i * 10, ry + 4, EBUI.file('info_dot')),
             add_sprite(x + 60 + i * 10, ry + 1, EBUI.file('info_stats'), 2, 1, type: SpriteSheet)]
          end
        end
      end

      def create_effects
        x, y, pitch = EFFECTS
        @effect_rows = Array.new(EFFECT_ROWS) do |i|
          frame = add_sprite(x, y + i * pitch, EBUI.file('info_effect_rows'), 1, 2, type: SpriteSheet)
          with_font(EBUI::SMALL_FONT) do
            name = add_text(x + 4, y + i * pitch - 1, 100, 13, '', 0, color: EBUI::DARK)
            turns = add_text(x + 108, y + i * pitch - 1, 28, 13, '', 1, color: EBUI::WHITE)
            next [frame, name, turns]
          end
        end
        sx, sy, = SLIDER
        @slider = add_sprite(sx, sy, EBUI.file('info_slider_base'))
        @thumb = add_sprite(sx, sy, EBUI.file('info_slider'), rect: [9, 0, 9, 9])
        dx, dy = DESC_BOX
        with_font(EBUI::SMALL_FONT) { @description = add_text(dx + 5, dy + 2, 140, 13, '', 0, color: EBUI::DARK) }
      end

      # @param battler [PFM::PokemonBattler]
      # @param own [Boolean]
      def refresh_pokemon(battler, own)
        @icon.data = battler
        @name.text = battler.given_name
        rate = battler.max_hp > 0 ? battler.hp.to_f / battler.max_hp : 0
        width = (48 * rate).ceil.clamp(battler.hp > 0 ? 1 : 0, 48)
        @hp_bar.src_rect.set(0, (rate > 0.5 ? 0 : rate > 0.2 ? 1 : 2) * 3, width, 3)
        @gender.visible = battler.gender.to_i > 0
        @gender.sx = battler.gender.to_i == 2 ? 1 : 0
        @type1.data = battler
        @type2.data = battler
        @type2.visible = battler.type2.to_i != 0
        @status.data = battler
        @level.text = format(EBUI.text(:level), battler.level)
        @hp.visible = own
        @hp.text = format(EBUI.text(:hp), battler.hp, battler.max_hp)
        last = battler.move_history.last
        @used.text = last ? format(EBUI.text(:used), last.move.name) : EBUI.text(:none_used)
      end

      # Talent et objet
      # @param battler [PFM::PokemonBattler]
      # @param visible [Boolean]
      def refresh_extra(battler, visible)
        @extra.each { |parts| parts.each { |sprite| sprite.visible = visible } }
        return unless visible

        @extra[0][2].text = ability_name(battler)
        item = battler.battle_item_db_symbol
        @extra[1][2].text = item && item != :__undef__ ? data_item(item).name : EBUI.text(:no_item)
      end

      # @param battler [PFM::PokemonBattler]
      # @return [String]
      def ability_name(battler)
        db_symbol = battler.battle_ability_db_symbol
        return EBUI.text(:no_item) if db_symbol.nil? || db_symbol == :__undef__

        return data_ability(db_symbol).name
      rescue StandardError
        return EBUI.text(:no_item)
      end

      # Points et flèches des statistiques
      # @param battler [PFM::PokemonBattler]
      def refresh_stats(battler)
        STAT_STAGES.each_with_index do |method, row|
          stage = method == :critical ? EBUI.critical_stage(battler) : battler.public_send(method).to_i
          @stat_marks[row].each_with_index do |(dot, arrow), i|
            marked = i < stage.abs
            dot.visible = !marked
            arrow.visible = marked
            arrow.sx = stage > 0 ? 0 : 1
          end
        end
      end

      # Liste des effets visibles
      def refresh_effects
        @effect_top = @effect_index - EFFECT_ROWS + 1 if @effect_index >= @effect_top + EFFECT_ROWS
        @effect_top = @effect_index if @effect_index < @effect_top
        @effect_rows.each_with_index do |(frame, name, turns), i|
          effect = @effects[@effect_top + i]
          frame.visible = name.visible = turns.visible = !effect.nil?
          next unless effect

          selected = @effect_top + i == @effect_index
          frame.sy = selected ? 1 : 0
          name.text = effect[:name]
          turns.text = effect[:turns]
        end
        refresh_slider
        current = @effects[@effect_index]
        @description.multiline_text = current ? current[:description].to_s : EBUI.text(:no_effect)
      end

      def refresh_slider
        sx, sy, height = SLIDER
        @slider.visible = @thumb.visible = @effects.size > EFFECT_ROWS
        return unless @slider.visible

        travel = height - 9 - 18
        ratio = @effect_index.to_f / [@effects.size - 1, 1].max
        @thumb.set_position(sx, sy + 9 + (travel * ratio).round)
      end

      # Effets en cours qui concernent le Pokémon : météo, champ, terrain, son côté, sa place, lui-même
      # @param battler [PFM::PokemonBattler]
      # @return [Array<Hash>] { name:, turns:, description: }
      def collect_effects(battler)
        list = []
        weather = $env.current_weather_db_symbol
        add_effect(list, weather, weather_turns) if weather && !%i[none __undef__].include?(weather)
        terrain = @logic.field_terrain
        add_effect(list, terrain, counter_text(@logic.field_terrain_effect.internal_counter)) if terrain && terrain != :none
        @logic.terrain_effects.each { |effect| add_battle_effect(list, effect) }
        @logic.bank_effects[battler.bank]&.each { |effect| add_battle_effect(list, effect) }
        @logic.position_effects.dig(battler.bank, battler.position)&.each { |effect| add_battle_effect(list, effect) }
        battler.effects.each { |effect| add_battle_effect(list, effect) }
        return list.uniq { |effect| effect[:name] }
      rescue StandardError => e
        log_error("Enhanced Battle UI : effets illisibles (#{e.message})") if respond_to?(:log_error, true)
        return list || []
      end

      # @param list [Array<Hash>]
      # @param effect [Battle::Effects::EffectBase]
      def add_battle_effect(list, effect)
        return if effect.dead?

        counter = effect.instance_variable_get(:@counter)
        turns = counter_text(counter)
        power = effect.respond_to?(:power) ? effect.power.to_i : 0
        turns = format(EBUI.text(:layers), power) if power > 0 && %i[spikes toxic_spikes].include?(effect.name)
        turns = format(EBUI.text(:layers), effect.stockpile) if effect.name == :stockpile && effect.respond_to?(:stockpile)
        add_effect(list, effect.name, turns)
      rescue StandardError
        nil
      end

      # @param list [Array<Hash>]
      # @param key [Symbol]
      # @param turns [String]
      def add_effect(list, key, turns)
        texts = EBUI.effect_text(key)
        return unless texts

        list << { name: texts[0], turns: turns, description: texts[1] }
      end

      # @return [String]
      def weather_turns
        return counter_text($env.weather_duration)
      rescue StandardError
        return EBUI.text(:infinite)
      end

      # @param counter [Numeric, nil]
      # @return [String]
      def counter_text(counter)
        return EBUI.text(:infinite) if counter.nil? || !counter.finite? || counter > 99 || counter <= 0

        return counter.to_i.to_s
      rescue StandardError
        return EBUI.text(:infinite)
      end
    end
  end
end
