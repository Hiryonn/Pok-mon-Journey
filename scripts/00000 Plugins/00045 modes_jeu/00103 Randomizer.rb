# Randomizer : espèces des Pokémon offerts (starters…), des rencontres sauvages et des équipes de dresseurs.
# Les niveaux sont conservés ; talents et capacités ne sont pas touchés. Le tirage dépend de la graine choisie au
# début de la partie : une même espèce donne toujours la même espèce de remplacement (1 pour 1, sans doublon).
module ModesJeu
  module Randomizer
    module_function

    def reset
      @map = nil
    end

    # @return [Array<Symbol>] espèces (db_symbol) pouvant être tirées
    def pool
      excluded = Array(ModesJeu.setting('randomizer_exclude')).map(&:to_sym)
      list = GameData::Pokemon.all.compact.map(&:db_symbol).reject { |sym| sym == :__undef__ || excluded.include?(sym) }
      return list.sort_by(&:to_s)
    end

    # @return [Hash{Symbol => Symbol}] espèce d'origine => espèce de remplacement
    def mapping
      return @map if @map && @seed == ModesJeu.seed

      @seed = ModesJeu.seed
      list = pool
      shuffled = list.shuffle(random: Random.new(@seed))
      @map = list.zip(shuffled).to_h
    end

    # @param id [Symbol, Integer]
    # @return [Symbol, Integer] espèce de remplacement (même type d'identifiant)
    def species(id)
      sym = id.is_a?(Integer) ? GameData::Pokemon.db_symbol(id) : id.to_sym
      new_sym = mapping[sym] || sym
      return id.is_a?(Integer) ? GameData::Pokemon.id(new_sym) : new_sym
    rescue StandardError => e
      ModesJeu.log_error("randomizer : #{e.message}")
      return id
    end

    # @param pokemon [PFM::Pokemon]
    # @param kind [Symbol] :trainers, :wild ou :gifts
    # @return [PFM::Pokemon] nouveau Pokémon (même niveau) ou le même si rien à faire
    def replace(pokemon, kind)
      return pokemon unless ModesJeu.randomizer? && ModesJeu.setting("randomizer_#{kind}")

      target = species(pokemon.db_symbol)
      return pokemon if target == pokemon.db_symbol

      fresh = PFM::Pokemon.new(target, pokemon.level)
      fresh.item_holding = pokemon.item_db_symbol if pokemon.respond_to?(:item_db_symbol) && fresh.respond_to?(:item_holding=)
      return fresh
    rescue StandardError => e
      ModesJeu.log_error("randomizer : #{e.message}")
      return pokemon
    end
  end
end

# Rencontres sauvages : les Pokémon sauvages sont remplacés (sur place) avant le combat
module PFM
  class Wild_Battle
    module ModesJeuWild
      def configure_battle(enemy_arr, battle_id)
        if enemy_arr.is_a?(Array) && ModesJeu.randomizer? && ModesJeu.setting('randomizer_wild')
          enemy_arr.each_index do |i|
            enemy_arr[i] = ModesJeu::Randomizer.replace(enemy_arr[i], :wild) if enemy_arr[i].is_a?(PFM::Pokemon)
          end
        end
        return super
      end
    end
    prepend ModesJeuWild
  end
end

# Pokémon offerts (starters, cadeaux, œufs) : commande add_pokemon des évènements
class Interpreter
  module ModesJeuGifts
    def add_pokemon(id, level = 5, shiny = false, *rest)
      if ModesJeu.randomizer? && ModesJeu.setting('randomizer_gifts') && !id.is_a?(PFM::Pokemon)
        id = ModesJeu::Randomizer.species(id)
      end
      return super
    end
  end
  prepend ModesJeuGifts
end
