module Battle
  module Actions
    # Action of calling out to a Shadow Pokemon, which opens the heart of one that lost control by
    # the largest amount its nature allows and sharpens the aim of one that kept it. It takes the
    # whole turn, like fleeing does.
    class Call < Base
      # Creates a new call action
      # @param scene [Battle::Scene]
      # @param battler [PFM::PokemonBattler] Shadow Pokemon being called
      def initialize(scene, battler)
        super(scene)
        @battler = battler
      end

      # Execute the action
      # @return [Integer] amount the heart lost
      def execute
        @scene.display_message_and_wait(PFM::ShadowTexts.creature_message(:call_out, @battler, PFM::Text::TRNAME[0] => $trainer.name))
        return call_calm_creature unless @battler.unstable?

        return soothe_creature
      end

      private

      # Call out to a creature that lost control, which calms it down and opens its heart.
      # @return [Integer] amount the heart lost
      def soothe_creature
        opened = @battler.soothe
        @scene.display_message_and_wait(PFM::ShadowTexts.creature_message(:reverse_mode_ended, @battler))
        message = opened.positive? ? PFM::ShadowTexts.creature_message(:heart_opened, @battler) : PFM::ShadowTexts.message(:call_unheard)
        @scene.display_message_and_wait(message)

        return opened
      end

      # Call out to a creature that kept control, which only catches its attention.
      # @return [Integer] nothing was opened
      def call_calm_creature
        @scene.display_message_and_wait(PFM::ShadowTexts.creature_message(:call_attentive, @battler))
        @scene.logic.stat_change_handler.stat_change_with_process(:acc, 1, @battler)

        return 0
      end
    end
  end
end
