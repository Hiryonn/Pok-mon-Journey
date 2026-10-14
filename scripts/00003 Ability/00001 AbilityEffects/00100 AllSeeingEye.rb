module Battle
  module Effects
        class Ability 
          class AllSeeingEye < Ability
            def on_switch_event(handler, who, with)
              return if with != @target

              alive_foes = handler.logic.foes_of(with).select(&:alive?)
              return if alive_foes.empty?

              rng = handler.logic.generic_rng

  
              foe = alive_foes.shuffle(random: rng).first
              return if foe.nil? || foe.moveset.empty?

  
              revealed_moves = foe.moveset.shuffle(random: rng).take(2)

              handler.scene.visual.show_ability(with)

              revealed_moves.each do |move|
                handler.scene.display_message_and_wait(
                  parse_text_with_pokemon(19, 433, foe, PFM::Text::MOVE[1] => move.name)
                )
              end
            end
          end
          register(:allseeing_eye, AllSeeingEye)
        end
  end
end