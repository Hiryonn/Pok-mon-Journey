# Pokéblocs (d'après « Pokemon Contests and Pokeblocks » de Kotaro / Zerokid pour Essentials)
#
# Mixeur à baies façon Rubis / Saphir / Émeraude : on choisit une baie, jusqu'à 3 autres joueurs (ou le Maître
# Baies) ajoutent la leur, puis on appuie sur A quand la flèche passe sur son repère (Parfait / Bien / Raté) pour
# faire tourner le disque plus vite. Le Pokébloc obtenu dépend des saveurs des baies (données de cuisine de Studio),
# de la vitesse maximale atteinte, et devient Noir si deux baies identiques sont mixées.
# Mixeur simple façon Rubis Oméga / Saphir Alpha (Kit Pokébloc) : jusqu'à 4 baies, un Pokébloc par baie, de la
# couleur des baies (Arc-en-ciel avec 4 couleurs différentes), version + selon la chance « Pokébloc meilleur ».
# Boîte Pokébloc : liste des Pokéblocs, Donner (écran d'état : Sang-froid, Beauté, Grâce, Intelligence,
# Robustesse et Lustre), Jeter. Les goûts de la nature du Pokémon changent l'effet (+10 % / -10 %).
#
# Réglages : Data/configs/plugins/pokeblocs.json (Studio : Données > Baies > Pokéblocs)
#   mode            rse (mixeur à jouer, Lustre) ou oras (mixeur simple, chaque condition plafonne à 255)
#   sheen           le Lustre limite ce qu'un Pokémon peut manger (mode rse)
#   max_blocks      nombre de Pokéblocs que la Boîte peut contenir (0 : sans limite)
#   npc_random      les autres joueurs choisissent leur baie au hasard (sinon : celle qui complète la vôtre)
#   npc_names       noms des autres joueurs (3 listes) ; master_names : noms du Maître Baies
#   master_berries  baies du Maître Baies quand npc_random est actif
#   bgm             musique du mixeur (vide : on garde celle de la carte)
# Commandes d'évènement : 00110 Commandes.rb
module Configs
  class PokeblocsConfig
    attr_accessor :settings

    def initialize
      @settings = {}
    end
  end
  register(:pokeblocs, 'plugins/pokeblocs', :json, false, PokeblocsConfig)
end

module Pokeblocs
  CONFIG_FILE = 'Data/configs/plugins/pokeblocs.json'
  DIR = 'pokeblocs/'
  DEFAULTS = {
    'mode' => 'rse', 'sheen' => true, 'max_blocks' => 40, 'npc_random' => false, 'bgm' => '',
    'npc_names' => [%w[Alice Alex André], %w[Barry Béatrice Bob], %w[Carl Chris Caroline]],
    'master_names' => %w[Devin Drew Diane],
    'master_berries' => %w[liechi_berry ganlon_berry salac_berry petaya_berry apicot_berry lansat_berry starf_berry
                           enigma_berry micle_berry custap_berry jaboca_berry rowap_berry kee_berry maranga_berry]
  }.freeze
  FLAVORS = %i[spicy dry sweet bitter sour].freeze
  STATS = %i[coolness beauty cuteness cleverness toughness].freeze
  # Couleurs : nom français, anglais, ordre de rangement dans la Boîte
  COLORS = {
    'red' => ['Rouge', 'Red', 1], 'blue' => ['Bleu', 'Blue', 2], 'pink' => ['Rose', 'Pink', 3],
    'green' => ['Vert', 'Green', 4], 'yellow' => ['Jaune', 'Yellow', 5], 'purple' => ['Violet', 'Purple', 6],
    'indigo' => ['Indigo', 'Indigo', 7], 'brown' => ['Marron', 'Brown', 8], 'liteblue' => ['Bleu clair', 'LiteBlue', 9],
    'olive' => ['Kaki', 'Olive', 10], 'gold' => ['Or', 'Gold', 11], 'gray' => ['Gris', 'Gray', 12],
    'white' => ['Blanc', 'White', 13], 'rainbow' => ['Arc-en-ciel', 'Rainbow', 15], 'black' => ['Noir', 'Black', 99]
  }.freeze
  SINGLE = %w[red blue pink green yellow].freeze
  DOUBLE = %w[purple indigo brown liteblue olive].freeze

  module_function

  # @return [Configs::PokeblocsConfig]
  def config
    @config ||= load_config
  end

  def load_config
    return Configs.pokeblocs if PSDK_CONFIG.release?
    return Configs::PokeblocsConfig.new unless File.exist?(CONFIG_FILE)

    require 'json'
    data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
    cfg = Configs::PokeblocsConfig.new
    data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
    return cfg
  rescue StandardError, ScriptError => e
    log_error("Pokéblocs : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
    return Configs::PokeblocsConfig.new
  end

  def reload
    @config = nil
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

  # Mode du mixeur : :rse (jeu, Lustre) ou :oras (simple)
  def simple?
    return setting('mode').to_s == 'oras'
  end

  def sheen?
    return !simple? && setting('sheen') != false
  end

  def fr?
    return $options.nil? || $options.language.to_s == 'fr'
  end

  def t(fr, en = fr)
    return fr? ? fr : en
  end

  # @param name [String]
  # @return [String] image de graphics/interface
  def file(name)
    return "#{DIR}#{name}"
  end

  def play_se(name, volume = 100)
    Audio.se_play("audio/se/#{name}", volume)
  rescue StandardError
    nil
  end

  def play_bgm(name)
    return if name.to_s.empty?

    $game_system.bgm_play(RPG::AudioFile.new(name.to_s, 100, 100))
  rescue StandardError
    nil
  end

  # --- Baies --------------------------------------------------------------------------------------------------------
  # @param item [Symbol, Integer]
  # @return [Studio::Item::CookingData, nil]
  def cooking(item)
    data = data_item(item)
    return nil if data.db_symbol == :__undef__

    return data.respond_to?(:cooking_data) ? data.cooking_data : nil
  rescue StandardError
    return nil
  end

  def berry?(item)
    return !cooking(item).nil?
  end

  # @return [Array<Integer>] saveurs [épicé, sec, sucré, amer, acide]
  def flavors(item)
    data = cooking(item)
    return [0, 0, 0, 0, 0] unless data

    return [data.spicy_flavor, data.dry_flavor, data.sweet_flavor, data.bitter_flavor, data.sour_flavor].map(&:to_i)
  end

  def smoothness(item)
    return cooking(item)&.smoothness.to_i
  end

  def berry_color(item)
    color = cooking(item)&.pokeblock_color.to_s
    return SINGLE.include?(color) ? color : 'red'
  end

  def better_chance(item)
    return cooking(item)&.better_pokeblock_chance.to_i
  end

  def item_sym(item)
    return data_item(item).db_symbol
  rescue StandardError
    return :__undef__
  end

  def item_name(item)
    return data_item(item).name.to_s
  rescue StandardError
    return item.to_s
  end

  # Baies du sac qui peuvent aller dans le mixeur
  # @return [Array<Symbol>]
  def bag_berries
    return [] unless $bag

    return (0..7).flat_map { |socket| $bag.get_order(socket).to_a }.uniq
                 .select { |item| $bag.item_quantity(item) > 0 && berry?(item) }
  rescue StandardError
    return []
  end
end
