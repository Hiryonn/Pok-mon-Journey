# Carte de région (d'après « Arcky's Region Map » d'Arcky pour Essentials, refaite pour PSDK)
#
# Utilise les cartes du monde et les zones de Studio (image, grille des zones, nom, point de vol, météo, groupes
# sauvages). Réglages en plus faits dans Studio (Level design > Carte de région) : Data/configs/plugins/carte_region.json
#   settings        réglages généraux (thème, « ??? », zoom, souris, vol rapide, recherche, modes…)
#   regions         par carte du monde (clé = id) : theme, music { name, volume, pitch }, show_player, districts
#                   [{ name, x, y, w, h }], decorations [{ image, x, y, switch, above }], quests [{ quest, x, y, color }],
#                   trainers [{ name, character, x, y, switch, text }], connections [{ side, worldmap, offset }]
#   zones           par zone (clé = id) : description { fr, en }, image, switch (cachée tant qu'il est éteint),
#                   position { x, y } (point du lieu sur la carte)
#   fake_locations  [{ map_id, variable, value, worldmap, x, y }] : où montrer le joueur sur certaines cartes
module Configs
  class CarteRegionConfig
    attr_accessor :settings, :regions, :zones, :fake_locations

    def initialize
      @settings = {}
      @regions = {}
      @zones = {}
      @fake_locations = []
    end
  end
  register(:carte_region, 'plugins/carte_region', :json, false, CarteRegionConfig)
end

