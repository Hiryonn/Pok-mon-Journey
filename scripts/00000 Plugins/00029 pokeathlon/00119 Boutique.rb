# Pokéathlon : boutique du jour (plugin magasins) et monnaie « pokeathlon » (points Pokéathlon)
#
# Le magasin « pokeathlon » (comptoir) est créé à partir de la liste du jour de la semaine (réglage shop), sauf si un
# magasin du même identifiant est réglé dans Studio (Magasins). La monnaie « pokeathlon » utilise les points.
module Pokeathlon
  module_function

  # @return [Array<Hash>] articles du jour { item:, price: }
  def shop_items(wday = Time.now.wday)
    own = config.shop.is_a?(Hash) && !config.shop.empty? ? config.shop : DEFAULT_SHOP
    list = fetch(own, wday.to_s)
    return Array(list).select { |e| e.is_a?(Hash) && !fetch(e, 'item').to_s.empty? }.map do |e|
      { 'type' => 'item', 'item' => fetch(e, 'item').to_s, 'price' => fetch(e, 'price').to_i }
    end
  end

  SHOP_CURRENCY = { 'id' => 'pokeathlon', 'kind' => 'pokeathlon', 'symbol' => 'pts',
                    'name' => { 'fr' => 'Points', 'en' => 'Points' } }.freeze

  def shop_data
    return { 'id' => 'pokeathlon', 'name' => { 'fr' => 'Boutique du Pokéathlon', 'en' => 'Pokéathlon Shop' }, 'kind' => 'list',
             'currency' => 'pokeathlon', 'restock' => { 'mode' => 'never' }, 'entries' => shop_items }
  end
end

if defined?(Magasins)
  module Magasins
    module PokeathlonShop
      def shop(id)
        found = super
        return found if found || id.to_s != 'pokeathlon'

        return Pokeathlon.shop_data
      end

      def currency(id)
        return Pokeathlon::SHOP_CURRENCY if id.to_s == 'pokeathlon' &&
                                            Array(config.currencies).none? { |c| c.is_a?(Hash) && fetch(c, :id).to_s == 'pokeathlon' }

        return super
      end

      def funds(cur)
        return Pokeathlon.points if fetch(cur, :kind).to_s == 'pokeathlon'

        return super
      end

      def pay(cur, amount)
        return Pokeathlon.data['points'] = [Pokeathlon.points - amount.to_i, 0].max if fetch(cur, :kind).to_s == 'pokeathlon'

        return super
      end
    end
    singleton_class.prepend(PokeathlonShop)
  end
end
