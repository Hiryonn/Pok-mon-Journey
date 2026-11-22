# Hyping Up (hyping_up)
# Boosts the Pokémon's most proficient attacking stat every time it knocks out a target.
ExtraAbilitiesAdditions.define(:hyping_up) do
  # Après un K.O. : monte la meilleure stat offensive (Attaque ou Atq. Spé.).
  def on_post_damage_event(handler, _hp, target, launcher, _skill)
    ea_safe('Hyping Up') do
      next if launcher != @target || target == launcher || !target.dead?

      ea_stat(handler.logic, launcher.atk >= launcher.ats ? :atk : :ats, 1, launcher, launcher)
    end
  end
end
