# Interface PE — combat : boîtes d'infos des Pokémon (nom, sexe, niveau, PV, expérience, statut)
module BattleUI
  module PJ
    # Sexe : ♂ / ♀ (rien si asexué)
    class GenderIcon < SpriteSheet
      def initialize(viewport)
        super(viewport, 2, 1)
        set_bitmap(PJ.file('gender'), :interface)
      end

      # @param pokemon [PFM::Pokemon]
      def data=(pokemon)
        gender = pokemon&.gender.to_i
        self.visible = gender.between?(1, 2)
        self.sx = gender - 1 if visible
      end
    end

    # Statut : étiquette (BRN, PAR…) selon le statut de PSDK
    class StatusIcon < SpriteSheet
      def initialize(viewport)
        super(viewport, 1, 10)
        set_bitmap(PJ.file('status'), :interface)
      end

      # @param pokemon [PFM::Pokemon]
      def data=(pokemon)
        status = pokemon&.status.to_i
        self.visible = status.between?(1, 9)
        self.sy = status if visible
      end
    end
  end

  class InfoBar
    # Fond de la boîte (ennemi / joueur et alliés)
    class Background
      module PJStyle
        def background_filename(pokemon)
          return super unless PJ.active?

          return PJ.file(pokemon.bank != 0 ? 'databox_enemy' : 'databox_player')
        end
      end
      prepend PJStyle if PJ::ENABLED
    end

    module PJStyle
      private

      def create_sprites
        return super unless PJ.active?

        create_background
        enemy? ? create_pj_enemy : create_pj_player
      end

      def create_pj_enemy
        @name = add_text(6, -2, 76, 16, :given_name, 0, 1, color: PJ::WHITE, type: UI::SymText)
        @star = add_sprite(83, 4, PJ.file('shiny'))
        add_sprite(91, 3, nil, type: PJ::GenderIcon)
        add_sprite(99, 5, PJ.file('level'))
        add_text(107, -2, 0, 16, :level, 0, 1, color: PJ::WHITE, type: UI::SymText)
        create_pj_hp_bar(36, 17)
        add_sprite(9, 17, nil, type: PJ::StatusIcon)
        add_sprite(121, 15, PJ.file('caught'), type: PokemonCaughtSprite)
      end

      def create_pj_player
        @name = add_text(30, -2, 72, 16, :given_name, 0, 1, color: PJ::WHITE, type: UI::SymText)
        @star = add_sprite(100, 4, PJ.file('shiny'))
        add_sprite(107, 3, nil, type: PJ::GenderIcon)
        add_sprite(115, 5, PJ.file('level'))
        add_text(123, -2, 0, 16, :level, 0, 1, color: PJ::WHITE, type: UI::SymText)
        create_pj_hp_bar(51, 17)
        add_text(24, 19, 40, 16, :hp, 2, 1, color: PJ::WHITE, type: UI::SymText)
        add_text(72, 19, 22, 16, :max_hp, 0, 1, color: PJ::WHITE, type: UI::SymText)
        @exp_bar = push_sprite UI::Bar.new(@viewport, x + 95, y + 24, RPG::Cache.interface(PJ.file('exp_bar')), 38, 2, 0, 0, 1)
        @exp_bar.data_source = :exp_rate
        add_sprite(28, 16, nil, type: PJ::StatusIcon)
      end

      # @param bar_x [Integer]
      # @param bar_y [Integer]
      def create_pj_hp_bar(bar_x, bar_y)
        @hp_bar = push_sprite UI::Bar.new(@viewport, x + bar_x, y + bar_y, RPG::Cache.interface(PJ.file('hp_bar')), 82, 3, 0, 0, 6)
        @hp_bar.data_source = :hp_rate
      end

      def base_position_v1
        return super unless PJ.active?

        return enemy? ? PJ::ENEMY_BOX : PJ::PLAYER_BOX
      end

      def base_position_v2
        return super unless PJ.active?

        return enemy? ? PJ::ENEMY_BOX_DOUBLE : PJ::PLAYER_BOX_DOUBLE
      end

      def offset_position_v2
        return super unless PJ.active?

        return enemy? ? PJ::ENEMY_OFFSET : PJ::PLAYER_OFFSET
      end
    end
    prepend PJStyle if PJ::ENABLED
  end
end
