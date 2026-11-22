# encoding: utf-8
# Base secrète : commandes d'évènement
#   base_secrete                 ouvre la pièce pour la décorer
#   base_secrete_objets          nombre de décorations posées
#   base_secrete_trophees        nombre de trophées qu'on peut poser (succès obtenus + concours gagnés)
#   base_secrete_theme(:grotte)  change le fond de la pièce
#   base_secrete_vider           range toutes les décorations (les objets reviennent dans le sac)
class Interpreter
  def base_secrete
    $scene.call_scene(GamePlay::BaseSecreteScene)
  end

  def base_secrete_objets
    return BaseSecrete.placed.size
  end

  def base_secrete_trophees
    return BaseSecrete.trophies.size
  end

  def base_secrete_theme(id)
    return BaseSecrete.set_theme(id)
  end

  def base_secrete_vider
    BaseSecrete.clear
  end
end
