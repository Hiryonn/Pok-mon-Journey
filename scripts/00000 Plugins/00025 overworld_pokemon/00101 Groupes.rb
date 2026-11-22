# Overworld Pokémon : choix des Pokémon dans les groupes sauvages de la zone
module OverworldPokemon
  WATER_TAGS = %w[Ocean Pond Sea Lake WetSand].freeze
  WATER_TOOLS = %w[OldRod GoodRod SuperRod].freeze

  module_function

  # @param map_id [Integer]
  # @return [Studio::Zone, nil] zone de la carte (sinon la zone en cours)
  def zone_of(map_id)
    if defined?(GameData::Zone) && GameData::Zone.respond_to?(:all)
      zone = GameData::Zone.all.find { |z| z.respond_to?(:maps) && z.maps.to_a.include?(map_id) }
      return zone if zone
    end
    return $env&.current_zone_data
  rescue StandardError
    return $env&.current_zone_data
  end

  # Groupes sauvages de la zone utilisables (sol : ni eau, ni pêche, ni outil) dont les conditions sont remplies
  # @return [Array<Studio::Group>]
  def land_groups(zone)
    return [] unless zone

    groups = zone.wild_groups.to_a.map { |db_symbol| data_group(db_symbol) }.compact
    return groups.select { |group| land_group?(group) && group_active?(group) }
  rescue StandardError => e
    log_error("groupes illisibles (#{e.message})")
    return []
  end

  # @param group [Studio::Group]
  def land_group?(group)
    return false if WATER_TAGS.include?(group.system_tag.to_s)
    return false if WATER_TOOLS.include?(group.tool.to_s)

    tool = group.tool.to_s
    return tool.empty? || tool.casecmp?('none')
  end

  # @param group [Studio::Group]
  def group_active?(group)
    return group.custom_conditions.to_a.reduce(true) do |previous, condition|
      current = condition_ok?(condition)
      condition.relation_with_previous_condition.to_s.casecmp?('OR') ? (previous || current) : (previous && current)
    end
  rescue StandardError
    return true
  end

  def condition_ok?(condition)
    value = condition.value.to_i
    case condition.type.to_s
    when 'mapId' then return $game_map.map_id == value
    when 'enabledSwitch' then return $game_switches[value] ? true : false
    when 'disabledSwitch' then return !$game_switches[value]
    end
    return true
  end

  # @param name [String] tag système d'un groupe (Studio)
  # @return [Integer, nil] valeur du tag système (GameData::SystemTags)
  def tag_value(name)
    return nil if name.to_s.empty?

    @tag_cache ||= {}
    return @tag_cache[name] if @tag_cache.key?(name)

    tags = GameData::SystemTags
    name = (setting('tag_aliases')[name.to_s] || name).to_s
    key = name.downcase.delete('_')
    const = tags.constants.find { |c| c.to_s.downcase.delete('_') == key }
    log_error("tag système inconnu : #{name} (voir tag_aliases)") unless const
    return @tag_cache[name] = const ? tags.const_get(const) : nil
  rescue StandardError
    return @tag_cache[name] = nil
  end

  # Tire un Pokémon (espèce, forme, niveau) dans les groupes, pondéré par la chance de rencontre
  # @return [Array(Studio::Group, Object, Integer), nil] groupe, rencontre, niveau
  def roll(groups)
    entries = groups.flat_map { |group| group.encounters.to_a.map { |enc| [group, enc] } }
    excluded = setting('excluded_species').map(&:to_s)
    entries.reject! { |_group, enc| excluded.include?(enc.specie.to_s) }
    return nil if entries.empty?

    total = entries.sum { |_g, enc| weight(enc) }
    pick = rand * total
    entries.each do |group, enc|
      pick -= weight(enc)
      return [group, enc, level_of(enc)] if pick <= 0
    end
    group, enc = entries.last
    return [group, enc, level_of(enc)]
  end

  def weight(enc)
    value = enc.respond_to?(:chance) ? enc.chance.to_f : 1.0
    value = value > 0 ? value : 1.0
    value *= MeteoSaisons.spawn_factor(enc.specie, enc.respond_to?(:form) ? enc.form.to_i : 0) if defined?(MeteoSaisons)
    value *= PiqueNique.spawn_factor(enc.specie, enc.respond_to?(:form) ? enc.form.to_i : 0) if defined?(PiqueNique)
    return value
  end

  # Niveau de la rencontre (Studio), sinon niveau de l'équipe
  def level_of(enc)
    level = nil
    setup = enc.respond_to?(:level_setup) ? enc.level_setup : nil
    value = setup.respond_to?(:level) ? setup.level : nil
    if value.is_a?(Integer)
      level = value
    elsif value.respond_to?(:minimum) && value.respond_to?(:maximum)
      level = rand(value.minimum.to_i..[value.maximum.to_i, value.minimum.to_i].max)
    end
    level ||= [($actors || []).compact.map(&:level).max.to_i - rand(0..3), 2].max
    variation = setting('level_variation').to_i
    level += rand(-variation..variation) if variation > 0
    return level.clamp(1, 100)
  rescue StandardError
    return [($actors || []).compact.map(&:level).max.to_i, 2].max
  end
end
