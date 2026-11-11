# Générateur de personnages : commandes d'évent (Script)
#
#   personnaliser_joueur            -> le joueur crée son personnage (il doit valider)
#   personnaliser_joueur(true)      -> idem, B annule
#   joueur_personnalise?            -> le joueur a déjà créé son personnage
#   personnage_joueur_au_hasard     -> personnage au hasard, sans écran
class Interpreter
  # @param cancellable [Boolean]
  # @return [Boolean] le personnage a été validé
  def personnaliser_joueur(cancellable = false)
    unless Generateur.available?
      text = 'Générateur : pièces absentes. Dans Studio : Générateurs > Personnages > Dossiers des pièces > Préparer pour le jeu'
      log_error(text) if respond_to?(:log_error, true)
      message(text) if PSDK_CONFIG.debug? && respond_to?(:message, true)
      return false
    end
    done = false
    $scene.call_scene(GamePlay::GenerateurPersonnage, cancellable) { |scene| done = scene.done }
    @wait_count = 2
    return done
  end

  # @return [Boolean]
  def joueur_personnalise?
    return !Generateur.spec.nil?
  end

  # @param gender [String, nil] 'm', 'f' ou nil (au hasard)
  def personnage_joueur_au_hasard(gender = nil)
    return false unless Generateur.available?

    Generateur.apply(Generateur.random_spec(gender))
    return true
  end
end
