# Casino JP : la machine à sous « version japonaise » (graphismes graphics/interface/casino_jp, voir tools/casino-jp)
# C'est une machine alternative : elle ne remplace pas casino(:slotmachine, vitesse) du jeu, elle se lance avec
#   casino_jp(vitesse)        (voir 00102 Commandes.rb)
#
# Règles : on mise 1, 2 ou 3 jetons ; A lance les rouleaux, puis A arrête les rouleaux un par un (de gauche à droite).
# Le résultat est tiré au sort au lancement (selon OUTCOMES) ; l'arrêt des rouleaux le fait apparaître sur la ligne du milieu.
# Gain = gain du symbole x mise. Trois « Replay » : la partie suivante est gratuite.
# Les jetons sont ceux du jeu : la variable COIN_VARIABLE (comme les évents de la salle de jeux).
module CasinoJp
  # Variable du jeu qui contient les jetons
  COIN_VARIABLE = 41
  # Maximum de jetons (5 chiffres à l'écran)
  MAX_COINS = 99_999
  # Mises possibles
  BETS = [1, 2, 3].freeze
  # Vitesse des rouleaux : pixels par image = vitesse * SPEED_UNIT (vitesse = argument de casino_jp)
  SPEED_UNIT = 2
  # Symboles : numéro de l'image s<n>.png
  BERRY = 0
  PIKACHU = 1
  SEVEN = 2
  MARILL = 3
  REPLAY = 4
  # Ordre des symboles sur chaque rouleau (20 cases, tournent vers le bas)
  STRIP = [0, 3, 0, 4, 1, 0, 3, 0, 2, 4, 0, 1, 3, 0, 4, 1, 0, 3, 2, 4].freeze
  # Gain par jeton misé (Replay : partie gratuite, aucun gain)
  PAYOUT = { BERRY => 2, MARILL => 5, PIKACHU => 10, SEVEN => 50 }.freeze
  # Chances de chaque résultat à chaque partie, en pour mille (le reste : perdu).
  # Avec ces valeurs, la machine rend environ 90 % des jetons misés.
  OUTCOMES = { BERRY => 120, MARILL => 40, PIKACHU => 20, SEVEN => 4, REPLAY => 60 }.freeze
  # Sons (noms dans audio/se/, nil = aucun)
  SE_START = nil
  SE_STOP = nil
  SE_WIN = nil

  # Taille d'une case de rouleau (pixels)
  CELL = 28
  # Hauteur de la fenêtre d'un rouleau
  WINDOW_HEIGHT = 72

  module_function

  # Tire le résultat d'une partie
  # @param random [Integer, nil] nombre de 0 à 999 (au hasard si nil)
  # @return [Integer, nil] symbole gagnant, nil si perdu
  def draw_outcome(random = nil)
    random ||= rand(1000)
    OUTCOMES.each do |symbol, chance|
      return symbol if random < chance

      random -= chance
    end
    return nil
  end

  # Symbole de la case n du rouleau
  # @param index [Integer]
  # @return [Integer]
  def symbol_at(index)
    return STRIP[index % STRIP.size]
  end

  # Case où le rouleau s'arrête (la case de la ligne du milieu est alors strip[case])
  # @param position [Float] position du rouleau (en cases, augmente en tournant)
  # @param symbol [Integer, nil] symbole à avoir au milieu (nil : aucun en particulier)
  # @param avoid [Integer, nil] symbole à éviter (pour que la partie ne soit pas gagnante par hasard)
  # @return [Integer] numéro de case (>= position)
  def stop_index(position, symbol = nil, avoid = nil)
    index = position.ceil
    STRIP.size.times do
      stripped = symbol_at(index)
      return index if (symbol.nil? || stripped == symbol) && (avoid.nil? || stripped != avoid)

      index += 1
    end
    return position.ceil
  end

  # Case où s'arrête un rouleau quand le joueur appuie sur A
  # @param position [Float] position du rouleau à ce moment
  # @param outcome [Integer, nil] résultat tiré au sort (symbole gagnant, nil : perdu)
  # @param previous [Array<Integer>] cases d'arrêt des rouleaux déjà arrêtés
  # @return [Integer]
  def stop_for(position, outcome, previous = [])
    # sans gain prévu, le 3e rouleau évite de former une ligne gagnante
    avoid = (outcome.nil? && previous.size == 2 && symbol_at(previous[0]) == symbol_at(previous[1])) ? symbol_at(previous[0]) : nil
    return stop_index(position, outcome, avoid)
  end

  # @param indexes [Array<Integer>] cases d'arrêt
  # @return [Integer, nil] symbole de la ligne du milieu si les trois sont identiques
  def line_symbol(indexes)
    symbols = indexes.map { |i| symbol_at(i) }
    return symbols.uniq.size == 1 ? symbols[0] : nil
  end

  # @param symbol [Integer, nil]
  # @param bet [Integer]
  # @return [Integer] jetons gagnés
  def payout(symbol, bet)
    return (PAYOUT[symbol] || 0) * bet
  end

  # @return [Integer] jetons du joueur
  def coins
    return $game_variables ? $game_variables[COIN_VARIABLE].to_i : 0
  end

  # @param value [Integer]
  def coins=(value)
    $game_variables[COIN_VARIABLE] = value.clamp(0, MAX_COINS) if $game_variables
  end
end
