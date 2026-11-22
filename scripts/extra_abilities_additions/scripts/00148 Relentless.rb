# Relentless (relentless)
# When the Pokémon knocks out a target, it strengthens its pursuit, boosting its Speed stat.
# Après un K.O. : Vitesse +1.
ExtraAbilitiesAdditions.define(:relentless) do
  def on_post_damage_death(handler, _hp, target, launcher, _skill)
    ea_safe('Relentless') do
      next if launcher != @target || target == launcher

      ea_stat(handler.logic, :spd, 1, launcher, launcher)
    end
  end
end
