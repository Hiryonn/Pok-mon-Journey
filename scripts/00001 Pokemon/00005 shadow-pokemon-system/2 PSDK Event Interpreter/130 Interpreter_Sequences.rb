class Interpreter
  # Turns down a trade an event offers on a Shadow Pokemon. The sequence hands the creature over on
  # its very first lines, so there is nothing to undo afterwards, only a departure to prevent.
  module InterpreterShadowTradePatch
    # Sequence that perform NPC trade
    # @param index [Integer] index of the Pokemon in the party
    # @param pokemon [PFM::Pokemon] Pokemon that is traded with
    def npc_trade_sequence(index, pokemon)
      return if $actors[index]&.shadow?

      return super
    end
  end

  prepend InterpreterShadowTradePatch
end
