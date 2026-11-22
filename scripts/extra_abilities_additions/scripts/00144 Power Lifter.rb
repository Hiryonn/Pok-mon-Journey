# Power Lifter (power_lifter)
# The Pokémon's attacks deal more damage to heavier targets.
# Plus la cible est lourde, plus les dégâts augmentent : jusqu'à x1,5 (à partir de 200 kg).
ExtraAbilitiesAdditions.define(:power_lifter) do
  def base_power_multiplier(user, target, move)
    ea_safe('Power Lifter', 1) do
      next(user == @target ? 1 + [target.weight / 400.0, 0.5].min : 1)
    end
  end
end
