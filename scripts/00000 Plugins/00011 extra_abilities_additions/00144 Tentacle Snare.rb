# Tentacle Snare (tentacle_snare)
# This Pokémon's contact moves lower the opponent's Speed by one stage.
ExtraAbilitiesAdditions.define(:tentacle_snare) do
  # Ses capacités de contact baissent la Vitesse de la cible d'un cran.
  def on_post_damage_event(handler, _hp, target, launcher, skill)
    ea_safe('Tentacle Snare') do
      next if launcher != @target || launcher == target || !skill.direct? || target.dead?

      ea_stat(handler.logic, :spd, -1, target, launcher)
    end
  end
end
