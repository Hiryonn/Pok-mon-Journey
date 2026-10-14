module Debug
    module_function
    
    def party
        (1..6).each do |i|
            S.MI.add_pokemon(25, 50, false)
            S.MI.add_pokemon(150, 50, false)
            S.MI.add_pokemon(330, 50, false)
            S.MI.add_pokemon(658, 50, false)
            S.MI.add_pokemon(869, 50, false)
            S.MI.add_pokemon(959, 50, false)
        end
    end

    def pokemon
        (1..1024).each do |i|
            S.MI.add_pokemon(i, 50, false)
        end
    end

    def pokemon_shiny
        (1..1024).each do |i|
            S.MI.add_pokemon(i, 50, true)
        end
    end

    def pokegacha
            S.MI.add_pokemon(rand(1..1024), 50)
    end

    def candy
        S.MI.give_item(:rare_candy, 100)
        S.MI.give_item(:exp_candy_xs, 100)
        S.MI.give_item(:exp_candy_s, 100)
        S.MI.give_item(:exp_candy_m, 100)
        S.MI.give_item(:exp_candy_l, 100)
        S.MI.give_item(:exp_candy_xl, 100)
    end

    def ball
        S.MI.give_item(:poke_ball, 100)
        S.MI.give_item(:great_ball, 100)
        S.MI.give_item(:ultra_ball, 100)
        S.MI.give_item(:master_ball, 100)
    end

    def ability
        S.MI.give_item(:ability_patch, 100)
        S.MI.give_item(:ability_capsule, 100)
    end

    def heal_all
        $pokemon_party.heal_party  
    end

    def open_pc
        GamePlay.open_pokemon_storage_system  
    end
end

module PFM
    class Bag
        def contain_item_with_quantity?(db_symbol, quantity)
            return item_quantity(db_symbol) >= quantity
        end
    end
end