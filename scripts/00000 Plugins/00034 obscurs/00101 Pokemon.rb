# Pokémon Obscurs : données du Pokémon (jauge cœur, capacités, expérience gardée) et registre de la partie
module Obscurs
  # Capacités d'origine retrouvées selon les barres de la jauge (5 : pleine ... 0 : vide)
  ORIGINAL_MOVES = [3, 3, 2, 1, 1, 0].freeze

  module_function

  # --- Registre de la partie ----------------------------------------------------------------------------------------
  # @return [Hash] { 'seen' => { id => { 'status', 'species', 'trainer' } }, 'chamber' => [[Pokémon Obscur, autres...]] }
  def data
    state = PFM.game_state
    hash = state.instance_variable_get(:@pj_obscurs) || state.instance_variable_set(:@pj_obscurs, {})
    hash['seen'] ||= {}
    hash['chamber'] ||= Array.new(CHAMBER_SETS) { [] }
    hash['chamber'] << [] while hash['chamber'].size < CHAMBER_SETS
    return hash
  end

  # @param id [String] identifiant du Pokémon Obscur
  # @return [String, nil] 'seen', 'missed', 'snagged', 'purified'
  def status(id)
    return fetch(data['seen'][id.to_s], 'status')
  end

  # Statut d'un Pokémon Obscur (l'ordre empêche de revenir en arrière : vu < raté < capturé < purifié)
  STATUS_ORDER = %w[seen missed snagged purified].freeze

  def record(pokemon, new_status, trainer = nil)
    shadow = pokemon.respond_to?(:shadow_data) ? pokemon.shadow_data : nil
    id = shadow ? shadow['id'] : pokemon.instance_variable_get(:@pj_shadow_id)
    return if id.to_s.empty?

    entry = data['seen'][id.to_s] ||= { 'status' => 'seen', 'species' => pokemon.db_symbol.to_s }
    entry['trainer'] = trainer.to_s if trainer && !trainer.to_s.empty?
    old = STATUS_ORDER.index(entry['status']).to_i
    entry['status'] = new_status if STATUS_ORDER.index(new_status).to_i >= old || new_status == 'missed' && old <= 1
  end

  # --- Création -----------------------------------------------------------------------------------------------------
  # Rend un Pokémon Obscur
  # @param pokemon [PFM::Pokemon]
  # @param id [String, nil] identifiant (registre)
  # @param gauge [Integer, nil] taille de la jauge
  # @param moves [Array<Symbol>, nil] capacités Obscures (jusqu'à 4)
  # @return [PFM::Pokemon]
  def make_shadow(pokemon, id: nil, gauge: nil, moves: nil)
    return pokemon if pokemon.egg?

    size = gauge.to_i > 0 ? gauge.to_i : setting('gauge').to_i
    list = Array(moves).map { |move| move.to_s.to_sym }.reject { |move| move.to_s.empty? || move == :__undef__ }
    list = Array(setting('default_moves')).map(&:to_sym) if list.empty?
    list = list.uniq.first(4)
    saved = pokemon.skills_set.compact.map(&:db_symbol).reject { |move| list.include?(move) }
    pokemon.instance_variable_set(:@pj_shadow, {
      'id' => (id || "#{pokemon.db_symbol}_#{rand(1_000_000)}").to_s, 'max' => size, 'gauge' => size, 'exp' => 0,
      'moves' => list.map(&:to_s), 'saved' => saved.map(&:to_s), 'fury' => false
    })
    pokemon.instance_variable_set(:@pj_shadow_id, pokemon.shadow_data['id'])
    pokemon.update_shadow_moves
    return pokemon
  end

  # Crée un Pokémon Obscur
  # @return [PFM::Pokemon]
  def create(species, level, id: nil, gauge: nil, moves: nil, shiny: false, form: 0)
    pokemon = PFM::Pokemon.new(species.to_sym, level.to_i, shiny, !shiny, form.to_i)
    return make_shadow(pokemon, id: id, gauge: gauge, moves: moves)
  end

  # Barres de la jauge cœur (0 : vide, 5 : pleine)
  def stage_of(gauge, max)
    return 0 if gauge.to_i <= 0 || max.to_i <= 0

    return ((gauge.to_f * 5 / max).ceil).clamp(1, 5)
  end
end

