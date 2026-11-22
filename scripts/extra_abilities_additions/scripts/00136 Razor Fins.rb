# Razor Fins (razor_fins)
# Powers up moves that make direct contact.
ExtraAbilitiesAdditions.define(:razor_fins) do
  # Capacités de contact : x1,3.
  def base_power_multiplier(user, _target, move)
    ea_safe('Razor Fins', 1) { next(user == @target && move.direct? ? 1.3 : 1) }
  end
end
