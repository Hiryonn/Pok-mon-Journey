module Battle
  class Move
    # Is the skill type shadow ?
    # @return [Boolean]
    def type_shadow?
      return type?(data_type(:shadow).id)
    end
  end
end
