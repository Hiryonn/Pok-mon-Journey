# Petrify (petrify)
# With a glare, it petrifies opposing Pokémon upon entering battle, lowering their Speed stats.
# À l'entrée : la Vitesse des adversaires baisse d'un cran.
ExtraAbilitiesAdditions.define(:petrify) do
  def on_switch_event(handler, _who, with)
    ea_safe('Petrify') do
      next if with != @target

      ea_show(handler.scene, @target)
      ea_foes(handler.logic, @target).each { |foe| ea_stat(handler.logic, :spd, -1, foe, @target) }
    end
  end
end
