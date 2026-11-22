# Elementalist (elementalist)
# Powers up Fire-, Electric-, and Water-type moves.
# Feu, Électrik et Eau : x1,3.
ExtraAbilitiesAdditions.define(:elementalist) do
  def base_power_multiplier(user, target, move)
    ea_safe('Elementalist', 1) do
      next(user == @target && %i[fire electric water].any? { |t| ea_type?(move, t) } ? 1.3 : 1)
    end
  end
end
