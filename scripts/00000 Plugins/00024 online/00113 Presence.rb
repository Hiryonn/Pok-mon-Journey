# encoding: utf-8
# Jeu en ligne — étape 6 : « fantômes » sur la carte. Tes amis connectés qui se trouvent sur la même carte apparaissent comme des
# silhouettes (sans collision) ; on leur parle avec la touche d'action pour les défier, échanger ou visiter leur base.
# Les invitations reçues (défi, échange, combat) s'affichent dès que le joueur n'est pas occupé.
# ATTENTION : l'affichage s'appuie sur des évènements de carte réservés à l'avance (comme le plugin overworld_pokemon). Tout est protégé :
# en cas d'incompatibilité, les fantômes sont désactivés (message dans le log) mais le reste du jeu en ligne continue de fonctionner.
module Online
  module Presence
    SLOT_BASE = 9100
    INTERVAL = 0.15
    INVITE_TTL = 60

    module_function

    # @return [Boolean] le joueur a choisi d'être visible (et de voir ses amis)
    def enabled?
      return false unless Online.enabled? && Online.server? && Online.setting('ghosts')

      choice = Online.state['ghosts_on']
      return choice.nil? ? Online.setting('ghosts_default') == true : choice == true
    end

    def set_enabled(value)
      Online.state['ghosts_on'] = value ? true : false
      stop unless value
    end

    # @return [Integer] nombre d'évènements réservés par carte
    def slot_count
      return Online.setting('ghost_slots').to_i.clamp(1, 20)
    end

    def reset
      @link = nil
      @ghosts = {}
      @invites = []
      @last_sent = nil
      @last_at = 0
      @retry_at = 0
      @failed = false
    end
    reset

    # @return [Hash] fantômes connus (id → données)
    def ghosts
      return @ghosts
    end

    def stop
      return unless @link

      @link.request('t' => 'presence_off') if @link.welcomed?
      @link.close
      @link = nil
      @ghosts.clear
      @last_sent = nil
      refresh_slots
    end

    # Appelé à chaque image de la carte
    def tick
      return if @failed

      unless enabled?
        stop if @link
        return
      end
      connect unless @link
      return unless @link

      @link.refresh
      handle_events(@link.poll)
      if @link.closed?
        @link = nil
        @retry_at = Time.now.to_f + 30
        @ghosts.clear
        refresh_slots
        return
      end
      send_position if @link.welcomed?
      expire_ghosts
      show_invite
    rescue StandardError, NoMethodError => e
      @failed = true
      log_error("En ligne (fantômes) : #{e.class} #{e.message}") if respond_to?(:log_error, true)
      stop rescue nil
    end

    def connect
      return if Time.now.to_f < @retry_at

      @link = Online::ServerLink.new(Online.setting('server_host').to_s, Online.setting('server_port').to_i, Online.nickname, Online::Game.account)
      @link.open_social
      @listening = false
    end

    def handle_events(events)
      events.each do |event|
        next unless event['t'] == 'resp'

        message = event['m']
        case message['t']
        when 'ghost' then add_ghost(message['ghost'])
        when 'ghost_gone' then @ghosts.delete(message['id'].to_s)
        when 'invite' then queue_invite(message)
        end
      end
      refresh_slots unless events.empty?
    end

    def add_ghost(data)
      return unless data.is_a?(Hash) && data['id'].is_a?(String)

      @ghosts[data['id']] = { 'id' => data['id'], 'name' => data['name'].to_s[0, 16], 'map' => data['map'].to_i, 'x' => data['x'].to_i, 'y' => data['y'].to_i,
                              'dir' => data['dir'].to_i, 'skin' => safe_skin(data['skin']), 'seen' => Time.now.to_f }
    end

    # @return [String] nom de sprite de personnage connu (sinon vide : le fantôme prend l'apparence par défaut)
    def safe_skin(name)
      name = name.to_s
      return '' unless name =~ /\A[A-Za-z0-9_\- ]{1,40}\z/

      @skins ||= {}
      @skins[name] = File.exist?("graphics/characters/#{name}.png") unless @skins.key?(name)
      return @skins[name] ? name : ''
    end

    def expire_ghosts
      cutoff = Time.now.to_f - 90
      removed = @ghosts.reject! { |_id, data| data['seen'] < cutoff }
      refresh_slots if removed
    end

    # --- ma position -----------------------------------------------------------------------------------------------
    def send_position
      unless @listening
        @link.request('t' => 'listen', 'on' => true)
        @listening = true
      end
      return unless $game_player && $game_map

      now = Time.now.to_f
      pos = [$game_map.map_id, $game_player.x, $game_player.y, $game_player.direction]
      return if pos == @last_sent || now - @last_at < INTERVAL

      @last_sent = pos
      @last_at = now
      skin = $game_player.respond_to?(:character_name) ? $game_player.character_name.to_s : ''
      @link.request('t' => 'presence', 'map' => pos[0], 'x' => pos[1], 'y' => pos[2], 'dir' => pos[3], 'skin' => skin)
    end

    # --- évènements de carte réservés -------------------------------------------------------------------------------
    # Ajoute les évènements « fantôme » à la carte qui vient de s'installer
    def setup_slots(map)
      return unless enabled?

      slot_count.times do |index|
        rpg = RPG::Event.new(0, 0)
        rpg.id = SLOT_BASE + index
        rpg.name = 'fantome_en_ligne'
        page = rpg.pages[0]
        page.graphic.character_name = ''
        page.trigger = 0
        page.list = [RPG::EventCommand.new(355, 0, ["Online::Presence.talk(#{index})"]), RPG::EventCommand.new(0, 0, [])]
        map.events[rpg.id] = Game_OnlineGhost.new(map.map_id, rpg)
      end
    rescue StandardError, NoMethodError => e
      @failed = true
      log_error("En ligne (fantômes) : #{e.class} #{e.message}") if respond_to?(:log_error, true)
    end

    # Place chaque fantôme de la carte actuelle dans un évènement réservé
    def refresh_slots
      return unless $game_map

      here = @ghosts.values.select { |ghost| ghost['map'] == $game_map.map_id }.first(slot_count)
      slot_count.times do |index|
        event = $game_map.events[SLOT_BASE + index]
        next unless event.is_a?(Game_OnlineGhost)

        event.show_ghost(here[index])
      end
    end

    # @return [Hash, nil] fantôme occupant l'évènement réservé n°index
    def ghost_at(index)
      return @ghosts.values.select { |ghost| ghost['map'] == $game_map.map_id }.first(slot_count)[index]
    end

    # --- parler à un fantôme (touche d'action) ---------------------------------------------------------------------
    def talk(index)
      ghost = ghost_at(index)
      return unless ghost

      options = [Online.t("Défi d'équipe", 'Team challenge'), Online.t('Combat en temps réel', 'Live battle'), Online.t('Échanger', 'Trade')]
      options << Online.t('Visiter sa base', 'Visit base') if Online::BaseShare.available?
      options << Online.t('Annuler', 'Cancel')
      choice = Online::Game.ask(Online.t("#{ghost['name']}", ghost['name']), *options)
      case choice
      when 0 then Online::Game.duel(invite_to: ghost['id'])
      when 1 then Online::Game.pvp(invite_to: ghost['id'])
      when 2 then Online::Game.trade(invite_to: ghost['id'])
      when 3 then options.size == 5 ? visit(ghost) : nil
      end
    end

    def visit(ghost)
      link = Online::Social.connect(Online::Game.account) { Graphics.update }
      return Online::Game.say(Online.t('Connexion au serveur impossible.', "Couldn't reach the server.")) unless link

      begin
        Online::Game.visit_base(link, ghost)
      ensure
        link.close
      end
    end

    # --- invitations reçues -------------------------------------------------------------------------------------------
    def queue_invite(message)
      return unless %w[trade duel pvp].include?(message['kind']) && message['code'].to_s =~ /\A[A-Z0-9]{3,8}\z/
      return unless message['from'].is_a?(Hash)

      @invites << { 'from' => message['from']['name'].to_s[0, 16], 'kind' => message['kind'], 'code' => message['code'].to_s, 'at' => Time.now.to_f }
    end

    # @return [Boolean] le joueur est occupé (évènement, message, transfert de carte)
    def busy?
      return true if $game_system.respond_to?(:map_interpreter) && $game_system.map_interpreter&.running?
      return true if $game_temp.respond_to?(:message_window_showing) && $game_temp.message_window_showing
      return true if $game_temp.respond_to?(:player_transferring) && $game_temp.player_transferring
      return true if $game_player.respond_to?(:moving?) && $game_player.moving?

      return false
    rescue StandardError
      return true
    end

    def show_invite
      @invites.reject! { |invite| Time.now.to_f - invite['at'] > INVITE_TTL }
      return if @invites.empty? || busy?

      invite = @invites.shift
      what = { 'trade' => Online.t('un échange', 'a trade'), 'duel' => Online.t("un défi d'équipe", 'a team challenge'), 'pvp' => Online.t('un combat en temps réel', 'a live battle') }[invite['kind']]
      return unless Online::Game.ask(Online.t("#{invite['from']} te propose #{what}.", "#{invite['from']} offers #{what}."), Online.t('Accepter', 'Accept'), Online.t('Refuser', 'Decline')) == 0

      case invite['kind']
      when 'trade' then Online::Game.trade(join_code: invite['code'])
      when 'duel' then Online::Game.duel(join_code: invite['code'])
      else Online::Game.pvp(join_code: invite['code'])
      end
    end
  end
