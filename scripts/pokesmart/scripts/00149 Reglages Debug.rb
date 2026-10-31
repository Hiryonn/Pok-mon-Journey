# PokeSmart : réglages de l'écran Debug édités depuis Pokémon Studio (onglet « Debug » de l'éditeur Smartphone)
#
# Fichier : Data/configs/plugins/pokesmart_debug.json (sans lui, l'écran Debug garde ses réglages de base)
#   text_file_id  : fichier de textes (Data/Text/Dialogs/9102.csv par défaut) : noms, aides, noms des commandes
#   pokemon_level : niveau proposé pour les Pokémon donnés
#   item_count    : quantité proposée pour les objets donnés
#   badges        : nombre de badges de la région 1
#   categories    : [{ id, builtin, visible, icon, name_row, help_row }] dans l'ordre de l'écran
#                   (builtin : team, pokemon, items, player, map, switches, variables, phone ;
#                    les autres catégories ne contiennent que leurs commandes)
#   commands      : [{ id, category, label_row, kind, ... }] commandes ajoutées, en haut de leur catégorie :
#     script       : script Ruby lancé comme une commande d'évent (A) ; value_script : valeur affichée
#     switch       : interrupteur (switch) à allumer / éteindre
#     variable     : variable (variable) à régler / écrire
#     common_event : évent commun (common_event) lancé sur la carte (le menu se ferme)
#     pokemon      : Pokémon (pokemon : symbole, level : niveau, 0 = niveau réglé dans l'écran) à recevoir
#     item         : objet (item : symbole, count : quantité, 0 = quantité réglée) à recevoir
#     warp         : téléportation (map, x, y)
module Configs
  # Contenu de Data/configs/plugins/pokesmart_debug.json
  class PokeSmartDebugConfig
    attr_accessor :text_file_id, :pokemon_level, :item_count, :badges, :categories, :commands

    def initialize
      @text_file_id = 9102
      @pokemon_level = 50
      @item_count = 10
      @badges = 8
      @categories = []
      @commands = []
    end
  end
  register(:pokesmart_debug, 'plugins/pokesmart_debug', :json, false, PokeSmartDebugConfig)
end

module UI
  module PokeSmart
    # Réglages de l'écran Debug
    module DebugConfig
      CONFIG_FILE = 'Data/configs/plugins/pokesmart_debug.json'
      # Catégories de base : [id, nom, aide, icône du smartphone]
      BUILTIN = [
        [:team, 'Équipe', 'A : valider   Droite : niveau +1', 'icon_party'],
        [:pokemon, 'Pokémon', 'A : recevoir / écrire   X : chromatique', 'icon_pokedex'],
        [:items, 'Objets', 'A : recevoir / écrire', 'icon_bag'],
        [:player, 'Joueur', 'A : valider / écrire   Gauche / droite : régler', 'icon_trainercard'],
        [:map, 'Carte', 'A : écrire / se téléporter   Gauche / droite : régler', 'icon_map'],
        [:switches, 'Interrupteurs', 'A : allumer / éteindre', 'icon_option'],
        [:variables, 'Variables', 'Gauche / droite : -1 / +1   A : écrire   X : 0', 'icon_pc'],
        [:phone, 'Téléphone', 'A : valider   Gauche / droite : régler', 'icon_debug']
      ]

      module_function

      # @return [Configs::PokeSmartDebugConfig]
      def config
        @config ||= begin
          if PSDK_CONFIG.release? || File.exist?(CONFIG_FILE)
            Configs.pokesmart_debug
          else
            Configs::PokeSmartDebugConfig.new
          end
        rescue StandardError, ScriptError => e
          log_error("PokeSmart : réglages Debug illisibles (#{e.message})") if respond_to?(:log_error, true)
          Configs::PokeSmartDebugConfig.new
        end
      end

      # @param row [Integer, nil]
      # @return [String, nil] texte du fichier de textes (nil si vide ou absent)
      def text(row)
        return nil unless row.is_a?(Integer)

        value = ext_text(config.text_file_id || 9102, row)
        return value.is_a?(String) && !value.empty? ? value : nil
      rescue StandardError
        return nil
      end

      # Catégories affichées, dans l'ordre : { key:, builtin:, name:, help:, icon: }
      # @return [Array<Hash>]
      def categories
        defaults = BUILTIN.to_h { |key, name, help, icon| [key, { key: key, builtin: true, name: name, help: help, icon: icon }] }
        list = (config.categories || []).map { |data| data.transform_keys(&:to_sym) }
        result = list.filter_map do |data|
          key = data[:id].to_s.to_sym
          base = defaults.delete(key) || { key: key, builtin: false, name: key.to_s, help: 'A : valider', icon: 'icon_debug' }
          next nil if data[:visible] == false

          base.merge(name: text(data[:name_row]) || base[:name], help: text(data[:help_row]) || base[:help],
                     icon: data[:icon].to_s.empty? ? base[:icon] : data[:icon].to_s)
        end
        # catégories de base absentes du fichier (ou pas de fichier) : ajoutées à la fin
        return result.concat(defaults.values)
      end

      # @param category [Symbol]
      # @return [Array<Hash>] commandes ajoutées dans Studio pour cette catégorie
      def commands(category)
        return (config.commands || []).map { |data| data.transform_keys(&:to_sym) }
                                      .select { |data| data[:category].to_s == category.to_s }
      end

      # @return [Integer]
      def pokemon_level
        return (config.pokemon_level || DEBUG_POKEMON_LEVEL).to_i.clamp(1, 1000)
      end

      # @return [Integer]
      def item_count
        return (config.item_count || DEBUG_ITEM_COUNT).to_i.clamp(1, 999)
      end

      # @return [Integer]
      def badges
        return (config.badges || DEBUG_BADGES).to_i.clamp(0, 64)
      end
    end
  end
