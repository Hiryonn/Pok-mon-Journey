# Pokéathlon (Pokémon Or HeartGold / Argent SoulSilver)
#
# 5 coupes (Vitesse, Force, Technique, Endurance, Saut) de 3 épreuves chacune, parmi 10 épreuves :
#   hurdle  Course de haies      pennant  Capture de fanions   relay  Relais
#   block   Casse-blocs          circle   Pousse-cercle        goal   Tir au but
#   snow    Bataille de neige    lamp     Saut lumineux        disc   Attrape-disques
#   ring    Anneau (sumo)
# Le joueur choisit une coupe et 3 Pokémon, contre 3 équipes adverses. Chaque épreuve rapporte des points selon le
# classement et le score ; l'équipe première au total gagne un bonus. Les points se dépensent à la boutique
# (plugin magasins, monnaie « pokeathlon »).
# Performances (00101) : Vitesse, Force, Technique, Endurance, Saut (1 à 5 étoiles) par espèce (calculées depuis les
# statistiques ou réglées dans Studio), variation du jour, nature, Jus de Noigrume (00102).
#
# Réglages : Data/configs/plugins/pokeathlon.json (Studio : Level design > Mini-jeux > Pokéathlon)
#   settings    règles (voir DEFAULTS)
#   courses     coupes : { id:, name: { fr:, en: }, events: [3 épreuves] }
#   events      épreuves : { id => { time:, medal:, crown:, bgm: } }
#   opponents   équipes adverses : { name: { fr:, en: }, team: [3 espèces] }
#   performance espèces réglées : { espèce => { base: [5 valeurs], max: [5 valeurs] } }
#   apricorns   Noigrumes : { objet => [épicé, sec, sucré, amer, acide] }
#   shop        boutique : { '0'..'6' (dimanche..samedi) => [{ item:, price: }] }
module Configs
  class PokeathlonConfig
    attr_accessor :settings, :courses, :events, :opponents, :performance, :apricorns, :shop

    def initialize
      @settings = {}
      @courses = []
      @events = {}
      @opponents = []
      @performance = {}
      @apricorns = {}
      @shop = {}
    end
  end
  register(:pokeathlon, 'plugins/pokeathlon', :json, false, PokeathlonConfig)
end

