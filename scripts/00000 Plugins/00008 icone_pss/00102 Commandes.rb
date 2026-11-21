# Icône PSS : commandes d'évent (Script)
#
#   creer_icone_pss                 -> le joueur crée son icône de profil (il doit valider)
#   creer_icone_pss(true)           -> idem, B annule
#   icone_pss_creee?                -> condition : le joueur a déjà créé son icône
#   icone_pss_au_hasard             -> icône au hasard, sans écran
#   icone_pss_au_hasard('a')        -> idem dans la série A (ou 'b')
class Interpreter
  # @param cancellable [Boolean]
  # @return [Boolean] l'icône a été validée
  def creer_icone_pss(cancellable = false)
    unless IconePss.available?
      text = 'Icône PSS : pièces absentes. Lance tools/pss-icones/decouper_planches.py (voir LISEZMOI.md du plugin)'
      log_error(text) if respond_to?(:log_error, true)
      message(text) if PSDK_CONFIG.debug? && respond_to?(:message, true)
      return false
    end
    done = false
    $scene.call_scene(GamePlay::IconePssCreation, cancellable) { |scene| done = scene.done }
    @wait_count = 2
    return done
  end

  # @return [Boolean]
  def icone_pss_creee?
    return !IconePss.spec.nil?
  end

  # @param serie [String, nil] 'a', 'b' ou nil (au hasard)
  def icone_pss_au_hasard(serie = nil)
    return false unless IconePss.available?

    IconePss.apply(IconePss.random_spec(serie))
    return true
  end
end
