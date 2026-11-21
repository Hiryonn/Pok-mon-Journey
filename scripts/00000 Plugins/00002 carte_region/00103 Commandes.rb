# Carte de région : commandes d'évènement (Script) et remplacement de la carte de PSDK
#
#   carte_region                -> ouvre la carte de la région où se trouve le joueur
#   carte_region(1)             -> ouvre la carte du monde n° 1
#   carte_region_vol            -> ouvre la carte en mode Vol (comme Vol depuis l'équipe)
#   carte_murale                -> carte murale : on regarde seulement (pas d'aperçu ni de vol)
#   carte_region_progression    -> pourcentage de lieux visités de la région du joueur (0 à 100)
#
# La carte de PSDK (objet Carte, Vol depuis l'équipe, GamePlay.open_town_map) ouvre cette carte à la place,
# sauf si « Remplacer la carte de PSDK » est décoché dans Studio. Le Pokédex garde sa carte des zones.
class Interpreter
  def carte_region(worldmap_id = nil)
    $scene.call_scene(GamePlay::CarteRegion, :view, worldmap_id)
    @wait_count = 2
    return true
  end

  def carte_region_vol
    $scene.call_scene(GamePlay::CarteRegion, :fly, nil, :map)
    @wait_count = 2
    return true
  end

  def carte_murale(worldmap_id = nil)
    $scene.call_scene(GamePlay::CarteRegion, :view_wall, worldmap_id)
    @wait_count = 2
    return true
  end

  def carte_region_progression(worldmap_id = nil)
    worldmap_id ||= (CarteRegion.player_position || [$env.get_worldmap])[0]
    line = CarteRegion.progress(worldmap_id).first
    return line ? CarteRegion.percent(line[1], line[2]) : 0
  end
end

GamePlay.town_map_class = GamePlay::CarteRegion
