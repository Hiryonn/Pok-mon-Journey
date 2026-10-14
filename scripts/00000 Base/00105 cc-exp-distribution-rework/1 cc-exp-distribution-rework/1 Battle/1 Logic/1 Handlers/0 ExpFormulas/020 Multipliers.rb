module Battle
  class Logic
    class ExpHandler
      class BaseFormula
        # Multiplier based on whether the battle is a trainer battle
        # @return [Float] the trainer multiplier
        def trainer_multiplier
          return 1.0 unless trainer_bonus?
          return 1.0 unless handler.logic.battle_info.trainer_battle?

          return trainer_multiplier_value
        end

        # Multiplier based on whether the receiver was traded
        # @param receiver [PFM::PokemonBattler] the Pokemon receiving experience
        # @return [Float] the trade multiplier
        def trade_multiplier(receiver)
          return 1.0 unless trade_bonus?
          return 1.0 if receiver.from_player?

          return trade_multiplier_value
        end

        # Multiplier based on whether the receiver is holding a Lucky Egg
        # @param receiver [PFM::PokemonBattler] the Pokemon receiving experience
        # @return [Float] the Lucky Egg multiplier
        def lucky_egg_multiplier(receiver)
          return 1.0 unless lucky_egg_bonus?
          return 1.0 unless receiver.hold_item?(:lucky_egg)

          return lucky_egg_multiplier_value
        end

        # Multiplier based on whether the receiver can evolve but has not yet
        # @param receiver [PFM::PokemonBattler] the Pokemon receiving experience
        # @return [Float] the evolution multiplier
        def evolution_multiplier(receiver)
          return 1.0 unless evolution_bonus?
          return 1.0 unless receiver.evolve_check(:level_up)

          return evolution_multiplier_value
        end

        # Multiplier based on the receiver's loyalty
        # @param receiver [PFM::PokemonBattler] the Pokemon receiving experience
        # @return [Float] the loyalty multiplier
        def loyalty_multiplier(receiver)
          return 1.0 unless loyalty_bonus?
          return 1.0 if receiver.loyalty < loyalty_threshold

          return loyalty_multiplier_value
        end

        # Multiplier based on whether the EXP Charm is in the bag
        # @param receiver [PFM::PokemonBattler] the Pokemon receiving experience
        # @return [Float] the EXP Charm multiplier
        def experience_charm_multiplier(receiver)
          return 1.0 unless experience_charm_bonus?
          return 1.0 unless $bag.contain_item?(:exp_charm)

          return experience_charm_multiplier_value
        end
      end
    end
  end
end
