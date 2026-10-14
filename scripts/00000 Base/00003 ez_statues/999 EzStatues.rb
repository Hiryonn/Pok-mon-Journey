# EZ Statues
#
# Author : Raty
# License : MIT
#
# A PSDK plugin that lets you easily create customizable statues.
#
# Documentation :
# https://github.com/RatyHub/EZ-Statues

module Configs
  module Project
    class EzStatues
      FILENAME = File.join('plugins', 'ez_statues_config')

      attr_accessor :default_preset_id
      attr_accessor :presets

      def initialize
        @default_preset_id = 1
        @presets = []
      end

      def to_h
        return {
          default_preset_id: @default_preset_id,
          presets: @presets
        }
      end
    end
  end

  register(:ez_statues, Project::EzStatues::FILENAME, :json, true, Project::EzStatues)
end

module EzStatues
  DEFAULTS = {
    preset_id: 1,
    form: 0,
    base: { image: '', scale: 1.0, show_when_empty: true }.freeze,
    pokemon: { x: 0, y: 0 }.freeze,
    shadow: { color: [0, 0, 0].freeze, opacity: 0.0, y_offset: 0 }.freeze,
    tint: {
      color: [96, 127, 160].freeze,
      darkness: 0.55,
      lightness: 0.55,
      contrast: 1.16,
      brightness: 0.03
    }.freeze
  }.freeze

  Shader.register(:ez_statues_tint, <<~SHADER)
    uniform sampler2D texture;
    uniform vec3 tint_dark;
    uniform vec3 tint_light;
    uniform float tint_contrast;
    uniform float tint_brightness;

    const vec3 lumaF = vec3(.299, .587, .114);

    void main() {
      vec4 frag = texture2D(texture, gl_TexCoord[0].xy);
      float luma = dot(frag.rgb, lumaF);
      luma = clamp((luma - 0.5) * tint_contrast + 0.5 + tint_brightness, 0.0, 1.0);
      frag.rgb = mix(tint_dark, tint_light, luma);
      frag.a *= gl_Color.a;
      gl_FragColor = frag;
    }
  SHADER

  module_function

  def config
    @config ||= load_config
  end

  def config_version
    @config_version ||= 0
  end

  def reload_config
    @config = nil
    @normalized_presets = nil
    @logged_errors = nil
    @config_version = config_version + 1
    unless PSDK_CONFIG.release?
      Configs.register(:ez_statues, Configs::Project::EzStatues::FILENAME, :json, true, Configs::Project::EzStatues)
    end
    return config
  end

  def refresh_current_map_events
    return 0 unless defined?($game_map) && $game_map&.respond_to?(:events)

    refreshed_count = 0
    $game_map.events.each_value do |event|
      next unless event.respond_to?(:reload_ez_statue_event)

      refreshed_count += 1 if event.reload_ez_statue_event
    end
    return refreshed_count
  rescue => e
    log_once(
      [:refresh_current_map_events_error, e.class, e.message],
      "failed to refresh current map statue events after config reload: #{e.class}: #{e.message}"
    )
    return 0
  end

  def load_config
    return build_config(read_config_file)
  rescue StandardError => e
    log_once(
      [:config_load_error, e.class, e.message],
      "failed to load config file #{config_filename}: #{e.class}: #{e.message}; using empty defaults"
    )
    return build_config({})
  end

  def read_config_file
    data = Configs.ez_statues.to_h
    return data if data.is_a?(Hash)

    log_once(:invalid_config_root, "compiled config #{config_filename} should contain an object; using empty defaults")
    return {}
  end

  def config_filename
    return File.join('Data', 'configs', 'plugins', 'ez_statues_config.json')
  end

  def build_config(data)
    presets = parse_config_presets(data[:presets])
    default_preset_id = parse_default_preset_id(data[:default_preset_id], presets)
    return {
      default_preset_id: default_preset_id,
      presets: presets
    }
  end

  def parse_config_presets(value)
    unless value.is_a?(Array)
      log_once(:invalid_config_presets, "config #{config_filename} should contain a presets array; no presets loaded")
      return {}
    end

    presets = {}
    value.each_with_index do |preset_data, index|
      next if preset_data.nil?

      unless preset_data.is_a?(Hash)
        log_once(
          [:invalid_config_preset, index, preset_data.class],
          "config preset at index #{index} should be an object, got #{preset_data.inspect}; ignored"
        )
        next
      end

      preset_id = parse_config_preset_id(preset_data[:id], index)
      next unless preset_id

      if presets.key?(preset_id)
        log_once(
          [:duplicate_config_preset, preset_id],
          "duplicate preset id #{preset_id} in #{config_filename}; keeping first declaration"
        )
        next
      end

      presets[preset_id] = preset_data
    end
    return presets
  end

  def parse_config_preset_id(value, index)
    unless value
      log_once(
        [:missing_config_preset_id, index],
        "config preset at index #{index} is missing id; using #{index + 1}"
      )
      return index + 1
    end

    raw_value = value.to_s.strip
    if raw_value.empty? || !raw_value.match?(/\A\d+\z/) || raw_value.to_i <= 0
      log_once(
        [:invalid_config_preset_id, index, value],
        "config preset at index #{index} has invalid id #{value.inspect}; ignored"
      )
      return nil
    end

    return raw_value.to_i
  end

  def parse_default_preset_id(value, presets)
    default_id = parse_positive_integer(value, DEFAULTS[:preset_id], 'default_preset_id')
    return default_id if presets.empty? || presets.key?(default_id)

    fallback_id = presets.keys.min
    log_once(
      [:missing_default_preset, default_id, fallback_id],
      "default_preset_id #{default_id} was not found in #{config_filename}; using preset #{fallback_id}"
    )
    return fallback_id
  end

  def parse_positive_integer(value, fallback, key)
    return fallback if value.nil?

    raw_value = value.to_s.strip
    return raw_value.to_i if raw_value.match?(/\A\d+\z/) && raw_value.to_i > 0

    log_once(
      [:invalid_config_integer, key, value],
      "config #{key} should be an integer >= 1, got #{value.inspect}; using #{fallback}"
    )
    return fallback
  end

  def default_preset_id
    return config[:default_preset_id]
  end

  def raw_presets
    return config[:presets]
  end

  def raw_preset(preset_id)
    return raw_presets[preset_id]
  end

  def preset_exists?(preset_id)
    return raw_presets.key?(preset_id)
  end

  def statue_event_name?(event_name)
    return !!statue_tag_match(event_name)
  end

  def statue_tag_match(event_name)
    return event_name.to_s.match(/\[statue=(?::(?<db_symbol>[a-z0-9_]+)|\$actors\[(?<actor_index>\d+)\])(?<options>[^\]]*)\]/i)
  end

  def parse_tag_options(raw_options)
    options = raw_options.to_s.sub(/\A\s*,\s*/, '').strip
    return { preset_id: nil, form: nil, overrides: {}, valid: true } if options.empty?

    tag_options = { preset_id: nil, form: nil, overrides: {}, valid: true }
    options.split(',').each_with_index do |raw_token, index|
      token = raw_token.strip
      next if token.empty?

      unless token.include?('=')
        log_once(
          [:invalid_tag_option, options, index, token],
          "invalid statue tag option #{token.inspect} in #{options.inspect}; expected key=value"
        )
        tag_options[:valid] = false
        next
      end

      parse_tag_assignment_token(token, tag_options)
    end
    return tag_options
  end

  def parse_tag_assignment_token(token, tag_options)
    raw_key, raw_value = token.split('=', 2)
    key = raw_key.to_s.strip.downcase
    case key
    when 'preset'
      tag_options[:preset_id] = raw_value.to_s.strip
    when 'form'
      tag_options[:form] = parse_form_id(raw_value)
    else
      tag_options[:valid] = false unless parse_override_token(token, tag_options[:overrides])
    end
  end

  def parse_override_token(token, overrides)
    raw_key, raw_value = token.split('=', 2)
    key = raw_key.to_s.strip.downcase
    spec = override_spec(key)
    unless spec
      log_once(
        [:unknown_override_key, key],
        "unknown override #{raw_key.inspect}; expected one of #{override_keys.inspect}"
      )
      return false
    end

    path, value_type = spec
    assign_override_value(overrides, path, parse_override_value(raw_value, value_type))
    return true
  end

  def override_spec(key)
    case key
    when 'mode' then [[:mode], :symbol]
    when 'direction' then [[:direction], :symbol]
    when 'base' then [[:base, :image], :string]
    when 'base.image' then [[:base, :image], :string]
    when 'base.scale' then [[:base, :scale], :number]
    when 'base.show_when_empty' then [[:base, :show_when_empty], :boolean]
    when 'pokemon.x' then [[:pokemon, :x], :number]
    when 'pokemon.y' then [[:pokemon, :y], :number]
    when 'shadow.color' then [[:shadow, :color], :rgb]
    when 'shadow.opacity' then [[:shadow, :opacity], :number]
    when 'shadow.y_offset' then [[:shadow, :y_offset], :number]
    when 'tint.color' then [[:tint, :color], :rgb]
    when 'tint.darkness' then [[:tint, :darkness], :number]
    when 'tint.lightness' then [[:tint, :lightness], :number]
    when 'tint.contrast' then [[:tint, :contrast], :number]
    when 'tint.brightness' then [[:tint, :brightness], :number]
    end
  end

  def override_keys
    return %w[
      mode direction base base.image base.scale base.show_when_empty pokemon.x pokemon.y
      shadow.color shadow.opacity shadow.y_offset tint.color tint.darkness
      tint.lightness tint.contrast tint.brightness
    ]
  end

  def parse_override_value(raw_value, value_type)
    value = unquote(raw_value.to_s.strip)
    case value_type
    when :number
      return parse_override_number(value)
    when :rgb
      return parse_override_rgb(value)
    when :symbol
      return value.to_sym
    when :boolean
      return parse_override_boolean(value)
    else
      return value
    end
  end

  def parse_override_number(value)
    return value.to_f if value.match?(/\A-?\d+\.\d+\z/)
    return value.to_i if value.match?(/\A-?\d+\z/)

    return value
  end

  def parse_form_id(raw_value)
    value = unquote(raw_value.to_s.strip)
    return value.to_i if value.match?(/\A-?\d+\z/)

    log_once(
      [:invalid_form_id, value],
      "invalid form #{raw_value.inspect}, expected an integer, fallback to #{DEFAULTS[:form]}"
    )
    return DEFAULTS[:form]
  end

  def parse_override_rgb(value)
    components = value.split(/[|;\/:]/).map(&:strip)
    return value unless components.size == 3

    return components.map { |component| parse_override_number(component) }
  end

  def parse_override_boolean(value)
    normalized_value = value.to_s.strip.downcase
    return true if %w[true yes oui on 1].include?(normalized_value)
    return false if %w[false no non off 0].include?(normalized_value)

    return value
  end

  def unquote(value)
    return value[1...-1] if value.size >= 2 && value.start_with?('"') && value.end_with?('"')
    return value[1...-1] if value.size >= 2 && value.start_with?("'") && value.end_with?("'")

    return value
  end

  def assign_override_value(overrides, path, value)
    current = overrides
    path[0...-1].each do |key|
      current[key] ||= {}
      current = current[key]
    end
    current[path.last] = value
  end

  def statue_data_from_event_name(event_name)
    match = statue_tag_match(event_name)
    return nil unless match

    tag_options = parse_tag_options(match[:options])
    return nil unless tag_options[:valid]

    preset_id = normalize_preset_id(tag_options[:preset_id])
    preset_data = preset(preset_id, tag_options[:overrides])
    source_data = statue_source_data(match)
    unless source_data
      form = tag_options[:form] || DEFAULTS[:form]
      return { db_symbol: nil, form: form, preset_id: preset_id, overrides: tag_options[:overrides] }
    end

    creature = data_creature(source_data[:db_symbol])
    form = tag_options[:form] || source_data[:form]
    log_missing_form(creature, form)
    return { db_symbol: creature.db_symbol, form: form, preset_id: preset_id, overrides: tag_options[:overrides] }
  rescue => e
    log("statue_data_from_event_name: #{e.message}")
    return nil
  end

  def statue_source_data(match)
    actor_index = match[:actor_index]
    return statue_source_data_from_actor(actor_index) if actor_index

    return statue_source_data_from_db_symbol(match[:db_symbol])
  end

  def statue_source_data_from_db_symbol(db_symbol_name)
    creature = data_creature(db_symbol_name.to_s.downcase.to_sym)
    if creature.db_symbol == :__undef__
      log("unknown Pokemon db_symbol #{db_symbol_name.inspect}")
      return nil
    end

    return { db_symbol: creature.db_symbol, form: DEFAULTS[:form] }
  end

  def statue_source_data_from_actor(raw_actor_index)
    actor_index = raw_actor_index.to_i
    unless (0..5).cover?(actor_index)
      log_once(
        [:invalid_actor_slot, actor_index],
        "invalid party slot $actors[#{actor_index}], expected 0..5"
      )
      return nil
    end

    unless defined?($actors) && $actors
      log_once(
        [:missing_actors, actor_index],
        "cannot resolve $actors[#{actor_index}] because $actors is not available"
      )
      return nil
    end

    pokemon = $actors[actor_index]
    unless defined?(PFM::Pokemon) && pokemon.is_a?(PFM::Pokemon)
      actual_type = pokemon.nil? ? 'nil' : pokemon.class.to_s
      log_once(
        [:missing_actor_pokemon, actor_index, actual_type],
        "$actors[#{actor_index}] does not contain a PFM::Pokemon, got #{actual_type}; Pokemon graphic disabled"
      )
      return nil
    end

    if pokemon.egg?
      log_once(
        [:actor_pokemon_egg, actor_index],
        "$actors[#{actor_index}] is an egg; Pokemon graphic disabled"
      )
      return nil
    end

    creature = data_creature(pokemon.db_symbol)
    if creature.db_symbol == :__undef__
      log_once(
        [:unknown_actor_pokemon, actor_index, pokemon.db_symbol],
        "$actors[#{actor_index}] has unknown Pokemon db_symbol #{pokemon.db_symbol.inspect}; Pokemon graphic disabled"
      )
      return nil
    end

    return { db_symbol: creature.db_symbol, form: normalize_form_id(pokemon.form) }
  rescue => e
    log_once(
      [:actor_source_error, raw_actor_index, e.class, e.message],
      "failed to resolve $actors[#{raw_actor_index}]: #{e.class}: #{e.message}; Pokemon graphic disabled"
    )
    return nil
  end

  def encoded_character_name(db_symbol, form, preset_id)
    return "__ez_statues__:#{db_symbol || '__missing__'}:#{normalize_form_id(form)}:#{normalize_preset_id(preset_id)}"
  end

  def encoded_character_name?(character_name)
    return character_name.to_s.start_with?('__ez_statues__:')
  end

  def db_symbol_from_character_name(character_name)
    return nil unless encoded_character_name?(character_name)

    db_symbol_name = encoded_character_payload(character_name).first.to_s
    return nil if db_symbol_name.empty? || db_symbol_name == '__missing__'

    return db_symbol_name.to_sym
  end

  def form_from_character_name(character_name)
    return DEFAULTS[:form] unless encoded_character_name?(character_name)

    payload = encoded_character_payload(character_name)
    return DEFAULTS[:form] unless payload.size == 3

    return normalize_form_id(payload[1])
  end

  def preset_id_from_character_name(character_name)
    return default_preset_id unless encoded_character_name?(character_name)

    payload = encoded_character_payload(character_name)
    return default_preset_id unless payload.size == 3

    return normalize_preset_id(payload[2])
  end

  def preset(preset_id, overrides = nil)
    normalized_id = normalize_preset_id(preset_id)
    @normalized_presets ||= {}
    base_preset = @normalized_presets[normalized_id] ||= build_normalized_preset(normalized_id)
    return base_preset if overrides.nil? || overrides.empty?

    return apply_preset_overrides(base_preset, overrides)
  end

  def apply_preset_overrides(base_preset, overrides)
    preset_data = deep_dup_preset(base_preset)
    preset_data[:override_key] = override_cache_key(overrides)
    preset_id = preset_data[:id]

    preset_data[:mode] = graphic_mode_value(preset_id, 'override mode', overrides[:mode], preset_data[:mode]) if overrides.key?(:mode)
    preset_data[:direction] = direction_value(preset_id, 'override direction', overrides[:direction], preset_data[:direction]) if overrides.key?(:direction)
    apply_base_overrides(preset_data, overrides[:base]) if overrides[:base]
    apply_pokemon_overrides(preset_data, overrides[:pokemon]) if overrides[:pokemon]
    apply_shadow_overrides(preset_data, overrides[:shadow]) if overrides[:shadow]
    apply_tint_overrides(preset_data, overrides[:tint]) if overrides[:tint]
    return preset_data
  end

  def apply_base_overrides(preset_data, overrides)
    preset_id = preset_data[:id]
    preset_data[:base][:image] = filename_setting(preset_id, 'override base.image', overrides, :image, preset_data[:base][:image]) if overrides.key?(:image)
    preset_data[:base][:scale] = numeric_setting(preset_id, 'override base.scale', overrides, :scale, preset_data[:base][:scale], min: 0.01) if overrides.key?(:scale)
    preset_data[:base][:show_when_empty] = boolean_setting(preset_id, 'override base.show_when_empty', overrides, :show_when_empty, preset_data[:base][:show_when_empty]) if overrides.key?(:show_when_empty)
  end

  def apply_pokemon_overrides(preset_data, overrides)
    preset_id = preset_data[:id]
    preset_data[:pokemon][:x] = numeric_setting(preset_id, 'override pokemon.x', overrides, :x, preset_data[:pokemon][:x]) if overrides.key?(:x)
    preset_data[:pokemon][:y] = numeric_setting(preset_id, 'override pokemon.y', overrides, :y, preset_data[:pokemon][:y]) if overrides.key?(:y)
  end

  def apply_shadow_overrides(preset_data, overrides)
    preset_id = preset_data[:id]
    preset_data[:shadow][:color] = rgb_setting(preset_id, 'override shadow.color', overrides, :color, preset_data[:shadow][:color]) if overrides.key?(:color)
    preset_data[:shadow][:opacity] = numeric_setting(preset_id, 'override shadow.opacity', overrides, :opacity, preset_data[:shadow][:opacity], min: 0.0, max: 1.0) if overrides.key?(:opacity)
    preset_data[:shadow][:y_offset] = numeric_setting(preset_id, 'override shadow.y_offset', overrides, :y_offset, preset_data[:shadow][:y_offset]) if overrides.key?(:y_offset)
  end

  def apply_tint_overrides(preset_data, overrides)
    preset_id = preset_data[:id]
    preset_data[:tint][:color] = rgb_setting(preset_id, 'override tint.color', overrides, :color, preset_data[:tint][:color]) if overrides.key?(:color)
    preset_data[:tint][:darkness] = numeric_setting(preset_id, 'override tint.darkness', overrides, :darkness, preset_data[:tint][:darkness], min: 0.0, max: 1.0) if overrides.key?(:darkness)
    preset_data[:tint][:lightness] = numeric_setting(preset_id, 'override tint.lightness', overrides, :lightness, preset_data[:tint][:lightness], min: 0.0, max: 1.0) if overrides.key?(:lightness)
    preset_data[:tint][:contrast] = numeric_setting(preset_id, 'override tint.contrast', overrides, :contrast, preset_data[:tint][:contrast], min: 0.0) if overrides.key?(:contrast)
    preset_data[:tint][:brightness] = numeric_setting(preset_id, 'override tint.brightness', overrides, :brightness, preset_data[:tint][:brightness]) if overrides.key?(:brightness)
  end

  def deep_dup_preset(preset_data)
    return {
      id: preset_data[:id],
      name: preset_data[:name],
      mode: preset_data[:mode],
      direction: preset_data[:direction],
      base: preset_data[:base].dup,
      pokemon: preset_data[:pokemon].dup,
      shadow: preset_data[:shadow].dup,
      tint: preset_data[:tint].dup
    }
  end

  def override_cache_key(overrides)
    return nil if overrides.nil? || overrides.empty?

    return overrides.inspect
  end

  def graphic_data(db_symbol, form, preset_data)
    unless db_symbol
      log_once(:missing_db_symbol, 'missing Pokemon db_symbol, Pokemon graphic disabled')
      return nil
    end

    return character_graphic_data(db_symbol, form, preset_data) if graphic_mode(preset_data) == :character

    return pokeicon_graphic_data(db_symbol, form)
  end

  def graphic_mode(preset_data)
    mode = preset_data.is_a?(Hash) ? preset_data[:mode] : nil
    return mode if %i[pokeicon character].include?(mode)

    log_invalid_graphic_mode(mode, preset_data)
    return :pokeicon
  end

  def pokeicon_graphic_data(db_symbol, form)
    creature = data_creature(db_symbol)
    if creature.db_symbol == :__undef__
      log_once([:unknown_pokeicon_pokemon, db_symbol], "unknown Pokemon #{db_symbol.inspect}, Pokemon graphic disabled")
      return nil
    end

    filename = PFM::Pokemon.icon_filename(creature.id, form, false, false, false)
    if filename.to_s == '000'
      log_once(
        [:missing_pokeicon_configuration, db_symbol, form],
        "missing pokeicon configuration for #{db_symbol.inspect} form #{form}, Pokemon graphic disabled"
      )
      return nil
    end

    unless valid_pokeicon_filename?(filename)
      log_once(
        [:missing_pokeicon, db_symbol, form, filename],
        "missing pokeicon resource #{filename.inspect} for #{db_symbol.inspect} form #{form}, Pokemon graphic disabled"
      )
      return nil
    end

    bitmap = RPG::Cache.b_icon(filename)
    return pokeicon_bitmap_graphic_data(bitmap, db_symbol, filename)
  rescue => e
    log_once(
      [:pokeicon_load_error, db_symbol, form, e.class, e.message],
      "failed to load pokeicon for #{db_symbol.inspect} form #{form}: #{e.message}, Pokemon graphic disabled"
    )
    return nil
  end

  def character_graphic_data(db_symbol, form, preset_data)
    creature = data_creature(db_symbol)
    if creature.db_symbol == :__undef__
      log_once([:unknown_character_pokemon, db_symbol], "unknown Pokemon #{db_symbol.inspect}, Pokemon graphic disabled")
      return nil
    end

    filename = data_creature_form(creature.id, form)&.resources&.character.to_s
    unless valid_character_filename?(filename)
      log_once(
        [:missing_character, db_symbol, form, filename],
        "missing character resource #{filename.inspect} for #{db_symbol.inspect} form #{form}, Pokemon graphic disabled"
      )
      return nil
    end

    bitmap = RPG::Cache.character(filename, 0)
    unless valid_character_sheet?(bitmap)
      log_once(
        [:invalid_character_sheet, db_symbol, form, filename, bitmap_size_text(bitmap)],
        "character resource #{filename.inspect} for #{db_symbol.inspect} form #{form} should be a 4x4 spritesheet, got #{bitmap_size_text(bitmap)}, Pokemon graphic disabled"
      )
      return nil
    end

    frame_width = bitmap.width / 4
    frame_height = bitmap.height / 4
    return {
      bitmap: bitmap,
      src_x: 0,
      src_y: direction_row(preset_data) * frame_height,
      frame_width: frame_width,
      frame_height: frame_height
    }
  rescue => e
    log_once(
      [:character_load_error, db_symbol, form, e.class, e.message],
      "failed to load character graphic for #{db_symbol.inspect} form #{form}: #{e.message}, Pokemon graphic disabled"
    )
    return nil
  end

  def tint_shader(preset_data)
    tint_data = preset_data[:tint] || {}
    shader = Shader.create(:ez_statues_tint)
    shader.set_float_uniform('tint_dark', shader_rgb(tint_dark_color(tint_data)))
    shader.set_float_uniform('tint_light', shader_rgb(tint_light_color(tint_data)))
    shader.set_float_uniform('tint_contrast', tint_data.fetch(:contrast, DEFAULTS[:tint][:contrast]))
    shader.set_float_uniform('tint_brightness', tint_data.fetch(:brightness, DEFAULTS[:tint][:brightness]))
    return shader
  end

  def tint_dark_color(tint_data)
    color = tint_data[:color] || DEFAULTS[:tint][:color]
    darkness = tint_data.fetch(:darkness, DEFAULTS[:tint][:darkness])
    return color.map { |component| tint_channel(component * (1.0 - darkness)) }
  end

  def tint_light_color(tint_data)
    color = tint_data[:color] || DEFAULTS[:tint][:color]
    lightness = tint_data.fetch(:lightness, DEFAULTS[:tint][:lightness])
    return color.map { |component| tint_channel(component + (255 - component) * lightness) }
  end

  def tint_channel(value)
    return [[value.round, 0].max, 255].min
  end

  def shadow_shader(preset_data)
    shadow_data = preset_data[:shadow] || {}
    shader = Shader.create(:color_shader)
    shader.set_float_uniform('color', shader_rgba(shadow_data[:color] || DEFAULTS[:shadow][:color], 1.0))
    return shader
  end

  def base_bitmap(preset_data)
    image = base_image(preset_data)
    return nil if image.to_s.empty?

    unless valid_picture_filename?(image)
      log_once(
        [:missing_base_picture, preset_id(preset_data), image],
        "preset #{preset_id(preset_data)} missing base picture #{image.inspect}, base disabled"
      )
      return nil
    end

    return RPG::Cache.picture(image)
  rescue => e
    log_once(
      [:base_load_error, preset_id(preset_data), image, e.class, e.message],
      "preset #{preset_id(preset_data)} failed to load base picture #{image.inspect}: #{e.message}, base disabled"
    )
    return nil
  end

  def base_image(preset_data)
    return (preset_data[:base] || {})[:image].to_s
  end

  def base_scale(preset_data)
    return (preset_data[:base] || {}).fetch(:scale, DEFAULTS[:base][:scale])
  end

  def base_show_when_empty?(preset_data)
    return (preset_data[:base] || {}).fetch(:show_when_empty, DEFAULTS[:base][:show_when_empty])
  end

  def pokemon_x(preset_data)
    return (preset_data[:pokemon] || {}).fetch(:x, DEFAULTS[:pokemon][:x])
  end

  def pokemon_y(preset_data)
    return (preset_data[:pokemon] || {}).fetch(:y, DEFAULTS[:pokemon][:y])
  end

  def shadow_y_offset(preset_data)
    return (preset_data[:shadow] || {}).fetch(:y_offset, DEFAULTS[:shadow][:y_offset])
  end

  def shadow_y(preset_data)
    return pokemon_y(preset_data) + shadow_y_offset(preset_data)
  end

  def shadow_opacity(preset_data)
    return (preset_data[:shadow] || {}).fetch(:opacity, DEFAULTS[:shadow][:opacity])
  end

  def shadow_source_height(source_height)
    return 0 if source_height.to_i <= 0

    return [(source_height / 2.0).ceil, 1].max
  end

  def direction_row(preset_data)
    direction = (preset_data[:direction] || :face).to_sym
    row = direction_row_value(direction)
    return row unless row.nil?

    log_once(
      [:invalid_direction_runtime, preset_id(preset_data), direction],
      "preset #{preset_id(preset_data)} has invalid direction #{direction.inspect}, fallback to :face"
    )
    return 0
  end

  def direction_row_value(direction)
    case direction
    when :face, :front, :down then 0
    when :gauche, :left then 1
    when :droite, :right then 2
    when :dos, :back, :up then 3
    end
  end

  def direction_names
    return %i[face front down gauche left droite right dos back up]
  end

  def shader_rgb(rgb)
    return rgb.map { |component| component.to_f / 255 }
  end

  def shader_rgba(rgb, alpha)
    return shader_rgb(rgb) + [alpha]
  end

  def build_normalized_preset(preset_id)
    preset_data = raw_preset(preset_id)
    unless preset_data.is_a?(Hash)
      log_once(
        [:invalid_preset_data, preset_id, preset_data.class],
        "preset #{preset_id} should be an object in #{config_filename}, fallback to default settings"
      )
      preset_data = {}
    end

    mode = normalized_graphic_mode(preset_id, preset_data[:mode])
    return {
      id: preset_id,
      name: preset_name(preset_id, preset_data),
      mode: mode,
      direction: normalized_direction(preset_id, preset_data[:direction], mode),
      base: normalized_base_settings(preset_id, preset_data[:base]),
      pokemon: normalized_pokemon_settings(preset_id, preset_data[:pokemon]),
      shadow: normalized_shadow_settings(preset_id, preset_data[:shadow]),
      tint: normalized_tint_settings(preset_id, preset_data[:tint])
    }
  end

  def preset_name(preset_id, preset_data)
    name = preset_data[:name]
    return name.to_s unless name.nil? || name.to_s.empty?

    return "Preset #{preset_id}"
  end

  def normalized_graphic_mode(preset_id, value)
    return graphic_mode_value(preset_id, 'mode', value, :pokeicon)
  end

  def graphic_mode_value(preset_id, path, value, fallback)
    mode = value.to_sym if value.respond_to?(:to_sym)
    return mode if %i[pokeicon character].include?(mode)

    log_once(
      [:invalid_graphic_mode, preset_id, path, value],
      "preset #{preset_id} has invalid #{path} #{value.inspect}, expected #{%i[pokeicon character].inspect}, fallback to #{fallback.inspect}"
    )
    return fallback
  end

  def normalized_direction(preset_id, value, mode)
    return :face if value.nil? && mode == :pokeicon

    if value.nil?
      log_once(
        [:missing_setting, preset_id, 'direction'],
        "preset #{preset_id} is missing direction, fallback to :face"
      )
      return :face
    end

    return direction_value(preset_id, 'direction', value, :face)
  end

  def direction_value(preset_id, path, value, fallback)
    direction = value.to_sym if value.respond_to?(:to_sym)
    return direction unless direction_row_value(direction).nil?

    log_once(
      [:invalid_direction, preset_id, path, value],
      "preset #{preset_id} has invalid #{path} #{value.inspect}, expected one of #{direction_names.inspect}, fallback to #{fallback.inspect}"
    )
    return fallback
  end

  def normalized_base_settings(preset_id, value)
    settings = normalized_section(preset_id, :base, value)
    return {
      image: filename_setting(preset_id, 'base.image', settings, :image, DEFAULTS[:base][:image]),
      scale: numeric_setting(preset_id, 'base.scale', settings, :scale, DEFAULTS[:base][:scale], min: 0.01),
      show_when_empty: boolean_setting(preset_id, 'base.show_when_empty', settings, :show_when_empty, DEFAULTS[:base][:show_when_empty])
    }
  end

  def normalized_pokemon_settings(preset_id, value)
    settings = normalized_section(preset_id, :pokemon, value)
    return {
      x: settings.key?(:x) ? numeric_setting(preset_id, 'pokemon.x', settings, :x, DEFAULTS[:pokemon][:x]) : DEFAULTS[:pokemon][:x],
      y: numeric_setting(preset_id, 'pokemon.y', settings, :y, DEFAULTS[:pokemon][:y])
    }
  end

  def normalized_shadow_settings(preset_id, value)
    settings = normalized_section(preset_id, :shadow, value)
    return {
      color: rgb_setting(preset_id, 'shadow.color', settings, :color, DEFAULTS[:shadow][:color]),
      opacity: numeric_setting(preset_id, 'shadow.opacity', settings, :opacity, DEFAULTS[:shadow][:opacity], min: 0.0, max: 1.0),
      y_offset: numeric_setting(preset_id, 'shadow.y_offset', settings, :y_offset, DEFAULTS[:shadow][:y_offset])
    }
  end

  def normalized_tint_settings(preset_id, value)
    settings = normalized_section(preset_id, :tint, value)
    return {
      color: rgb_setting(preset_id, 'tint.color', settings, :color, DEFAULTS[:tint][:color]),
      darkness: numeric_setting(preset_id, 'tint.darkness', settings, :darkness, DEFAULTS[:tint][:darkness], min: 0.0, max: 1.0),
      lightness: numeric_setting(preset_id, 'tint.lightness', settings, :lightness, DEFAULTS[:tint][:lightness], min: 0.0, max: 1.0),
      contrast: numeric_setting(preset_id, 'tint.contrast', settings, :contrast, DEFAULTS[:tint][:contrast], min: 0.0),
      brightness: numeric_setting(preset_id, 'tint.brightness', settings, :brightness, DEFAULTS[:tint][:brightness])
    }
  end

  def normalized_section(preset_id, section_name, value)
    return value if value.is_a?(Hash)

    log_once(
      [:invalid_preset_section, preset_id, section_name, value.class],
      "preset #{preset_id} has invalid #{section_name} settings #{value.inspect}, expected a Hash, fallback to defaults"
    )
    return {}
  end

  def filename_setting(preset_id, path, settings, key, default)
    unless settings.key?(key)
      log_once(
        [:missing_setting, preset_id, path],
        "preset #{preset_id} is missing #{path}, fallback to #{default.inspect}"
      )
      return default
    end

    value = settings[key]
    unless value.is_a?(String) || value.is_a?(Symbol)
      log_once(
        [:invalid_filename_setting, preset_id, path, value],
        "preset #{preset_id} has invalid #{path} #{value.inspect}, expected a String or Symbol, fallback to #{default.inspect}"
      )
      return default
    end

    filename = value.to_s.strip
    return filename unless filename.empty?

    log_once(
      [:empty_filename_setting, preset_id, path],
      "preset #{preset_id} has empty #{path}, fallback to #{default.inspect}"
    )
    return default
  end

  def numeric_setting(preset_id, path, settings, key, default, min: nil, max: nil, integer: false)
    unless settings.key?(key)
      log_once(
        [:missing_setting, preset_id, path],
        "preset #{preset_id} is missing #{path}, fallback to #{default.inspect}"
      )
      return default
    end

    value = settings[key]
    unless value.is_a?(Numeric)
      log_once(
        [:invalid_numeric_setting, preset_id, path, value],
        "preset #{preset_id} has invalid #{path} #{value.inspect}, expected a number, fallback to #{default.inspect}"
      )
      return default
    end

    if integer && value.to_i != value
      log_once(
        [:invalid_integer_setting, preset_id, path, value],
        "preset #{preset_id} has invalid #{path} #{value.inspect}, expected an integer, fallback to #{default.inspect}"
      )
      return default
    end

    normalized_value = integer ? value.to_i : value.to_f
    if (min && normalized_value < min) || (max && normalized_value > max)
      expected_range = [min ? ">= #{min}" : nil, max ? "<= #{max}" : nil].compact.join(' and ')
      log_once(
        [:out_of_range_numeric_setting, preset_id, path, value],
        "preset #{preset_id} has out-of-range #{path} #{value.inspect}, expected #{expected_range}, fallback to #{default.inspect}"
      )
      return default
    end

    return normalized_value
  end

  def rgb_setting(preset_id, path, settings, key, default)
    unless settings.key?(key)
      log_once(
        [:missing_setting, preset_id, path],
        "preset #{preset_id} is missing #{path}, fallback to #{default.inspect}"
      )
      return default
    end

    value = settings[key]
    unless value.is_a?(Array) && value.size == 3 && value.all? { |component| component.is_a?(Numeric) && component.between?(0, 255) }
      log_once(
        [:invalid_rgb_setting, preset_id, path, value],
        "preset #{preset_id} has invalid #{path} #{value.inspect}, expected [r, g, b] with values from 0 to 255, fallback to #{default.inspect}"
      )
      return default
    end

    return value.map(&:to_i)
  end

  def boolean_setting(preset_id, path, settings, key, default)
    unless settings.key?(key)
      log_once(
        [:missing_setting, preset_id, path],
        "preset #{preset_id} is missing #{path}, fallback to #{default.inspect}"
      )
      return default
    end

    value = settings[key]
    return value if value == true || value == false

    log_once(
      [:invalid_boolean_setting, preset_id, path, value],
      "preset #{preset_id} has invalid #{path} #{value.inspect}, expected true or false, fallback to #{default.inspect}"
    )
    return default
  end

  def valid_pokeicon_filename?(filename)
    return false if filename.to_s.empty?

    return RPG::Cache.b_icon_exist?(filename)
  rescue => e
    log_once(
      [:pokeicon_exist_error, filename, e.class, e.message],
      "failed to check pokeicon resource #{filename.inspect}: #{e.message}"
    )
    return false
  end

  def valid_character_filename?(filename)
    return false if filename.to_s.empty?

    return RPG::Cache.character_exist?(filename)
  rescue => e
    log_once(
      [:character_exist_error, filename, e.class, e.message],
      "failed to check character resource #{filename.inspect}: #{e.message}"
    )
    return false
  end

  def valid_picture_filename?(filename)
    return false if filename.to_s.empty?

    return RPG::Cache.picture_exist?(filename)
  rescue => e
    log_once(
      [:picture_exist_error, filename, e.class, e.message],
      "failed to check picture resource #{filename.inspect}: #{e.message}"
    )
    return false
  end

  def valid_character_sheet?(bitmap)
    return false unless bitmap
    return false if bitmap.width <= 0 || bitmap.height <= 0

    return (bitmap.width % 4).zero? && (bitmap.height % 4).zero?
  end

  def bitmap_size_text(bitmap)
    return 'nil' unless bitmap

    return "#{bitmap.width}x#{bitmap.height}"
  end

  def pokeicon_bitmap_graphic_data(bitmap, db_symbol, filename)
    unless bitmap && bitmap.width > 0 && bitmap.height > 0
      log_once(
        [:invalid_pokeicon_bitmap, db_symbol, filename],
        "pokeicon resource #{filename.inspect} for #{db_symbol.inspect} is empty, Pokemon graphic disabled"
      )
      return nil
    end

    return {
      bitmap: bitmap,
      src_x: 0,
      src_y: 0,
      frame_width: [bitmap.height, bitmap.width].min,
      frame_height: bitmap.height
    }
  end

  def empty_graphic_data
    @empty_graphic_bitmap ||= Texture.new(1, 1).tap { |bitmap| bitmap.fill_rect(0, 0, 1, 1, Color.new(0, 0, 0, 0)) }
    return {
      bitmap: @empty_graphic_bitmap,
      src_x: 0,
      src_y: 0,
      frame_width: 1,
      frame_height: 1
    }
  end

  def encoded_character_payload(character_name)
    return character_name.to_s.sub('__ez_statues__:', '').split(':')
  end

  def normalize_form_id(form)
    return DEFAULTS[:form] if form.nil?

    raw_form = form.to_s.strip
    return raw_form.to_i if raw_form.match?(/\A-?\d+\z/)

    log_once(
      [:invalid_form_id, raw_form],
      "invalid form #{form.inspect}, expected an integer, fallback to #{DEFAULTS[:form]}"
    )
    return DEFAULTS[:form]
  end

  def log_missing_form(creature, form)
    return if creature.forms.any? { |creature_form| creature_form.form == form }

    log_once(
      [:missing_form, creature.db_symbol, form],
      "Pokemon #{creature.db_symbol.inspect} has no form #{form}; PSDK resource lookup will use its default form"
    )
  end

  def normalize_preset_id(preset_id)
    return default_preset_id if preset_id.nil?

    raw_preset_id = preset_id.to_s.strip
    if raw_preset_id.empty? || !raw_preset_id.match?(/\A\d+\z/)
      log_once(
        [:invalid_preset_id_value, raw_preset_id],
        "invalid preset id #{preset_id.inspect}, fallback to #{default_preset_id}"
      )
      return default_preset_id
    end

    normalized_id = raw_preset_id.to_i
    if normalized_id <= 0
      log_once(
        [:invalid_preset_id_value, normalized_id],
        "invalid preset id #{normalized_id.inspect}, expected an integer >= 1, fallback to #{default_preset_id}"
      )
      return default_preset_id
    end

    return normalized_id if preset_exists?(normalized_id)

    log_invalid_preset(normalized_id)
    return default_preset_id
  end

  def preset_id(preset_data)
    return preset_data[:id] if preset_data.is_a?(Hash) && preset_data[:id]

    return default_preset_id
  end

  def log_invalid_preset(preset_id)
    log_once(
      [:invalid_preset, preset_id],
      "preset #{preset_id.inspect} was not found in #{config_filename}, fallback to #{default_preset_id}"
    )
  end

  def log_invalid_graphic_mode(mode, preset_data)
    log_once(
      [:invalid_graphic_mode_runtime, preset_id(preset_data), mode],
      "preset #{preset_id(preset_data)} has invalid graphic mode #{mode.inspect}, fallback to :pokeicon"
    )
  end

  def log(message)
    log_error("[EZ Statues] #{message}")
  end

  def log_once(key, message)
    @logged_errors ||= {}
    return if @logged_errors[key]

    log(message)
    @logged_errors[key] = true
  end
