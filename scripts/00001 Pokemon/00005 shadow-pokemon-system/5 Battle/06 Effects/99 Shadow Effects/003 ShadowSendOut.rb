module Battle
  module Effects
    # Effect opening the heart of a Shadow Pokemon the first time it is sent out to a battle. Pokemon
    # XD pays a creature for taking the field, once per battle and not once per switch, which is why
    # the mark lives here: the effect is built with the battler and lasts the whole fight.
    class ShadowSendOut < Shadow
      # Function giving the name of the effect
      # @return [Symbol]
      def name
        return :shadow_send_out
      end

      # Function called when a Pokemon has actually switched with another one
      # @param handler [Battle::Logic::SwitchHandler]
      # @param who [PFM::PokemonBattler] Pokemon that is switched out
      # @param with [PFM::PokemonBattler] Pokemon that is switched in
      def on_switch_event(handler, who, with)
        return unless with == @target
        return unless watched?
        return if @sent_out

        @sent_out = true
        @target.enter_battle
      end
    end

    Shadow::CLASSES << ShadowSendOut
  end
end
