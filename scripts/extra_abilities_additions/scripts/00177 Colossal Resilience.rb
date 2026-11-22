# Colossal Resilience (colossal_resilience)
# Their gigantic size and tough hide protects this Pokémon from special attacks, halving their damage.
# Dégâts des attaques spéciales divisés par deux.
ExtraAbilitiesAdditions.define(:colossal_resilience) do
  def base_power_multiplier(user, target, move)
    ea_safe('Colossal Resilience', 1) do
      next(target == @target && move.special? ? 0.5 : 1)
    end
  end
end
