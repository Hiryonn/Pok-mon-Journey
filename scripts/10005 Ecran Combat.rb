# Combat en pleine largeur (écran 640x360)
#
# Le combat est cadré comme les autres scènes (repère 320x240 centré, zoom 1,5). Ce fichier utilise la largeur gagnée à gauche et à droite :
# - décor : prolongé de chaque côté (reflet des bords) ; si l'image du décor est introuvable, un décor par défaut est affiché ;
# - bande du bas : étirée sur tout l'écran, texte collé à gauche, boutons collés à droite ;
# - boîtes d'infos : ennemi collé au bord gauche, joueur collé au bord droit ; Pokémon écartés vers les côtés ;
# - fenêtre de messages : sur toute la largeur.
# Les écrans d'infos / lancer rapide du plugin enhanced_battle_ui restent à refaire.
module Ecran
  module_function

  # @return [Integer] largeur (repère 320x240) gagnée à droite du cadre
  def marge_droite
    return [logique_largeur + logique_gauche - BASE_LARGEUR, 0].max
  end

  # @return [Integer] largeur (repère 320x240) gagnée à gauche du cadre
  def marge_gauche
    return [-logique_gauche, 0].max
  end

  # @param vp [Viewport, nil]
  # @return [Boolean]
  def combat_large?(vp)
    return grand? && cadre?(vp) && !vp.instance_variable_get(:@ecran_gauche)
  end

  # Décor du combat : image par défaut si l'image demandée n'existe pas, puis bords prolongés par reflet
  module DecorCombat
    def init_background_sprite
      if Ecran.grand? && !(RPG::Cache.battleback_exist?(@battleback_name.to_s) || Yuki::GifReader.exist?("#{@battleback_name}.gif", :battleback))
        defaut = %w[back_building back_tall_grass_day].find { |nom| RPG::Cache.battleback_exist?(nom) }
        @battleback_name = defaut if defaut
      end
      super
      prolonger_decor
    end

    private

    def prolonger_decor
      return unless Ecran.combat_large?(viewport)

      bitmap = @main_background&.bitmap
      return unless bitmap && !bitmap.disposed?

      largeur = bitmap.width
      hauteur = bitmap.height
      gauche = [Ecran.marge_gauche + 2, largeur].min
      droite = [Ecran.marge_droite + 2, largeur].min
      y = @main_background.y
      z = @main_background.z
      cote_gauche = Sprite.new(viewport)
      cote_gauche.bitmap = bitmap
      cote_gauche.src_rect.set(0, 0, gauche, hauteur)
      cote_gauche.mirror = true
      cote_gauche.set_position(@main_background.x - gauche, y)
      cote_droit = Sprite.new(viewport)
      cote_droit.bitmap = bitmap
      cote_droit.src_rect.set(largeur - droite, 0, droite, hauteur)
      cote_droit.mirror = true
      cote_droit.set_position(@main_background.x + largeur, y)
      [cote_gauche, cote_droit].each do |sprite|
        sprite.z = z
        push_sprite(sprite)
      end
    end
  end

  # Boîtes d'infos collées aux bords de l'écran
  module InfoCombat
    private

    def base_position_v1
      return ecran_bord(*super)
    end

    def base_position_v2
      return ecran_bord(*super)
    end

    def ecran_bord(x, y)
      return x, y unless Ecran.combat_large?(viewport)

      return enemy? ? x - Ecran.marge_gauche : x + Ecran.marge_droite, y
    end
  end

  # Pokémon écartés vers les côtés (l'ennemi à droite, le joueur à gauche)
  module SpriteCombat
    private

    def base_position_v1
      return ecran_ecart(*super)
    end

    def base_position_v2
      return ecran_ecart(*super)
    end

    def ecran_ecart(x, y)
      return x, y unless Ecran.combat_large?(viewport)

      return enemy? ? x + Ecran.marge_droite / 2 : x - Ecran.marge_gauche / 2, y
    end
  end

  # Fenêtre de messages sur toute la largeur
  module MessageCombat
    def default_width
      return super unless Ecran.combat_large?(viewport)

      return Ecran.logique_largeur - default_horizontal_margin * 2
    end

    def width=(value)
      return super unless Ecran.combat_large?(viewport)

      super(Ecran.logique_largeur - default_horizontal_margin * 2)
    end

    def calculate_position
      super
      return unless Ecran.combat_large?(viewport)

      set_position(Ecran.bord_gauche(viewport) + default_horizontal_margin, y)
    end
  end
end

if defined?(BattleUI::BattleBackground)
  BattleUI::BattleBackground.prepend(Ecran::DecorCombat) unless BattleUI::BattleBackground.include?(Ecran::DecorCombat)
end
BattleUI::InfoBar.prepend(Ecran::InfoCombat) if defined?(BattleUI::InfoBar)
BattleUI::PokemonSprite.prepend(Ecran::SpriteCombat) if defined?(BattleUI::PokemonSprite)
Battle::Scene::Message.prepend(Ecran::MessageCombat) if defined?(Battle::Scene::Message)

# Bande du bas et grille de boutons (interface Horizon du combat) : bande étirée, texte à gauche, boutons à droite
if defined?(BattleUI::PJ::Panel)
  module BattleUI
    module PJ
      module Panel
        private

        # @param lines [Integer] nombre de lignes de texte à gauche
        def create_pj_panel(lines = 3)
          large = Ecran.combat_large?(@viewport)
          gauche = large ? Ecran.bord_gauche(@viewport) : 0
          largeur = large ? Ecran.logique_largeur : 320
          panneau = add_sprite(gauche, PJ::PANEL_Y, PJ.file('command_panel'))
          panneau.zoom_x = largeur / 320.0
          texte = PJ::GRID_X + (gauche + largeur - 320) - (gauche + 8) - 4
          @pj_lines = Array.new(lines) { |i| add_text(gauche + 8, PJ::PANEL_Y + 3 + i * 15, texte, 16, '', 0, 1, color: PJ::WHITE) }
        end

        # Position de la case n° index de la grille (collée au bord droit)
        # @param index [Integer]
        # @return [Array(Integer, Integer)]
        def pj_cell(index)
          decalage = Ecran.combat_large?(@viewport) ? Ecran.marge_droite : 0
          return PJ::GRID_X + decalage + (index % 2) * PJ::CELL_W, PJ::GRID_Y + (index / 2) * (PJ::CELL_H + PJ::ROW_GAP)
        end
      end

      # Souris dans le repère de l'interface
      class GridButton
        def simple_mouse_in?(mouse_x = nil, mouse_y = nil)
          mouse_x, mouse_y = Ecran.cadre?(viewport) ? Ecran.souris(viewport) : [Mouse.x, Mouse.y] unless mouse_x
          return mouse_x.between?(x, x + PJ::CELL_W - 1) && mouse_y.between?(y, y + PJ::CELL_H)
        end
      end
    end
  end
end
