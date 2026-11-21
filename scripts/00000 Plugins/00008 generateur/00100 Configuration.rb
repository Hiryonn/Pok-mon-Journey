# Générateur de personnages : le joueur crée son personnage en jeu
#
# Les pièces (base, cheveux, haut, bas, chapeau, sac) sont préparées dans Pokémon Studio :
#   Générateurs > Personnages > Dossiers des pièces > « Préparer pour le jeu »
#   -> graphics/generateur/<sprite>/<n>.png et Data/configs/plugins/generateur_pieces.json
#
# Commande d'évent (Script) : personnaliser_joueur        (annulable : personnaliser_joueur(true))
# Le personnage du joueur est assemblé en jeu (aucun fichier écrit) : charset « pj_joueur »
#   (pj_joueur_m_walk, _run, _cycle_roll, _misc2, _swim…) et dresseur de dos « pj_joueur ».
module Configs
  # Contenu de Data/configs/plugins/generateur_pieces.json (écrit par Studio)
  class GenerateurPiecesConfig
    attr_accessor :kinds, :labels, :color_labels, :color_hex, :skin_labels, :skin_hex

    def initialize
      @kinds = {}
      @labels = {}
      @color_labels = {}
      @color_hex = {}
      @skin_labels = {}
      @skin_hex = {}
    end
  end
  register(:generateur_pieces, 'plugins/generateur_pieces', :json, false, GenerateurPiecesConfig)
end

