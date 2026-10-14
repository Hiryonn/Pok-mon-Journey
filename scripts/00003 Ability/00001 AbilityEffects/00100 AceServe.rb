module Battle
  module Effects
    class Ability
      class AceServe < Ability

      def on_switch_event(handler, who, with)
          return if with != @target
          alive_foes = handler.logic.foes_of(with).select(&:alive?)
          if alive_foes.any?
              handler.scene.visual.show_ability(with) 
              if alive_foes.length == 1
                alive_foes.each do |foe|
                  types = []
                  types[0] = foe.type1
                  types[1] = foe.type2
                  effectiveness = effect_multiplier(types)
                  handler.logic.damage_handler.damage_change( foe.max_hp/effectiveness, foe)
                end
              else
                battler_index = rand(alive_foes.length)
                foe = alive_foes[battler_index]
                types = []
                types[0] = foe.type1
                types[1] = foe.type2
                effectiveness = effect_multiplier(types)
                handler.logic.damage_handler.damage_change( foe.max_hp/effectiveness, foe)
              end
          end
      end

      def effect_multiplier(types)
          effectiveness = 8
          types.each do |type|
              if type == 5 || type == 17 || type == 11 || type == 19
              effectiveness = effectiveness/2
              elsif type == 2 || type == 18 || type == 16 || type == 7 || type == 8 || type == 14 || type == 10
                effectiveness = 2*effectiveness
              else 
                nil
              end
          end
          puts "effectiveness #{effectiveness}"
          return effectiveness                      
      end 
      end

      register(:ace_serve, AceServe)
    end
  end
end