class Interpreter
  # Closes the rename screen on a Shadow Pokemon, whatever event opens it. The creature refuses the
  # name on its own, so this only spares the player a keyboard whose result would be thrown away.
  module InterpreterShadowRenamePatch
    # Show the rename interface of a Pokemon
    # @param index_or_pokemon [Integer, PFM::Pokemon] the Pokemon or the index of the Pokemon in the party (0~5)
    # @param num_char [Integer] the number of character the Pokemon can have in its name.
    def rename_pokemon(index_or_pokemon, num_char = 12)
      pokemon = index_or_pokemon
      pokemon = $actors[index_or_pokemon] if index_or_pokemon.is_a?(Integer)
      return if pokemon&.shadow?

      return super
    end

    # Show the rename interface of a Pokemon
    # @param index_or_pokemon [Integer, PFM::Pokemon] the Pokemon or the index of the Pokemon in the party (0~5)
    # @param num_char [Integer] the number of character the Pokemon can have in its name.
    def renommer_pokemon(index_or_pokemon, num_char = 12)
      # The engine aliases this to the method above before any prepend, so the alias holds the
      # original body and would open the screen anyway. Redirected rather than repeated.
      return rename_pokemon(index_or_pokemon, num_char)
    end
  end

  prepend InterpreterShadowRenamePatch
end
