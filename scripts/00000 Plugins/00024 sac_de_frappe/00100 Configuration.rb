# Sac de frappe (comme dans Pokémon X/Y ; d'après « Punch Bag Game » de FL pour Essentials, licence MIT-0)
#
# Le joueur choisit un Pokémon de son équipe, qui frappe un sac : une flèche file sur la jauge et A la fige.
# Plus elle est près du centre, plus le coup vaut d'étoiles (1 à 5) et plus le sac balance. Après N coups, si le score
# atteint le minimum, le Pokémon gagne des EV et/ou des IV dans les stats choisies.
#
# Réglages : Data/configs/plugins/sac_de_frappe.json
#   settings  rounds (coups par défaut), arrow_speed (vitesse de la flèche, pixels par seconde), can_cancel (B pour
#             arrêter), perfect_se (son d'un coup à 5 étoiles), hit_se ([faible, normal, fort]), bag (sac par défaut,
#             voir BAGS ; vide : le sac d'origine)
#   sessions  séances prêtes à l'emploi (sac_de_frappe_seance(:attaque)) :
#             { id, name, rounds, min_score, stats: [hp atk dfe spd ats dfs], ev, iv, max_iv, fainted, block_max, min_level,
#               bag }
# Commandes d'évènement : 00102 Commandes.rb. Graphismes : graphics/interface/sac_de_frappe/
module Configs
  class SacDeFrappeConfig
    attr_accessor :settings, :sessions

    def initialize
      @settings = {}
      @sessions = []
    end
  end
  register(:sac_de_frappe, 'plugins/sac_de_frappe', :json, false, SacDeFrappeConfig)
end