module Pokeathlon
  CONFIG_FILE = 'Data/configs/plugins/pokeathlon.json'
  DIR = 'pokeathlon/'
  # Performances : ordre des étoiles partout
  STATS = %w[speed power skill stamina jump].freeze
  STAT_NAMES = {
    'speed' => %w[Vitesse Speed], 'power' => %w[Force Power], 'skill' => %w[Technique Skill],
    'stamina' => %w[Endurance Stamina], 'jump' => %w[Saut Jump]
  }.freeze
  # Saveurs des Jus de Noigrume -> performance
  FLAVORS = %w[spicy dry sweet bitter sour].freeze
  FLAVOR_STAT = { 'spicy' => 'power', 'dry' => 'skill', 'sweet' => 'speed', 'bitter' => 'jump', 'sour' => 'stamina' }.freeze
  FLAVOR_NAMES = { 'spicy' => %w[Épicé Spicy], 'dry' => %w[Sec Dry], 'sweet' => %w[Sucré Sweet], 'bitter' => %w[Amer Bitter],
                   'sour' => %w[Acide Sour] }.freeze
  # Nature (index dans pokemon.nature : 1 Attaque, 2 Défense, 3 Vitesse, 4 Atq. Spé., 5 Déf. Spé.) -> performance
  NATURE_STAT = { 3 => 'speed', 1 => 'power', 5 => 'skill', 2 => 'stamina', 4 => 'jump' }.freeze
  EVENTS = %w[hurdle pennant relay block circle goal snow lamp disc ring].freeze
  EVENT_NAMES = {
    'hurdle' => ['Course de haies', 'Hurdle Dash'], 'pennant' => ['Capture de fanions', 'Pennant Capture'],
    'relay' => ['Relais', 'Relay Run'], 'block' => ['Casse-blocs', 'Block Smash'], 'circle' => ['Pousse-cercle', 'Circle Push'],
    'goal' => ['Tir au but', 'Goal Roll'], 'snow' => ['Bataille de neige', 'Snow Throw'], 'lamp' => ['Saut lumineux', 'Lamp Jump'],
    'disc' => ['Attrape-disques', 'Disc Catch'], 'ring' => ['Anneau', 'Ring Drop']
  }.freeze
  # Statistiques utiles à chaque épreuve (affichées avant l'épreuve)
  EVENT_STATS = {
    'hurdle' => %w[speed jump skill], 'pennant' => %w[speed skill stamina power], 'relay' => %w[speed stamina skill power],
    'block' => %w[power stamina skill], 'circle' => %w[power speed stamina], 'goal' => %w[power skill speed stamina],
    'snow' => %w[power skill stamina], 'lamp' => %w[jump skill stamina], 'disc' => %w[jump speed power],
    'ring' => %w[power stamina speed jump]
  }.freeze
  # Règles affichées avant chaque épreuve
  EVENT_DESCRIPTIONS = {
    'hurdle' => ['Les 3 Pokémon courent l’un après l’autre. Saute les haies avec A au bon moment : un saut parfait donne de l’élan, une haie touchée fait trébucher. Le temps le plus court gagne.',
                 'Your 3 Pokémon run one after another. Jump the hurdles with A at the right moment: a perfect jump gives a boost, hitting a hurdle makes you trip. Fastest time wins.'],
    'pennant' => ['Ramasse les fanions et rapporte-les à ta base (ton coin). Bousculé, ton Pokémon perd un fanion. Fatigué ? Reviens à la base et appuie sur B pour changer de Pokémon.',
                  'Pick up pennants and bring them back to your base (your corner). When bumped, your Pokémon drops one. Tired? Go back to base and press B to switch.'],
    'relay' => ['Fais le plus de tours possible. A maintenu : sprinter. Haut / Bas : éviter les rochers. Dans la zone de relais, B passe le relais à un Pokémon reposé.',
                'Run as many laps as you can. Hold A: sprint. Up / Down: avoid rocks. In the relay zone, B hands over to a rested Pokémon.'],
    'block' => ['Frappe la pile de blocs avec A quand le curseur est au centre de la jauge : plusieurs blocs d’un coup ! Attention à la fatigue ; B pour changer de Pokémon.',
                'Strike the block pile with A when the cursor is in the middle of the gauge: several blocks at once! Watch out for fatigue; B to switch Pokémon.'],
    'circle' => ['Reste dans les cercles qui bougent : chaque seconde, le petit rapporte 3 points, le moyen 2, le grand 1. Pousse les autres dehors ! B : changer de Pokémon dirigé.',
                 'Stay inside the moving circles: every second the small one gives 3 points, the middle one 2, the big one 1. Push the others out! B: switch Pokémon.'],
    'goal' => ['Pousse les ballons dans les buts des autres équipes (+1) et protège le tien (-1). Le ballon doré vaut 2 points. B : changer de Pokémon dirigé.',
               'Push the balls into the other teams’ goals (+1) and guard yours (-1). The golden ball is worth 2. B: switch Pokémon.'],
    'snow' => ['Lance des boules de neige sur les autres équipes : 1 point par Pokémon touché. Gauche / Droite pour esquiver, Haut / Bas pour viser, A pour lancer (ou clic). B : changer.',
               'Throw snowballs at the other teams: 1 point per Pokémon hit. Left / Right to dodge, Up / Down to aim, A to throw (or click). B: switch.'],
    'lamp' => ['Rebondis sur le trampoline et éteins les lampes en les traversant. A au moment de toucher le trampoline : grand saut. Plusieurs lampes dans un saut rapportent plus.',
               'Bounce on the trampoline and turn off the lamps by passing through them. A when touching the trampoline: big jump. Several lamps in one jump score more.'],
    'disc' => ['Va sous les disques (regarde leur ombre) et saute avec A juste avant qu’ils tombent. Plus la bande est basse, plus le disque rapporte. Ne tombe pas de la plateforme !',
               'Get under the discs (watch their shadow) and jump with A just before they land. The lower the band, the more points. Don’t fall off the platform!'],
    'ring' => ['Fais tomber les autres Pokémon de l’anneau : maintiens A puis relâche pour charger. Chaque Pokémon que tu fais tomber rapporte 1 point.',
               'Knock the other Pokémon out of the ring: hold A then release to charge. Each Pokémon you knock out scores 1 point.']
  }.freeze
  # Score : plus petit = meilleur (temps)
  LOWER_IS_BETTER = %w[hurdle].freeze
  DEFAULT_COURSES = [
    { 'id' => 'speed', 'name' => { 'fr' => 'Coupe Vitesse', 'en' => 'Speed Course' }, 'events' => %w[hurdle pennant relay] },
    { 'id' => 'power', 'name' => { 'fr' => 'Coupe Force', 'en' => 'Power Course' }, 'events' => %w[block circle goal] },
    { 'id' => 'skill', 'name' => { 'fr' => 'Coupe Technique', 'en' => 'Skill Course' }, 'events' => %w[snow goal pennant] },
    { 'id' => 'stamina', 'name' => { 'fr' => 'Coupe Endurance', 'en' => 'Stamina Course' }, 'events' => %w[block ring relay] },
    { 'id' => 'jump', 'name' => { 'fr' => 'Coupe Saut', 'en' => 'Jump Course' }, 'events' => %w[lamp disc hurdle] }
  ].freeze
  # Épreuves : durée (secondes), scores à battre (médaille, couronne)
  EVENT_DEFAULTS = {
    'hurdle' => { 'time' => 90, 'medal' => 28, 'crown' => 24 }, 'pennant' => { 'time' => 60, 'medal' => 18, 'crown' => 28 },
    'relay' => { 'time' => 60, 'medal' => 9, 'crown' => 11 }, 'block' => { 'time' => 45, 'medal' => 220, 'crown' => 300 },
    'circle' => { 'time' => 60, 'medal' => 250, 'crown' => 340 }, 'goal' => { 'time' => 60, 'medal' => 3, 'crown' => 6 },
    'snow' => { 'time' => 60, 'medal' => 10, 'crown' => 16 }, 'lamp' => { 'time' => 60, 'medal' => 800, 'crown' => 1300 },
    'disc' => { 'time' => 60, 'medal' => 25, 'crown' => 40 }, 'ring' => { 'time' => 60, 'medal' => 3, 'crown' => 6 }
  }.freeze
  DEFAULTS = {
    # points par place à chaque épreuve (1er, 2e, 3e, 4e)
    'rank_points' => [100, 70, 45, 25],
    # points en plus selon le score (score / médaille × ce nombre, plafonné au double)
    'score_points' => 60,
    # bonus de l'équipe première au total
    'first_bonus' => 100,
    # difficulté des adversaires (1 à 3)
    'difficulty' => 2,
    # musiques (vide : celles par défaut)
    'menu_bgm' => '',
    'event_bgm' => '',
    'win_me' => '',
    # Jus de Noigrume : pas pour mixer, nombre de verres par mixage, Noigrumes par mixage
    'juice_steps' => 100,
    'juice_uses' => 3,
    'juice_apricorns' => 5,
    # objet nécessaire pour le mixeur (vide = aucun)
    'blender_item' => 'apricorn_box',
    # le jus disparaît quand le Pokémon va au PC
    'juice_pc_reset' => true,
    # performances : variation du jour (étoiles) et effet de la nature
    'daily_range' => 1,
    'nature_effect' => true
  }.freeze
  DEFAULT_OPPONENTS = [
    ['Les Fulgurants', 'The Bolts', %w[pikachu jolteon electabuzz]], ['Les Plumes', 'The Feathers', %w[pidgeotto fearow doduo]],
    ['Les Costauds', 'The Brawlers', %w[machoke hitmonlee tauros]], ['Les Bondissants', 'The Bouncers', %w[buneary spoink wooper]],
    ['Les Flammèches', 'The Embers', %w[ponyta growlithe vulpix]], ['Les Vagues', 'The Waves', %w[psyduck marill totodile]],
    ['Les Feuillus', 'The Leaves', %w[oddish chikorita sunkern]], ['Les Rapides', 'The Speedsters', %w[rattata zubat sentret]],
    ['Les Malins', 'The Clever', %w[abra natu smoochum]], ['Les Rocs', 'The Rocks', %w[geodude onix sudowoodo]],
    ['Les Étoiles', 'The Stars', %w[clefairy staryu togepi]], ['Les Champions', 'The Champions', %w[gyarados dragonite tyranitar]]
  ].map { |fr, en, team| { 'name' => { 'fr' => fr, 'en' => en }, 'team' => team } }.freeze
  # Noigrumes : [épicé, sec, sucré, amer, acide]
  DEFAULT_APRICORNS = {
    'red_apricorn' => [12, 0, 3, 0, 0], 'yellow_apricorn' => [3, 0, 0, 0, 12], 'blue_apricorn' => [0, 12, 0, 3, 0],
    'green_apricorn' => [0, 3, 0, 12, 0], 'pink_apricorn' => [0, 0, 12, 0, 3], 'white_apricorn' => [-3, -3, -3, -3, -3],
    'black_apricorn' => [6, 6, 6, 6, 6]
  }.freeze
  # Boutique par jour (0 = dimanche)
  DEFAULT_SHOP = {
    '1' => [%w[red_apricorn 200], %w[blue_apricorn 200], %w[green_apricorn 200], %w[moomoo_milk 100], %w[moon_stone 3000], %w[rare_candy 2000]],
    '2' => [%w[yellow_apricorn 200], %w[pink_apricorn 200], %w[white_apricorn 200], %w[moomoo_milk 100], %w[fire_stone 3000], %w[pp_up 1000]],
    '3' => [%w[blue_apricorn 200], %w[pink_apricorn 200], %w[black_apricorn 200], %w[moomoo_milk 100], %w[water_stone 2500], %w[heart_scale 1000]],
    '4' => [%w[yellow_apricorn 200], %w[pink_apricorn 200], %w[white_apricorn 200], %w[moomoo_milk 100], %w[thunder_stone 2500], %w[pp_up 500]],
    '5' => [%w[red_apricorn 200], %w[yellow_apricorn 200], %w[green_apricorn 200], %w[moomoo_milk 100], %w[metal_coat 2500], %w[nugget 500]],
    '6' => [%w[green_apricorn 200], %w[white_apricorn 200], %w[black_apricorn 200], %w[moomoo_milk 100], %w[leaf_stone 2500], %w[rare_candy 2000]],
    '0' => [%w[red_apricorn 200], %w[blue_apricorn 200], %w[black_apricorn 200], %w[moomoo_milk 100], %w[kings_rock 3000], %w[heart_scale 1000]]
  }.transform_values { |list| list.map { |item, price| { 'item' => item, 'price' => price.to_i } } }.freeze
  # Couleurs des équipes (joueur, puis adversaires)
  TEAM_COLORS = [[232, 72, 72], [72, 120, 232], [240, 200, 48], [72, 184, 96]].freeze

  module_function

  # @return [Configs::PokeathlonConfig]
  def config
    @config ||= load_config
  end

  def load_config
    return Configs.pokeathlon if PSDK_CONFIG.release?
    return Configs::PokeathlonConfig.new unless File.exist?(CONFIG_FILE)

    require 'json'
    data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
    cfg = Configs::PokeathlonConfig.new
    data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
    return cfg
  rescue StandardError, ScriptError => e
    log_error("Pokéathlon : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
    return Configs::PokeathlonConfig.new
  end

  def reload
    @config = nil
    @species_perf = nil
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

  def fr?
    return $options.nil? || $options.language.to_s == 'fr'
  end

  def t(fr, en = fr)
    return fr? ? fr : en
  end

  # Texte { fr:, en: } ou [fr, en]
  def localized(value)
    return value.to_s unless value.is_a?(Hash) || value.is_a?(Array)
    return (fr? ? value[0] : value[1] || value[0]).to_s if value.is_a?(Array)

    text = fetch(value, fr? ? 'fr' : 'en')
    text = fetch(value, 'fr') if text.to_s.empty?
    return text.to_s
  end

  def file(name)
    return "#{DIR}#{name}"
  end

  def stat_name(stat)
    return localized(STAT_NAMES[stat.to_s] || [stat.to_s])
  end

  def event_name(id)
    return localized(EVENT_NAMES[id.to_s] || [id.to_s])
  end

  def event_description(id)
    return localized(EVENT_DESCRIPTIONS[id.to_s] || [''])
  end

  # --- Coupes et épreuves --------------------------------------------------------------------------------------------
  # @return [Array<Hash>]
  def courses
    list = Array(config.courses).select { |c| c.is_a?(Hash) && !fetch(c, 'id').to_s.empty? }
    list = DEFAULT_COURSES if list.empty?
    return list.each_with_index.map do |c, i|
      events = Array(fetch(c, 'events')).map(&:to_s).select { |e| EVENTS.include?(e) }.first(3)
      events = DEFAULT_COURSES.first['events'] if events.empty?
      icon = fetch(c, 'icon')
      icon = icon.nil? || icon.to_s.empty? ? i % 5 : icon.to_i % 5
      { 'id' => fetch(c, 'id').to_s, 'name' => fetch(c, 'name') || { 'fr' => fetch(c, 'id').to_s }, 'events' => events,
        'icon' => icon, 'switch' => fetch(c, 'switch').to_i }
    end
  end

  # Coupes disponibles (interrupteur réglé dans Studio activé)
  # @return [Array<Hash>]
  def available_courses
    return courses.select { |c| c['switch'] <= 0 || ($game_switches && $game_switches[c['switch']]) }
  end

  # Image de l'icône d'une coupe
  def course_icon(course)
    return file("coupe_#{course['icon'].to_i % 5}")
  end

  def course(id)
    return courses.find { |c| c['id'] == id.to_s }
  end

  # Réglages d'une épreuve (avec les valeurs par défaut)
  # @return [Hash]
  def event_setting(id)
    own = fetch(config.events, id.to_s)
    return (EVENT_DEFAULTS[id.to_s] || {}).merge(own.is_a?(Hash) ? own.transform_keys(&:to_s) : {})
  end

  # @return [Array<Hash>] équipes adverses réglées
  def opponents
    list = Array(config.opponents).select { |o| o.is_a?(Hash) && Array(fetch(o, 'team')).compact.size >= 1 }
    list = DEFAULT_OPPONENTS if list.empty?
    return list
  end

  # Le score a est meilleur que b
  def better?(event, a, b)
    return true if b.nil?

    return LOWER_IS_BETTER.include?(event.to_s) ? a < b : a > b
  end

  # --- Sauvegarde ----------------------------------------------------------------------------------------------------
  # @return [Hash] { 'points', 'total', 'records' => { épreuve => score }, 'played', 'wins' => { coupe => n },
  #   'juice' => mixeur, 'firsts' }
  def data
    $user_data[:pj_athlon] ||= {}
    store = $user_data[:pj_athlon]
    store['points'] ||= 0
    store['total'] ||= 0
    store['records'] ||= {}
    store['played'] ||= 0
    store['wins'] ||= {}
    store['events_played'] ||= {}
    return store
  end

  def points
    return data['points'].to_i
  end

  def add_points(amount)
    data['points'] = [points + amount.to_i, 0].max
    data['total'] += amount.to_i if amount.to_i > 0
  end

  # Médaille (:medal), couronne (:crown) ou nil pour un score
  def award(event, score)
    return nil if score.nil?

    cfg = event_setting(event)
    crown = cfg['crown'].to_f
    medal = cfg['medal'].to_f
    return :crown if crown > 0 && reached?(event, score, crown)
    return :medal if medal > 0 && reached?(event, score, medal)

    return nil
  end

  def reached?(event, score, target)
    return LOWER_IS_BETTER.include?(event.to_s) ? score <= target : score >= target
  end
end
