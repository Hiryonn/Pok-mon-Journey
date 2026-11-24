# encoding: utf-8
# Météo et saisons : la météo de chaque zone
require 'zlib'

module MeteoSaisons
  module_function

  # @return [String, nil] identifiant de la zone actuelle
  def zone_key(zone = $env&.current_zone_data)
    return nil unless zone

    key = zone.respond_to?(:db_symbol) ? zone.db_symbol : (zone.respond_to?(:id) ? zone.id : nil)
    return key.to_s
  rescue StandardError
    return nil
  end

  # Lignes du tableau : { 'zone', 'season', 'weather', 'weight' }
  def forecast_rows
    rows = Array(config.forecast).select { |row| row.is_a?(Hash) }
    return rows unless rows.empty?

    return DEFAULT_FORECAST.map { |season, weather, weight| { 'zone' => '', 'season' => season, 'weather' => weather, 'weight' => weight } }
  end

  # @return [Array<Hash>] lignes qui valent pour la zone et la saison (celles de la zone seule si elle en a)
  def rows_for(zone, season)
    rows = forecast_rows.select { |row| fetch(row, 'season').to_s.empty? || fetch(row, 'season').to_s == season }
    own = rows.select { |row| fetch(row, 'zone').to_s == zone.to_s && !zone.to_s.empty? }
    return own unless own.empty?

    return rows.select { |row| fetch(row, 'zone').to_s.empty? }
  end

  # La zone a-t-elle une météo changeante ?
  def managed?(zone)
    return false if zone.nil?
    return false if setting('excluded_maps').map(&:to_i).include?($game_map&.map_id.to_i)
    return false if setting('respect_forced') && forced?(zone)
    return true if setting('all_zones')

    return forecast_rows.any? { |row| fetch(row, 'zone').to_s == zone.to_s }
  end

  def forced?(zone_data = $env&.current_zone_data)
    return !zone_data.forced_weather.nil? if zone_data.respond_to?(:forced_weather)

    return false
  rescue StandardError
    return false
  end

  # Période de la météo : change_hours heures réelles
  def block
    hours = [setting('change_hours').to_i, 1].max
    return (Time.now.to_i / 3600) / hours
  end

  # @return [String, nil] météo tirée pour la zone (la même pendant toute la période)
  def forecast(zone = zone_key, at = block)
    rows = rows_for(zone, season).select { |row| fetch(row, 'weight').to_i > 0 }
    return nil if rows.empty?

    random = Random.new(Zlib.crc32("#{at}-#{zone}-#{season}-#{$trainer&.id_public}"))
    pick = random.rand(rows.sum { |row| fetch(row, 'weight').to_i })
    rows.each do |row|
      pick -= fetch(row, 'weight').to_i
      return fetch(row, 'weather').to_s if pick < 0
    end
    return fetch(rows.last, 'weather').to_s
  end

  # Applique la météo de la zone actuelle
  # @param announce [Boolean] bannière du téléphone si la météo change
  def refresh(announce: false)
    zone = zone_key
    return unless zone && managed?($env.current_zone_data)

    weather = forecast(zone)
    return unless weather && weather != current_weather
    return unless apply_weather(weather)

    state['applied'] = block
    return unless announce && setting('notify') && defined?(UI::PokeSmart::Notify)

    UI::PokeSmart::Notify.push(format(t('Météo : %s', 'Weather: %s'), weather_name(weather)), title: season_name)
  end
end

class Game_Map
  module MeteoSaisonsSetup
    def setup(map_id)
      result = super
      MeteoSaisons.refresh
      MeteoSaisons.install_hooks
      return result
    rescue StandardError => e
      log_error("Météo et saisons : #{e.message}") if respond_to?(:log_error, true)
      return result
    end
  end
  prepend MeteoSaisonsSetup
end

# La météo est revérifiée de temps en temps (changement de période)
class Scene_Map
  module MeteoSaisonsTick
    def update
      super
      @pj_meteo_tick = (@pj_meteo_tick || 0) + 1
      return unless @pj_meteo_tick % 600 == 0

      MeteoSaisons.refresh(announce: true) if $game_map && MeteoSaisons.state['applied'] != MeteoSaisons.block
    rescue StandardError => e
      log_error("Météo et saisons : #{e.message}") if respond_to?(:log_error, true)
    end
  end
  prepend MeteoSaisonsTick
end
