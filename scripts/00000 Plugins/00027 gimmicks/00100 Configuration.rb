# Gimmicks : Méga-Évolution, capacités Z, Dynamax / Gigamax et Téracristal
#
# Règles (Pokémon Journey) :
#   - chaque mécanique s'utilise une fois par combat et par dresseur ;
#   - un Pokémon qui a utilisé une mécanique n'a plus accès aux autres jusqu'à la fin du combat ;
#   - les quatre peuvent servir dans le même combat, chacune avec un Pokémon différent ;
#   - un Pokémon qui tient une méga-gemme ou un cristal Z peut quand même choisir Téracristal ou Dynamax.
#
# Pendant le choix de l'attaque, Y ouvre la roue des mécaniques possibles pour le Pokémon : toutes apparaissent en
# même temps, on pointe celle qu'on veut avec les flèches (ou la souris) et A la choisit (onglet « ACTION »).
# Images : graphics/interface/gimmicks (tools/build_assets.py à partir des ressources d'Essentials).
module Gimmicks
  # Ordre de défilement avec Y
  KINDS = %i[mega zmove dynamax tera].freeze

  # Objets clés (au moins un dans le sac du dresseur). La Méga-Évolution utilise les objets « méga » de Studio
  # (Méga-Anneau, Gemme Sésame…, case « Permet la méga-évolution »).
  KEY_ITEMS = {
    zmove: %i[z_ring z_power_ring],
    dynamax: %i[dynamax_band],
    tera: %i[tera_orb]
  }.freeze

  # Cinématique façon Pokémon Essentials (zoom sur le Pokémon et son dresseur). false : animation de base de PSDK.
  CINEMATIC = true
  # Les dresseurs adverses s'en servent (ils doivent avoir l'objet clé dans leur sac, réglé dans Studio)
  AI_ENABLED = true
  # Chance qu'un dresseur adverse utilise une mécanique possible à un tour (toujours avec son dernier Pokémon)
  AI_CHANCE = 0.4

  # Dossier des images (graphics/interface)
  DIR = 'gimmicks/'

  # Textes : [français, anglais]
  TEXTS = {
    mega: ['Méga-Évolution', 'Mega Evolution'],
    zmove: ['Capacité Z', 'Z-Move'],
    dynamax: %w[Dynamax Dynamax],
    tera: %w[Téracristal Terastallize],
    hint: ['Y : %s', 'Y: %s'],
    # Noms courts (aide de l'interface de combat)
    mega_short: %w[Méga Mega], zmove_short: ['Cap. Z', 'Z-Move'], dynamax_short: %w[Dynamax Dynamax],
    tera_short: %w[Téra Tera],
    # Roue des mécaniques (Y)
    wheel_short: %w[Action Action], wheel_choose: ['A : choisir', 'A: choose'], wheel_back: ['B : retour', 'B: back'],
    wheel_cancel: ['A : annuler', 'A: cancel']
  }.freeze

  module_function

  # @param key [Symbol]
  # @return [String]
  def text(key)
    return TEXTS[key][$options&.language == 'fr' ? 0 : 1]
  rescue StandardError
    return TEXTS[key].first
  end

  # @param name [String]
  # @return [String] image de graphics/interface
  def file(name)
    return "#{DIR}#{name}"
  end

  # Réglages enregistrés dans la partie (commandes d'évènement)
  # @return [Hash]
  def save_data
    return {} unless $user_data

    return $user_data[:pj_gimmicks] ||= { disabled: [], enabled: [], wild: [] }
  end
end
