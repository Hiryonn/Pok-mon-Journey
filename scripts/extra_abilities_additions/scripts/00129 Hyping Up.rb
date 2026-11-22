# Hyping Up (hyping_up)
# Boosts the Pokémon's most proficient attacking stat every time it knocks out a target.
# Après un K.O. : monte la meilleure stat offensive (Attaque ou Atq. Spé.).
ExtraAbilitiesAdditions.define(:hyping_up) do
  def on_post_damage_death(handler, _hp, target, launcher, _skill)
    ea_safe('Hyping Up') do
      next if launcher != @target || target == launcher

      ea_stat(handler.logic, launcher.atk >= launcher.ats ? :atk : :ats, 1, launcher, launcher)
    end
  end
end
