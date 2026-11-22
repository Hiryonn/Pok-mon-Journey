# Overworld Pokémon : commandes d'évènement (Script)
#
#   pokemon_visibles(false)     -> coupe les Pokémon visibles (à partir de la prochaine carte) ; pokemon_visibles(true) les remet
#   effacer_pokemon_visibles    -> retire tous les Pokémon visibles de la carte en cours
#   nombre_pokemon_visibles     -> nombre de Pokémon visibles sur la carte
#   (suite : apparition_massive, combat_baron, combat_dominant en bas du fichier)
class Interpreter
  def pokemon_visibles(value = true)
    OverworldPokemon.forced_off = !value
    return value
  end

  def effacer_pokemon_visibles
    $game_map.events.each_value { |event| event.erase if event.is_a?(Game_OverworldPokemon) || event.is_a?(Game_OverworldIcon) }
    return true
  end

  def nombre_pokemon_visibles
    return $game_map.events.values.count { |event| event.is_a?(Game_OverworldPokemon) && !event.erased }
  end
end

# Apparitions massives, Barons et Dominants
#
#   apparition_massive(:pikachu)        -> rassemble un groupe de cette espèce autour d'une tuile libre de la carte
#   apparition_massive(:pikachu, 12)       (nombre en 2e argument ; sans espèce : tirée dans les groupes de la zone)
#   combat_baron(:pikachu, 30)          -> combat sauvage immédiat contre un Pokémon Baron de niveau 30 (+ bonus)
#   combat_monarque(:pikachu, 30)       -> idem contre un Pokémon Monarque
#   combat_dominant(:raichu, 30)        -> idem contre un Pokémon Dominant
class Interpreter
  def combat_baron(species, level)
    OverworldPokemon.rank_battle(self, :baron, species, level)
  end

  def combat_monarque(species, level)
    OverworldPokemon.rank_battle(self, :monarch, species, level)
  end

  def combat_dominant(species, level)
    OverworldPokemon.rank_battle(self, :dominant, species, level)
  end

  def apparition_massive(species = nil, count = nil)
    OverworldPokemon.force_outbreak($game_map, species, count)
  end
end
