# encoding: utf-8
# Pique-nique (Écarlate / Violet) : sandwichs et œufs du panier
#
# - On installe un pique-nique (commande pique_nique) : pendant picnic_steps pas, le panier peut recevoir des œufs.
#   À chaque egg_steps pas, si deux Pokémon de l'équipe (œufs exclus) sont compatibles, un œuf apparaît dans le panier
#   avec egg_chance % de chances (plus un bonus par niveau du pouvoir « œuf » du sandwich). Le panier contient basket_max
#   œufs au plus ; on les récupère dans le menu du pique-nique (ils vont dans l'équipe, ou au PC si elle est pleine).
#   Compatibles : de sexes différents et d'un groupe d'œuf commun, ou avec un Métamorph (groupe 13), jamais du groupe 15
#   (« inconnu »). L'espèce de l'œuf est le bébé de la mère (ou du Pokémon qui n'est pas Métamorph).
# - Un sandwich se prépare avec des objets du sac (recettes dans le réglage recipes) et dure steps pas ; un seul à la fois.
#   Ses pouvoirs : egg (niveau), spawn (type + pourcentage : plus de Pokémon visibles de ce type), happy (bonheur donné à
#   l'équipe en le mangeant).
# Réglages : Data/configs/plugins/pique_nique.json
#   settings   picnic_steps, egg_steps, egg_chance, egg_bonus, basket_max, egg_group_none, egg_group_ditto, ditto_species
#   recipes    [{ id:, name: { fr:, en: }, ingredients: [{ item:, count: }], steps:, egg: niveau, spawn: { type:, percent: }, happy: }]
# Commandes d'évènement : pique_nique (menu), pique_nique_installer, pique_nique_actif?, pique_nique_oeufs (œufs du panier),
#   panier_recuperer (renvoie le nombre d'œufs récupérés), sandwich_cuisiner(:id), sandwich_actif (nom ou nil),
#   sandwich_possible?(:id), pique_nique_compatibles?
module Configs
  class PiqueNiqueConfig
    attr_accessor :settings, :recipes

    def initialize
      @settings = {}
      @recipes = []
    end
  end
  register(:pique_nique, 'plugins/pique_nique', :json, false, PiqueNiqueConfig)
end

module PiqueNique
  CONFIG_FILE = 'Data/configs/plugins/pique_nique.json'
  DEFAULTS = {
    'picnic_steps' => 1500, 'egg_steps' => 150, 'egg_chance' => 35, 'egg_bonus' => 20, 'basket_max' => 10,
    'egg_group_none' => 15, 'egg_group_ditto' => 13, 'ditto_species' => 'ditto'
  }.freeze

  module_function

  def config
    @config ||= begin
      if PSDK_CONFIG.release?
        Configs.pique_nique
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        cfg = Configs::PiqueNiqueConfig.new
        data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
        cfg
      else
        Configs::PiqueNiqueConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Pique-nique : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::PiqueNiqueConfig.new
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

  def localized(value)
    return value.to_s unless value.is_a?(Hash)

    return (fr? ? (value['fr'] || value[:fr]) : (value['en'] || value[:en])) || value['fr'] || value['en'] || value.values.first.to_s
  end

  # @return [Array<Hash>] recettes
  def recipes
    return Array(config.recipes).select { |r| r.is_a?(Hash) }
  end

  # @return [Hash, nil]
  def recipe(id)
    return recipes.find { |r| fetch(r, 'id').to_s == id.to_s }
  end

  def recipe_name(recipe)
    return localized(fetch(recipe, 'name') || fetch(recipe, 'id'))
  end

  # @return [Hash] état du pique-nique (sauvegardé avec la partie)
  def state
    data = ($user_data ||= {})[:pj_picnic] ||= {}
    data['steps'] ||= 0
    data['egg_clock'] ||= 0
    data['basket'] ||= []
    data['meal'] ||= nil
    return data
  end
end
