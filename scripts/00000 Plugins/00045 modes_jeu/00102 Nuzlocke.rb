# Mode Nuzlocke
#  - 1re rencontre sauvage de chaque zone : seule celle-là peut être capturée (les autres : capture impossible)
#  - clause chromatique : un Pokémon chromatique est toujours capturable et ne consomme pas la zone
#  - clause doublons : une espèce déjà obtenue ne compte pas comme rencontre de la zone (mais n'est pas capturable)
#  - surnom obligatoire à la capture ; mort définitive : un Pokémon K.O. part au cimetière (réglage nuzlocke_permadeath)
#  - objet « nuzlocke_revive » (ou commande nuzlocke_ressusciter) : ranime un Pokémon du cimetière
module ModesJeu
  module Nuzlocke
    module_function

    def data
      return ($user_data[:pj_nuzlocke] ||= { 'zones' => {}, 'species' => [], 'graves' => [] })
    end

    def zone_id
      id = $env.master_zone.to_i >= 0 ? $env.master_zone : $env.get_current_zone
      return id.to_i
    rescue StandardError
      return -1
    end

    def species_of(pokemon)
      return pokemon.db_symbol.to_s
    end

    # Appelé au début d'un combat sauvage : décide si la capture sera permise
    # @param wild [PFM::PokemonBattler]
    # @return [Symbol] :ok, :zone (zone déjà utilisée), :dupe (doublon)
    def evaluate(wild)
      zones = data['zones']
      key = zone_id.to_s
      return :ok if ModesJeu.setting('nuzlocke_shiny_clause') && wild.shiny?
      return :ok unless ModesJeu.setting('nuzlocke_first_encounter')
      return :zone if zones[key]
      return :dupe if ModesJeu.setting('nuzlocke_dupes_clause') && data['species'].include?(species_of(wild))

      zones[key] = species_of(wild)
      return :ok
    end

    def caught(pokemon)
      list = data['species']
      list << species_of(pokemon) unless list.include?(species_of(pokemon))
    end

    # --- Cimetière -----------------------------------------------------------------------------
    def graves
      return data['graves']
    end

    # Marque les Pokémon K.O. à la fin d'un combat
    def mark_dead
      $actors.each { |pokemon| pokemon.instance_variable_set(:@pj_grave, true) if !pokemon.egg? && pokemon.dead? }
    end

    # Enterre les Pokémon marqués (dernier ranimé si toute l'équipe est tombée)
    def bury
      dead = $actors.select { |pokemon| pokemon.instance_variable_get(:@pj_grave) }
      return if dead.empty?

      if dead.size == $actors.size
        last = dead.pop
        last.remove_instance_variable(:@pj_grave)
        last.hp = 1
        $scene.display_message_and_wait(ModesJeu.text(:nuz_wipe)) if ModesJeu.setting('nuzlocke_wipe') == 'revive_last'
      end
      dead.each do |pokemon|
        $actors.delete(pokemon)
        pokemon.remove_instance_variable(:@pj_grave)
        graves << pokemon
        $scene.display_message_and_wait(ModesJeu.text(:nuz_dead, pokemon.given_name))
      end
    rescue StandardError => e
      ModesJeu.log_error("cimetière : #{e.message}")
    end

    # Ranime un Pokémon du cimetière dans l'équipe (sinon dans le PC)
    # @return [Boolean]
    def revive(index)
      pokemon = graves[index]
      return false unless pokemon

      graves.delete_at(index)
      pokemon.cure if pokemon.respond_to?(:cure)
      pokemon.hp = (pokemon.max_hp / 2.0).ceil
      if $actors.size < 6
        $actors << pokemon
      else
        $storage.store(pokemon)
      end
      return true
    end

    def random_nickname
      names = Array(ModesJeu.setting('nuzlocke_nicknames'))
      return names.empty? ? 'Sans-nom' : names.sample
    end
  end
end

module Battle
  class Logic
    class BattleEndHandler
      module ModesJeuNuzlockeEnd
        def process
          result = super
          ModesJeu::Nuzlocke.mark_dead if ModesJeu.nuzlocke? && ModesJeu.setting('nuzlocke_permadeath')
          return result
        rescue StandardError => e
          ModesJeu.log_error("fin de combat : #{e.message}")
          return result
        end
      end
      prepend ModesJeuNuzlockeEnd
    end
  end

  class Scene
    module ModesJeuNuzlocke
      # La capture est-elle permise dans ce combat ? (calculé une seule fois par combat)
      def pj_nuz_status
        return @pj_nuz_status if @pj_nuz_status

        wild = @logic.alive_battlers(1).first
        @pj_nuz_status = wild ? ModesJeu::Nuzlocke.evaluate(wild) : :ok
      end

      # Zone déjà utilisée / doublon : pas de Poké Ball
      def catch_prevented(item_wrapper)
        if ModesJeu.nuzlocke? && !@logic.battle_info.trainer_battle? && pj_nuz_status != :ok
          message_window.blocking = true
          message_window.wait_input = true
          display_message_and_wait(ModesJeu.text(pj_nuz_status == :zone ? :nuz_block_zone : :nuz_block_dupe))
          $bag.add_item(item_wrapper.item.db_symbol, 1)
          @next_update = :player_action_choice
          return true
        end
        return super
      end

      # Surnom obligatoire (on redemande, puis surnom de secours)
      def give_pokemon_procedure(battler, ball)
        return super unless ModesJeu.nuzlocke?

        super
        pokemon = battler.original
        ModesJeu::Nuzlocke.caught(pokemon)
        return unless ModesJeu.setting('nuzlocke_nickname')

        3.times do
          break if pokemon.given_name.to_s != pokemon.name.to_s

          rename_sequence(pokemon)
        end
        pokemon.given_name = ModesJeu::Nuzlocke.random_nickname if pokemon.given_name.to_s == pokemon.name.to_s
      rescue StandardError => e
        ModesJeu.log_error("capture : #{e.message}")
      end
    end
    prepend ModesJeuNuzlocke
  end
end

# Enterrement sur la carte (après le combat, ou après l'écran de défaite)
class Scene_Map
  module ModesJeuGrave
    def update
      super
      return unless ModesJeu.nuzlocke? && ModesJeu.setting('nuzlocke_permadeath')

      @pj_grave_tick = (@pj_grave_tick || 0) + 1
      return unless @pj_grave_tick % 30 == 0
      return if $game_system.map_interpreter.running?

      ModesJeu::Nuzlocke.bury
    rescue StandardError => e
      ModesJeu.log_error("carte : #{e.message}")
    end
  end
  prepend ModesJeuGrave
end
