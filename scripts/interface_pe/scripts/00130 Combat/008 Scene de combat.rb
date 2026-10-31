# Interface PE — combat : réglages de la scène (position du Pokémon du joueur, boîte d'infos, Poké Balls de l'équipe)
module BattleUI
  # Pokémon du joueur remonté au-dessus de la bande du bas
  class PokemonSprite
    module PJStyle
      private

      def base_position_v1
        x, y = super
        return x, y if enemy? || !PJ.active?

        return x, y - PJ::PLAYER_SPRITE_RAISE
      end

      def base_position_v2
        x, y = super
        return x, y if enemy? || !PJ.active?

        return x, y - PJ::PLAYER_SPRITE_RAISE
      end
    end
    prepend PJStyle if PJ::ENABLED
  end

  # Poké Balls de l'équipe du joueur cachées
  class TrainerPartyBalls
    module PJStyle
      def initialize(viewport, scene, bank)
        @pj_hidden = PJ::HIDE_PLAYER_PARTY_BALLS && bank == 0 && PJ.active?
        super
        self.visible = false if @pj_hidden
      end

      # @param value [Boolean]
      def visible=(value)
        super(value && !@pj_hidden)
      end
    end
    prepend PJStyle if PJ::ENABLED
  end
end

module Battle
  class Visual
    module PJBars
      # Pendant les choix, la boîte d'infos du Pokémon du joueur reste affichée
      def set_info_state(state, pokemon = nil)
        super
        show_info_bars(bank: 0) if state == :choice && pj_keep_player_bar?
      end

      # Les menus de PSDK cachent la boîte du joueur : on la garde
      def hide_info_bars(no_animation = false, bank: nil)
        return if bank == 0 && pj_keep_player_bar?

        super
      end

      private

      def pj_keep_player_bar?
        return BattleUI::PJ::KEEP_PLAYER_BAR && BattleUI::PJ.active?
      end
    end
    prepend PJBars if BattleUI::PJ::ENABLED
  end
end
