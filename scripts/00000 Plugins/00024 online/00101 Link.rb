# encoding: utf-8
# Jeu en ligne : liaison réseau (serveur relais ou connexion directe).
# Une « liaison » (Link) échange des messages JSON (une ligne par message) avec UN autre joueur. Un thread lit la socket et
# range les évènements dans une file ; le jeu les récupère avec #poll (jamais de blocage dans la boucle principale).
# Évènements renvoyés par #poll (Hash) :
#   { 't' => 'room', 'code' => 'ABCDE' }       salon créé (mode serveur) : le code est à donner à l'autre joueur
#   { 't' => 'ready', 'peer' => { 'id', 'name' }, 'role' => 'host'|'guest' }  les deux joueurs sont connectés
#   { 't' => 'data', 'data' => Hash }          message de l'autre joueur
#   { 't' => 'closed', 'why' => String }       liaison terminée (l'autre est parti, erreur réseau, délai dépassé…)
require 'socket'
require 'json'

module Online
  class Link
    # @return [Symbol] :idle, :connecting, :waiting (salon ouvert), :ready, :closed
    attr_reader :state
    # @return [Hash, nil] l'autre joueur { 'id', 'name' }
    attr_reader :peer
    # @return [String, nil] 'host' (a créé le salon / hébergé) ou 'guest'
    attr_reader :role
    # @return [String, nil] code du salon (mode serveur)
    attr_reader :code
    # @return [String, nil] dernière erreur lisible
    attr_reader :error

    def initialize
      @state = :idle
      @queue = Queue.new
      @inbox = []
      @code = nil
      @write_lock = Mutex.new
      @socket = nil
      @thread = nil
      @peer = nil
      @role = nil
      @error = nil
    end

    def ready?
      return @state == :ready
    end

    def closed?
      return @state == :closed
    end

    # @return [Array<Hash>] évènements reçus depuis le dernier appel
    def poll
      refresh
      events = @inbox
      @inbox = []
      return events
    end

    # Applique les évènements reçus sans les consommer (ils restent disponibles pour poll)
    def refresh
      until @queue.empty?
        event = @queue.pop(true)
        apply(event)
        @inbox << event
      end
    rescue ThreadError
      nil
    end

    # Envoie un message à l'autre joueur
    # @param data [Hash]
    def send_data(data)
      return false unless ready?

      return write('t' => 'relay', 'data' => data)
    end

    def close
      return if @state == :closed

      @state = :closed
      begin
        @socket&.close
      rescue StandardError
        nil
      end
      @keepalive&.kill
      @thread&.kill unless @thread == Thread.current
    end

    private

    def apply(event)
      case event['t']
      when 'ready'
        @peer = event['peer']
        @role = event['role'].to_s
        @state = :ready
      when 'closed'
        @error ||= event['why']
        @state = :closed
      when 'room'
        @code = event['code']
        @state = :waiting
      end
    end

    def push(event)
      @queue << event
    end

    # Écrit une ligne JSON ; false si la connexion est perdue
    def write(message)
      line = JSON.generate(message)
      return false if line.bytesize > MAX_LINE

      @write_lock.synchronize { @socket.write(line + "\n") }
      return true
    rescue StandardError => e
      push('t' => 'closed', 'why' => "write: #{e.class}")
      return false
    end

    # Lit une ligne JSON (Hash) ou nil si fin de flux ; lève une erreur si la ligne est trop longue ou invalide
    def read_message
      line = @socket.gets("\n", MAX_LINE + 1)
      return nil if line.nil?
      raise 'message trop long' if line.bytesize > MAX_LINE

      data = JSON.parse(line, max_nesting: 24)
      raise 'message invalide' unless data.is_a?(Hash)

      return data
    end

    def open_socket(host, port)
      timeout = Online.setting('connect_timeout').to_f
      timeout = 6.0 if timeout <= 0
      @socket = Socket.tcp(host, port, connect_timeout: timeout)
      @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
    end

    def run_thread(&block)
      @thread = Thread.new do
        begin
          block.call
        rescue StandardError => e
          push('t' => 'closed', 'why' => e.message.to_s[0, 80])
        end
      end
      @thread.report_on_exception = false if @thread.respond_to?(:report_on_exception=)
    end
  end

  # Liaison via le serveur relais (tools/online-server)
  class ServerLink < Link
    # @param host [String]
    # @param port [Integer]
    # @param name [String] pseudo
    # @param account [Hash] { 'id', 'token' } (renseigné par le serveur à la première connexion)
    def initialize(host, port, name, account)
      super()
      @host = host
      @port = port
      @name = name
      @account = account
      @pending = nil
    end

    # Crée un salon ; l'évènement 'room' donne le code
    def create_room(kind)
      @pending = { 't' => 'room_create', 'kind' => kind.to_s }
      connect
    end

    # Rejoint le salon d'un autre joueur
    def join_room(code)
      @pending = { 't' => 'room_join', 'code' => code.to_s.upcase.gsub(/[^A-Z0-9]/, '')[0, 8] }
      connect
    end

    # Connexion « sociale » (profil, amis, classements) : pas de salon, la liaison reste ouverte
    def open_social
      @social = true
      @pending = nil
      connect
    end

    # @return [Boolean] le serveur a accepté la connexion
    def welcomed?
      return @welcomed ? true : false
    end

    # Envoie une requête (la réponse arrive comme évènement 't' => 'resp')
    def request(message)
      return write(message)
    end

    # Connexion TCP, chiffrée (TLS) si le réglage « server_tls » est actif
    def open_socket(host, port)
      super
      return unless Online.setting('server_tls')

      require 'openssl'
      context = OpenSSL::SSL::SSLContext.new
      context.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER)
      ssl = OpenSSL::SSL::SSLSocket.new(@socket, context)
      ssl.hostname = host.to_s
      ssl.sync_close = true
      ssl.connect
      ssl.post_connection_check(host.to_s)
      @socket = ssl
    rescue LoadError
      raise 'TLS indisponible dans ce jeu (openssl manquant)'
    end

    def close
      write('t' => 'room_leave') if @socket && !@socket.closed? && @state != :closed
      super
    rescue StandardError
      super
    end

    private

    def connect
      @state = :connecting
      run_thread do
        open_socket(@host, @port)
        start_keepalive
        write('t' => 'hello', 'v' => PROTOCOL, 'name' => @name, 'id' => @account['id'], 'token' => @account['token'])
        loop do
          message = read_message
          break push('t' => 'closed', 'why' => 'connexion fermée') if message.nil?

          handle(message)
        end
      end
    end

    # Le serveur coupe les connexions silencieuses (90 s) : un ping toutes les 25 s (même pendant un combat)
    def start_keepalive
      @keepalive = Thread.new do
        loop do
          sleep 25
          write('t' => 'ping')
        end
      end
    end

    def handle(message)
      case message['t']
      when 'welcome'
        @account['id'] = message['id']
        @account['token'] = message['token'] if message['token'].is_a?(String)
        @welcomed = true
        push('t' => 'welcome', 'id' => message['id'])
        write(@pending) if @pending
      when 'room'
        push('t' => 'room', 'code' => message['code'].to_s)
      when 'room_ready'
        push('t' => 'ready', 'peer' => sanitize_peer(message['peer']), 'role' => message['role'].to_s)
      when 'relay'
        push('t' => 'data', 'data' => message['data']) if message['data'].is_a?(Hash)
      when 'peer_left', 'room_closed'
        push('t' => 'closed', 'why' => message['why'].to_s)
      when 'profile_ok', 'profile', 'friends', 'friend_ok', 'board', 'friend_notice', 'events', 'event_reward', 'box', 'box_mine', 'box_ok', 'box_inbox', 'base', 'base_ok', 'ghost', 'ghost_gone', 'invite', 'invite_ok'
        push('t' => 'resp', 'm' => message)
      when 'error'
        return push('t' => 'resp', 'm' => message) if @social && @welcomed

        push('t' => 'closed', 'why' => "#{message['code']}: #{message['text']}"[0, 80])
      end
    end

    def sanitize_peer(peer)
      peer = {} unless peer.is_a?(Hash)
      return { 'id' => peer['id'].to_s[0, 16], 'name' => peer['name'].to_s.gsub(/[\u0000-\u001f\u007f]/, '')[0, 16] }
    end
  end

  # Liaison directe entre deux joueurs (sans serveur) : l'un héberge, l'autre se connecte à son adresse IP
  class DirectLink < Link
    # @param name [String] pseudo
    def initialize(name)
      super()
      @name = name
      @server = nil
    end

    # Attend l'autre joueur sur le port donné
    def host(port)
      @state = :waiting
      run_thread do
        @server = TCPServer.new('0.0.0.0', port)
        @socket = @server.accept
        @server.close
        @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
        hello('host')
        listen
      end
    end

    # Se connecte à un hôte
    def join(address, port)
      @state = :connecting
      run_thread do
        open_socket(address.to_s.strip, port)
        hello('guest')
        listen
      end
    end

    def close
      begin
        @server&.close
      rescue StandardError
        nil
      end
      super
    end

    private

    def hello(role)
      @role = role
      write('t' => 'hi', 'v' => PROTOCOL, 'name' => @name)
    end

    def listen
      loop do
        message = read_message
        break push('t' => 'closed', 'why' => 'connexion fermée') if message.nil?

        case message['t']
        when 'hi'
          raise 'version incompatible' unless message['v'] == PROTOCOL

          name = message['name'].to_s.gsub(/[\u0000-\u001f\u007f]/, '')[0, 16]
          push('t' => 'ready', 'peer' => { 'id' => '', 'name' => name }, 'role' => @role)
        when 'relay'
          push('t' => 'data', 'data' => message['data']) if message['data'].is_a?(Hash)
        end
      end
    end
  end
end
