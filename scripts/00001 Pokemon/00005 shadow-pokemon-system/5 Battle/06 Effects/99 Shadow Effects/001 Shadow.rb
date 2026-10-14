module Battle
  module Effects
    # Base class of the effects a Shadow Pokemon carries through a battle. They live in a slot of
    # their own on the battler rather than among its effects, because the engine throws those away
    # every time a creature leaves the field, and a Shadow Pokemon keeps being one on the bench.
    class Shadow < EffectBase
      # Creature the effect watches
      # @return [PFM::PokemonBattler]
      attr_reader :target

      # Classes a Shadow Pokemon is given, in the order they answer. Left open on purpose, a game or
      # another plugin adds its own behaviour by pushing a class here.
      # @return [Array<Class<Shadow>>]
      CLASSES = []

      # Create a new Shadow effect
      # @param logic [Battle::Logic]
      # @param target [PFM::PokemonBattler] creature the effect watches
      def initialize(logic, target)
        super(logic)
        @target = target
      end

      # Whether the creature is a Shadow Pokemon the player owns, the only one the original game lets
      # break down and purify. Answered on the spot rather than held, a snag handing a creature over
      # in the middle of a battle.
      # @return [Boolean]
      def watched?
        return @target.shadow? && @target.from_party?
      end
    end
  end
end
