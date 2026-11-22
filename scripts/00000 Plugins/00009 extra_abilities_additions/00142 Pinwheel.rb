# Pinwheel (pinwheel)
# Being hit by a Flying-type move boosts the Speed stat of the Pokémon.
# Touché par une capacité Vol : Vitesse +1.
ExtraAbilitiesAdditions.define(:pinwheel) do
  def on_post_damage(handler, _hp, target, launcher, skill)
    ea_safe('Pinwheel') do
      next if target != @target || launcher == target || !ea_type?(skill, :flying)

      ea_stat(handler.logic, :spd, 1, target, target)
    end
  end
end
