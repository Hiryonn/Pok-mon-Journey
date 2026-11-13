# Quel est ce Pokémon ? : un Pokémon à deviner chaque jour (date réelle), d'après sa silhouette
#
# Réglages : Studio, Level design > Mini-jeux > Quel est ce Pokémon (Data/configs/plugins/quel_pokemon.json)
#   pool        all (tous les Pokémon), seen (vus dans le Pokédex), list (liste choisie)
#   min_id, max_id   numéros du Pokédex national pris en compte (all / seen)
#   list        Pokémon de la liste (pool list) ; exclude : Pokémon jamais tirés
#   tries       essais (1 à 5) : le joueur écrit le nom ; hints : un indice après chaque erreur
#   mark_seen   le Pokémon révélé est marqué « vu » dans le Pokédex
#   rewards     [{ item, quantity, weight }] et money : gains d'une bonne réponse
#   rewards_mode random (un objet tiré au hasard dans la liste, selon les poids) ou all (tous)
#   streak_every, streak_rewards, streak_mode : objets en plus tous les N jours trouvés d'affilée
#   variable    variable qui reçoit le résultat (1 trouvé, 2 raté, 3 déjà joué aujourd'hui)
#   seed        change le Pokémon de chaque jour (même date, autre tirage)
# Images / sons : graphics/interface/minigames/whosthatpokemon.png, audio/se/minigames/{WhosThatPokemon,Correct,Incorrect}.ogg
module Configs
  class QuelPokemonConfig
    attr_accessor :pool, :min_id, :max_id, :list, :exclude, :tries, :hints, :mark_seen, :rewards, :rewards_mode, :money,
                  :streak_every, :streak_rewards, :streak_mode, :variable, :seed

    def initialize
      @pool = 'all'
      @min_id = 1
      @max_id = 1025
      @list = []
      @exclude = []
      @tries = 3
      @hints = true
      @mark_seen = true
      @rewards = []
      @rewards_mode = 'random'
      @money = 0
      @streak_every = 0
      @streak_rewards = []
      @streak_mode = 'random'
      @variable = 0
      @seed = 0
    end
  end
  register(:quel_pokemon, 'plugins/quel_pokemon', :json, false, QuelPokemonConfig)
end

