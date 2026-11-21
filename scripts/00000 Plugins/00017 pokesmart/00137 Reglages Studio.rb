# PokeSmart : réglages édités depuis Pokémon Studio (onglet Smartphone de la version personnalisée)
#
# Fichier : Data/configs/plugins/pokesmart_config.json (copié en .rxdata pour la version finale du jeu)
#   text_file_id      : fichier de textes des noms d'applis (Data/Text/Dialogs/9100.csv par défaut)
#   app_texts         : {action => ligne du CSV} (0 = première ligne après l'en-tête)
#   app_order         : ordre des applis sur l'écran d'accueil (les applis absentes de la liste viennent après)
#   hidden_apps       : applis à ne pas afficher
#   locked_apps       : applis absentes au début du jeu, débloquées par la commande smartphone_unlock(:open_x)
#   default_case      : coque par défaut (avant tout choix du joueur)
#   default_wallpaper : fond par défaut : « auto », « none » ou le nom d'une image de wallpapers/
#   default_icons     : {action => variante} icônes par défaut (« 01 »…, « » = classique)
#   variant_texts     : {image => ligne du CSV} nom des variantes d'icônes (« icon_bag », « icon_bag_01 »…)
#   cases             : coques ajoutées ou modifiées (même format que THEMES)
# Sans ce fichier, le plugin garde son comportement habituel.
module Configs
  # Contenu de Data/configs/plugins/pokesmart_config.json
  class PokeSmartConfig
    attr_accessor :text_file_id, :app_texts, :app_order, :hidden_apps, :default_case, :default_wallpaper,
                  :default_icons, :cases, :variant_texts, :locked_apps

    def initialize
      @text_file_id = 9100
      @app_texts = {}
      @app_order = []
      @hidden_apps = []
      @locked_apps = []
      @default_case = nil
      @default_wallpaper = nil
      @default_icons = {}
      @cases = {}
      @variant_texts = {}
    end
  end
  register(:pokesmart, 'plugins/pokesmart_config', :json, false, PokeSmartConfig)
end

