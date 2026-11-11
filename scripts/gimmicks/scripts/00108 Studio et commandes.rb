# Gimmicks : réglages faits dans Studio (Plugins > Gimmicks) et commandes d'évènement
#
# Data/configs/plugins/gimmicks.json :
#   enabled      { mega, zmove, dynamax, tera } mécaniques actives au début de la partie
#   cinematic, ai, ai_chance, dynamax_turns, dynamax_level, tera_orb_recharge
#   species      { espèce => { tera: type Téra par défaut, gmax: facteur Gigamax d'office, no_dynamax: true } }
#   trainers     { dresseur => { keys: [mécaniques utilisables], team: [{ tera:, gmax:, dynamax_level: }, …] } }
module Configs
  # Contenu de Data/configs/plugins/gimmicks.json
  class GimmicksConfig
    attr_accessor :enabled, :cinematic, :ai, :ai_chance, :dynamax_turns, :dynamax_level, :tera_orb_recharge, :species,
                  :trainers

    def initialize
      @enabled = {}
      @species = {}
      @trainers = {}
    end
  end
  register(:gimmicks, 'plugins/gimmicks', :json, false, GimmicksConfig)
end

module Gimmicks
  CONFIG_FILE = 'Data/configs/plugins/gimmicks.json'
  # Objet clé donné au dresseur pour chaque mécanique cochée dans Studio
  TRAINER_KEY_ITEMS = { mega: :mega_ring, zmove: :z_ring, dynamax: :dynamax_band, tera: :tera_orb }.freeze

  module_function

  # @return [Hash] réglages de Studio (vide si le fichier n'existe pas)
  def config
    return @config if @config

    @config = File.exist?(CONFIG_FILE) ? JSON.parse(File.read(CONFIG_FILE, encoding: 'UTF-8').delete_prefix("﻿")) : {}
  rescue StandardError => e
    log_error("Gimmicks : #{CONFIG_FILE} illisible (#{e.message})") if respond_to?(:log_error, true)
    @config = {}
  end

  # @param key [String]
  # @param default [Object]
  def setting(key, default)
    value = config[key]
    return value.nil? ? default : value
  end

  # @return [Boolean]
  def cinematic?
    return setting(:cinematic, CINEMATIC)
  end

  # @return [Boolean]
  def ai_enabled?
    return setting(:ai, AI_ENABLED)
  end

  # @return [Float]
  def ai_chance
    return setting(:ai_chance, AI_CHANCE).to_f
  end

  # @param species [Symbol]
  # @return [Hash]
  def species_config(species)
    data = fetch(setting(:species, {}), species)
    return data.is_a?(Hash) ? data.transform_keys(&:to_s) : {}
  end

  # Mécanique active : réglage de Studio, puis commande d'évènement (activer / désactiver)
  # @param kind [Symbol]
  def enabled?(kind)
    data = save_data
    return false if (data[:disabled] || []).include?(kind)
    return true if (data[:enabled] || []).include?(kind)

    value = fetch(setting(:enabled, {}), kind)
    return value.nil? || value ? true : false
  end

  # Réglages d'un dresseur appliqués à son équipe et à son sac (début du combat)
  # @param trainer [Studio::Trainer]
  # @param party [Array<PFM::Pokemon>]
  # @param bag [PFM::Bag]
  def apply_trainer(trainer, party, bag)
    data = fetch(setting(:trainers, {}), trainer.db_symbol)
    return unless data.is_a?(Hash)

    data = data.transform_keys(&:to_s)
    (data['keys'] || []).each do |kind|
      item = TRAINER_KEY_ITEMS[kind.to_sym]
      bag.add_item(item, 1) if item && bag && !bag.contain_item?(item)
    end
    (data['team'] || []).each_with_index do |slot, index|
      pokemon = party[index]
      next unless pokemon && slot.is_a?(Hash)

      slot = slot.transform_keys(&:to_s)
      pokemon.pj_tera_type = slot['tera'] if slot['tera'] && !slot['tera'].to_s.empty?
      pokemon.pj_gmax_factor = true if slot['gmax']
      pokemon.pj_dynamax_level = slot['dynamax_level'] if slot['dynamax_level']
    end
  rescue StandardError => e
    log_error("Gimmicks : dresseur #{trainer&.db_symbol} (#{e.message})") if respond_to?(:log_error, true)
  end
end

module PFM
  class Pokemon
    module PJGimmicksStudio
      # Facteur Gigamax : donné au Pokémon, sinon réglage de l'espèce dans Studio
      def pj_gmax_factor
        value = super
        return value unless value.nil?

        return Gimmicks.species_config(db_symbol)['gmax'] ? true : false
      end
    end
    prepend PJGimmicksStudio
  end
end

module Battle
  class Logic
    class BattleInfo
      class << self
        module PJGimmicksTrainers
          def add_trainer(battle_info, bank, id_trainer)
            super
            trainer = data_trainer(id_trainer)
            Gimmicks.apply_trainer(trainer, battle_info.parties[bank]&.last || [], battle_info.bags[bank]&.last)
          end
        end
        prepend PJGimmicksTrainers
      end
    end
  end
end

# Commandes d'évènement (onglet Plugins de l'éditeur d'évènements, ou commande Script)
class Interpreter
  # Active / désactive une mécanique pour la suite de la partie
  # @param kind [Symbol] :mega, :zmove, :dynamax, :tera
  # @param value [Boolean]
  def gimmick_actif(kind, value = true)
    data = Gimmicks.save_data
    kind = kind.to_sym
    data[:disabled] = (data[:disabled] || []) - [kind]
    data[:enabled] = (data[:enabled] || []) - [kind]
    (value ? data[:enabled] : data[:disabled]) << kind
  end

  # Le prochain Pokémon sauvage pourra utiliser ces mécaniques (une fois, pour le prochain combat)
  # @param kinds [Array<Symbol>]
  def gimmick_sauvage(*kinds)
    Gimmicks.save_data[:wild] = kinds.flatten.map(&:to_sym)
  end

  # Type Téra d'un Pokémon de l'équipe
  # @param index [Integer] place dans l'équipe (0 à 5)
  # @param type [Symbol] type (:fire…) ou :stellar
  def type_tera(index, type)
    $actors[index.to_i]&.pj_tera_type = type
  end

  # Facteur Gigamax d'un Pokémon de l'équipe
  # @param index [Integer] place dans l'équipe (0 à 5)
  # @param value [Boolean]
  def facteur_gigamax(index, value = true)
    $actors[index.to_i]&.pj_gmax_factor = value ? true : false
  end

  # Niveau Dynamax d'un Pokémon de l'équipe
  # @param index [Integer] place dans l'équipe (0 à 5)
  # @param level [Integer] 0 à 10
  def niveau_dynamax(index, level)
    $actors[index.to_i]&.pj_dynamax_level = level
  end

  # Recharge l'Orbe Téracristal
  def recharger_orbe_tera
    Gimmicks::Tera.recharge
  end

  # @param index [Integer] place dans l'équipe
  # @return [Symbol, nil] type Téra du Pokémon
  def type_tera?(index)
    return $actors[index.to_i]&.pj_tera_type
  end
end
