module PFM
  class Pokemon
    # What a locked heart refuses to let the player do with the moves of a Shadow Pokemon. The plugin rebuilds
    # its moveset from the Shadow moves and the opened bars, so any other edit would be undone anyway.
    module PokemonShadowSkillsPatch
      # Check if the Pokemon can learn a skill
      # @param db_symbol [Integer, Symbol] id or db_symbol of the move
      # @return [Boolean, nil] nil = learnt, false = cannot learn, true = can learn
      def can_learn?(db_symbol)
        # A Technical Machine asks this before offering itself, so it is never spent on a creature that
        # cannot take it
        return false if shadow?

        return super
      end

      # Swap the position of two skills in the skills_set
      # @param index1 [Integer] Index of the first skill to swap
      # @param index2 [Integer] Index of the second skill to swap
      def swap_skills_index(index1, index2)
        return if shadow?

        return super
      end

      # Forget a skill by its id
      # @param db_symbol [Symbol] db_symbol of the move in the database
      # @param delete_from_learnt [Boolean] if the skill should be deleted from the skill_learnt attribute of the Pokemon
      def forget_skill(db_symbol, delete_from_learnt: false)
        return if shadow?

        return super
      end
    end

    prepend PokemonShadowSkillsPatch
  end
end
