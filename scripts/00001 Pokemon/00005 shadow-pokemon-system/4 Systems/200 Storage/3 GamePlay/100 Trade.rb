module GamePlay
  class PokemonTradeStorage < PokemonStorage
    # Turns down the trade of a Shadow Pokemon, and says why, the way the engine turns down a creature fused with another one right above
    module TradeStorageShadowPatch
      private

      # Offer what can be done with the creature the player picked
      def choice_trade
        return super unless @current_pokemon&.shadow?

        return display_message(PFM::ShadowTexts.message(:trade_refusal))
      end
    end

    prepend TradeStorageShadowPatch
  end
end