module QuelPokemon
  CONFIG_FILE = 'Data/configs/plugins/quel_pokemon.json'
  BACKGROUND = 'minigames/whosthatpokemon'
  SE_INTRO = 'audio/se/minigames/WhosThatPokemon'
  SE_CORRECT = 'audio/se/minigames/Correct'
  SE_WRONG = 'audio/se/minigames/Incorrect'
  WIN = 1
  LOSE = 2
  ALREADY = 3

  module_function

  # Réglages (relus à chaque partie en test : Studio peut les avoir changés)
  # @return [Hash{Symbol => Object}]
  def config
    defaults = Configs::QuelPokemonConfig.new
    data = {}
    if PSDK_CONFIG.release?
      cfg = Configs.quel_pokemon
      defaults.instance_variables.each { |iv| data[iv.to_s.delete('@').to_sym] = cfg.instance_variable_get(iv) }
    elsif File.exist?(CONFIG_FILE)
      require 'json'
      data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8')).transform_keys(&:to_sym)
    end
    result = {}
    defaults.instance_variables.each do |iv|
      key = iv.to_s.delete('@').to_sym
      result[key] = data.key?(key) && !data[key].nil? ? data[key] : defaults.instance_variable_get(iv)
    end
    return result
  rescue StandardError, ScriptError => e
    log_error("Quel est ce Pokémon : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
    return config_defaults
  end

  def config_defaults
    defaults = Configs::QuelPokemonConfig.new
    return defaults.instance_variables.to_h { |iv| [iv.to_s.delete('@').to_sym, defaults.instance_variable_get(iv)] }
  end

  # Partie enregistrée : { day:, result:, guess:, streak:, best:, wins:, played: }
  # @return [Hash]
  def save_data
    return {} unless $user_data

    return $user_data[:pj_quel_pokemon] ||= { day: nil, result: nil, streak: 0, best: 0, wins: 0, played: 0 }
  end

  # Jour (date réelle, heure locale) : même calcul que la page de Studio
  # @return [Integer]
  def today
    now = Time.now
    return (now.to_i + now.utc_offset) / 86_400
  end

  def imul(a, b)
    return (a * b) & 0xffffffff
  end

  # Nombre pseudo-aléatoire fixe pour (jour, graine, n) : même calcul que la page de Studio
  def roll(day, seed, salt = 0)
    h = (day ^ (seed * 7919) ^ (salt * 104_729)) & 0xffffffff
    h = imul(h ^ (h >> 16), 0x45d9f3b)
    h = imul(h ^ (h >> 16), 0x45d9f3b)
    return (h ^ (h >> 16)) & 0xffffffff
  end

  # Pokémon pouvant être tirés, triés par numéro
  # @return [Array<Symbol>]
  def pool(cfg = config)
    excluded = Array(cfg[:exclude]).map(&:to_sym)
    list =
      if cfg[:pool].to_s == 'list'
        Array(cfg[:list]).map(&:to_sym).select { |db| data_creature(db).db_symbol == db rescue false }
      else
        min = cfg[:min_id].to_i
        max = cfg[:max_id].to_i
        all = []
        each_data_creature { |creature| all << creature if creature.id.between?(min, max) && creature.db_symbol != :__undef__ }
        all.sort_by!(&:id)
        all.map(&:db_symbol)
      end
    list -= excluded
    if cfg[:pool].to_s == 'seen' && $pokedex
      seen = list.select { |db| $pokedex.creature_seen?(db) rescue false }
      list = seen unless seen.empty?
    end
    list = list.uniq.sort_by { |db| data_creature(db).id }
    return list
  end

  # Pokémon du jour (toujours le même pour un jour donné)
  # @return [Symbol, nil]
  def daily(day = today, cfg = config)
    list = pool(cfg)
    return nil if list.empty?

    return list[roll(day, cfg[:seed].to_i) % list.size]
  end

  ACCENTS_FROM = 'àáâäãåāçćčèéêëēęìíîïīñńòóôöõøōùúûüūýÿœæß'
  ACCENTS_TO   = 'aaaaaaaccceeeeeeiiiiinnooooooouuuuuyyoas'

  # Texte sans majuscules, accents, espaces ni ponctuation (« Mr. Mime » = « mrmime »)
  # @return [String]
  def plain(text)
    s = text.to_s.dup.force_encoding(Encoding::UTF_8)
    s = s.scrub('').downcase.tr(ACCENTS_FROM, ACCENTS_TO).gsub('♀', 'f').gsub('♂', 'm')
    return s.gsub(/[^a-z0-9]/, '')
  end

  # Le nom écrit est-il le bon ? (nom dans la langue du jeu, ou nom de base de données)
  def good_answer?(written, db_symbol)
    guess = plain(written)
    return false if guess.empty?

    return [name_of(db_symbol), db_symbol.to_s].any? { |name| plain(name) == guess }
  end

  # Récompenses à donner : tout, ou une seule tirée au hasard (selon les poids)
  # @param list [Array<Hash>]
  # @param mode [String] random / all
  # @return [Array<Array(Symbol, Integer)>]
  def pick_rewards(list, mode)
    rewards = Array(list).filter_map do |reward|
      reward = reward.transform_keys(&:to_sym)
      item = reward[:item].to_s
      quantity = (reward[:quantity] || 1).to_i
      next if item.empty? || quantity <= 0

      [item.to_sym, quantity, [(reward[:weight] || 1).to_i, 0].max]
    end
    return rewards.map { |r| r.first(2) } if mode.to_s == 'all'

    rewards.reject! { |r| r[2] <= 0 }
    return [] if rewards.empty?

    n = rand(rewards.sum { |r| r[2] })
    pick = rewards.find { |r| (n -= r[2]) < 0 }
    return [pick.first(2)]
  end

  def played_today?
    return save_data[:day] == today
  end

  # Nom du Pokémon
  def name_of(db_symbol)
    return data_creature(db_symbol).name
  rescue StandardError
    return db_symbol.to_s
  end

  # @param fr [String]
  # @param en [String]
  def t(fr, en)
    return $options && $options.language.to_s != 'fr' ? en : fr
  end
end
