module Studio
  # Data class describing a creature form
  class CreatureForm < Creature
    module Randomizer
      # Returns the base stat total of this form
      # @return [Integer]
      attr_reader :bst

      # Get the creature form's base stat total
      # @return [Integer]
      def bst
        return @bst if @bst

        @bst = @base_hp + @base_atk + @base_dfe + @base_ats + @base_dfs + @base_spd

        return @bst
      end
    end
  end

  Studio::CreatureForm.prepend(Studio::CreatureForm::Randomizer)
end
