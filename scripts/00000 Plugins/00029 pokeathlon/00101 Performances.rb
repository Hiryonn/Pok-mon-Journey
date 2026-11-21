# Pokéathlon : performances (Vitesse, Force, Technique, Endurance, Saut : 1 à 5 étoiles)
#
# Espèce : étoiles de base et maximum, réglées dans Studio ou calculées depuis les statistiques de base :
#   Vitesse <- Vitesse ; Force <- Attaque ; Technique <- (Atq. Spé. + Déf. Spé.) / 2 ;
#   Endurance <- (PV + Défense) / 2 ; Saut <- (Vitesse + Atq. Spé.) / 2 ; maximum = base + 1 (+ 2 si statistiques élevées).
# Pokémon : base de l'espèce, + variation du jour (selon sa personnalité et le jour du mois, réglage daily_range),
#   + nature (+1 sur la performance de la statistique augmentée, -1 sur celle de la statistique baissée),
#   + Jus de Noigrume ; le tout entre 1 et le maximum de l'espèce.
module Pokeathlon
  module_function

  # @return [Integer] étoiles (1 à 5) d'une statistique de base
  def stars_of(value)
    return 1 if value < 45
    return 2 if value < 65
    return 3 if value < 85
    return 4 if value < 105

    return 5
  end

  # Performances calculées depuis les statistiques de base
  # @return [Hash] { 'base' => [5], 'max' => [5] }
  def auto_performance(form)
    values = [form.base_spd, form.base_atk, (form.base_ats + form.base_dfs) / 2, (form.base_hp + form.base_dfe) / 2,
              (form.base_spd + form.base_ats) / 2]
    total = form.base_hp + form.base_atk + form.base_dfe + form.base_spd + form.base_ats + form.base_dfs
    base = values.map { |v| stars_of(v.to_i) }
    max = base.map { |b| (b + (total >= 500 ? 2 : 1)).clamp(b, 5) }
    return { 'base' => base, 'max' => max }
  end

  # Performances d'une espèce (réglées dans Studio, sinon calculées)
  # @param species [Symbol, String]
  # @param form [Integer]
  # @return [Hash] { 'base' => [5], 'max' => [5] }
  def species_performance(species, form = 0)
    @species_perf ||= {}
    key = "#{species}/#{form}"
    return @species_perf[key] if @species_perf[key]

    own = fetch(config.performance, species.to_s)
    own = fetch(config.performance, "#{species}_#{form}") || own if form.to_i > 0
    result = auto_performance(data_creature_form(species.to_sym, form.to_i))
    if own.is_a?(Hash)
      base = Array(fetch(own, 'base')).map(&:to_i)
      max = Array(fetch(own, 'max')).map(&:to_i)
      result['base'] = base.map { |v| v.clamp(1, 5) } if base.size == 5
      result['max'] = max.each_with_index.map { |v, i| v.clamp(result['base'][i], 5) } if max.size == 5
    end
    return @species_perf[key] = result
  rescue StandardError
    return { 'base' => [3] * 5, 'max' => [4] * 5 }
  end

  # Variation du jour d'une performance (-range à +range)
  def daily_shift(pokemon, index)
    range = setting('daily_range').to_i
    return 0 if range <= 0

    seed = (pokemon.code.to_i >> (index * 4)) & 0xFFFF
    day = Time.now.day
    return ((seed + day * (index + 3)) % (range * 2 + 1)) - range
  end

  # Effet de la nature sur une performance (+1 / -1 / 0)
  def nature_shift(pokemon, stat)
    return 0 unless setting('nature_effect')

    nature = pokemon.nature
    index = NATURE_STAT.key(stat)
    return 0 unless index && nature

    return 1 if nature[index].to_i > 100
    return -1 if nature[index].to_i < 100

    return 0
  rescue StandardError
    return 0
  end

  # @param pokemon [PFM::Pokemon]
  # @return [Hash{String => Integer}] performances du jour
  def performance(pokemon)
    perf = species_performance(pokemon.db_symbol, pokemon.form)
    juice = pokemon.athlon_juice || {}
    return STATS.each_with_index.to_h do |stat, i|
      value = perf['base'][i] + daily_shift(pokemon, i) + nature_shift(pokemon, stat)
      value = value.clamp(perf['base'][i] - 2, perf['base'][i] + 2) + juice[stat].to_i
      [stat, value.clamp(1, perf['max'][i])]
    end
  end

  # Somme des performances (pour classer les Pokémon)
  def performance_total(pokemon)
    return performance(pokemon).values.sum
  end
end

module PFM
  class Pokemon
    # Jus de Noigrume bu : { performance => +n / -n }
    # @return [Hash, nil]
    def athlon_juice
      return @pj_athlon_juice
    end

    attr_writer :pj_athlon_juice

    # Coupes gagnées par ce Pokémon (identifiants des coupes)
    # @return [Array<String>]
    def athlon_medals
      return @pj_athlon_medals ||= []
    end

    # @return [Hash{String => Integer}]
    def athlon_performance
      return Pokeathlon.performance(self)
    end
  end
end

# Au PC, le Pokémon perd l'effet de son Jus de Noigrume
module PFM
  class Storage
    module PokeathlonJuice
      def store(pokemon, *args)
        pokemon.pj_athlon_juice = nil if pokemon.is_a?(PFM::Pokemon) && Pokeathlon.setting('juice_pc_reset')
        super
      end
    end
    prepend PokeathlonJuice
  end
end
