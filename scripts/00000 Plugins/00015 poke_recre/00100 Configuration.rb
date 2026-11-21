# Poké Récré (Pokémon-Amie de X/Y ; d'après « Pokémon Amie / Refresh » pour Essentials : BhagyaJyoti, PizzaSun, rigbycwts,
# Gardenette, Victorcarvalhosp)
#
# Chaque Pokémon a trois jauges (0 à 255, montrées en 5 niveaux) :
#   affection     monte quand on le caresse ou qu'on le nourrit ; ne baisse pas
#   satiété       monte quand il mange ; baisse en marchant (1 point tous les N pas)
#   bonne humeur  monte quand on le caresse ; baisse en marchant et un peu à chaque visite
# Évolution : Évoli devient Nymphali (Sylveon) en montant de niveau s'il connaît une capacité Fée et a au moins
# 2 cœurs d'affection (comme dans X/Y ; réglage sylveon_hearts).
#
# Ouvrir : appli « Poké Récré » du téléphone (menu), en parlant au Pokémon qui suit le joueur, ou commande poke_recre.
# Réglages : Data/configs/plugins/poke_recre.json
#   settings  follower (« ask » : propose de jouer quand on parle au Pokémon qui suit, « direct » : ouvre tout de suite,
#             « off » : rien), steps (pas pour perdre 1 point de satiété et de bonne humeur), sylveon_hearts,
#             all_berries (toutes les baies se mangent), pet_distance (mouvement de la main pour une caresse réussie),
#             berry_affection ([min, max] gagnés avec une baie), berry_fullness
#   foods     friandises : { item, affection: [min, max], fullness }
#   backdrops décor imposé par carte : { "n° de carte" : "forest" ou "type_fire"... } (sinon choisi selon l'endroit)
# Pofiteroles, décors de X / Y, décorations, main et statuts : voir 00103 ; mini-jeux : 00104.
# Graphismes : graphics/interface/poke_recre/ ; sons : audio/se/poke_recre_eat, poke_recre_pet
module Configs
  class PokeRecreConfig
    attr_accessor :settings, :foods, :backdrops

    def initialize
      @settings = {}
      @foods = []
      @backdrops = {}
    end
  end
  register(:poke_recre, 'plugins/poke_recre', :json, false, PokeRecreConfig)
end

module PokeRecre
  CONFIG_FILE = 'Data/configs/plugins/poke_recre.json'
  DIR = 'poke_recre/'
  MAX_POINTS = 255
  DEFAULTS = {
    'follower' => 'ask', 'steps' => 50, 'sylveon_hearts' => 2, 'all_berries' => true, 'pet_distance' => 500,
    'berry_affection' => [3, 6], 'berry_fullness' => 90,
    'puff_affection' => [[4, 8], [8, 12], [12, 18], [18, 25], [20, 30]], 'puff_fullness' => 60, 'puff_liked_bonus' => 50,
    'all_decorations' => false, 'start_decorations' => %w[coeur_normal rond_rouge], 'decoration_chance' => 35,
    'cure_pets' => 3, 'hand_style' => 'xy', 'game_time' => 60,
    'berry_stars' => [5, 10, 15, 20, 30], 'head_stars' => [10, 20, 35, 50, 80]
  }.freeze
  # Décors (graphics/interface/poke_recre/bg_<nom>)
  BACKDROPS = %w[field forest cave cave_dark city mountain snow water underwater indoor_a indoor_b indoor_c champion
                 elite_a elite_b elite_c elite_d].freeze
  # Changement des jauges : [affection, satiété, bonne humeur] (nombres ou intervalles)
  CHANGES = {
    walking: [0, -1, -1],
    visit: [0, 0, -2],
    pet: [2..5, 0, 20..39],
    send_in_battle: [0, -25, -25]
  }.freeze

  module_function

  # @return [Configs::PokeRecreConfig]
  def config
    @config ||= begin
      if PSDK_CONFIG.release?
        Configs.poke_recre
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        cfg = Configs::PokeRecreConfig.new
        data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
        cfg
      else
        Configs::PokeRecreConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Poké Récré : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::PokeRecreConfig.new
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

  def file(name)
    return DIR + name
  end

  # Niveau (0 à 5) d'une jauge
  def level(points)
    return 0 if points <= 0
    return 5 if points >= MAX_POINTS

    return [points / 50 + 1, 4].min
  end

  # Tirage dans [min, max] ou nombre fixe
  def roll(value)
    return rand(value) if value.is_a?(Range)
    return rand(value[0].to_i..[value[1].to_i, value[0].to_i].max) if value.is_a?(Array)

    return value.to_i
  end

  # --- Friandises -------------------------------------------------------------------------------
  # @return [Hash, nil] { affection:, fullness: } pour un objet qui se mange
  def food(item)
    entry = Array(config.foods).find { |f| fetch(f, :item).to_s == item.to_s }
    return { affection: fetch(entry, :affection) || [3, 6], fullness: fetch(entry, :fullness) || 90 } if entry
    return nil unless setting('all_berries') && berry?(item)

    return { affection: setting('berry_affection'), fullness: setting('berry_fullness') }
  end

  def berry?(item)
    return data_item(item).is_berry ? true : false
  rescue StandardError
    return false
  end

  # Friandises du sac, dans l'ordre du sac (friandises réglées puis baies)
  # @return [Array<Symbol>]
  def bag_foods
    list = Array(config.foods).map { |f| fetch(f, :item).to_s.to_sym }
    if setting('all_berries')
      held = $bag.instance_variable_get(:@items)
      held = held.is_a?(Hash) ? held.keys : []
      list.concat(held.select { |item| berry?(item) }.sort_by { |item| data_item(item).id })
    end
    return list.uniq.select { |item| $bag.contain_item?(item) && food(item) }
  rescue StandardError
    return []
  end

  # --- Décor -----------------------------------------------------------------------------------
  def backdrop
    forced = fetch(config.backdrops, $game_map&.map_id.to_s)
    return forced.to_s if forced && (BACKDROPS + NEW_BACKDROPS).include?(forced.to_s)
    return 'underwater' if $env.under_water?
    return 'water' if $game_player.respond_to?(:surfing?) && $game_player.surfing?
    return 'cave' if $env.cave?
    return 'indoor_a' if $env.building?
    return 'snow' if $env.snow? || $env.snowing? || $env.hail?
    return 'mountain' if $env.mount?
    return 'forest' if $env.tall_grass? || $env.very_tall_grass?

    return 'field'
  rescue StandardError
    return 'field'
  end

  # Pokémon qui peuvent jouer (pas les œufs)
  def party
    return ($actors || []).compact.reject(&:egg?)
  end
