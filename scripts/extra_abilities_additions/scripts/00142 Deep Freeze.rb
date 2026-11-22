# Deep Freeze (deep_freeze)
# Contact with the Pokémon may freeze the attacker.
ExtraAbilitiesAdditions.define(:deep_freeze) do
  # Contact : 30 % de chances de geler l'attaquant.
  def on_post_damage_event(handler, _hp, target, launcher, skill)
    ea_safe('Deep Freeze') do
      next if target != @target || launcher == target || !skill.direct? || rand >= 0.3

      handler.logic.status_change_handler.status_change_with_process(:freeze, launcher, target, skill)
    end
  end
end
