# Razor Fins (razor_fins)
# Powers up moves that make direct contact.
# Capacités de contact : x1,3.
ExtraAbilitiesAdditions.define(:razor_fins) do
  def base_power_multiplier(user, target, move)
    ea_safe('Razor Fins', 1) do
      next(user == @target && move.direct? ? 1.3 : 1)
    end
  end
end
