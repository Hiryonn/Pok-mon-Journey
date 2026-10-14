# Wild Alterations
#
# Author : Raty
# License : MIT
#
# A PSDK plugin that can inflict status conditions
# and modify the HP of wild creatures.
#
# Documentation :
# https://github.com/RatyHub/Ambient-Cries

module Configs
  module Project
    class AmbientCries
      FILENAME = File.join('plugins', 'ambient_cries_config')

      attr_accessor :roll_chance_percent
      attr_accessor :roll_interval_seconds
      attr_accessor :volume
      attr_accessor :ground_system_tags
      attr_accessor :water_system_tags

      def initialize
        @roll_chance_percent = 50
        @roll_interval_seconds = [20, 40]
        @volume = [60, 80]
        @ground_system_tags = %w[grass cave tall_grass snow sand]
        @water_system_tags = %w[sea pond]
      end

      def to_h
        return {
          roll_chance_percent: @roll_chance_percent,
          roll_interval_seconds: @roll_interval_seconds,
          volume: @volume,
          ground_system_tags: @ground_system_tags,
          water_system_tags: @water_system_tags
        }
      end
    end
  end

  register(:ambient_cries, Project::AmbientCries::FILENAME, :json, true, Project::AmbientCries)
end

module AmbientCries
  module_function

  def enable
    unless @disabled
      log_error('[AmbientCries] Ambient cries are already enabled.')
      return true
    end

    @disabled = false
    @next_roll_frame = nil
    log_error('[AmbientCries] Ambient cries enabled. The next roll has been rescheduled.')
    return true
  end

  def disable
    if @disabled
      log_error('[AmbientCries] Ambient cries are already disabled.')
      return true
    end

    @disabled = true
    log_error('[AmbientCries] Ambient cries disabled.')
    return true
  end

  def reload_config
    unless PSDK_CONFIG.release?
      Configs.register(:ambient_cries, Configs::Project::AmbientCries::FILENAME, :json, true, Configs::Project::AmbientCries)
    end
    @config = load_config
    @next_roll_frame = nil
    log_error('[AmbientCries] Configuration reloaded. The next roll has been rescheduled.')
    return true
  end

  def update
    return unless enabled?

    schedule_next_roll unless @next_roll_frame
    return unless Graphics.frame_count >= @next_roll_frame

    schedule_next_roll
    return unless can_play_now?

    return unless roll_success?

    play_random_current_group_cry
  rescue StandardError => e
    log_error("[AmbientCries] #{e.class}: #{e.message}")
  end

  def enabled?
    return false if @disabled
    return false unless defined?(::Scene_Map) && $scene.is_a?(::Scene_Map)
    return false unless defined?($wild_battle) && $wild_battle
    return false unless defined?($game_player) && $game_player

    return true
  end

  def can_play_now?
    return cant_play_reason.nil?
  end

  def cant_play_reason
    return 'encounters disabled' if $game_system&.encounter_disabled
    return 'map interpreter running' if $game_system&.map_interpreter&.running?
    return 'message window showing' if $game_temp&.message_window_showing
    return 'battle calling' if $game_temp&.battle_calling
    return 'player transferring' if $game_temp&.player_transferring
    return 'event task processing disabled' if PFM.game_state.respond_to?(:cant_process_event_tasks?) && PFM.game_state.cant_process_event_tasks?

    return nil
  end

  def schedule_next_roll
    @next_roll_frame = Graphics.frame_count + interval_frames
  end

  def interval_frames
    frame_rate = Graphics.respond_to?(:frame_rate) ? Graphics.frame_rate : 60
    return [(random_in_range(config[:roll_interval_seconds]) * frame_rate).round, 1].max
  end

  def roll_success?
    return rand * 100 < config[:roll_chance_percent]
  end

  def play_random_current_group_cry
    groups = current_wild_groups
    return if groups.empty?

    entries = groups.flat_map { |group| weighted_cry_entries(group) }
    return if entries.empty?

    selected = weighted_sample(entries)
    Audio.cry_play(selected[:filename], random_volume)
  end

  def current_wild_groups
    allowed_tags = $game_player.surfing? ? config[:water_system_tags] : config[:ground_system_tags]

    return $wild_battle.groups.select do |group|
      group.tool.nil? && allowed_tags.include?(group.system_tag)
    end
  end

  def weighted_cry_entries(group)
    return [] unless group

    group.encounters.each_with_object([]) do |encounter, entries|
      weight = encounter.encounter_rate.to_f
      next unless weight.positive?

      filename = cry_filename_for(encounter)
      next unless filename

      entries << { filename: filename, weight: weight, specie: encounter.specie, form: encounter.form, group: group.db_symbol }
    end
  end

  def cry_filename_for(encounter)
    form = encounter.form == -1 ? 0 : encounter.form
    creature_data = data_creature(encounter.specie)
    creature_form = creature_data.forms.find { |data| data.form == form }
    creature_form ||= creature_data.forms.find { |data| data.form == 0 }
    cry = creature_form&.resources&.cry
    return if cry.nil? || cry.empty?

    filename = "audio/se/cries/#{cry}"
    return filename if File.exist?(filename)

    return nil
  end

  def weighted_sample(entries)
    total_weight = entries.reduce(0.0) { |sum, entry| sum + entry[:weight] }
    roll = rand * total_weight

    entries.each do |entry|
      roll -= entry[:weight]
      return entry if roll < 0
    end

    return entries.last
  end

  def random_volume
    return random_in_range(config[:volume]).round
  end

  def random_in_range(range)
    min = range.begin.to_f
    max = range.end.to_f
    return min if max <= min

    return min + rand * (max - min)
  end

  def config
    @config ||= load_config
  end

  def load_config
    return build_config(read_config_file)
  rescue StandardError => e
    log_error("[AmbientCries] Failed to load config file #{config_filename}: #{e.class}: #{e.message}")
    return default_config
  end

  def read_config_file
    data = Configs.ambient_cries.to_h
    return data if data.is_a?(Hash)

    log_error("[AmbientCries] Compiled config #{config_filename} should contain an object; using defaults")
    return {}
  end

  def build_config(data)
    defaults = default_config
    return {
      roll_chance_percent: parse_percent(data[:roll_chance_percent], defaults[:roll_chance_percent], :roll_chance_percent),
      roll_interval_seconds: parse_range(data[:roll_interval_seconds], defaults[:roll_interval_seconds], :roll_interval_seconds),
      volume: parse_range(data[:volume], defaults[:volume], :volume),
      ground_system_tags: parse_tags(data[:ground_system_tags], defaults[:ground_system_tags], :ground_system_tags),
      water_system_tags: parse_tags(data[:water_system_tags], defaults[:water_system_tags], :water_system_tags)
    }
  end

  def default_config
    return {
      roll_chance_percent: 50.0,
      roll_interval_seconds: 20.0..40.0,
      volume: 60.0..80.0,
      ground_system_tags: %i[grass cave tall_grass snow sand],
      water_system_tags: %i[sea pond]
    }
  end

  def config_filename
    return File.join('Data', 'configs', 'plugins', 'ambient_cries_config.json')
  end

  def parse_percent(value, fallback, key)
    return fallback if value.nil?

    return Float(value).clamp(0, 100)
  rescue ArgumentError, TypeError
    log_error("[AmbientCries] Invalid #{key}: #{value.inspect}; using default")
    return fallback
  end

  def parse_range(value, fallback, key)
    return fallback if value.nil?

    unless value.is_a?(Array) && value.size >= 2
      log_error("[AmbientCries] Invalid #{key}: #{value.inspect}; expected [min, max], using default")
      return fallback
    end

    min = Float(value[0])
    max = Float(value[1])
    if max < min
      log_error("[AmbientCries] Invalid #{key}: max is lower than min; using default")
      return fallback
    end

    return min..max
  rescue ArgumentError, TypeError
    log_error("[AmbientCries] Invalid #{key}: #{value.inspect}; expected numeric values, using default")
    return fallback
  end

  def parse_tags(value, fallback, key)
    return fallback if value.nil?

    unless value.is_a?(Array)
      log_error("[AmbientCries] Invalid #{key}: #{value.inspect}; expected an array, using default")
      return fallback
    end

    tags = value.map { |tag| tag.to_s.strip }.reject(&:empty?).map(&:to_sym)
    return tags unless tags.empty?

    log_error("[AmbientCries] Invalid #{key}: no valid system tag, using default")
    return fallback
  end
end

Scheduler.add_proc(:on_update, ::Scene_Map, 'Ambient cries', 0) do
  AmbientCries.update
end
