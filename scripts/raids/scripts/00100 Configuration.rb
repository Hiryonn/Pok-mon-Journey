# Raids (d'après « [DBK] Raid Battles » pour Essentials, de Lucidious89) : combats de raid contre un Pokémon géant,
# antres de raid sur les cartes, récompenses et Aventures Raid (labyrinthe avec Pokémon de location).
#
# Quatre styles :
#   basic  Antre de raid           boss normal ; les attaques super efficaces cassent plus vite le bouclier
#   ultra  Brèche Ultra            boss qui tient un cristal Z (capacité Z tous les 2 tours) ; les capacités Z cassent
#                                  2 barres de bouclier en plus
#   max    Antre Dynamax           boss Dynamax tout le combat (Gigamax s'il a le facteur) ; les attaques Max cassent
#                                  une barre de plus (deux pour une attaque G-Max)
#   tera   Antre Téracristal       boss Téracristallisé ; les attaques du type Téra cassent plus vite le bouclier
# Combat de raid : 1 à 3 Pokémon du joueur (les premiers de l'équipe en état de se battre) contre le boss, qui a
# beaucoup de PV. Le combat est perdu quand le compteur de tours ou de K.O. tombe à 0 (un Pokémon K.O. revient à la fin
# du tour). Sous la moitié de ses PV, le boss se protège derrière un bouclier (barres à casser, dégâts très réduits) et
# peut lancer une attaque de zone en plus. Rangs 3 et plus : actions en plus (efface ses baisses de stats, les hausses
# du joueur, l'encouragement) ; affaibli, le boss attaque deux fois. Encourager remplace la Fuite : le niveau
# d'encouragement monte à chaque tour (3 au plus) ; celui du style recharge le Dynamax / la capacité Z / le
# Téracristal du joueur (bloqués sinon). Une fois battu, le boss peut être capturé (une Poké Ball du sac, sans rater) ;
# un antre donne des objets selon son rang.
#
# Raid Obscur (plugin Obscurs) : le boss est un Pokémon Obscur (obscur_chance % des antres, ou obscur: true dans la
# commande) ; capturé, il reste Obscur et se purifie comme les autres.
#
# Réglages : Data/configs/plugins/raids.json (Studio : Level design > Mini-jeux > Raids)
#   settings   réglages généraux (taille de l'équipe, tours, K.O., bouclier, antres…)
#   styles     noms, charset de l'antre, fond de combat, musiques, textes de chaque style
#   species    Pokémon des raids : { pokemon, form, ranks: [1..6], styles: [] (tous si vide), gmax }
#   rewards    objets en plus des récompenses : [{ item, min, max, rank (mini), chance (%), style }]
#   adventure  réglages des aventures
# Cartes des aventures : Data/configs/plugins/raids_cartes.json
# Commandes d'évènement : 00110 Commandes.rb
module Configs
  class RaidsConfig
    attr_accessor :settings, :styles, :species, :rewards, :adventure

    def initialize
      @settings = {}
      @styles = {}
      @species = []
      @rewards = {}
      @adventure = {}
    end
  end
  register(:raids, 'plugins/raids', :json, false, RaidsConfig)

  class RaidMapsConfig
    attr_accessor :maps

    def initialize
      @maps = []
    end
  end
  register(:raids_cartes, 'plugins/raids_cartes', :json, false, RaidMapsConfig)
end

