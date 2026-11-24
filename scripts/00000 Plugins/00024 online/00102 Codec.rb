# encoding: utf-8
# Jeu en ligne : conversion sûre d'un Pokémon en données JSON (et inversement).
# On n'utilise JAMAIS Marshal sur des données reçues d'un autre joueur (exécution de code possible) : seuls des champs connus,
# de types simples, sont envoyés ; à la réception tout est vérifié (espèce, attaques, objet, niveau, IV/EV) puis le Pokémon est
# recréé par le jeu lui-même.
module Online
  module Codec
    STATS = %i[hp atk dfe spd ats dfs].freeze
    SYMBOL = /\A[a-z0-9_]{1,40}\z/.freeze

    module_function

    # @param pokemon [PFM::Pokemon]
    # @return [Hash]
    def encode(pokemon)
      data = {
        'id' => pokemon.db_symbol.to_s,
        'form' => pokemon.form.to_i,
        'level' => pokemon.level.to_i,
        'shiny' => pokemon.shiny? ? true : false,
        'gender' => pokemon.gender.to_i,
        'nature' => read(pokemon, :nature_db_symbol) || read(pokemon, :nature_id),
        'ability' => read(pokemon, :ability_db_symbol),
        'item' => read(pokemon, :item_db_symbol),
        'name' => read(pokemon, :given_name).to_s[0, 12],
        'ot' => read(pokemon, :trainer_name).to_s[0, 16],
        'tid' => read(pokemon, :trainer_id).to_i,
        'loyalty' => read(pokemon, :loyalty).to_i,
        'ball' => read(pokemon, :captured_with),
        'exp' => read(pokemon, :exp).to_i,
        'ivs' => STATS.map { |stat| read(pokemon, :"iv_#{stat}").to_i },
        'evs' => STATS.map { |stat| read(pokemon, :"ev_#{stat}").to_i },
        'moves' => Array(read(pokemon, :skills_set)).compact.map { |skill| { 'id' => skill.db_symbol.to_s, 'pp' => skill.pp.to_i } }
      }
      data['egg'] = true if pokemon.respond_to?(:egg?) && pokemon.egg?
      return data.reject { |_, value| value.nil? }
    end

    def read(object, name)
      value = object.respond_to?(name) ? object.public_send(name) : nil
      value = value.to_s if value.is_a?(Symbol)
      return value
    end

    # Vérifie les données reçues
    # @param data [Hash]
    # @param max_level [Integer]
    # @return [String, nil] motif de refus (nil : valide)
    def problem(data, max_level: 100)
      return 'données invalides' unless data.is_a?(Hash)
      return 'espèce invalide' unless data['id'].is_a?(String) && data['id'] =~ SYMBOL
      return 'espèce inconnue' unless species?(data['id'])

      level = data['level']
      return 'niveau invalide' unless level.is_a?(Integer) && level.between?(1, [max_level.to_i, 1].max)
      return 'forme invalide' unless data['form'].is_a?(Integer) && data['form'].between?(0, 99)
      return 'IV invalides' unless numbers?(data['ivs'], 0, 31)
      return 'EV invalides' unless numbers?(data['evs'], 0, 252) && data['evs'].sum <= 510
      return 'attaques invalides' unless valid_moves?(data['moves'])
      return 'objet invalide' unless data['item'].nil? || (data['item'].is_a?(String) && data['item'] =~ SYMBOL && (data['item'].empty? || item?(data['item'])))
      return 'nature invalide' unless data['nature'].nil? || data['nature'].is_a?(String) || data['nature'].is_a?(Integer)
      return 'talent invalide' unless data['ability'].nil? || (data['ability'].is_a?(String) && data['ability'] =~ SYMBOL)

      return nil
    end

    def numbers?(list, min, max)
      return list.is_a?(Array) && list.size == 6 && list.all? { |n| n.is_a?(Integer) && n.between?(min, max) }
    end

    def valid_moves?(moves)
      return false unless moves.is_a?(Array) && moves.size.between?(1, 4)

      return moves.all? { |m| m.is_a?(Hash) && m['id'].is_a?(String) && m['id'] =~ SYMBOL && move?(m['id']) }
    end

    def species?(symbol)
      return data_creature(symbol.to_sym).db_symbol != :__undef__
    rescue StandardError
      return false
    end

    def move?(symbol)
      return data_move(symbol.to_sym).db_symbol != :__undef__
    rescue StandardError
      return false
    end

    def item?(symbol)
      return data_item(symbol.to_sym).db_symbol != :__undef__
    rescue StandardError
      return false
    end

    # Recrée le Pokémon (après #problem)
    # @param data [Hash]
    # @param origin [String] dresseur d'origine affiché si absent
    # @return [PFM::Pokemon]
    def decode(data, origin: '')
      pokemon = PFM::Pokemon.generate_from_hash(
        id: data['id'].to_sym, level: data['level'], form: data['form'], shiny: data['shiny'] ? true : false,
        gender: data['gender'].to_i, given_name: data['name'].to_s.empty? ? nil : data['name'].to_s[0, 12],
        trainer_name: data['ot'].to_s.empty? ? origin.to_s : data['ot'].to_s[0, 16], trainer_id: data['tid'].to_i,
        stats: data['ivs'], bonus: data['evs'], loyalty: data['loyalty'].to_i.clamp(0, 255),
        moves: data['moves'].map { |m| m['id'].to_sym }, item: data['item'].to_s.empty? ? nil : data['item'].to_sym,
        nature: data['nature'].is_a?(String) ? data['nature'].to_sym : data['nature'],
        ability: data['ability'].to_s.empty? ? nil : data['ability'].to_sym, captured_with: data['ball'].to_s.empty? ? nil : data['ball'].to_sym
      )
      apply_pp(pokemon, data['moves'])
      return pokemon
    end

    def apply_pp(pokemon, moves)
      return unless pokemon.respond_to?(:skills_set)

      pokemon.skills_set.compact.each_with_index do |skill, index|
        pp = moves[index] && moves[index]['pp']
        skill.pp = pp.clamp(0, skill.ppmax) if pp.is_a?(Integer) && skill.respond_to?(:pp=) && skill.respond_to?(:ppmax)
      end
    end

    # @return [String] résumé « Nom N.12 »
    def summary(data)
      name = species_name(data['id'])
      return "#{name} #{Online.t('N.', 'Lv.')}#{data['level']}#{data['shiny'] ? ' ★' : ''}"
    end

    def species_name(symbol)
      return data_creature(symbol.to_sym).name.to_s
    rescue StandardError
      return symbol.to_s
    end

    # @return [String] empreinte stable d'un Pokémon encodé (pour valider un échange des deux côtés)
    def fingerprint(data)
      require 'digest'
      return Digest::SHA256.hexdigest(JSON.generate(canonical(data)))
    end

    def canonical(value)
      case value
      when Hash then value.keys.sort.map { |key| [key.to_s, canonical(value[key])] }
      when Array then value.map { |item| canonical(item) }
      else value
      end
    end
  end
end