module CarteRegion
  CONFIG_FILE = 'Data/configs/plugins/carte_region.json'
  DIR = 'carte_region/'
  # Taille d'une case de la grille des cartes du monde de PSDK
  TILE = 8
  THEMES = %w[horizon rouge bleu vert sombre violet].freeze
  MODES = %i[normal fly quest berry roaming trainer].freeze
  MODE_NAMES = {
    normal: ['Carte', 'Map'], fly: ['Vol', 'Fly'], quest: ['Quêtes', 'Quests'], berry: ['Baies', 'Berries'],
    roaming: ['Pokémon errants', 'Roaming Pokémon'], trainer: ['Revanches', 'Rematches']
  }.freeze
  WEATHER_NAMES = %i[none rain sunny sandstorm hail fog hardsun hardrain strong_winds snow].freeze
  WEATHER_TEXT = {
    rain: %w[Pluie Rain], sunny: %w[Soleil Sunny], sandstorm: %w[Tempête\ de\ sable Sandstorm], hail: %w[Grêle Hail],
    fog: %w[Brouillard Fog], hardsun: ['Soleil intense', 'Harsh sun'], hardrain: ['Pluie battante', 'Heavy rain'],
    strong_winds: ['Vents forts', 'Strong winds'], snow: %w[Neige Snow]
  }.freeze
  # Types de rencontres (système de PSDK : terrain + outil)
  ENCOUNTER_TYPES = {
    'Grass' => %w[Herbes Grass], 'TallGrass' => ['Hautes herbes', 'Tall grass'], 'Cave' => %w[Grotte Cave],
    'Ocean' => %w[Surf Surfing], 'Pond' => ['Surf (étang)', 'Surfing (pond)'], 'Sand' => %w[Sable Sand],
    'Snow' => %w[Neige Snow], 'Mount' => %w[Montagne Mountain], 'HeadButt' => ['Coup d\'Boule', 'Headbutt'],
    'OldRod' => ['Canne', 'Old Rod'], 'GoodRod' => ['Super canne', 'Good Rod'], 'SuperRod' => ['Méga canne', 'Super Rod'],
    'RockSmash' => ['Éclate-Roc', 'Rock Smash']
  }.freeze
  DEFAULTS = {
    'replace_town_map' => true, 'theme' => 'horizon', 'theme_variable' => 0,
    'unvisited_text' => { 'fr' => '???', 'en' => '???' }, 'show_unvisited_names' => false,
    'mark_unvisited' => true, 'unvisited_color' => [0, 0, 0, 110],
    'highlight' => true, 'highlight_color' => [255, 255, 255, 90],
    'quick_fly' => true, 'fly_from_map' => true, 'fly_other_regions' => false, 'auto_cursor' => true,
    'max_choices' => 6, 'zoom' => true, 'mouse' => true,
    'search' => true, 'search_min' => 3, 'search_unvisited' => false,
    'preview' => true, 'preview_animation' => true, 'extended_preview' => true, 'max_description_lines' => 3,
    'weather_preview' => true, 'progress' => true, 'time_based' => true, 'music' => true, 'show_player' => true,
    'button_hints' => true, 'cursor_frames' => 5,
    'modes' => { 'fly' => true, 'quest' => true, 'berry' => true, 'roaming' => true, 'trainer' => true }
  }.freeze

  module_function

  # @return [Configs::CarteRegionConfig]
  def config
    @config ||= begin
      if PSDK_CONFIG.release?
        Configs.carte_region
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        cfg = Configs::CarteRegionConfig.new
        data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
        cfg
      else
        Configs::CarteRegionConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Carte de région : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::CarteRegionConfig.new
    end
  end

  def reload
    @config = nil
    @grids = nil
  end

  def fetch(hash, key)
    return nil unless hash.is_a?(Hash)

    value = hash[key.to_s]
    return value.nil? ? hash[key.to_sym] : value
  end

  # Réglage général (valeur par défaut si absent)
  def setting(key)
    value = fetch(config.settings, key)
    return value.nil? ? DEFAULTS[key.to_s] : value
  end

  def setting?(key)
    return setting(key) == true
  end

  def mode_enabled?(mode)
    return true if mode == :normal

    value = fetch(setting('modes'), mode)
    return value.nil? ? true : value == true
  end

  def french?
    return !($options && $options.language.to_s != 'fr')
  end

  def t(fr, en = fr)
    return french? ? fr : en
  end

  # Texte réglé dans Studio ({ fr:, en: } ou texte simple)
  def localized(value)
    return value.to_s unless value.is_a?(Hash)

    text = fetch(value, french? ? 'fr' : 'en')
    text = fetch(value, :fr) if text.to_s.empty?
    text = fetch(value, :en) if text.to_s.empty?
    return text.to_s
  end

  def pair(values)
    return t(values[0], values[1] || values[0])
  end

  def switch?(id)
    id = id.to_i
    return true if id <= 0

    return $game_switches[id] == true
  end

  # --- Thème ---------------------------------------------------------------------------------------
  # Thème de la région (sinon variable du thème, sinon thème général)
  def theme(worldmap_id = nil)
    name = fetch(region(worldmap_id), :theme).to_s if worldmap_id
    if name.to_s.empty? && (var = setting('theme_variable').to_i) > 0 && $game_variables
      index = $game_variables[var].to_i
      name = THEMES[index - 1] if index.between?(1, THEMES.size)
    end
    name = setting('theme').to_s if name.to_s.empty?
    name = 'horizon' unless RPG::Cache.interface_exist?("#{DIR}themes/#{name}/box")
    return name
  end

  def theme_file(theme, name)
    return "#{DIR}themes/#{theme}/#{name}"
  end

  # Barre du haut façon Horizon : nom de la région dans l'onglet du milieu
  def centered_header?(theme)
    return theme.to_s == 'horizon'
  end

  def theme_has?(theme, name)
    return RPG::Cache.interface_exist?(theme_file(theme, name))
  end

  def icon_file(name)
    return "#{DIR}icons/#{name}"
  end

  # --- Données de Studio ---------------------------------------------------------------------------
  def worldmap(id)
    return data_world_map(id.to_i)
  rescue StandardError
    return nil
  end

  def worldmap_ids
    return each_data_world_map.map(&:id)
  rescue StandardError
    return [0]
  end

  def region(worldmap_id)
    regions = config.regions
    return {} unless regions.is_a?(Hash)

    return fetch(regions, worldmap_id.to_s) || {}
  end

  def region_list(worldmap_id, key)
    return Array(fetch(region(worldmap_id), key)).select { |v| v.is_a?(Hash) }
  end

  def zone_settings(zone_id)
    zones = config.zones
    return {} unless zones.is_a?(Hash)

    return fetch(zones, zone_id.to_s) || {}
  end

  def zone(zone_id)
    return nil if zone_id.nil? || zone_id.to_i < 0

    data = data_zone(zone_id.to_i)
    return data&.db_symbol == :__undef__ ? nil : data
  rescue StandardError
    return nil
  end

  # Grille (tableau des id de zone par ligne)
  def grid(worldmap_id)
    return Array(worldmap(worldmap_id)&.grid)
  end

  def grid_size(worldmap_id)
    rows = grid(worldmap_id)
    return [rows.map(&:size).max.to_i, rows.size]
  end

  def zone_at(worldmap_id, x, y)
    id = grid(worldmap_id).dig(y, x)
    return id && id >= 0 ? id : nil
  end

  # Cases occupées par chaque zone : { zone_id => [[x, y], …] }
  def cells(worldmap_id)
    @grids ||= {}
    @grids[worldmap_id.to_i] ||= begin
      list = Hash.new { |h, k| h[k] = [] }
      grid(worldmap_id).each_with_index do |row, y|
        Array(row).each_with_index { |id, x| list[id] << [x, y] if id && id >= 0 }
      end
      list
    end
  end

  def zone_cells(worldmap_id, zone_id)
    return cells(worldmap_id).fetch(zone_id.to_i, [])
  end

  # Carte du monde où se trouve une zone (celle qui contient la zone dans sa grille)
  def worldmap_of_zone(zone_id, prefer = nil)
    return prefer if prefer && !zone_cells(prefer, zone_id).empty?

    data = zone(zone_id)
    first = data&.worldmaps&.first
    return first if first && !zone_cells(first, zone_id).empty?

    return worldmap_ids.find { |id| !zone_cells(id, zone_id).empty? } || first || prefer || 0
  end

  # Case d'ancrage d'une zone : position réglée dans Studio, sinon la case la plus proche du centre
  def anchor(worldmap_id, zone_id)
    data = zone(zone_id)
    list = zone_cells(worldmap_id, zone_id)
    # point réglé dans la page Carte de région (prioritaire)
    own = fetch(zone_settings(zone_id), :position)
    if own.is_a?(Hash) && list.include?([fetch(own, :x).to_i, fetch(own, :y).to_i])
      return [fetch(own, :x).to_i, fetch(own, :y).to_i]
    end
    if data&.position&.x && data.position.y && (list.empty? || list.include?([data.position.x, data.position.y]))
      return [data.position.x, data.position.y]
    end
    return nil if list.empty?

    cx = list.sum { |c| c[0] } / list.size.to_f
    cy = list.sum { |c| c[1] } / list.size.to_f
    return list.min_by { |c| (c[0] - cx)**2 + (c[1] - cy)**2 }
  end

  # --- Zones : nom, visite, description ------------------------------------------------------------
  def visited?(zone_id)
    return $env.visited_zone?(zone_id.to_i)
  rescue StandardError
    return false
  end

  def hidden?(zone_id)
    return !switch?(fetch(zone_settings(zone_id), :switch))
  end

  def real_name(zone_id)
    data = zone(zone_id)
    return '' unless data

    return PFM::Text.parse_string_for_messages(data.name)
  rescue StandardError
    return data.name.to_s
  end

  # Nom montré (« ??? » pour un lieu pas encore visité)
  def zone_name(zone_id)
    return '' if zone_id.nil? || hidden?(zone_id)
    return real_name(zone_id) if visited?(zone_id) || setting?('show_unvisited_names')

    return localized(setting('unvisited_text'))
  end

  def description(zone_id)
    return localized(fetch(zone_settings(zone_id), :description))
  end

  def zone_image(zone_id)
    image = fetch(zone_settings(zone_id), :image).to_s
    return nil if image.empty?

    file = "#{DIR}lieux/#{image.sub(/\.png\z/i, '')}"
    timed = "#{file}_#{time_suffix}"
    return timed if RPG::Cache.interface_exist?(timed)

    return RPG::Cache.interface_exist?(file) ? file : nil
  end

  # Variante de l'image selon l'heure (images <lieu>_matin, <lieu>_soir, <lieu>_nuit) : matin et journée, soirée, nuit
  def time_suffix
    return 'matin' unless $game_switches
    return 'nuit' if $game_switches[Yuki::Sw::TJN_NightTime]
    return 'soir' if $game_switches[Yuki::Sw::TJN_SunsetTime]

    return 'matin'
  end

  # Largeur de l'image du lieu dans l'aperçu (les grandes images sont réduites)
  PREVIEW_IMAGE_W = 96

  def preview_image_width(file)
    return 0 unless file

    width = RPG::Cache.interface(file).width
    return [width, PREVIEW_IMAGE_W].min
  rescue StandardError
    return 0
  end

  def weather(zone_id)
    id = zone(zone_id)&.forced_weather
    return nil unless id && id > 0

    return WEATHER_NAMES[id]
  end

  def weather_text(symbol)
    names = WEATHER_TEXT[symbol]
    return names ? pair(names) : symbol.to_s
  end

  # Quartier de la région sous une case
  def district(worldmap_id, x, y)
    found = region_list(worldmap_id, :districts).find do |d|
      dx = fetch(d, :x).to_i
      dy = fetch(d, :y).to_i
      x.between?(dx, dx + [fetch(d, :w).to_i, 1].max - 1) && y.between?(dy, dy + [fetch(d, :h).to_i, 1].max - 1)
    end
    return found ? localized(fetch(found, :name)) : ''
  end

  # Lieux voisins dans les 8 directions : [[direction, nom], …]
  DIRECTIONS = {
    [0, -1] => %w[Nord North], [1, -1] => ['Nord-est', 'North-east'], [1, 0] => %w[Est East],
    [1, 1] => ['Sud-est', 'South-east'], [0, 1] => %w[Sud South], [-1, 1] => ['Sud-ouest', 'South-west'],
    [-1, 0] => %w[Ouest West], [-1, -1] => ['Nord-ouest', 'North-west']
  }.freeze

  def neighbours(worldmap_id, zone_id)
    own = zone_cells(worldmap_id, zone_id)
    return [] if own.empty?

    cx = own.sum { |c| c[0] } / own.size.to_f
    cy = own.sum { |c| c[1] } / own.size.to_f
    found = {}
    own.each do |x, y|
      DIRECTIONS.each_key do |dx, dy|
        other = zone_at(worldmap_id, x + dx, y + dy)
        next if other.nil? || other == zone_id || found.key?(other) || hidden?(other)

        found[other] = true
      end
    end
    return found.keys.map do |other|
      oc = zone_cells(worldmap_id, other)
      ox = oc.sum { |c| c[0] } / oc.size.to_f - cx
      oy = oc.sum { |c| c[1] } / oc.size.to_f - cy
      angle = Math.atan2(oy, ox)
      step = ((angle / (Math::PI / 4)).round + 8) % 8
      dir = [[1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1]][step]
      [pair(DIRECTIONS[dir]), zone_name(other), step]
    end.sort_by { |d| (d[2] + 2) % 8 }
  end

  # --- Position du joueur --------------------------------------------------------------------------
  # @return [Array(Integer, Integer, Integer), nil] carte du monde, x, y
  def player_position
    if $game_map && (fake = fake_location)
      return fake
    end
    if (mod = $env.modified_worldmap_position)
      return [mod[2] || $env.get_worldmap, mod[0], mod[1]]
    end

    zone_id = $env.master_zone.to_i >= 0 ? $env.master_zone : $env.get_current_zone
    return nil if zone_id.nil? || zone_id < 0

    wm = worldmap_of_zone(zone_id, $env.get_worldmap)
    x, y = anchor(wm, zone_id)
    return nil unless x

    x, y = refine_position(wm, zone_id, x, y)
    return [wm, x, y]
  rescue StandardError
    return nil
  end

  # Sur une grande zone, place le joueur selon sa position sur la carte (comme « town_map_size »)
  def refine_position(worldmap_id, zone_id, x, y)
    list = zone_cells(worldmap_id, zone_id)
    return [x, y] if list.size < 2 || zone(zone_id)&.maps&.size.to_i > 1 || zone(zone_id)&.position&.x
    return [x, y] if fetch(zone_settings(zone_id), :position).is_a?(Hash)

    xs = list.map(&:first)
    ys = list.map(&:last)
    w = xs.max - xs.min + 1
    h = ys.max - ys.min + 1
    px = xs.min + ($game_player.x * w / [$game_map.width, 1].max)
    py = ys.min + ($game_player.y * h / [$game_map.height, 1].max)
    return list.include?([px, py]) ? [px, py] : [x, y]
  rescue StandardError
    return [x, y]
  end

  def fake_location
    Array(config.fake_locations).each do |f|
      next unless f.is_a?(Hash) && fetch(f, :map_id).to_i == $game_map.map_id

      var = fetch(f, :variable).to_i
      next if var > 0 && $game_variables[var].to_i != fetch(f, :value).to_i

      return [fetch(f, :worldmap).to_i, fetch(f, :x).to_i, fetch(f, :y).to_i]
    end
    return nil
  end

  # --- Vol -----------------------------------------------------------------------------------------
  def flyable?(zone_id)
    data = zone(zone_id)
    return false unless data&.warp&.x && data.warp.y
    return false if hidden?(zone_id)

    return visited?(zone_id) || $DEBUG == true
  end

  # Lieux où l'on peut voler sur une carte du monde : [[zone_id, x, y], …]
  def fly_spots(worldmap_id)
    return cells(worldmap_id).keys.select { |id| flyable?(id) }.filter_map do |id|
      x, y = anchor(worldmap_id, id)
      x ? [id, x, y] : nil
    end.sort_by { |id, _, _| real_name(id) }
  end

  # Un Pokémon de l'équipe connaît Vol et l'endroit le permet
  def can_fly_from_map?
    return false unless setting?('fly_from_map')
    return false unless $game_switches[Yuki::Sw::Env_CanFly]

    return $actors.any? { |pkmn| !pkmn.egg? && pkmn.skills_set.any? { |s| s && s.db_symbol == :fly } }
  rescue StandardError
    return false
  end

  # --- Quêtes, baies, errants, revanches -----------------------------------------------------------
  def quest_id(value)
    return value.to_i if value.is_a?(Integer) || value.to_s =~ /\A\d+\z/

    return data_quest(value.to_sym).id
  rescue StandardError
    return nil
  end

  def quest_state(id)
    return :finished if $quests.finished?(id)
    return :failed if $quests.failed?(id)
    return :active if $quests.active_quest(id)

    return :none
  rescue StandardError
    return :none
  end

  # Quêtes en cours placées sur la carte : [{ id:, x:, y:, color: }, …]
  def quest_markers(worldmap_id)
    return region_list(worldmap_id, :quests).filter_map do |q|
      id = quest_id(fetch(q, :quest))
      next unless id && quest_state(id) == :active

      { id: id, x: fetch(q, :x).to_i, y: fetch(q, :y).to_i, color: fetch(q, :color).to_s }
    end
  end

  def quest_name(id)
    return data_quest(id).name.to_s
  rescue StandardError
    return '?'
  end

  def quest_description(id)
    return data_quest(id).description.to_s
  rescue StandardError
    return ''
  end

  # Objectifs visibles : [[texte, fait?], …]
  def quest_goals(id)
    quest = $quests.active_quest(id) || $quests.finished_quest(id)
    return quest ? quest.objective_text_list : []
  rescue StandardError
    return []
  end

  # Baies plantées par zone : { zone_id => [{ berry:, stage:, watered: }, …] }
  def berries(worldmap_id)
    data = PFM.game_state.berries
    return {} unless data.is_a?(Hash)

    zones = cells(worldmap_id).keys
    result = Hash.new { |h, k| h[k] = [] }
    data.each do |map_id, events|
      zone_id = zones.find { |id| zone(id)&.maps&.include?(map_id) }
      next unless zone_id

      events.each_value do |b|
        next unless b.is_a?(Array) && b[0].to_i != 0

        result[zone_id] << { berry: b[0].to_i, stage: b[1].to_i, watered: b[4].to_i > 0 }
      end
    end
    return result
  rescue StandardError
    return {}
  end

  def berry_stage_text(stage)
    return [%w[Planté Planted], %w[Pousse Sprouting], ['En croissance', 'Growing'], %w[Fleurit Flowering],
            ['Prête !', 'Ready!']].fetch(stage.clamp(0, 4)).then { |p| pair(p) }
  end

  # Pokémon errants : [{ pokemon:, zone_id: }, …]
  def roamers(worldmap_id)
    list = $wild_battle.roaming_pokemons
    zones = cells(worldmap_id).keys
    return list.filter_map do |infos|
      zone_id = zones.find { |id| zone(id)&.maps&.include?(infos.map_id) }
      zone_id ? { pokemon: infos.pokemon, zone_id: zone_id, infos: infos } : nil
    end
  rescue StandardError
    return []
  end

  # Dresseurs prêts pour une revanche (interrupteur allumé)
  def trainer_markers(worldmap_id)
    return region_list(worldmap_id, :trainers).select { |tr| fetch(tr, :switch).to_i <= 0 || switch?(fetch(tr, :switch)) }
  end

  # --- Rencontres et progression -------------------------------------------------------------------
  # Rencontres d'une zone par type : [[libellé, [[db_symbol, form], …]], …]
  def encounters(zone_id)
    data = zone(zone_id)
    return [] unless data

    types = Hash.new { |h, k| h[k] = [] }
    Array(data.wild_groups).each do |sym|
      group = data_group(sym)
      next unless group

      key = group.tool ? group.tool.to_s : group.system_tag.to_s
      names = ENCOUNTER_TYPES[key] || [key, key]
      label = pair(names)
      group.encounters.each do |enc|
        entry = [enc.specie.to_sym, enc.form.to_i]
        types[label] << entry unless types[label].include?(entry)
      end
    end
    return types.to_a
  rescue StandardError
    return []
  end

  def species_seen?(sym)
    return $pokedex.creature_seen?(sym)
  rescue StandardError
    return false
  end

  def species_caught?(sym)
    return $pokedex.creature_caught?(sym)
  rescue StandardError
    return false
  end

  # Progression d'une région : [[libellé, fait, total], …]
  def progress(worldmap_id)
    zones = cells(worldmap_id).keys.reject { |id| hidden?(id) }
    lines = [[t('Lieux visités', 'Visited places'), zones.count { |id| visited?(id) }, zones.size]]
    species = zones.flat_map { |id| encounters(id).flat_map { |_, list| list.map(&:first) } }.uniq
    lines << [t('Pokémon capturés', 'Pokémon caught'), species.count { |s| species_caught?(s) }, species.size] unless species.empty?
    quests = region_list(worldmap_id, :quests).filter_map { |q| quest_id(fetch(q, :quest)) }.uniq
    lines << [t('Quêtes terminées', 'Quests completed'), quests.count { |id| quest_state(id) == :finished }, quests.size] unless quests.empty?
    return lines
  end

  def percent(done, total)
    return 100 if total <= 0

    return (done * 100 / total).clamp(0, 100)
  end

  # --- Musique -------------------------------------------------------------------------------------
  def music(worldmap_id)
    m = fetch(region(worldmap_id), :music)
    return nil unless m.is_a?(Hash) && !fetch(m, :name).to_s.empty?

    return [fetch(m, :name).to_s, (fetch(m, :volume) || 100).to_i, (fetch(m, :pitch) || 100).to_i]
  end

  # --- Choix mémorisés (le dernier choix de chaque liste) ------------------------------------------
  def last_choice(key)
    return (@last_choices ||= {}).fetch(key, 0)
  end

  def remember_choice(key, index)
    (@last_choices ||= {})[key] = index
  end
end
