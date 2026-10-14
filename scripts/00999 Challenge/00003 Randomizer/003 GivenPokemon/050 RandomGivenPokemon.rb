module PFM
  class GameState
    module RandomizerGameState
      # Add a Pokemon to the party (also update the Pokedex Informations)
      # @param pkmn [PFM::Pokemon]
      # @return [Boolean, Integer] Box index if stored in a box, false if failed, true if stored in the Party
      def add_pokemon(pkmn)
        rand = PFM.game_state.randomizer.given_pokemon
        return super unless rand.enabled?

        egg_init = {
          is_egg: pkmn.egg?,
          egg_how_obtained: pkmn.memo_text&.last == 31 ? :received : :found
        }
        if pkmn.randomizer_properties&.none?(:species)
          pkmn = PFM.game_state.randomizer.randomize_pokemon(rand, pkmn, pkmn.shiny?)
        end
        if egg_init[:is_egg]
          text_id = egg_init[:egg_how_obtained] == :received ? 31 : 29
          pkmn.egg_init(egg_init[:egg_how_obtained])
          pkmn.memo_text = [28, text_id]
        end
        super(pkmn)
      end
    end
  end
end

PFM::GameState.prepend(PFM::GameState::RandomizerGameState)

module GamePlay
  class Pokemon_Shop
    module Randomizer_Pokemon_Shop
      # Create the initial list from symbol_or_list
      def get_list_item
        super
        @list_item.each do |item|
          next if item[:randomized]

          item[:id] = PFM.game_state.randomizer.randomize_pokemon($randomizer.given_pokemon, PFM::Pokemon.new(item[:id], 1)).id
          item[:randomized] = true
        end
      end

      # Take the good amount of money from the player and some other things
      # @param nb [Integer] the number of items that the player is buying
      def money_checkout(nb)
        display_message(parse_text(11, 29))
        PFM.game_state.lose_money(nb * @list_item[@index][:price])
        pokemon = PFM::Pokemon.generate_from_hash(@list_item[@index])
        pokemon.randomizer_properties[:species] = nil # Randomizer addition
        PFM.game_state.add_pokemon(pokemon)
        @what_was_buyed << @list_item[@index][:id] unless @what_was_buyed.include?(@list_item[@index][:id])
        @shop.remove_from_pokemon_shop(@symbol_or_list, [@list_item[@index][:id]], [@list_item[@index]], [1]) if @symbol_or_list.is_a?(Symbol)
        update_shop_ui_after_buying(@index)
      end
    end
  end
end

GamePlay::Pokemon_Shop.prepend(GamePlay::Pokemon_Shop::Randomizer_Pokemon_Shop)

module PFM
  class Storage
    module Randomizer_Storage
      # Store a pokemon to the PC
      # @param pokemon [PFM::Pokemon] the Pokemon to store
      # @return [Boolean] if the Pokemon has been stored
      def store(pokemon)
        rand = PFM.game_state.randomizer.given_pokemon
        return super unless rand.enabled? && pokemon.randomizer_properties&.none?(:species)

        super(PFM.game_state.randomizer.randomize_pokemon(rand, pokemon, pokemon.shiny?))
      end
    end
  end
end

PFM::Storage.prepend(PFM::Storage::Randomizer_Storage)

module Randomizer_GTS
  def open
    return super unless PFM.game_state.randomizer.enabled?

    $scene.display_message_and_wait(ext_text(700, 0))
  end
end

GTS.singleton_class.prepend(Randomizer_GTS)
