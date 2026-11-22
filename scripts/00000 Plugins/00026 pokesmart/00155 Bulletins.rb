# encoding: utf-8
# PokeSmart : bulletins de troupeaux
#
# Chaque jour, le radar annonce une espèce en masse dans une zone déjà visitée (une bannière du téléphone la première fois
# que le jour change, et une ligne « Troupeau » sur l'écran du radar). Dans cette zone, un troupeau de herd_count Pokémon
# de l'espèce se rassemble à l'arrivée sur la carte (plugin Pokémon visibles). Capturer ou vaincre un de ses Pokémon dans la
# zone fait avancer la tâche « troupeau » (herd) du Pokédex avancé de l'espèce (plugin Advanced Pokédex).
# Réglages (Data/configs/plugins/pokesmart_reactions.json, settings) :
#   herd_enabled (true)   herd_count (10 Pokémon)   herd_notify (bannière du téléphone)   herd_spawn (rassembler le troupeau)
# Commandes d'évènement : troupeau_du_jour (message), troupeau_espece, troupeau_zone
require 'zlib'

module UI
  module PokeSmart
    module Herds
      DEFAULTS = { 'herd_enabled' => true, 'herd_count' => 10, 'herd_notify' => true, 'herd_spawn' => true }.freeze

      module_function

      def setting(key)
        value = Reactions.settings[key.to_s]
        return value.nil? ? DEFAULTS[key.to_s] : value
      rescue StandardError
        return DEFAULTS[key.to_s]
      end

      def fr?
        return $options.nil? || $options.language.to_s == 'fr'
      end

      def state
        game = PFM.game_state
        data = game.instance_variable_get(:@pj_herds) || game.instance_variable_set(:@pj_herds, {})
        data['zones'] ||= {}
        return data
      end

      def today_key
        return Time.now.strftime('%Y%m%d')
      end

      # @param zone [Object, nil]
      # @return [String, nil]
      def zone_key(zone = $env&.current_zone_data)
        return nil unless zone

        key = zone.respond_to?(:db_symbol) ? zone.db_symbol : (zone.respond_to?(:id) ? zone.id : nil)
        return key.to_s
      rescue StandardError
        return nil
      end

      # Zone visitée et ses espèces terrestres (celles que le radar y montre)
      def register_zone
        key = zone_key
        return unless key

        groups = UI::PokeSmart.wild_groups.reject { |group| UI::PokeSmart.water_group?(group) }
        species = groups.flat_map { |group| group.encounters.to_a.map { |enc| [enc.specie.to_s, enc.form.to_i] } }.uniq
        return if species.empty?

        state['zones'][key] = { 'name' => $env.current_zone_name.to_s, 'species' => species }
      rescue StandardError
        nil
      end

      # Bulletin du jour (tiré une fois par jour parmi les zones visitées)
      # @return [Hash, nil] { 'zone', 'name', 'species', 'form' }
      def today
        return nil unless setting('herd_enabled') && PFM.game_state

        data = state
        return data['today'] if data['day'] == today_key && data['today']

        data['day'] = today_key
        data['today'] = nil
        zones = data['zones'].keys.sort
        return nil if zones.empty?

        seed = Zlib.crc32("#{today_key}-#{$trainer&.id_public}-#{zones.size}")
        random = Random.new(seed)
        zone = zones[random.rand(zones.size)]
        species, form = data['zones'][zone]['species'][random.rand(data['zones'][zone]['species'].size)]
        data['today'] = { 'zone' => zone, 'name' => data['zones'][zone]['name'], 'species' => species, 'form' => form }
        return data['today']
      end

      # @param map [Game_Map]
      # @return [Hash, nil] le bulletin si la carte est dans la zone du troupeau
      def herd_for(map)
        return nil unless setting('herd_spawn')

        herd = today
        return nil unless herd

        zone = defined?(OverworldPokemon) ? OverworldPokemon.zone_of(map.map_id) : $env&.current_zone_data
        return zone_key(zone) == herd['zone'] ? herd : nil
      rescue StandardError
        return nil
      end

      # Le Pokémon est du troupeau du jour, dans sa zone ?
      def match?(species)
        herd = today
        return false unless herd && herd['species'] == species.to_s

        return zone_key == herd['zone']
      rescue StandardError
        return false
      end

      def species_name(herd)
        return data_creature(herd['species'].to_sym).name.to_s
      rescue StandardError
        return herd['species'].to_s
      end

      # @return [String] « Roucool (Route 1) »
      def label(herd = today)
        return '' unless herd

        return "#{species_name(herd)} (#{herd['name']})"
      end

      # Bannière du téléphone, une fois par jour
      def announce
        herd = today
        return unless herd && setting('herd_notify') && defined?(UI::PokeSmart::Notify)

        data = state
        return if data['announced'] == today_key

        data['announced'] = today_key
        UI::PokeSmart::Notify.push(format(fr? ? 'Troupeau de %s repéré vers %s !' : 'A herd of %s was spotted around %s!', species_name(herd), herd['name']),
                                   title: fr? ? 'Radar' : 'Radar')
      end

      # Tâche « troupeau » du Pokédex avancé : capturer ou vaincre un Pokémon du troupeau dans sa zone
      module TaskHook
        def record(species, type, target = nil, amount = 1)
          super
          sym = species.is_a?(Integer) ? data_creature(species).db_symbol : species.to_sym
          super(sym, :herd, nil, 1) if %i[capture defeat].include?(type.to_sym) && UI::PokeSmart::Herds.match?(sym)
        rescue StandardError
          nil
        end
      end

      def install
        return if @installed || !defined?(AdvancedPokedex::Tasks)

        AdvancedPokedex::Tasks.singleton_class.prepend(TaskHook)
        @installed = true
      end
    end

    # Ligne « Troupeau » sur l'écran du radar
    class Radar
      module HerdLine
        def create_daynight
          super
          herd = Herds.today
          return unless herd

          with_font(20) do
            add_text(4, 140, 150, 14, "#{PokeSmart.french? ? 'Troupeau' : 'Herd'} : #{Herds.label(herd)}", 0, color: @color)
          end
        rescue StandardError
          nil
        end
      end
      prepend HerdLine
    end

    Herds.install
  end
end

class Game_Map
  module PokeSmartHerds
    def setup(map_id)
      result = super
      UI::PokeSmart::Herds.install
      UI::PokeSmart::Herds.register_zone
      UI::PokeSmart::Herds.announce
      return result
    rescue StandardError => e
      log_error("PokeSmart : bulletins #{e.message}") if respond_to?(:log_error, true)
      return result
    end
  end
  prepend PokeSmartHerds
end

class Interpreter
  # Message : le troupeau du jour
  def troupeau_du_jour
    herd = UI::PokeSmart::Herds.today
    text = herd ? format(UI::PokeSmart::Herds.fr? ? 'Troupeau du jour : %s.' : 'Today’s herd: %s.', UI::PokeSmart::Herds.label(herd)) :
                  (UI::PokeSmart::Herds.fr? ? 'Aucun troupeau signalé aujourd’hui.' : 'No herd reported today.')
    display_message_and_wait(text)
  end

  # @return [Symbol, nil] espèce du troupeau du jour
  def troupeau_espece
    herd = UI::PokeSmart::Herds.today
    return herd ? herd['species'].to_sym : nil
  end

  # @return [String] nom de la zone du troupeau du jour
  def troupeau_zone
    herd = UI::PokeSmart::Herds.today
    return herd ? herd['name'].to_s : ''
  end
end
