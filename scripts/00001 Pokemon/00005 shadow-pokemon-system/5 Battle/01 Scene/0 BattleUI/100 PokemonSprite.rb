module BattleUI
  class PokemonSprite < ShaderedSprite
    prepend UI::ShadowAura

    # Dresses the battler of a Shadow Pokemon.
    module ShadowAuraPatch
      # Set the Pokemon
      # @param pokemon [PFM::PokemonBattler]
      def pokemon=(pokemon)
        super
        refresh_shadow_aura(pokemon)
      end
    end

    prepend ShadowAuraPatch
  end
end
