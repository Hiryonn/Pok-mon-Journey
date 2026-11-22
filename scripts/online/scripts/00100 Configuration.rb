# encoding: utf-8
# Jeu en ligne — étape 1 : échanges et défis d'équipe entre joueurs.
#
# Deux modes de connexion (au choix du joueur) :
#   - Serveur : un petit serveur relais (tools/online-server/server.js) que tu héberges ; salons à code de 5 lettres.
#   - Direct  : un joueur « héberge » (port direct_port), l'autre se connecte avec son adresse IP ; sans serveur.
# Réglages : Data/configs/plugins/online.json
#   settings   enabled, server_host (vide : mode serveur masqué), server_port, server_tls (chiffrement : le serveur doit être lancé avec un certificat), direct_port, nickname (vide : nom du joueur),
#              connect_timeout (s), idle_timeout (s),
#              ghosts (amis visibles sur la carte), ghosts_default (visible par défaut), ghost_slots (amis affichés au plus par carte)
#   trade      max_level, banned (espèces refusées), allow_eggs, keep_last (garder un Pokémon en état de se battre)
#   duel       team_size (1-6), level_cap (0 : aucun ; sinon les niveaux sont ramenés à cette valeur dans le défi), banned
# État : $user_data[:pj_online] = { 'id', 'token' (compte serveur), 'trades', 'duels' => { 'won', 'lost' }, 'log' => [] }
# Commandes d'évènement : online_echange, online_defi, online_disponible?, online_echanges_nombre, online_defis_gagnes
# Le protocole est décrit dans tools/online-server/PROTOCOLE.md
module Configs
  class OnlineConfig
    attr_accessor :settings, :trade, :duel

    def initialize
      @settings = {}
      @trade = {}
      @duel = {}
    end
  end
  register(:online, 'plugins/online', :json, false, OnlineConfig)
end

module Online
  CONFIG_FILE = 'Data/configs/plugins/online.json'
  PROTOCOL = 1
  MAX_LINE = 64 * 1024
  DEFAULTS = {
    'enabled' => true, 'server_host' => '', 'server_port' => 7777, 'server_tls' => false, 'direct_port' => 7778, 'nickname' => '',
    'connect_timeout' => 6, 'idle_timeout' => 60, 'ghosts' => false, 'ghosts_default' => false, 'ghost_slots' => 8
  }.freeze
  TRADE_DEFAULTS = { 'max_level' => 100, 'banned' => [], 'allow_eggs' => false, 'keep_last' => true }.freeze
  DUEL_DEFAULTS = { 'team_size' => 3, 'level_cap' => 50, 'banned' => [] }.freeze

  module_function

  def config
    @config ||= begin
      if defined?(PSDK_CONFIG) && PSDK_CONFIG.release?
        Configs.online
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        cfg = Configs::OnlineConfig.new
        data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
        cfg
      else
        Configs::OnlineConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("En ligne : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::OnlineConfig.new
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

  def trade_setting(key)
    value = fetch(config.trade, key)
    return value.nil? ? TRADE_DEFAULTS[key.to_s] : value
  end

  BATTLER_NAME = /\A[A-Za-z0-9_\- ]{1,40}\z/.freeze

  # @return [String] nom du sprite de combat (dresseur) du joueur local, envoyé à l'adversaire
  def my_battler
    name = ::Battle::Logic::BattleInfo.new.player_basic_info[3].to_s
    return name =~ BATTLER_NAME ? name : ''
  rescue StandardError
    return ''
  end

  # @param name [Object] nom reçu d'un autre joueur
  # @return [String] le nom s'il est sûr et si l'image existe chez nous, sinon ''
  def peer_battler_name(name)
    name = name.to_s
    return '' unless name =~ BATTLER_NAME

    RPG::Cache.battler(name)
    return name
  rescue StandardError
    return ''
  end

  # @param peer_name [Object] sprite de combat de l'adversaire
  # @param own [String] sprite local par défaut
  def opponent_battler(peer_name, own)
    forced = duel_setting('battler').to_s
    return forced unless forced.empty?

    found = peer_battler_name(peer_name)
    return found.empty? ? own : found
  end

  def duel_setting(key)
    value = fetch(config.duel, key)
    return value.nil? ? DUEL_DEFAULTS[key.to_s] : value
  end

  def enabled?
    return setting('enabled') != false
  end

  def server?
    return !setting('server_host').to_s.strip.empty?
  end

  def fr?
    return !defined?($options) || $options.nil? || $options.language.to_s == 'fr'
  end

  def t(fr, en = fr)
    return fr? ? fr : en
  end

  # @return [String] pseudo envoyé aux autres joueurs
  def nickname
    name = setting('nickname').to_s.strip
    name = $trainer.name.to_s if name.empty? && defined?($trainer) && $trainer.respond_to?(:name)
    name = 'Dresseur' if name.empty?
    return name.gsub(/[\u0000-\u001f\u007f<>]/, '')[0, 16]
  end

  # @return [Hash] état sauvegardé
  def state
    data = (($user_data ||= {})[:pj_online] ||= {})
    data['trades'] ||= 0
    data['duels'] ||= { 'won' => 0, 'lost' => 0 }
    data['log'] ||= []
    return data
  end

  def add_log(text)
    list = state['log']
    list.unshift("#{Time.now.strftime('%Y-%m-%d %H:%M')} #{text}")
    list.pop while list.size > 30
  end
end
