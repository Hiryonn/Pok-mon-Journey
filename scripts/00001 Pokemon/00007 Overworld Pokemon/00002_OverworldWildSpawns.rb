# Script décompilé depuis le bytecode du jeu (Ruby 3.0) — fichier d'origine : RMXP/00007_OverworldWildSpawns.rb
# Les commentaires et la mise en forme d'origine ne sont pas récupérables.

module Raty
  module OverworldWildSpawns
    EVENT_TAG = /\[ow_wild=(ground|water)\]/i

    RESPAWN_DELAY = 5 * 60
    EVENT_REFRESH_INTERVAL = 30
    GROUND_SYSTEM_TAGS = [:grass, :cave, :tall_grass, :sand, :snow]
    WATER_SYSTEM_TAGS = [:sea, :pond]
    DESPAWN_BATTLE_RESULTS = [0, 3]
    module_function

    def environment_for(event)
      name = event.respond_to?(:event) ? event.event.name : event.respond_to?(:name) ? event.name : event.to_s

      match = EVENT_TAG.match(name.to_s)
      match && match[1].downcase.to_sym
    end

    def key_for(event)
      map_id = event.original_map || $game_map.map_id
      event_id = event.original_id || event.event.id
      [map_id.to_i, event_id.to_i]
    end

    def pokemon_for(event)
      return unless event
      record = spawn_records[key_for(event)]
      record && record[:pokemon]
    end

    def active?(event)
      !pokemon_for(event).nil?
    end

    def spawn_page?(event)
      page = event.instance_variable_get(:@page)
      return false unless page

      page.list.any? do |command|
        command.code == 355 && command.parameters.first.to_s.include?("call_overworld_wild_battle")
      end
    end

    def refresh_event(event)
      environment = environment_for(event)
      return false unless environment

      unless spawn_page?(event)
        hide_event(event)
        return false
      end

      key = key_for(event)
      record = spawn_records[key]
      if record && record[:environment].to_sym != environment
        spawn_records.delete(key)
        record = nil
      end

      if record && record[:pokemon]
        show_event(event, record[:pokemon])
        true
      else
        if record && record[:respawn_at].to_i > current_time
          hide_event(event)
          return false
        end
        pokemon = generate_pokemon(environment, event)
        unless pokemon
          hide_event(event)
          return false
        end
        spawn_records[key] = { environment: environment, pokemon: pokemon, respawn_at: nil }
        show_event(event, pokemon)
        log_info("[OverworldWildSpawns] Map #{key[0]} event #{key[1]}: #{pokemon.db_symbol}, level #{pokemon.level}, shiny=#{pokemon.shiny?}")
        true
      end
    end

    def resolve_battle(key, battle_result)
      caught = $game_switches[Yuki::Sw::BT_Catch]
      return unless caught || DESPAWN_BATTLE_RESULTS.include?(battle_result)
      record = spawn_records[key]
      return unless record
      record[:pokemon] = nil
      record[:respawn_at] = current_time + RESPAWN_DELAY
      current_event = $game_map&.events&.values&.find { |event| key_for(event) == key }
      return hide_event(current_event) if current_event
    end

    def hide_event(event)
      return unless event
      event.set_appearance("")
      event.opacity = 0
      event.through = true
      event.shadow_disabled = false
    end

    def show_event(event, pokemon)
      page = event.instance_variable_get(:@page)
      character_name = character_name_for(event, pokemon)
      event.set_appearance(character_name)
      event.opacity = page ? page.graphic.opacity : 255
      event.through = page ? page.through : false
      event.shadow_disabled = environment_for(event) == :water
      log_event_appearance(event, pokemon, character_name)
    end

    def log_event_appearance(event, pokemon, character_name)
      return if event.instance_variable_get(:@overworld_wild_visual_logged)
      key = key_for(event)

      unless RPG::Cache.character_exist?(character_name)
        log_error("[OverworldWildSpawns] Missing OW graphic graphics/characters/#{character_name}.png for map #{key[0]} at (#{event.x}, #{event.y}), species=#{pokemon.db_symbol}")
      end

      event.instance_variable_set(:@overworld_wild_visual_logged, true)
    end

    def character_name_for(event, pokemon)
      character_name = pokemon.character_name.to_s
      return character_name unless environment_for(event) == :water

      "#{character_name.sub(/_0\z/, "")}_surf"
    end

    def generate_pokemon(environment, event)
      encounter = weighted_encounter(environment, event)
      return unless encounter
      pokemon = encounter.to_creature
      apply_project_shiny_roll(pokemon, encounter)
      pokemon
    end

    def weighted_encounter(environment, event)
      tags = environment == :water ? WATER_SYSTEM_TAGS : GROUND_SYSTEM_TAGS
      terrain_tag = event.terrain_tag
      system_tag = event.system_tag_db_symbol
      groups = Array($wild_battle&.groups).select do |group|
        group.tool.nil? && tags.include?(system_tag) && group.system_tag == system_tag && group.terrain_tag == terrain_tag
      end

      if groups.empty?
        log_missing_encounter_group(event, environment, system_tag, terrain_tag)
        nil
      else
        entries = groups.flat_map do |group|
          group.encounters.filter_map do |encounter|
            weight = encounter.encounter_rate.to_f
            next [encounter, weight] if weight.positive?
          end
        end
        return if entries.empty?
        total = entries.sum { |entry| entry[1] }
        roll = Random::WILD_BATTLE.rand * total
        entries.each do |encounter, weight|
          roll -= weight
          return encounter if roll < 0
        end
        entries.last[0]
      end
    end

    def log_missing_encounter_group(event, environment, system_tag, terrain_tag)
      return if event.instance_variable_get(:@overworld_wild_missing_group_logged)
      key = key_for(event)
      log_error("[OverworldWildSpawns] Missing Studio encounter group for OW map #{key[0]} at (#{event.x}, #{event.y}), environment=#{environment}, system_tag=#{system_tag}, terrain_tag=#{terrain_tag}")
      event.instance_variable_set(:@overworld_wild_missing_group_logged, true)
    end

    def apply_project_shiny_roll(pokemon, encounter)
      shiny_kind = encounter.shiny_setup.instance_variable_get(:@kind)
      return unless shiny_kind == :automatic

      pokemon.shiny = Random::WILD_BATTLE.rand(shiny_denominator(pokemon.db_symbol)).zero?
    end

    def shiny_denominator(db_symbol)
      case $pokedex.creature_caught_count(db_symbol)
      when (0..9) then return 4096
      when (10..19) then return 2048
      when (20..29) then return 1024
      when (30..49) then 512
      else
        return 256
      end
    end

    def spawn_records
      PFM.game_state.overworld_wild_spawns
    end

    def current_time
      Time.now.to_i
    end
  end
