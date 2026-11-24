# encoding: utf-8
# Météo et saisons
#
# SAISONS (spring, summer, autumn, winter) : season_mode
#   calendar  d'après la date de l'ordinateur (mars-mai printemps, juin-août été, sept.-nov. automne, déc.-fév. hiver ;
#             southern : saisons inversées)        variable  variable n° season_variable (0 printemps … 3 hiver)
#   manual    fixée par la commande saison_fixer(:winter)       days  une saison tous les season_days jours réels
# MÉTÉO PAR ZONE : à l'arrivée dans une zone, puis toutes les change_hours heures réelles, la météo de la carte est tirée
#   dans le tableau forecast (zone vide : toutes les zones ; saison vide : toutes les saisons ; météo : none, rain, sunny, sandstorm,
#   hail, fog, hardsun, hardrain, strong_winds, snow, et même shadow_sky : le combat commence alors sous le Ciel Obscur).
#   Sans tableau (liste vide), des valeurs par défaut s'appliquent. all_zones : false = seules les zones citées dans le tableau
#   ont une météo changeante ; respect_forced : la météo imposée par la zone dans Studio est respectée ;
#   excluded_maps : numéros de cartes (intérieurs) sans météo changeante.
# APPARITIONS (plugin Pokémon visibles) : la chance qu'une espèce apparaisse est multipliée selon la météo et la saison :
#   type_weights    [{ on: weather|season, key:, type:, percent: }]    (liste vide : valeurs par défaut : pluie -> Eau, etc.)
#   species_weights [{ on: weather|season, key:, species:, percent: }]
# BAIES (champs de baies du Berrydex) : season_growth { spring: 100, … } (% du temps de pousse), berry_seasons
#   [{ berry:, season: }] : dans sa saison une baie pousse en berry_in_season % du temps (et donne 1 baie de plus), hors saison en
#   berry_out_season %.
# Commandes : saison, saison_fixer(:summer), meteo_zone, meteo_actualiser, meteo_zone_symbole
module Configs
  class MeteoSaisonsConfig
    attr_accessor :settings, :forecast, :type_weights, :species_weights, :berry_seasons

    def initialize
      @settings = {}
      @forecast = []
      @type_weights = []
      @species_weights = []
      @berry_seasons = []
    end
  end
  register(:meteo_saisons, 'plugins/meteo_saisons', :json, false, MeteoSaisonsConfig)
end

