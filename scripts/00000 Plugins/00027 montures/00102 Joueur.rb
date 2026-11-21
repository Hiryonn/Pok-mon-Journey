# Montures : le joueur sur sa monture (sprite, vitesse, Pokémon qui suit, eau, vélo, changement de carte, rencontres)
module Montures
  module_function

  # @return [Hash, nil] monture du joueur
  def current
    id = $user_data && $user_data[:pj_montures] && $user_data[:pj_montures]['riding']
    return id ? mount(id) : nil
  end

  def riding?
    return !current.nil?
  end

  # Le joueur peut monter ici
  # @return [Boolean]
  def allowed_here?
    switch = setting('block_switch').to_i
    return false if switch > 0 && $game_switches[switch]
    return true unless setting('outdoor_only')

    return $game_switches[Yuki::Sw::Env_CanFly] || $game_switches[Yuki::Sw::Env_CanDig] || $game_player.surfing?
  end

  # Raison pour laquelle on ne peut pas monter (nil = possible)
  # @param mount [Hash]
  # @return [String, nil]
  def refusal(mount)
    player = $game_player
    return t('Impossible d’appeler une monture ici.', "You can't call a mount here.") unless allowed_here?
    if player.surfing?
      return t("#{name(mount)} ne sait pas nager.", "#{name(mount)} can't swim.") unless water?(mount)
    elsif !land?(mount)
      return t("#{name(mount)} ne peut se déplacer que sur l’eau.", "#{name(mount)} can only move on water.")
    end
    return t('Impossible de faire ça maintenant.', "You can't do that now.") if player.cycling? || player.moving? || player.jumping?

    return nil
  end

  # Monte sur une monture (sans message)
  # @param mount [Hash]
  # @param cry [Boolean] cri de la monture
  def ride(mount, cry: false)
    return false unless mount

    store = data
    store['riding'] = mount['id']
    store['last'] = mount['id']
    store['land'] = mount['id'] if land?(mount)
    Yuki::FollowMe.smart_disable
    play_cry(mount) if cry && setting('cry_on_call')
    player = $game_player
    player.pj_refresh_ride
    $game_map.autoplay unless player.surfing?
    return true
  end

  # Descend de la monture (sans message)
  def dismount
    store = data
    return false unless store['riding']

    store['riding'] = nil
    player = $game_player
    Yuki::FollowMe.smart_enable unless player.surfing? || player.cycling?
    player.pj_refresh_ride
    $game_map.autoplay unless player.surfing?
    return true
  end

  # Monte, ou change de monture, en vérifiant que c'est possible (messages dans la scène donnée)
  # @param mount [Hash]
  # @return [String, nil] message d'erreur
  def call(mount)
    return t('Cette monture n’est pas disponible.', 'This mount is not available.') unless mount && unlocked?(mount['id'])
    return nil if current && current['id'] == mount['id']

    error = refusal(mount)
    return error if error

    ride(mount, cry: true)
    return nil
  end

  # Descend si possible
  # @return [String, nil] message d'erreur
  def leave
    return t('Impossible de descendre sur l’eau.', "You can't get off on water.") if $game_player.surfing?

    dismount
    return nil
  end

  def play_cry(mount)
    pkmn = pokemon(mount)
    Audio.se_play(pkmn.cry) if pkmn && pkmn.cry && !pkmn.cry.empty?
  rescue StandardError
    nil
  end

  # Musique sur la monture
  # @return [RPG::AudioFile, nil]
  def ride_bgm
    mount = current
    return nil unless mount && !$game_player.surfing?

    name = mount['bgm'].to_s
    name = setting('ride_bgm').to_s if name.empty?
    return nil if name.empty?

    return RPG::AudioFile.new(name, 100, 100)
  end

  # Après un changement de carte (ou un Vol) : on descend là où c'est interdit, monture de terre hors de l'eau
  def check_terrain
    mount = current
    return unless mount

    player = $game_player
    if !allowed_here?
      data['riding'] = nil
      Yuki::FollowMe.smart_enable unless player.surfing? || player.cycling?
    elsif !player.surfing? && !land?(mount)
      land = mount(data['land'])
      if land && unlocked?(land['id'])
        data['riding'] = land['id']
      else
        data['riding'] = nil
        Yuki::FollowMe.smart_enable
      end
    end
    Yuki::FollowMe.smart_disable if riding?
    player.pj_refresh_ride
  rescue StandardError => e
    log_error("Montures : #{e.message}") if respond_to?(:log_error, true)
  end

  # Le joueur quitte l'eau : monture de terre (ou à pied)
  def after_water
    store = data
    back = store.delete('back')
    mount = current
    return if mount && land?(mount)

    land = mount(store['land'])
    if back && land && unlocked?(land['id']) && setting('auto_switch')
      ride(land)
    elsif mount
      dismount
    end
  end
end

class Game_Player
  module MonturesPlayer
    # Redessine le joueur (monture ou à pied)
    def pj_refresh_ride
      update_move_parameter(@state || :walking)
      update_appearance(@pattern || 0)
    end

    def update_appearance(forced_pattern = 0)
      mount = Montures.current
      return super unless mount && @charset_base && Montures::RIDE_STATES.include?(@state)

      sprite = Montures.charset(mount)
      return super unless sprite

      set_appearance(sprite)
      @pattern = forced_pattern
      update_pattern_state
      return true
    end

    def update_move_parameter(state)
      super
      mount = Montures.current
      return unless mount && Montures::RIDE_STATES.include?(state)

      speed = mount['speed'].to_i.clamp(1, 6)
      speed += 1 if mount['gallop'] && %i[running swamp_running].include?(state)
      @move_speed = speed.clamp(1, 6)
      next_event_follower&.move_speed = @move_speed
    end

    # Sur l'eau avec la monture choisie par l'évent du Surf (ou à pied si c'est un Pokémon de l'équipe)
    def enter_in_surfing_state
      store = Montures.data
      mount = Montures.take_pending(:surf)
      riding = Montures.current
      store['back'] = !riding.nil? && Montures.land?(riding) unless @state == :surfing
      if mount
        Montures.ride(mount) unless riding && riding['id'] == mount['id']
      elsif riding && !Montures.water?(riding)
        store['riding'] = nil
      end
      super
    end

    # Retour sur la terre ferme : monture de terre, ou à pied
    def leave_surfing_state
      super
      Montures.after_water
      Yuki::FollowMe.smart_disable if Montures.riding?
      update_appearance(@pattern || 0)
    end

    # Vélo : on descend d'abord
    def enter_in_cycling_state
      Montures.data['riding'] = nil if Montures.riding?
      super
    end

    def enter_in_acro_bike_state
      Montures.data['riding'] = nil if Montures.riding?
      super
    end
  end
  prepend MonturesPlayer
end

class Game_Map
  module MonturesBgm
    def cycling_bgm
      return super || Montures.ride_bgm
    end

    def autoplay_bgm?
      return super || !Montures.ride_bgm.nil?
    end
  end
  prepend MonturesBgm
end

class Scene_Map
  module MonturesTransfer
    private

    # Arrivée sur une carte où l'on ne peut pas monter : le joueur descend
    def transfer_player_end(transition_sprite)
      Montures.check_terrain
      super
    end
  end
  prepend MonturesTransfer
end

module PFM
  class Wild_Battle
    module MonturesEncounters
      # Moins de rencontres sur certaines montures
      def update_encounter_count
        mount = Montures.current
        rate = mount ? mount['encounters'].to_i : 100
        return if rate < 100 && rand(100) >= rate

        super
      end
    end
    prepend MonturesEncounters
  end
end
