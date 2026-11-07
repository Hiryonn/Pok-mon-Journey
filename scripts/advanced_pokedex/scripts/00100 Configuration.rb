# Advanced Pokédex : pages « Taille » et « Poids » du Pokédex (comparaison avec des personnages)
#
# Dans la fiche d'un Pokémon du Pokédex : DROITE ouvre la page Taille, puis Poids.
#   Gauche / droite : changer de page (gauche sur Taille : retour à la fiche)
#   Haut / bas : Pokémon précédent / suivant      A : personnage suivant      B : retour
#
# Réglages : Data/configs/plugins/advanced_pokedex.json (édité dans Studio : Plugins > Advanced Pokédex)
# Graphismes : graphics/pokedex/advanced/
#   bg_height / bg_weight : fonds 320x240         title_height / title_weight : titres du cadre
#   tab_height / tab_weight : onglets (haut : inactif, bas : actif)   scale : balance (11 images de haut en bas)
module Configs
  # Contenu de Data/configs/plugins/advanced_pokedex.json
  class AdvancedPokedexConfig
    attr_accessor :characters, :labels, :require_caught, :silhouette_color,
                  :height_max, :height_base_y, :height_pokemon_x, :height_character_x,
                  :weight_scale_x, :weight_scale_y, :weight_icon_zoom, :weight_character_zoom, :pan_offset,
                  :show_titles, :show_tabs

    def initialize
      # personnages à comparer : name (vide = nom du joueur), player (sprite du joueur), height (m), weight (kg),
      # sprite (dans graphics/, ex. characters/npc_bucheron_02), cols / rows / frame (image de la planche)
      @characters = [{ 'name' => '', 'player' => true, 'height' => 1.55, 'weight' => 46.0, 'sprite' => '',
                       'cols' => 4, 'rows' => 4, 'frame' => 0 }]
      @labels = { 'height' => { 'fr' => 'Taille', 'en' => 'Height' }, 'weight' => { 'fr' => 'Poids', 'en' => 'Weight' } }
      @require_caught = true
      @silhouette_color = '#000000'
      @height_max = 104
      @height_base_y = 164
      @height_pokemon_x = 96
      @height_character_x = 222
      @weight_scale_x = 83
      @weight_scale_y = 92
      # zoom de l'icône du Pokémon et du personnage posés sur la balance (1 = taille réelle)
      @weight_icon_zoom = 1
      @weight_character_zoom = 1
      @pan_offset = 3
      @show_titles = true
      @show_tabs = true
    end
  end
  register(:advanced_pokedex, 'plugins/advanced_pokedex', :json, false, AdvancedPokedexConfig)
end

