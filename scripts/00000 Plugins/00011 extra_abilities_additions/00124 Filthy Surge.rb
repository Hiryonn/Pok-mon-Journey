# Filthy Surge (filthy_surge)
# Turns the ground into Filthy Terrain when the Pokémon enters a battle.
# À l'entrée : le sol devient Terrain Sale (terrain ajouté par ce plugin, 5 tours).
ExtraAbilitiesAdditions.define(:filthy_surge) do
  def on_switch_event(handler, _who, with)
    ea_safe('Filthy Surge') do
      next if with != @target

      ea_show(handler.scene, @target)
      ExtraAbilitiesAdditions::FilthyTerrain.start(handler.logic, handler.scene)
    end
  end
end
