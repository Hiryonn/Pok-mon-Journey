# Interface PE — combat : choix de l'attaque (grille 2 x 2 de boutons colorés selon le type)
module BattleUI
  class SkillChoice
    # Bouton d'une attaque : fond du type, nom, catégorie, efficacité sur l'adversaire, PP
    class MoveButton
      module PJStyle
        # @param pokemon [PFM::PokemonBattler]
        def data=(pokemon)
          return super unless @pj

          @data = move = pokemon.moveset[@index]
          return unless (self.visible = move)

          rows = @background.bitmap.height / PJ::CELL_H
          @background.sy = move.type < rows ? move.type : 0
          @name.text = move.name
          @pp.text = "#{move.pp}/#{move.ppmax}"
          @pp.load_color(move.pp == 0 ? 2 : PJ::WHITE)
          @category.sy = (move.atk_class || 1) - 1
          factor = PJ.effectiveness(move, pj_target(pokemon))
          @effectiveness.visible = !factor.nil?
          @effectiveness.sy = PJ.effectiveness_row(factor) if factor
        end

        private

        def create_sprites
          return super unless PJ.active?

          @pj = true
          rows = RPG::Cache.interface(PJ.file('move_buttons')).height / PJ::CELL_H
          @background = add_sprite(0, 0, PJ.file('move_buttons'), 1, rows, type: SpriteSheet)
          @name = add_text(4, -1, 64, 16, '', 0, 1, color: PJ::WHITE)
          @effectiveness = add_sprite(69, 2, PJ.file('effectiveness'), 1, 6, type: SpriteSheet)
          @category = add_sprite(36, 12, PJ.file('categories'), 1, 3, type: SpriteSheet)
          with_font(20) { @pp = add_text(62, 10, 30, 13, '', 2, 1, color: PJ::WHITE) }
        end

        # Premier adversaire en jeu (pour l'efficacité affichée)
        # @param pokemon [PFM::PokemonBattler]
        # @return [PFM::PokemonBattler, nil]
        def pj_target(pokemon)
          logic = $scene.respond_to?(:logic) ? $scene.logic : nil
          return nil unless logic

          bank = pokemon.bank == 0 ? 1 : 0
          return 3.times.map { |position| logic.battler(bank, position) }.compact.find(&:alive?)
        rescue StandardError
          return nil
        end
      end
      prepend PJStyle if PJ::ENABLED
    end

    module PJStyle
      include PJ::Panel

      # Texte de gauche : type et catégorie, puissance / précision, touches
      # @param pokemon [PFM::PokemonBattler]
      def data=(pokemon)
        super
        return unless @pj && pokemon

        move = pokemon.moveset[@index]
        return self.pj_lines = [] unless move

        hint = PJ.text(:hint_skill)
        special = pj_special_hint(pokemon)
        hint = "#{PJ.text(:hint_short)}   #{special}" if special
        self.pj_lines = ["#{PJ.text(:power)} #{move.power_text}", "#{PJ.text(:accuracy)} #{move.accuracy_text}", hint]
      end

      private

      def create_sprites
        return super unless PJ.active?

        @pj = true
        create_pj_panel
        super
        pj_hide_special_buttons(@sub_choice)
        @info&.set_position(-400, -400)
      end

      def create_cursor
        return super unless @pj

        @cursor = add_sprite(0, 0, PJ.file('button_cursor'), type: PJ::FrameCursor)
      end

      def cursor_offset_x
        return @pj ? 0 : super
      end

      def cursor_offset_y
        return @pj ? 0 : super
      end

      # Grille 2 x 2 : boutons dans l'ordre, sans décalage du bouton choisi
      def update_button_opacity
        return super unless @pj

        buttons.each_with_index do |button, index|
          next unless button.visible

          button.opacity = 255
          cx, cy = pj_cell(index)
          button.set_position(cx + @x, cy + @y)
        end
      end

      # Haut / bas : ligne, gauche / droite : colonne
      def update_key_index
        return super unless @pj

        count = @buttons.count(&:visible)
        return if count == 0

        target = @index
        target -= 2 if Input.repeat?(:UP)
        target += 2 if Input.repeat?(:DOWN)
        target -= 1 if Input.repeat?(:LEFT) && @index.odd?
        target += 1 if Input.repeat?(:RIGHT) && @index.even?
        target = count - 1 if Input.repeat?(:DOWN) && target >= count && @index < 2 # pas d'attaque en dessous : la dernière
        @index = target if target.between?(0, count - 1)
      end

      # Texte de la touche Y (méga ; le plugin gimmicks le remplace par la mécanique choisie)
      # @param pokemon [PFM::PokemonBattler]
      # @return [String, nil]
      def pj_special_hint(pokemon)
        return pj_can_mega?(pokemon) ? PJ.text(:hint_mega) : nil
      end

      # @param pokemon [PFM::PokemonBattler]
      def pj_can_mega?(pokemon)
        return @scene.logic.mega_evolve.can_pokemon_mega_evolve?(pokemon)
      rescue StandardError
        return false
      end
    end
    prepend PJStyle if PJ::ENABLED
  end
end
