# Scale Burst (scale_burst)
# When this Pokémon reaches low HP, its scales erupt, lowering Defenses while boosting Attack and Speed.
# Une fois, aux PV bas : Défense et Déf. Spé. -1, Attaque et Vitesse +1.
ExtraAbilitiesAdditions.define(:scale_burst) do
  def on_post_damage(handler, _hp, target, _launcher, _skill)
    ea_safe('Scale Burst') do
      next if target != @target || @burst || !ea_low_hp?

      @burst = true
      logic = handler.logic
      ea_show(handler.scene, target)
      ea_stat(logic, :dfe, -1, target, target)
      ea_stat(logic, :dfs, -1, target, target)
      ea_stat(logic, :atk, 1, target, target)
      ea_stat(logic, :spd, 1, target, target)
    end
  end
end
