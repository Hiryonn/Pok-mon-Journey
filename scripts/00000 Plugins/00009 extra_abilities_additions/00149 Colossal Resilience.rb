# Colossal Resilience (colossal_resilience)
# Their gigantic size and tough hide protects this Pokémon from special attacks, halving their damage.
ExtraAbilitiesAdditions.define(:colossal_resilience) do
  # Dégâts des attaques spéciales divisés par deux.
  def base_power_multiplier(_user, target, move)
    ea_safe('Colossal Resilience', 1) { next(target == @target && move.special? ? 0.5 : 1) }
  end
end
