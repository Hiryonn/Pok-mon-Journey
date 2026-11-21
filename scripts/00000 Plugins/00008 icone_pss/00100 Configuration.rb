# Icône PSS : la photo de profil du mode en ligne
#
# Indépendant du générateur de personnages : l'icône n'a rien à voir avec le personnage du joueur.
# Les pièces (peau, yeux, cheveux, haut, accessoire, chapeau) sont des images de 40x40 déjà à leur place, empilées :
#   graphics/icones_pss/pieces/<catégorie>/<nom>.png et Data/configs/plugins/icone_pss_pieces.json
#   (écrits par tools/pss-icones/decouper_planches.py)
#
# Réglage d'une icône (spec, sauvegardé avec la partie dans $user_data[:pss_icone]) :
#   { 'serie' => 'a' ou 'b', 'peau' => n, 'yeux' => n, 'haut' => n (couleur), 'coiffure' => n (-1 : aucune),
#     'couleur_cheveux' => n, 'frange' => n (couleur, -1 : aucune), 'accessoire' => n (-1 : aucun), 'chapeau' => n (-1 : aucun) }
# Couches, de l'arrière vers l'avant : cheveux (arrière), haut, peau, yeux, frange, cheveux (avant), accessoire, chapeau.
# Les règles sont les mêmes que dans l'outil Studio (tools/studio-pss/pj-pss-logic.js).
#
# Commandes d'évent (Script) : voir 00102 Commandes.rb
# Pour le mode en ligne : IconePss.to_code(spec) donne un court texte à envoyer ("a.0.2.5.1.3.-1.-1.4"),
# IconePss.from_code(texte) le relit chez l'autre joueur, IconePss.compose_texture(spec) en fait l'image.
module IconePss
  CATALOG_FILE = 'Data/configs/plugins/icone_pss_pieces.json'
  PIECES_DIR = 'graphics/icones_pss/pieces'
  # Clé du réglage dans $user_data (sauvegardé avec la partie)
  USER_KEY = :pss_icone
  # Taille de l'icône
  SIZE = 40
  # Ordre des réglages dans le code texte
  CODE_KEYS = %w[peau yeux haut coiffure couleur_cheveux frange accessoire chapeau].freeze

  module_function

  # @return [Hash] catalogue des pièces (vide si les pièces n'ont pas été préparées)
  def catalog
    return @catalog if @catalog

    @catalog = File.exist?(CATALOG_FILE) ? JSON.parse(File.read(CATALOG_FILE, encoding: 'UTF-8')) : {}
    return @catalog
  rescue StandardError => e
    log_error("Icône PSS : #{CATALOG_FILE} illisible (#{e.message})") if respond_to?(:log_error, true)
    return @catalog = {}
  end

  # @return [Boolean] les pièces sont là
  def available?
    return !(catalog['series'] || []).empty?
  end

  # @param id [String, nil]
  # @return [Hash, nil] série « a » ou « b » (la première si l'id est inconnu)
  def serie_of(id)
    list = catalog['series'] || []
    return list.find { |s| s['id'] == id } || list.first
  end

  # @param serie [Hash]
  # @return [Array<Hash>] tous les accessoires de la série, à plat : { 'file', 'genre', 'label' }
  def accessories(serie)
    out = []
    (serie['accessoires'] || []).each do |group|
      (group['fichiers'] || []).each { |file| out << { 'file' => file, 'genre' => group['genre'], 'label' => group['label'] } }
    end
    return out
  end

  def wrap(value, length)
    return length > 0 ? value % length : 0
  end

  # Ramène chaque choix dans les valeurs possibles de la série
  # @param spec [Hash]
  # @return [Hash]
  def fix_spec(spec)
    s = serie_of(spec['serie'])
    spec['serie'] = s['id']
    spec['peau'] = wrap(spec['peau'].to_i, s['peau'].size)
    spec['yeux'] = wrap(spec['yeux'].to_i, s['yeux'].size)
    spec['haut'] = wrap(spec['haut'].to_i, s['hauts'].size)
    style = spec['coiffure'].to_i
    spec['coiffure'] = style >= 0 && style < s['cheveux'].size ? style : -1
    spec['couleur_cheveux'] = spec['coiffure'] < 0 ? 0 : spec['couleur_cheveux'].to_i.clamp(0, s['cheveux'][spec['coiffure']]['couleurs'].size - 1)
    fringe = spec['frange'].to_i
    spec['frange'] = fringe >= 0 && fringe < s['frange'].size ? fringe : -1
    accessory = spec['accessoire'].to_i
    spec['accessoire'] = accessory >= 0 && accessory < accessories(s).size ? accessory : -1
    hat = spec['chapeau'].to_i
    spec['chapeau'] = hat >= 0 && hat < s['chapeaux'].size ? hat : -1
    return spec
  end

  # Fichiers à superposer, dans l'ordre
  # @param spec [Hash]
  # @return [Array<String>]
  def layers(spec)
    s = serie_of(spec['serie'])
    out = []
    hair = spec['coiffure'] >= 0 ? s['cheveux'][spec['coiffure']]['couleurs'][spec['couleur_cheveux']] : nil
    out << hair['arriere'] if hair
    out << s['hauts'][spec['haut']] << s['peau'][spec['peau']] << s['yeux'][spec['yeux']]
    out << s['frange'][spec['frange']] if spec['frange'] >= 0
    out << hair['avant'] if hair
    out << accessories(s)[spec['accessoire']]['file'] if spec['accessoire'] >= 0
    out << s['chapeaux'][spec['chapeau']] if spec['chapeau'] >= 0
    return out.compact
  end

  # Icône au hasard
  # @param serie_id [String, nil] 'a', 'b' ou nil (au hasard)
  # @param previous [Hash, nil] réglage dont on garde les valeurs verrouillées
  # @param locks [Hash] réglages à garder ('haut' => true…)
  # @return [Hash]
  def random_spec(serie_id = nil, previous = nil, locks = {})
    previous ||= {}
    keep = ->(key) { locks[key] && !previous[key].nil? }
    spec = { 'serie' => serie_id || (keep.call('serie') ? previous['serie'] : (catalog['series'].sample)['id']) }
    s = serie_of(spec['serie'])
    spec['peau'] = keep.call('peau') ? previous['peau'] : rand(s['peau'].size)
    spec['yeux'] = keep.call('yeux') ? previous['yeux'] : rand(s['yeux'].size)
    spec['haut'] = keep.call('haut') ? previous['haut'] : rand(s['hauts'].size)
    spec['coiffure'] = keep.call('coiffure') ? previous['coiffure'] : (rand < 0.05 ? -1 : rand(s['cheveux'].size))
    spec['couleur_cheveux'] = keep.call('couleur_cheveux') ? previous['couleur_cheveux'] : rand(5)
    spec['frange'] = keep.call('frange') ? previous['frange'] : (!s['frange'].empty? && rand < 0.3 ? rand(s['frange'].size) : -1)
    spec['accessoire'] = keep.call('accessoire') ? previous['accessoire'] : (!accessories(s).empty? && rand < 0.35 ? rand(accessories(s).size) : -1)
    spec['chapeau'] = keep.call('chapeau') ? previous['chapeau'] : (!s['chapeaux'].empty? && rand < 0.3 ? rand(s['chapeaux'].size) : -1)
    return fix_spec(spec)
  end

  # --- Texte à envoyer en ligne -----------------------------------------------------
  # @param spec [Hash]
  # @return [String] ex. "a.0.2.5.1.3.-1.-1.4"
  def to_code(spec)
    return ([spec['serie']] + CODE_KEYS.map { |key| spec[key].to_i }).join('.')
  end

  # @param code [String]
  # @return [Hash, nil] réglage valide, ou nil si le texte n'a pas la bonne forme
  def from_code(code)
    parts = code.to_s.strip.split('.')
    return nil unless parts.size == CODE_KEYS.size + 1 && parts[0].match?(/\A[a-z]\z/) && parts[1..].all? { |p| p.match?(/\A-?\d+\z/) }

    spec = { 'serie' => parts[0] }
    CODE_KEYS.each_with_index { |key, i| spec[key] = parts[i + 1].to_i }
    return fix_spec(spec)
  end

  # --- Icône du joueur ---------------------------------------------------------------
  # @return [Hash, nil] réglage du joueur (sauvegardé avec la partie)
  def spec
    return $user_data && $user_data[USER_KEY]
  end

  # Enregistre l'icône du joueur
  # @param new_spec [Hash]
  def apply(new_spec)
    return unless $user_data

    $user_data[USER_KEY] = fix_spec(Marshal.load(Marshal.dump(new_spec)))
    clear_textures
  end

  # --- Textes -------------------------------------------------------------------------
  # @return [String] "#rrggbb" d'une couleur de haut (pour la pastille)
  def top_hex(serie, index)
    return serie['hauts_hex'][index]
  end

  # @return [String] "#rrggbb" d'une couleur de cheveux
  def hair_hex(index)
    return catalog['couleurs_cheveux'][index]['hex']
  end

  # @return [String]
  def hair_label(index)
    return catalog['couleurs_cheveux'][index]['label']
  end

  # @return [String]
  def top_label(index)
    return catalog['couleurs_hauts'][index]
  end
end
