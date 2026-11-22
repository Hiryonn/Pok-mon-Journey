# Tentacle Snare (tentacle_snare)
# This Pokémon's contact moves lower the opponent's Speed by one stage.
# Ses capacités de contact baissent la Vitesse de la cible d'un cran.
ExtraAbilitiesAdditions.define(:tentacle_snare) do
  def on_post_damage(handler, _hp, target, launcher, skill)
    ea_safe('Tentacle Snare') do
      next if launcher != @target || launcher == target || skill.nil? || !skill.direct?

      ea_stat(handler.logic, :spd, -1, target, launcher)
    end
  end
end
