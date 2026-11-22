# Droning Noise (droning_noise)
# Torments all other Pokémon on the field, making them have to go for a different move each turn.
# À l'entrée : tous les autres Pokémon au combat subissent Tourmente.
ExtraAbilitiesAdditions.define(:droning_noise) do
  def on_switch_event(handler, _who, with)
    ea_safe('Droning Noise') do
      next if with != @target

      ea_show(handler.scene, @target)
      handler.logic.all_alive_battlers.each do |pokemon|
        next if pokemon == @target || pokemon.effects.has?(:torment)

        pokemon.effects.add(Battle::Effects::Torment.new(handler.logic, pokemon))
      end
    end
  end
end
