# encoding: utf-8
# Base secrète : une pièce à décorer
#
# La pièce est une grille de GRID_W x GRID_H cases. On y pose :
#   - des objets du sac, achetés dans les Magasins (l'objet quitte le sac tant qu'il est posé, et y revient quand on le retire) :
#       les objets dont le db_symbol commence par decor_prefix (« deco_ » par défaut) et ceux de la liste decor ;
#   - des trophées, qui ne coûtent rien et ne quittent jamais leur propriétaire :
#       un trophée par Succès obtenu (avec l'icône du succès) et un par Concours remporté par le joueur (le Pokémon gagnant).
# Réglages : Data/configs/plugins/base_secrete.json
#   settings   decor_prefix, trophies_achievements, trophies_contests, max_items (objets posés au plus, 0 : sans limite)
#   themes     [{ id:, name: { fr:, en: }, image: } ] fonds de pièce (graphics/interface/base_secrete/<image>.png)
#   decor      [{ item:, name: { fr:, en: } }] objets décoratifs en plus du préfixe (le nom ne sert que dans la pièce)
# État : $user_data[:pj_base] = { 'theme' => id, 'placed' => [{ 'kind' => item|ach|contest, 'id' =>, 'x' =>, 'y' => }] }
# Commandes d'évènement : base_secrete (ouvre la pièce), base_secrete_objets (nombre de décorations posées),
#   base_secrete_theme(:grotte), base_secrete_vider (range tout), base_secrete_trophees (nombre de trophées disponibles)
module Configs
  class BaseSecreteConfig
    attr_accessor :settings, :themes, :decor

    def initialize
      @settings = {}
      @themes = []
      @decor = []
    end
  end
  register(:base_secrete, 'plugins/base_secrete', :json, false, BaseSecreteConfig)
end

