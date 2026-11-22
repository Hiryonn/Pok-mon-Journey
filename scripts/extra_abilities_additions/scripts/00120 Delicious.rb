# Delicious (delicious)
# Infatuates the attacker when hit by a biting move.
# Touché par une capacité de morsure : l'attaquant tombe amoureux (Attraction).
ExtraAbilitiesAdditions.define(:delicious) do
  def on_post_damage(handler, _hp, target, launcher, skill)
    ea_safe('Delicious') do
      next if target != @target || launcher.nil? || launcher == target || !skill.bite? || launcher.effects.has?(:attract)

      launcher.effects.add(Battle::Effects::Attract.new(handler.logic, launcher, target))
      ea_show(handler.scene, target)
      handler.scene.display_message_and_wait(ExtraAbilitiesAdditions.text("#{launcher.given_name} tombe amoureux !", "#{launcher.given_name} fell in love!"))
    end
  end
end
