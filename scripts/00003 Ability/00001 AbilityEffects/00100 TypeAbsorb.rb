module Battle
  module Effects
        class Ability 
          class TypeAbsorb < Ability
           def initialize(logic, target, db_symbol)
              super
              @type = 13
           end
            
            def on_post_damage(handler, hp, target, launcher, skill)
                return unless target == @target && !skill.nil?
                return if skill.type_rock? || target.type1 != 13
                target.type1 = skill.type
                @type = skill.type
                @logic.scene.visual.show_ability(target)
                @logic.scene.visual.wait_for_animation
                @logic.scene.display_message_and_wait(parse_text_with_pokemon(19, 899, target, '[VAR TYPE(0001)]' => data_type(target.type1).name)) 
            end

            def on_move_type_change(user, target, move, type)
              return nil unless user == @target && move.be_method == :s_crystal_burst  
              user.type1 = 13
              return @type
            end

            def on_end_turn_event(logic, scene, battlers)
                @type = @target.type1 == 13 ? 13 : @type
            end
           
          end
          register(:type_absorb, TypeAbsorb)
        end
  end
end