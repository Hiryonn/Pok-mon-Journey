class Interpreter
  # Purify a Shadow Pokemon, then offer the nickname its locked heart refused. The rename screen is
  # the one of the engine, the purification having lifted the refusal just before.
  # @param index_or_pokemon [Integer, PFM::Pokemon] the Pokemon or the index of the Pokemon in the party (0~5)
  # @param num_char [Integer] the number of character the Pokemon can have in its name.
  # @return [Boolean] whether it was purified
  def purify_pokemon(index_or_pokemon, num_char = 12)
    pokemon = index_or_pokemon
    pokemon = $actors[index_or_pokemon] if index_or_pokemon.is_a?(Integer)
    held_experience = pokemon&.purify
    return false unless held_experience

    pour_held_experience(pokemon, held_experience)
    rename_pokemon(pokemon, num_char) if yes_no_choice(PFM::ShadowTexts.creature_message(:purification_nickname, pokemon))

    return true
  end

  # Open the party menu to purify a Shadow Pokemon, then purify the one the player chose. The
  # purification waits for the menu to close, so the rename screen never opens over it.
  # @param id_var [Integer] id of the variable holding the index of the chosen Pokemon
  # @param num_char [Integer] the number of character the Pokemon can have in its name.
  # @return [Boolean] whether a Pokemon was purified
  def purification_menu(id_var = ::Yuki::Var::Party_Menu_Sel, num_char = 12)
    GamePlay.open_party_menu_to_purify_pokemon($actors) { |scene| $game_variables[id_var] = scene.return_data }
    @wait_count = 2
    return false if $game_variables[id_var] < 0

    return purify_pokemon($game_variables[id_var], num_char)
  end

  private

  # Pour the experience a locked heart held through give_exp, the way an event hands experience out,
  # so the levels it crosses teach the moves and set off the evolution they owe.
  # @param pokemon [PFM::Pokemon]
  # @param amount [Integer]
  def pour_held_experience(pokemon, amount)
    return unless amount.positive?

    index = $actors.index(pokemon)
    # A creature purified outside the party has nobody to walk its levels, so it takes the plain sum.
    return pokemon.exp += amount unless index

    give_exp(index, amount)
  end
end
