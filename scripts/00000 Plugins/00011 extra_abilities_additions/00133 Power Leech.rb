# Power Leech (power_leech)
# Powers up draining moves.
ExtraAbilitiesAdditions.define(:power_leech) do
  # Capacités de drain : x1,3.
  def base_power_multiplier(user, _target, move)
    ea_safe('Power Leech', 1) { next(user == @target && move.respond_to?(:drain_factor) ? 1.3 : 1) }
  end
end
