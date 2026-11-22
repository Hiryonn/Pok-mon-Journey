# Concours (d'après « Pokemon Super Contests » de Swdfm / Kotaro pour Essentials) : Super Concours façon Diamant
# Étincelant / Perle Scintillante, sur un écran dédié (scène, public, présentateur).
#
# Accueil (type, rang, Pokémon, ruban déjà gagné), scène avec présentation des concurrents, trois épreuves jouées
# sur leurs propres écrans (00107 Habillage, 00108 Danse, 00109 Acteur ; réglage minigames à false : épreuves
# simulées), résultats avec barres, places, projecteur sur le gagnant, ruban, tableau des gagnants et Mallette.
# Points : Condition (principale + secondaires / 2 + Lustre / 2) + Habillage (accessoires × points du thème)
#          + Danse (+2 excellent, +1 bien) + Jeu d'acteur (cœurs × 10). Les concurrents ont des points fixés par rang.
#
# Réglages : Data/configs/plugins/concours.json (Studio : Level design > Mini-jeux > Concours)
#   settings     musiques, présentateur (nom, apparence), objet Passe Concours exigé, temps et accessoires de
#                l'habillage par rang, interrupteur de victoire, variable de la place
#   types        Sang-froid, Beauté, Grâce, Intelligence, Robustesse (noms)
#   ranks        Normal, Méga, Ultra, Master : interrupteur pour l'ouvrir (0 : ouvert), 4 concurrents (dresseur,
#                apparence, Pokémon, surnom, sexe, forme, chromatique, points d'habillage et de condition)
#   ribbons      ruban gagné pour chaque type et rang (rubans de PSDK)
#   themes, categories, accessories (points de 0 à 3 par thème), backdrops, starter (Mallette de départ),
#   rewards      récompenses de victoire par rang (objets, argent, accessoires)
#   moves        capacités du jeu d'acteur : { "megahorn": ["cool", 2, "plus_2_if_last"] } (type, cœurs, effet) ;
#                une capacité absente prend sa condition de Studio, son attrait / 2 et l'effet de base
# Commandes d'évènement : 00110 Commandes.rb
module Configs
  class ConcoursConfig
    attr_accessor :settings, :types, :ranks, :ribbons, :themes, :categories, :accessories, :backdrops, :starter,
                  :rewards, :moves

    def initialize
      @settings = {}
      @types = []
      @ranks = []
      @ribbons = {}
      @themes = []
      @categories = []
      @accessories = []
      @backdrops = []
      @starter = {}
      @rewards = []
      @moves = {}
    end
  end
  register(:concours, 'plugins/concours', :json, false, ConcoursConfig)
end

