# Power Leech (power_leech)
# Powers up draining moves.
# Capacités de drain : x1,3.
ExtraAbilitiesAdditions.define(:power_leech) do
  def base_power_multiplier(user, target, move)
    ea_safe('Power Leech', 1) do
      next(user == @target && move.drain? ? 1.3 : 1)
    end
  end
end
