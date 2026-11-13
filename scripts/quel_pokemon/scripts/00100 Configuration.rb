# Quel est ce Pokémon ? : un Pokémon à deviner chaque jour (date réelle), d'après sa silhouette
#
# Réglages : Studio, Level design > Mini-jeux > Quel est ce Pokémon (Data/configs/plugins/quel_pokemon.json)
#   pool        all (tous les Pokémon), seen (vus dans le Pokédex), list (liste choisie)
#   min_id, max_id   numéros du Pokédex national pris en compte (all / seen)
#   list        Pokémon de la liste (pool list) ; exclude : Pokémon jamais tirés
#   choices     nombre de réponses proposées (2 à 6) ; tries : essais (1 à 3)
#   mark_seen   le Pokémon révélé est marqué « vu » dans le Pokédex
#   rewards     [{ item, quantity }] et money : gains d'une bonne réponse
#   streak_every, streak_rewards : bonus tous les N jours gagnés d'affilée
#   variable    variable qui reçoit le résultat (1 trouvé, 2 raté, 3 déjà joué aujourd'hui)
#   seed        change le Pokémon de chaque jour (même date, autre tirage)
# Images / sons : graphics/interface/minigames/whosthatpokemon.png, audio/se/minigames/{WhosThatPokemon,Correct,Incorrect}.ogg
module Configs
  class QuelPokemonConfig
    attr_accessor :pool, :min_id, :max_id, :list, :exclude, :choices, :tries, :mark_seen, :rewards, :money, :streak_every,
                  :streak_rewards, :variable, :seed

    def initialize
      @pool = 'all'
      @min_id = 1
      @max_id = 1025
      @list = []
      @exclude = []
      @choices = 4
      @tries = 1
      @mark_seen = true
      @rewards = []
      @money = 0
      @streak_every = 0
      @streak_rewards = []
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

  # Pokémon du jour et réponses proposées (toujours les mêmes pour un jour donné)
  # @return [Array(Symbol, Array<Symbol>)]
  def daily(day = today, cfg = config)
    list = pool(cfg)
    return [nil, []] if list.empty?

    seed = cfg[:seed].to_i
    answer = list[roll(day, seed) % list.size]
    count = cfg[:choices].to_i.clamp(2, 6)
    others = list - [answer]
    choices = [answer]
    salt = 1
    while choices.size < count && !others.empty?
      pick = others.delete_at(roll(day, seed, salt) % others.size)
      choices << pick
      salt += 1
    end
    # place de la bonne réponse
    choices.rotate!(roll(day, seed, 99) % choices.size)
    return [answer, choices]
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
