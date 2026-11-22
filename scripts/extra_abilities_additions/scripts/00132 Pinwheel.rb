# Pinwheel (pinwheel)
# Being hit by a Flying-type move boosts the Speed stat of the Pokémon.
ExtraAbilitiesAdditions.define(:pinwheel) do
  # Touché par une capacité Vol : Vitesse +1.
  def on_post_damage_event(handler, _hp, target, launcher, skill)
    ea_safe('Pinwheel') do
      next if target != @target || launcher == target || !ea_type?(skill, :flying)

      ea_stat(handler.logic, :spd, 1, target, target)
    end
  end
end
