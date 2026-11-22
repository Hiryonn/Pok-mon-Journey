# encoding: utf-8
# Advanced Pokédex : récompenses de recherche
#
# Quand la recherche d'une espèce atteint le niveau reward_level (10 points par défaut), elle est récompensée UNE fois :
#   charm     Charme Chroma de l'espèce : ses Pokémon sauvages ont une chance de plus d'être chromatiques (1 / charm_rate par
#             Pokémon sauvage de l'espèce, en plus de la chance normale ; combats et Pokémon visibles)
#   card      la carte Triple Triad de l'espèce (plugin Triple Triad)
#   memento   un Souvenir (ruban, ex. hisui) donné aux Pokémon de l'espèce que le joueur possède alors (équipe et PC)
#   none      rien
# Réglages (Data/configs/plugins/pokedex_tasks.json) :
#   settings  reward_level, reward_default (charm / card / memento / none), reward_ribbon (Souvenir par défaut), charm_rate,
#             reward_notify (bannière du téléphone)
#   rewards   par espèce : { "pikachu": { "type": "charm" }, "eevee": { "type": "memento", "ribbon": "hisui" } }
# Commandes d'évènement : recherche_recompensee?(:pikachu), recompenser_recherche(:pikachu) (force)
module AdvancedPokedex
  module Research
    REWARD_DEFAULTS = { 'reward_level' => 0, 'reward_default' => 'card', 'reward_ribbon' => 'hisui', 'charm_rate' => 1365,
                        'reward_notify' => true }.freeze
    TYPES = %w[charm card memento none].freeze

    module_function

    def setting(key)
      value = Tasks.fetch(Tasks.config.settings, key)
      return value.nil? ? REWARD_DEFAULTS[key.to_s] : value
    end

    # @return [Integer] points de recherche exigés
    def level
      value = setting('reward_level').to_i
      return value > 0 ? value : Tasks.points_needed
    end

    # @return [Hash] { 'given' => { espèce => type }, 'charms' => { espèce => true } }
    def store
      dex = PFM.game_state.pokedex
      data = dex.instance_variable_get(:@pj_research) || dex.instance_variable_set(:@pj_research, {})
      data['given'] ||= {}
      data['charms'] ||= {}
      return data
    end

    # @return [Hash] récompense prévue pour l'espèce : { 'type' =>, 'ribbon' => }
    def reward_for(species)
      custom = Tasks.fetch(Tasks.config.rewards, species)
      type = Tasks.fetch(custom, 'type').to_s
      type = setting('reward_default').to_s unless TYPES.include?(type)
      ribbon = Tasks.fetch(custom, 'ribbon').to_s
      ribbon = setting('reward_ribbon').to_s if ribbon.empty?
      return { 'type' => type, 'ribbon' => ribbon }
    end

    def given?(species)
      return store['given'].key?(species.to_s)
    end

    def charm?(species)
      return store['charms'][species.to_s] ? true : false
    rescue StandardError
      return false
    end

    # Récompense l'espèce si sa recherche est assez haute
    def check(species)
      species = species.to_sym
      return false if given?(species) || Tasks.points(species) < level

      return grant(species)
    end

    # @return [Boolean]
    def grant(species)
      species = species.to_sym
      reward = reward_for(species)
      store['given'][species.to_s] = reward['type']
      text = case reward['type']
             when 'charm' then give_charm(species)
             when 'card' then give_card(species)
             when 'memento' then give_memento(species, reward['ribbon'])
             end
      notify(species, text) if text
      return true
    rescue StandardError => e
      log_error("Récompenses de recherche : #{e.message}") if respond_to?(:log_error, true)
      return false
    end

    def name_of(species)
      return data_creature(species).name.to_s
    rescue StandardError
      return species.to_s
    end

    def give_charm(species)
      store['charms'][species.to_s] = true
      return Tasks.fr? ? "Charme Chroma : #{name_of(species)}" : "Shiny Charm: #{name_of(species)}"
    end

    def give_card(species)
      return nil unless defined?(TripleTriad) && TripleTriad.add(species, 1)

      return Tasks.fr? ? "Carte #{name_of(species)}" : "#{name_of(species)} card"
    end

    def give_memento(species, ribbon)
      ribbon = ribbon.to_sym
      return nil unless defined?(PFM::RIBBONS_DATA) && PFM::RIBBONS_DATA.key?(ribbon)

      owned(species).each { |pokemon| pokemon.add_ribbon(ribbon) }
      return Tasks.fr? ? "Souvenir pour vos #{name_of(species)}" : "Memento for your #{name_of(species)}"
    end

    # Pokémon de l'espèce dans l'équipe et au PC
    def owned(species)
      list = Array($actors).compact.dup
      boxes = $storage&.instance_variable_get(:@boxes)
      Array(boxes).each { |box| list.concat(Array(box.respond_to?(:content) ? box.content : box).compact) }
      return list.select { |pokemon| pokemon.respond_to?(:db_symbol) && pokemon.db_symbol == species && !pokemon.egg? }
    rescue StandardError
      return Array($actors).compact.select { |pokemon| pokemon.db_symbol == species }
    end

    def notify(species, text)
      return unless setting('reward_notify') && defined?(UI::PokeSmart::Notify)

      UI::PokeSmart::Notify.push(text, title: Tasks.fr? ? 'Recherche terminée' : 'Research complete')
    end

    # Chance de plus d'un Pokémon sauvage de l'espèce du Charme Chroma
    # @param pokemon [PFM::Pokemon]
    # @return [PFM::Pokemon]
    def apply_charm(pokemon)
      return pokemon unless pokemon.is_a?(PFM::Pokemon) && !pokemon.shiny? && charm?(pokemon.db_symbol)

      rate = [setting('charm_rate').to_i, 1].max
      pokemon.shiny = true if rand(rate) == 0
      return pokemon
    rescue StandardError
      return pokemon
    end
  end

  module Tasks
    module ResearchHook
      def record(species, type, target = nil, amount = 1)
        super
        sym = species.is_a?(Integer) ? data_creature(species).db_symbol : species.to_sym
        Research.check(sym) if PFM.game_state&.pokedex
      rescue StandardError
        nil
      end
    end
    singleton_class.prepend ResearchHook
  end
end

module PFM
  class Wild_Battle
    module PokedexCharmWild
      def configure_battle(enemy_arr, battle_id)
        Array(enemy_arr).each { |pokemon| AdvancedPokedex::Research.apply_charm(pokemon) } if enemy_arr.is_a?(Array)
        return super
      end
    end
    prepend PokedexCharmWild
  end
end

class Interpreter
  def recherche_recompensee?(species)
    return AdvancedPokedex::Research.given?(species)
  end

  # Donne la récompense de l'espèce tout de suite (une seule fois)
  def recompenser_recherche(species)
    return false if AdvancedPokedex::Research.given?(species)

    return AdvancedPokedex::Research.grant(species)
  end
end
