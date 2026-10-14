module PFM
  class Skill
    # A move of a creature asks the text database itself for its description instead of going through its
    # Studio data, so the labels of the plugin have to be served here too.
    module SkillShadowPatch
      # Return the skill description
      # @return [String]
      def description
        return super unless ShadowNames.move?(db_symbol)

        return ShadowNames.move_label(db_symbol, ShadowNames::MOVE_DESCRIPTION_ROW)
      end

      # Get the skill contest description
      # @return [String]
      def contest_description
        return super unless ShadowNames.move?(db_symbol)

        return ShadowNames.move_label(db_symbol, ShadowNames::MOVE_CONTEST_ROW)
      end
    end

    prepend SkillShadowPatch
  end
end