end

module PFM
  class GameState
    def overworld_wild_spawns
      @overworld_wild_spawns ||= {}
    end

    on_player_initialize(:overworld_wild_spawns) { @overworld_wild_spawns = {} }

    on_expand_global_variables(:overworld_wild_spawns) { @overworld_wild_spawns ||= {} }
  end
end

class Game_Event
  module OverworldWildSpawnPatch
    def initialize(map_id, event)
      super
      @overworld_wild_environment = Raty::OverworldWildSpawns.environment_for(self)
      return unless @overworld_wild_environment
      @surfing = true if @overworld_wild_environment == :water
      @overworld_wild_next_refresh = 0
      @overworld_wild_active = false
      Raty::OverworldWildSpawns.hide_event(self)
    end

    def update
      if @overworld_wild_environment
        unless Raty::OverworldWildSpawns.spawn_page?(self)
          Raty::OverworldWildSpawns.hide_event(self)
          @overworld_wild_active = false
          @overworld_wild_next_refresh = 0
          return super
        end
        if Graphics.frame_count >= @overworld_wild_next_refresh
          @overworld_wild_active = Raty::OverworldWildSpawns.refresh_event(self)
          @overworld_wild_next_refresh = Graphics.frame_count + Raty::OverworldWildSpawns::EVENT_REFRESH_INTERVAL
        else
          @overworld_wild_active = Raty::OverworldWildSpawns.active?(self)
        end
        return unless @overworld_wild_active
      else
        super
      end
    end

    def start
      if @overworld_wild_environment && Raty::OverworldWildSpawns.spawn_page?(self) && !Raty::OverworldWildSpawns.active?(self)
        return
      end

      super
    end
  end

  prepend(OverworldWildSpawnPatch)
end

class Interpreter
  def play_overworld_wild_cry
    event = $game_map.events[@event_id]
    pokemon = Raty::OverworldWildSpawns.pokemon_for(event)
    return cry_pokemon(pokemon.db_symbol) if pokemon
  end

  def call_overworld_wild_battle
    event = $game_map.events[@event_id]
    pokemon = Raty::OverworldWildSpawns.pokemon_for(event)
    return unless pokemon
    key = Raty::OverworldWildSpawns.key_for(event)
    previous_battle_proc = $game_temp.battle_proc
    $game_temp.battle_proc = proc do |battle_result|
      begin
        previous_battle_proc&.call(battle_result)
      ensure
        Raty::OverworldWildSpawns.resolve_battle(key, battle_result)
      end
    end

    $wild_battle.start_battle(pokemon)
    @wait_count = 2
  end
end
