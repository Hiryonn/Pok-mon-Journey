# Inner Self (inner_self)
# Inner Self resets all stat changes and statuses, on both sides of the field, upon entering the field.
ExtraAbilitiesAdditions.define(:inner_self) do
  # À l'entrée : remet à zéro les changements de stats et guérit les statuts de tous les Pokémon au combat.
  def on_switch_event(handler, _who, with)
    ea_safe('Inner Self') do
      next if with != @target

      handler.logic.all_alive_battlers.each do |pokemon|
        pokemon.reset_stat_stages if pokemon.respond_to?(:reset_stat_stages)
        pokemon.cure if pokemon.respond_to?(:cure)
      end
    end
  end
end
