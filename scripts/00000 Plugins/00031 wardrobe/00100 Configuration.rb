# Wardrobe : tenues préfaites pour le héros
#
# Une tenue est un OBJET du sac (créé dans Studio) auquel on associe ci-dessous des pièces du générateur de personnages
# (haut, bas, chapeau, sac, coiffure + couleurs). Le joueur la porte depuis l'onglet « Tenues » du sac (A) ou depuis la salle
# d'essayage (commande ouvrir_wardrobe). Pas de personnalisation : la tenue remplace simplement les pièces indiquées, le reste du
# personnage (genre, peau, pièces non citées) ne change pas. Il peut toujours revenir à son apparence d'origine (« Ma tenue »).
#
# Pour ajouter une tenue :
#   1. Studio : créer un objet (ex. dbSymbol « tenue_sport »), le plus simple est de le mettre dans les objets rares.
#   2. L'ajouter dans la page Studio « Plugins > Tenues » (écrit Data/configs/plugins/wardrobe.json), ou à OUTFITS ci-dessous :
#      l'objet devient une tenue. Si les deux définissent le même objet, c'est le fichier JSON qui gagne.
#   3. Le donner au joueur (donner_tenue(:tenue_sport), ou un objet trouvé / acheté / reçu comme n'importe quel autre).
# Astuce : habille le héros avec le générateur, puis lance tenue_actuelle_en_texte (commande Script) : la ligne à copier est écrite
# dans la console (et renvoyée).
module Configs
  # Contenu de Data/configs/plugins/wardrobe.json (écrit par la page Studio « Tenues »)
  class WardrobeConfig
    attr_accessor :outfits

    def initialize
      @outfits = []
    end
  end
  register(:wardrobe, 'plugins/wardrobe', :json, false, WardrobeConfig)
end

module Wardrobe
  extend self

  CONFIG_FILE = 'Data/configs/plugins/wardrobe.json'

  DIR = 'wardrobe/'
  # Clé dans $user_data (sauvegardé avec la partie)
  STORAGE_KEY = :wardrobe
  # Pièces que peut changer une tenue (chapeau et sac peuvent être retirés avec nil)
  PIECES = %w[hair top bottom hat bag].freeze
  OPTIONAL = %w[hat bag].freeze
  # Afficher l'onglet « Tenues » dans le sac (quand le joueur possède au moins une tenue)
  TAB_ENABLED = true
  # Caractères par ligne de la description
  DESCRIPTION_CHARS = 24

  # Les tenues.
  #   'item'        dbSymbol de l'objet
  #   'name'        nom (sinon le nom de l'objet) : texte ou [français, anglais]
  #   'description' description (sinon celle de l'objet)
  #   'gender'      'm', 'f' ou nil (les deux) : la tenue n'est proposée qu'aux héros de ce genre
  #   'sprites'     tenue toute faite (au lieu de, ou en plus de, 'pieces') : {'charset' => 'NPC_Felix', 'front' => 'Felix'}
