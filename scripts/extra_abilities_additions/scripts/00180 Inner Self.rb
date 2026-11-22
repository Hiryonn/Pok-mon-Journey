# Inner Self (inner_self)
# Inner Self resets all stat changes and statuses, on both sides of the field, upon entering the field.
# À l'entrée : remet à zéro les changements de stats et guérit les statuts de tous les Pokémon au combat.
ExtraAbilitiesAdditions.define(:inner_self) do


  def on_switch_event(handler, _who, with)
    ea_safe('Inner Self') do
      next if with != @target

      ea_show(handler.scene, @target)
      handler.logic.all_alive_battlers.each do |pokemon|
        ExtraAbilitiesAdditions::STAGES.each { |stat| pokemon.send("#{stat}_stage=", 0) if pokemon.respond_to?("#{stat}_stage=") }
        handler.logic.status_change_handler.status_change_with_process(:cure, pokemon) if pokemon.status?
      end
    end
  end
end
