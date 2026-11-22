# Sunscreen (sunscreen)
# Prevents the Pokémon from getting a burn. It will also gradually regain HP in sunshine.
# Écran Solaire : hérite de Voile Eau (immunité à la brûlure) ; regagne 1/16 des PV par tour au soleil.
ExtraAbilitiesAdditions.define(:sunscreen, :WaterVeil) do
  def on_end_turn_event(logic, _scene, battlers)
    ea_safe('Sunscreen') do
      next unless battlers.include?(@target) && ea_sun?(logic) && !@target.dead?

      ea_heal(logic, @target, @target.max_hp / 16.0)
    end
  end
end
