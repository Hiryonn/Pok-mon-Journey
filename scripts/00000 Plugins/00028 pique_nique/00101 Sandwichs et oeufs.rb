# encoding: utf-8
# Pique-nique : sandwichs, panier et œufs
module PiqueNique
  module_function

  # --- Sandwichs ---------------------------------------------------------------------------------------------------
  def quantity(item)
    return $bag.item_quantity(item.to_sym)
  rescue StandardError
    return $bag.contain_item?(item.to_sym) ? 1 : 0
  end

  # @return [Array<Hash>] ingrédients { item:, count: }
  def ingredients(recipe)
    return Array(fetch(recipe, 'ingredients')).map { |i| { item: fetch(i, 'item').to_s, count: [fetch(i, 'count').to_i, 1].max } }
  end

  def possible?(id)
    recipe = recipe(id)
    return false unless recipe

    return ingredients(recipe).all? { |i| quantity(i[:item]) >= i[:count] }
  end

  # Prépare et mange le sandwich (les ingrédients quittent le sac)
  # @return [Boolean]
  def cook(id)
    recipe = recipe(id)
    return false unless recipe && possible?(id)

    ingredients(recipe).each { |i| $bag.remove_item(i[:item].to_sym, i[:count]) }
    steps = [fetch(recipe, 'steps').to_i, 1].max
    state['meal'] = { 'id' => fetch(recipe, 'id').to_s, 'steps' => steps, 'egg' => fetch(recipe, 'egg').to_i,
                      'spawn' => fetch(recipe, 'spawn') }
    happy(fetch(recipe, 'happy').to_i)
    notify(recipe_name(recipe), t('Sandwich prêt, les pouvoirs durent un moment.', 'Sandwich ready, its powers last a while.'))
    return true
  end

  # Bonheur donné à l'équipe en mangeant
  def happy(amount)
    return if amount <= 0

    $actors.each { |pokemon| pokemon.loyalty = [pokemon.loyalty.to_i + amount, 255].min unless pokemon.egg? }
  rescue StandardError => e
    log_error("Pique-nique : bonheur (#{e.message})") if respond_to?(:log_error, true)
  end

  # @return [Hash, nil] sandwich en cours
  def meal
    data = state['meal']
    return data && data['steps'].to_i > 0 ? data : nil
  end

  def meal_name
    data = meal
    return nil unless data

    recipe = recipe(data['id'])
    return recipe ? recipe_name(recipe) : data['id']
  end

  # Facteur d'apparition des Pokémon visibles de l'espèce (pouvoir « spawn » du sandwich)
  # @return [Float]
  def spawn_factor(species, form = 0)
    data = meal
    spawn = data && data['spawn']
    return 1.0 unless spawn.is_a?(Hash)

    type = fetch(spawn, 'type').to_s
    data_form = data_creature_form(species, form.to_i)
    types = [data_form.type1, data_form.type2].compact.map(&:to_s)
    return types.include?(type) ? (fetch(spawn, 'percent').to_f / 100.0).clamp(0.05, 20.0) : 1.0
  rescue StandardError
    return 1.0
  end

  # --- Pique-nique et panier ---------------------------------------------------------------------------------------
  def active?
    return state['steps'].to_i > 0
  end

  def install
    state['steps'] = setting('picnic_steps').to_i
    state['egg_clock'] = 0
    notify(t('Pique-nique', 'Picnic'), t('Le panier est installé.', 'The basket is set up.'))
  end

  def eggs
    return state['basket'].size
  end

  # --- Compatibilité -----------------------------------------------------------------------------------------------
  def groups(pokemon)
    form = data_creature_form(pokemon.db_symbol, pokemon.form.to_i)
    return Array(form.respond_to?(:breed_groups) ? form.breed_groups : [])
  rescue StandardError
    return []
  end

  def ditto?(pokemon)
    return groups(pokemon).include?(setting('egg_group_ditto').to_i) || pokemon.db_symbol.to_s == setting('ditto_species').to_s
  end

  def fertile?(pokemon)
    return false if pokemon.egg?

    return !groups(pokemon).include?(setting('egg_group_none').to_i)
  end

  # @return [Array<PFM::Pokemon>, nil] la paire compatible (mère ou Pokémon sans Métamorph en premier)
  def pair
    team = $actors.select { |pokemon| fertile?(pokemon) }
    team.combination(2).each do |a, b|
      if ditto?(a) && ditto?(b)
        next
      elsif ditto?(a)
        return [b, a]
      elsif ditto?(b)
        return [a, b]
      elsif a.gender != b.gender && a.gender.to_i > 0 && b.gender.to_i > 0 && (groups(a) & groups(b)).any?
        return a.gender == 2 ? [a, b] : [b, a]
      end
    end
    return nil
  rescue StandardError => e
    log_error("Pique-nique : compatibilité (#{e.message})") if respond_to?(:log_error, true)
    return nil
  end

  # Espèce de l'œuf : le bébé de la mère
  def baby_species(mother)
    form = data_creature_form(mother.db_symbol, mother.form.to_i)
    baby = form.respond_to?(:baby_db_symbol) ? form.baby_db_symbol : nil
    baby = mother.db_symbol if baby.nil? || baby.to_s.empty? || baby.to_s == '__undef__'
    return baby.to_sym
  rescue StandardError
    return mother.db_symbol
  end

  # @return [PFM::Pokemon, nil]
  def make_egg(mother)
    egg = PFM::Pokemon.new(baby_species(mother), 1)
    egg.egg_init
    return egg
  rescue StandardError => e
    log_error("Pique-nique : œuf impossible (#{e.message})") if respond_to?(:log_error, true)
    return nil
  end

  # Un tour de panier (tous les egg_steps pas)
  def basket_tick
    return if state['basket'].size >= setting('basket_max').to_i

    parents = pair
    return unless parents

    data = meal
    chance = setting('egg_chance').to_i + (data ? data['egg'].to_i * setting('egg_bonus').to_i : 0)
    return unless rand(100) < chance.clamp(0, 95)

    egg = make_egg(parents.first)
    return unless egg

    state['basket'] << egg
    notify(t('Pique-nique', 'Picnic'), t('Un œuf est apparu dans le panier !', 'An egg appeared in the basket!'))
  end

  # Prend les œufs du panier
  # @return [Integer] œufs récupérés
  def collect
    count = 0
    state['basket'].dup.each do |egg|
      $pokemon_party.add_pokemon(egg)
      state['basket'].delete(egg)
      count += 1
    end
    return count
  rescue StandardError => e
    log_error("Pique-nique : récupération (#{e.message})") if respond_to?(:log_error, true)
    return count
  end

  # Un pas du joueur
  def step
    data = state
    if data['meal'] && data['meal']['steps'].to_i > 0
      data['meal']['steps'] -= 1
      data['meal'] = nil if data['meal']['steps'] <= 0
    end
    return unless data['steps'].to_i > 0

    data['steps'] -= 1
    data['egg_clock'] += 1
    return if data['egg_clock'] < [setting('egg_steps').to_i, 1].max

    data['egg_clock'] = 0
    basket_tick
  end

  def notify(title, text)
    ::UI::PokeSmart::Notify.push(text, title: title) if defined?(::UI::PokeSmart::Notify)
  rescue StandardError
    nil
  end
end

module PFM
  class GameState
    module PiqueNiqueSteps
      def increase_steps
        super
        PiqueNique.step
      rescue StandardError => e
        log_error("Pique-nique : pas (#{e.message})") if respond_to?(:log_error, true)
      end
    end
    prepend PiqueNiqueSteps
  end
end
