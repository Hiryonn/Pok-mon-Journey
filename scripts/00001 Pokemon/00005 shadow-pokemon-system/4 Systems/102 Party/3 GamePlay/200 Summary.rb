module GamePlay
  class Summary
    # The engine bounds page navigation with a constant rather than the number of pages it holds. Grown from
    # the value in place, so a plugin that already added a page of its own keeps it.
    grown_last_state = LAST_STATE + 1
    remove_const(:LAST_STATE)
    LAST_STATE = grown_last_state

    # Adds the heart page of a Shadow Pokemon, which only shows up for a creature that has one.
    module SummaryShadowPatch
      # Buttons the heart page offers, the plain set of a page that only shows something
      # @return [Integer]
      SHADOW_PAGE_CTRL_STATE = 13
      # Buttons offered while a locked heart browses its moves, the set of the engine that leaves
      # nothing but Cancel, since the move it points at can neither be picked up nor put down
      # @return [Integer]
      LOCKED_MOVES_CTRL_STATE = 5

      private

      # Create the various UI
      def create_uis
        super
        @uis << UI::Summary_Shadow.new(@viewport)
      end

      # Tell if a UI page is available for the current creature
      # @param ui [SpriteStack] the UI page to check
      # @return [Boolean]
      def ui_available?(ui)
        return @pokemon&.shadow? == true if ui.is_a?(UI::Summary_Shadow)

        return super
      end

      # Retrieve the ID state of the ctrl button
      # @note The scene asks for it before it holds any page, hence the safe navigation on the list
      # @return [Integer] a number sent to @base_ui.mode to choose the texts to show
      def ctrl_id_state
        return super unless @uis&.at(@index).is_a?(UI::Summary_Shadow)

        return SHADOW_PAGE_CTRL_STATE
      end

      # Retrieve the ID state for the moves page
      # @return [Integer]
      def ctrl_id_state_moves_page
        return super unless @selecting_move && @pokemon&.shadow?

        return LOCKED_MOVES_CTRL_STATE
      end

      # Update the inputs in view mode
      # @note The engine dispatches inputs page by page and stops at its own last one, so the heart page would answer to nothing
      def update_inputs_view
        return super unless @uis&.at(@index).is_a?(UI::Summary_Shadow)

        update_inputs_basic
        return true
      end

      # Update the Pokemon shown in the UIs
      def update_pokemon
        super
        leave_unavailable_page(1)
      end

      # Action performed when the player press on the [<] button with the mouse
      def mouse_left
        super
        leave_unavailable_page(-1)
      end

      # Action performed when the player press on the [>] button with the mouse
      def mouse_right
        super
        leave_unavailable_page(1)
      end

      # Walk off a page the creature on screen cannot show. The engine only does this when the player turns a
      # page with the keys, so switching creature or clicking an arrow could otherwise land on the heart page
      # of a creature that has no heart.
      # @param direction [Integer] way to walk, 1 forwards and -1 backwards
      def leave_unavailable_page(direction)
        return unless @uis
        return if ui_available?(@uis[@index])

        until ui_available?(@uis[@index])
          @index += direction
          @index = 0 if @index > LAST_STATE
          @index = LAST_STATE if @index < 0
        end
        update_ui_visibility
      end
    end

    prepend SummaryShadowPatch
  end
end
