# Succès : commandes d'évènement (Script) et appli du téléphone
#
#   succes                          -> ouvre la liste des succès (alias ouvrir_succes)
#   succes_debloquer(:id)           -> débloque un succès (récompense + bandeau)
#   succes_obtenu?(:id)             -> true si le succès est obtenu (conditions)
#   succes_compteur(:nom, 1)        -> ajoute 1 au compteur « nom » (conditions « compteur »)
#   succes_compteur_fixer(:nom, 5)  -> met le compteur à 5
#   succes_valeur_compteur(:nom)    -> valeur du compteur
#   succes_nombre                   -> nombre de succès obtenus
#   succes_points                   -> total des points
#   succes_verifier                 -> vérifie tout de suite les conditions automatiques
#   succes_retirer(:id)             -> retire un succès (tests)
class Interpreter
  def succes(category = nil)
    $scene.call_scene(GamePlay::Succes, category)
    @wait_count = 2
    return true
  end
  alias ouvrir_succes succes

  def succes_debloquer(id)
    return Succes.unlock(id)
  end

  def succes_obtenu?(id)
    return Succes.unlocked?(id)
  end

  def succes_compteur(name, amount = 1)
    return Succes.add_counter(name, amount)
  end

  def succes_compteur_fixer(name, value)
    return Succes.set_counter(name, value)
  end

  def succes_valeur_compteur(name)
    return Succes.counter(name)
  end

  def succes_nombre
    return Succes.unlocked_count
  end

  def succes_points
    return Succes.total_points
  end

  def succes_verifier
    Succes.check_all
    return true
  end

  def succes_retirer(id)
    Succes.relock(id)
    return true
  end
end

# Appli « Succès » du téléphone (PokeSmart : icône icon_trophy) ; dans le menu de PSDK, un bouton de plus
module GamePlay
  class Menu
    def open_achievements
      call_scene(GamePlay::Succes)
    end

    register_button(:open_achievements) { !::Succes.all.empty? } unless ACTION_LIST.include?(:open_achievements)
  end
end
