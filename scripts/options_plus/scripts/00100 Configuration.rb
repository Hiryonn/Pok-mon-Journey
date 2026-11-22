# Options en plus du menu Options : Multi Exp. (désactivable) et Sauvegarde automatique.
# La Course permanente est l'option « auto_run » de PSDK : elle est ajoutée à Data/configs/game_options_config.json.
#
# Les options du joueur sont enregistrées dans $options (sauvegarde) :
#   pj_multi_exp   Multi Exp. : tous les Pokémon vivants de l'équipe gagnent de l'expérience même sans combattre
#   pj_autosave    Sauvegarde automatique : la partie est sauvegardée à chaque changement de carte
# Réglages : Data/configs/plugins/options_plus.json (settings)
#   multi_exp_default / autosave_default   valeur pour une nouvelle partie
#   multi_exp_percent                      % de l'expérience d'un combattant donné à chaque Pokémon qui n'a pas combattu
#   autosave_min_seconds                   délai minimum entre deux sauvegardes automatiques
#   autosave_se                            son joué après la sauvegarde (vide : aucun)
# Pour afficher les options : ajouter « pj_multi_exp » et « pj_autosave » (et « auto_run ») à la liste « order » de
# Data/configs/game_options_config.json (Studio : Réglages du jeu > Options).
module Configs
  class OptionsPlusConfig
    attr_accessor :settings

    def initialize
      @settings = {}
    end
  end
  register(:options_plus, 'plugins/options_plus', :json, false, OptionsPlusConfig)
end

module OptionsPlus
  CONFIG_FILE = 'Data/configs/plugins/options_plus.json'
  DEFAULTS = {
    'multi_exp_default' => true, 'multi_exp_percent' => 50,
    'autosave_default' => false, 'autosave_min_seconds' => 30, 'autosave_se' => ''
  }.freeze
  TEXTS = {
    on: ['Activé', 'On'], off: ['Désactivé', 'Off'],
    multi_exp_name: ['Multi Exp.', 'Exp. Share'],
    multi_exp_desc: ['Tous les Pokémon de l\'équipe gagnent de l\'expérience, même sans combattre.',
                     'The whole team earns experience, even without fighting.'],
    autosave_name: ['Sauvegarde auto.', 'Autosave'],
    autosave_desc: ['Sauvegarde la partie à chaque changement de carte.', 'Saves the game on every map change.']
  }.freeze

  module_function

  def settings
    @settings ||= begin
      if PSDK_CONFIG.release?
        Configs.options_plus.settings || {}
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        data.is_a?(Hash) && data['settings'].is_a?(Hash) ? data['settings'] : {}
      else
        {}
      end
    rescue StandardError, ScriptError => e
      log_error("réglages illisibles (#{e.message})")
      {}
    end
  end

  def setting(key)
    value = settings[key.to_s]
    return value.nil? ? DEFAULTS[key.to_s] : value
  end

  def log_error(message)
    Kernel.send(:log_error, "Options en plus : #{message}") if Kernel.respond_to?(:log_error, true)
  rescue StandardError
    nil
  end

  # @param key [Symbol]
  # @return [String] texte dans la langue du jeu
  def text(key)
    pair = TEXTS[key.to_sym] || [key.to_s, key.to_s]
    return $options && $options.language.to_s != 'fr' ? pair[1] : pair[0]
  end
end

# Les textes des options sont demandés par une méthode globale, comme text_get dans les options de PSDK
class Object
  def pj_option_text(key)
    return OptionsPlus.text(key)
  end
end

module Kernel
  def self.pj_option_text(key)
    return OptionsPlus.text(key)
  end
end
