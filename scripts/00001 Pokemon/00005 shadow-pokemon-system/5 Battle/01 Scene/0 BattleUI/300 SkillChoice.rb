module BattleUI
  class SkillChoice < GenericChoice
    # Set the choice as calling out to the creature instead of using a move
    # @return [Boolean] if the operation was a success
    def choice_call
      @result = :call
      return true
    end

    # Tell if the player chose to call out to the creature
    # @return [Boolean]
    def call_requested?
      return @result == :call
    end

    # Button offering to call out to a Shadow Pokemon, sitting where the Mega Evolution button sits since the
    # two mechanics never meet on the same creature.
    class CallButton < UI::SpriteStack
      # Create a new call button
      # @param viewport [Viewport]
      # @param scene [Battle::Scene]
      def initialize(viewport, scene)
        super(viewport)
        @scene = scene
        create_sprites
      end

      # Set the data of the button
      # @param pokemon [PFM::PokemonBattler]
      def data=(pokemon)
        super
        self.visible = true
      end

      # Update the call button content
      def refresh
        @text.text = PFM::ShadowTexts.message(:call_button)
      end

      # Set the visibility of the button
      # @param visible [Boolean]
      def visible=(visible)
        super(visible && offered?)
      end

      # Tell if the creature on the field is one the player can call out to.
      # @return [Boolean]
      def offered?
        return @data.is_a?(PFM::PokemonBattler) && @data.shadow?
      end

      private

      def create_sprites
        @background = add_background('battle/shadow/button_call')
        @text = add_text(23, 9, 0, 16, nil.to_s, color: 10)
        add_sprite(3, 9, NO_INITIAL_IMAGE, :Y, type: UI::KeyShortcut)
      end
    end

    class SubChoice < UI::SpriteStack
      # Puts the call button on the Y key, which the Mega Evolution holds otherwise.
      module SubChoiceShadowCallPatch
        # Reset the sub choice
        def reset
          super
          @call_button.refresh
        end

        private

        # Action triggered when pressing Y
        def action_y
          return super unless @call_button.visible

          @choice.choice_call
          play_decision_se
        end

        def create_special_buttons
          super
          # Qualified because a prepended module does not see the constants the class inherits
          @call_button = add_sprite(2, 183, UI::SpriteStack::NO_INITIAL_IMAGE, @scene, type: CallButton)
        end
      end

      # Opens the description of a locked slot, which the engine skips because no move sits there.
      module SubChoiceShadowDescriptionPatch
        private

        # Action triggered when pressing X
        def action_x
          move = PFM::ShadowMovesetView.wrap(@choice.pokemon).moveset[@choice.index]
          return super if move.nil? || !move.is_a?(PFM::LockedMove)

          @move_description.data = move
          @move_description.show
          @choice.hide
          @scene.visual.show_info_bars(bank: 0)
          play_decision_se
        end
      end

      prepend SubChoiceShadowCallPatch
      prepend SubChoiceShadowDescriptionPatch
    end

    class MoveButton < UI::SpriteStack
      # Draws a locked slot the way the engine draws a move, the descriptor answering the little of
      # a move this button reads.
      module MoveButtonShadowPatch
        # Set the data
        # @param pokemon [PFM::PokemonBattler]
        def data=(pokemon)
          super(PFM::ShadowMovesetView.wrap(pokemon))
        end
      end

      prepend MoveButtonShadowPatch
    end

    class MoveInfo < UI::SpriteStack
      # Shows the unknown power point count of a locked slot instead of leaving the box empty.
      module MoveInfoShadowPatch
        # Set the move shown by the UI
        # @param pokemon [PFM::PokemonBattler]
        def data=(pokemon)
          super(PFM::ShadowMovesetView.wrap(pokemon))
        end
      end

      prepend MoveInfoShadowPatch
    end

    private

    # Set the choice of the move to use
    # @param index [Integer]
    # @return [Boolean]
    def choice_move(index = @index)
      return false if locked_slot?(index)

      return super
    end

    # Show the move choice failure
    # @param index [Integer]
    def show_move_choice_failure(index = @index)
      return if locked_slot?(index)

      return super
    end

    # Tell if the button under the cursor stands for a move the locked heart still holds back, shown so the
    # player knows a move is on its way but never usable.
    # @param index [Integer]
    # @return [Boolean]
    def locked_slot?(index)
      return @pokemon.shadow? && index >= @pokemon.moveset.size
    end
  end
end
