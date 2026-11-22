# Cueillette Dodrio : commandes d'évènement (commande Script)
#   cueillette_dodrio            lance le mini-jeu (renvoie les points, nil si le joueur quitte avant de jouer)
#   cueillette_dodrio(1)         nombre de Dodrio sur le terrain (1 : seul, 2 ou 3 : avec l'ordinateur)
#   cueillette_dodrio_points     points de la dernière partie
#   cueillette_dodrio_record     meilleur score
#   cueillette_dodrio_parties    nombre de parties jouées
#   dodrio_dans_equipe?          condition : un Dodrio est dans l'équipe
class Interpreter
  def cueillette_dodrio(joueurs = nil)
    unless Dodrio.has_dodrio?
      message(Dodrio.t('Il faut un Dodrio dans ton équipe pour jouer.', 'You need a Dodrio in your party to play.'))
      return nil
    end
    result = nil
    $scene.call_scene(GamePlay::DodrioBerryPicking, joueurs) { |scene| result = scene.result }
    @wait_count = 2
    return result
  end
  alias dodrio_berry_picking cueillette_dodrio

  def cueillette_dodrio_points
    return Dodrio.data['last']
  end

  def cueillette_dodrio_record
    return Dodrio.data['record']
  end

  def cueillette_dodrio_parties
    return Dodrio.data['played']
  end

  def dodrio_dans_equipe?
    return $actors.any? { |pk| !pk.egg? && pk.db_symbol == Dodrio.species }
  end
end
