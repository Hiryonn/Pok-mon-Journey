# Magasins (d'après « Arcky's Poke Market », Essentials) : comptoirs, étalages avec panier et caisse
#
# Réglages faits dans Studio (Level design > Magasins) : Data/configs/plugins/magasins.json
#   currencies  monnaies : { id:, name: { fr:, en: }, symbol:, kind: money | coins | variable, variable: }
#   sellers     vendeurs : { id:, name:, lines: { welcome: { fr: [], en: [] }, … } } (une phrase tirée au hasard)
#   shops       magasins : { id:, name:, kind: list | shelf, currency:, seller:, modifier: (% : -20 = remise),
#               modifier_switch:, restock: { mode: never | daily | hours, hours: }, entries: [], bonus: [] }
#     entries   { type: item | pokemon, item: / species:, form:, level:, shiny:, price:, stock:, badges:, switch:, modifier: }
#     bonus     { buy:, count:, give:, amount:, repeat: } (ex. 10 Poké Balls achetées = 1 Honor Ball offerte)
# Comptoir (list) : catégories (poches du sac, Pokémon) à gauche / droite, quantité, confirmation, vente.
# Étalage (shelf) : les objets sont posés sur 3 rayons ; on remplit un panier, payé à la caisse (magasin_caisse).
module Configs
  class MagasinsConfig
    attr_accessor :currencies, :sellers, :shops, :money_speed

    def initialize
      @currencies = []
      @sellers = []
      @shops = []
      @money_speed = 12
    end
  end
  register(:magasins, 'plugins/magasins', :json, false, MagasinsConfig)
end

