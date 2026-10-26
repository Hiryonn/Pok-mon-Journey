# Script décompilé depuis le bytecode du jeu (Ruby 3.0) — fichier d'origine : RMXP/00000 DebugFeatures.rb
# Les commentaires et la mise en forme d'origine ne sont pas récupérables.

module DebugFeatures
  module GamePlayerLogic
    def update_check_trigger(last_moving)
      if last_moving && !check_event_trigger_here([1, 2]) && !((debug? || $TEST) && (Input::Keyboard.press?(Input::Keyboard::LControl) || Input::Keyboard.press?(Input::Keyboard::RControl)))
        $wild_battle.update_encounter_count
      end

      super
    end
  end

  module FleeHandlerDebug
    def attempt(index)
      if (debug? || $TEST) && (Input::Keyboard.press?(Input::Keyboard::LControl) || Input::Keyboard.press?(Input::Keyboard::RControl))
        @scene.display_message_and_wait("Debug: Guaranteed escape!")
        return :success
      end

      super
    end
  end

  module CatchHandlerDebug
    def pokemon_catch_rate(pokemon, ball)
      if (debug? || $TEST) && (Input::Keyboard.press?(Input::Keyboard::LControl) || Input::Keyboard.press?(Input::Keyboard::RControl))
        return 1000
      end

      super
    end
  end
end

Game_Player.prepend(DebugFeatures::GamePlayerLogic)
Battle::Logic::FleeHandler.prepend(DebugFeatures::FleeHandlerDebug)
Battle::Logic::CatchHandler.prepend(DebugFeatures::CatchHandlerDebug)
