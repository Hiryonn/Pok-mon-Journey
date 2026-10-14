module Battle
  class Move
      class IdentitySwap < Move


          def deal_effect(user,  actual_target)
              actual_target.each do |target|
                target.type1 , user.type1 = user.type1 , target.type1
                target.type2 , user.type2 = user.type2 , target.type2
                logic.scene.display_message_and_wait(parse_text_with_2pokemon(400002, 74 , user, target))
              end
          end

      end
      Move.register(:s_identity_swap, IdentitySwap)
  end
end