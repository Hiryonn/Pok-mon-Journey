# Advanced Pokédex : tâches de recherche (comme le Pokédex de Légendes Arceus ; d'après « Pokedex Tasks » pour
# Essentials, de dewm3734)
#
# Chaque espèce a une liste de tâches (capturer, vaincre, voir utiliser une capacité…). Chaque tâche a des paliers
# (ex. 1, 3, 5, 8, 10) : chaque palier atteint donne 1 point de recherche ; la recherche est terminée à 10 points
# (réglage points_needed). Les tâches se font toutes seules en jouant :
#   capture         Pokémon capturés (ou obtenus, ou évolués en cette espèce)
#   capture_night   capturés la nuit
#   defeat          Pokémon vaincus en combat (K.O.)
#   defeat_type     vaincus par une capacité d'un type donné                 (cible : type, ex. fire)
#   move            vu utiliser une capacité (par lui ou un adversaire)     (cible : capacité, ex. vine_whip)
#   evolve          a évolué
#   item_win        combats gagnés en tenant un objet                       (cible : objet, ex. miracle_seed)
#   herd            capturés ou vaincus dans le troupeau du jour annoncé par le radar (plugin PokeSmart ; herd_task : false pour
#                   l'ôter des tâches automatiques)
# Sans liste réglée pour l'espèce (et avec auto_tasks), les tâches sont faites à partir de l'espèce : capturer, vaincre,
# voir utiliser une de ses capacités apprises par niveau, vaincre avec un type super efficace, évoluer (s'il évolue).
#
# Réglages : Data/configs/plugins/pokedex_tasks.json
#   settings    points_needed, auto_tasks
#   thresholds  paliers de chaque type de tâche ({ "capture": [1, 3, 5, 8, 10] }, 5 paliers au plus)
#   species     tâches réglées par espèce : { "bulbasaur": [["capture"], ["move", "vine_whip"], ["evolve"]] } ; un 3e
#               élément donne des paliers propres à la tâche : ["capture", null, [1, 2, 5]]
# Tout se règle dans Studio : Données > Pokédex > Tâches.
# Commandes d'évènement : tache_pokedex(:bulbasaur, :move, :vine_whip, 1) (avance une tâche), recherche_pokedex(:bulbasaur)
#   (points), recherche_terminee?(:bulbasaur), nombre_recherches_terminees
module Configs
  class PokedexTasksConfig
    attr_accessor :settings, :thresholds, :species, :rewards

    def initialize
      @settings = {}
      @thresholds = {}
      @species = {}
      @rewards = {}
    end
  end
  register(:pokedex_tasks, 'plugins/pokedex_tasks', :json, false, PokedexTasksConfig)
end

