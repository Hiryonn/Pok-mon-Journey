# Reel In (reel_in)
# Prevents Water-type Pokémon from escaping. If a Pokémon with this ability is first in your party, fishing odds are doubled.
# Empêche les Pokémon Eau adverses de fuir ou d'être remplacés. (Les chances de pêche x2 hors combat ne sont pas codées.)
ExtraAbilitiesAdditions.define(:reel_in) do
  def on_flee_prevention(handler, target)
    ea_safe('Reel In') { next(trapped?(target) ? ea_prevent(handler) : nil) }
  end

  def on_switch_prevention(handler, pokemon, _skill, _reason)
    ea_safe('Reel In') { next(trapped?(pokemon) ? ea_prevent(handler) : nil) }
  end

  private

  def trapped?(pokemon)
    return !@target.dead? && pokemon.bank != @target.bank && pokemon.type_water?
  end
end
