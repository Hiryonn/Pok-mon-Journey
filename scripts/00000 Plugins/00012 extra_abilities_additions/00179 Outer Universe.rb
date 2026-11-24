# Outer Universe (outer_universe)
# Outer Universe resets all weather, barriers such as Light Screen (move), and hazards such as Spikes (move) on both sides of the field, upon entering the field.
# À l'entrée : remet à zéro la météo, les écrans et les pièges des deux camps.
ExtraAbilitiesAdditions.define(:outer_universe) do
  def on_switch_event(handler, _who, with)
    ea_safe('Outer Universe') do
      next if with != @target

      ea_show(handler.scene, @target)
      logic = handler.logic
      ExtraAbilitiesAdditions.clear_effects(logic, ExtraAbilitiesAdditions::HAZARDS + ExtraAbilitiesAdditions::SCREENS)
      logic.weather_change_handler.weather_change_with_process(:none) unless ExtraAbilitiesAdditions.weather(logic) == :none
    end
  end
end