module AdvancedPokedex
  module Tasks
    CONFIG_FILE = 'Data/configs/plugins/pokedex_tasks.json'
    DEFAULTS = { 'points_needed' => 10, 'auto_tasks' => true, 'herd_task' => true }.freeze
    THRESHOLDS = {
      capture: [1, 3, 5, 8, 10], capture_night: [1, 3, 5, 8], defeat: [1, 3, 5, 8, 10], defeat_type: [1, 3, 5, 8, 10],
      move: [1, 3, 6, 10, 15], evolve: [1, 3, 5], item_win: [1, 5, 10, 15, 20], herd: [1, 3, 5]
    }.freeze
    # [français, anglais] ; %s : cible (capacité, type, objet)
    NAMES = {
      capture: ['Pokémon capturés', 'Number caught'], capture_night: ['Capturés la nuit', 'Caught at night'],
      defeat: ['Pokémon vaincus', 'Number defeated'], defeat_type: ['Vaincus avec une capacité %s', 'Defeated with %s-type moves'],
      move: ['Vu utiliser %s', 'Times you’ve seen it use %s'], evolve: ['Évolutions', 'Times evolved'],
      item_win: ['Victoires en tenant %s', 'Battles won holding %s'], herd: ['Pris dans un troupeau du jour', 'Caught or beaten in the daily herd']
    }.freeze
    # Types attaquants essayés pour la tâche automatique « vaincre avec un type »
    ATTACK_TYPES = %i[normal fire water grass electric ice fighting poison ground flying psychic bug rock ghost dragon dark
                      steel fairy].freeze

    # Une tâche d'une espèce
    Task = Struct.new(:type, :target, :thresholds) do
      # @return [String] clé de la progression
      def key
        return target ? "#{type}:#{target}" : type.to_s
      end
    end

    module_function

    # @return [Configs::PokedexTasksConfig]
    def config
      @config ||= begin
        if PSDK_CONFIG.release?
          Configs.pokedex_tasks
        elsif File.exist?(CONFIG_FILE)
          require 'json'
          data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
          cfg = Configs::PokedexTasksConfig.new
          data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
          cfg
        else
          Configs::PokedexTasksConfig.new
        end
      rescue StandardError, ScriptError => e
        log_error("Tâches du Pokédex : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
        Configs::PokedexTasksConfig.new
      end
    end

    def reload
      @config = nil
      @cache = {}
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

    # @param type [Symbol]
    # @return [Array<Integer>] paliers (5 au plus)
    def thresholds(type)
      list = Array(fetch(config.thresholds, type)).map(&:to_i).select(&:positive?)
      list = THRESHOLDS[type] || [1] if list.empty?
      return list.sort.first(5)
    end

    # --- Tâches d'une espèce ---------------------------------------------------------------------------
    # @param species [Symbol]
    # @return [Array<Task>]
    def tasks_for(species)
      species = species.to_sym
      (@cache ||= {})[species] ||= begin
        custom = fetch(config.species, species)
        list = if custom.is_a?(Array) && !custom.empty?
                 custom.map { |entry| Array(entry) }.map { |type, target, steps| make(type, target, steps) }
               elsif setting('auto_tasks')
                 auto_tasks(species)
               else
                 []
               end
        list.compact
      end
    end

    # @param steps [Array<Integer>, nil] paliers propres à cette tâche (sinon ceux du type)
    def make(type, target = nil, steps = nil)
      type = type.to_s.downcase.to_sym
      return nil unless THRESHOLDS.key?(type)

      target = target.to_s.empty? || target.to_s.casecmp?('none') ? nil : target.to_s.downcase.to_sym
      steps = Array(steps).map(&:to_i).select(&:positive?).uniq.sort.first(5)
      return Task.new(type, target, steps.empty? ? thresholds(type) : steps)
    end

    # Tâches faites à partir de l'espèce
    def auto_tasks(species)
      form = data_creature_form(species, 0)
      list = [make(:capture), make(:defeat)]
      move = signature_move(form)
      list << make(:move, move) if move
      type = weakness(form)
      list << make(:defeat_type, type) if type
      list << make(:evolve) if Array(form.evolutions).any? { |evo| !gemme?(evo) }
      list << make(:herd) if setting('herd_task')
      return list
    rescue StandardError
      return [make(:capture), make(:defeat)]
    end

    def gemme?(evolution)
      return Array(evolution.conditions).any? do |c|
        type = c.is_a?(Hash) ? (c[:type] || c['type']) : c.type
        type.to_s == 'gemme'
      end
    end

    # Capacité offensive apprise par niveau (la plus tardive avant le niveau 40)
    def signature_move(form)
      moves = Array(form.move_set).select(&:level_learnable?).sort_by(&:level)
      damaging = moves.select do |m|
        data = data_move(m.move)
        data.db_symbol != :__undef__ && data.power.to_i > 0
      end
      pick = damaging.select { |m| m.level.to_i <= 40 }.last || damaging.first || moves.last
      return pick&.move
    end

    # Type le plus efficace contre l'espèce
    def weakness(form)
      types = [form.type1, form.type2].compact.map(&:to_sym).reject { |t| t == :__undef__ }
      best = ATTACK_TYPES.map do |attack|
        factor = types.reduce(1.0) { |acc, defense| acc * data_type(attack).hit(defense).to_f }
        [attack, factor]
      end.max_by { |_, factor| factor }
      return best && best[1] > 1 ? best[0] : nil
    rescue StandardError
      return nil
    end

    # --- Progression -------------------------------------------------------------------------------------
    # @return [Hash{Symbol => Hash{String => Integer}}]
    def progress_data
      dex = PFM.game_state.pokedex
      return dex.instance_variable_get(:@pj_tasks) || dex.instance_variable_set(:@pj_tasks, {})
    end

    # @param species [Symbol]
    # @param task [Task]
    # @return [Integer]
    def progress(species, task)
      return progress_data.dig(species.to_sym, task.key).to_i
    end

    # Avance les tâches d'une espèce qui correspondent
    # @param species [Symbol, Integer]
    # @param type [Symbol]
    # @param target [Symbol, nil]
    # @param amount [Integer]
    def record(species, type, target = nil, amount = 1)
      return unless PFM.game_state&.pokedex

      species = species.is_a?(Integer) ? data_creature(species).db_symbol : species.to_sym
      return if species == :__undef__

      tasks_for(species).each do |task|
        next unless task.type == type.to_sym
        next if task.target && task.target != target&.to_sym

        store = (progress_data[species] ||= {})
        store[task.key] = (store[task.key].to_i + amount).clamp(0, task.thresholds.last)
      end
    rescue StandardError => e
      log_error("Tâches du Pokédex : #{e.message}") if respond_to?(:log_error, true)
    end

    # @return [Integer] points de recherche (paliers atteints)
    def points(species)
      return tasks_for(species).sum { |task| task.thresholds.count { |t| progress(species, task) >= t } }
    end

    def points_needed
      return [setting('points_needed').to_i, 1].max
    end

    def complete?(species)
      return points(species) >= points_needed
    end

    # @return [String] texte de la tâche
    def label(task)
      name = NAMES[task.type][fr? ? 0 : 1]
      return name unless name.include?('%s')

      return format(name, target_name(task))
    end

    def target_name(task)
      case task.type
      when :move then return data_move(task.target).name.to_s
      when :defeat_type then return data_type(task.target).name.to_s
      when :item_win then return data_item(task.target).name.to_s
      end
      return task.target.to_s
    rescue StandardError
      return task.target.to_s
    end
  end
end

# --- Suivi en jeu ----------------------------------------------------------------------------------------
module PFM
  class Pokedex
    module PokedexTasksCatch
      # Capture (aussi les Pokémon reçus et les évolutions, comme dans le plugin d'origine)
      def increase_creature_caught_count(db_symbol)
        super
        return unless enabled?

        species = resolve_db_symbol(db_symbol)
        ::AdvancedPokedex::Tasks.record(species, :capture)
        ::AdvancedPokedex::Tasks.record(species, :capture_night) if $env.respond_to?(:night?) && $env.night?
      end
    end
    prepend PokedexTasksCatch
  end

  class Pokemon
    module PokedexTasksEvolve
      def evolve(id, form)
        ::AdvancedPokedex::Tasks.record(db_symbol, :evolve) if $actors&.include?(self)
        super
      end
    end
    prepend PokedexTasksEvolve
  end
end

module Battle
  class Move
    # Capacité vue en combat
    module PokedexTasksMove
      def proceed(user, target_bank, target_position)
        ::AdvancedPokedex::Tasks.record(user.db_symbol, :move, db_symbol) if user.respond_to?(:db_symbol)
        super
      end
    end
    prepend PokedexTasksMove
  end

  class Logic
    class BattleEndHandler
      # Fin du combat : Pokémon vaincus (et par quel type), victoires en tenant un objet
      module PokedexTasksBattle
        private

        def handle_pokedex_update(players_creatures)
          super
          tasks = ::AdvancedPokedex::Tasks
          logic.all_battlers do |battler|
            next if battler.from_party? || battler.last_sent_turn == -1 || battler.alive?

            tasks.record(battler.db_symbol, :defeat)
            hit = battler.damage_history.last
            type = hit&.move ? data_move(hit.move.db_symbol).type : nil
            tasks.record(battler.db_symbol, :defeat_type, type) if type
          end
          return unless logic.battle_result == 0

          Array(players_creatures).each do |battler|
            next unless battler.alive? && battler.last_sent_turn != -1

            item = battler.item_db_symbol
            tasks.record(battler.db_symbol, :item_win, item) if item && item != :__undef__
          end
        rescue StandardError => e
          log_error("Tâches du Pokédex : #{e.message}") if respond_to?(:log_error, true)
        end
      end
      prepend PokedexTasksBattle
    end
  end
end

class Interpreter
  # Avance une tâche du Pokédex, ex. tache_pokedex(:bulbasaur, :move, :vine_whip, 1)
  def tache_pokedex(species, type, target = nil, amount = 1)
    AdvancedPokedex::Tasks.record(species, type, target, amount)
  end

  # @return [Integer] points de recherche de l'espèce
  def recherche_pokedex(species)
    return AdvancedPokedex::Tasks.points(species)
  end

  def recherche_terminee?(species)
    return AdvancedPokedex::Tasks.complete?(species)
  end

  # @return [Integer] espèces dont la recherche est terminée
  def nombre_recherches_terminees
    return AdvancedPokedex::Tasks.progress_data.keys.count { |species| AdvancedPokedex::Tasks.complete?(species) }
  end
end