end

if defined?(Game_Event)
  # Évènement de carte réservé à un fantôme : traverse tout, change d'apparence et de place sur ordre du réseau
  class Game_OnlineGhost < Game_Event
    def initialize(map_id, event)
      @ghost = nil
      super
      @through = true
      @transparent = true
    end

    # @param data [Hash, nil]
    def show_ghost(data)
      @ghost = data
      apply_ghost
    end

    def refresh
      super
      apply_ghost
    end

    def update
      super
      @through = true
    end

    private

    def apply_ghost
      @through = true
      if @ghost.nil?
        @transparent = true
        return
      end
      skin = @ghost['skin'].to_s
      skin = $game_player.character_name.to_s if skin.empty? && $game_player.respond_to?(:character_name)
      @character_name = skin
      @transparent = false
      @direction = @ghost['dir'].to_i if [2, 4, 6, 8].include?(@ghost['dir'].to_i)
      target = [@ghost['x'], @ghost['y']]
      return if [x, y] == target

      near = (x - target[0]).abs + (y - target[1]).abs == 1 && !moving?
      near ? move_toward_target(target) : moveto(*target)
    end

    def move_toward_target(target)
      dir = if target[0] > x then 6
            elsif target[0] < x then 4
            elsif target[1] > y then 2
            else 8
            end
      move_straight(dir)
    rescue StandardError
      moveto(*target)
    end
  end

  class Game_Map
    module OnlineGhostSetup
      def setup(map_id)
        result = super
        Online::Presence.setup_slots(self)
        return result
      end
    end
    prepend OnlineGhostSetup
  end
end

class Scene_Map
  module OnlinePresenceTick
    def update
      super
      Online::Presence.tick
    end
  end
  prepend OnlinePresenceTick
end

class Interpreter
  # Active ou coupe sa propre visibilité (fantômes) : online_presence(true / false)
  def online_presence(value)
    Online::Presence.set_enabled(value)
  end

  # @return [Boolean] fantômes actifs
  def online_presence?
    return Online::Presence.enabled?
  end

  # @return [Integer] nombre d'amis visibles sur la carte
  def online_joueurs_carte
    return Online::Presence.ghosts.values.count { |ghost| ghost['map'] == $game_map.map_id }
  end
end
