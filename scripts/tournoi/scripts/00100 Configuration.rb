# Tournoi (d'après « Tournament Selection » de Neiro pour Essentials) : écran de sélection d'équipe façon Pokémon
# Champions et tournois à élimination directe contre les dresseurs de Studio.
#
# Écran de sélection : le joueur voit son équipe et celle de l'adversaire, et choisit les N Pokémon qui combattent
# (dans l'ordre) ; l'adversaire choisit les siens (au hasard, les premiers ou les plus forts). On peut voir le résumé
# des Pokémon, et selon les règles celui de l'équipe adverse (Droite), ses objets (ou « ? ») et changer de teinte.
# Tournoi : 2 à 16 participants (le joueur + des dresseurs de Studio, places vides = qualifiés d'office), tableau à
# élimination directe ; les autres matchs se jouent tout seuls (le plus fort a plus de chances). Avant chaque match du
# joueur : écran de sélection, puis combat. Récompenses selon la place (objets, argent), interrupteur / variable.
#
# Réglages : Data/configs/plugins/tournois.json (Studio : Level design > Dresseurs > Tournois)
#   settings     musique de la sélection et du tableau, teinte, vitesse de l'animation
#   tournaments  [{ id, name, participants (dresseurs de Studio), shuffle, rules, rewards, switch, variable, … }]
#   rules        pick (Pokémon à choisir), mode (1 : simple, 2 : double), max_level (0 : aucun), items (show, hide,
#                none), show_opponent, opponent_pick (random, first, strongest), bag, exp, heal, background, battle_bgm
# Commandes d'évènement : 00110 Commandes.rb
module Configs
  class TournoisConfig
    attr_accessor :settings, :tournaments, :towers

    def initialize
      @settings = {}
      @tournaments = []
      @towers = []
    end
  end
  register(:tournois, 'plugins/tournois', :json, false, TournoisConfig)
end

module Tournoi
  CONFIG_FILE = 'Data/configs/plugins/tournois.json'
  DIR = 'tournoi/'
  DEFAULTS = {
    'bgm' => 'tournoi_selection', 'bracket_bgm' => 'tournoi_selection', 'tone' => 'default', 'speed' => 1
  }.freeze
  RULE_DEFAULTS = {
    'pick' => 3, 'mode' => 1, 'max_level' => 0, 'items' => 'hide', 'show_opponent' => true, 'opponent_pick' => 'random',
    'bag' => true, 'exp' => false, 'heal' => true, 'cancel' => false, 'background' => '', 'battle_bgm' => ''
  }.freeze
  # Teintes du fond (comme dans le plugin d'origine : rouge, vert, bleu, gris)
  TONES = {
    'default' => [0, 0, 0, 0], 'red' => [75, -100, -100, 255], 'orange' => [80, 10, -80, 200],
    'yellow' => [100, 80, -50, 255], 'lime' => [40, 90, -110, 255], 'green' => [-100, 75, -80, 255],
    'cyan' => [-100, 60, 60, 255], 'blue' => [-50, 40, 160, 255], 'deep_blue' => [-100, -70, 100, 255],
    'purple' => [-50, -150, 50, 255], 'magenta' => [50, -100, 50, 255], 'grey' => [0, 0, 0, 255]
  }.freeze

  module_function

  # @return [Configs::TournoisConfig]
  def config
    @config ||= load_config
  end

  def load_config
    return Configs.tournois if PSDK_CONFIG.release?
    return Configs::TournoisConfig.new unless File.exist?(CONFIG_FILE)

    require 'json'
    data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
    cfg = Configs::TournoisConfig.new
    data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
    return cfg
  rescue StandardError, ScriptError => e
    log_error("Tournoi : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
    return Configs::TournoisConfig.new
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

  # @param id [Symbol, String]
  # @return [Hash, nil]
  def tournament(id)
    return Array(config.tournaments).find { |cup| fetch(cup, 'id').to_s == id.to_s }
  end

  # Règles complètes (celles de base, puis celles du tournoi, puis celles passées à la commande)
  # @param base [Hash, nil]
  # @param extra [Hash]
  # @return [Hash{String => Object}]
  def rules(base = nil, extra = {})
    out = RULE_DEFAULTS.dup
    (base || {}).each { |k, v| out[k.to_s] = v unless v.nil? }
    extra.each { |k, v| out[k.to_s] = v unless v.nil? }
    out['pick'] = out['pick'].to_i.clamp(1, 6)
    out['mode'] = out['mode'].to_i == 2 ? 2 : 1
    out['max_level'] = out['max_level'].to_i
    out['items'] = out['items'].to_s
    out['opponent_pick'] = out['opponent_pick'].to_s
    return out
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

  # @param name [String]
  # @return [String] image de graphics/interface
  def file(name)
    return "#{DIR}#{name}"
  end

  # Teinte [rouge, vert, bleu, gris]
  def tone(name = nil)
    return TONES[(name || setting('tone')).to_s] || TONES['default']
  end

  # Dresseur de Studio (n° ou symbole)
  # @return [Integer, Symbol, nil]
  def trainer_ref(value)
    return nil if value.nil? || value.to_s.empty?
    return value if value.is_a?(Integer)
    return value.to_i if value.to_s.match?(/\A\d+\z/)

    return value.to_s.to_sym
  end

  def trainer_exists?(value)
    ref = trainer_ref(value)
    return false unless ref

    return data_trainer(ref).db_symbol != :__undef__
  rescue StandardError
    return false
  end

  def trainer_name(value)
    ref = trainer_ref(value)
    trainer = data_trainer(ref)
    return [trainer.class_name, trainer.name].reject { |s| s.to_s.empty? }.join(' ')
  rescue StandardError
    return value.to_s
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

  # Résultats de la partie : { id => { 'played', 'won', 'best', 'last' } }
  # @return [Hash]
  def stats
    state = PFM.game_state
    return state.instance_variable_get(:@pj_tournois) || state.instance_variable_set(:@pj_tournois, {})
  end

  # @param id [String, Symbol]
  # @return [Hash]
  def record(id)
    return stats[id.to_s] ||= { 'played' => 0, 'won' => 0, 'best' => 0, 'last' => 0 }
  end

  # Soigne entièrement une équipe
  def heal(party)
    party.each do |pokemon|
      next if pokemon.respond_to?(:egg?) && pokemon.egg?

      pokemon.cure
      pokemon.hp = pokemon.max_hp
      pokemon.skills_set.each { |skill| skill.pp = skill.ppmax if skill.respond_to?(:ppmax) }
    end
  end

  # Le Pokémon peut combattre
  def able?(pokemon)
    return false unless pokemon
    return false if pokemon.respond_to?(:egg?) && pokemon.egg?

    return !pokemon.dead?
  end

  def play_bgm(name)
    return if name.to_s.empty?

    $game_system.bgm_play(RPG::AudioFile.new(name.to_s, 100, 100))
  rescue StandardError
    nil
  end
end