#                 charset = image de marche dans graphics/characters (4x4 images, aussi utilisée pour la course, le vélo et la nage),
#                 front = image de face (80x80) dans graphics/pictures, utilisée par le dresseur « pj_joueur_front ».
#                 Le dos en combat reste celui du personnage du générateur. L'icône de l'objet est la première case du charset.
#   'pieces'      pièces remplacées : 'top', 'bottom', 'hat', 'bag', 'hair' => {'key' => 'hoodie', 'color' => 'red'}
  #                 (ou ['hoodie', 'red']) ; nil pour retirer le chapeau / le sac ; une pièce absente reste comme elle est.
  #                 Les clés et les couleurs sont celles du générateur (voir Studio, Générateurs > Personnages).
  # Tenues écrites à la main (facultatif : la page Studio « Tenues » écrit celles du fichier JSON, dont Félix et Ann).
  # Exemple avec des pièces du générateur :
  #   {'item' => :tenue_sport, 'name' => 'Sport', 'pieces' => {'top' => {'key' => 'hoodie', 'color' => 'red'}, 'hat' => nil}}
  OUTFITS = [].freeze

  # --- Données --------------------------------------------------------------------------
  # @return [Integer] 0 français, 1 anglais
  def language_index
    return $options && $options.language.to_s != 'fr' ? 1 : 0
  end

  # @param value [String, Array<String>, nil]
  # @return [String]
  def localize(value)
    return (value[language_index] || value[0]).to_s if value.is_a?(Array)

    return value.to_s
  end

  # @return [Configs::WardrobeConfig]
  def config
    @config ||= begin
      PSDK_CONFIG.release? || File.exist?(CONFIG_FILE) ? Configs.wardrobe : Configs::WardrobeConfig.new
    rescue StandardError, ScriptError => e
      log_error("Wardrobe : #{CONFIG_FILE} illisible (#{e.message})") if respond_to?(:log_error, true)
      Configs::WardrobeConfig.new
    end
  end

  # Clés en texte (le fichier peut être lu avec des clés en symboles)
  def stringify(obj)
    case obj
    when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify(v) }
    when Array then obj.map { |v| stringify(v) }
    else obj
    end
  end

  # @return [Array<Hash>] les tenues : celles du fichier JSON (page Studio) puis celles de OUTFITS (le JSON gagne pour un même objet)
  def outfits
    return @outfits ||= begin
      from_file = stringify(config.outfits || []).select { |outfit| outfit.is_a?(Hash) && !outfit['item'].to_s.empty? }
      from_file + OUTFITS.reject { |outfit| from_file.any? { |other| other['item'].to_s == outfit['item'].to_s } }
    end
  end

  # @param item [Symbol, String]
  # @return [Hash, nil] la tenue de cet objet
  def find(item)
    return outfits.find { |outfit| outfit['item'].to_s == item.to_s }
  end

  # @param item [Symbol, String]
  # @return [Boolean] l'objet est une tenue
  def outfit?(item)
    return !find(item).nil?
  end

  # @param outfit [Hash]
  # @return [Boolean] le joueur a l'objet
  def owned?(outfit)
    return $bag ? $bag.item_quantity(outfit['item'].to_sym) > 0 : false
  end

  # @param outfit [Hash]
  # @param gender [String]
  # @return [Boolean]
  def gender_ok?(outfit, gender)
    return outfit['gender'].to_s.empty? || outfit['gender'].to_s == gender.to_s
  end

  # @return [String] 'm' ou 'f'
  def player_gender
    current = Generateur.spec if defined?(Generateur)
    return current['gender'] if current && current['gender']

    return $game_switches && $game_switches[Yuki::Sw::Gender] ? 'f' : 'm'
  end

  # @return [Array<Hash>] les tenues que le joueur possède et peut porter
  def owned_outfits
    gender = player_gender
    return outfits.select { |outfit| owned?(outfit) && gender_ok?(outfit, gender) }
  end

  # @return [Array<Symbol>] objets-tenues possédés (contenu de l'onglet du sac)
  def owned_items
    return owned_outfits.map { |outfit| outfit['item'].to_sym }
  end

  # @param outfit [Hash]
  # @return [String]
  def name_of(outfit)
    return localize(outfit['name']) if outfit['name']

    return data_item(outfit['item'].to_sym).name.to_s
  rescue StandardError
    return outfit['item'].to_s
  end

  # @param outfit [Hash]
  # @return [String]
  def description_of(outfit)
    return localize(outfit['description']) if outfit['description']

    return data_item(outfit['item'].to_sym).descr.to_s
  rescue StandardError
    return ''
  end

  # @return [String] nom de l'onglet du sac
  def tab_name
    return language_index == 1 ? 'Outfits' : 'Tenues'
  end

  # @return [Boolean] les pièces du générateur sont là
  def ready?
    return defined?(Generateur) && Generateur.available?
  end

  # @param text [String]
  # @param width [Integer]
  # @return [Array<String>] lignes coupées entre les mots
  def wrap(text, width = DESCRIPTION_CHARS)
    lines = []
    text.to_s.split("\n", -1).each do |paragraph|
      line = ''
      paragraph.split(' ').each do |word|
        if line.empty?
          line = word.dup
        elsif line.size + 1 + word.size <= width
          line << ' ' << word
        else
          lines << line
          line = word.dup
        end
      end
      lines << line
    end
    return lines
  end

  # --- Sauvegarde -----------------------------------------------------------------------
  # @return [Hash] { 'worn' => dbSymbol, 'base' => spec d'origine, 'applied' => spec appliquée par la tenue }
  def storage
    return {} unless $user_data

    return $user_data[STORAGE_KEY] ||= {}
  end

  # @param obj [Object]
  # @return [Object] copie profonde
  def deep_copy(obj)
    return Marshal.load(Marshal.dump(obj))
  end

  # @return [Hash] personnage d'origine du joueur (sans tenue) ; une modification faite ailleurs (générateur) devient la nouvelle origine
  def base_spec
    data = storage
    current = Generateur.spec
    if data['base'] && data['applied'] && current == data['applied']
      return data['base']
    end

    base = current ? deep_copy(current) : Generateur.random_spec(player_gender)
    base.delete('outfit_sprites')
    data['base'] = base
    data['applied'] = nil
    data['worn'] = nil
    return base
  end

  # @return [Symbol, nil] objet de la tenue portée (nil : apparence d'origine)
  def worn_item
    data = storage
    return nil unless data['worn'] && data['applied'] && Generateur.spec == data['applied']

    return data['worn'].to_sym
  end

  # @param item [Symbol, String]
  # @return [Boolean]
  def worn?(item)
    return worn_item.to_s == item.to_s
  end

  # --- Habillage ------------------------------------------------------------------------
  # @param value [Hash, Array, nil]
  # @return [Hash, nil] pièce { 'key', 'color' }
  def normalize_piece(value)
    return nil if value.nil?
    return {'key' => value[0].to_s, 'color' => value[1].to_s} if value.is_a?(Array)
    return {'key' => value.to_s, 'color' => ''} unless value.is_a?(Hash)

    return value.each_with_object({}) { |(k, v), h| h[k.to_s] = v }
  end

  # @param base [Hash] personnage d'origine
  # @param outfit [Hash]
  # @return [Hash] personnage habillé : les pièces de la tenue remplacent celles de l'origine
  def build_spec(base, outfit)
    spec = deep_copy(base)
    options = Generateur.options(spec['gender'])
    apply_sprites(spec, outfit)
    (outfit['pieces'] || {}).each do |cat, value|
      cat = cat.to_s
      next unless PIECES.include?(cat)

      piece = normalize_piece(value)
      if piece.nil?
        spec[cat] = nil if OPTIONAL.include?(cat)
        next
      end
      known = options[cat] || {}
      unless known.key?(piece['key'])
        log_error("Wardrobe : pièce « #{piece['key']} » (#{cat}) inconnue pour la tenue #{outfit['item']}") if respond_to?(:log_error, true)
        next
      end
      piece['color'] = known[piece['key']].first.to_s if piece['color'].to_s.empty? && !known[piece['key']].include?('')
      spec[cat] = piece
    end
    return spec
  end

  # Tenue toute faite : ses images remplacent celles des pièces (charset pour la carte, image de face pour les menus)
  # @param spec [Hash] personnage modifié
  # @param outfit [Hash]
  def apply_sprites(spec, outfit)
    sprites = outfit['sprites']
    return unless sprites

    sprites = sprites.each_with_object({}) { |(k, v), h| h[k.to_s] = v.to_s }
    unless File.exist?("graphics/characters/#{sprites['charset']}.png")
      log_error("Wardrobe : charset « #{sprites['charset']} » introuvable (tenue #{outfit['item']})") if respond_to?(:log_error, true)
      return
    end
    spec['outfit_sprites'] = sprites
  end

  # Le héros enfile la tenue
  # @param outfit [Hash]
  # @return [Boolean]
  def wear(outfit)
    return false unless ready? && outfit

    base = base_spec
    spec = build_spec(base, outfit)
    Generateur.apply(spec, true)
    data = storage
    data['base'] = base
    data['applied'] = deep_copy(spec)
    data['worn'] = outfit['item'].to_s
    return true
  end

  # Le héros retrouve son apparence d'origine
  # @return [Boolean] il y avait une tenue à retirer
  def restore
    return false unless ready?

    was_worn = !worn_item.nil?
    base = base_spec
    Generateur.apply(deep_copy(base))
    data = storage
    data['applied'] = deep_copy(base)
    data['worn'] = nil
    return was_worn
  end

  # @return [String] la tenue du héros sous la forme d'une ligne de OUTFITS (pour la copier ici)
  def current_as_text
    spec = Generateur.spec
    return '' unless spec

    pieces = PIECES.map do |cat|
      piece = spec[cat]
      piece ? "'#{cat}' => {'key' => '#{piece['key']}', 'color' => '#{piece['color']}'}" : (OPTIONAL.include?(cat) ? "'#{cat}' => nil" : nil)
    end.compact
    return "{'item' => :tenue_a_nommer, 'name' => 'Nom', 'pieces' => {#{pieces.join(', ')}}}"
  end
end
