# encoding: utf-8
# Météo et saisons : commandes d'évènement
#   saison                  saison actuelle (:spring, :summer, :autumn, :winter)
#   saison_fixer(:winter)   fixe la saison (mode manual)
#   meteo_zone_symbole      météo prévue pour la zone actuelle (symbole), nil si la zone n'a pas de météo changeante
#   meteo_zone              message : « Printemps : pluie »
#   meteo_actualiser        applique tout de suite la météo prévue de la zone
class Interpreter
  def saison
    return MeteoSaisons.season.to_sym
  end

  def saison_fixer(name)
    return MeteoSaisons.set_season(name)
  end

  def meteo_zone_symbole
    return nil unless MeteoSaisons.managed?($env.current_zone_data)

    weather = MeteoSaisons.forecast
    return weather ? weather.to_sym : nil
  end

  def meteo_zone
    weather = MeteoSaisons.forecast || MeteoSaisons.current_weather
    display_message_and_wait("#{MeteoSaisons.season_name} : #{MeteoSaisons.weather_name(weather)}")
  end

  def meteo_actualiser
    MeteoSaisons.refresh(announce: false)
  end
end
