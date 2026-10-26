# Script décompilé depuis le bytecode du jeu (Ruby 3.0) — fichier d'origine : RMXP/00104_Storage_OW.rb
# Les commentaires et la mise en forme d'origine ne sont pas récupérables.

module PFM
  class Storage
    def get_all_storage_creatures
      values = []
      @boxes.each { |box| box.content.each { |pokemon| next values.push(pokemon) if pokemon } }

      values
    end
  end
end

module PFM
  class Daycare
    @male_data = nil
    @female_data = nil
    def how_much_in_pension
      unless pokemon_list = @daycares.dig($game_variables[46], :pokemon)
        return 0
      end

      pokemon_list.size
    end

    def retrieve_poke(var_id, index)
      pokemon = @daycares.dig(game_state.game_variables[var_id], :pokemon, index)
    end
  end
end

module PokemonOW_Pension
  EVENT_ROAD_IDS = [18, 17]
  EVENT_WATER_IDS = [35, 36]
  BREED_GROUPS_WATER = [2, 9, 12]
  UNDER_WATER_OPACITY = 80
  EVENT_EGG_ID = 47
  module_function

  def creature_in_pension
    !$daycare.empty?($game_variables[46])
  end

  def pension_have_egg
    $daycare.has_egg?($game_variables[46])
  end

  def show_creatures
    if creature_in_pension
      how_much_in_pension = $daycare.how_much_in_pension
      poke1, poke2 = nil, nil
      if how_much_in_pension == 1
        log_error("PokemonOW_Pension how_much_in_pension = 1")
        poke1 = $daycare.retrieve_poke($game_variables[46], 0)
        log_error("Pokemon name : #{poke1.character_name}")
        breed_groups = data_creature_form(poke1.db_symbol, poke1.form).breed_groups
        log_error("Breed groups : #{breed_groups}")
        is_water_type = false
        for group in breed_groups
          if BREED_GROUPS_WATER.include?(group)
            is_water_type = true
            break
          end
        end
        log_error("Is water type : #{is_water_type}")
        if is_water_type
          if poke1.form == 0
            tmp = poke1.character_name
            first_part = tmp.split("_")[0] + "_surf"
            log_error(first_part)
            return $game_system.map_interpreter.ge(EVENT_WATER_IDS[0]).set_appearance(first_part)
          end
          return $game_system.map_interpreter.ge(EVENT_WATER_IDS[0]).set_appearance(poke1.character_name + "_surf")
        end
        return $game_system.map_interpreter.ge(EVENT_ROAD_IDS[0]).set_appearance(poke1.character_name)
      end
      if how_much_in_pension == 2
        log_error("PokemonOW_Pension how_much_in_pension = 2")
        poke1 = $daycare.retrieve_poke($game_variables[46], 0)
        poke2 = $daycare.retrieve_poke($game_variables[46], 1)
        log_error("Pokemon 1 name : #{poke1.character_name}")
        log_error("Pokemon 2 name : #{poke2.character_name}")
        breed_groups_1 = data_creature_form(poke1.db_symbol, poke1.form).breed_groups
        log_error("Breed groups 1 : #{breed_groups_1}")
        breed_groups_2 = data_creature_form(poke2.db_symbol, poke2.form).breed_groups
        log_error("Breed groups 2 : #{breed_groups_2}")
        is_water_type_1 = false
        for group in breed_groups_1
          if BREED_GROUPS_WATER.include?(group)
            is_water_type_1 = true
            break
          end
        end
        is_water_type_2 = false
        for group in breed_groups_2
          if BREED_GROUPS_WATER.include?(group)
            is_water_type_2 = true
            break
          end
        end
        log_error("Is water type 1 : #{is_water_type_1}")
        log_error("Is water type 2 : #{is_water_type_2}")
        if is_water_type_1
          if poke1.form == 0
            tmp = poke1.character_name
            first_part = tmp.split("_")[0] + "_surf"
            log_error(first_part)
            $game_system.map_interpreter.ge(EVENT_WATER_IDS[0]).set_appearance(first_part)
          else
            $game_system.map_interpreter.ge(EVENT_WATER_IDS[0]).set_appearance(poke1.character_name + "_surf")
          end
        else
          $game_system.map_interpreter.ge(EVENT_ROAD_IDS[0]).set_appearance(poke1.character_name)
        end
        if is_water_type_2
          if poke2.form == 0
            tmp = poke2.character_name
            first_part = tmp.split("_")[0] + "_surf"
            log_error(first_part)
            return $game_system.map_interpreter.ge(EVENT_WATER_IDS[1]).set_appearance(first_part)
          end
          return $game_system.map_interpreter.ge(EVENT_WATER_IDS[1]).set_appearance(poke2.character_name + "_surf")
        end
        return $game_system.map_interpreter.ge(EVENT_ROAD_IDS[1]).set_appearance(poke2.character_name)
      end
    end
  end

  def show_egg
    $game_switches[::Yuki::Sw::EGG_DAYCARE] = pension_have_egg
  end
end

module PokemonOW
  EVENT_FLOOR_IDS = [3, 4, 5, 6, 7, 8]
  EVENT_WATER_IDS = [9, 11, 12, 13, 14, 15]
  BREED_GROUPS_WATER = [2, 9, 12]
  NUMBER_OF_CREATURES = 6
  module_function

  def show_creatures
    data = $storage.get_all_storage_creatures
    index = 0
    data = data.count < NUMBER_OF_CREATURES ? data : data.sample(NUMBER_OF_CREATURES)

    for creature in data
      breed_groups = data_creature_form(creature.db_symbol, creature.form).breed_groups
      is_water_type = false
      for group in breed_groups
        if BREED_GROUPS_WATER.include?(group)
          is_water_type = true
          break
        end
      end

      log_error("Creature : #{creature.character_name}")
      log_error("Is water type : #{is_water_type}")

      if is_water_type
        log_error("Form : #{creature.form}")
        if creature.form == 0
          tmp = creature.character_name
          first_part = tmp.split("_")[0] + "_surf"
          log_error(first_part)
          $game_system.map_interpreter.ge(EVENT_WATER_IDS[index]).set_appearance(first_part)
        else
          $game_system.map_interpreter.ge(EVENT_WATER_IDS[index]).set_appearance(creature.character_name)
        end
      else
        $game_system.map_interpreter.ge(EVENT_FLOOR_IDS[index]).set_appearance(creature.character_name)
      end

      index += 1
    end
  end

  def reset_creatures
    index = 0

    for event in EVENT_FLOOR_IDS
      $game_system.map_interpreter.ge(EVENT_FLOOR_IDS[index]).set_appearance("blank")
      index += 1
    end
  end
end
