# Montures (façon Pokémon Légendes Arceus et Soleil / Lune)
#
# Le joueur appelle un Pokémon monture et se déplace sur son dos. Chaque monture a ses pouvoirs :
#   surf, waterfall, whirlpool, dive  nager, remonter les cascades, passer les tourbillons, plonger
#   strength, rock_smash, cut          pousser les rochers, casser les rochers, couper les arbustes
#   rock_climb, headbutt, flash        escalader, Coup d'Boule sur les arbres, éclairer
#   fly                                voler vers une ville (carte du monde)
#   search                             flairer les objets cachés (comme le Cherch'Objet)
# Les CS marchent toujours : la monture fait l'action si le joueur l'a (réglage prefer_mount), sinon un Pokémon de
# l'équipe qui connaît la capacité. Au contact de l'eau, d'un rocher, d'un arbre… le jeu propose la monture qui convient.
#   - Façon Légendes Arceus : une monture peut avoir plusieurs pouvoirs, on passe de l'une à l'autre (eau / terre)
#     automatiquement (réglage auto_switch).
#   - Façon Soleil / Lune : une monture par pouvoir.
# Appel : touche raccourci (réglage key : appui = monter / descendre, appui long = roue des montures), appli Monture
# du téléphone, commandes d'évènement (00110 Commandes.rb).
# Sprites : faits main, dans les ressources de chaque héros (voir 00101 Sprites.rb) ; sans sprite, le héros garde le sien.
#
# Réglages : Data/configs/plugins/montures.json (Studio : Données > Personnages > Montures)
#   settings  règles (voir DEFAULTS)
#   mounts    montures : voir MOUNT_DEFAULTS
module Configs
  class MonturesConfig
    attr_accessor :settings, :mounts

    def initialize
      @settings = {}
      @mounts = []
    end
  end
  register(:montures, 'plugins/montures', :json, false, MonturesConfig)
end

