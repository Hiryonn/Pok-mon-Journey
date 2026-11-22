# Spirit Bound (spirit_bound)
# Prevents Ghost-type Pokémon from escaping.
# Empêche les Pokémon Spectre adverses de fuir ou d'être remplacés.
ExtraAbilitiesAdditions.define(:spirit_bound) do
  def on_flee_prevention(handler, target)
    ea_safe('Spirit Bound') { next(trapped?(target) ? ea_prevent(handler) : nil) }
  end

  def on_switch_prevention(handler, pokemon, _skill, _reason)
    ea_safe('Spirit Bound') { next(trapped?(pokemon) ? ea_prevent(handler) : nil) }
  end

  private

  def trapped?(pokemon)
    return !@target.dead? && pokemon.bank != @target.bank && pokemon.type_ghost?
  end
end
