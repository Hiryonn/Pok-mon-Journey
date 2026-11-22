# Bloodlust (bloodlust)
# The Pokémon restores a little HP every time it inflicts damage on others.
ExtraAbilitiesAdditions.define(:bloodlust) do
  # Rend 1/16 des PV max à chaque dégât infligé.
  def on_post_damage_event(handler, hp, target, launcher, _skill)
    ea_safe('Bloodlust') do
      next if launcher != @target || target == launcher || hp <= 0 || launcher.dead?

      ea_heal(handler.logic, launcher, launcher.max_hp / 16.0)
    end
  end
end
