# Power Lifter (power_lifter)
# The Pokémon's attacks deal more damage to heavier targets.
ExtraAbilitiesAdditions.define(:power_lifter) do
  # Plus la cible est lourde, plus les dégâts augmentent : +1 % par 10 kg, jusqu'à x1,5.
  def base_power_multiplier(user, target, _move)
    ea_safe('Power Lifter', 1) { next(user == @target ? 1 + [target.weight / 1000.0, 0.5].min : 1) }
  end
end
