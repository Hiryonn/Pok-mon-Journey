# Infuriate (infuriate)
# Contact with the Pokémon makes it so angry that it boosts the Attack stat.
# Touché par une capacité de contact : Attaque +1.
ExtraAbilitiesAdditions.define(:infuriate) do
  def on_post_damage(handler, _hp, target, launcher, skill)
    ea_safe('Infuriate') do
      next if target != @target || launcher.nil? || launcher == target || !skill.direct?

      ea_stat(handler.logic, :atk, 1, target, target)
    end
  end
end