module BaseSecrete
  CONFIG_FILE = 'Data/configs/plugins/base_secrete.json'
  DIR = 'base_secrete/'
  GRID_W = 10
  GRID_H = 7
  CELL = 32
  TOP = 16
  DEFAULTS = {
    'decor_prefix' => 'deco_', 'trophies_achievements' => true, 'trophies_contests' => true, 'max_items' => 0
  }.freeze
  DEFAULT_THEMES = [
    { 'id' => 'bois', 'name' => { 'fr' => 'Cabane en bois', 'en' => 'Wooden hut' }, 'image' => 'fond_bois' },
    { 'id' => 'grotte', 'name' => { 'fr' => 'Grotte', 'en' => 'Cave' }, 'image' => 'fond_grotte' },
    { 'id' => 'jardin', 'name' => { 'fr' => 'Jardin', 'en' => 'Garden' }, 'image' => 'fond_jardin' }
  ].freeze

  module_function

  def config
    @config ||= begin
      if PSDK_CONFIG.release?
        Configs.base_secrete
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        cfg = Configs::BaseSecreteConfig.new
        data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
        cfg
      else
        Configs::BaseSecreteConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Base secrète : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::BaseSecreteConfig.new
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

  def localized(value)
    return value.to_s unless value.is_a?(Hash)

    text = fetch(value, fr? ? 'fr' : 'en')
    text = fetch(value, 'fr') if text.to_s.empty?
    return text.to_s
  end

  def file(name)
    return "#{DIR}#{name}"
  end

  # --- Thèmes -----------------------------------------------------------------------------------------------
  def themes
    list = Array(config.themes)
    return list.empty? ? DEFAULT_THEMES : list
  end

  def theme_index
    index = themes.index { |theme| fetch(theme, 'id').to_s == state['theme'].to_s }
    return index || 0
  end

  def theme
    return themes[theme_index]
  end

  def next_theme
    state['theme'] = fetch(themes[(theme_index + 1) % themes.size], 'id').to_s
  end

  def set_theme(id)
    return false unless themes.any? { |theme| fetch(theme, 'id').to_s == id.to_s }

    state['theme'] = id.to_s
    return true
  end

  # --- État ---------------------------------------------------------------------------------------------------
  # @return [Hash]
  def state
    data = $user_data[:pj_base] ||= {}
    data['placed'] ||= []
    data['theme'] ||= fetch(themes.first, 'id').to_s
    return data
  end

  # @return [Array<Hash>]
  def placed
    return state['placed']
  end

  def at(x, y)
    return placed.find { |entry| entry['x'] == x && entry['y'] == y }
  end

  # --- Décorations disponibles --------------------------------------------------------------------------------
  # @return [Array<Symbol>] objets décoratifs (préfixe ou liste)
  def decor_items
    prefix = setting('decor_prefix').to_s
    listed = Array(config.decor).map { |entry| fetch(entry, 'item').to_s.to_sym }
    items = $bag.respond_to?(:all_items) ? $bag.all_items : $bag.instance_variable_get(:@items)
    owned = (items.is_a?(Hash) ? items.keys : Array(items)).map { |item| item.respond_to?(:db_symbol) ? item.db_symbol : item.to_s.to_sym }
    from_prefix = prefix.empty? ? [] : owned.select { |sym| sym.to_s.start_with?(prefix) }
    return (listed + from_prefix).uniq.reject { |sym| sym == :__undef__ || sym.to_s.empty? }
  end

  def item_name(symbol)
    entry = Array(config.decor).find { |e| fetch(e, 'item').to_s == symbol.to_s }
    custom = entry ? localized(fetch(entry, 'name')) : ''
    return custom unless custom.empty?

    return data_item(symbol).name.to_s
  rescue StandardError
    return symbol.to_s
  end

  def item_count(symbol)
    return $bag.item_quantity(symbol).to_i
  rescue StandardError
    return 0
  end

  # @return [Array<Hash>] trophées possibles : { 'kind', 'id', 'name' }
  def trophies
    list = []
    if setting('trophies_achievements') && defined?(::Succes)
      ::Succes.all.each do |achievement|
        id = ::Succes.fetch(achievement, :id)
        list << { 'kind' => 'ach', 'id' => id.to_s, 'name' => ::Succes.name(achievement) } if ::Succes.unlocked?(id)
      end
    end
    if setting('trophies_contests') && defined?(::Concours)
      ::Concours.type_ids.each do |type|
        ::Concours.rank_ids.each do |rank|
          record = ::Concours.winner(type, rank)
          next unless record && record['player']

          list << { 'kind' => 'contest', 'id' => "#{type}_#{rank}", 'name' => ::Concours.contest_name(type, rank) }
        end
      end
    end
    return list
  rescue StandardError => e
    log_error("Base secrète : trophées (#{e.message})") if respond_to?(:log_error, true)
    return []
  end

  def trophy_available?(kind, id)
    return trophies.any? { |trophy| trophy['kind'] == kind && trophy['id'] == id.to_s }
  end

  # Ce qu'on peut poser : objets du sac pas encore tous posés, trophées pas encore posés
  # @return [Array<Hash>] { 'kind', 'id', 'name', 'count' }
  def choices
    list = decor_items.filter_map do |symbol|
      count = item_count(symbol)
      { 'kind' => 'item', 'id' => symbol.to_s, 'name' => item_name(symbol), 'count' => count } if count > 0
    end
    trophies.each do |trophy|
      next if placed.any? { |entry| entry['kind'] == trophy['kind'] && entry['id'] == trophy['id'] }

      list << trophy.merge('count' => 1)
    end
    return list
  end

  def items_placed
    return placed.count { |entry| entry['kind'] == 'item' }
  end

  def full?
    limit = setting('max_items').to_i
    return limit > 0 && items_placed >= limit
  end

  # @return [Boolean] posé (l'objet quitte le sac)
  def place(choice, x, y)
    return false if at(x, y) || !x.between?(0, GRID_W - 1) || !y.between?(0, GRID_H - 1)

    if choice['kind'] == 'item'
      return false if full? || item_count(choice['id'].to_sym) < 1

      $bag.remove_item(choice['id'].to_sym, 1)
    end
    placed << { 'kind' => choice['kind'], 'id' => choice['id'], 'x' => x, 'y' => y }
    return true
  end

  # @return [Boolean] retiré (l'objet revient dans le sac)
  def remove(x, y)
    entry = at(x, y)
    return false unless entry

    $bag.add_item(entry['id'].to_sym, 1) if entry['kind'] == 'item'
    placed.delete(entry)
    return true
  end

  def clear
    placed.dup.each { |entry| remove(entry['x'], entry['y']) }
  end
end
