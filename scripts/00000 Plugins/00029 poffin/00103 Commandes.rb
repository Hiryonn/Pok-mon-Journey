# Poffin : commandes d'évent (Script)
#
#   cuisiner_poffin                     -> choisir des baies du sac et cuisiner (vrai si un poffin a été fait)
#   nourrir_poffin                      -> donner un poffin à un Pokémon de l'équipe (vrai si un poffin a été mangé)
#   nombre_poffins                      -> combien de poffins a le joueur (condition d'évent)
#   donner_poffin([20, 0, 0, 0, 10], 15) -> ajoute un poffin : saveurs (épicé, sec, doux, amer, acide) et douceur
class Interpreter
  # @return [Boolean]
  def cuisiner_poffin
    unless Poffin.berries.any?
      log_error('Poffin : aucune baie avec des données de cuisson (Data/Studio/items)') if respond_to?(:log_error, true)
      return false
    end
    made = false
    $scene.call_scene(GamePlay::PoffinCooking) { |scene| made = !scene.poffin.nil? }
    @wait_count = 2
    return made
  end

  # @return [Boolean]
  def nourrir_poffin
    fed = false
    $scene.call_scene(GamePlay::PoffinBox) { |scene| fed = scene.fed }
    @wait_count = 2
    return fed
  end

  # @return [Integer]
  def nombre_poffins
    return Poffin.inventory.size
  end

  # @param flavors [Array<Integer>] épicé, sec, doux, amer, acide
  # @param smoothness [Integer]
  # @return [Boolean]
  def donner_poffin(flavors = [20, 0, 0, 0, 0], smoothness = 20)
    values = (Array(flavors) + [0] * 5).first(5).map { |v| v.to_i.clamp(0, 255) }
    level = values.max
    tier = level >= Poffin::TIER_3 ? 3 : (level >= Poffin::TIER_2 ? 2 : 1)
    return Poffin.add('kind' => 'normal', 'flavors' => values, 'smoothness' => smoothness.to_i.clamp(1, 255), 'tier' => tier, 'level' => level)
  end
end
