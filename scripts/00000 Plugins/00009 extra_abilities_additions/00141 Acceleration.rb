# Acceleration (acceleration)
# Powers up priority moves.
ExtraAbilitiesAdditions.define(:acceleration) do
  # Capacités prioritaires : x1,3.
  def base_power_multiplier(user, _target, move)
    ea_safe('Acceleration', 1) { next(user == @target && move.respond_to?(:priority) && move.priority > 0 ? 1.3 : 1) }
  end
end
