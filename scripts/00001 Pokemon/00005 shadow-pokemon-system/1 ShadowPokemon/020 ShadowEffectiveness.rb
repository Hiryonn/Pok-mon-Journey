module PFM
  # Effectiveness of a Shadow move, which ignores the type chart entirely.
  module ShadowEffectiveness
    # Multiplier a Shadow move gets on a target that is not Shadow.
    # @return [Float]
    SUPER_EFFECTIVE = 2.0
    # Multiplier a Shadow move gets on a Shadow target.
    # @return [Float]
    NOT_VERY_EFFECTIVE = 0.5

    module_function

    # Multiplier a Shadow move gets on that target.
    # @param target_is_shadow [Boolean]
    # @return [Float]
    def against(target_is_shadow)
      return target_is_shadow ? NOT_VERY_EFFECTIVE : SUPER_EFFECTIVE
    end
  end
end
