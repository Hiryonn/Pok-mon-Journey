# Deep Freeze (deep_freeze)
# Contact with the Pokémon may freeze the attacker.
# Contact : 30 % de chances de geler l'attaquant.
ExtraAbilitiesAdditions.define(:deep_freeze) do
  def on_post_damage(handler, _hp, target, launcher, skill)
    ea_safe('Deep Freeze') do
      next if target != @target || launcher.nil? || launcher == target || !skill.direct? || rand >= 0.3

      handler.logic.status_change_handler.status_change_with_process(:freeze, launcher, target, skill)
    end
  end
end
