# Triple Triad (comme dans Pokémon Essentials) : jeu de cartes Pokémon sur un plateau 3x3
#
# Chaque carte = un Pokémon, avec 4 valeurs (haut, droite, bas, gauche) de 1 à 10 (A) tirées de ses stats.
# Poser une carte à côté d'une carte adverse la capture si la valeur qui la touche est plus grande.
# À la fin, celui qui possède le plus de cartes (plateau + main) gagne.
#
# Commandes d'évent (Script) : voir 00106 Commandes.rb
#   triple_triad_duel('Léo', 0, 3)              -> duel (adversaire avec des cartes de niveau 0 à 3)
#   give_triad_card(:pikachu, 2)                -> donne des cartes
#   triple_triad_collection / triple_triad_shop -> voir ses cartes / boutique
#
# Graphismes : graphics/interface/triple_triad/
module Configs
  # Contenu de Data/configs/plugins/triple_triad.json (édité dans Studio : Plugins > Triple Triad)
  class TripleTriadConfig
    # cards : { db_symbol => { values: [haut, droite, bas, gauche], price:, excluded: } } (cartes modifiées)
    # decks : [{ id:, name:, cards: [5 db_symbol], rules: [...] }] (adversaires prêts à l'emploi)
    # shop : cartes de la boutique par défaut (vide : Pokémon vus dans le Pokédex)
    attr_accessor :cards, :decks, :shop, :price_factor, :sell_ratio

    def initialize
      @cards = {}
      @decks = []
      @shop = []
      @price_factor = 1.0
      @sell_ratio = 0.5
    end
  end
  register(:triple_triad, 'plugins/triple_triad', :json, false, TripleTriadConfig)
end

module TripleTriad
  CONFIG_FILE = 'Data/configs/plugins/triple_triad.json'
  # Dossier des graphismes (dans graphics/interface/)
  DIR = 'triple_triad/'
  # Nombre de cartes par main
  HAND_SIZE = 5
  # Plateau : coin haut gauche de la 1re case, pas entre les cases
  BOARD_X = 101
  BOARD_Y = 25
  CELL_W = 39
  CELL_H = 47
  # Mains : x du joueur / de l'adversaire, y de la 1re carte, écart entre les cartes
  HAND_X = [30, 250].freeze
  HAND_Y = 18
  HAND_STEP = 30
  # Décalage de la carte choisie dans la main
  HAND_PICK_OFFSET = 10
  # Taille d'une carte
  CARD_W = 40
  CARD_H = 48
  # Règles connues (comme Essentials) :
  #   open        : la main de l'adversaire est visible
  #   random      : 5 cartes tirées au hasard dans la collection du joueur
  #   same        : « Pareil » (2 côtés égaux ou plus capturent, avec combo)
  #   samewall    : « Pareil mur » (les bords du plateau comptent comme des A pour Pareil)
  #   plus        : « Plus » (2 sommes égales ou plus capturent, avec combo)
  #   elements    : certaines cases ont un type : +1 si la carte a ce type, -1 sinon
  #   suddendeath : en cas d'égalité, on rejoue avec les cartes possédées
  #   trade_none / trade_one (par défaut) / trade_direct / trade_all : échange de cartes à la fin
  RULES = %i[open random same samewall plus elements suddendeath trade_none trade_one trade_direct trade_all].freeze
  # Prix minimum d'une carte (boutique)
  MIN_PRICE = 100

  module_function

  # @return [Configs::TripleTriadConfig]
  def config
    @config ||= begin
      if PSDK_CONFIG.release? || File.exist?(CONFIG_FILE)
        Configs.triple_triad
      else
        Configs::TripleTriadConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Triple Triad : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::TripleTriadConfig.new
    end
  end

  # Relit les réglages (après une modification dans Studio, en mode debug)
  def reload
    @config = nil
    @card_settings = nil
    @pre_evolutions = nil
    Card.reset
  end

  # @return [Hash{Symbol => Hash}] réglages des cartes modifiées dans Studio
  def card_settings
    @card_settings ||= (config.cards || {}).to_h { |k, v| [k.to_sym, (v || {}).transform_keys(&:to_sym)] }
  end

  # @return [Array<Integer>, nil] valeurs imposées dans Studio
  def custom_values(db_symbol)
    values = card_settings.dig(db_symbol.to_sym, :values)
    return nil unless values.is_a?(Array) && values.size == 4

    return values.map { |v| v.to_i.clamp(1, 10) }
  end

  # @return [Integer, nil] prix imposé dans Studio
  def custom_price(db_symbol)
    price = card_settings.dig(db_symbol.to_sym, :price)
    return price.to_i > 0 ? price.to_i : nil
  end

  # @return [Boolean] carte retirée (ni boutique, ni adversaires au hasard)
  def excluded?(db_symbol)
    return card_settings.dig(db_symbol.to_sym, :excluded) == true
  end

  # @return [Float]
  def price_factor
    return (config.price_factor || 1.0).to_f
  end

  # @return [Float]
  def sell_ratio
    return (config.sell_ratio || 0.5).to_f.clamp(0.0, 1.0)
  end

  # @return [Array<Hash>] adversaires réglés dans Studio
  def decks
    return (config.decks || []).map { |deck| deck.transform_keys(&:to_sym) }
  end

  # @param id [Symbol, String]
  # @return [Hash, nil]
  def deck(id)
    return decks.find { |deck| deck[:id].to_s == id.to_s }
  end

  # Pokémon dont celui-ci évolue (d'après les évolutions de Studio)
  # @return [Symbol, nil]
  def pre_evolution(db_symbol)
    unless @pre_evolutions
      @pre_evolutions = {}
      each_data_creature do |creature|
        creature.forms.each do |form|
          (form.evolutions || []).each do |evolution|
            target = evolution.db_symbol
            next if target.nil? || target == :__undef__ || target == creature.db_symbol

            @pre_evolutions[target] ||= creature.db_symbol
          end
        end
      end
    end
    return @pre_evolutions[db_symbol.to_sym]
  end

  # @return [String]
  def file(name)
    return "#{DIR}#{name}"
  end

  # Texte selon la langue
  # @param fr [String]
  # @param en [String]
  # @return [String]
  def t(fr, en)
    return $options && $options.language.to_s != 'fr' ? en : fr
  end
end
