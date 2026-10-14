module Battle
  class Move
    module InverseBattleTypeProcessing
      # Get a single type multiplier overwrite from force flying
      # @param target [PFM::PokemonBattler] target of the move
      # @param target_type [Integer] one of the type of the target
      # @param type [Integer] one of the type of the move
      # @return [Float | nil] definitive multiplier
      def single_type_multiplier_overwrite_from_force_flying(target, target_type, type)
        return super unless $game_switches[Yuki::Sw::BT_Inverse]
        return if target.grounded? || type != data_type(:ground).id || db_symbol == :thousand_arrows

        # Flying Effects activated ?
        is_flying_type = false # During Inverse Battle, Ground type moves are not negated by Flying type
        is_flying_item = target.hold_item?(:air_balloon)
        is_flying_ability = target.has_ability?(:levitate) && user&.can_be_lowered_or_canceled? # Special Interaction with Mold Breaker effect
        is_flying_effects = target.effects.has? { |effect| %i[magnet_rise telekinesis].include?(effect.name) }
        return unless is_flying_type || is_flying_item || is_flying_ability || is_flying_effects

        return 0
      end

      # Get a single type multiplier overwrite from force grounded
      # @param target [PFM::PokemonBattler] target of the move
      # @param target_type [Integer] one of the type of the target
      # @param type [Integer] one of the type of the move
      # @return [Float | nil] definitive multiplier
      def single_type_multiplier_overwrite_from_force_grounded(target, target_type, type)
        return $game_switches[Yuki::Sw::BT_Inverse] ? nil : super
      end
    end
  end
end

Battle::Move.prepend(Battle::Move::InverseBattleTypeProcessing)
