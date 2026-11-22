# Steam Power (steam_power)
# The power of the Pokémon's Water-type moves are boosted in sunshine, instead of being weakened.
ExtraAbilitiesAdditions.define(:steam_power) do
  # Eau en plein soleil : PSDK applique déjà x0,5 ; x3 annule cette baisse et donne x1,5.
  def base_power_multiplier(user, _target, move)
    ea_safe('Steam Power', 1) { next(user == @target && ea_type?(move, :water) && ea_sun?(@logic) ? 3 : 1) }
  end
end
