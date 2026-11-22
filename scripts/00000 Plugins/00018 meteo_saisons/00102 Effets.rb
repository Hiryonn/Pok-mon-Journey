# encoding: utf-8
# Météo et saisons : effets sur les apparitions (Pokémon visibles) et les baies (champs de baies)
module MeteoSaisons
  module_function

  def type_rows
    rows = Array(config.type_weights).select { |row| row.is_a?(Hash) }
    return rows unless rows.empty?

    return DEFAULT_TYPE_WEIGHTS.map { |on, key, type, percent| { 'on' => on, 'key' => key, 'type' => type, 'percent' => percent } }
  end

  # Multiplicateur (1.0 = rien) de la chance d'apparition d'une espèce, d'après la météo et la saison
  # @param species [Symbol]
  # @param form [Integer]
  # @return [Float]
  def spawn_factor(species, form = 0)
    return 1.0 unless setting('spawn_effects')

    keys = { 'weather' => current_weather, 'season' => season }
    types = species_types(species, form)
    factor = 1.0
    type_rows.each do |row|
      next unless keys[fetch(row, 'on').to_s] == fetch(row, 'key').to_s && types.include?(fetch(row, 'type').to_s)

      factor *= fetch(row, 'percent').to_f / 100.0
    end
    Array(config.species_weights).each do |row|
      next unless row.is_a?(Hash) && keys[fetch(row, 'on').to_s] == fetch(row, 'key').to_s && fetch(row, 'species').to_s == species.to_s

      factor *= fetch(row, 'percent').to_f / 100.0
    end
    return factor.clamp(0.05, 20.0)
  rescue StandardError
    return 1.0
  end

  def species_types(species, form = 0)
    data = data_creature_form(species, form.to_i)
    return [data.type1, data.type2].compact.map(&:to_s).reject { |t| t == '__undef__' }
  rescue StandardError
    return []
  end

  # --- Baies -------------------------------------------------------------------------------------------------------
  def berry_season_in?(berry)
    row = Array(config.berry_seasons).find { |entry| entry.is_a?(Hash) && fetch(entry, 'berry').to_s == berry.to_s }
    return nil unless row

    return fetch(row, 'season').to_s == season
  end

  # @return [Integer] % du temps de pousse de la baie
  def berry_growth_percent(berry)
    return 100 unless setting('berry_effects')

    percent = fetch(setting('season_growth'), season).to_i
    percent = 100 if percent <= 0
    inside = berry_season_in?(berry)
    percent = percent * setting('berry_in_season').to_i / 100 if inside == true
    percent = percent * setting('berry_out_season').to_i / 100 if inside == false
    return [percent, 10].max
  rescue StandardError
    return 100
  end

  # Pousse des champs de baies : durée par stade et récolte
  module BerryGrowth
    def stage_minutes(data, ex)
      minutes = super
      berry = data_item(data[0]).db_symbol
      return [minutes * MeteoSaisons.berry_growth_percent(berry) / 100, 30].max
    rescue StandardError
      return minutes
    end

    def harvest_amount(data, ex)
      amount = super
      berry = data_item(data[0]).db_symbol
      amount += 1 if MeteoSaisons.setting('berry_effects') && MeteoSaisons.berry_season_in?(berry) == true
      return amount
    rescue StandardError
      return amount
    end
  end

  def install_hooks
    return if @hooks || !defined?(ChampsBaies::Growth)

    ChampsBaies::Growth.singleton_class.prepend(BerryGrowth)
    @hooks = true
  end
  install_hooks
end
