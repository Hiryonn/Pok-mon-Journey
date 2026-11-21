# Pokéblocs : la Boîte (sauvegardée dans la partie), les mélanges et l'effet sur les conditions
# Un Pokébloc est un Hash simple (sauvegarde sans classe) :
#   { 'color' => 'red', 'flavors' => [épicé, sec, sucré, amer, acide], 'feel' => douceur, 'plus' => false }
module Pokeblocs
  module_function

  # --- Boîte --------------------------------------------------------------------------------------------------------
  # @return [Array<Hash>]
  def blocks
    state = PFM.game_state
    return state.instance_variable_get(:@pj_pokeblocs) || state.instance_variable_set(:@pj_pokeblocs, [])
  end

  def capacity
    return setting('max_blocks').to_i
  end

  def full?
    return capacity > 0 && blocks.size >= capacity
  end

  # @param color [String, Symbol]
  # @param flavors [Array<Integer>]
  # @return [Hash]
  def make(color, flavors, feel = 0, plus = false)
    color = color.to_s.downcase.delete(' _')
    color = 'red' unless COLORS.key?(color)
    values = Array(flavors).first(5).map(&:to_i)
    values += [0] * (5 - values.size)
    return { 'color' => color, 'flavors' => values, 'feel' => feel.to_i.clamp(0, 255), 'plus' => plus ? true : false }
  end

  # @return [Boolean] false si la Boîte est pleine
  def add(block)
    return false if full?

    blocks << block
    sort!
    return true
  end

  def remove(block)
    index = blocks.index { |other| other.equal?(block) } || blocks.index(block)
    blocks.delete_at(index) if index
  end

  def sort!
    blocks.sort_by! { |b| [COLORS.dig(b['color'], 2).to_i, -level(b), b['plus'] ? 0 : 1] }
  end

  def level(block)
    return Array(block['flavors']).max.to_i
  end

  def color_name(block_or_color)
    color = block_or_color.is_a?(Hash) ? block_or_color['color'] : block_or_color.to_s
    names = COLORS[color] || COLORS['red']
    return fr? ? names[0] : names[1]
  end

  # « Pokébloc Rouge + »
  def name(block)
    plus = block['plus'] ? ' +' : ''
    return fr? ? "Pokébloc #{color_name(block)}#{plus}" : "#{color_name(block)} Pokéblock#{plus}"
  end

  # Nom au pluriel : « 3 Pokéblocs Rouges + »
  def plural(block, count)
    return "#{count} #{name(block)}" if count <= 1 || !fr?

    color = color_name(block)
    color = PLURAL_FR[color] || color
    return "#{count} Pokéblocs #{color}#{block['plus'] ? ' +' : ''}"
  end

  PLURAL_FR = { 'Rouge' => 'Rouges', 'Bleu' => 'Bleus', 'Rose' => 'Roses', 'Vert' => 'Verts', 'Jaune' => 'Jaunes',
                'Violet' => 'Violets', 'Blanc' => 'Blancs', 'Noir' => 'Noirs' }.freeze

  def icon(block)
    return file("blocs/#{block['color']}")
  end

  def big_icon(block)
    base = "blocs/grand_#{block['color']}"
    plus = "#{base}_plus"
    return file(plus) if block['plus'] && RPG::Cache.interface_exist?(file(plus))

    return file(base)
  end

  # --- Mixeur à jouer (Rubis / Saphir / Émeraude) -------------------------------------------------------------------
  # @param berries [Array<Symbol>] baies des joueurs (la première est celle du joueur)
  # @param max_rpm [Numeric] vitesse maximale atteinte (tr/min)
  # @param fail [Boolean] Pokébloc raté (Noir)
  # @return [Hash] le Pokébloc
  def rse_blend(berries, max_rpm, fail = false)
    feel = berries.empty? ? 0 : berries.sum { |b| smoothness(b) } / berries.size - berries.size
    feel = feel.clamp(0, 99)
    return black(feel) if fail || berries.uniq.size != berries.size

    sum = [0, 0, 0, 0, 0]
    berries.each do |berry|
      f = flavors(berry)
      5.times { |i| sum[i] += f[i] - f[(i + 1) % 5] }
    end
    negatives = sum.count(&:negative?)
    sum.map! { |v| [v - negatives, 0].max }
    factor = max_rpm.to_f >= 110 ? 1.33 : (max_rpm.to_f / 333 + 1).round(2)
    sum.map! { |v| (v * factor).round }
    positive = sum.count(&:positive?)
    return black(feel) if positive == 0

    strongest = sum.index(sum.max)
    color = case positive
            when 1 then sum.max > 50 ? 'gold' : SINGLE[strongest]
            when 2 then sum.max > 50 ? 'gold' : DOUBLE[strongest]
            when 3 then 'gray'
            else 'white'
            end
    return make(color, sum, feel)
  end

  # Pokébloc Noir : 3 saveurs au hasard à 2
  def black(feel)
    values = [0, 0, 0, 0, 0]
    [0, 1, 2, 3, 4].sample(3).each { |i| values[i] = 2 }
    return make('black', values, feel)
  end

  # Baies des autres joueurs (celles qui complètent la vôtre, ou au hasard)
  # @param berry [Symbol] baie du joueur
  # @param players [Integer] 1 à 3 autres joueurs, 4 : Maître Baies
  # @return [Array<Symbol>]
  def npc_berries(berry, players)
    return [] if players <= 0

    if setting('npc_random')
      return [pick_existing(Array(setting('master_berries')))].compact if players == 4

      pool = all_berries
      return Array.new(players) { pool.sample }.compact
    end
    key = berry.to_s.delete('_').sub(/berry\z/, '')
    if players == 4
      return [existing(MASTER_SPECIAL[key] || MASTER_GROUPS.find { |_, list| list.include?(key) }&.first)].compact
    end

    trio = NPC_SPECIAL[key] || NPC_GROUPS.find { |_, list| list.include?(key) }&.first || %w[cheri pecha rawst]
    return trio.first(players).map { |name| existing(name) }.compact
  end

  def existing(short)
    return nil unless short

    sym = :"#{short}_berry"
    return berry?(sym) ? sym : nil
  end

  def pick_existing(list)
    return list.map { |s| s.to_s.to_sym }.select { |s| berry?(s) }.sample
  end

  def all_berries
    @all_berries ||= each_data_item.select { |item| item.respond_to?(:cooking_data) && item.cooking_data }.map(&:db_symbol)
  rescue StandardError
    @all_berries = []
  end

  # Baies des autres joueurs selon la vôtre (tables du plugin d'origine)
  NPC_GROUPS = {
    %w[cheri pecha rawst] => %w[leppa figy razz pomeg tamato spelon occa chople tanga babiri liechi lansat enigma],
    %w[chesto rawst aspear] => %w[oran wiki bluk kelpsy cornn pamtre passho kebia charti chilan ganlon micle kee starf],
    %w[pecha aspear cheri] => %w[persim mago nanab qualot magost watmel wacan shuca kasib salac custap roseli],
    %w[rawst cheri chesto] => %w[lum aguav wepear hondew rabuta durin rindo coba haban petaya jaboca maranga],
    %w[aspear chesto pecha] => %w[sitrus iapapa pinap grepa nomel belue yache colbur apicot rowap]
  }.freeze
  NPC_SPECIAL = {
    'cheri' => %w[aspear rawst pecha], 'chesto' => %w[cheri aspear rawst], 'pecha' => %w[chesto cheri aspear],
    'rawst' => %w[pecha chesto cheri], 'aspear' => %w[rawst pecha chesto]
  }.freeze
  MASTER_GROUPS = {
    'spelon' => %w[cheri enigma leppa figy razz pomeg tamato occa chople tanga babiri liechi lansat],
    'pamtre' => %w[chesto oran wiki bluk kelpsy cornn passho kebia charti chilan ganlon micle kee starf],
    'watmel' => %w[pecha persim mago nanab qualot magost wacan shuca kasib salac custap roseli],
    'durin' => %w[rawst lum aguav wepear hondew rabuta rindo coba haban petaya jaboca maranga],
    'belue' => %w[aspear sitrus iapapa pinap grepa nomel yache colbur apicot rowap]
  }.freeze
  MASTER_SPECIAL = { 'spelon' => 'tamato', 'pamtre' => 'cornn', 'watmel' => 'magost', 'durin' => 'rabuta', 'belue' => 'nomel' }.freeze

  # --- Mixeur simple (Rubis Oméga / Saphir Alpha) -------------------------------------------------------------------
  # @param berries [Array<Symbol>] 1 à 4 baies
  # @return [Array<Hash>] un Pokébloc par baie
  def simple_blend(berries)
    colors = berries.map { |b| berry_color(b) }
    unique = colors.uniq
    color = if unique.size >= 4 then 'rainbow'
            elsif unique.size == 1 then unique.first
            elsif unique.size == colors.size then colors.sample
            else
              best = unique.map { |c| colors.count(c) }.max
              unique.select { |c| colors.count(c) == best }.sample
            end
    plus = rand(100) < berries.sum { |b| better_chance(b) }
    value = plus ? 15 : 5
    values = color == 'rainbow' ? [value] * 5 : [0, 0, 0, 0, 0].tap { |v| v[SINGLE.index(color)] = value }
    return Array.new(berries.size) { make(color, values, 0, plus) }
  end

  # --- Effet sur un Pokémon -----------------------------------------------------------------------------------------
  # @return [Array<Integer>] conditions + Lustre
  def conditions(pokemon)
    return pokemon.contest_conditions + [pokemon.sheen.to_i]
  end

  # Raison pour laquelle le Pokémon ne peut pas manger ce Pokébloc (nil : il peut)
  def refusal(pokemon, block)
    name = pokemon.given_name
    return t("#{name} ne peut pas manger.", "#{name} can't eat.") if pokemon.egg?
    return t("#{name} n'a plus faim !", "#{name} can't eat anymore.") if sheen? && pokemon.sheen.to_i >= 255

    unless sheen?
      return t("#{name} ne peut plus manger de Pokéblocs.", "#{name} can't eat any more Pokéblocks.") if pokemon.contest_conditions.sum >= 1275

      raised = gains(pokemon, block).each_with_index.select { |gain, _| gain > 0 }.map(&:last)
      if raised.any? && raised.all? { |i| pokemon.contest_conditions[i] >= 255 }
        return t("#{name} ne peut plus manger ce genre de Pokébloc.", "#{name} can't eat this kind of Pokéblock anymore.")
      end
    end
    return nil
  end

  # Ce que chaque condition gagnerait (goûts de la nature : +10 % aimé, -10 % détesté)
  # @return [Array<Integer>]
  def gains(pokemon, block)
    values = Array(block['flavors']).map(&:to_f)
    FLAVORS.each_with_index do |flavor, i|
      values[i] *= 1.1 if pokemon.respond_to?(:flavor_liked?) && pokemon.flavor_liked?(flavor)
      values[i] *= 0.9 if pokemon.respond_to?(:flavor_disliked?) && pokemon.flavor_disliked?(flavor)
    end
    values.map!(&:round)
    return values if sheen?

    total = pokemon.contest_conditions.sum
    return values.map { |v| v > 0 ? simple_value(v, total, block['plus']) : 0 }
  end

  # Mode simple : effet décroissant quand les conditions sont déjà hautes (les Pokéblocs + restent forts)
  def simple_value(value, total, plus)
    return value if plus

    return 8 if total < 256
    return 6 if total < 512
    return 4 if total < 768
    return 3 if total < 1024

    return 2
  end

  # Le Pokémon mange le Pokébloc (retiré de la Boîte)
  # @return [Array(Array<Integer>, Array<Integer>)] conditions avant / après (avec le Lustre)
  def feed(pokemon, block)
    before = conditions(pokemon)
    gain = gains(pokemon, block)
    STATS.each_with_index do |stat, i|
      pokemon.send("#{stat}=", (pokemon.send(stat).to_i + gain[i]).clamp(0, 255))
    end
    pokemon.sheen = (pokemon.sheen.to_i + block['feel'].to_i).clamp(0, 255) if sheen?
    remove(block)
    return [before, conditions(pokemon)]
  end

  # Goût du Pokémon pour ce Pokébloc (pour le message)
  # @return [Symbol] :liked, :disliked ou :normal
  def taste(pokemon, block)
    main = Array(block['flavors']).each_with_index.max_by { |v, _| v }&.last
    return :normal unless main && block['flavors'][main].to_i > 0

    flavor = FLAVORS[main]
    return :liked if pokemon.respond_to?(:flavor_liked?) && pokemon.flavor_liked?(flavor)
    return :disliked if pokemon.respond_to?(:flavor_disliked?) && pokemon.flavor_disliked?(flavor)

    return :normal
  end

  # Noms des conditions
  def stat_names
    return fr? ? %w[Sang-froid Beauté Grâce Intelligence Robustesse Lustre] : %w[Cool Beauty Cute Smart Tough Sheen]
  end
end