module Raids
  CONFIG_FILE = 'Data/configs/plugins/raids.json'
  MAPS_FILE = 'Data/configs/plugins/raids_cartes.json'
  DIR = 'raids/'
  STYLES = %i[basic ultra max tera].freeze
  DEFAULTS = {
    'party_size' => 2, 'turn_limit' => 10, 'knock_outs' => 4, 'shields' => true, 'shield_threshold' => 50,
    'extra_actions' => true, 'double_attack' => true, 'cheers' => true, 'max_moves_turn' => 5, 'z_power_every' => 2,
    'capture_chance' => 100, 'den_daily_reset' => true, 'bait_item' => 'raid_bait', 'badge_ranks' => true,
    'den_rewards' => true, 'no_exp' => true, 'heal_after' => true, 'obscur_chance' => 0, 'obscur_gauge' => 0,
    'den_daily_change' => true, 'den_notify' => true
  }.freeze
  STYLE_DEFAULTS = {
    basic: {
      'name' => { 'fr' => 'Raid', 'en' => 'Raid' }, 'den' => { 'fr' => 'Antre de raid', 'en' => 'Raid Den' },
      'adventure' => { 'fr' => 'Aventure Raid', 'en' => 'Raid Adventure' }, 'charset' => 'raid_den_basic',
      'background' => 'back_cave', 'bgm' => %w[raid_basic_battle_1 raid_basic_battle_2], 'capture_bgm' => 'raid_basic_capture',
      'adventure_bgm' => 'raid_basic_adventure',
      'appear' => { 'fr' => '%s sort de l’antre !', 'en' => '%s emerged from within the den!' },
      'flee' => { 'fr' => '%s disparaît au fond de l’antre…', 'en' => '%s disappeared somewhere into the den...' }
    },
    ultra: {
      'name' => { 'fr' => 'Raid Ultra', 'en' => 'Ultra Raid' }, 'den' => { 'fr' => 'Brèche Ultra', 'en' => 'Ultra Raid Wormhole' },
      'adventure' => { 'fr' => 'Aventure Ultra', 'en' => 'Ultra Adventure' }, 'charset' => 'raid_den_ultra',
      'background' => 'back_raid_ultra', 'bgm' => %w[raid_ultra_battle_1 raid_ultra_battle_2 raid_ultra_battle_3],
      'capture_bgm' => 'raid_ultra_capture', 'adventure_bgm' => 'raid_ultra_adventure',
      'appear' => { 'fr' => '%s sort de la brèche !', 'en' => '%s emerged from the wormhole!' },
      'flee' => { 'fr' => '%s repart par la brèche…', 'en' => '%s disappeared through the wormhole...' }
    },
    max: {
      'name' => { 'fr' => 'Raid Dynamax', 'en' => 'Max Raid' }, 'den' => { 'fr' => 'Antre Dynamax', 'en' => 'Max Raid Den' },
      'adventure' => { 'fr' => 'Aventure Dynamax', 'en' => 'Dynamax Adventure' }, 'charset' => 'raid_den_max',
      'background' => 'back_raid_max', 'bgm' => %w[raid_max_battle_1 raid_max_battle_2 raid_max_battle_3],
      'capture_bgm' => 'raid_max_capture', 'adventure_bgm' => 'raid_max_adventure',
      'appear' => { 'fr' => '%s Dynamax sort de l’antre !', 'en' => 'A Dynamaxed %s emerged from within the den!' },
      'flee' => { 'fr' => '%s disparaît au fond de l’antre…', 'en' => '%s disappeared somewhere into the den...' }
    },
    tera: {
      'name' => { 'fr' => 'Raid Téracristal', 'en' => 'Tera Raid' }, 'den' => { 'fr' => 'Antre Téracristal', 'en' => 'Tera Raid Den' },
      'adventure' => { 'fr' => 'Aventure Téracristal', 'en' => 'Terastal Adventure' }, 'charset' => 'raid_den_tera',
      'background' => 'back_raid_tera', 'bgm' => %w[raid_tera_battle_1 raid_tera_battle_2 raid_tera_battle_3],
      'capture_bgm' => 'raid_tera_capture', 'adventure_bgm' => 'raid_tera_adventure',
      'appear' => { 'fr' => '%s Téracristallisé sort de l’antre !', 'en' => 'A Terastallized %s emerged from within the den!' },
      'flee' => { 'fr' => '%s disparaît au fond de l’antre…', 'en' => '%s disappeared somewhere into the den...' }
    }
  }.freeze
  # Texte d'un style : nom de la mécanique liée
  GIMMICK_OF = { ultra: :zmove, max: :dynamax, tera: :tera }.freeze

  module_function

  # @return [Configs::RaidsConfig]
  def config
    @config ||= load_config(CONFIG_FILE, :raids, Configs::RaidsConfig)
  end

  # @return [Configs::RaidMapsConfig]
  def maps_config
    @maps_config ||= load_config(MAPS_FILE, :raids_cartes, Configs::RaidMapsConfig)
  end

  def load_config(file, name, klass)
    return Configs.send(name) if PSDK_CONFIG.release?
    return klass.new unless File.exist?(file)

    require 'json'
    data = JSON.parse(File.read(file, encoding: 'utf-8'))
    cfg = klass.new
    data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
    return cfg
  rescue StandardError, ScriptError => e
    log_error("Raids : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
    return klass.new
  end

  def reload
    @config = @maps_config = nil
    @species_cache = nil
  end

  def fetch(hash, key)
    return nil unless hash.is_a?(Hash)

    value = hash[key.to_s]
    return value.nil? ? hash[key.to_sym] : value
  end

  def setting(key)
    value = fetch(config.settings, key)
    return value.nil? ? DEFAULTS[key.to_s] : value
  end

  # @param style [Symbol]
  # @return [Hash] réglages du style (ceux de raids.json par-dessus ceux de base)
  def style_data(style)
    style = normalize_style(style)
    return STYLE_DEFAULTS[style].merge(fetch(config.styles, style) || {})
  end

  # @param style [Symbol, String, nil]
  # @return [Symbol]
  def normalize_style(style)
    style = style.to_s.downcase.to_sym
    return STYLES.include?(style) ? style : :basic
  end

  # Le style est utilisable (la mécanique liée est branchée dans le plugin gimmicks)
  def style_available?(style)
    style = normalize_style(style)
    data = fetch(config.styles, style)
    return false if data && fetch(data, 'enabled') == false
    return true if style == :basic

    kind = GIMMICK_OF[style]
    return defined?(::Gimmicks) && ::Gimmicks::HANDLERS.key?(kind)
  end

  def fr?
    return $options.nil? || $options.language.to_s == 'fr'
  end

  def t(fr, en = fr)
    return fr? ? fr : en
  end

  # Texte réglé { fr:, en: } ou chaîne
  def local(value, fallback = '')
    return value.to_s unless value.is_a?(Hash)

    return (fetch(value, fr? ? 'fr' : 'en') || fetch(value, 'fr') || value.values.first || fallback).to_s
  end

  def style_text(style, key)
    return local(fetch(style_data(style), key))
  end

  # @param name [String]
  # @return [String] image de graphics/interface
  def file(name)
    return "#{DIR}#{name}"
  end

  def item_exists?(item)
    return false if item.nil? || item.to_s.empty?

    return data_item(item.to_sym).db_symbol != :__undef__
  rescue StandardError
    return false
  end

  def item_name(item)
    return data_item(item.to_sym).name.to_s
  rescue StandardError
    return item.to_s
  end

  def creature_exists?(species)
    return data_creature(species.to_sym).db_symbol != :__undef__
  rescue StandardError
    return false
  end

  # Statistiques de la partie (combats gagnés, antres vidés, aventures)
  # @return [Hash]
  def stats
    state = PFM.game_state
    return state.instance_variable_get(:@pj_raid_stats) || state.instance_variable_set(:@pj_raid_stats, Hash.new(0))
  end

  # Nombre de badges du joueur
  def badges
    return $trainer.badge_counter.to_i if $trainer.respond_to?(:badge_counter)

    return 0
  rescue StandardError
    return 0
  end
end
