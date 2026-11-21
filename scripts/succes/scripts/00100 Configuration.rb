# Succès : objectifs à débloquer, créés dans Studio (Level design > Interface > Succès), consultés dans l'appli Succès du téléphone
#
# Data/configs/plugins/succes.json (fait par Studio) :
#   notify        bandeau « Succès obtenu ! » quand un succès est débloqué
#   notify_me     musique jouée avec le bandeau (audio/me/…), vide = aucune
#   check_every   les conditions automatiques sont vérifiées toutes les N images sur la carte
#   categories    [{ id:, name: { fr:, en: } }]
#   achievements  [{ id:, name: { fr:, en: }, descr: { fr:, en: }, category:, points:, secret:,
#                    icon: { kind: trophy|item|pokemon, value: }, condition: { type:, target:, value: },
#                    rewards: { money:, items: [{ item:, quantity: }] } }]
# Conditions (type) :
#   manual          débloqué seulement par commande (succes_debloquer)
#   switch          interrupteur n° target activé
#   variable        variable n° target >= value
#   counter         compteur « target » >= value (succes_compteur(:nom, 1) dans un évènement)
#   dex_seen        Pokémon vus >= value          dex_caught    Pokémon capturés >= value
#   species         Pokémon « target » capturé    badges        badges >= value
#   money           argent >= value               item          objet « target » dans le sac (value exemplaires)
#   level           un Pokémon de l'équipe au niveau value
#   steps           pas >= value                  play_time     heures de jeu >= value
#   quests          quêtes terminées >= value      berries       baies du Berrydex trouvées >= value
#   achievements    autres succès obtenus >= value
module Configs
  class SuccesConfig
    attr_accessor :notify, :notify_me, :check_every, :categories, :achievements

    def initialize
      @notify = true
      @notify_me = 'audio/me/rosa_keyitemobtained'
      @check_every = 30
      @categories = []
      @achievements = []
    end
  end
  register(:succes, 'plugins/succes', :json, false, SuccesConfig)
end

