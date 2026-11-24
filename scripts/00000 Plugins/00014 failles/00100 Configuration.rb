# encoding: utf-8
# Failles spatio-temporelles (Légendes Pokémon : Arceus) pour le type Cosmique
#
# Au fil des pas, une faille s'ouvre près du joueur sur une carte (annoncée par la bannière du téléphone si le plugin
# PokeSmart est là). La toucher ouvre une zone temporaire sur la même carte (teinte de l'écran) pendant duration_steps pas :
#   - pokemon_count Pokémon rares se promènent : ceux du type Cosmique (réglage type) trouvés dans les données de Studio,
#     plus les espèces du réglage species (utile tant que le type n'a pas de Pokémon). Niveau du joueur + level_bonus,
#     chromatiques 1 / shiny_rate, Barons / Dominants (plugin Overworld Pokémon) baron_rate %.
#   - item_count objets rares à ramasser (tirés dans la table loot selon leur poids).
# Quand le temps est écoulé (avertissement warn_steps pas avant) ou que le joueur quitte la carte, la zone se referme.
# Réglages : Data/configs/plugins/failles.json
#   settings  enabled, appear_steps (pas entre deux failles, ±25 %), appear_chance (%), faille_lifetime (pas avant qu'elle se
#             referme si on ne la touche pas), duration_steps, warn_steps, pokemon_count, item_count, level_bonus,
#             shiny_rate, baron_rate, type, charset_faille / charset_item (graphics/characters), tone ([rouge, vert, bleu, gris])
#   species   espèces ajoutées au tirage      loot   [{ item:, count: [min, max], weight: }]
# Commandes d'évènement : faille_ouvrir (en fait apparaître une près du joueur), faille_active?, faille_fermer
module Configs
  class FaillesConfig
    attr_accessor :settings, :species, :loot

    def initialize
      @settings = {}
      @species = []
      @loot = []
    end
  end
  register(:failles, 'plugins/failles', :json, false, FaillesConfig)
end

module Failles
  CONFIG_FILE = 'Data/configs/plugins/failles.json'
  DEFAULTS = {
    'enabled' => true, 'appear_steps' => 900, 'appear_chance' => 60, 'faille_lifetime' => 500, 'duration_steps' => 300,
    'warn_steps' => 60, 'pokemon_count' => 6, 'item_count' => 6, 'level_bonus' => 3, 'shiny_rate' => 100, 'baron_rate' => 40,
    'type' => 'cosmic', 'charset_faille' => 'fx-portal', 'charset_item' => 'fx-pokeball', 'tone' => [-40, -50, 60, 20]
  }.freeze

  module_function

  def config
    @config ||= begin
      if PSDK_CONFIG.release?
        Configs.failles
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        cfg = Configs::FaillesConfig.new
        data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
        cfg
      else
        Configs::FaillesConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Failles : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::FaillesConfig.new
    end
  end

  def reload
    @config = nil
  end

  def fetch(hash, key)
    return nil unless hash.is_a?(Hash)

    value = hash[key.to_s]
    return value.nil? ? hash[key.to_sym] : value
  end

  def setting(key)
    value = fetch(config.settings, key)
    return value.nil? ? DEFAULTS[key.to_s] : value
  end

  def fr?
    return $options.nil? || $options.language.to_s == 'fr'
  end

  def t(fr, en = fr)
    return fr? ? fr : en
  end

  # Bannière du téléphone (plugin PokeSmart) si disponible
  def banner(text)
    UI::PokeSmart::Notify.push(text, title: t('Faille', 'Rift')) if defined?(UI::PokeSmart::Notify)
  rescue StandardError
    nil
  end
end
