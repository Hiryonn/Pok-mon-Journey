# Heat Rush (heat_rush)
# Boosts the Pokémon's Speed stat in harsh sunlight.
ExtraAbilitiesAdditions.define(:heat_rush) do
  # Vitesse x2 en plein soleil.
  def spd_modifier
    ea_safe('Heat Rush', 1) { next(ea_sun?(@logic) ? 2 : 1) }
  end
end