module Generateur
  CONFIG_FILE = 'Data/configs/plugins/generateur_pieces.json'
  # Dossier des pièces copiées par Studio
  PARTS_DIR = 'graphics/generateur'
  # Nom du charset du joueur (pj_joueur_m_walk…) et de son sprite de dos
  CHARSET = 'pj_joueur'
  # Suffixe du charset -> sprite assemblé (les autres états utilisent la marche)
  SUFFIX_KIND = {
    'walk' => 'walk', 'run' => 'run', 'swim' => 'swim', 'misc2' => 'water',
    'cycle_roll' => 'bike', 'cycle_stop' => 'bike', 'cycle_wheel' => 'bike', 'cycle_roll_to_wheel' => 'bike'
  }.freeze
  # Ordre des calques
  LAYERS = %w[base bottom top bag hair hat].freeze
  # Sprites de la carte : les pièces sont 2 fois trop grandes pour PSDK (format RPG Maker), on les réduit de moitié
  HALF_KINDS = %w[walk run bike swim water].freeze
  # Pièces réglables (chapeau et sac peuvent être « Aucun »)
  CATS = %w[hair top bottom hat bag].freeze
  OPTIONAL = %w[hat bag].freeze
  # Images du dresseur de dos (côte à côte dans les pièces, les unes sous les autres pour PSDK)
  BACK_FRAMES = 5
  # Couleur la plus proche quand un sprite n'a pas la couleur choisie (mêmes listes que Studio)
  NEAR_COLORS = {
    'light green' => %w[green], 'powder blue' => ['light blue', 'cyan', 'blue'], 'lavender' => %w[purple pink],
    'magenta' => %w[pink purple], 'light blue' => ['cyan', 'powder blue', 'blue'], 'aqua' => ['cyan', 'light blue', 'blue'],
    'cyan' => ['light blue', 'aqua', 'blue'], 'navy' => %w[blue black], 'wine' => %w[red purple], 'beige' => %w[brown white],
    'grey' => %w[black white], 'ginger' => %w[red orange brown], 'blonde' => %w[yellow], 'yellow' => %w[blonde orange],
    'orange' => %w[ginger red yellow], 'purple' => %w[lavender magenta pink], 'pink' => %w[magenta red],
    'brown' => %w[ginger beige black], 'green' => ['light green'], 'blue' => ['navy', 'light blue', 'cyan'],
    'red' => %w[wine pink ginger], 'dark' => %w[black navy], 'light' => %w[white grey]
  }.freeze
  # Luminosité sous laquelle un pixel est un contour (gardé tel quel par les teintes)
  OUTLINE_L = 0.15

  module_function

  # @return [Configs::GenerateurPiecesConfig]
  def config
    @config ||= begin
      PSDK_CONFIG.release? || File.exist?(CONFIG_FILE) ? Configs.generateur_pieces : Configs::GenerateurPiecesConfig.new
    rescue StandardError, ScriptError => e
      log_error("Générateur : #{CONFIG_FILE} illisible (#{e.message})") if respond_to?(:log_error, true)
      Configs::GenerateurPiecesConfig.new
    end
  end

  # Clés en texte (le fichier peut être lu avec des clés en symboles)
  def stringify(obj)
    case obj
    when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify(v) }
    when Array then obj.map { |v| stringify(v) }
    else obj
    end
  end

  # @return [Hash{String => Array<Hash>}] pièces par sprite
  def kinds
    @kinds ||= stringify(config.kinds || {})
  end

  def text_table(name)
    @tables ||= {}
    @tables[name] ||= stringify(config.send(name) || {})
  end

  # @return [Boolean] les pièces ont été préparées dans Studio
  def available?
    return !(kinds['walk'] || []).empty?
  end

  # @param kind [String]
  # @return [Array<Hash>]
  def entries(kind)
    return kinds[kind.to_s] || []
  end

  def ok_gender?(entry, gender)
    return entry['gender'].to_s.empty? || entry['gender'] == gender
  end

  # Choix possibles pour un genre : { 'skins' => [...], 'hair' => { 'clé' => [couleurs] }, … }
  # (toutes les pièces de la marche : c'est le sprite le plus complet)
  def options(gender)
    list = entries('walk').select { |e| ok_gender?(e, gender) }
    out = { 'skins' => list.select { |e| e['cat'] == 'base' }.map { |e| e['key'] }.uniq }
    order = %w[pale light medium dark]
    out['skins'].sort_by! { |k| order.index(k) || 9 }
    CATS.each do |cat|
      map = {}
      list.select { |e| e['cat'] == cat }.each { |e| (map[e['key']] ||= []) << e['color'] }
      map.each_value(&:uniq!)
      out[cat] = map
    end
    return out
  end

  # @return [Array<String>] clés triées d'une pièce
  def keys(opts, cat)
    list = (opts[cat] || {}).keys
    return cat == 'hair' ? list.sort_by(&:to_i) : list.sort_by { |k| label(k) }
  end

  # --- Textes -----------------------------------------------------------------
  def label(key)
    return text_table(:labels)[key] || key.to_s.capitalize
  end

  def color_label(color)
    return 'unique' if color.to_s.empty?

    return text_table(:color_labels)[color] || color
  end

  def skin_label(skin)
    return text_table(:skin_labels)[skin] || skin
  end

  # @return [String, nil] "#rrggbb" d'une couleur de pièce (pour la pastille)
  def color_hex(color)
    return text_table(:color_hex)[color]
  end

  def skin_hex(skin)
    return text_table(:skin_hex)[skin]
  end

  # --- Personnage du joueur -------------------------------------------------------
  # @return [Hash, nil] choix du joueur (sauvegardé avec la partie)
  def spec
    return $user_data && $user_data[:pj_generateur]
  end

  # Enregistre le personnage et l'applique au joueur
  # @param new_spec [Hash]
  # @param keep_outfit [Boolean] garder les sprites d'une tenue toute faite (clé 'outfit_sprites', plugin wardrobe) ; sinon
  #   un personnage (re)fait avec le générateur retrouve ses propres sprites
  def apply(new_spec, keep_outfit = false)
    new_spec.delete('outfit_sprites') unless keep_outfit
    $user_data[:pj_generateur] = new_spec
    clear_textures
    $game_switches[Yuki::Sw::Gender] = new_spec['gender'] == 'f' if $game_switches
    actor = $game_actors && $game_actors[1]
    actor&.instance_variable_set(:@battler_name, '')
    # nom nouveau à chaque fois : sinon le sprite du joueur garde l'ancienne image (même nom de charset)
    $user_data[:pj_generateur_rev] = ($user_data[:pj_generateur_rev] || 0) + 1
    $game_player&.set_appearance_set("#{CHARSET}_r#{$user_data[:pj_generateur_rev]}")
  end

  # Personnage au hasard
  # @param gender [String, nil]
  # @return [Hash]
  def random_spec(gender = nil)
    gender ||= %w[m f].sample
    opts = options(gender)
    spec = { 'gender' => gender, 'skin' => opts['skins'].sample || 'light' }
    CATS.each do |cat|
      keys = (opts[cat] || {}).keys
      if keys.empty? || (OPTIONAL.include?(cat) && rand(2) == 0)
        spec[cat] = nil
        next
      end
      key = keys.sample
      spec[cat] = { 'key' => key, 'color' => opts[cat][key].sample }
    end
    return spec
  end
end
