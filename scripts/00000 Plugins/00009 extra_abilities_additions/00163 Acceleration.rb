# Acceleration (acceleration)
# Powers up priority moves.
# Capacités prioritaires : x1,3.
ExtraAbilitiesAdditions.define(:acceleration) do
  def base_power_multiplier(user, target, move)
    ea_safe('Acceleration', 1) do
      next(user == @target && move.priority(user) > 0 ? 1.3 : 1)
    end
  end
end
