# Triple Triad : duel contre un adversaire réglé dans Studio (decks), utilisable sans évènement
# (Ligue de Triple Triad du plugin Tournoi, défis de l'appli Amis du téléphone).
module TripleTriad
  module_function

  # @param scene [#call_scene] scène qui lance les écrans (Scene_Map, tableau du Tournoi…)
  # @param deck_id [Symbol, String] adversaire (Studio : Mini-jeux > Triple Triad > Adversaires)
  # @param bonus [Integer] niveaux de cartes en plus (revanches : l'adversaire progresse) ; 0 : cartes du deck
  # @param extra_rules [Array<Symbol>] règles en plus
  # @return [Integer] 1 victoire, 2 défaite, 3 égalité, 0 abandon / pas assez de cartes
  def play_deck(scene, deck_id, bonus: 0, extra_rules: [])
    tt = TripleTriad
    deck = tt.deck(deck_id)
    return 0 unless deck

    if tt.total_count < tt::HAND_SIZE
      $scene.display_message_and_wait(tt.t("Il te faut au moins #{tt::HAND_SIZE} cartes pour jouer.", "You need at least #{tt::HAND_SIZE} cards to play."))
      return 0
    end
    rules = (Array(deck[:rules]).map(&:to_sym) | Array(extra_rules).map(&:to_sym))
    hand = rules.include?(:random) ? tt.random_hand : nil
    scene.call_scene(GamePlay::TripleTriadCards, :hand) { |s| hand = s.hand } unless hand
    return 0 unless hand

    min_level = [deck[:min_level].to_i + bonus.to_i, 9].min
    max_level = [(deck[:max_level] || 9).to_i + bonus.to_i, 9].min
    cards = Array(deck[:cards]).map(&:to_sym).reject { |s| s.to_s.empty? }
    cards = [] if bonus.to_i > 0
    opponent = cards.dup
    opponent += tt.opponent_hand(min_level, max_level) while opponent.size < tt::HAND_SIZE
    result = 0
    scene.call_scene(GamePlay::TripleTriadDuel, deck[:name].to_s, hand, opponent.first(tt::HAND_SIZE), rules) { |s| result = s.result }
    tt.last_result = result
    return result
  end

  # @return [Boolean] le joueur peut jouer un duel (assez de cartes)
  def can_play?
    return total_count >= HAND_SIZE
  end
end
