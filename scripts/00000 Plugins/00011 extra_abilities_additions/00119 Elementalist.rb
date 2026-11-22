# Elementalist (elementalist)
# Powers up Fire-, Electric-, and Water-type moves.
ExtraAbilitiesAdditions.define(:elementalist) do
  def base_power_multiplier(user, _target, move)
    ea_safe('Elementalist', 1) { next(user == @target && %i[fire electric water].any? { |t| ea_type?(move, t) } ? 1.3 : 1) }
  end
end
