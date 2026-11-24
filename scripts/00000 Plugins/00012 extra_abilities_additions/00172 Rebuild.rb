# Rebuild (rebuild)
# If it hasn't taken damage in a turn, it will restore a little HP.
# Fin de tour : rend 1/8 des PV max si aucun dégât n'a été subi pendant le tour.
ExtraAbilitiesAdditions.define(:rebuild) do
  def on_post_damage(_handler, hp, target, _launcher, _skill)
    @hurt = true if target == @target && hp.to_i > 0
  end

  def on_post_damage_death(_handler, _hp, target, _launcher, _skill)
    @hurt = true if target == @target
  end

  def on_end_turn_event(logic, _scene, battlers)
    ea_safe('Rebuild') do
      hurt = @hurt
      @hurt = false
      next if hurt || !battlers.include?(@target) || @target.dead? || @target.hp >= @target.max_hp

      ea_heal(logic, @target, @target.max_hp / 8.0)
    end
  end
end