module AdvancedPokedex
  CONFIG_FILE = 'Data/configs/plugins/advanced_pokedex.json'
  # Dossier des graphismes (dans graphics/pokedex/)
  DIR = 'advanced/'
  # Plateaux de la balance pour chacune des 11 images : [[x, y] gauche, [x, y] droite] (haut du rebord)
  PANS = [[[22, 0], [130, 29]], [[22, 2], [130, 27]], [[20, 6], [132, 23]], [[20, 8], [132, 21]],
          [[20, 10], [132, 19]], [[20, 15], [132, 15]], [[22, 19], [132, 10]], [[22, 21], [132, 8]],
          [[22, 23], [132, 6]], [[22, 27], [132, 2]], [[22, 29], [132, 0]]].freeze
  SCALE_FRAMES = 11
  # Cadres de texte du bas [x, y, largeur] (zone blanche entre les bandes de couleur)
  BOXES = [[24, 179, 114], [182, 179, 114]].freeze
  # Onglets du bandeau [x, y]
  TABS = { height: [111, 1], weight: [166, 1] }.freeze
  # Titre du cadre : centre x, y
  TITLE = [160, 31].freeze

  module_function

  # @return [Configs::AdvancedPokedexConfig]
  def config
    @config ||= begin
      if PSDK_CONFIG.release? || File.exist?(CONFIG_FILE)
        Configs.advanced_pokedex
      else
        Configs::AdvancedPokedexConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Advanced Pokédex : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::AdvancedPokedexConfig.new
    end
  end

  # Valeur d'un réglage (valeur par défaut si absente du fichier)
  # @param key [Symbol]
  def get(key)
    value = config.send(key)
    return value.nil? ? Configs::AdvancedPokedexConfig.new.send(key) : value
  rescue StandardError
    return Configs::AdvancedPokedexConfig.new.send(key)
  end

  # @return [String] code de langue (fr, en…)
  def lang
    return ($options&.language || 'fr').to_s
  end

  # @param key [String] height ou weight
  # @return [String]
  def label(key)
    labels = get(:labels) || {}
    entry = labels[key] || labels[key.to_sym] || {}
    entry = entry.transform_keys(&:to_s)
    return entry[lang] || entry['en'] || entry.values.first || key.capitalize
  end

  # Personnages à comparer
  # @return [Array<Hash>] { name:, player:, height:, weight:, sprite:, cols:, rows:, frame: }
  def characters
    list = (get(:characters) || []).map { |c| c.transform_keys(&:to_sym) }
    list = Configs::AdvancedPokedexConfig.new.characters.map { |c| c.transform_keys(&:to_sym) } if list.empty?
    return list
  end

  # @param character [Hash]
  # @return [String]
  def character_name(character)
    name = character[:name].to_s
    return name unless name.empty? && character[:player]

    return PFM.game_state.trainer.name.to_s
  rescue StandardError
    return name.to_s
  end

  # Image d'un personnage
  # @param character [Hash]
  # @return [Texture, nil]
  def character_texture(character)
    path = character[:sprite].to_s
    path = player_sprite if path.empty? && character[:player]
    return nil if path.to_s.empty?

    folder, file = path.split('/', 2)
    return RPG::Cache.character(file) if folder == 'characters' && file
    return RPG::Cache.battler(file) if folder == 'battlers' && file

    return Texture.new("graphics/#{path}.png")
  rescue StandardError => e
    log_error("Advanced Pokédex : image #{path} introuvable (#{e.message})") if respond_to?(:log_error, true)
    return nil
  end

  # @return [String] planche de marche du joueur (characters/…)
  def player_sprite
    base = $game_player&.charset_base
    return "characters/#{base}_#{$game_switches[Yuki::Sw::Gender] ? 'f' : 'm'}_walk" if base

    name = $game_player&.character_name.to_s
    return name.empty? ? 'characters/player_m_walk' : "characters/#{name}"
  rescue StandardError
    return 'characters/player_m_walk'
  end

  # Rectangle de l'image choisie dans la planche
  # @param texture [Texture]
  # @param character [Hash]
  # @return [Array<Integer>] x, y, largeur, hauteur
  def character_rect(texture, character)
    cols = [character[:cols].to_i, 1].max
    rows = [character[:rows].to_i, 1].max
    frame = character[:frame].to_i.clamp(0, cols * rows - 1)
    w = texture.width / cols
    h = texture.height / rows
    return [(frame % cols) * w, (frame / cols) * h, w, h]
  end

  # Zone non transparente d'une image (gardée en cache)
  # @param texture [Texture]
  # @param rect [Array<Integer>, nil] partie de l'image
  # @return [Array<Integer>] x, y, largeur, hauteur (relatifs à rect)
  def bbox(texture, rect = nil)
    rect ||= [0, 0, texture.width, texture.height]
    @bboxes ||= {}
    key = [texture.object_id, *rect]
    return @bboxes[key] if @bboxes[key]

    image = Image.new(texture.to_png, true)
    x0, y0, w, h = rect
    min_x = w
    min_y = h
    max_x = max_y = -1
    h.times do |y|
      w.times do |x|
        next if image.get_pixel_alpha(x0 + x, y0 + y) == 0

        min_x = x if x < min_x
        max_x = x if x > max_x
        min_y = y if y < min_y
        max_y = y
      end
    end
    image.dispose
    return @bboxes[key] = (max_x < 0 ? [0, 0, w, h] : [min_x, min_y, max_x - min_x + 1, max_y - min_y + 1])
  rescue StandardError
    return [0, 0, rect[2], rect[3]]
  end

  # @param hex [String]
  # @return [Color]
  def color(hex)
    value = hex.to_s.delete('#')
    value = '000000' unless value.match?(/\A\h{6}\z/)
    return Color.new(value[0, 2].hex, value[2, 2].hex, value[4, 2].hex, 255)
  end

  # Vide les caches (réglages relus)
  def reload
    @config = nil
    @bboxes = nil
  end
end
