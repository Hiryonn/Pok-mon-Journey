# Pots à baies : objet du sac et commandes d'évènement (Script)
#
#   pots_a_baies          -> ouvre les pots (comme l'objet « Pots à Baies »)
#   ajouter_pots          -> donne un pot de plus (ajouter_pots(2) : deux) ; false si le joueur a déjà le maximum
#   nombre_pots           -> nombre de pots du joueur
#   pots_prets            -> nombre de pots dont les baies sont mûres (condition : pots_prets > 0)
class Interpreter
  def pots_a_baies
    $scene.call_scene(GamePlay::PotsBaies)
    @wait_count = 2
    return true
  end
  alias ouvrir_pots_a_baies pots_a_baies

  def ajouter_pots(amount = 1)
    return ::PotsBaies.add_pots(amount)
  end

  def nombre_pots
    return ::PotsBaies.count
  end

  def pots_prets
    return ::PotsBaies.ripe_count
  end
end

# Objet « Pots à Baies » (berry_pots) : ouvre les pots depuis le sac (l'objet n'est pas consommé)
PFM::ItemDescriptor.define_bag_use(:berry_pots, true) do |_item, scene|
  scene.call_scene(GamePlay::PotsBaies)
  next :unused
end
