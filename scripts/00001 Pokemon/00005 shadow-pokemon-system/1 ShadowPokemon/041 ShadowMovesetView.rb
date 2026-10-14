module PFM
  # Stands in for a Shadow Pokemon in the interfaces that read its moves by index, so a locked slot
  # shows where an original move is still held back. Those interfaces read the list and nothing else
  # of the creature, so nothing else is forwarded, and the battle logic never meets this object.
  class ShadowMovesetView
    # Wrap a creature whose heart holds moves back, and leave any other one alone.
    # @param creature [PFM::Pokemon, PFM::PokemonBattler, nil]
    # @return [PFM::Pokemon, PFM::PokemonBattler, PFM::ShadowMovesetView, nil]
    def self.wrap(creature)
      return creature unless creature.is_a?(PFM::Pokemon) && creature.shadow?
      return creature if creature.locked_moves.empty?

      return new(creature)
    end

    # @param creature [PFM::Pokemon, PFM::PokemonBattler]
    def initialize(creature)
      @creature = creature
    end

    # Moves shown in battle, the usable ones then a locked slot per move the heart holds back.
    # @return [Array<Battle::Move, PFM::LockedMove>]
    def moveset
      return @creature.moveset + @creature.locked_moves
    end

    # Moves shown outside battle, the usable ones then a locked slot per move the heart holds back.
    # @return [Array<PFM::Skill, PFM::LockedMove>]
    def skills_set
      return @creature.skills_set.compact + @creature.locked_moves
    end
  end
end