end

class Game_Event
  attr_reader :ez_statue_db_symbol
  attr_reader :ez_statue_form
  attr_reader :ez_statue_preset_id
  attr_reader :ez_statue_preset_overrides

  def ez_statue?
    return !!@ez_statue_enabled
  end

  def ez_statue_preset
    return EzStatues.preset(@ez_statue_preset_id, @ez_statue_preset_overrides)
  end

  def ez_statue_preset_key
    return [EzStatues.config_version, @ez_statue_form, @ez_statue_preset_id, EzStatues.override_cache_key(@ez_statue_preset_overrides)]
  end

  def reload_ez_statue_event
    return false unless EzStatues.statue_event_name?(@event&.name) || @ez_statue_enabled

    load_ez_statue_data
    if @ez_statue_enabled
      apply_ez_statue_appearance
    elsif @page
      refresh_page(@page)
    end
    return @ez_statue_enabled
  end

  module EzStatueEventPatch
    def initialize_parse_name
      super
      load_ez_statue_data
    end

    private

    def load_ez_statue_data
      statue_data = EzStatues.statue_data_from_event_name(@event&.name)
      @ez_statue_enabled = !!statue_data
      @ez_statue_db_symbol = statue_data&.[](:db_symbol)
      @ez_statue_form = statue_data&.[](:form) || EzStatues::DEFAULTS[:form]
      @ez_statue_preset_id = statue_data&.[](:preset_id) || EzStatues.default_preset_id
      @ez_statue_preset_overrides = statue_data&.[](:overrides) || {}
    end

    def refresh_page(new_page)
      result = super
      apply_ez_statue_appearance if result && @ez_statue_enabled
      return result
    end

    def apply_ez_statue_appearance
      @tile_id = 0
      set_appearance(EzStatues.encoded_character_name(@ez_statue_db_symbol, @ez_statue_form, @ez_statue_preset_id), 0)
      @shadow_disabled = true
    end
  end

  prepend EzStatueEventPatch
