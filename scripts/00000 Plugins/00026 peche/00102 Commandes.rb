# encoding: utf-8
# Pêche : commandes d'évènement (voir 00100 Configuration.rb)
#   peche_minijeu(:normal)   joue le mini-jeu ; true si le poisson est ferré (la pêche continue comme dans PSDK)
#   peche_message_fait?      le mini-jeu a déjà expliqué l'échec (l'évènement n'ajoute pas « rien n'a mordu »)
#   peche_stats              { 'caught', 'lost', 'perfect', 'best' }
class Interpreter
  def peche_minijeu(type = :normal)
    Peche.message_done = false
    return $wild_battle.check_fishing_chances(type) unless Peche.enabled?
    # Rien à pêcher ici : l'évènement affiche lui-même son message
    return true unless $wild_battle.any_fish?(type)

    result = :cancel
    $scene.call_scene(GamePlay::PecheScene, type) { |scene| result = scene.result }
    @wait_count = 2
    return result == :caught
  end

  def peche_message_fait?
    return Peche.message_done?
  end

  def peche_stats
    return Peche.data
  end
end
