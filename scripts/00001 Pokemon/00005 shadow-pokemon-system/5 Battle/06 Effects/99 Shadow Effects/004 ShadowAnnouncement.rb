module Battle
  module Effects
    # Effect announcing a Shadow Pokemon someone else owns when it takes the field. The player has no
    # other way of telling one apart before the fight starts, the aura being invisible to the eye.
    class ShadowAnnouncement < Shadow
      # Function giving the name of the effect
      # @return [Symbol]
      def name
        return :shadow_announcement
      end

      # Function called when a Pokemon has actually switched with another one
      # @param handler [Battle::Logic::SwitchHandler]
      # @param who [PFM::PokemonBattler] Pokemon that is switched out
      # @param with [PFM::PokemonBattler] Pokemon that is switched in
      def on_switch_event(handler, who, with)
        return unless with == @target
        return if @target.from_party?

        handler.scene.display_message_and_wait(PFM::ShadowTexts.message(:shadow_spotted))
      end
    end

    Shadow::CLASSES << ShadowAnnouncement
  end
end
