# Relentless (relentless)
# When the Pokémon knocks out a target, it strengthens its pursuit, boosting its Speed stat.
ExtraAbilitiesAdditions.define(:relentless) do
  # Après un K.O. : Vitesse +1.
  def on_post_damage_event(handler, _hp, target, launcher, _skill)
    ea_safe('Relentless') do
      next if launcher != @target || target == launcher || !target.dead?

      ea_stat(handler.logic, :spd, 1, launcher, launcher)
    end
  end
end
