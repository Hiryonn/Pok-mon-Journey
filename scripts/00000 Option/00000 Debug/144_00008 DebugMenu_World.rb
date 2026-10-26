# Script décompilé depuis le bytecode du jeu (Ruby 3.0) — fichier d'origine : RMXP/00008 DebugMenu_World.rb
# Les commentaires et la mise en forme d'origine ne sont pas récupérables.

module GamePlay
  class DebugMenu
    def edit_switches
      switches_per_page = 10
      page = 0
      max_page = (($game_switches.size - 1) / switches_per_page rescue 10)
      last_index = 0

      loop do
        start_idx = page * switches_per_page + 1
        end_idx = start_idx + switches_per_page - 1

        options = (start_idx..end_idx).map do |i|
          value = $game_switches[i] ? text_get(TEXT_FILE_ID, 66) : text_get(TEXT_FILE_ID, 67)
          name = ($data_system.switches[i] rescue nil)
          if name && !name.empty?
            "#{i}: #{name} - #{value}"
          else
            "#{i}: #{value}"
          end
        end

        options << text_get(TEXT_FILE_ID, 39)
        choice = display_list_choice_paged(format(text_get(TEXT_FILE_ID, 65), page + 1), options, page, max_page, last_index)

        case choice
        when :next_page
          page = [page + 1, max_page].min
          next last_index = 0
        when :prev_page
          page = [page - 1, 0].max
          next last_index = 0
        when :first
          page = 0
          next last_index = 0
        when :last
          page = max_page
          next last_index = 0
        when -1, nil then break
        else
          break if options[choice] == text_get(TEXT_FILE_ID, 39)
          last_index = choice
          switch_id = start_idx + choice
          next $game_switches[switch_id] = !$game_switches[switch_id]
        end
      end
    end

    def edit_variables
      vars_per_page = 10
      page = 0
      max_page = (($game_variables.size - 1) / vars_per_page rescue 10)
      last_index = 0

      loop do
        start_idx = page * vars_per_page + 1
        end_idx = start_idx + vars_per_page - 1

        options = (start_idx..end_idx).map do |i|
          val = $game_variables[i]
          name = ($data_system.variables[i] rescue nil)
          if name && !name.empty?
            "#{i}: #{name} = #{val}"
          else
            "#{i}: #{val}"
          end
        end

        options << text_get(TEXT_FILE_ID, 39)
        choice = display_list_choice_paged(format(text_get(TEXT_FILE_ID, 68), page + 1), options, page, max_page, last_index)

        case choice
        when :next_page
          page = [page + 1, max_page].min
          next last_index = 0
        when :prev_page
          page = [page - 1, 0].max
          next last_index = 0
        when :first
          page = 0
          next last_index = 0
        when :last
          page = max_page
          next last_index = 0
        when -1, nil then break
        else
          break if options[choice] == text_get(TEXT_FILE_ID, 39)
          last_index = choice
          var_id = start_idx + choice
          new_value = display_number_input(format(text_get(TEXT_FILE_ID, 69), var_id), $game_variables[var_id])
          next $game_variables[var_id] = new_value if new_value
          next
        end
      end
    end

    def refresh_map
      $game_map.need_refresh = true
      $game_map.events.each_value { |e| e.refresh }
      display_message(text_get(TEXT_FILE_ID, 70))
    end

    def test_wild_battle
      battle_types = [text_get(TEXT_FILE_ID, 72), text_get(TEXT_FILE_ID, 73), text_get(TEXT_FILE_ID, 74)]
      type_choice = display_list_choice(text_get(TEXT_FILE_ID, 71), battle_types)
      return if type_choice < 0
      pokemon_count = type_choice + 1
      enemies = []
      last_species = "pikachu"
      last_level = 50

      pokemon_count.times do |i|
        ordinal = ["1st", "2nd", "3rd"][i]
        species_input = display_text_input(format(text_get(TEXT_FILE_ID, 75), ordinal), last_species)
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

        level = display_number_input(format(text_get(TEXT_FILE_ID, 76), ordinal), last_level)
        return if level.nil?
        level = [[level, 1].max, 100].min
        enemies << PFM::Pokemon.new(species_sym, level)
        last_species = species_input
        last_level = level
      end

      @running = false
      case type_choice
      when 0
        return $wild_battle.start_battle(enemies.first, enemies.first.level)
      when 1, 2
        $wild_battle.start_battle(enemies[0], enemies[0].level, *enemies[(1..-1)])
      else
        return
      end
    end

    def test_trainer_battle
      trainer_id = display_number_input(text_get(TEXT_FILE_ID, 104), 1)
      return if trainer_id.nil?
      @running = false
      ($game_system.map_interpreter.start_trainer_battle(trainer_id) rescue display_message(text_get(TEXT_FILE_ID, 77)))
    end

    def reset_map_trainers
      count = 0
      $game_map.events.each do |id, event|
        name = event.event.name.downcase
        if name.include?("trainer") || name.include?("dresseur")
          ["A", "B", "C", "D"].each { |letter| $game_self_switches[[$game_map.map_id, id, letter]] = false }
          count += 1
        end
      end

      $game_map.need_refresh = true
      display_message(format(text_get(TEXT_FILE_ID, 78), count))
    end

    def manage_roaming
      display_message(text_get(TEXT_FILE_ID, 79))
    end
  end
end
