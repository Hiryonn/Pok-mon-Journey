# encoding: utf-8
# Échange Miracle hors ligne : on envoie un Pokémon de l'équipe et on en reçoit un autre, tiré au hasard, d'un dresseur imaginaire.
#
# Le Pokémon reçu est choisi parmi les espèces dont le total de statistiques de base est proche de celui du Pokémon envoyé
# (power_window % d'écart) ; une fois sur luck_chance %, c'est un coup de chance : il vient d'une catégorie plus forte
# (luck_boost fois le total). Son niveau est celui du Pokémon envoyé, à level_spread près. Il peut être chromatique
# (shiny_chance %). Il a un autre dresseur d'origine (liste trainers) et on ne peut pas envoyer un Œuf ni son dernier
# Pokémon en état de se battre (keep_last).
# Réglages : Data/configs/plugins/echange_miracle.json
#   settings   level_spread, power_window, luck_chance, luck_boost, shiny_chance, min_id, max_id (0 : sans limite), exclude_groups
#              (groupes d'œuf exclus, 15 : Légendaires et bébés), exclude (espèces exclues), daily_limit (0 : sans limite),
#              keep_last, history_size
#   trainers   [{ name:, message: { fr:, en: } }] dresseurs imaginaires ; message : « %s » est le Pokémon reçu
# État : $user_data[:pj_wt] = { 'count', 'day', 'today', 'last', 'history' => [{ 'gave', 'got', 'trainer', 'level' }] }
# Commandes d'évènement : echange_miracle (renvoie true si un échange a eu lieu), echange_miracle_possible?,
#   echanges_miracle_nombre, echange_miracle_dernier (nom du dernier Pokémon reçu)
module Configs
  class EchangeMiracleConfig
    attr_accessor :settings, :trainers

    def initialize
      @settings = {}
      @trainers = []
    end
  end
  register(:echange_miracle, 'plugins/echange_miracle', :json, false, EchangeMiracleConfig)
end

module EchangeMiracle
  CONFIG_FILE = 'Data/configs/plugins/echange_miracle.json'
  DEFAULTS = {
    'level_spread' => 3, 'power_window' => 15, 'luck_chance' => 8, 'luck_boost' => 1.3, 'shiny_chance' => 0.4,
    'min_id' => 1, 'max_id' => 1025, 'exclude_groups' => [15], 'exclude' => [], 'daily_limit' => 0, 'keep_last' => true,
    'history_size' => 20
  }.freeze
  DEFAULT_TRAINERS = [
    { 'name' => 'Léa', 'message' => { 'fr' => 'Léa t’envoie %s !', 'en' => 'Léa sends you %s!' } },
    { 'name' => 'Marco', 'message' => { 'fr' => 'Marco t’envoie %s !', 'en' => 'Marco sends you %s!' } },
    { 'name' => 'Aïcha', 'message' => { 'fr' => 'Aïcha t’envoie %s !', 'en' => 'Aïcha sends you %s!' } },
    { 'name' => 'Yuki', 'message' => { 'fr' => 'Yuki t’envoie %s !', 'en' => 'Yuki sends you %s!' } }
  ].freeze

  module_function

  def config
    @config ||= begin
      if PSDK_CONFIG.release?
        Configs.echange_miracle
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        cfg = Configs::EchangeMiracleConfig.new
        data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
        cfg
      else
        Configs::EchangeMiracleConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Échange Miracle : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::EchangeMiracleConfig.new
    end
  end

  def reload
    @config = nil
    @pool = nil
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

  def localized(value)
    return value.to_s unless value.is_a?(Hash)

    return (fr? ? (value['fr'] || value[:fr]) : (value['en'] || value[:en])) || value['fr'] || value['en'] || value.values.first.to_s
  end

  # @return [Array<Hash>]
  def trainers
    list = Array(config.trainers).select { |entry| entry.is_a?(Hash) && !fetch(entry, 'name').to_s.empty? }
    return list.empty? ? DEFAULT_TRAINERS : list
  end

  # @return [Hash] état sauvegardé
  def state
    data = ($user_data ||= {})[:pj_wt] ||= {}
    data['count'] ||= 0
    data['today'] ||= 0
    data['history'] ||= []
    return data
  end
end
