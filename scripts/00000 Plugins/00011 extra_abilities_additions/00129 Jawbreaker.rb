# Jawbreaker (jawbreaker)
# Harshly lowers the Attack stat of the attacker when hit by a biting move.
ExtraAbilitiesAdditions.define(:jawbreaker) do
  # Touché par une capacité de morsure : l'Attaque de l'attaquant baisse de 2 crans.
  def on_post_damage_event(handler, _hp, target, launcher, skill)
    ea_safe('Jawbreaker') do
      next if target != @target || launcher == target || !skill.respond_to?(:bite?) || !skill.bite?

      ea_stat(handler.logic, :atk, -2, launcher, target)
    end
  end
end
