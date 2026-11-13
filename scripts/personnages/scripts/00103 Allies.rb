# Personnages : alliés qui combattent au côté du héros
#
# Un allié est lié à un dresseur de Studio (Données > Dresseurs) : son équipe (toujours soignée) combat avec le héros
# en combat double. Réglages dans Studio (Données > Personnages > Alliés) : combats contre dresseurs, combats sauvages,
# suit le héros sur la carte (son personnage de la carte).
#
# Commandes d'évent (Script) :
#   allie_rejoint('ally_1')   l'allié accompagne le héros (identifiant de Studio, nom ou position : 0 = premier)
#   allie_quitte              l'allié s'en va
#   allie_actuel              identifiant de l'allié (nil si aucun) — condition : allie_actuel == 'ally_1'
#   allie_present?            un allié accompagne le héros
# Les combats lancés avec un allié précis (start_double_trainer_battle_with_friend…) gardent leur allié.
module Personnages
  module_function

  # @return [Hash, nil]
  def current_ally
    id = $user_data && $user_data[:pj_ally]
    return id ? ally(id) : nil
  end

  # @param id [String, Symbol, Integer]
  # @return [Boolean]
  def ally_join(id)
    data = ally(id)
    unless data
      log_error("Personnages : allié #{id.inspect} introuvable") if respond_to?(:log_error, true)
      return false
    end
    $user_data[:pj_ally] = data['id'].to_s
    refresh_follower
    return true
  end

  def ally_leave
    $user_data.delete(:pj_ally)
    refresh_follower
  end

  # Dresseur de Studio de l'allié
  # @param data [Hash]
  # @return [Integer, nil] id du dresseur
  def ally_trainer_id(data)
    trainer = data && data['trainer']
    return nil if trainer.nil? || trainer.to_s.empty?

    return trainer.to_i if trainer.is_a?(Integer) || trainer.to_s.match?(/\A\d+\z/)

    found = data_trainer(trainer.to_sym)
    return found && found.db_symbol != :__undef__ ? found.id : nil
  rescue StandardError
    return nil
  end

  # L'allié suit le héros sur la carte (personnage n°2 du « Follow Me » de PSDK)
  def refresh_follower
    data = current_ally
    actor = $game_actors && $game_actors[2]
    if data && data['follow'] && !data['charset'].to_s.empty? && actor
      actor.set_graphic(data['charset'].to_s, 0, '', 0)
      actor.name = data['name'].to_s unless data['name'].to_s.empty?
      $user_data[:pj_ally_follow] = true
      Yuki::FollowMe.human_count = [Yuki::FollowMe.human_count, 1].max
      Yuki::FollowMe.enabled = true
    elsif $user_data[:pj_ally_follow]
      $user_data.delete(:pj_ally_follow)
      Yuki::FollowMe.human_count = 0
    end
  rescue StandardError => e
    log_error("Personnages : allié sur la carte (#{e.message})") if respond_to?(:log_error, true)
  end

  # Ajoute l'équipe de l'allié au combat (double) s'il le faut
  # @param battle_info [Battle::Logic::BattleInfo]
  def add_ally_to_battle(battle_info)
    data = current_ally
    return unless data && battle_info

    parties = battle_info.parties[0] || []
    return if parties.size != 1 # combat déjà avec un allié (ou sans joueur)

    trainer_battle = battle_info.trainer_battle?
    return if trainer_battle && data['trainer_battles'] == false
    return if !trainer_battle && !data['wild_battles']

    trainer_id = ally_trainer_id(data)
    unless trainer_id
      log_error("Personnages : l'allié #{data['id']} n'a pas de dresseur")
      return
    end

    Battle::Logic::BattleInfo.add_trainer(battle_info, 0, trainer_id)
    name = data['name'].to_s
    battle_info.names[0][-1] = name if !name.empty? && battle_info.names[0]
    battle_info.vs_type = 2 if battle_info.vs_type.to_i < 2
  rescue StandardError => e
    log_error("Personnages : allié en combat (#{e.message})") if respond_to?(:log_error, true)
  end
end

class Scene_Map
  module PJPersonnagesAllies
    def setup_start_battle(klass, battle_info)
      Personnages.add_ally_to_battle(battle_info) if battle_info
      super
    end
  end
  prepend PJPersonnagesAllies
end

class Interpreter
  # @param id [String, Symbol, Integer]
  def allie_rejoint(id)
    return Personnages.ally_join(id)
  end

  def allie_quitte
    Personnages.ally_leave
    return true
  end

  # @return [String, nil]
  def allie_actuel
    return $user_data && $user_data[:pj_ally]
  end

  # @return [Boolean]
  def allie_present?
    return !Personnages.current_ally.nil?
  end
end
