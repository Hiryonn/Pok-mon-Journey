# Overwhelming (overwhelming)
# The Pokémon's attacks always land, but PP usage is raised.
# Ses attaques touchent toujours, mais consomment un PP de plus.
ExtraAbilitiesAdditions.define(:overwhelming) do
  def chance_of_hit_multiplier(user, _target, _move)
    return user == @target ? 1000.0 : 1
  end

  def on_post_accuracy_check(_logic, _scene, _targets, launcher, skill)
    ea_safe('Overwhelming') { skill.pp = [skill.pp - 1, 0].max if launcher == @target && skill && !skill.pp.nil? }
  end
end
