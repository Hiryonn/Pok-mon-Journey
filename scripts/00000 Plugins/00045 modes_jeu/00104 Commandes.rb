# Modes de jeu : commandes d'évènement (Script)
#
#   choisir_modes          -> menu de début de partie : difficulté (Normal / Difficile / Extrême), Nuzlocke, Randomizer
#                             (fixé pour toute la partie, une seule fois)
#   mode_difficile?  mode_extreme?  mode_nuzlocke?  mode_randomizer?   -> true / false
#   plafond_niveau         -> plafond de niveau actuel (nil hors Difficile)
#   resume_modes           -> texte des modes choisis
#   ouvrir_cimetiere       -> liste des Pokémon tombés (Nuzlocke)
#   nuzlocke_ressusciter   -> choisir un Pokémon du cimetière et le ranimer (à mettre dans l'évènement commun de l'objet
#                             « nuzlocke_revive » ; l'objet est consommé par PSDK si l'évènement le demande)
class Interpreter
  def choisir_modes
    return false if ModesJeu.chosen? && ModesJeu.setting('lock_choice')

    loop do
      diff = pj_modes_ask(:ask_diff, %i[normal hard extreme])
      nuz = pj_modes_ask(:ask_nuz, %i[no yes]) == 1
      rand = pj_modes_ask(:ask_rand, %i[no yes]) == 1
      ModesJeu.choose(hard: diff == 1, extreme: diff == 2, nuzlocke: nuz, randomizer: rand)
      next_ok = pj_modes_ask_text("#{ModesJeu.summary}\n#{ModesJeu.text(:confirm)}", %i[yes no]) == 0
      return true if next_ok

      ModesJeu.state['chosen'] = false
    end
  end

  def mode_difficile?
    return ModesJeu.hard?
  end

  def mode_extreme?
    return ModesJeu.extreme?
  end

  def mode_nuzlocke?
    return ModesJeu.nuzlocke?
  end

  def mode_randomizer?
    return ModesJeu.randomizer?
  end

  def plafond_niveau
    return ModesJeu.level_cap
  end

  def resume_modes
    return ModesJeu.summary
  end

  def ouvrir_cimetiere
    graves = ModesJeu::Nuzlocke.graves
    return $scene.display_message_and_wait(ModesJeu.text(:grave_empty)) if graves.empty?

    lines = graves.map { |pokemon| "#{pokemon.given_name} (#{pokemon.name} N.#{pokemon.level})" }
    $scene.display_message_and_wait(lines.join("\n"))
    return true
  end

  def nuzlocke_ressusciter
    graves = ModesJeu::Nuzlocke.graves
    return $scene.display_message_and_wait(ModesJeu.text(:grave_empty)) && false if graves.empty?

    names = graves.map { |pokemon| "#{pokemon.given_name} N.#{pokemon.level}" }
    index = $scene.display_message(ModesJeu.text(:grave_pick), 1, *names, ModesJeu.text(:grave_cancel)).to_i
    return false if index >= graves.size

    pokemon = graves[index]
    return false unless ModesJeu::Nuzlocke.revive(index)

    $scene.display_message_and_wait(ModesJeu.text(:grave_done, pokemon.given_name))
    return true
  end

  private

  def pj_modes_ask(question, keys)
    return pj_modes_ask_text(ModesJeu.text(question), keys)
  end

  def pj_modes_ask_text(text, keys)
    index = $scene.display_message(text, 1, *keys.map { |key| ModesJeu.text(key) }).to_i
    return index.clamp(0, keys.size - 1)
  end
end