module Concours
  CONFIG_FILE = 'Data/configs/plugins/concours.json'
  DIR = 'concours/'
  DEFAULTS = {
    'hall_bgm' => 'concours_hall', 'judging_bgm' => 'concours_jugement', 'results_bgm' => 'concours_resultats',
    'winner_bgm' => 'concours_gagnant', 'win_bgm' => 'concours_victoire', 'mc_name' => 'Dexter',
    'mc_charset' => 'chef_orchestre', 'pass_item' => '', 'dressup_time' => 60, 'max_accessories' => [5, 10, 15, 20],
    'win_switch' => 0, 'result_variable' => 0, 'minigames' => true,
    'dressup_bgm' => 'concours_habillage', 'dance_bgm' => 'concours_jugement', 'acting_bgm' => 'concours_jugement',
    'judges' => [{ 'name' => 'Jordan', 'charset' => 'npc_ace-trainer-m-01' }, { 'name' => '', 'charset' => '' },
                 { 'name' => 'Keira', 'charset' => 'npc_lady' }],
    # Danse : [excellent, bien, bonne direction] des concurrents et [pas rapprochés, au début / à la fin,
    # différents] du danseur principal, en % par rang
    'dance' => { 'timing' => [[10, 70, 80], [35, 50, 85], [60, 30, 90], [80, 15, 95]],
                 'lead' => [[20, 10, 20], [40, 30, 40], [60, 60, 60], [80, 80, 80]] },
    'acting_avoid' => [90, 50, 20, 0]
  }.freeze
  TYPE_IDS = %w[cool beauty cute smart tough].freeze
  RANK_IDS = %w[normal great ultra master].freeze
  TYPE_NAMES = { 'cool' => %w[Sang-froid Cool], 'beauty' => %w[Beauté Beauty], 'cute' => %w[Grâce Cute],
                 'smart' => %w[Intelligence Smart], 'tough' => %w[Robustesse Tough] }.freeze
  RANK_NAMES = { 'normal' => %w[Normal Normal], 'great' => %w[Méga Great], 'ultra' => %w[Ultra Ultra],
                 'master' => %w[Master Master] }.freeze
  # Condition principale, puis les deux secondaires (comptées pour moitié)
  CONDITIONS = {
    'cool' => %i[coolness beauty toughness], 'beauty' => %i[beauty coolness cuteness],
    'cute' => %i[cuteness cleverness beauty], 'smart' => %i[cleverness toughness cuteness],
    'tough' => %i[toughness coolness cleverness]
  }.freeze
  # Condition des capacités dans Studio
  MOVE_CONDITION = { 'cool' => :cool, 'beauty' => :beautiful, 'cute' => :cute, 'smart' => :clever, 'tough' => :tough }.freeze

  module_function

  # @return [Configs::ConcoursConfig]
  def config
    @config ||= load_config
  end

  def load_config
    return Configs.concours if PSDK_CONFIG.release?
    return Configs::ConcoursConfig.new unless File.exist?(CONFIG_FILE)

    require 'json'
    data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
    cfg = Configs::ConcoursConfig.new
    data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
    return cfg
  rescue StandardError, ScriptError => e
    log_error("Concours : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
    return Configs::ConcoursConfig.new
  end

  def reload
    @config = nil
    @accessory_index = nil
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

  # Texte réglé { fr:, en: } ou chaîne
  def local(value, fallback = '')
    return (value.nil? || value.to_s.empty? ? fallback : value.to_s) unless value.is_a?(Hash)

    text = fetch(value, fr? ? 'fr' : 'en')
    text = fetch(value, 'fr') if text.to_s.empty?
    text = fetch(value, 'en') if text.to_s.empty?
    return text.to_s.empty? ? fallback : text.to_s
  end

  # @param name [String]
  # @return [String] image de graphics/interface
  def file(name)
    return "#{DIR}#{name}"
  end

  def image?(name)
    return RPG::Cache.interface_exist?(file(name))
  end

  def play_se(name, volume = 100)
    Audio.se_play("audio/se/#{name}", volume)
  rescue StandardError
    nil
  end

  def play_me(name)
    Audio.me_play("audio/me/#{name}")
  rescue StandardError
    nil
  end

  def play_bgm(name)
    return if name.to_s.empty?

    $game_system.bgm_play(RPG::AudioFile.new(name.to_s, 100, 100))
  rescue StandardError
    nil
  end

  # --- Types et rangs -----------------------------------------------------------------------------------------------
  def type_ids
    return TYPE_IDS
  end

  def rank_ids
    return RANK_IDS
  end

  def type_index(type)
    return TYPE_IDS.index(type.to_s) || 0
  end

  def rank_index(rank)
    return RANK_IDS.index(rank.to_s) || 0
  end

  def type_data(type)
    return Array(config.types).find { |data| fetch(data, 'id').to_s == type.to_s } || {}
  end

  def rank_data(rank)
    return Array(config.ranks).find { |data| fetch(data, 'id').to_s == rank.to_s } || {}
  end

  def type_name(type)
    names = TYPE_NAMES[type.to_s] || [type.to_s, type.to_s]
    return local(fetch(type_data(type), 'name'), fr? ? names[0] : names[1])
  end

  def rank_name(rank)
    names = RANK_NAMES[rank.to_s] || [rank.to_s, rank.to_s]
    return local(fetch(rank_data(rank), 'name'), fr? ? names[0] : names[1])
  end

  # Bandeau de couleur du concours : fond, rang (à gauche) et catégorie (à droite)
  # @param stack [UI::SpriteStack]
  # @param left [String, nil] texte de gauche (par défaut : « Rang Normal »)
  # @return [Array] [sprite, texte gauche, texte droite]
  def add_banner(stack, type, rank, y = 0, left: nil, right: nil, color: 10)
    kind = TYPE_IDS.include?(type.to_s) ? type.to_s : 'cute'
    sprite = stack.add_sprite(0, y, file("bandeau_#{kind}"))
    left ||= t("Rang #{rank_name(rank)}", "#{rank_name(rank)} Rank")
    right ||= t("Concours #{type_name(type)}", "#{type_name(type)} Contest")
    a = stack.add_text(24, y + 1, 150, 16, left, color: color)
    b = stack.add_text(150, y + 1, 164, 16, right, 2, color: color)
    return [sprite, a, b]
  end

  # Pastille de couleur d'une catégorie
  def pill_file(type)
    return file("pastille_#{TYPE_IDS.include?(type.to_s) ? type : 'cute'}")
  end

  # « Concours Sang-froid rang Master »
  def contest_name(type, rank)
    return t("Concours #{type_name(type)} rang #{rank_name(rank)}", "#{rank_name(rank)} Rank #{type_name(type)} Contest")
  end

  # Le rang est ouvert (interrupteur réglé allumé, ou pas d'interrupteur)
  def rank_open?(rank)
    switch = fetch(rank_data(rank), 'switch').to_i
    return switch <= 0 || $game_switches[switch]
  end

  # @return [Array<Hash>] concurrents du rang
  def rank_contestants(rank)
    return Array(fetch(rank_data(rank), 'contestants'))
  end

  # @return [Symbol, nil] ruban du type et du rang
  def ribbon(type, rank)
    list = fetch(config.ribbons, type.to_s)
    value = Array(list)[rank_index(rank)]
    value = "#{type}_#{rank}_sinnoh" if value.nil? || value.to_s.empty?
    return value.to_s.to_sym
  end

  def ribbon_name(symbol)
    data = defined?(PFM::RIBBONS_DATA) ? PFM::RIBBONS_DATA[symbol] : nil
    return data ? data.name.to_s : symbol.to_s
  rescue StandardError
    return symbol.to_s
  end

  # --- Habillage ----------------------------------------------------------------------------------------------------
  def themes
    return Array(config.themes)
  end

  def theme_name(index)
    return local(fetch(themes[index.to_i], 'name'), '?')
  end

  def categories
    return Array(config.categories)
  end

  def accessories
    return Array(config.accessories)
  end

  # @return [Hash, nil]
  def accessory(id)
    @accessory_index ||= accessories.to_h { |data| [fetch(data, 'id').to_s, data] }
    return @accessory_index[id.to_s]
  end

  def accessory_name(id)
    data = accessory(id)
    return data ? local(fetch(data, 'name'), id.to_s) : id.to_s
  end

  def accessory_points(id, theme)
    return Array(fetch(accessory(id), 'points'))[theme.to_i].to_i
  end

  def accessory_image(id)
    return file("accessoires/#{fetch(accessory(id), 'file') || id}")
  end

  def backdrops
    return Array(config.backdrops)
  end

  def backdrop(id)
    return backdrops.find { |data| fetch(data, 'id').to_s == id.to_s }
  end

  def backdrop_name(id)
    data = backdrop(id)
    return data ? local(fetch(data, 'name'), id.to_s) : id.to_s
  end

  def backdrop_image(id, card = false)
    name = fetch(backdrop(id), 'file') || id
    return file(card ? "fonds/carte_#{name}" : "fonds/#{name}")
  end

  def max_accessories(rank)
    list = Array(setting('max_accessories'))
    return (list[rank_index(rank)] || [5, 10, 15, 20][rank_index(rank)]).to_i
  end

  # Les épreuves se jouent (sinon elles sont simulées)
  def minigames?
    value = fetch(config.settings, 'minigames')
    return value.nil? || value == true || value.to_s == 'true'
  end

  # --- Jeu d'acteur -------------------------------------------------------------------------------------------------
  # @return [Array<Hash>] 3 juges { 'name', 'charset' } ; celui du milieu est le juge principal (le présentateur)
  def judges
    list = Array(setting('judges'))
    defaults = DEFAULTS['judges']
    return Array.new(3) do |i|
      data = list[i].is_a?(Hash) ? list[i] : {}
      name = fetch(data, 'name').to_s
      charset = fetch(data, 'charset').to_s
      name = i == 1 ? setting('mc_name').to_s : defaults[i]['name'] if name.empty?
      charset = i == 1 ? setting('mc_charset').to_s : defaults[i]['charset'] if charset.empty?
      { 'name' => name, 'charset' => charset }
    end
  end

  # Types qui font monter (le même), qui ne changent rien et qui font baisser l'ambiance d'un concours
  OPPOSED = { 'cool' => %w[smart cute], 'beauty' => %w[tough smart], 'cute' => %w[cool tough],
              'smart' => %w[cool beauty], 'tough' => %w[beauty cute] }.freeze

  # @return [Symbol] :match, :neutral ou :opposed
  def move_relation(move_type, contest_type)
    return :match if move_type.to_s == contest_type.to_s
    return :opposed if Array(OPPOSED[contest_type.to_s]).include?(move_type.to_s)

    return :neutral
  end

  # @param symbol [Symbol] capacité
  # @return [Array(String, Integer, String)] type de concours, cœurs d'attrait (0 à 3), effet
  def contest_move(symbol)
    data = fetch(config.moves, symbol.to_s)
    return [data[0].to_s, data[1].to_i.clamp(0, 3), data[2].to_s.empty? ? 'basic' : data[2].to_s] if data.is_a?(Array)

    move = data_move(symbol)
    condition = move.respond_to?(:condition) ? move.condition&.to_sym : nil
    type = MOVE_CONDITION.key(condition) || 'cool'
    appeal = move.respond_to?(:appeal) ? (move.appeal.to_i / 2).clamp(0, 3) : 1
    return [type, appeal, 'basic']
  rescue StandardError
    return ['cool', 1, 'basic']
  end

  # Effets des capacités : [français, anglais]
  EFFECTS = {
    'basic' => ['Une prestation de base.', 'A basic act.'],
    'plus_2_if_first' => ['+2 si le Pokémon passe en premier.', '+2 if the Pokémon performs first.'],
    'plus_2_if_last' => ['+2 si le Pokémon passe en dernier.', '+2 if the Pokémon performs last.'],
    'prevent_voltage_up_same_turn' => ["L'ambiance ne peut plus monter pendant ce tour.",
                                       'Prevents the Voltage from going up in the same turn.'],
    'prevent_voltage_down_same_turn' => ["L'ambiance ne peut plus baisser pendant ce tour.",
                                         'Prevents the Voltage from going down in the same turn.'],
    'can_perform_move_twice_in_a_row' => ['La capacité peut être reprise au tour suivant.',
                                          'Can be performed twice in a row.'],
    'plus_3_if_previous_pokemon_hit_max_voltage' => ["+3 si le Pokémon précédent a mis l'ambiance au maximum.",
                                                     '+3 if the Pokémon before hit max Voltage.'],
    'double_score_next_turn' => ['Double les points du tour suivant.', 'Earns double the score on the next turn.'],
    'raise_score_if_voltage_low' => ["Plus l'ambiance du juge est basse, plus elle rapporte.",
                                     'The lower the Voltage, the higher the score.'],
    'increased_voltage_added_to_score' => ["L'ambiance du juge s'ajoute aux points.",
                                           'The Voltage is added to the score.'],
    'next_1' => ['Le Pokémon passera en premier au tour suivant.', 'The Pokémon performs first next turn.'],
    'next_4' => ['Le Pokémon passera en dernier au tour suivant.', 'The Pokémon performs last next turn.'],
    'double_score_if_final_turn' => ['Double les points du dernier tour.', 'Earns double the score on the final turn.'],
    'plus_3_if_2_voltage_in_a_row' => ["+3 si l'ambiance monte deux fois de suite.",
                                       '+3 if the Voltage goes up twice in a row.'],
    'plus_2_if_voltage_up' => ["+2 si l'ambiance du juge monte.", '+2 if the Voltage goes up.'],
    'steal_voltage_previous_pokemon' => ['Obtient le bonus du Pokémon précédent s’il a mis l’ambiance au maximum.',
                                         'Gets the same score as the previous Pokémon if it hit max Voltage.'],
    'plus_3_if_get_lowest_score' => ['+3 si le Pokémon a le moins de points du tour.',
                                     '+3 if the Pokémon gets the lowest score.'],
    'lower_voltage_of_all_judges_1' => ["Fait baisser l'ambiance de tous les juges.",
                                        'Lowers the Voltage of all Judges by 1.'],
    'higher_score_the_later_performs' => ['Rapporte plus si le Pokémon passe tard.',
                                          'The later the Pokémon performs, the higher the score.'],
    'plus_3_if_no_pokemon_chose_judge' => ['+3 si aucun autre Pokémon ne choisit ce juge.',
                                           '+3 if no other Pokémon chose the same Judge.'],
    'plus_15_if_all_chose_same_judge' => ['+15 si tous les Pokémon choisissent ce juge.',
                                          '+15 if all the Pokémon chose the same Judge.'],
    'random_order' => ["Mélange l'ordre de passage du tour suivant.", 'Shuffles the order for the next turn.'],
    'points_equal_to_order' => ["Rapporte autant que l'ordre de passage.", 'Earns points equal to its order.']
  }.freeze

  def effect_text(effect)
    texts = EFFECTS[effect.to_s] || EFFECTS['basic']
    return t(texts[0], texts[1])
  end

  # Danse : réglages en % par rang
  def dance_rates(kind, rank)
    data = setting('dance')
    list = Array(fetch(data, kind))
    list = DEFAULTS['dance'][kind] if list.empty?
    return Array(list[rank_index(rank)] || list.last).map(&:to_i)
  end

  def acting_avoid(rank)
    list = Array(setting('acting_avoid'))
    return (list[rank_index(rank)] || DEFAULTS['acting_avoid'][rank_index(rank)]).to_i
  end

  # Cœurs du défilé (rose : habillage, rouge : condition) d'après les points, par rang
  DRESSUP_HEARTS = [[1, 3, 5, 8], [1, 5, 10, 15], [1, 7, 15, 23], [1, 10, 20, 30]].freeze
  CONDITION_HEARTS = [[10, 10], [90, 20], [170, 30], [320, 40]].freeze

  def dressup_hearts(points, rank)
    return DRESSUP_HEARTS[rank_index(rank)].count { |limit| points.to_i >= limit }
  end

  def condition_hearts(points, rank)
    start, step = CONDITION_HEARTS[rank_index(rank)]
    return 0 if points.to_i < start

    return (1 + (points.to_i - start) / step).clamp(0, 8)
  end
end