module Magasins
  CONFIG_FILE = 'Data/configs/plugins/magasins.json'
  DIR = 'magasins/'
  # Poches du sac (catégories du comptoir) : poche PSDK => [français, anglais]
  POCKETS = {
    1 => %w[Objets Items], 6 => %w[Soins Medicine], 2 => ['Poké Balls', 'Poké Balls'], 3 => ['CT & CS', 'TMs & HMs'],
    4 => %w[Baies Berries], 8 => ['Objets de combat', 'Battle items'], 7 => %w[Lettres Mail], 5 => ['Objets rares', 'Key items']
  }.freeze
  POKEMON_POCKET = 0
  MAX_ITEMS = 999
  # Phrases par défaut des vendeurs ({item}, {qty}, {price}, {total}, {currency}, {bonus}, {player}, {count})
  DEFAULT_LINES = {
    welcome: [['Bienvenue ! Que puis-je pour toi ?'], ['Welcome! How may I help you?']],
    ask_quantity: [['{item} ? Combien en veux-tu ?'], ['{item}? How many would you like?']],
    confirm: [['{qty} {item}, ça fera {total} {currency}. D\'accord ?'], ['{qty} {item} will be {total} {currency}. OK?']],
    thanks: [['Merci beaucoup !'], ['Thank you very much!']],
    no_money: [['Tu n\'as pas assez d\'argent.'], ['You don\'t have enough money.']],
    out_of_stock: [['Désolé, il n\'y en a plus en stock.'], ['Sorry, that\'s out of stock.']],
    bonus: [['En cadeau, voici aussi {bonus} !'], ['Here, take {bonus} as a bonus!']],
    goodbye: [['À bientôt !'], ['Please come again!']],
    bag_full: [['Tu ne peux pas en porter plus.'], ['You can\'t carry any more.']],
    sell: [['Que veux-tu me vendre ?'], ['What would you like to sell?']]
  }.freeze

  module_function

  # @return [Configs::MagasinsConfig]
  def config
    @config ||= begin
      if PSDK_CONFIG.release?
        Configs.magasins
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        cfg = Configs::MagasinsConfig.new
        data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
        cfg
      else
        Configs::MagasinsConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Magasins : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::MagasinsConfig.new
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

  def french?
    return !($options && $options.language.to_s != 'fr')
  end

  def t(fr, en = fr)
    return french? ? fr : en
  end

  # Texte réglé dans Studio ({ fr:, en: } ou texte simple)
  def localized(value)
    return value.to_s unless value.is_a?(Hash)

    text = fetch(value, french? ? 'fr' : 'en')
    text = fetch(value, :fr) if text.to_s.empty?
    text = fetch(value, :en) if text.to_s.empty?
    return text.to_s
  end

  def file(name)
    return "#{DIR}#{name}"
  end

  # --- Magasins ------------------------------------------------------------------------------------
  # @return [Hash, nil]
  def shop(id)
    return Array(config.shops).find { |s| s.is_a?(Hash) && fetch(s, :id).to_s == id.to_s }
  end

  def shop_name(shop)
    return localized(fetch(shop, :name))
  end

  # --- Monnaies -------------------------------------------------------------------------------------
  DEFAULT_CURRENCY = { 'id' => 'money', 'kind' => 'money', 'symbol' => 'P', 'name' => { 'fr' => 'Argent', 'en' => 'Money' } }.freeze

  def currency(id)
    found = Array(config.currencies).find { |c| c.is_a?(Hash) && fetch(c, :id).to_s == id.to_s }
    return found || (id.to_s == 'coins' ? { 'id' => 'coins', 'kind' => 'coins', 'symbol' => 'J', 'name' => { 'fr' => 'Jetons', 'en' => 'Coins' } } : DEFAULT_CURRENCY)
  end

  def shop_currency(shop)
    return currency(fetch(shop, :currency) || 'money')
  end

  def currency_name(cur)
    return localized(fetch(cur, :name))
  end

  def currency_symbol(cur)
    return fetch(cur, :symbol).to_s
  end

  # @return [Integer] ce que le joueur possède
  def funds(cur)
    case fetch(cur, :kind).to_s
    when 'coins' then $game_variables[Yuki::Var::CoinCase].to_i
    when 'variable' then $game_variables[fetch(cur, :variable).to_i].to_i
    else PFM.game_state.money.to_i
    end
  end

  def pay(cur, amount)
    amount = amount.to_i
    case fetch(cur, :kind).to_s
    when 'coins' then $game_variables[Yuki::Var::CoinCase] = [funds(cur) - amount, 0].max
    when 'variable' then $game_variables[fetch(cur, :variable).to_i] = [funds(cur) - amount, 0].max
    else PFM.game_state.lose_money(amount)
    end
  end

  def receive(cur, amount)
    return PFM.game_state.add_money(amount.to_i) if fetch(cur, :kind).to_s == 'money'

    pay(cur, -amount.to_i)
  end

  # 1200 -> « 1 200 »
  def number(value)
    text = value.to_i.abs.to_s.reverse.scan(/\d{1,3}/).join(t(' ', ',')).reverse
    return value.to_i < 0 ? "-#{text}" : text
  end

  def amount_text(cur, value)
    symbol = currency_symbol(cur)
    return symbol.empty? ? number(value) : "#{number(value)} #{symbol}"
  end

  # --- Articles ------------------------------------------------------------------------------------
  # @return [String] clé de l'article (stock, panier)
  def entry_key(entry)
    return fetch(entry, :type).to_s == 'pokemon' ? "pokemon:#{fetch(entry, :species)}:#{fetch(entry, :form).to_i}:#{fetch(entry, :level).to_i}" : "item:#{fetch(entry, :item)}"
  end

  def pokemon?(entry)
    return fetch(entry, :type).to_s == 'pokemon'
  end

  def entry_name(entry)
    if pokemon?(entry)
      creature = data_creature(fetch(entry, :species).to_s.to_sym)
      return "#{creature.name} #{t('N.', 'Lv.')}#{[fetch(entry, :level).to_i, 1].max}"
    end
    return data_item(fetch(entry, :item).to_s.to_sym).name
  rescue StandardError
    return '???'
  end

  def entry_descr(entry)
    return data_item(fetch(entry, :item).to_s.to_sym).descr.to_s unless pokemon?(entry)

    creature = data_creature(fetch(entry, :species).to_s.to_sym)
    return creature.descr.to_s
  rescue StandardError
    return ''
  end

  # Catégorie (poche du sac, 0 = Pokémon)
  def entry_pocket(entry)
    return POKEMON_POCKET if pokemon?(entry)

    return data_item(fetch(entry, :item).to_s.to_sym).socket.to_i
  rescue StandardError
    return 1
  end

  def pocket_name(pocket)
    return t('Pokémon', 'Pokémon') if pocket == POKEMON_POCKET

    names = POCKETS[pocket] || POCKETS[1]
    return t(names[0], names[1])
  end

  # Article visible ? (badges, interrupteur)
  def available?(entry)
    return false if pokemon?(entry) ? fetch(entry, :species).to_s.empty? : fetch(entry, :item).to_s.empty?
    return false if fetch(entry, :badges).to_i > 0 && $trainer.badge_counter.to_i < fetch(entry, :badges).to_i
    return false if fetch(entry, :switch).to_i > 0 && !$game_switches[fetch(entry, :switch).to_i]
    return false if !pokemon?(entry) && data_item(fetch(entry, :item).to_s.to_sym).db_symbol == :__undef__

    return true
  rescue StandardError
    return false
  end

  # @return [Array<Hash>]
  def entries(shop)
    return Array(fetch(shop, :entries)).select { |e| e.is_a?(Hash) && available?(e) }
  end

  # Remise / majoration en % (négatif = remise)
  def modifier(shop, entry)
    own = fetch(entry, :modifier)
    return own.to_i unless own.nil? || own.to_s.empty?

    switch = fetch(shop, :modifier_switch).to_i
    return 0 if switch > 0 && !$game_switches[switch]

    return fetch(shop, :modifier).to_i
  end

  def base_price(entry)
    price = fetch(entry, :price)
    return price.to_i unless price.nil? || price.to_s.empty?
    return 0 if pokemon?(entry)

    return data_item(fetch(entry, :item).to_s.to_sym).price.to_i
  rescue StandardError
    return 0
  end

  # @return [Integer] prix à l'unité (avec remise / majoration)
  def price(shop, entry)
    base = base_price(entry)
    mod = modifier(shop, entry)
    return base if mod == 0

    return [(base * (100 + mod) / 100.0).round, base > 0 ? 1 : 0].max
  end

  # --- Stocks --------------------------------------------------------------------------------------
  def save_data
    return { stock: {}, restock: {}, basket: [] } unless $user_data

    data = $user_data[:pj_magasins] ||= {}
    data[:stock] ||= {}
    data[:restock] ||= {}
    data[:basket] ||= []
    return data
  end

  # Réassort : remet les stocks à zéro quand le délai est passé
  def check_restock(shop)
    id = fetch(shop, :id).to_s
    restock = fetch(shop, :restock) || {}
    mode = fetch(restock, :mode).to_s
    data = save_data
    now = Time.now
    last = data[:restock][id]
    reset = case mode
            when 'daily' then last && Time.at(last).strftime('%Y%m%d') != now.strftime('%Y%m%d')
            when 'hours' then last && now.to_i - last >= [fetch(restock, :hours).to_i, 1].max * 3600
            else false
            end
    data[:stock].delete(id) if reset
    data[:restock][id] = now.to_i if reset || !last
  rescue StandardError
    nil
  end

  # @return [Integer, nil] nombre restant (nil = illimité)
  def remaining(shop, entry)
    stock = fetch(entry, :stock)
    return nil if stock.nil? || stock.to_s.empty?

    bought = save_data[:stock].dig(fetch(shop, :id).to_s, entry_key(entry)).to_i
    return [stock.to_i - bought, 0].max
  end

  def take_stock(shop, entry, count)
    return if remaining(shop, entry).nil?

    shop_stock = save_data[:stock][fetch(shop, :id).to_s] ||= {}
    shop_stock[entry_key(entry)] = shop_stock[entry_key(entry)].to_i + count
  end

  # --- Bonus ---------------------------------------------------------------------------------------
  # @return [Array<Array(Symbol, Integer)>] objets offerts pour cet achat
  def bonuses(shop, entry, count)
    return [] if pokemon?(entry)

    item = fetch(entry, :item).to_s
    return Array(fetch(shop, :bonus)).filter_map do |bonus|
      next unless bonus.is_a?(Hash) && fetch(bonus, :buy).to_s == item

      need = [fetch(bonus, :count).to_i, 1].max
      next if count < need

      times = fetch(bonus, :repeat) == false ? 1 : count / need
      give = fetch(bonus, :give).to_s
      next if give.empty? || data_item(give.to_sym).db_symbol == :__undef__

      [give.to_sym, [fetch(bonus, :amount).to_i, 1].max * times]
    end
  end

  def bonus_text(list)
    return list.map { |item, n| n > 1 ? "#{data_item(item).name} x#{n}" : data_item(item).name }.join(', ')
  end

  # --- Achat ---------------------------------------------------------------------------------------
  # @return [Integer] quantité maximale achetable (argent, stock, place dans le sac)
  def max_quantity(shop, entry, already = 0)
    unit = price(shop, entry)
    cur = shop_currency(shop)
    max = unit > 0 ? (funds(cur) - already) / unit : 99
    left = remaining(shop, entry)
    max = [max, left].min if left
    max = [max, 1].min if pokemon?(entry)
    max = [max, MAX_ITEMS - $bag.item_quantity(fetch(entry, :item).to_s.to_sym)].min unless pokemon?(entry)
    return [[max, 99].min, 0].max
  end

  # Donne l'article (objets ou Pokémon) ; bonus compris
  # @return [Array<Array(Symbol, Integer)>] bonus donnés
  def give(shop, entry, count)
    if pokemon?(entry)
      count.times do
        species = data_creature(fetch(entry, :species).to_s.to_sym).id
        pokemon = PFM::Pokemon.generate_from_hash(id: species, level: [fetch(entry, :level).to_i, 1].max,
                                                  form: fetch(entry, :form).to_i, shiny: fetch(entry, :shiny) == true)
        PFM.game_state.add_pokemon(pokemon)
      end
      take_stock(shop, entry, count)
      return []
    end
    $bag.add_item(fetch(entry, :item).to_s.to_sym, count)
    # Baies achetées : insigne Gourmet (plugin Souvenirs)
    if defined?(::Mementos)
      ::Mementos.safely('boutique') { ::Mementos.berries_gained! if ::Mementos.berry?(fetch(entry, :item).to_s.to_sym) }
    end
    take_stock(shop, entry, count)
    extra = bonuses(shop, entry, count)
    extra.each { |item, n| $bag.add_item(item, n) }
    return extra
  end

  # --- Vendeurs ------------------------------------------------------------------------------------
  def seller(id)
    return Array(config.sellers).find { |s| s.is_a?(Hash) && fetch(s, :id).to_s == id.to_s }
  end

  # Phrase du vendeur (au hasard parmi celles réglées), avec les {valeurs}
  def line(seller, key, values = {})
    lines = seller && fetch(fetch(seller, :lines), key)
    list = lines.is_a?(Hash) ? Array(fetch(lines, french? ? 'fr' : 'en')) : Array(lines)
    list = Array(fetch(lines, :fr)) if list.reject { |l| l.to_s.strip.empty? }.empty? && lines.is_a?(Hash)
    list = list.map(&:to_s).reject { |l| l.strip.empty? }
    if list.empty?
      default = DEFAULT_LINES[key.to_sym] || [[''], ['']]
      list = french? ? default[0] : default[1]
    end
    text = list.sample.to_s
    values = { player: $trainer&.name.to_s }.merge(values)
    return text.gsub(/\{(\w+)\}/) { values.key?(Regexp.last_match(1).to_sym) ? values[Regexp.last_match(1).to_sym].to_s : Regexp.last_match(0) }
  end

  # --- Panier (étalages) ---------------------------------------------------------------------------
  # @return [Array<Hash>] [{ shop:, key:, qty: }]
  def basket
    return save_data[:basket]
  end

  def basket_entry(shop, entry)
    return basket.find { |b| b[:shop] == fetch(shop, :id).to_s && b[:key] == entry_key(entry) }
  end

  def basket_quantity(shop, entry)
    return basket_entry(shop, entry)&.dig(:qty).to_i
  end

  def set_basket(shop, entry, qty)
    line = basket_entry(shop, entry)
    if qty <= 0
      basket.delete(line)
    elsif line
      line[:qty] = qty
    else
      basket << { shop: fetch(shop, :id).to_s, key: entry_key(entry), qty: qty }
    end
  end

  # Articles du panier encore valables : [[magasin, article, quantité]]
  def basket_lines
    return basket.filter_map do |b|
      s = shop(b[:shop])
      e = s && entries(s).find { |x| entry_key(x) == b[:key] }
      e ? [s, e, b[:qty].to_i] : nil
    end
  end

  # Total du panier par monnaie : { id de la monnaie => total }
  def basket_totals(except = nil)
    totals = Hash.new(0)
    basket_lines.each do |s, e, qty|
      next if except && except == [fetch(s, :id).to_s, entry_key(e)]

      totals[fetch(shop_currency(s), :id).to_s] += price(s, e) * qty
    end
    return totals
  end

  def basket_count
    return basket_lines.sum { |_s, _e, qty| qty }
  end

  def clear_basket
    basket.clear
  end

  # Paye le panier à la caisse : true si payé
  # @return [Symbol] :empty, :no_money ou :ok
  def checkout
    lines = basket_lines
    return :empty if lines.empty?

    totals = basket_totals
    return :no_money if totals.any? { |cur, total| funds(currency(cur)) < total }

    totals.each { |cur, total| pay(currency(cur), total) }
    @last_bonus = lines.flat_map { |s, e, qty| give(s, e, qty) }
    clear_basket
    return :ok
  end

  # Bonus du dernier passage en caisse
  def last_bonus
    return @last_bonus || []
  end
end