end

class Interpreter
  def reload_ez_statues_config
    EzStatues.reload_config
    EzStatues.refresh_current_map_events
    return true
  end
end

class Sprite_Character
  module EzStatueSpritePatch
    def update
      invalidate_ez_statue_config_if_needed
      super
    end

    def update_graphics
      clear_ez_statue_visual unless EzStatues.encoded_character_name?(@character.character_name)
      super
    end

    def update_sprite_graphic
      return update_ez_statue_graphic if EzStatues.encoded_character_name?(@character_name)

      clear_ez_statue_visual
      super
    end

    def update_tile_graphic
      clear_ez_statue_visual
      super
    end

    def update_pattern
      return update_ez_statue_pattern if @ez_statue_sprite

      super
    end

    def update_position
      result = super
      update_ez_statue_position if result && @ez_statue_sprite
      return result
    end

    def dispose
      dispose_ez_statue_companions
      super
    end

    private

    def invalidate_ez_statue_config_if_needed
      return unless EzStatues.encoded_character_name?(@character.character_name)

      config_version = EzStatues.config_version
      return if @ez_statue_config_version == config_version

      @ez_statue_config_version = config_version
      @character_name = nil
    end

    def update_ez_statue_graphic
      db_symbol = EzStatues.db_symbol_from_character_name(@character_name)
      form = current_ez_statue_form
      preset_key = current_ez_statue_preset_key
      preset_data = current_ez_statue_preset
      reset_ez_statue_preset_state(preset_key) if @ez_statue_current_preset_key != preset_key
      @ez_statue_config_version = EzStatues.config_version
      graphic_data = EzStatues.graphic_data(db_symbol, form, preset_data)
      @ez_statue_has_pokemon = !!graphic_data
      graphic_data ||= EzStatues.empty_graphic_data
      self.bitmap = graphic_data[:bitmap]
      @cw = graphic_data[:frame_width]
      @height = @ch = graphic_data[:frame_height]
      @ez_statue_src_x = graphic_data[:src_x]
      @ez_statue_src_y = graphic_data[:src_y]
      set_origin(@cw / 2, @ch)
      self.zoom = SPRITE_ZOOM
      src_rect.set(@ez_statue_src_x, @ez_statue_src_y, @cw, @ch)
      @pattern = @character.pattern
      @direction = @character.direction
      @ez_statue_sprite = true
      @ez_statue_shader ||= EzStatues.tint_shader(preset_data)
      self.shader = @ez_statue_shader
      update_ez_statue_shadow_graphic(preset_data)
    end

    def update_ez_statue_position
      preset_data = current_ez_statue_preset
      base_x = x
      base_y = y
      pokemon_x = base_x + EzStatues.pokemon_x(preset_data) * @tile_zoom
      pokemon_y = base_y + EzStatues.pokemon_y(preset_data) * @tile_zoom
      shadow_x = pokemon_x
      shadow_y = base_y + EzStatues.shadow_y(preset_data) * @tile_zoom
      self.x = pokemon_x
      self.y = pokemon_y
      @reflection&.x = @reflection.x + pokemon_x - base_x
      @reflection&.y = @reflection.y + pokemon_y - base_y
      update_ez_statue_base_position(preset_data, base_x, base_y)
      update_ez_statue_shadow_position(preset_data, shadow_x, shadow_y)
    end

    def update_ez_statue_base_position(preset_data, base_x, base_y)
      base = ensure_ez_statue_base(preset_data)
      return unless base

      base.set_position(base_x, base_y)
      base.z = z - 2
      base.opacity = @character.transparent ? 0 : @character.opacity
      base.visible = visible && (@ez_statue_has_pokemon || EzStatues.base_show_when_empty?(preset_data))
    end

    def update_ez_statue_shadow_graphic(preset_data)
      unless @ez_statue_has_pokemon
        hide_ez_statue_shadows
        return
      end

      shadow = ensure_ez_statue_shadow(preset_data)
      return unless shadow

      shadow_height = EzStatues.shadow_source_height(src_rect.height)
      return hide_ez_statue_shadows if shadow_height <= 0

      shadow_y = src_rect.y + src_rect.height - shadow_height
      update_ez_statue_shadow_segment(shadow, ez_statue_shadow_segment(preset_data), shadow_y, shadow_height)
    end

    def update_ez_statue_shadow_position(preset_data, base_x, shadow_y)
      unless @ez_statue_has_pokemon
        hide_ez_statue_shadows
        return
      end

      shadow = ensure_ez_statue_shadow(preset_data)
      update_ez_statue_shadow_sprite_position(shadow, base_x, shadow_y, preset_data) if shadow
    end

    def update_ez_statue_shadow_sprite_position(shadow, base_x, shadow_y, preset_data)
      return unless shadow && !shadow.disposed?

      shadow.set_position(base_x, shadow_y)
      shadow.z = z - 1
      shadow.opacity = ez_statue_shadow_opacity(preset_data)
      shadow.visible = visible && shadow.src_rect.width > 0 && shadow.src_rect.height > 0
    end

    def update_ez_statue_shadow_segment(shadow, segment, source_y, shadow_height)
      unless segment && segment[:width] > 0
        if shadow
          shadow.src_rect.set(0, 0, 0, 0)
          shadow.visible = false
        end
        return
      end

      shadow.bitmap = bitmap
      shadow.src_rect.set(src_rect.x + segment[:x], source_y, segment[:width], shadow_height)
      shadow.set_origin(ox - segment[:x], shadow_height)
      shadow.zoom = zoom_x
    end

    def ez_statue_shadow_segment(preset_data)
      full_width = src_rect.width
      return { x: 0, width: full_width } if full_width <= 0 || zoom_x <= 0

      base_bounds = ez_statue_base_display_bounds(preset_data)
      return { x: 0, width: full_width } unless base_bounds

      pokemon_x = EzStatues.pokemon_x(preset_data) * @tile_zoom
      left_limit = [[((base_bounds[:left] - pokemon_x + ox * zoom_x) / zoom_x).floor, 0].max, full_width].min
      right_limit = [[((base_bounds[:right] - pokemon_x + ox * zoom_x) / zoom_x).ceil, 0].max, full_width].min
      return { x: left_limit, width: right_limit - left_limit }
    end

    def ez_statue_base_display_bounds(preset_data)
      bitmap = @ez_statue_base && !@ez_statue_base.disposed? ? @ez_statue_base.bitmap : nil
      bitmap ||= EzStatues.base_bitmap(preset_data)
      return nil unless bitmap
      return full_ez_statue_base_display_bounds(bitmap, preset_data) unless bitmap.respond_to?(:get_pixel_alpha)

      base_scale = EzStatues.base_scale(preset_data)
      return nil if base_scale <= 0

      row = bitmap.height + (EzStatues.shadow_y(preset_data) * @tile_zoom / base_scale)
      alpha_bounds = ez_statue_base_alpha_bounds(bitmap, row.round)
      return full_ez_statue_base_display_bounds(bitmap, preset_data) unless alpha_bounds

      base_origin_x = bitmap.width / 2.0
      return {
        left: (alpha_bounds[:left] - base_origin_x) * base_scale,
        right: (alpha_bounds[:right] - base_origin_x) * base_scale
      }
    end

    def full_ez_statue_base_display_bounds(bitmap, preset_data)
      base_scale = EzStatues.base_scale(preset_data)
      base_origin_x = bitmap.width / 2.0
      return {
        left: -base_origin_x * base_scale,
        right: (bitmap.width - base_origin_x) * base_scale
      }
    end

    def ez_statue_base_alpha_bounds(bitmap, preferred_row)
      return nil if bitmap.width <= 0 || bitmap.height <= 0

      row = [[preferred_row, 0].max, bitmap.height - 1].min
      row.upto(bitmap.height - 1) do |scan_row|
        bounds = ez_statue_base_alpha_bounds_on_row(bitmap, scan_row)
        return bounds if bounds
      end
      row.downto(0) do |scan_row|
        bounds = ez_statue_base_alpha_bounds_on_row(bitmap, scan_row)
        return bounds if bounds
      end
      return nil
    end

    def ez_statue_base_alpha_bounds_on_row(bitmap, row)
      left = nil
      right = nil
      bitmap.width.times do |x|
        alpha = bitmap.get_pixel_alpha(x, row)
        next unless alpha && alpha > 0

        left ||= x
        right = x + 1
      end
      return nil unless left && right

      return { left: left, right: right }
    end

    def ensure_ez_statue_base(preset_data)
      return @ez_statue_base if @ez_statue_base && !@ez_statue_base.disposed?

      bitmap = EzStatues.base_bitmap(preset_data)
      return nil unless bitmap

      @ez_statue_base = Sprite.new(viewport)
      @ez_statue_base.bitmap = bitmap
      @ez_statue_base.src_rect.set(0, 0, bitmap.width, bitmap.height)
      @ez_statue_base.set_origin(bitmap.width / 2, bitmap.height)
      @ez_statue_base.zoom = EzStatues.base_scale(preset_data)
      return @ez_statue_base
    end

    def ensure_ez_statue_shadow(preset_data)
      return @ez_statue_shadow if @ez_statue_shadow && !@ez_statue_shadow.disposed?

      @ez_statue_shadow = Sprite.new(viewport)
      @ez_statue_shadow.shader = EzStatues.shadow_shader(preset_data)
      return @ez_statue_shadow
    end

    def ez_statue_shadow_opacity(preset_data)
      return 0 if @character.transparent

      return (@character.opacity * EzStatues.shadow_opacity(preset_data)).to_i
    end

    def update_ez_statue_pattern
      @pattern = @character.pattern
      @direction = @character.direction
      src_rect.set(@ez_statue_src_x, @ez_statue_src_y, @cw, @ch)
      @reflection&.src_rect&.set(@ez_statue_src_x, @ez_statue_src_y, @cw, @ch)
      update_ez_statue_shadow_graphic(current_ez_statue_preset)
    end

    def clear_ez_statue_visual
      return unless @ez_statue_sprite

      self.shader = nil if shader == @ez_statue_shader
      @ez_statue_sprite = false
      @ez_statue_shader = nil
      dispose_ez_statue_companions
    end

    def dispose_ez_statue_companions
      @ez_statue_base&.dispose
      @ez_statue_base = nil
      @ez_statue_shadow&.dispose
      @ez_statue_shadow = nil
    end

    def hide_ez_statue_shadows
      @ez_statue_shadow&.visible = false
    end

    def current_ez_statue_preset_key
      return @character.ez_statue_preset_key if @character.respond_to?(:ez_statue_preset_key)

      return [EzStatues.config_version, current_ez_statue_form, current_ez_statue_preset_id, nil]
    end

    def current_ez_statue_form
      if @character.respond_to?(:ez_statue_form)
        return EzStatues.normalize_form_id(@character.ez_statue_form)
      end

      return EzStatues.form_from_character_name(@character_name)
    end

    def current_ez_statue_preset_id
      if @character.respond_to?(:ez_statue_preset_id)
        return EzStatues.normalize_preset_id(@character.ez_statue_preset_id)
      end

      return EzStatues.preset_id_from_character_name(@character_name)
    end

    def current_ez_statue_preset
      return @character.ez_statue_preset if @character.respond_to?(:ez_statue_preset)

      return EzStatues.preset(current_ez_statue_preset_id)
    end

    def reset_ez_statue_preset_state(preset_key)
      dispose_ez_statue_companions
      @ez_statue_shader = nil
      @ez_statue_current_preset_key = preset_key
    end
  end

  prepend EzStatueSpritePatch
end
