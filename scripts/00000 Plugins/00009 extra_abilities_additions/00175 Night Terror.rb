# Night Terror (night_terror)
# Opposing Pokémon that awaken from sleep are paralyzed.
# Les adversaires qui se réveillent sont paralysés.
ExtraAbilitiesAdditions.define(:night_terror) do
  def on_post_action_event(logic, scene, battlers)
    watch(logic, scene, battlers)
  end

  def on_end_turn_event(logic, scene, battlers)
    watch(logic, scene, battlers)
  end

  private

  def watch(logic, scene, battlers)
    ea_safe('Night Terror') do
      @asleep ||= {}
      battlers.each do |pokemon|
        next if pokemon.bank == @target.bank

        was = @asleep[pokemon.object_id]
        @asleep[pokemon.object_id] = pokemon.asleep?
        next unless was && !pokemon.asleep? && !pokemon.dead?

        ea_show(scene, @target)
        logic.status_change_handler.status_change_with_process(:paralysis, pokemon, @target)
      end
    end
  end
end
