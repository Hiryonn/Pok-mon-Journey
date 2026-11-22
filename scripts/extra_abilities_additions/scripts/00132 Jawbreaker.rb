# Jawbreaker (jawbreaker)
# Harshly lowers the Attack stat of the attacker when hit by a biting move.
# Touché par une capacité de morsure : l'Attaque de l'attaquant baisse de 2 crans.
ExtraAbilitiesAdditions.define(:jawbreaker) do
  def on_post_damage(handler, _hp, target, launcher, skill)
    ea_safe('Jawbreaker') do
      next if target != @target || launcher.nil? || launcher == target || !skill.bite?

      ea_stat(handler.logic, :atk, -2, launcher, target)
    end
  end
end
