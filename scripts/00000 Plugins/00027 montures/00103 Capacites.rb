# Montures : pouvoirs (CS des évents communs de PSDK, Surf au contact, Vol, Flair)
#
# Les évents communs des CS (Surf, Force, Éclate-Roc, Coupe, Cascade, Siphon, Plongée, Escalade, Coup d'Boule, Flash,
# Vol…) cherchent un Pokémon de l'équipe qui connaît la capacité. Leurs commandes Script sont relues au lancement :
#   party.has_skill?(:x)                   -> Montures.has_skill?(:x)        (équipe ou monture)
#   pokemon_index(:has_skill?, :x, true)   -> Montures.skill_index(self, :x) (place dans l'équipe, ou la monture)
#   $actors[index]                         -> Montures.skill_user(index)     (Pokémon de l'équipe ou de la monture)
# Les évents gardent leurs messages et leurs choix ; c'est la monture qui agit (son nom dans les messages, son cri ou
# le bandeau des CS selon le réglage hm_animation).
# Sur une monture, entrer dans l'eau appelle directement une monture d'eau (réglage auto_switch, ou ask_on_contact
# désactivé : sans question même à pied).
module Montures
  # Place « monture » renvoyée par skill_index
  MOUNT_INDEX = -42

  module_function

  # @param skill [Symbol, Integer]
  # @return [Boolean] un Pokémon de l'équipe ou une monture peut utiliser la capacité
  def has_skill?(skill)
    return true if PFM.game_state.has_skill?(skill)

    power = power_of_skill(skill)
    return power && !mount_for(power).nil? ? true : false
  end

  # @param interpreter [Interpreter]
  # @param skill [Symbol, Integer]
  # @return [Integer] place du Pokémon de l'équipe, ou MOUNT_INDEX
  def skill_index(interpreter, skill)
    selected = $game_variables[Yuki::Var::Party_Menu_Sel].to_i
    return selected if selected >= 0

    power = power_of_skill(skill)
    mount = power && mount_for(power)
    index = PFM.game_state.has_skill?(skill, true)
    index = nil unless index.is_a?(Integer)
    if mount && (setting('prefer_mount') || index.nil?)
      pending[power] = mount
      @skill_user = mount
      return MOUNT_INDEX
    end
    pending.delete(power) if power
    return index || interpreter.pokemon_index(:has_skill?, skill, true)
  end

  # @return [PFM::Pokemon, nil]
  def skill_user(index)
    return $actors[index] unless index == MOUNT_INDEX

    return pokemon(@skill_user)
  end

  # Montures choisies par les évents (pouvoir => monture)
  def pending
    @pending ||= {}
  end

  # @return [Hash, nil] monture choisie pour ce pouvoir (et l'oublie)
  def take_pending(power)
    return pending.delete(power.to_s)
  end

  # Le Pokémon est celui d'une monture
  def mount_pokemon?(pkmn)
    return false unless pkmn.is_a?(PFM::Pokemon) && @pokemon

    return @pokemon.value?(pkmn)
  end

  # --- Réécriture des évents ----------------------------------------------------------------------------------------
  PATTERNS = [
    [/party\.has_skill\?\(/, 'Montures.has_skill?('],
    [/pokemon_index\(\s*:has_skill\?\s*,\s*([^,()]+?)\s*,\s*true\s*\)/, 'Montures.skill_index(self, \1)'],
    [/\$actors\[index\]/, 'Montures.skill_user(index)']
  ].freeze

  # @param list [Array<RPG::EventCommand>]
  # @return [Array<RPG::EventCommand>] liste avec les commandes Script réécrites (la même si rien ne change)
  def patch_list(list)
    @patched ||= {}.compare_by_identity
    return @patched[list] if @patched.key?(list)

    changed = false
    copy = list.map do |command|
      text = script_of(command)
      next command unless text

      new_text = PATTERNS.reduce(text) { |s, (re, rep)| s.gsub(re, rep) }
      next command if new_text == text

      changed = true
      dup = command.clone
      dup.parameters = command.parameters.clone
      dup.parameters[command.code == 111 ? 1 : 0] = new_text
      dup
    end
    return @patched[list] = changed ? copy : list
  rescue StandardError => e
    log_error("Montures : évent (#{e.message})") if respond_to?(:log_error, true)
    return list
  end

  # Texte d'une commande Script (355 / 655) ou d'une condition Script (111)
  def script_of(command)
    params = command.parameters
    return params[0] if [355, 655].include?(command.code) && params[0].is_a?(String)
    return params[1] if command.code == 111 && params[0] == 12 && params[1].is_a?(String)

    return nil
  end

  # Liste à remplacer par un déroulement Ruby (Surf direct sur une monture)
  # @return [Proc, nil]
  def special_flow(list)
    surf = $data_common_events && $data_common_events[Game_CommonEvent::SURF_ENTER]
    return nil unless surf && list.equal?(surf.list)
    return nil if $game_player.surfing? || $game_variables[Yuki::Var::Party_Menu_Sel].to_i >= 0

    mount = mount_for('surf')
    return nil unless mount && allowed_here?
    return nil unless (riding? && setting('auto_switch')) || !setting('ask_on_contact')

    bgm = list.find { |c| c.code == 241 }&.parameters&.first
    return proc { Montures.auto_surf(mount, bgm) }
  end

  # Le joueur entre dans l'eau sur sa monture d'eau
  def auto_surf(mount, bgm)
    player = $game_player
    Yuki::FollowMe.smart_disable
    play_cry(mount) unless current && current['id'] == mount['id']
    $game_system.bgm_play(bgm) if bgm
    pending['surf'] = mount
    player.set_surfing
    player.enter_in_surfing_state
    player.move_forward
  end

  # --- Vol et Flair -------------------------------------------------------------------------------------------------
  def can_fly?
    return $game_switches[Yuki::Sw::Env_CanFly] && !mount_for('fly').nil?
  end

  # Ouvre la carte pour voler (la monture fait l'évent du Vol)
  def fly(mount)
    return t('Impossible de voler ici.', "You can't fly here.") unless $game_switches[Yuki::Sw::Env_CanFly]

    pending['fly'] = mount
    @skill_user = mount
    GamePlay.open_town_map_to_fly(PFM.game_state.env.get_worldmap, pokemon(mount))
    return nil
  end

  # Flair : lance le Cherch'Objet (évent commun de PSDK)
  def search(mount)
    play_cry(mount)
    $game_temp.common_event_id = SEARCH_EVENT
    return nil
  end
end

class Interpreter
  module MonturesEvents
    def setup(list, event_id, block = nil)
      if block.nil? && list.is_a?(Array) && defined?(Montures)
        flow = Montures.special_flow(list)
        return super(nil, event_id, flow) if flow

        list = Montures.patch_list(list)
      end
      super(list, event_id, block)
    end

    # Bandeau des CS : seulement si réglé pour les montures (sinon leur cri)
    def hm_bar_animation_on_map(reason)
      return super unless Montures.mount_pokemon?(reason) && !Montures.setting('hm_animation')

      Audio.se_play(reason.cry) if reason.cry && !reason.cry.empty?
    end
  end
  prepend MonturesEvents
end

# Carte de région : Vol depuis la carte avec une monture qui vole
if defined?(CarteRegion) && CarteRegion.respond_to?(:can_fly_from_map?)
  module CarteRegion
    class << self
      module MonturesFly
        def can_fly_from_map?
          return true if super
          return false unless setting?('fly_from_map')

          return Montures.can_fly?
        rescue StandardError
          return false
        end
      end
      prepend MonturesFly
    end
  end
end
