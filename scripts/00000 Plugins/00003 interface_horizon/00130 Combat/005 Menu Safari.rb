# Interface Horizon — combat : menu du combat Safari (Safari Ball / Appât / Boue / Fuite)
module BattleUI
  # Safari : bandes Safari Ball / Appât / Boue / Fuite
  class PlayerChoiceSafari
    module PJStyle
      private

      def create_buttons
        return super unless @pj

        @buttons = pj_button_keys.map.with_index do |key, i|
          button = add_sprite(*pj_cell(i), nil, 'safari_buttons', 4, PJ.text(key), type: PJ::GridButton)
          button.row = i
          next button
        end
      end

      def pj_button_keys
        return %i[safari_ball bait mud flee]
      end

      def pj_button_rows
        return 4
      end
    end
    prepend PJStyle if PJ::ENABLED
  end
end
