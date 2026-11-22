# Heat Rush (heat_rush)
# Boosts the Pokémon's Speed stat in harsh sunlight.
# Vitesse x2 en plein soleil.
ExtraAbilitiesAdditions.define(:heat_rush) do
  def spd_modifier
    ea_safe('Heat Rush', 1) { next(ea_sun? ? 2 : 1) }
  end
end
