# Triple Triad : plateau, captures (normale, Pareil, Pareil mur, Plus, combo), Éléments et IA
module TripleTriad
  # Une carte posée sur le plateau
  Slot = Struct.new(:card, :owner)

  class Game
    # Côtés : 0 haut, 1 droite, 2 bas, 3 gauche ; [décalage de case, côté opposé]
    NEIGHBORS = { 0 => [-3, 2], 1 => [1, 3], 2 => [3, 0], 3 => [-1, 1] }.freeze

    # @return [Array<Slot, nil>] les 9 cases
    attr_reader :board
    # @return [Array<Symbol, nil>] type des cases (règle Éléments)
    attr_reader :elements
    # @return [Array<Symbol>] règles
    attr_reader :rules

    # @param rules [Array<Symbol>]
    def initialize(rules)
      @rules = rules
      @board = Array.new(9)
      @elements = Array.new(9)
      init_elements if rule?(:elements)
    end

    # @param name [Symbol]
    def rule?(name)
      return @rules.include?(name)
    end

    # @return [Array<Integer>] cases libres
    def free_cells
      return (0...9).select { |i| @board[i].nil? }
    end

    # @return [Boolean]
    def full?
      return @board.none?(&:nil?)
    end

    # @param owner [Integer] 0 joueur, 1 adversaire
    # @return [Integer] cartes du plateau à ce joueur
    def owned(owner)
      return @board.count { |slot| slot&.owner == owner }
    end

    # Case voisine d'un côté (nil au bord)
    # @param cell [Integer]
    # @param side [Integer]
    # @return [Integer, nil]
    def neighbor(cell, side)
      return nil if side == 0 && cell < 3
      return nil if side == 2 && cell > 5
      return nil if side == 3 && cell % 3 == 0
      return nil if side == 1 && cell % 3 == 2

      return cell + NEIGHBORS[side][0]
    end

    # Valeur d'un côté d'une carte posée (avec le bonus Éléments)
    # @param cell [Integer]
    # @param side [Integer]
    # @return [Integer]
    def value_at(cell, side)
      slot = @board[cell]
      value = slot.card.value(side)
      element = @elements[cell]
      value += slot.card.type == element ? 1 : -1 if element
      return value.clamp(1, 10)
    end

    # Pose une carte et applique les captures
    # @param cell [Integer]
    # @param card [Card]
    # @param owner [Integer]
    # @return [Array<Array>] captures dans l'ordre : [case, :normal / :same / :plus / :combo]
    def place(cell, card, owner)
      @board[cell] = Slot.new(card, owner)
      flips = []
      special = []
      special.concat(same_captures(cell, owner)) if rule?(:same) || rule?(:samewall)
      plus = rule?(:plus) ? plus_captures(cell, owner) : []
      special.concat(plus.map { |c| [c, :plus] })
      special.uniq! { |c, _| c }
      special.each do |c, kind|
        @board[c].owner = owner
        flips << [c, kind]
      end
      basic_captures(cell, owner).each do |c|
        next if flips.any? { |f, _| f == c }

        @board[c].owner = owner
        flips << [c, :normal]
      end
      # combo : les cartes prises par Pareil / Plus capturent à leur tour
      queue = special.map(&:first)
      until queue.empty?
        from = queue.shift
        basic_captures(from, owner).each do |c|
          @board[c].owner = owner
          flips << [c, :combo]
          queue << c
        end
      end
      return flips
    end

    # Copie pour l'IA
    # @return [Game]
    def dup_game
      copy = Game.new(@rules)
      copy.instance_variable_set(:@board, @board.map { |s| s && Slot.new(s.card, s.owner) })
      copy.instance_variable_set(:@elements, @elements.dup)
      return copy
    end

    # Meilleur coup de l'adversaire : le plus de cartes possédées, puis les côtés exposés les plus forts
    # @param hand [Array<Card>]
    # @param owner [Integer]
    # @return [Array(Integer, Integer)] index de la carte, case
    def best_move(hand, owner)
      best = nil
      best_score = nil
      hand.each_with_index do |card, index|
        free_cells.each do |cell|
          game = dup_game
          game.place(cell, card, owner)
          score = game.owned(owner) * 100 + game.exposure_score(cell, owner) - card.total + rand(3)
          next if best_score && score <= best_score

          best_score = score
          best = [index, cell]
        end
      end
      return best
    end

    # Sécurité d'une carte posée : valeur de ses côtés tournés vers des cases libres
    # @return [Integer]
    def exposure_score(cell, _owner)
      return (0..3).sum { |side| (n = neighbor(cell, side)) && @board[n].nil? ? value_at(cell, side) : 10 }
    end

    private

    def init_elements
      types = %i[fire water grass electric ice fighting poison ground flying psychic bug rock ghost dragon dark steel fairy]
      (0...9).to_a.sample(rand(1..4)).each { |cell| @elements[cell] = types.sample }
    end

    # @return [Array<Integer>] cases adverses battues normalement
    def basic_captures(cell, owner)
      return (0..3).filter_map do |side|
        n = neighbor(cell, side)
        next nil unless n && @board[n] && @board[n].owner != owner

        value_at(cell, side) > value_at(n, NEIGHBORS[side][1]) ? n : nil
      end
    end

    # @return [Array<Array>] [case, :same] si 2 côtés ou plus sont égaux (les murs comptent avec Pareil mur)
    def same_captures(cell, owner)
      matches = []
      walls = 0
      (0..3).each do |side|
        n = neighbor(cell, side)
        if n.nil?
          walls += 1 if rule?(:samewall) && value_at(cell, side) == 10
          next
        end
        next unless @board[n]

        matches << n if value_at(cell, side) == value_at(n, NEIGHBORS[side][1])
      end
      return [] if matches.size + walls < 2

      return matches.select { |n| @board[n].owner != owner }.map { |n| [n, :same] }
    end

    # @return [Array<Integer>] cases adverses prises par Plus (au moins 2 sommes égales)
    def plus_captures(cell, owner)
      sums = Hash.new { |h, k| h[k] = [] }
      (0..3).each do |side|
        n = neighbor(cell, side)
        next unless n && @board[n]

        sums[value_at(cell, side) + value_at(n, NEIGHBORS[side][1])] << n
      end
      return sums.values.select { |cells| cells.size >= 2 }.flatten.select { |n| @board[n].owner != owner }
    end
  end
end
