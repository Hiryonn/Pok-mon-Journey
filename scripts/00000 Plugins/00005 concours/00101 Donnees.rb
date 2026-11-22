# Concours : données de la partie (Mallette, gagnants), concurrents et calcul des points
module Concours
  # Un concurrent (le joueur ou un dresseur réglé dans Studio)
  class Entrant
    attr_accessor :trainer, :charset, :pokemon, :nickname, :player, :dressup, :condition, :dance, :acting, :picture,
                  :worn, :number, :backdrop, :pose, :moves

    def initialize
      @dressup = @condition = @dance = @acting = 0
      @worn = []
      @player = false
    end

    def visual
      return @dressup.to_i + @condition.to_i
    end

    def total
      return visual + @dance.to_i + @acting.to_i
    end

    def name
      return @nickname.to_s.empty? ? @pokemon.given_name.to_s : @nickname.to_s
    end
  end

  module_function

  # --- Sauvegarde ---------------------------------------------------------------------------------------------------
  # @return [Hash] { 'accessories' => { id => nombre }, 'backdrops' => [id], 'winners' => {}, 'stats' => {} }
  def data
    state = PFM.game_state
    hash = state.instance_variable_get(:@pj_concours) || state.instance_variable_set(:@pj_concours, {})
    hash['accessories'] ||= {}
    hash['backdrops'] ||= []
    hash['winners'] ||= {}
    hash['stats'] ||= {}
    return hash
  end

  def accessory_count(id)
    return data['accessories'][id.to_s].to_i
  end

  def backdrop?(id)
    return data['backdrops'].include?(id.to_s)
  end

  # @return [Boolean] l'accessoire existe
  def unlock_accessory(id, count = 1)
    return false unless accessory(id)

    data['accessories'][id.to_s] = accessory_count(id) + count.to_i
    return true
  end

  def unlock_backdrop(id)
    return false unless backdrop(id)

    data['backdrops'] << id.to_s unless backdrop?(id)
    return true
  end

  # Mallette de départ (une seule fois)
  def give_starter
    return false if data['starter']

    starter = config.starter.is_a?(Hash) ? config.starter : {}
    (fetch(starter, 'accessories') || {}).each { |id, count| unlock_accessory(id, count.to_i) }
    Array(fetch(starter, 'backdrops')).each { |id| unlock_backdrop(id) }
    data['starter'] = true
    return true
  end

  def empty_case
    data['accessories'] = {}
    data['backdrops'] = []
    data.delete('starter')
  end

  def winner_key(type, rank)
    return "#{type}_#{rank}"
  end

  # @return [Hash, nil] gagnant enregistré
  def winner(type, rank)
    return data['winners'][winner_key(type, rank)]
  end

  def last_winner
    return data['winners']['last']
  end

  def save_winner(type, rank, entrant)
    pokemon = entrant.pokemon
    record = {
      'trainer' => entrant.trainer.to_s, 'name' => entrant.name, 'species' => pokemon.db_symbol.to_s,
      'form' => pokemon.form.to_i, 'shiny' => pokemon.shiny? ? true : false, 'gender' => pokemon.gender.to_i,
      'score' => entrant.total, 'player' => entrant.player, 'type' => type.to_s, 'rank' => rank.to_s
    }
    data['winners'][winner_key(type, rank)] = record
    data['winners']['last'] = record
  end

  # Statistiques : { 'cool_normal' => { 'played', 'won', 'last' } }
  def record(type, rank)
    return data['stats'][winner_key(type, rank)] ||= { 'played' => 0, 'won' => 0, 'last' => 0 }
  end

  # Pokémon d'un gagnant enregistré (pour les images)
  def winner_pokemon(record)
    return nil unless record

    pokemon = PFM::Pokemon.new(record['species'].to_sym, 50, record['shiny'] ? true : false, !record['shiny'], record['form'].to_i,
                               gender: record['gender'].to_i)
    return pokemon
  rescue StandardError
    return nil
  end

  # --- Concurrents --------------------------------------------------------------------------------------------------
  # @param type [String]
  # @param rank [String]
  # @param pokemon [PFM::Pokemon] Pokémon du joueur
  # @return [Array<Entrant>] 3 concurrents puis le joueur (entrée n° 4)
  def build_entrants(type, rank, pokemon)
    pool = rank_contestants(rank).select { |data| species_exists?(fetch(data, 'species')) }
    others = pool.sample(3).map { |data| npc_entrant(data) }
    player = Entrant.new
    player.trainer = $trainer.name.to_s
    player.charset = $game_player.respond_to?(:character_name) ? $game_player.character_name.to_s : ''
    player.pokemon = pokemon
    player.nickname = pokemon.given_name.to_s
    player.player = true
    player.condition = condition_points(type, pokemon)
    list = others + [player]
    list.each_with_index { |entrant, i| entrant.number = i + 1 }
    return list
  end

  def species_exists?(species)
    return false if species.to_s.empty?

    return data_creature(species.to_sym).db_symbol != :__undef__
  rescue StandardError
    return false
  end

  def npc_entrant(data)
    entrant = Entrant.new
    entrant.trainer = fetch(data, 'trainer').to_s
    entrant.charset = fetch(data, 'charset').to_s
    shiny = fetch(data, 'shiny') ? true : false
    gender = fetch(data, 'gender')
    opts = gender.nil? ? {} : { gender: gender.to_i }
    entrant.pokemon = PFM::Pokemon.new(fetch(data, 'species').to_sym, 50, shiny, !shiny, fetch(data, 'form').to_i, opts)
    entrant.nickname = fetch(data, 'nickname').to_s
    entrant.dressup = fetch(data, 'dressup').to_i
    entrant.condition = fetch(data, 'condition').to_i
    entrant.picture = fetch(data, 'picture').to_s
    entrant.moves = Array(fetch(data, 'moves')).map(&:to_s).reject(&:empty?).map(&:to_sym)
    return entrant
  end

  # Condition principale + secondaires / 2 + Lustre / 2
  def condition_points(type, pokemon)
    main, second, third = CONDITIONS[type.to_s] || CONDITIONS['cool']
    value = ->(stat) { pokemon.respond_to?(stat) ? pokemon.send(stat).to_i : 0 }
    return value.call(main) + value.call(second) / 2 + value.call(third) / 2 + pokemon.sheen.to_i / 2
  end

  # --- Épreuves simulées (réglage minigames à false) -----------------------------------------------------------------
  # Habillage automatique : les accessoires de la Mallette qui valent le plus pour le thème
  # @return [Array<String>] accessoires portés
  def auto_dressup(entrant, theme, rank)
    pieces = data['accessories'].flat_map { |id, count| [id] * count.to_i }.select { |id| accessory(id) }
    pieces = pieces.sort_by { |id| [-accessory_points(id, theme), rand] }.first(max_accessories(rank))
    pieces.reject! { |id| accessory_points(id, theme) <= 0 }
    entrant.worn = pieces
    entrant.dressup = pieces.sum { |id| accessory_points(id, theme) }
    return pieces
  end

  # Danse : +2 par pas excellent, +1 par pas bien
  # @return [Array(Integer, Integer)] pas excellents, pas bien
  def auto_dance(entrant, rank)
    steps = 8 + rank_index(rank) * 4
    excellent_rate = entrant.player ? 40 : 25 + rank_index(rank) * 10
    great = good = 0
    steps.times do
      roll = rand(100)
      if roll < excellent_rate
        great += 1
      elsif roll < excellent_rate + 40
        good += 1
      end
    end
    entrant.dance = great * 2 + good
    return [great, good]
  end

  # Jeu d'acteur : 4 tours, cœurs selon l'attrait des capacités (et leur condition)
  # @return [Array<Integer>] cœurs à chaque tour
  def auto_acting(entrant, type, rank)
    hearts = Array.new(4) do |round|
      if entrant.player
        move = best_moves(entrant.pokemon, type)[round % [best_moves(entrant.pokemon, type).size, 1].max]
        appeal = move ? move_appeal(move) : 1
        matches = move && move_condition(move) == MOVE_CONDITION[type.to_s]
        (appeal / 2 + (matches ? 1 : 0) + rand(2)).clamp(0, 5)
      else
        (1 + rand(3) + (rank_index(rank) >= 2 ? 1 : 0)).clamp(0, 5)
      end
    end
    entrant.acting = hearts.sum * 10
    return hearts
  end

  # Capacités du Pokémon triées par intérêt pour ce concours
  def best_moves(pokemon, type)
    moves = pokemon.skills_set.compact.map(&:db_symbol).reject { |sym| sym == :__undef__ }
    return moves.sort_by { |sym| -(move_appeal(sym) + (move_condition(sym) == MOVE_CONDITION[type.to_s] ? 2 : 0)) }
  end

  def move_appeal(move)
    data = data_move(move)
    return data.respond_to?(:appeal) ? data.appeal.to_i : 2
  rescue StandardError
    return 2
  end

  def move_condition(move)
    data = data_move(move)
    return data.respond_to?(:condition) ? data.condition&.to_sym : nil
  rescue StandardError
    return nil
  end

  # Ordre final (le plus de points en premier ; égalité : au hasard)
  # @return [Array<Entrant>]
  def ranking(entrants)
    return entrants.sort_by { |entrant| [-entrant.total, rand] }
  end
end
