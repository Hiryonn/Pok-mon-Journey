# Script décompilé depuis le bytecode du jeu (Ruby 3.0) — fichier d'origine : RMXP/99999_Systems_00101_Dex.rb
# Les commentaires et la mise en forme d'origine ne sont pas récupérables.

module PFM
  class Pokemon
    def shiny_attempts
      n = 1
      n += 2 if $bag.contain_item?(:shiny_charm)

      caught_count = $pokedex.creature_caught_count(db_symbol)

      case caught_count
      when (0..9) then multiplier = 1
      when (10..19) then multiplier = 2
      when (20..29) then multiplier = 4
      when (30..49) then multiplier = 8
      else
        multiplier = 16
      end

      n *= multiplier
      n
    end
  end
end

module UI
  module Dex
    class InfoPanel
      private

      def create_sprites
        add_background("WinInfos")

        @detail_sprites = [add_sprite(94, 64, "cadre_shiny_pokedex"), add_sprite(8, 4, "Catch"), add_text(29, 4, 116, 16, @form_name_symbol, type: SymText, color: 10), add_text(9, 27, 116, 16, :pokedex_species, type: SymText), add_text(9, 67, 116, 16, :pokedex_weight, type: SymText), add_text(9, 87, 116, 16, :pokedex_height, type: SymText), add_sprite(25, 47, NO_INITIAL_IMAGE, true, type: Type1Sprite), add_sprite(112, 47, NO_INITIAL_IMAGE, true, type: Type2Sprite), add_text(100, 67, 116, 16, :pokedex_nb_captured, type: SymText), add_text(100, 87, 116, 16, :pokedex_shiny_rate, type: SymText)]
      end
    end
  end
end
