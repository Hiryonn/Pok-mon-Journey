module Battle
  module Effects
    class Ability
      class Overdrive < Ability
        def initialize(logic, target, db_symbol)
          super
        end

        def mod3_multiplier(user, target, move)
          return 1 unless user == @target
          return 1 unless move.type_electric?
          return 2
        end

        def on_post_damage(handler, hp, target, launcher, skill)
          return unless launcher == @target
          return unless skill&.type_electric?
          return if launcher.hp <= 0 

          recoil = (hp * 0.5).to_i
          recoil = [recoil, launcher.hp - 1].min 
          return if recoil <= 0

          handler.scene.visual.show_ability(launcher)
          handler.scene.display_message_and_wait(parse_text_with_pokemon(400003, 36, launcher))
          handler.logic.damage_handler.damage_change(recoil, launcher)
        end
      end

      register(:overdrive, Overdrive)
    end
  end
end