module UI
  module PokeSmart
    # Fichier de réglages écrit par Studio
    CONFIG_FILE = 'Data/configs/plugins/pokesmart_config.json'

    module_function

    # Réglages Studio (valeurs par défaut si le fichier n'existe pas)
    # @return [Configs::PokeSmartConfig]
    def config
      @config ||= begin
        if PSDK_CONFIG.release? || File.exist?(CONFIG_FILE)
          Configs.pokesmart
        else
          Configs::PokeSmartConfig.new
        end
      rescue StandardError, ScriptError => e
        log_error("PokeSmart : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
        Configs::PokeSmartConfig.new
      end
    end

    # Coques : THEMES + celles du fichier de réglages
    # @return [Hash{Symbol => Hash}]
    def themes
      @themes ||= begin
        list = THEMES.dup
        (config.cases || {}).each do |id, data|
          data = data.transform_keys(&:to_sym)
          base = list[id.to_sym] || THEMES[DEFAULT_THEME]
          case_data = base.merge(data)
          case_data[:home] = case_data[:home].map { |a, b| a.is_a?(Range) ? a : (a..b) } if case_data[:home].is_a?(Array) && case_data[:home].first.is_a?(Array)
          list[id.to_sym] = case_data
        end
        list
      rescue StandardError
        THEMES
      end
    end

    # Coque par défaut (réglages Studio, sinon DEFAULT_THEME)
    # @return [Symbol]
    def default_theme_id
      id = config.default_case.to_s.to_sym
      return themes.key?(id) ? id : DEFAULT_THEME
    end

    # Fond d'écran par défaut des réglages Studio (nil = selon la coque)
    # @return [Symbol, String, nil]
    def default_wallpaper
      value = config.default_wallpaper.to_s
      return nil if value.empty?
      return value.to_sym if %w[auto none].include?(value)

      return wallpapers.include?(value) ? value : nil
    end

    # Variante d'icône par défaut des réglages Studio
    # @param action [Symbol]
    # @return [String, nil]
    def default_icon_variant(action)
      icons = config.default_icons || {}
      value = icons[action] || icons[action.to_s]
      return value&.to_s
    end

    # Nom d'une appli dans le fichier de textes (nil si absent)
    # @param action [Symbol]
    # @return [String, nil]
    def studio_app_name(action)
      texts = config.app_texts || {}
      row = texts[action] || texts[action.to_s]
      return nil unless row.is_a?(Integer)

      text = ext_text(config.text_file_id || 9100, row)
      return text.is_a?(String) && !text.empty? ? text : nil
    rescue StandardError
      return nil
    end

    # Nom d'une variante d'icône dans le fichier de textes (nil si absent)
    # @param base [String] icône de base (ex. « icon_bag »)
    # @param variant [String] '' ou '01'…
    # @return [String, nil]
    def studio_variant_name(base, variant)
      texts = config.variant_texts || {}
      key = variant.to_s.empty? ? base : "#{base}_#{variant}"
      row = texts[key.to_sym] || texts[key]
      return nil unless row.is_a?(Integer)

      text = ext_text(config.text_file_id || 9100, row)
      return text.is_a?(String) && !text.empty? ? text : nil
    rescue StandardError
      return nil
    end

    # Ordre des applis des réglages Studio
    # @return [Array<Symbol>]
    def studio_app_order
      return (config.app_order || []).map { |action| action.to_s.to_sym }
    end

    # Applis cachées des réglages Studio
    # @return [Array<Symbol>]
    def studio_hidden_apps
      return (config.hidden_apps || []).map { |action| action.to_s.to_sym }
    end

    # Applis à débloquer par une commande (réglages Studio)
    # @return [Array<Symbol>]
    def studio_locked_apps
      return (config.respond_to?(:locked_apps) && config.locked_apps || []).map { |action| action.to_s.to_sym }
    end

    # Applis débloquées pendant la partie (sauvegarde)
    # @return [Array<Symbol>]
    def unlocked_apps
      return $user_data[:pokesmart_unlocked] ||= []
    end

    # Autres noms acceptés par les commandes (smartphone_unlock(:pokedex) = smartphone_unlock(:open_dex))
    APP_ALIASES = {
      pokedex: :open_dex, dex: :open_dex, open_pokedex: :open_dex, equipe: :open_party, team: :open_party,
      party: :open_party, sac: :open_bag, bag: :open_bag, carte: :open_map, map: :open_map, pc: :open_pc,
      quetes: :open_quest, quests: :open_quest, carte_dresseur: :open_tcard, tcard: :open_tcard,
      badges: :open_badges, amie: :open_amie, poke_recre: :open_amie, sauvegarde: :open_save, save: :open_save,
      options: :open_option
    }.freeze

    # @param action [Symbol, String] :open_dex, :pokedex, 'open_dex'…
    # @return [Symbol] action du menu (:open_dex)
    def app_action(action)
      key = action.to_s.strip.downcase.delete_prefix(':').to_sym
      return APP_ALIASES[key] if APP_ALIASES.key?(key)

      return key.to_s.start_with?('open_') ? key : :"open_#{key}"
    end

    # @param action [Symbol]
    # @return [Boolean] si l'appli est disponible (débloquée dès le début ou par la commande)
    def app_unlocked?(action)
      action = app_action(action)
      return !studio_locked_apps.include?(action) || unlocked_apps.include?(action)
    end

    # Débloque une appli
    # Pokédex : le menu de PSDK ne le montre que si le Pokédex est activé ($pokedex.enable, interrupteur 100), la
    # commande l'active donc aussi
    # @param action [Symbol]
    def unlock_app(action)
      action = app_action(action)
      unlocked_apps << action unless unlocked_apps.include?(action)
      PFM.game_state.pokedex.enable if action == :open_dex && PFM.game_state&.pokedex
    end

    # Rebloque une appli (seulement si Studio la met en « par une commande »)
    # @param action [Symbol]
    def lock_app(action)
      unlocked_apps.delete(app_action(action))
    end
  end
end

# Commandes d'évent (script) pour débloquer les applis réglées « par une commande » dans Studio
class Interpreter
  # Débloque une ou plusieurs applis du téléphone, ex. smartphone_unlock(:open_map, :open_pc)
  # smartphone_unlock(:open_dex) (ou :pokedex) active aussi le Pokédex
  # @param actions [Array<Symbol>]
  def smartphone_unlock(*actions)
    actions.each { |action| UI::PokeSmart.unlock_app(action) }
  end

  # Rebloque une ou plusieurs applis, ex. smartphone_lock(:open_map)
  # @param actions [Array<Symbol>]
  def smartphone_lock(*actions)
    actions.each { |action| UI::PokeSmart.lock_app(action) }
  end

  # @param action [Symbol]
  # @return [Boolean] si l'appli est disponible dans le téléphone (pour une condition)
  def smartphone_unlocked?(action)
    UI::PokeSmart.app_unlocked?(action)
  end
end
