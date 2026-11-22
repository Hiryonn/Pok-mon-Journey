# encoding: utf-8
# Combats spéciaux : combats triples (3 contre 3) et hordes (1 ou 2 Pokémon du joueur contre jusqu'à 5 sauvages en même temps).
#
# Le moteur de combat de PSDK règle le nombre de Pokémon en jeu avec vs_type (une seule valeur pour les deux camps) :
# les positions vont de 0 à vs_type - 1 et « adjacent » veut dire « à une position d'écart ». Ce plugin lance donc un combat
# avec vs_type = 3. Il ne touche à aucun autre combat : tout est lié au drapeau pj_special posé sur le BattleInfo.
#
# Réglages : Data/configs/plugins/combats_speciaux.json
#   settings   triple_fallback (true : avec moins de 3 Pokémon en état, le combat se fait à 2 ou 1 au lieu d'être refusé),
#              horde_size (5), horde_active (Pokémon sauvages en jeu, 1 à 5), horde_player (Pokémon du joueur, 1 ou 2), horde_spread (écart de niveau au hasard), horde_bgm, triple_bgm, background
# Commandes d'évènement :
#   combat_triple(dresseur, variable: 0)                  3 contre 3 contre un dresseur de Studio (id ou db_symbol)
#   combat_trio_sauvage([[:especes, niveau], ...], variable: 0)   3 Pokémon sauvages à la fois
#   combat_horde(:espece, niveau, taille: nil, forme: 0, variable: 0)   horde de Pokémon sauvages de la même espèce
#   combat_special_gagne?                                 le dernier combat spécial est gagné
#   combat_special_possible?(nombre = 3)                  assez de Pokémon en état de se battre
# La variable reçoit 1 (gagné) ou 0 (perdu, fuite, autre).
module Configs
  class CombatsSpeciauxConfig
    attr_accessor :settings

    def initialize
      @settings = {}
    end
  end
  register(:combats_speciaux, 'plugins/combats_speciaux', :json, false, CombatsSpeciauxConfig)
end

module CombatsSpeciaux
  CONFIG_FILE = 'Data/configs/plugins/combats_speciaux.json'
  DEFAULTS = {
    'triple_fallback' => true, 'horde_size' => 5, 'horde_active' => 5, 'horde_player' => 2, 'horde_spread' => 0,
    'horde_bgm' => '', 'triple_bgm' => '', 'background' => ''
  }.freeze

  module_function

  def config
    @config ||= begin
      if PSDK_CONFIG.release?
        Configs.combats_speciaux
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        cfg = Configs::CombatsSpeciauxConfig.new
        data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
        cfg
      else
        Configs::CombatsSpeciauxConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Combats spéciaux : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::CombatsSpeciauxConfig.new
    end
  end

  def reload
    @config = nil
  end

  def setting(key)
    settings = config.settings
    value = settings.is_a?(Hash) ? (settings[key.to_s].nil? ? settings[key.to_sym] : settings[key.to_s]) : nil
    return value.nil? ? DEFAULTS[key.to_s] : value
  end

  def fr?
    return $options.nil? || $options.language.to_s == 'fr'
  end

  def t(fr, en = fr)
    return fr? ? fr : en
  end
end
