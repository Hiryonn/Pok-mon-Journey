# encoding: utf-8
# Échange Miracle : tirage du Pokémon reçu et déroulement de l'échange
module EchangeMiracle
  module_function

  # @param form [Studio::CreatureForm]
  # @return [Integer] total des statistiques de base
  def power(form)
    return %i[base_hp base_atk base_dfe base_spd base_ats base_dfs].sum { |stat| form.respond_to?(stat) ? form.send(stat).to_i : 0 }
  end

  # @return [Array<Hash>] espèces possibles { db:, power: }
  def pool
    @pool ||= begin
      min = setting('min_id').to_i
      max = setting('max_id').to_i
      groups = Array(setting('exclude_groups')).map(&:to_i)
      excluded = Array(setting('exclude')).map(&:to_s)
      list = []
      each_data_creature do |creature|
        next if creature.db_symbol == :__undef__ || excluded.include?(creature.db_symbol.to_s)
        next if creature.id < min || (max > 0 && creature.id > max)

        form = creature.forms.find { |f| f.form == 0 } || creature.forms.first
        next unless form
        next if (Array(form.respond_to?(:breed_groups) ? form.breed_groups : []).map(&:to_i) & groups).any?

        list << { db: creature.db_symbol, power: power(form) }
      end
      list
    end
  end

  # @param given [PFM::Pokemon]
  # @return [Symbol] espèce reçue
  def pick_species(given)
    base = power(data_creature_form(given.db_symbol, given.form.to_i))
    window = setting('power_window').to_f / 100.0
    lucky = rand(100) < setting('luck_chance').to_i
    target = lucky ? base * setting('luck_boost').to_f : base
    low = (target * (1 - window)).floor
    high = (target * (1 + window)).ceil
    list = pool.select { |entry| entry[:power].between?(low, high) && entry[:db] != given.db_symbol }
    list = pool.sort_by { |entry| (entry[:power] - target).abs }.first(10) if list.empty?
    return list.sample[:db]
  end

  # @param given [PFM::Pokemon]
  # @return [Hash] { pokemon:, trainer: }
  def make_received(given)
    species = pick_species(given)
    level = (given.level + rand(-setting('level_spread').to_i..setting('level_spread').to_i)).clamp(1, 100)
    shiny = rand * 100 < setting('shiny_chance').to_f
    pokemon = PFM::Pokemon.new(species, level, shiny)
    trainer = trainers.sample
    set_origin(pokemon, fetch(trainer, 'name').to_s)
    return { pokemon: pokemon, trainer: trainer }
  end

  # Dresseur d'origine imaginaire
  def set_origin(pokemon, name)
    if pokemon.respond_to?(:trainer_name=) then pokemon.trainer_name = name
    else pokemon.instance_variable_set(:@trainer_name, name)
    end
    pokemon.trainer_id = rand(1..65_535) if pokemon.respond_to?(:trainer_id=)
    pokemon.loyalty = 70 if pokemon.respond_to?(:loyalty=)
  rescue StandardError => e
    log_error("Échange Miracle : dresseur d'origine (#{e.message})") if respond_to?(:log_error, true)
  end

  # @return [String] jour (pour la limite quotidienne)
  def today
    return Time.now.strftime('%Y-%m-%d')
  end

  def limit_reached?
    limit = setting('daily_limit').to_i
    return false if limit <= 0

    data = state
    return false unless data['day'] == today

    return data['today'].to_i >= limit
  end

  # @param pokemon [PFM::Pokemon]
  # @return [String, nil] raison du refus
  def refusal(pokemon)
    return t('Un Œuf ne peut pas être échangé.', 'An Egg can’t be traded.') if pokemon.egg?
    return nil unless setting('keep_last')

    others = $actors.reject { |p| p.equal?(pokemon) || p.egg? || p.dead? }
    return t('Il te faut un autre Pokémon en état de se battre.', 'You need another Pokémon that can fight.') if others.empty? && !pokemon.dead?

    return nil
  end

  def possible?
    return !limit_reached? && $actors.any? { |pokemon| !refusal(pokemon) }
  end

  # Fait l'échange
  # @param index [Integer] place du Pokémon envoyé dans l'équipe
  # @return [Hash, nil] { gave:, got:, trainer: }
  def trade(index)
    given = $actors[index]
    return nil unless given && !refusal(given) && !limit_reached?

    received = make_received(given)
    pokemon = received[:pokemon]
    $actors[index] = pokemon
    register(pokemon)
    log(given, pokemon, received[:trainer])
    return { gave: given, got: pokemon, trainer: received[:trainer] }
  end

  def register(pokemon)
    dex = PFM.game_state.pokedex
    dex.mark_seen(pokemon.db_symbol, forced: true)
    dex.mark_captured(pokemon.db_symbol)
  rescue StandardError => e
    log_error("Échange Miracle : Pokédex (#{e.message})") if respond_to?(:log_error, true)
  end

  def log(given, got, trainer)
    data = state
    data['count'] += 1
    data['today'] = data['day'] == today ? data['today'].to_i + 1 : 1
    data['day'] = today
    data['last'] = got.db_symbol.to_s
    data['history'].unshift({ 'gave' => given.db_symbol.to_s, 'got' => got.db_symbol.to_s, 'level' => got.level,
                              'trainer' => fetch(trainer, 'name').to_s })
    data['history'] = data['history'].first([setting('history_size').to_i, 1].max)
  end

  def last_name
    sym = state['last']
    return nil if sym.nil? || sym.empty?

    return data_creature(sym.to_sym).name.to_s
  rescue StandardError
    return sym
  end
end
