module PFM
  module ItemDescriptor
    class Wrapper
      # A Shadow Pokemon that lost control refuses every item but a scent, which is the one thing
      # that can still reach it.
      module WrapperShadowPatch
        # Return the symbol describing why this creature can't receive the item in battle, or nil
        # @param creature [PFM::Pokemon]
        # @return [Symbol, nil]
        def battle_rejection_reason(creature)
          return :shadow_instability if creature.unstable? && !scent?

          return super
        end

        # Build the user-facing message when on_creature_choice returns false for this creature
        # @param creature [PFM::Pokemon]
        # @return [String]
        def rejection_message(creature)
          return ShadowTexts.message(:instability_refusal) if battle_rejection_reason(creature) == :shadow_instability

          return super
        end

        private

        # Whether the item this wrapper carries is one of the scents of the plugin.
        # @return [Boolean]
        def scent?
          return ShadowScents::MULTIPLIERS.key?(@item.db_symbol)
        end
      end

      prepend WrapperShadowPatch
    end
  end
end
