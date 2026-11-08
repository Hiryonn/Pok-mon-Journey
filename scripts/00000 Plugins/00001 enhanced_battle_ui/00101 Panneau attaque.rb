# Enhanced Battle UI — panneau des infos de l'attaque choisie
#
#  ┌ nom de l'attaque ───────────────┐ type  catégorie ┌ PP ┐
#  particularités (contact, son…)      ┌Pui┐ ┌Pré┐ ┌Eff┐
#  ┌ description ─────────────────────────────────────────┐
#
# Au-dessus, à droite : une case par adversaire avec son icône et l'efficacité de l'attaque.
module BattleUI
  module EBUI
    class MovePanel < UI::SpriteStack
      # Hauteur d'une ligne de move_panel.png
      HEIGHT = 82
      # Taille d'une case d'efficacité
      BOX_W = 32
      BOX_H = 38

      # @param viewport [Viewport]
      # @param y [Integer]
      def initialize(viewport, y)
        super(viewport, 0, y)
        @rows = RPG::Cache.interface(EBUI.file('move_panel')).height / HEIGHT
        create_sprites
        self.visible = false
      end

      # Affiche l'attaque
      # @param move [Battle::Move, nil]
      # @param user [PFM::PokemonBattler]
      # @param logic [Battle::Logic]
      def show_move(move, user, logic)
        return self.visible = false unless move

        self.visible = true
        data = move.data
        @background.sy = move.type < @rows ? move.type : 0
        @name.text = move.name
        @type.data = move
        @category.sy = (move.atk_class || 1) - 1
        @pp.text = "#{EBUI.text(:pp)} #{move.pp}/#{move.ppmax}"
        @pp.load_color(move.pp == 0 ? 2 : EBUI::DARK)
        @power.text = "#{EBUI.text(:power)} #{move.power_text}"
        @accuracy.text = "#{EBUI.text(:accuracy)} #{move.accuracy_text}"
        @chance.text = "#{EBUI.text(:effect)} #{effect_chance_text(move, data)}"
        @description.multiline_text = move.description.to_s
        refresh_flags(data)
        refresh_targets(move, user, logic)
      end

      # @param value [Boolean]
      def visible=(value)
        super
        @flags&.each { |sprite| sprite.visible = false } unless value
        @boxes&.each { |box| box.each { |sprite| sprite.visible = false } } unless value
      end

      private

      def create_sprites
        @background = add_sprite(0, 0, EBUI.file('move_panel'), 1, @rows, type: SpriteSheet)
        @name = add_text(6, 1, 160, 16, '', 0, color: EBUI::DARK)
        # Petites étiquettes adaptées au panneau (type 32 x 11, catégorie 17 x 9)
        @type = add_sprite(190, 5, nil, :type, type: TypeLabel)
        @category = add_sprite(226, 6, EBUI.file('categories'), 1, 3, type: SpriteSheet)
        with_font(EBUI::SMALL_FONT) do
          @pp = add_text(266, 5, 48, 13, '', 1, color: EBUI::DARK)
          @power = add_text(160, 19, 48, 13, '', 1, color: EBUI::DARK)
          @accuracy = add_text(216, 19, 49, 13, '', 1, color: EBUI::DARK)
          @chance = add_text(273, 19, 42, 13, '', 1, color: EBUI::DARK)
          @description = add_text(8, 36, 304, 13, '', 0, color: EBUI::DARK)
        end
        @flags = Array.new(11) { |i| add_sprite(4 + i * 14, 17, EBUI.file('move_flags'), EBUI::FLAGS.size, 1, type: SpriteSheet) }
        @boxes = Array.new(3) do |i|
          bx = 320 - (BOX_W + 2) * (i + 1)
          by = -BOX_H - 2
          [add_sprite(bx, by, EBUI.file('move_effectiveness'), 5, 1, type: SpriteSheet),
           add_sprite(bx, by + 5, nil, false, type: UI::PokemonIconSprite)]
        end
      end

      # @param move [Battle::Move]
      # @param data [Studio::Move]
      # @return [String]
      def effect_chance_text(move, data)
        return '--' if data.effect_chance.to_i == 0 && data.move_status.empty? && data.battle_stage_mod.empty?

        return "#{move.effect_chance}%"
      rescue StandardError
        return '--'
      end

      # @param data [Studio::Move]
      def refresh_flags(data)
        active = EBUI::FLAGS.each_index.select do |index|
          EBUI::FLAGS[index][1].call(data)
        rescue StandardError
          false
        end
        @flags.each_with_index do |sprite, i|
          next sprite.visible = false unless (index = active[i])

          sprite.visible = true
          sprite.sx = index
        end
      end

      # Cases d'efficacité sur les adversaires en jeu
      # @param move [Battle::Move]
      # @param user [PFM::PokemonBattler]
      # @param logic [Battle::Logic]
      def refresh_targets(move, user, logic)
        foes = EBUI::SHOW_EFFECTIVENESS ? foes_of(user, logic) : []
        @boxes.each_with_index do |(box, icon), i|
          foe = foes[i]
          box.visible = icon.visible = !foe.nil?
          next unless foe

          box.sx = EBUI.effectiveness_frame(EBUI.effectiveness(move, foe))
          icon.data = foe
        end
      end

      # Adversaires en jeu (de droite à gauche comme sur le terrain)
      # @return [Array<PFM::PokemonBattler>]
      def foes_of(user, logic)
        bank = user.bank == 0 ? 1 : 0
        return logic.battle_info.vs_type.times.map { |position| logic.battler(bank, position) }.compact.select(&:alive?)
      rescue StandardError
        return []
      end
    end
  end
end
