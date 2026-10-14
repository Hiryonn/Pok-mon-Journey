module Battle
  module Effects
    class Ability
      class CellAcceleration < Ability
        

         def initialize(logic, target, db_symbol)
                super
                @set_pokemon = nil 
                @type = nil
                @position = nil
                @radiant_set = nil

         end


        def on_switch_event(handler, who, with)
          return if with != @target && @set_pokemon == nil
          if @target.type1 == 19 && @target.kosmosa_type && !@radiant_set
              @target.type2 = @target.kosmosa_type
              @radiant_set = true
          end
          if @set_pokemon == nil && with == @target && @type == nil
            foes = handler.logic.foes_of(with).select(&:alive?)
            return if foes.empty?
            @position = rand(foes.length)
            @set_pokemon = foes[@position]
            bank = foes.map(&:bank).first
            handler.logic.add_bank_effect(Effects::CellAcceleration.new(@logic, bank, @target, @set_pokemon, @position))
          end  
        end

        
      end
      register(:cell_acceleration, CellAcceleration)
    end
  end
end