end

module PFM
  class Pokemon
    # Jauges de Poké Récré (0 à 255)
    def amie_affection
      return @amie_affection ||= 0
    end

    def amie_fullness
      return @amie_fullness ||= 0
    end

    def amie_enjoyment
      return @amie_enjoyment ||= 0
    end

    def amie_affection=(value)
      @amie_affection = value.to_i.clamp(0, PokeRecre::MAX_POINTS)
    end

    def amie_fullness=(value)
      @amie_fullness = value.to_i.clamp(0, PokeRecre::MAX_POINTS)
    end

    def amie_enjoyment=(value)
      @amie_enjoyment = value.to_i.clamp(0, PokeRecre::MAX_POINTS)
    end

    # Niveaux (0 à 5 cœurs)
    def affection_level
      return PokeRecre.level(amie_affection)
    end

    def fullness_level
      return PokeRecre.level(amie_fullness)
    end

    def enjoyment_level
      return PokeRecre.level(amie_enjoyment)
    end

    # Change les jauges ([affection, satiété, bonne humeur])
    # @param method [Symbol] voir PokeRecre::CHANGES
    def amie_change(method)
      gains = PokeRecre::CHANGES[method.to_sym]
      return unless gains

      self.amie_affection = amie_affection + PokeRecre.roll(gains[0])
      self.amie_fullness = amie_fullness + PokeRecre.roll(gains[1])
      self.amie_enjoyment = amie_enjoyment + PokeRecre.roll(gains[2])
    end

    # Fait manger une friandise (sans la retirer du sac)
    # @return [Boolean] false s'il n'a plus faim ou si l'objet ne se mange pas
    def amie_feed(item)
      data = PokeRecre.food(item)
      return false unless data && fullness_level < 5

      self.amie_affection = amie_affection + PokeRecre.roll(data[:affection])
      self.amie_fullness = amie_fullness + PokeRecre.roll(data[:fullness])
      return true
    end

    # Nymphali : capacité Fée et assez de cœurs d'affection (comme X/Y)
    module PokeRecreEvolution
      def elv_nymphali
        return super && affection_level >= PokeRecre.setting('sylveon_hearts').to_i
      end
    end
    prepend PokeRecreEvolution
  end

  # Satiété et bonne humeur baissent en marchant
  class GameState
    module PokeRecreSteps
      def increase_steps
        super
        steps = (@poke_recre_steps || 0) + 1
        if steps >= [PokeRecre.setting('steps').to_i, 1].max
          steps = 0
          PokeRecre.party.each { |pokemon| pokemon.amie_change(:walking) }
        end
        @poke_recre_steps = steps
      rescue StandardError => e
        log_error("Poké Récré : #{e.message}") if respond_to?(:log_error, true)
      end
    end
    prepend PokeRecreSteps
  end
end