module SacDeFrappe
  CONFIG_FILE = 'Data/configs/plugins/sac_de_frappe.json'
  DIR = 'sac_de_frappe/'
  DEFAULTS = {
    'rounds' => 10, 'arrow_speed' => 320, 'can_cancel' => true, 'perfect_se' => 'audio/se/pokemove',
    'hit_se' => %w[audio/se/hitlow audio/se/hit audio/se/hitplus], 'bag' => ''
  }.freeze
  # Sacs du Super Training de X / Y (graphics/interface/sac_de_frappe/sacs/<id>, tools/sac_de_frappe/build_sacs.py)
  BAGS = {
    'gris' => %w[Sac\ gris Grey\ bag], 'rose' => %w[Sac\ rose Pink\ bag], 'team_flare' => %w[Sac\ Team\ Flare Team\ Flare\ bag],
    'jaune' => %w[Sac\ jaune Yellow\ bag], 'bleu' => %w[Sac\ bleu Blue\ bag], 'violet' => %w[Sac\ violet Purple\ bag],
    'vert' => %w[Sac\ vert Green\ bag], 'double' => %w[Sac\ ×2 Double-Up\ bag], 'noir' => %w[Sac\ noir Black\ bag]
  }.merge(
    { 'aquatique' => %w[aquatique Water], 'scarabee' => %w[scarabée Beetle], 'acier' => %w[acier Steel],
      'spectre' => %w[spectre Ghost], 'givre' => %w[givre Frost], 'plante' => %w[plante Plant] }.each_with_object({}) do |(id, (fr, en)), h|
      (1..3).each { |n| h["#{id}_#{n}"] = ["Sac #{fr} #{n}", "#{en} bag #{n}"] }
    end
  ).freeze
  STATS = %i[hp atk dfe spd ats dfs].freeze
  STAT_NAMES = {
    hp: %w[PV HP], atk: %w[Attaque Attack], dfe: %w[Défense Defense], spd: %w[Vitesse Speed],
    ats: ['Attaque Spé.', 'Sp. Atk'], dfs: ['Défense Spé.', 'Sp. Def']
  }.freeze
  MAX_IV = 31

  # Réglages d'une partie (comme PunchBag::Parameters d'Essentials)
  #   rounds     nombre de coups
  #   min_score  score à atteindre pour la récompense
  #   stats      stats concernées (:hp :atk :dfe :spd :ats :dfs)
  #   ev / iv    EV / IV gagnés dans chaque stat ; max_iv : IV mis à 31
  #   fainted    un Pokémon K.O. peut jouer ; block_max : refuse un Pokémon déjà au maximum ; min_level : niveau minimum
  #   can_cancel B arrête la partie
  class Parameters
    attr_accessor :rounds, :min_score, :stats, :ev, :iv, :max_iv, :fainted, :block_max, :min_level, :can_cancel, :name, :bag

    def initialize(rounds = nil, **options)
      @rounds = (rounds || SacDeFrappe.setting('rounds')).to_i.clamp(1, 99)
      @min_score = 0
      @stats = STATS.dup
      @ev = 0
      @iv = 0
      @max_iv = false
      @fainted = false
      @block_max = false
      @min_level = 0
      @can_cancel = SacDeFrappe.setting('can_cancel') ? true : false
      @name = nil
      @bag = SacDeFrappe.setting('bag').to_s
      options.each { |key, value| send(:"#{key}=", value) if respond_to?(:"#{key}=") }
      @stats = Array(@stats).map(&:to_sym) & STATS
    end

    def reward?
      return @ev.to_i > 0 || @iv.to_i > 0 || @max_iv
    end
  end

  module_function

  # @return [Configs::SacDeFrappeConfig]
  def config
    @config ||= begin
      if PSDK_CONFIG.release?
        Configs.sac_de_frappe
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        cfg = Configs::SacDeFrappeConfig.new
        data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
        cfg
      else
        Configs::SacDeFrappeConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Sac de frappe : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::SacDeFrappeConfig.new
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

  def t(fr, en = fr)
    return $options && $options.language.to_s != 'fr' ? en : fr
  end

  def stat_name(stat)
    pair = STAT_NAMES[stat.to_sym] || [stat.to_s, stat.to_s]
    return t(*pair)
  end

  def file(name)
    return DIR + name
  end

  # Image du sac (nil ou inconnu : le sac d'origine)
  def bag_file(bag)
    name = bag.to_s
    return file('bag') if name.empty? || !BAGS.key?(name)

    path = file("sacs/#{name}")
    return RPG::Cache.interface_exist?(path) ? path : file('bag')
  end

  def bag_name(bag)
    pair = BAGS[bag.to_s]
    return pair ? t(*pair) : t('Sac d’origine', 'Default bag')
  end

  # Séance réglée dans les réglages (sessions)
  # @return [Parameters, nil]
  def session(id)
    data = Array(config.sessions).find { |s| fetch(s, :id).to_s == id.to_s }
    return nil unless data

    options = {}
    %i[min_score stats ev iv max_iv fainted block_max min_level name bag].each do |key|
      value = fetch(data, key)
      options[key] = value unless value.nil?
    end
    return Parameters.new(fetch(data, :rounds), **options)
  end

  # --- Récompenses ------------------------------------------------------------------------------
  # EV qu'on peut encore ajouter dans une stat
  def ev_room(pokemon, stat)
    stat_room = Configs.stats.max_stat_ev - pokemon.send(:"ev_#{stat}")
    total_room = Configs.stats.max_total_ev - pokemon.total_ev
    return [[stat_room, total_room].min, 0].max
  end

  def raise_ev(pokemon, stat, value)
    added = [value.to_i, ev_room(pokemon, stat)].min
    return 0 if added <= 0

    pokemon.send(:"ev_#{stat}=", pokemon.send(:"ev_#{stat}") + added)
    return added
  end

  def raise_iv(pokemon, stat, value)
    added = [value.to_i, MAX_IV - pokemon.send(:"iv_#{stat}")].min
    return 0 if added <= 0

    pokemon.send(:"iv_#{stat}=", pokemon.send(:"iv_#{stat}") + added)
    return added
  end

  # Le Pokémon ne peut plus rien gagner (block_max)
  def maxed?(pokemon, param)
    return param.stats.none? do |stat|
      (param.ev.to_i > 0 && ev_room(pokemon, stat) > 0) ||
        ((param.iv.to_i > 0 || param.max_iv) && pokemon.send(:"iv_#{stat}") < MAX_IV)
    end
  end

  # Le Pokémon peut-il jouer ?
  # @return [String, nil] raison du refus
  def refusal(pokemon, param)
    return t("Un Œuf ne peut pas s'entraîner.", "An Egg can't train.") if pokemon.egg?
    return t("#{pokemon.given_name} est K.O.", "#{pokemon.given_name} has fainted.") if pokemon.dead? && !param.fainted
    if pokemon.level < param.min_level.to_i
      return t("Il faut un Pokémon de niveau #{param.min_level} ou plus.", "The Pokémon must be level #{param.min_level} or higher.")
    end
    if param.block_max && param.reward? && maxed?(pokemon, param)
      return t("#{pokemon.given_name} ne peut plus progresser ici.", "#{pokemon.given_name} can't improve any further here.")
    end

    return nil
  end

  # Donne la récompense et l'annonce
  # @return [Array<String>] messages
  def give_reward(pokemon, param)
    messages = []
    param.stats.each do |stat|
      raised = raise_ev(pokemon, stat, param.ev) > 0
      raised = true if raise_iv(pokemon, stat, param.max_iv ? MAX_IV : param.iv) > 0
      messages << t("#{pokemon.given_name} : #{stat_name(stat)} en hausse !", "#{pokemon.given_name}'s #{stat_name(stat)} increased!") if raised
    end
    pokemon.hp = pokemon.max_hp if pokemon.hp > pokemon.max_hp
    messages << t("#{pokemon.given_name} n'a rien pu gagner de plus.", "#{pokemon.given_name} couldn't gain anything more.") if messages.empty? && param.reward?
    return messages
  end
end
