# Triple Triad : commandes d'évent (Script)
#
#   triple_triad_duel('Léo')                       -> duel, adversaire de niveau 0 à 9 au hasard
#   triple_triad_duel('Léo', 2, 5)                 -> cartes de l'adversaire de niveau 2 à 5 (sur 9)
#   triple_triad_duel('Léo', 0, 9, [:open, :same, :plus], nil, variable: 12)
#       règles : open, random, same, samewall, plus, elements, suddendeath, trade_none / trade_one / trade_direct / trade_all
#       5e paramètre : cartes imposées à l'adversaire, ex. [:pikachu, :eevee, :snorlax, :mew, :ditto]
#       variable : la variable reçoit le résultat (1 victoire, 2 défaite, 3 égalité, 0 abandon / pas assez de cartes)
#   triple_triad_deck_duel(:leo, variable: 12)     -> duel contre un adversaire réglé dans Studio (nom, cartes, règles)
#   triple_triad_won?                              -> true si le dernier duel est gagné
#   give_triad_card(:pikachu, 2)                   -> donne des cartes (message : true pour l'annoncer)
#   take_triad_card(:pikachu)                      -> retire une carte
#   triad_card_count(:pikachu) / triad_card_total  -> nombre de cartes
#   triple_triad_collection                        -> voir ses cartes
#   triple_triad_shop                              -> boutique (Pokémon vus dans le Pokédex), ou une liste : triple_triad_shop([:pikachu, :eevee])
#   triple_triad_sell                              -> vendre des cartes (moitié du prix)
class Interpreter
  # @return [Integer] 1 victoire, 2 défaite, 3 égalité, 0 abandon / pas assez de cartes
  def triple_triad_duel(name, min_level = 0, max_level = 9, rules = [], opponent_cards = nil, variable: nil)
    tt = TripleTriad
    tt.reload if PSDK_CONFIG.debug?
    rules = Array(rules).map(&:to_sym)
    result = 0
    if tt.total_count < tt::HAND_SIZE
      $scene.display_message(tt.t("Il te faut au moins #{tt::HAND_SIZE} cartes pour jouer.", "You need at least #{tt::HAND_SIZE} cards to play."))
    else
      hand = rules.include?(:random) ? tt.random_hand : nil
      $scene.call_scene(GamePlay::TripleTriadCards, :hand) { |scene| hand = scene.hand } unless hand
      if hand
        opponent = opponent_cards ? Array(opponent_cards).map(&:to_sym) : tt.opponent_hand(min_level, max_level)
        opponent += tt.opponent_hand(min_level, max_level) while opponent.size < tt::HAND_SIZE
        $scene.call_scene(GamePlay::TripleTriadDuel, name, hand, opponent.first(tt::HAND_SIZE), rules) { |scene| result = scene.result }
      end
    end
    tt.last_result = result
    $game_variables[variable] = result if variable
    @wait_count = 2
    return result
  end
  alias duel_triple_triad triple_triad_duel

  # Duel contre un adversaire réglé dans Studio (Level design > Mini-jeux > Triple Triad > Adversaires)
  # @param id [Symbol, String] identifiant de l'adversaire
  # @param variable [Integer, nil]
  # @return [Integer]
  def triple_triad_deck_duel(id, variable: nil)
    TripleTriad.reload if PSDK_CONFIG.debug?
    deck = TripleTriad.deck(id)
    unless deck
      log_error("Triple Triad : adversaire #{id} introuvable") if respond_to?(:log_error, true)
      return 0
    end
    cards = Array(deck[:cards]).map(&:to_sym).reject { |s| s.to_s.empty? }
    return triple_triad_duel(deck[:name].to_s, deck[:min_level] || 0, deck[:max_level] || 9, Array(deck[:rules]),
                             cards.empty? ? nil : cards, variable: variable)
  end
  alias duel_triple_triad_adversaire triple_triad_deck_duel

  # @return [Boolean]
  def triple_triad_won?
    return TripleTriad.last_result == GamePlay::TripleTriadDuel::WIN
  end

  # @param species [Symbol]
  # @param quantity [Integer]
  # @param message [Boolean]
  def give_triad_card(species, quantity = 1, message: false)
    return false unless TripleTriad.add(species, quantity)

    if message
      card = TripleTriad::Card.get(species)
      $scene.display_message(TripleTriad.t("Tu reçois #{quantity > 1 ? "#{quantity} cartes" : 'la carte'} #{card.name} !", "You received #{quantity > 1 ? "#{quantity} " : 'the '}#{card.name} card#{quantity > 1 ? 's' : ''}!"))
    end
    return true
  end
  alias donner_carte_triad give_triad_card

  # @return [Boolean]
  def take_triad_card(species, quantity = 1)
    return TripleTriad.remove(species, quantity)
  end

  # @return [Integer]
  def triad_card_count(species)
    return TripleTriad.count(species)
  end

  # @return [Integer]
  def triad_card_total
    return TripleTriad.total_count
  end

  def triple_triad_collection
    $scene.call_scene(GamePlay::TripleTriadCards, :view)
    @wait_count = 2
  end

  # @param list [Array<Symbol>, nil]
  def triple_triad_shop(list = nil)
    $scene.call_scene(GamePlay::TripleTriadCards, :shop, list && Array(list).map(&:to_sym))
    @wait_count = 2
  end

  def triple_triad_sell
    $scene.call_scene(GamePlay::TripleTriadCards, :sell)
    @wait_count = 2
  end
end

module TripleTriad
  class << self
    # @return [Integer] résultat du dernier duel
    attr_accessor :last_result
  end
end
