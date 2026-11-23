# Monnaie « points » (kind: points) : un compteur sauvegardé par monnaie, sans variable du jeu à choisir.
# Sert aux Points Combat du Tour de Combat (plugin Tournoi), monnaie d'identifiant « pco ».
module Magasins
  # @return [Hash{String => Integer}] points de chaque monnaie
  def self.points
    game = PFM.game_state
    return game.instance_variable_get(:@pj_points) || game.instance_variable_set(:@pj_points, {})
  end

  class << self
    module PointsCurrency
      def funds(cur)
        return points[fetch(cur, :id).to_s].to_i if fetch(cur, :kind).to_s == 'points'

        return super
      end

      def pay(cur, amount)
        return super unless fetch(cur, :kind).to_s == 'points'

        key = fetch(cur, :id).to_s
        points[key] = [points[key].to_i - amount.to_i, 0].max
      end
    end
    prepend PointsCurrency
  end
end