module Succes
  CONFIG_FILE = 'Data/configs/plugins/succes.json'
  DIR = 'succes/'
  # Conditions avec une progression (valeur actuelle / valeur à atteindre)
  NUMERIC = %w[variable counter dex_seen dex_caught badges money item level steps play_time quests berries achievements].freeze

  module_function

  # @return [Configs::SuccesConfig]
  def config
    @config ||= begin
      if PSDK_CONFIG.release?
        Configs.succes
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        cfg = Configs::SuccesConfig.new
        data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
        cfg
      else
        Configs::SuccesConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Succès : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::SuccesConfig.new
    end
  end

  def reload
    @config = nil
    @by_id = nil
  end

  # Valeur d'un hash JSON (clés texte ou symboles)
  def fetch(hash, key)
    return nil unless hash.is_a?(Hash)

    value = hash[key.to_s]
    return value.nil? ? hash[key.to_sym] : value
  end

  # @return [Array<Hash>]
  def all
    return Array(config.achievements).select { |a| a.is_a?(Hash) && !fetch(a, :id).to_s.empty? }
  end

  # @return [Hash, nil]
  def get(id)
    @by_id ||= all.to_h { |a| [fetch(a, :id).to_s, a] }
    return @by_id[id.to_s]
  end

  # @return [Array<Hash>] catégories [{ id:, name: }]
  def categories
    return Array(config.categories).select { |c| c.is_a?(Hash) && !fetch(c, :id).to_s.empty? }
  end

  # Texte selon la langue
  def t(fr, en = fr)
    return $options && $options.language.to_s != 'fr' ? en : fr
  end

  # Texte réglé dans Studio ({ fr:, en: } ou texte simple)
  def localized(value)
    return value.to_s unless value.is_a?(Hash)

    text = fetch(value, $options&.language || 'fr')
    text = fetch(value, :fr) if text.to_s.empty?
    text = fetch(value, :en) if text.to_s.empty?
    return text.to_s
  end

  def name(achievement) = localized(fetch(achievement, :name))
  def descr(achievement) = localized(fetch(achievement, :descr))
  def secret?(achievement) = fetch(achievement, :secret) == true
  def points(achievement) = fetch(achievement, :points).to_i

  # @return [String]
  def category_name(id)
    category = categories.find { |c| fetch(c, :id).to_s == id.to_s }
    return category ? localized(fetch(category, :name)) : ''
  end

  # @return [String]
  def file(name)
    return "#{DIR}#{name}"
  end

  # --- Sauvegarde ------------------------------------------------------------------------
  # @return [Hash] { unlocked: { id => heure (secondes) }, counters: { nom => nombre } }
  def data
    return { unlocked: {}, counters: {} } unless $user_data

    data = $user_data[:pj_succes] ||= {}
    data[:unlocked] ||= {}
    data[:counters] ||= {}
    return data
  end

  def unlocked?(id)
    return data[:unlocked].key?(id.to_s)
  end

  # @return [Time, nil]
  def unlock_time(id)
    time = data[:unlocked][id.to_s]
    return time ? Time.at(time) : nil
  end

  # @return [Integer]
  def unlocked_count
    return all.count { |a| unlocked?(fetch(a, :id)) }
  end

  # @return [Integer]
  def total_points
    return all.sum { |a| unlocked?(fetch(a, :id)) ? points(a) : 0 }
  end

  # @return [Integer]
  def counter(name)
    return data[:counters][name.to_s].to_i
  end

  # Ajoute au compteur (et vérifie les succès qui en dépendent)
  def add_counter(name, amount = 1)
    data[:counters][name.to_s] = counter(name) + amount.to_i
    check_all
    return counter(name)
  end

  def set_counter(name, value)
    data[:counters][name.to_s] = value.to_i
    check_all
    return counter(name)
  end

  # --- Conditions --------------------------------------------------------------------------
  # @return [Hash] condition du succès
  def condition(achievement)
    return fetch(achievement, :condition) || {}
  end

  def condition_type(achievement)
    type = fetch(condition(achievement), :type).to_s
    return type.empty? ? 'manual' : type
  end

  # @return [Integer] valeur à atteindre
  def goal(achievement)
    value = fetch(condition(achievement), :value).to_i
    return condition_type(achievement) == 'level' ? value.clamp(1, 100) : [value, 1].max
  end

  # @return [Integer, nil] valeur actuelle (conditions avec une progression)
  def current(achievement)
    cond = condition(achievement)
    target = fetch(cond, :target)
    case condition_type(achievement)
    when 'variable' then $game_variables[target.to_i].to_i
    when 'counter' then counter(target)
    when 'dex_seen' then $pokedex.creature_seen.to_i
    when 'dex_caught' then $pokedex.creature_caught.to_i
    when 'badges' then $trainer.badge_counter.to_i
    when 'money' then PFM.game_state.money.to_i
    when 'item' then target.to_s.empty? ? 0 : $bag.item_quantity(target.to_sym).to_i
    when 'level' then Array($actors).map { |c| c.level.to_i }.max.to_i
    when 'steps' then PFM.game_state.steps.to_i
    when 'play_time' then $trainer.play_time.to_i / 3600
    when 'quests' then $quests.finished_quests.size
    when 'berries' then defined?(::Berrydex) ? ::Berrydex.found_count : 0
    when 'achievements' then all.count { |a| a != achievement && unlocked?(fetch(a, :id)) }
    end
  rescue StandardError
    return 0
  end

  # @return [Boolean] condition remplie
  def done?(achievement)
    cond = condition(achievement)
    case condition_type(achievement)
    when 'manual' then false
    when 'switch' then $game_switches[fetch(cond, :target).to_i] == true
    when 'species'
      target = fetch(cond, :target).to_s
      !target.empty? && $pokedex.creature_caught?(target.to_sym)
    else
      NUMERIC.include?(condition_type(achievement)) && current(achievement).to_i >= goal(achievement)
    end
  rescue StandardError
    return false
  end

  # @return [Array(Integer, Integer), nil] progression [actuel, but] (nil si pas de progression)
  def progress(achievement)
    return nil unless NUMERIC.include?(condition_type(achievement))

    max = goal(achievement)
    return [[current(achievement).to_i, max].min, max]
  end

  # Vérifie les succès automatiques
  def check_all
    return unless $user_data

    all.each { |a| unlock(fetch(a, :id)) if !unlocked?(fetch(a, :id)) && done?(a) }
  end

  # Débloque un succès (récompenses, bandeau)
  # @return [Boolean] true s'il vient d'être débloqué
  def unlock(id, notify: true)
    achievement = get(id)
    return false if !achievement || unlocked?(id)

    data[:unlocked][id.to_s] = Time.now.to_i
    give_rewards(achievement)
    Notification.push(achievement) if notify && config.notify != false
    # un succès peut en débloquer un autre (« obtenir N succès »)
    check_all
    return true
  end

  # Retire un succès (tests)
  def relock(id)
    data[:unlocked].delete(id.to_s)
  end

  # @return [Array<Array(Symbol, Integer)>] objets de la récompense
  def reward_items(achievement)
    items = Array(fetch(fetch(achievement, :rewards), :items))
    return items.filter_map do |entry|
      item = fetch(entry, :item).to_s
      next if item.empty?

      [item.to_sym, [fetch(entry, :quantity).to_i, 1].max]
    end
  end

  # @return [Integer]
  def reward_money(achievement)
    return fetch(fetch(achievement, :rewards), :money).to_i
  end

  def give_rewards(achievement)
    reward_items(achievement).each do |item, quantity|
      $bag.add_item(item, quantity) if data_item(item).db_symbol != :__undef__
    end
    PFM.game_state.add_money(reward_money(achievement)) if reward_money(achievement) > 0
  rescue StandardError => e
    log_error("Succès : récompense (#{e.message})") if respond_to?(:log_error, true)
  end

  # Texte de la récompense (« 500 P, Potion x2 »)
  # @return [String]
  def reward_text(achievement)
    parts = []
    parts << "#{reward_money(achievement)} P" if reward_money(achievement) > 0
    reward_items(achievement).each do |item, quantity|
      name = data_item(item).name
      parts << (quantity > 1 ? "#{name} x#{quantity}" : name)
    end
    return parts.join(', ')
  end

  # --- Icônes ------------------------------------------------------------------------------
  # Place l'icône d'un succès dans un sprite (centrée dans une case de 32 x 32 à x, y)
  # @param sprite [Sprite]
  def draw_icon(sprite, achievement, x, y)
    icon = fetch(achievement, :icon) || {}
    kind = fetch(icon, :kind).to_s
    value = fetch(icon, :value).to_s
    sprite.src_rect.set(0, 0, 0, 0) if sprite.bitmap
    case kind
    when 'item'
      sprite.set_bitmap(data_item(value.to_sym).icon, :icon)
    when 'pokemon'
      creature = data_creature(value.to_sym)
      sprite.set_bitmap(PFM::Pokemon.icon_filename(creature.id, 0, false, false, false), :b_icon)
    else
      metal = %w[bronze silver gold platinum].include?(value) ? value : 'gold'
      sprite.set_bitmap(file("trophy_#{metal}"), :interface)
    end
    w = sprite.bitmap.width
    h = sprite.bitmap.height
    w = h if kind == 'pokemon' && w > h # icônes des Pokémon en 2 images
    sprite.src_rect.set(0, 0, w, h)
    sprite.set_position(x + (32 - w) / 2, y + (32 - h) / 2)
    sprite.visible = true
  rescue StandardError
    sprite.set_bitmap(file('trophy_gold'), :interface)
    sprite.src_rect.set(0, 0, 32, 32)
    sprite.set_position(x, y)
    sprite.visible = true
  end
end