end

module GamePlay
  class PokeSmartDebug
    # @return [Boolean] si une commande demande de fermer le menu (évent commun)
    attr_reader :close_menu

    private

    # Lignes des commandes ajoutées dans Studio (en haut de la catégorie)
    # @param category [Symbol]
    # @return [Array<Hash>]
    def entries_custom(category)
      return UI::PokeSmart::DebugConfig.commands(category).map { |command| custom_entry(command) }.compact
    end

    # @param command [Hash]
    # @return [Hash, nil]
    def custom_entry(command)
      label = UI::PokeSmart::DebugConfig.text(command[:label_row]) || command[:id].to_s
      case command[:kind].to_s
      when 'switch'
        id = command[:switch].to_i
        return nil if id <= 0

        toggle = proc do
          $game_switches[id] = !$game_switches[id]
          $game_map.need_refresh = true
          nil
        end
        return { label: label, value: $game_switches[id] ? 'ON' : 'off', a: toggle, left: toggle, right: toggle }
      when 'variable'
        id = command[:variable].to_i
        return nil if id <= 0

        return number_entry(label, $game_variables[id].to_i, -9_999_999..9_999_999) do |value|
          $game_variables[id] = value
          $game_map.need_refresh = true
        end
      when 'common_event'
        id = command[:common_event].to_i
        return { label: label, value: "Évent commun #{id}", a: proc do
          $game_temp.common_event_id = id
          @close_menu = true
          @running = false
          nil
        end }
      when 'pokemon'
        db_symbol = command[:pokemon].to_s.to_sym
        level = command[:level].to_i
        return { label: label, value: level > 0 ? "N.#{level}" : "N.#{@give_level}", a: proc do
          debug_give_pokemon(db_symbol, false, level > 0 ? level : @give_level)
        end, x: proc { debug_give_pokemon(db_symbol, true, level > 0 ? level : @give_level) } }
      when 'item'
        db_symbol = command[:item].to_s.to_sym
        count = command[:count].to_i
        return { label: label, value: "x#{count > 0 ? count : @give_count}", a: proc do
          amount = count > 0 ? count : @give_count
          PFM.game_state.bag.add_item(db_symbol, amount)
          next "#{data_item(db_symbol).name} x#{amount}"
        end }
      when 'warp'
        map_id = command[:map].to_i
        x = command[:x].to_i
        y = command[:y].to_i
        return { label: label, value: "#{map_id} : #{x}, #{y}", a: proc { debug_warp_to(map_id, x, y) } }
      else
        return { label: label, value: custom_value(command), a: proc { run_custom_script(command[:script].to_s) } }
      end
    end

    # @param command [Hash]
    # @return [String] valeur d'une commande « script » (value_script)
    def custom_value(command)
      script = command[:value_script].to_s
      return 'A' if script.strip.empty?

      return debug_interpreter.instance_eval(script).to_s
    rescue StandardError, ScriptError
      return '?'
    end

    # Lance un script Ruby comme une commande « Script » d'évent (méthodes de l'Interpreter disponibles)
    # @param script [String]
    # @return [String] résultat affiché en bas
    def run_custom_script(script)
      return 'Script vide' if script.strip.empty?

      result = debug_interpreter.instance_eval(script)
      @phone_changed = true
      return result.is_a?(String) ? result : 'Commande lancée'
    rescue ScriptError => e
      return "Erreur : #{e.message}"[0, 60]
    end

    # @return [Interpreter]
    def debug_interpreter
      @debug_interpreter ||= Interpreter.new
    end
  end
end
