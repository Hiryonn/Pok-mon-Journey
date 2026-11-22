# Bloodlust (bloodlust)
# The Pokémon restores a little HP every time it inflicts damage on others.
# Rend 1/16 des PV max à chaque dégât infligé.
ExtraAbilitiesAdditions.define(:bloodlust) do
  def on_post_damage(handler, hp, target, launcher, _skill)
    drain_blood(handler, hp, target, launcher)
  end

  def on_post_damage_death(handler, hp, target, launcher, _skill)
    drain_blood(handler, hp, target, launcher)
  end

  private

  def drain_blood(handler, hp, target, launcher)
    ea_safe('Bloodlust') do
      next if launcher != @target || target == launcher || hp.to_i <= 0 || launcher.dead?

      ea_heal(handler.logic, launcher, launcher.max_hp / 16.0)
    end
  end
end
