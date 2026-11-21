# Lance-Ball : commandes d'évènement (commande Script)
#   lance_ball                 lance le mini-jeu (renvoie les points, nil si le joueur quitte avant de jouer)
#   lance_ball(3)              nombre de Pokémon à capturer (1 à 6)
#   lance_ball_points          points de la dernière partie
#   lance_ball_record          meilleur score
#   lance_ball_parties         nombre de parties jouées
#   lance_ball_captures        total des Pokémon capturés
class Interpreter
  def lance_ball(nombre = nil)
    result = nil
    $scene.call_scene(GamePlay::LanceBallScene, nombre) { |scene| result = scene.result }
    @wait_count = 2
    return result
  end
  alias ball_launch lance_ball

  def lance_ball_points
    return LanceBall.data['last']
  end

  def lance_ball_record
    return LanceBall.data['record']
  end

  def lance_ball_parties
    return LanceBall.data['played']
  end

  def lance_ball_captures
    return LanceBall.data['caught']
  end
end
