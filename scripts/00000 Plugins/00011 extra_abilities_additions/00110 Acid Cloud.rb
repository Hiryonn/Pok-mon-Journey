# Acid Cloud (acid_cloud)
# Summons Acid Rain that damages all Pokémon except the Poison-type.
# À l'entrée : fait tomber la Pluie Acide (météo ajoutée par ce plugin, 5 tours).
ExtraAbilitiesAdditions.define(:acid_cloud) do
  def on_switch_event(handler, _who, with)
    ea_safe('Acid Cloud') do
      next if with != @target

      ea_show(handler.scene, @target)
      handler.logic.weather_change_handler.weather_change_with_process(:acid_rain, 5)
    end
  end
end