module PFM
  class Pokemon
    # @return [Hash, nil] données Obscures (nil : Pokémon normal)
    def shadow_data
      return @pj_shadow
    end

    # Pokémon Obscur ?
    def shadow?
      return !shadow_data.nil?
    end
    alias shadowPokemon? shadow?

    # Pokémon Obscur purifié ?
    def purified?
      return @pj_purified == true
    end

    # @return [Integer] valeur de la jauge cœur
    def heart_gauge
      return shadow_data ? shadow_data['gauge'].to_i : 0
    end

    # @return [Integer] taille de la jauge
    def max_heart_gauge
      return shadow_data ? shadow_data['max'].to_i : 1
    end

    # @return [Integer] barres de la jauge (0 à 5)
    def heart_stage
      return Obscurs.stage_of(heart_gauge, max_heart_gauge)
    end

    # Prêt à être purifié (jauge vide)
    def purifiable?
      return shadow? && heart_gauge <= 0
    end

    # @return [Boolean] en furie (mode Hyper / Inversion)
    def shadow_fury?
      return shadow? && shadow_data['fury'] ? true : false
    end

    def shadow_fury=(value)
      shadow_data['fury'] = value ? true : false if shadow?
    end

    # Change la jauge cœur
    # @param delta [Integer] valeur ajoutée (négative : la jauge baisse)
    # @return [Boolean] la jauge a changé
    def change_heart_gauge(delta)
      return false unless shadow?

      old = heart_gauge
      stage = heart_stage
      shadow_data['gauge'] = (old + delta.to_i).clamp(0, max_heart_gauge)
      update_shadow_moves if heart_stage != stage
      return heart_gauge != old
    end

    # Capacités : capacités Obscures, puis quelques capacités d'origine selon la jauge
    def update_shadow_moves
      return unless shadow?

      shadow = shadow_data['moves'].map(&:to_sym).first(4)
      originals = shadow_data['saved'].map(&:to_sym) - shadow
      count = [Obscurs::ORIGINAL_MOVES[heart_stage].to_i, 4 - shadow.size].min
      list = shadow + originals.first([count, 0].max)
      old = @skills_set.compact.to_h { |skill| [skill.db_symbol, skill] }
      @skills_set = list.map { |move| old[move] || PFM::Skill.new(move) }
    end

    # Expérience gardée pendant que le Pokémon est Obscur
    def shadow_exp
      return shadow_data ? shadow_data['exp'].to_i : 0
    end

    def add_shadow_exp(amount)
      shadow_data['exp'] = shadow_exp + amount.to_i if shadow?
    end

    # Purifie le Pokémon (sans message) : capacités d'origine, ruban, nature dévoilée
    # @return [Integer] expérience gardée à rendre
    def purify_shadow
      return 0 unless shadow?

      exp = shadow_exp
      originals = shadow_data['saved'].map(&:to_sym)
      old = @skills_set.compact.to_h { |skill| [skill.db_symbol, skill] }
      moves = originals.first(4)
      moves = shadow_data['moves'].map(&:to_sym).first(1) if moves.empty?
      @skills_set = moves.map { |move| old[move] || PFM::Skill.new(move) }
      Obscurs.record(self, 'purified')
      @pj_shadow = nil
      @pj_purified = true
      ribbon = Obscurs.setting('ribbon').to_s
      add_ribbon(ribbon.to_sym) if !ribbon.empty? && respond_to?(:add_ribbon) && !(respond_to?(:ribbon?) && ribbon?(ribbon.to_sym))
      return exp
    end

    # Nature cachée tant que le Pokémon est Obscur
    alias pj_obscurs_nature_text nature_text
    def nature_text
      return '????' if shadow?

      return pj_obscurs_nature_text
    end
    alias nature_name nature_text

    # Pas de niveau ni d'évolution tant que le Pokémon est Obscur
    alias pj_obscurs_level_up level_up
    def level_up
      return false if shadow?

      return pj_obscurs_level_up
    end

    alias pj_obscurs_evolve_check evolve_check
    def evolve_check(*args)
      return false if shadow?

      return pj_obscurs_evolve_check(*args)
    end
  end

  class PokemonBattler
    def shadow_data
      return @original.respond_to?(:shadow_data) ? @original.shadow_data : nil
    end

    def purified?
      return @original.respond_to?(:purified?) && @original.purified?
    end

    def change_heart_gauge(delta)
      return @original.change_heart_gauge(delta)
    end

    def add_shadow_exp(amount)
      @original.add_shadow_exp(amount)
    end

    def update_shadow_moves
      @original.update_shadow_moves
    end
  end
end
