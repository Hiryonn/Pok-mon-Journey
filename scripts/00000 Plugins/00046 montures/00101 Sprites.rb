# Montures : sprite du héros sur sa monture (sprites faits main, graphics/characters)
#
# Chaque héros a une ressource par monture dans Studio (Données > Personnages > Héros > Ressources > Montures),
# enregistrée comme l'apparence « ride_<monture> » du héros (plugin personnages). Le jeu cherche, dans l'ordre :
#   1. la ressource « ride_<monture> » du héros actuel ;
#   2. <base>_<g>_ride_<monture> dans graphics/characters (ex. : player_m_ride_wyrdeer, utile pour le générateur).
# Sans sprite, le héros garde son sprite habituel (marche, course, surf) mais va à la vitesse de sa monture.
module Montures
  module_function

  # @param mount [Hash]
  # @return [String, nil] sprite du héros sur cette monture
  def charset(mount)
    key = "ride_#{mount['id']}"
    file = hero_sprite(key)
    return file if file && character_exist?(file)

    base = $game_player&.charset_base.to_s
    return nil if base.empty? || base.start_with?('pj_heros_')

    gender = $game_switches && $game_switches[Yuki::Sw::Gender] ? 'f' : 'm'
    name = "#{base}_#{gender}_#{key}"
    return character_exist?(name) ? name : nil
  end

  # Ressource du héros actuel (plugin personnages)
  # @return [String, nil]
  def hero_sprite(key)
    return nil unless defined?(::Personnages) && ::Personnages.respond_to?(:current_hero)

    hero = ::Personnages.current_hero
    return nil if hero.nil? || hero['generator']

    return ::Personnages.sprites(hero)[key]
  rescue StandardError
    return nil
  end

  def character_exist?(name)
    @exist ||= {}
    return @exist[name] if @exist.key?(name)

    return @exist[name] = RPG::Cache.character_exist?(name) ? true : false
  rescue StandardError
    return false
  end
end
