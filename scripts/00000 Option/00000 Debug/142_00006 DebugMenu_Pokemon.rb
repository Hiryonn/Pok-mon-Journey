# Script décompilé depuis le bytecode du jeu (Ruby 3.0) — fichier d'origine : RMXP/00006 DebugMenu_Pokemon.rb
# Les commentaires et la mise en forme d'origine ne sont pas récupérables.

module GamePlay
  class DebugMenu
    def add_pokemon
      species_input = display_text_input(text_get(TEXT_FILE_ID, 48), "pikachu")
      return if species_input.nil? || species_input.empty?
      species_sym = species_input.downcase.to_sym

      begin
        creature = data_creature(species_sym)
        if creature && creature.id > 0
          nil
        else
          display_message(format(text_get(TEXT_FILE_ID, 87), species_sym))
          return
        end
      rescue
        display_message(format(text_get(TEXT_FILE_ID, 87), species_sym))
        return
      end

      level = display_number_input(text_get(TEXT_FILE_ID, 50), 50)
      return if level.nil?
      level = [[level, 1].max, 100].min
      pokemon = PFM::Pokemon.new(species_sym, level)

      if $actors.size < 6
        $actors << pokemon
        display_message(format(text_get(TEXT_FILE_ID, 88), pokemon.name))
      else
        $storage.store(pokemon)
        display_message(format(text_get(TEXT_FILE_ID, 89), pokemon.name))
      end
    end

    def fill_storage
      count = 0
      each_data_creature do |creature|
        next if creature.db_symbol == :__undef__ || creature.id == 0
        pokemon = PFM::Pokemon.new(creature.db_symbol, 50)
        $storage.store(pokemon)
        $pokedex.mark_seen(creature.id, pokemon.form)
        count += 1
      end

      display_message(format(text_get(TEXT_FILE_ID, 90), count))
    end

    def clear_storage
      choice = display_list_choice(text_get(TEXT_FILE_ID, 54), [text_get(TEXT_FILE_ID, 55), text_get(TEXT_FILE_ID, 56)])
      return if choice != 0

      $storage.max_box.times { |box_idx| $storage.get_box_content(box_idx).map! { } }

      display_message(text_get(TEXT_FILE_ID, 57))
    end

    def quick_hatch_eggs
      count = 0
      $actors.each do |pokemon|
        if pokemon.egg?
          pokemon.step_remaining = 1
          count += 1
        end
      end

      msg = count > 0 ? format(text_get(TEXT_FILE_ID, 91), count) : text_get(TEXT_FILE_ID, 92)
      display_message(msg)
    end

    def access_storage
      GamePlay.open_pokemon_storage_system
    end
  end
end
