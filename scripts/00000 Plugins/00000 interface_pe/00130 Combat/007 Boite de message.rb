# Interface PE — combat : boîte des messages de combat assortie à la bande du bas (graphics/windowskins/battle_pj_message.png)
module Battle
  class Scene
    class Message
      if BattleUI::PJ::ENABLED
        remove_const(:WINDOW_SKIN)
        # Fond des messages de combat (même découpage que message_box de PSDK : 320 x 50)
        WINDOW_SKIN = 'battle_pj_message'
      end
    end
  end
end
