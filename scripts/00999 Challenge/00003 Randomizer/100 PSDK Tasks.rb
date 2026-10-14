module Scheduler
  add_proc(:on_scene_switch, GamePlay::Load, 'Randomizer: add randomizer_properties', 1000) do
    next unless $scene.is_a?(Scene_Map)

    log_info('Randomizer: adding randomizer_properties to all pokemon')
    block = proc { |pokemon| pokemon&.randomizer_properties ||= {} }
    add_randomizer_properties = proc do |pokemon|
      next unless pokemon
      next if pokemon.instance_variable_defined?(:@randomizer_properties)

      pokemon.instance_variable_set(:@randomizer_properties, {})
    end

    PFM.game_state.randomizer.affect_all_pokemon(&add_randomizer_properties)
  end

  add_proc(:on_scene_switch, GamePlay::Load, 'Randomizer: Remove move_pool ivar', 1000) do
    next unless $scene.is_a?(Scene_Map)

    log_info('Randomizer: removing move_pool ivar from all pokemon')
    cleanup_move_pool = proc do |pokemon|
      next unless pokemon
      next unless pokemon.instance_variable_defined?(:@move_pool)

      pokemon.remove_instance_variable(:@move_pool)
    end

    PFM.game_state.randomizer.affect_all_pokemon(&cleanup_move_pool)
  end

  add_proc(:on_scene_switch, GamePlay::Load, 'Randomizer: Remove duplicates moves in randomizer_properties', 1000) do
    next unless $scene.is_a?(Scene_Map)

    log_info('Randomizer: removing duplicate moves from randomizer_properties')
    remove_duplicate_moves = proc do |pokemon|
      next unless pokemon
      next unless pokemon.instance_variable_defined?(:@randomizer_properties)

      pokemon.randomizer_properties[:moves]&.uniq!
    end

    PFM.game_state.randomizer.affect_all_pokemon(&remove_duplicate_moves)
  end

  add_proc(:on_scene_switch, GamePlay::Load, 'Randomizer: Remove leftover correspondance_hash ivar', 1000) do
    next unless $scene.is_a?(Scene_Map)

    log_info('Randomizer: Removing leftover correspondance_hash ivar')
    [
      $randomizer.wild_pokemon,
      $randomizer.given_pokemon,
      $randomizer.trainers_pokemon,
      $randomizer.evolutions,
      $randomizer.abilities
    ].each do |randomizer|
      randomizer.remove_instance_variable(:@correspondance_hash) if randomizer.instance_variable_defined?(:@correspondance_hash)
    end
  end

  add_proc(:on_scene_switch, GamePlay::Load, 'Randomizer: add new randomizer ivar', 1000) do
    next unless $scene.is_a?(Scene_Map)

    log_info('Randomizer: adding new randomizer ivar')
    $randomizer.balance ||= -1
    $randomizer.trainers_pokemon.mega_persistence ||= true
  end
end
