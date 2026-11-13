# Quel est ce Pokémon ? : commandes d'évènement (Script)
#
#   quel_est_ce_pokemon                 -> lance le mini-jeu du jour (variable des réglages de Studio)
#   quel_est_ce_pokemon(variable: 12)   -> la variable reçoit 1 (trouvé), 2 (raté) ou 3 (déjà joué aujourd'hui)
#   quel_pokemon_joue_aujourdhui?       -> true si le joueur a déjà joué aujourd'hui
#   quel_pokemon_serie                  -> jours trouvés d'affilée
class Interpreter
  # @return [Integer] 1 trouvé, 2 raté, 3 déjà joué
  def quel_est_ce_pokemon(variable: nil)
    result = QuelPokemon::ALREADY
    $scene.call_scene(GamePlay::QuelPokemon) { |scene| result = scene.result }
    variable ||= QuelPokemon.config[:variable].to_i
    $game_variables[variable] = result if variable.to_i > 0
    @wait_count = 2
    return result
  end
  alias whos_that_pokemon quel_est_ce_pokemon

  def quel_pokemon_joue_aujourdhui?
    return QuelPokemon.played_today?
  end

  def quel_pokemon_serie
    return QuelPokemon.save_data[:streak].to_i
  end
end
