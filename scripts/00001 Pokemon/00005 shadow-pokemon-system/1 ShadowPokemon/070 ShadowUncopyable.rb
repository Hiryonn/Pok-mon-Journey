module Battle
  class Move
    # Refusal shared by the moves that take another one for themselves. A Shadow move belongs to the
    # heart it was locked into, so none of them can be copied.
    module ShadowUncopyable
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return true unless targets.first.move_history.last.move.type_shadow?

        show_usage_failure(user)
        return false
      end
    end
  end
end
