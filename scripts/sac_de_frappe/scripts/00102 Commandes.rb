# Sac de frappe : commandes d'évènement (Script)
#
#   sac_de_frappe                       -> 10 coups (réglage rounds), sans récompense ; renvoie le score (nil : arrêté)
#   sac_de_frappe(15)                   -> 15 coups
#   sac_de_frappe(10, min_score: 30, ev: 2)
#       -> 10 coups ; 30 points ou plus : +2 EV dans toutes les stats
#   sac_de_frappe(5, min_score: 22, stats: [:atk], max_iv: true, fainted: true, block_max: true, min_level: 100)
#       -> 5 coups ; 22 points : IV d'Attaque à 31 ; un Pokémon K.O. peut jouer ; refusé s'il est déjà au maximum
#          ou s'il n'est pas niveau 100
#   options : min_score, stats ([:hp, :atk, :dfe, :spd, :ats, :dfs]), ev, iv, max_iv, fainted, block_max, min_level,
#             can_cancel (B arrête), name (titre du bandeau), bag (sac : 'team_flare', 'double', 'plante_2'... voir BAGS),
#             variable: n° (reçoit le score, -1 si arrêté)
#   sac_de_frappe_seance(:attaque)      -> séance réglée dans Data/configs/plugins/sac_de_frappe.json (sessions)
#   score_sac_de_frappe                 -> score de la dernière partie (nil si arrêtée)
#   sac_de_frappe_reussi?               -> la dernière partie a atteint le score minimum
class Interpreter
  # @return [Integer, nil] score (nil : partie arrêtée ou aucun Pokémon choisi)
  def sac_de_frappe(rounds = nil, variable: nil, **options)
    SacDeFrappe.reload if PSDK_CONFIG.debug?
    param = rounds.is_a?(SacDeFrappe::Parameters) ? rounds : SacDeFrappe::Parameters.new(rounds, **options)
    score = SacDeFrappe.play(param, variable: variable)
    @wait_count = 2
    return score
  end
  alias punch_bag sac_de_frappe

  # Séance réglée dans les réglages (sessions)
  def sac_de_frappe_seance(id, variable: nil)
    SacDeFrappe.reload if PSDK_CONFIG.debug?
    param = SacDeFrappe.session(id)
    unless param
      log_error("Sac de frappe : séance #{id} introuvable") if respond_to?(:log_error, true)
      return nil
    end

    score = SacDeFrappe.play(param, variable: variable)
    @wait_count = 2
    return score
  end

  def score_sac_de_frappe
    return SacDeFrappe.last_score
  end

  def sac_de_frappe_reussi?
    return SacDeFrappe.last_success ? true : false
  end
end

module SacDeFrappe
  class << self
    # @return [Integer, nil]
    attr_accessor :last_score
    # @return [Boolean]
    attr_accessor :last_success
  end

  module_function

  # Choix du Pokémon, partie, récompense
  # @param param [Parameters]
  # @return [Integer, nil]
  def play(param, variable: nil)
    self.last_score = nil
    self.last_success = false
    pokemon = choose_pokemon(param)
    score = nil
    if pokemon
      $scene.call_scene(GamePlay::SacDeFrappe, pokemon, param.rounds, param.can_cancel, param.name, param.bag) { |scene| score = scene.result }
      if score && score >= param.min_score.to_i
        self.last_success = true
        give_reward(pokemon, param).each { |message| $scene.display_message(message) } if param.reward?
      elsif score && param.reward?
        $scene.display_message(t("Il fallait #{param.min_score} points... Réessaie !", "You needed #{param.min_score} points... Try again!"))
      end
    end
    self.last_score = score
    $game_variables[variable] = score || -1 if variable
    return score
  end

  # Menu de l'équipe ; un Pokémon refusé est expliqué et on recommence (B : rien)
  # @return [PFM::Pokemon, nil]
  def choose_pokemon(param)
    loop do
      index = -1
      $scene.call_scene(GamePlay::Party_Menu, $actors, :map) { |scene| index = scene.return_data }
      return nil if index.nil? || index < 0

      pokemon = $actors[index]
      return nil unless pokemon

      reason = refusal(pokemon, param)
      return pokemon unless reason

      $scene.display_message(reason)
    end
  end
end
