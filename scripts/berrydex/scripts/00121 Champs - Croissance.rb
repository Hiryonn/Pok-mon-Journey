# Berrydex : champs de baies — pousse (chaque minute du jeu), flétrissement, mutations, propagation, mauvaises herbes,
# nuisibles, météo préférée, et affichage sur la carte (mauvaises herbes, plant qui tremble)
#
# PSDK range les plants dans PFM.game_state.berries[carte][évènement] =
#   [baie, stade (0 graine .. 4 mûre), minutes restantes, minutes par stade, humidité restante, durée de l'humidité,
#    nombre d'arrosages, engrais]
# Les données en plus sont dans PFM.game_state (@pj_champs_baies[carte][évènement]) :
#   clock (minutes dans le stade), x / y, soil, zone, mulch, weeds, pests, weed_clock, pest_clock, replants,
#   pref_weather, pref_zone, unpref_zone, pref_soil, mutation ([baie, nombre]), mutation_tried, wstages (stades
#   arrosés), withered_item
# Les pots à baies (clé :pots_baies) gardent la pousse de PSDK.
module ChampsBaies
  module Growth
    module_function

    # --- Données en plus -----------------------------------------------------------------------------------
    def store
      state = PFM.game_state
      return state.instance_variable_get(:@pj_champs_baies) || state.instance_variable_set(:@pj_champs_baies, {})
    end

    # @return [Hash]
    def extra(map_id, event_id)
      return (store[map_id] ||= {})[event_id] ||= {}
    end

    def berries_of(map_id)
      return (PFM.game_state.berries ||= {})[map_id] ||= {}
    end

    # @return [Game_Event, nil]
    def event(map_id, event_id)
      return nil unless $game_map && $game_map.map_id == map_id

      return $game_map.events[event_id]
    end

    # Nom RMXP de l'évènement (étiquettes berrysoil(...) et berryzone(...))
    def event_name(event)
      return event&.instance_variable_get(:@event)&.name.to_s
    end

    def tag(name, key)
      return name[/#{key}\(([^)]*)\)/i, 1]&.strip&.downcase
    end

    # L'évènement appelle l'évènement commun des baies
    def berry_event?(event)
      id = ChampsBaies.setting('common_event').to_i
      pages = event.instance_variable_get(:@event)&.pages || []
      return pages.any? { |page| Array(page.list).any? { |c| c.code == 117 && c.parameters[0] == id } }
    rescue StandardError
      return false
    end

    # Position, sol et zone d'un emplacement (carte affichée)
    def learn_spot(map_id, event_id)
      ev = event(map_id, event_id)
      return unless ev

      ex = extra(map_id, event_id)
      ex[:x] = ev.x
      ex[:y] = ev.y
      name = event_name(ev)
      ex[:soil] = tag(name, 'berrysoil') || ex[:soil]
      ex[:zone] = tag(name, 'berryzone') || ex[:zone]
    end

    # --- Plantation ----------------------------------------------------------------------------------------
    # Nouveau plant : préférences, compteurs à zéro (l'engrais posé avant reste)
    def on_plant(map_id, event_id)
      data = berries_of(map_id)[event_id]
      return unless data && data[0] != 0

      learn_spot(map_id, event_id)
      ex = extra(map_id, event_id)
      keep = ex.slice(:x, :y, :soil, :zone, :mulch)
      ex.clear
      ex.merge!(keep)
      ex[:clock] = 0
      ex[:replants] = 0
      ex[:wstages] = []
      berry = data_item(data[0]).db_symbol
      ex[:pref_zone] = ex[:zone] && ChampsBaies.preferred_list(berry, 'zones').include?(ex[:zone]) ? true : false
      ex[:unpref_zone] = ex[:zone] && !ex[:pref_zone] && ChampsBaies.preferred_list(berry, 'unpref_zones').include?(ex[:zone]) ? true : false
      soil = ChampsBaies.soil(ex[:soil])
      wanted = ChampsBaies.fetch(ChampsBaies.berrydex_entry(berry), 'soil').to_s.downcase
      ex[:pref_soil] = soil && !wanted.empty? && wanted == soil['id'] ? true : false
      data[7] = ex[:mulch] ? data_item(ex[:mulch]).id : 0
    end

    # Plante une baie sur un emplacement (même sur une autre carte : propagation)
    def plant_at(map_id, event_id, berry)
      item = data_item(berry)
      return false unless item.is_berry

      data = berries_of(map_id)[event_id] = Array.new(8, 0)
      data[0] = item.id
      data[3] = (item.berry_data.growth * 15).to_i
      data[2] = data[3]
      data[5] = (item.berry_data.drain_rate * 60).to_i
      on_plant(map_id, event_id)
      refresh_event(map_id, event_id)
      return true
    end

    # --- Traits ----------------------------------------------------------------------------------------------
    # @return [Array<Hash>] traits actifs du plant
    def traits(ex)
      list = []
      list << ChampsBaies.trait(:pref_weather) if ex[:pref_weather]
      list << ChampsBaies.trait(:pref_zone) if ex[:pref_zone]
      list << ChampsBaies.trait(:unpref_zone) if ex[:unpref_zone]
      soil = ChampsBaies.soil(ex[:soil])
      list << soil if soil
      list << ChampsBaies.trait(:pref_soil) if ex[:pref_soil]
      list << ChampsBaies.trait(:weeds) if ex[:weeds] && ChampsBaies.setting('weeds')
      list << ChampsBaies.trait(:pests) if ex[:pests] && ChampsBaies.setting('pests')
      return list
    end

    def sum(ex, key)
      return traits(ex).sum { |trait| ChampsBaies.trait_value(trait, key) }
    end

    def mulch_value(ex, key, default)
      value = ChampsBaies.fetch(ChampsBaies.mulch(ex[:mulch]), key)
      return value.nil? ? default : value.to_i
    end

    # Minutes par stade
    def stage_minutes(data, ex)
      minutes = data[3].to_i + 60 * sum(ex, 'hours_per_stage')
      minutes = minutes * mulch_value(ex, 'growth', 100) / 100
      return [minutes, 60].max
    end

    # Durée de l'humidité après un arrosage
    def water_minutes(data, ex)
      drying = [sum(ex, 'drying_per_hour'), -90].max
      minutes = data[5].to_i * 100 / (100 + drying)
      minutes = minutes * 100 / [mulch_value(ex, 'drying', 100), 1].max
      return [minutes, 30].max
    end

    def max_replants(ex)
      value = ChampsBaies.setting('max_replants').to_i + sum(ex, 'max_replants')
      value = (value * mulch_value(ex, 'replants', 100) / 100.0).ceil
      return [value, 1].max
    end

    def ripe_minutes(data, ex)
      stages = (ChampsBaies.setting('ripe_stages').to_i * mulch_value(ex, 'ripe', 100) / 100.0).ceil
      return stage_minutes(data, ex) * [stages, 1].max
    end

    # Baies récoltées (sans la mutation)
    def harvest_amount(data, ex)
      berry = data_item(data[0]).berry_data
      waters = [data[6].to_i, 4].min
      amount = berry.min_yield + (berry.max_yield - berry.min_yield) * waters / 4
      amount += sum(ex, 'yield') + mulch_value(ex, 'yield', 0)
      return [amount, 1].max
    end

    def watered?(data)
      return data[4].to_i > 0
    end

    # Arrose (un arrosage compte une fois par stade pour la récolte)
    def water(data, ex)
      data[4] = water_minutes(data, ex)
      ex[:wstages] ||= []
      return if ex[:wstages].include?(data[1])

      ex[:wstages] << data[1]
      data[6] += 1
    end

    def weed_chance(ex)
      value = mulch_value(ex, 'weeds', ChampsBaies.setting('weed_chance').to_i)
      soil = ChampsBaies.soil(ex[:soil])
      return value + (soil ? ChampsBaies.trait_value(soil, 'weed_chance') : 0)
    end

    def pest_chance(ex)
      value = mulch_value(ex, 'pests', ChampsBaies.setting('pest_chance').to_i)
      soil = ChampsBaies.soil(ex[:soil])
      value += ChampsBaies.trait_value(soil, 'pest_chance') if soil
      value += ChampsBaies.trait_value(ChampsBaies.trait(:weeds), 'pest_chance') if ex[:weeds]
      return value
    end

    # --- Pousse ----------------------------------------------------------------------------------------------
    def update_all
      PFM.game_state.berries&.each do |map_id, berries|
        if map_id.is_a?(Integer)
          berries.each { |event_id, data| tick(map_id, event_id, data) }
        else
          base_tick(berries)
        end
      end
    rescue StandardError => e
      log_error("Champs de baies : #{e.message}") if respond_to?(:log_error, true)
    end

    # Pousse de PSDK (pots à baies)
    def base_tick(berries)
      berries.each do |event_id, data|
        next if data[0] == 0

        data[2] -= 1 if data[2] >= 0
        data[4] -= 1 if data[2] >= 0 && data[4] > 0
        next unless data[1] < 4 && (data[2] % data[3]) == 0

        data[1] += 1
        data[2] = data[3]
        Yuki::Berries.update_event(event_id, data) if Yuki::Berries.data && data.__id__ == Yuki::Berries.data[event_id].__id__
      end
    end

    # Une minute de jeu pour un plant
    def tick(map_id, event_id, data)
      return if data[0] == 0

      ex = extra(map_id, event_id)
      ex[:clock] = ex[:clock].to_i + 1
      data[4] -= 1 if data[4] > 0
      current = $game_map && $game_map.map_id == map_id
      berry = data_item(data[0]).db_symbol
      changed = false
      if current
        water(data, ex) if ChampsBaies.setting('rain_waters') && !watered?(data) && rain?
        ex[:pref_weather] = true if !ex[:pref_weather] && data[1].between?(1, 3) && ChampsBaies.preferred_weather_now?(berry)
      end
      changed |= roll_weeds(ex, data)
      changed |= roll_pests(ex, data)
      if data[1] < 4
        limit = stage_minutes(data, ex)
        data[2] = limit - ex[:clock]
        if ex[:clock] >= limit
          data[1] += 1
          ex[:clock] = 0
          changed = true
        end
      elsif ex[:clock] >= ripe_minutes(data, ex)
        wither(map_id, event_id, data, ex)
        changed = true
      end
      try_mutation(map_id, event_id, data, ex) if data[0] != 0 && data[1] >= 1 && !ex[:mutation_tried]
      refresh_event(map_id, event_id) if changed && current
    end

    def rain?
      return $env.rain? || $env.hardrain?
    rescue StandardError
      return false
    end

    # @return [Boolean] des mauvaises herbes viennent de pousser
    def roll_weeds(ex, data)
      return false if !ChampsBaies.setting('weeds') || ex[:weeds] || data[1] < 1

      ex[:weed_clock] = ex[:weed_clock].to_i + 1
      return false if ex[:weed_clock] < [ChampsBaies.setting('weed_hours').to_i, 1].max * 60

      ex[:weed_clock] = 0
      ex[:weeds] = rand(100) < weed_chance(ex)
      return ex[:weeds]
    end

    def roll_pests(ex, data)
      return false if !ChampsBaies.setting('pests') || ex[:pests] || data[1] < 2

      ex[:pest_clock] = ex[:pest_clock].to_i + 1
      return false if ex[:pest_clock] < [ChampsBaies.setting('pest_hours').to_i, 1].max * 60

      ex[:pest_clock] = 0
      ex[:pests] = rand(100) < pest_chance(ex)
      return ex[:pests]
    end

    # Le plant flétrit : il se replante ou disparaît
    def wither(map_id, event_id, data, ex)
      berry = data_item(data[0]).db_symbol
      ex[:replants] = ex[:replants].to_i + 1
      propagate(map_id, event_id, data, ex) if ChampsBaies.setting('propagation')
      if ex[:replants] >= max_replants(ex)
        data[0] = 0
        keep = ex.slice(:x, :y, :soil, :zone)
        ex.clear
        ex.merge!(keep)
        ex[:withered_item] = ChampsBaies.withered_item(berry)
      else
        replant(data, ex, 0)
      end
    end

    # Repart d'un stade (flétrissement : graine ; plant durable : stade réglé)
    def replant(data, ex, stage)
      data[1] = stage
      data[4] = 0
      data[6] = 0
      ex[:clock] = 0
      ex[:wstages] = []
      ex[:pref_weather] = false
      ex[:pests] = false
      ex[:pest_clock] = 0
      return unless ChampsBaies.setting('replant_resets_mutation')

      ex[:mutation] = nil
      ex[:mutation_tried] = false
    end

    # Emplacements voisins (haut, bas, gauche, droite) connus sur la carte
    # @return [Array<Integer>] id des évènements
    def neighbors(map_id, ex)
      return [] unless ex[:x]

      return (store[map_id] || {}).select do |_id, other|
        other[:x] && (other[:x] - ex[:x]).abs + (other[:y] - ex[:y]).abs == 1
      end.keys
    end

    # Une baie qui tombe peut prendre racine dans un emplacement vide voisin
    def propagate(map_id, event_id, data, ex)
      amount = harvest_amount(data, ex)
      berries = Array.new(amount) { data[0] }
      if ex[:mutation]
        count = [ex[:mutation][1].to_i, amount - 1].min
        count.times { berries << data_item(ex[:mutation][0]).id }
      end
      neighbors(map_id, ex).each do |other_id|
        other = berries_of(map_id)[other_id]
        next if other && other[0] != 0

        other_ex = extra(map_id, other_id)
        chance = mulch_value(other_ex, 'propagation', ChampsBaies.setting('propagation_chance').to_i)
        next if chance <= 0 || rand(1000) >= chance

        plant_at(map_id, other_id, berries.sample)
      end
    end

    # Au premier stade, deux plants voisins peuvent préparer une mutation
    def try_mutation(map_id, event_id, data, ex)
      ex[:mutation_tried] = true
      return unless ChampsBaies.setting('mutations')

      berry = data_item(data[0]).db_symbol
      return unless ChampsBaies.mutation_parent?(berry)

      chance = mulch_value(ex, 'mutation', ChampsBaies.setting('mutation_chance').to_i) + sum(ex, 'mutation_chance')
      return if chance <= 0 || rand(100) >= chance

      possible = neighbors(map_id, ex).flat_map do |other_id|
        other = berries_of(map_id)[other_id]
        other && other[0] != 0 ? ChampsBaies.mutations_of(berry, data_item(other[0]).db_symbol) : []
      end
      ex[:mutation] = [possible.sample, [ChampsBaies.setting('mutation_count').to_i, 1].max] unless possible.empty?
    end

    # --- Carte ---------------------------------------------------------------------------------------------------
    # Emplacements de la carte affichée : position, sol, zone ; plants : apparence
    def refresh_map
      return unless $game_map

      map_id = $game_map.map_id
      $game_map.events.each do |event_id, ev|
        known = store[map_id]&.key?(event_id) || berries_of(map_id).key?(event_id)
        next unless known || berry_event?(ev)

        learn_spot(map_id, event_id)
        refresh_event(map_id, event_id)
      end
    rescue StandardError => e
      log_error("Champs de baies : #{e.message}") if respond_to?(:log_error, true)
    end

    # Plant qui tremble quand des nuisibles s'y cachent
    def refresh_event(map_id, event_id)
      ev = event(map_id, event_id)
      return unless ev

      data = berries_of(map_id)[event_id]
      Yuki::Berries.update_event(event_id, data) if data && Yuki::Berries.data && Yuki::Berries.data[event_id].equal?(data)
      ex = store.dig(map_id, event_id) || {}
      pests = data && data[0] != 0 && ex[:pests] ? true : false
      ev.instance_variable_set(:@pj_base_speed, ev.move_speed) unless ev.instance_variable_defined?(:@pj_base_speed)
      ev.instance_variable_set(:@step_anime, pests)
      ev.move_speed = pests ? 6 : ev.instance_variable_get(:@pj_base_speed)
    rescue StandardError => e
      log_error("Champs de baies : #{e.message}") if respond_to?(:log_error, true)
    end

    # @return [Boolean] des mauvaises herbes poussent sur ce plant (carte affichée)
    def weeds_here?(event_id)
      return false unless $game_map && ChampsBaies.setting('weeds')

      data = berries_of($game_map.map_id)[event_id]
      return data && data[0] != 0 && store.dig($game_map.map_id, event_id, :weeds) ? true : false
    end
  end
end

module Yuki
  module Berries
    class << self
      module ChampsBaiesHooks
        def update
          return super unless ::ChampsBaies.enabled?

          ::ChampsBaies::Growth.update_all
        end

        def plant(event_id, berry_id)
          super
          ::ChampsBaies::Growth.on_plant($game_map.map_id, event_id) if ::ChampsBaies.enabled?
        end

        def init
          super
          ::ChampsBaies::Growth.refresh_map if ::ChampsBaies.enabled?
        end
      end
      prepend ChampsBaiesHooks
    end
  end
end

# Mauvaises herbes dessinées par-dessus le plant
class Sprite_Character
  module ChampsBaiesWeeds
    def update
      super
      champs_weeds_update
    end

    def dispose
      @pj_weeds&.dispose unless @pj_weeds&.disposed?
      @pj_weeds = nil
      super
    end

    private

    def champs_weeds_update
      on = @character.is_a?(Game_Event) && ChampsBaies::Growth.weeds_here?(@character.id)
      unless on
        @pj_weeds.visible = false if @pj_weeds
        return
      end
      unless @pj_weeds
        @pj_weeds = Sprite.new(viewport)
        @pj_weeds.bitmap = RPG::Cache.character(ChampsBaies::WEEDS_CHARSET)
        @pj_weeds.ox = @pj_weeds.bitmap.width / 2
        @pj_weeds.oy = @pj_weeds.bitmap.height
      end
      @pj_weeds.visible = visible
      @pj_weeds.set_position(x, y)
      @pj_weeds.zoom_x = zoom_x
      @pj_weeds.zoom_y = zoom_y
      @pj_weeds.z = z + 1
      @pj_weeds.opacity = opacity
    rescue StandardError
      @pj_weeds = nil
    end
  end
  prepend ChampsBaiesWeeds
end
