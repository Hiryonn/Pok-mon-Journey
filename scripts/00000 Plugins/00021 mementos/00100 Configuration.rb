# Souvenirs : rubans, insignes et titres (d'après « Improved Mementos » de Lucidious89 pour Essentials, refait pour PSDK)
#
# Les rubans de PSDK (PFM::RIBBONS_DATA) restent la base : ce plugin ajoute les rubans qui manquaient, les 53 insignes
# (8e génération et après), leurs titres, leurs rangs et leurs catégories (00101 Donnees.rb).
# - Insignes donnés aux Pokémon sauvages (heure, météo, humeur, rareté, pêche, miel, anniversaire du joueur, taille)
#   et gagnés en route (pas avec un Pokémon très attaché, objets ramassés, baies) : 00103 Insignes.rb.
#   Le Charme Insigne (mark_charm) les rend plus fréquents.
# - Titre : le ruban ou l'insigne choisi dans le résumé donne un titre au Pokémon (« Pikachu l'Affamé »),
#   montré en combat (en couleur) avec l'icône du souvenir qui s'élève au-dessus du Pokémon : 00104 Combat.rb.
# - Taille (0 à 255) de chaque Pokémon : insignes Mini et Colosse.
# - Résumé (Interface Horizon) : page des souvenirs avec tri, rangs regroupés, déplacement et choix du titre.
# Réglages : Data/configs/plugins/mementos.json
#   settings  title_color (couleur des titres en combat, -1 : sans couleur), auto_title (le premier souvenir à titre
#             devient le titre), mark_ratio (chance de base 1/x), size_marks (Mini/Colosse toujours donnés aux
#             sauvages de taille 0/255), collapse_ranks (rangs regroupés par défaut), battle_titles, battle_icon,
#             partner_steps (pas pour l'insigne Partenaire), wild_marks (insignes des sauvages)
#   trainers  [{ trainer: db_symbol du dresseur, slot: place (0..5), memento: ruban ou insigne }] titres des Pokémon
#             des dresseurs
#   texts     { souvenir: { name: [fr, en], description: [fr, en], title: [fr, en] } } textes changés dans Studio
# Page Studio : Données > Pokémon > Rubans et insignes (tools/studio-mementos)
module Configs
  class MementosConfig
    attr_accessor :settings, :trainers, :texts

    def initialize
      @settings = {}
      @trainers = []
      @texts = {}
    end
  end
  register(:mementos, 'plugins/mementos', :json, false, MementosConfig)
end

module Mementos
  CONFIG_FILE = 'Data/configs/plugins/mementos.json'
  DIR = 'mementos/'
  DEFAULTS = {
    'title_color' => 2, 'auto_title' => true, 'mark_ratio' => 50, 'size_marks' => true, 'collapse_ranks' => true,
    'battle_titles' => true, 'battle_icon' => true, 'partner_steps' => 10_000, 'wild_marks' => true
  }.freeze

  module_function

  # @return [Configs::MementosConfig]
  def config
    @config ||= begin
      if PSDK_CONFIG.release?
        Configs.mementos
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        cfg = Configs::MementosConfig.new
        data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
        cfg
      else
        Configs::MementosConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Souvenirs : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::MementosConfig.new
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

  def setting?(key)
    return setting(key) == true
  end

  def french?
    return !($options && $options.language.to_s != 'fr')
  end

  def t(fr, en = fr)
    return french? ? fr : en
  end

  # Texte [fr, en] dans la langue du jeu
  def pick(pair)
    return pair.to_s unless pair.is_a?(Array)

    return (french? ? pair[0] : pair[1]).to_s
  end

  # Texte changé dans Studio (réglage texts), nil s'il n'y en a pas dans la langue du jeu
  # @param symbol [Symbol] souvenir
  # @param key [Symbol] :name, :description ou :title
  def custom_text(symbol, key)
    value = fetch(fetch(config.texts, symbol), key)
    return nil unless value.is_a?(Array)

    text = pick(value)
    return text.empty? ? nil : text
  end

  # Le joueur a-t-il le Charme Insigne ?
  def charm?
    return $bag&.contain_item?(:mark_charm) ? true : false
  rescue StandardError
    return false
  end

  # Données de la partie (pas, anniversaire)
  def store
    return PFM.game_state.user_data[:pj_mementos] ||= {}
  end

  # --- Anniversaire du joueur (insigne Destin) ---------------------------------------------------
  # @return [Array(Integer, Integer), nil] jour, mois
  def birthday
    value = store[:birthday]
    return value.is_a?(Array) && value.size == 2 ? value : nil
  end

  def set_birthday(day, month)
    month = month.to_i.clamp(1, 12)
    day = day.to_i.clamp(1, days_in_month(month))
    store[:birthday] = [day, month]
  end

  def days_in_month(month)
    return 29 if month == 2
    return 30 if [4, 6, 9, 11].include?(month)

    return 31
  end

  # C'est l'anniversaire du joueur aujourd'hui (date de l'ordinateur)
  def anniversary?
    return false unless (date = birthday)

    now = Time.now
    return now.day == date[0] && now.month == date[1]
  end

  MONTHS = [%w[Janvier January], %w[Février February], %w[Mars March], %w[Avril April], %w[Mai May], %w[Juin June],
            %w[Juillet July], %w[Août August], %w[Septembre September], %w[Octobre October], %w[Novembre November],
            %w[Décembre December]].freeze

  def month_name(month)
    return pick(MONTHS[(month.to_i - 1).clamp(0, 11)])
  end
end
