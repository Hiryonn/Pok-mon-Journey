# Trample (trample)
# This Pokémon's trampling feet destroy any traps and terrain effects on the field when entering a battle.
# À l'entrée : détruit les pièges, les écrans et le terrain actif.
ExtraAbilitiesAdditions.define(:trample) do
  def on_switch_event(handler, _who, with)
    ea_safe('Trample') do
      next if with != @target

      ea_show(handler.scene, @target)
      logic = handler.logic
      ExtraAbilitiesAdditions.clear_effects(logic, ExtraAbilitiesAdditions::HAZARDS + ExtraAbilitiesAdditions::SCREENS)
      logic.fterrain_change_handler.fterrain_change_with_process(:none) unless logic.field_terrain == :none
    end
  end
end
