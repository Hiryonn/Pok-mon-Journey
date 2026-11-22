# Steam Power (steam_power)
# The power of the Pokémon's Water-type moves are boosted in sunshine, instead of being weakened.
# Eau en plein soleil : le moteur applique déjà x0,5 ; x3 annule cette baisse et donne x1,5.
ExtraAbilitiesAdditions.define(:steam_power) do
  def base_power_multiplier(user, target, move)
    ea_safe('Steam Power', 1) do
      next(user == @target && ea_type?(move, :water) && ea_sun? ? 3 : 1)
    end
  end
end
