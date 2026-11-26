# Générateur de personnages : commandes d'évent (Script)
#
#   personnaliser_joueur            -> le joueur crée son personnage (il doit valider)
#   personnaliser_joueur(true)      -> idem, B annule
#   personnaliser_joueur(false, 'f') -> genre imposé ('m' garçon, 'f' fille) : le joueur ne peut pas le changer
#   personnaliser_joueur(false, :choisir) -> demande d'abord « garçon ou fille ? », puis ouvre l'écran avec ce genre
#   choisir_genre_joueur            -> demande « garçon ou fille ? » ; renvoie 'm' ou 'f'
#   choisir_genre_joueur('Es-tu un garçon ou une fille ?', 'Garçon', 'Fille', 12) -> texte, choix, variable (0 / 1)
#   genre_joueur                    -> 'm' ou 'f' (fille? : genre_joueur == 'f')
#   joueur_personnalise?            -> le joueur a déjà créé son personnage
#   personnage_joueur_au_hasard     -> personnage au hasard, sans écran
class Interpreter
  # @param cancellable [Boolean]
  # @param genre [String, Symbol, nil] 'm' / 'f' : imposé ; :choisir : demandé avant l'écran ; nil : au choix dans l'écran
  # @return [Boolean] le personnage a été validé
  def personnaliser_joueur(cancellable = false, genre = nil)
    unless Generateur.available?
      text = 'Générateur : pièces absentes. Dans Studio : Générateurs > Personnages > Dossiers des pièces > Préparer pour le jeu'
      log_error(text) if respond_to?(:log_error, true)
      message(text) if PSDK_CONFIG.debug? && respond_to?(:message, true)
      return false
    end
    genre = choisir_genre_joueur if genre.to_s == 'choisir'
    genre = nil unless %w[m f].include?(genre.to_s)
    done = false
    $scene.call_scene(GamePlay::GenerateurPersonnage, cancellable, genre&.to_s) { |scene| done = scene.done }
    @wait_count = 2
    return done
  end

  # @return [Boolean]
  def joueur_personnalise?
    return !Generateur.spec.nil?
  end

  # Demande au joueur s'il est un garçon ou une fille (interrupteur du genre de PSDK).
  # Si son personnage existe déjà avec l'autre genre, il en reçoit un nouveau au hasard de ce genre.
  # @param question [String, nil]
  # @param garcon [String, nil] texte du choix Garçon
  # @param fille [String, nil] texte du choix Fille
  # @param variable [Integer] variable qui reçoit 0 (garçon) ou 1 (fille), 0 : aucune
  # @return [String] 'm' ou 'f'
  def choisir_genre_joueur(question = nil, garcon = nil, fille = nil, variable = 0)
    fr = !$options || $options.language == 'fr'
    question = (fr ? 'Es-tu un garçon ou une fille ?' : 'Are you a boy or a girl?') if question.to_s.empty?
    garcon = (fr ? 'Garçon' : 'Boy') if garcon.to_s.empty?
    fille = (fr ? 'Fille' : 'Girl') if fille.to_s.empty?
    index = message(question, 0, garcon, fille).to_i
    gender = index == 1 ? 'f' : 'm'
    $game_switches[Yuki::Sw::Gender] = gender == 'f'
    $game_variables[variable] = index if variable.to_i > 0
    spec = Generateur.spec
    Generateur.apply(Generateur.random_spec(gender)) if spec && spec['gender'] != gender && Generateur.available?
    return gender
  end

  # @return [String] 'm' ou 'f'
  def genre_joueur
    spec = Generateur.spec
    return spec['gender'] if spec

    return $game_switches[Yuki::Sw::Gender] ? 'f' : 'm'
  end

  # @param gender [String, nil] 'm', 'f' ou nil (au hasard)
  def personnage_joueur_au_hasard(gender = nil)
    return false unless Generateur.available?

    Generateur.apply(Generateur.random_spec(gender))
    return true
  end
end