module Montures
  CONFIG_FILE = 'Data/configs/plugins/montures.json'
  DIR = 'montures/'
  DEFAULTS = {
    # touche raccourci (A, B, X, Y, L, R, L2, R2, START, SELECT) : appui = monter / descendre, appui long = roue
    'key' => 'R',
    # durée de l'appui long (images)
    'hold_frames' => 18,
    # la monture fait l'action même si un Pokémon de l'équipe connaît la capacité
    'prefer_mount' => true,
    # au contact de l'eau : demander avant d'appeler la monture (sinon elle arrive toute seule)
    'ask_on_contact' => true,
    # animation des CS (bandeau) quand c'est une monture qui agit (sinon : son cri)
    'hm_animation' => false,
    # cri de la monture quand on l'appelle
    'cry_on_call' => true,
    # monter seulement là où le vélo est permis (dehors)
    'outdoor_only' => true,
    # interrupteur qui interdit les montures quand il est activé (0 = aucun)
    'block_switch' => 0,
    # passer seul d'une monture de terre à une monture d'eau (et inversement)
    'auto_switch' => true,
    # musique quand on est sur une monture (vide = celle de la carte)
    'ride_bgm' => '',
    # objet nécessaire pour l'appli Monture et la touche (vide = aucun)
    'item' => ''
  }.freeze
  MOUNT_DEFAULTS = {
    'id' => '',
    'name' => '',
    'name_en' => '',
    'species' => '',
    'form' => 0,
    'shiny' => false,
    'level' => 50,
    'powers' => [],
    # vitesse sur la carte (3 = marche, 4 = course, 5 = vélo) ; course (B) : +1 si gallop
    'speed' => 4,
    'gallop' => true,
    # monture d'eau seulement (Lokhlass, Paragruel…)
    'water_only' => false,
    # rencontres sauvages (% de la normale)
    'encounters' => 100,
    # débloquée dès le début de la partie
    'start' => false,
    'bgm' => ''
  }.freeze
  # Pouvoirs : capacité de PSDK (évents communs des CS), noms
  POWERS = {
    'surf' => [:surf, 'Surf', 'Surf'],
    'waterfall' => [:waterfall, 'Cascade', 'Waterfall'],
    'whirlpool' => [:whirlpool, 'Siphon', 'Whirlpool'],
    'dive' => [:dive, 'Plongée', 'Dive'],
    'strength' => [:strength, 'Force', 'Strength'],
    'rock_smash' => [:rock_smash, 'Éclate-Roc', 'Rock Smash'],
    'cut' => [:cut, 'Coupe', 'Cut'],
    'rock_climb' => [:rock_climb, 'Escalade', 'Rock Climb'],
    'headbutt' => [:headbutt, 'Coup d’Boule', 'Headbutt'],
    'flash' => [:flash, 'Flash', 'Flash'],
    'fly' => [:fly, 'Vol', 'Fly'],
    'search' => [nil, 'Flair', 'Search']
  }.freeze
  WATER_POWERS = %w[surf waterfall whirlpool dive].freeze
  # États du joueur où il est dessiné sur sa monture
  RIDE_STATES = %i[walking running surfing swamp swamp_running].freeze
  # Évent commun du Cherch'Objet (PSDK)
  SEARCH_EVENT = 19

  module_function

  # @return [Configs::MonturesConfig]
  def config
    @config ||= load_config
  end

  def load_config
    return Configs.montures if PSDK_CONFIG.release?
    return Configs::MonturesConfig.new unless File.exist?(CONFIG_FILE)

    require 'json'
    data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
    cfg = Configs::MonturesConfig.new
    data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
    return cfg
  rescue StandardError, ScriptError => e
    log_error("Montures : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
    return Configs::MonturesConfig.new
  end

  def reload
    @config = nil
    @mounts = nil
    @pokemon = nil
  end

  def fetch(hash, key)
    return nil unless hash.is_a?(Hash)

    value = hash[key.to_s]
    return value.nil? ? hash[key.to_sym] : value
  end

  def setting(key)
    value = fetch(config.settings, key)
    return value.nil? || value == '' ? DEFAULTS[key.to_s] : value
  end

  def fr?
    return $options.nil? || $options.language.to_s == 'fr'
  end

  def t(fr, en = fr)
    return fr? ? fr : en
  end

  def file(name)
    return "#{DIR}#{name}"
  end

  # --- Montures ------------------------------------------------------------------------------------------------------
  # @return [Array<Hash>] montures réglées (avec les valeurs par défaut)
  def mounts
    @mounts ||= Array(config.mounts).select { |m| m.is_a?(Hash) }.map do |m|
      entry = MOUNT_DEFAULTS.merge(m.transform_keys(&:to_s))
      entry['id'] = entry['id'].to_s.empty? ? entry['species'].to_s : entry['id'].to_s
      entry['powers'] = Array(entry['powers']).map(&:to_s) & POWERS.keys
      entry
    end.reject { |m| m['id'].empty? || m['species'].to_s.empty? }
  end

  # @param id [String, Symbol, nil]
  # @return [Hash, nil]
  def mount(id)
    return nil if id.nil?

    return mounts.find { |m| m['id'] == id.to_s }
  end

  # Nom affiché de la monture
  def name(mount)
    return '' unless mount

    text = fr? ? mount['name'] : (mount['name_en'].to_s.empty? ? mount['name'] : mount['name_en'])
    return text.to_s unless text.to_s.empty?

    return species_name(mount)
  end

  def species_name(mount)
    return data_creature(mount['species'].to_sym).name
  rescue StandardError
    return mount['species'].to_s
  end

  # Pokémon de la monture (bandeau des CS, cri, icône, sprite de la carte)
  # @return [PFM::Pokemon, nil]
  def pokemon(mount)
    return nil unless mount

    @pokemon ||= {}
    return @pokemon[mount['id']] ||= begin
      pkmn = PFM::Pokemon.new(mount['species'].to_sym, mount['level'].to_i.clamp(1, 100), mount['shiny'] == true, mount['shiny'] != true,
                              mount['form'].to_i)
      pkmn.given_name = name(mount)
      pkmn
    end
  rescue StandardError => e
    log_error("Montures : Pokémon de « #{mount['id']} » (#{e.message})") if respond_to?(:log_error, true)
    return nil
  end

  def power?(mount, power)
    return mount && mount['powers'].include?(power.to_s)
  end

  # La monture peut aller sur l'eau
  def water?(mount)
    return power?(mount, 'surf')
  end

  # La monture peut aller sur terre
  def land?(mount)
    return mount && !(mount['water_only'] && water?(mount))
  end

  def power_name(power)
    entry = POWERS[power.to_s]
    return power.to_s unless entry

    return fr? ? entry[1] : entry[2]
  end

  # Pouvoir lié à une capacité de PSDK (:surf, 291…)
  # @return [String, nil]
  def power_of_skill(skill)
    skill = (data_move(skill).db_symbol rescue nil) if skill.is_a?(Integer)
    return POWERS.find { |_, v| v[0] && v[0] == skill&.to_sym }&.first
  end

  # --- Sauvegarde ----------------------------------------------------------------------------------------------------
  # @return [Hash] { 'unlocked' => [id], 'riding' => id, 'last' => id, 'land' => id }
  def data
    $user_data[:pj_montures] ||= {}
    store = $user_data[:pj_montures]
    unless store['init']
      store['init'] = true
      store['unlocked'] = mounts.select { |m| m['start'] }.map { |m| m['id'] }
    end
    store['unlocked'] ||= []
    return store
  end

  def unlocked?(id)
    return data['unlocked'].include?(id.to_s) && !mount(id).nil?
  end

  # @return [Array<Hash>] montures débloquées (ordre de Studio)
  def unlocked
    return mounts.select { |m| data['unlocked'].include?(m['id']) }
  end

  # Monture qui a un pouvoir (la monture actuelle d'abord, puis la dernière utilisée)
  # @return [Hash, nil]
  def mount_for(power)
    power = power.to_s
    list = unlocked.select { |m| power?(m, power) }
    return nil if list.empty?

    return list.find { |m| m['id'] == data['riding'] } || list.find { |m| m['id'] == data['last'] } ||
           list.find { |m| m['id'] == data['land'] } || list.first
  end

  # Le joueur a des montures et peut les appeler (objet nécessaire)
  def available?
    return false if unlocked.empty?

    item = setting('item').to_s
    return item.empty? || ($bag && $bag.contain_item?(item.to_sym))
  rescue StandardError
    return false
  end

  def key
    sym = setting('key').to_s.upcase.to_sym
    return Input::Keys.key?(sym) ? sym : :R
  rescue StandardError
    return :R
  end
end
