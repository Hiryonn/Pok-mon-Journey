module PFM
  class Pokemon
    # What a Shadow Pokemon keeps to itself about its own identity. Pokemon XD hides the original Trainer
    # behind question marks and refuses nicknaming until the purification hands the creature over for good.
    module PokemonShadowTextPatch
      # Shown in place of the original Trainer and of the identifier of a creature the player does not really own yet
      HIDDEN_TRAINER = '????'

      # Give a new name to the Pokemon
      # @param nickname [String] the new name of the Pokemon
      def given_name=(nickname)
        super unless shadow?
      end

      # Give a new name to the Pokemon
      # @param nickname [String] the new name of the Pokemon
      def nickname=(nickname)
        # The engine aliases this to given_name= before any prepend, so the alias would walk past the refusal
        self.given_name = nickname
      end

      # Name of the original trainer
      # @return [String]
      def trainer_name
        return HIDDEN_TRAINER if shadow?

        return super
      end

      # Return the normalized text trainer id of the Pokemon
      # @return [String]
      def trainer_id_text
        return HIDDEN_TRAINER if shadow?

        return super
      end
    end

    prepend PokemonShadowTextPatch
  end
end
