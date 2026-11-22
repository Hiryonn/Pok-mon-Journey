# Options en plus : sauvegarde automatique
# Quand l'option est activée, la partie est sauvegardée à l'arrivée sur une carte, dès que le joueur est libre
# (aucun évènement, message ni transfert en cours) et au plus une fois toutes les autosave_min_seconds secondes.
module OptionsPlus
  module_function

  # Une carte vient d'être chargée : la sauvegarde sera faite dès que possible
  def autosave_request
    @autosave_pending = true
  end

  # @return [Boolean] si le joueur est libre
  def player_free?
    return false unless $game_player && $game_map && $trainer
    return false if $game_temp.respond_to?(:player_transferring) && $game_temp.player_transferring
    return false if $game_temp.respond_to?(:message_window_showing) && $game_temp.message_window_showing
    return false if $game_system.respond_to?(:map_interpreter) && $game_system.map_interpreter&.running?

    return true
  rescue StandardError
    return false
  end

  # Appelé à chaque image de la carte
  def autosave_tick
    return unless @autosave_pending
    return unless $options.respond_to?(:pj_autosave) && $options.pj_autosave
    return unless player_free?

    @autosave_pending = false
    now = Time.now
    return if @last_autosave && now - @last_autosave < [setting('autosave_min_seconds').to_i, 0].max

    @last_autosave = now
    autosave
  end

  # Sauvegarde dans le fichier de la partie en cours
  def autosave
    if defined?(Save) && Save.respond_to?(:save)
      Save.save
    elsif PFM.game_state.respond_to?(:save)
      PFM.game_state.save
    else
      return log_error('aucune méthode de sauvegarde trouvée (Save.save)')
    end
    sound = setting('autosave_se').to_s
    Audio.se_play(sound) unless sound.empty?
  rescue StandardError => e
    log_error("sauvegarde automatique impossible (#{e.message})")
  end
end

class Game_Map
  module OptionsPlusAutosave
    def setup(map_id)
      result = super
      OptionsPlus.autosave_request
      return result
    end
  end
  prepend OptionsPlusAutosave
end

class Scene_Map
  module OptionsPlusAutosaveTick
    def update
      super
      OptionsPlus.autosave_tick
    end
  end
  prepend OptionsPlusAutosaveTick
end