module MeteoSaisons
  CONFIG_FILE = 'Data/configs/plugins/meteo_saisons.json'
  SEASONS = %w[spring summer autumn winter].freeze
  SEASON_NAMES = { 'spring' => %w[Printemps Spring], 'summer' => %w[Été Summer], 'autumn' => %w[Automne Autumn],
                   'winter' => %w[Hiver Winter] }.freeze
  WEATHER_NAMES = { 'none' => ['Ciel dégagé', 'Clear sky'], 'rain' => %w[Pluie Rain], 'sunny' => %w[Soleil Sunny],
                    'sandstorm' => ['Tempête de sable', 'Sandstorm'], 'hail' => %w[Grêle Hail], 'fog' => %w[Brouillard Fog],
                    'hardsun' => ['Soleil ardent', 'Harsh sunlight'], 'hardrain' => ['Pluie battante', 'Heavy rain'],
                    'strong_winds' => ['Vents forts', 'Strong winds'], 'snow' => %w[Neige Snow],
                    'shadow_sky' => ['Ciel Obscur', 'Shadow sky'] }.freeze
  # Météos qui ne restent pas sur la carte après un combat (PSDK) : posées en direct
  DIRECT = %w[shadow_sky acid_rain].freeze
  DEFAULTS = {
    'season_mode' => 'calendar', 'season_variable' => 0, 'southern' => false, 'season_days' => 7, 'change_hours' => 6,
    'all_zones' => false, 'respect_forced' => true, 'notify' => true, 'spawn_effects' => true, 'berry_effects' => true,
    'berry_in_season' => 80, 'berry_out_season' => 120, 'season_growth' => { 'spring' => 100, 'summer' => 100, 'autumn' => 100, 'winter' => 120 },
    'excluded_maps' => []
  }.freeze
  DEFAULT_FORECAST = [
    ['spring', 'none', 40], ['spring', 'rain', 35], ['spring', 'sunny', 15], ['spring', 'fog', 10],
    ['summer', 'sunny', 45], ['summer', 'none', 30], ['summer', 'rain', 15], ['summer', 'hardsun', 10],
    ['autumn', 'none', 30], ['autumn', 'rain', 30], ['autumn', 'fog', 25], ['autumn', 'strong_winds', 15],
    ['winter', 'snow', 35], ['winter', 'none', 35], ['winter', 'hail', 10], ['winter', 'fog', 20]
  ].freeze
  # [on, key, type, %]
  DEFAULT_TYPE_WEIGHTS = [
    ['weather', 'rain', 'water', 200], ['weather', 'rain', 'electric', 150], ['weather', 'rain', 'bug', 120], ['weather', 'rain', 'fire', 60],
    ['weather', 'hardrain', 'water', 250], ['weather', 'sunny', 'fire', 200], ['weather', 'sunny', 'grass', 150], ['weather', 'hardsun', 'fire', 250],
    ['weather', 'sandstorm', 'rock', 200], ['weather', 'sandstorm', 'ground', 200], ['weather', 'sandstorm', 'steel', 150],
    ['weather', 'hail', 'ice', 250], ['weather', 'snow', 'ice', 250], ['weather', 'fog', 'ghost', 200], ['weather', 'fog', 'fairy', 150],
    ['weather', 'fog', 'psychic', 150], ['weather', 'strong_winds', 'flying', 200], ['weather', 'shadow_sky', 'dark', 250],
    ['weather', 'shadow_sky', 'ghost', 200],
    ['season', 'spring', 'grass', 150], ['season', 'spring', 'bug', 150], ['season', 'spring', 'fairy', 130],
    ['season', 'summer', 'fire', 150], ['season', 'summer', 'water', 130], ['season', 'summer', 'bug', 130],
    ['season', 'autumn', 'grass', 120], ['season', 'autumn', 'dark', 130], ['season', 'autumn', 'ghost', 130],
    ['season', 'winter', 'ice', 200], ['season', 'winter', 'bug', 50], ['season', 'winter', 'grass', 60]
  ].freeze

  module_function

  def config
    @config ||= begin
      if PSDK_CONFIG.release?
        Configs.meteo_saisons
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        cfg = Configs::MeteoSaisonsConfig.new
        data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
        cfg
      else
        Configs::MeteoSaisonsConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Météo et saisons : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::MeteoSaisonsConfig.new
    end
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
    return value.nil? ? DEFAULTS[key.to_s] : value
  end

  def fr?
    return $options.nil? || $options.language.to_s == 'fr'
  end

  def t(fr, en = fr)
    return fr? ? fr : en
  end

  def state
    return $user_data[:pj_saisons] ||= {}
  end

  # --- Saisons ---------------------------------------------------------------------------------------------------
  # @return [String] spring, summer, autumn ou winter
  def season
    index = case setting('season_mode').to_s
            when 'variable' then $game_variables[setting('season_variable').to_i].to_i % 4
            when 'manual' then SEASONS.index(state['season'].to_s) || 0
            when 'days' then (Time.now.to_i / 86_400 / [setting('season_days').to_i, 1].max) % 4
            else calendar_season
            end
    index = (index + 2) % 4 if setting('southern') && setting('season_mode').to_s != 'manual'
    return SEASONS[index]
  rescue StandardError
    return SEASONS[0]
  end

  def calendar_season
    month = Time.now.month
    return 3 if month == 12 || month <= 2
    return 0 if month <= 5
    return 1 if month <= 8

    return 2
  end

  def set_season(name)
    name = name.to_s
    return false unless SEASONS.include?(name)

    state['season'] = name
    return true
  end

  def season_name(season = self.season)
    return SEASON_NAMES[season][fr? ? 0 : 1]
  end

  def weather_name(symbol)
    names = WEATHER_NAMES[symbol.to_s]
    return names ? names[fr? ? 0 : 1] : symbol.to_s
  end

  # --- Météo de l'environnement ------------------------------------------------------------------------------
  # @return [String] météo de la carte (db_symbol)
  def current_weather
    return $env.current_weather_db_symbol.to_s
  rescue StandardError
    return 'none'
  end

  # @param symbol [String, Symbol]
  def apply_weather(symbol)
    symbol = symbol.to_s
    index = PFM::Environment::WEATHER_NAMES.index(symbol.to_sym)
    return false unless index

    if DIRECT.include?(symbol)
      $env.instance_variable_set(:@weather, index)
    else
      $env.apply_weather(index, 9_999_999)
    end
    return true
  rescue StandardError => e
    log_error("Météo et saisons : #{e.message}") if respond_to?(:log_error, true)
    return false
  end
end
