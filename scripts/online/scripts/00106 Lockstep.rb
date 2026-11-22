# encoding: utf-8
# Jeu en ligne — étape 2 : combat en temps réel entre deux joueurs (synchronisation « lockstep »).
# Principe : les deux jeux simulent LE MÊME combat avec la même graine aléatoire ; seules les décisions des joueurs circulent
# (une ligne par tour). Après chaque tour, chacun envoie une empreinte de l'état du combat : si elles diffèrent (désynchronisation),
# le combat est interrompu proprement plutôt que de continuer avec deux versions différentes.
# Cette classe ne connaît pas PSDK : elle gère seulement l'échange (équipes, graine, décisions, empreintes, abandon, délais).
require 'securerandom'
require 'digest'

module Online
  class Lockstep
    ACTION_TYPES = %w[move switch item flee skip].freeze

    # @return [Symbol] :choosing, :waiting_team, :ready, :waiting_seed, :running, :over, :cancelled
    attr_reader :status
    # @return [Array<Hash>, nil] équipes encodées (miennes / adverses)
    attr_reader :mine, :theirs, :peer_battler
    # @return [Integer, nil] graine commune
    attr_reader :seed
    attr_reader :reason
    # @return [Boolean, nil] true : j'ai gagné ; false : j'ai perdu (annoncé par l'adversaire ou par abandon)
    attr_reader :won

    # @param link [Online::Link]
    # @param team_size [Integer]
    # @param level_cap [Integer] 0 : aucun
    # @param banned [Array<String>]
    # @param turn_timeout [Numeric] secondes avant de considérer l'adversaire comme parti
    def initialize(link, team_size: 6, level_cap: 0, banned: [], turn_timeout: 90)
      @link = link
      @team_size = team_size.to_i.clamp(1, 6)
      @level_cap = level_cap.to_i
      @banned = Array(banned).map(&:to_s)
      @turn_timeout = turn_timeout
      @status = :choosing
      @mine = nil
      @theirs = nil
      @seed = nil
      @reason = nil
      @won = nil
      @actions = {}
      @sums = {}
      @my_sums = {}
      @waiting_since = nil
    end

    # Envoie mon équipe
    # @param team [Array<Hash>] Pokémon encodés
    def offer(team)
      return unless @status == :choosing

      @mine = team.first(@team_size)
      @link.send_data('k' => 'pvp', 'a' => 'team', 'team' => @mine, 'cap' => @level_cap, 'battler' => Online.my_battler)
      @status = :waiting_team
      advance
    end

    # @return [String] 'host' ou 'guest'
    def role
      return @link.role.to_s
    end

    # @return [Boolean] c'est moi qui fixe la graine
    def host?
      return role == 'host'
    end

    # Envoie ma décision pour un tour (liste d'actions, une par Pokémon actif)
    # @param turn [Integer]
    # @param actions [Array<Hash>]
    def submit(turn, actions)
      return false unless @status == :running

      clean = self.class.clean_actions(actions)
      return cancel('action invalide') unless clean

      @waiting_since ||= Time.now
      return @link.send_data('k' => 'pvp', 'a' => 'act', 'turn' => turn.to_i, 'acts' => clean)
    end

    # @return [Array<Hash>, nil] décision de l'adversaire pour ce tour (nil : pas encore arrivée)
    def remote_actions(turn)
      return @actions[turn.to_i]
    end

    # Le tour est joué : on envoie l'empreinte de l'état et on la compare avec celle de l'adversaire
    # @param turn [Integer]
    # @param digest [String]
    def report(turn, digest)
      @my_sums[turn.to_i] = digest.to_s[0, 64]
      @waiting_since = nil
      @link.send_data('k' => 'pvp', 'a' => 'sum', 'turn' => turn.to_i, 'sum' => @my_sums[turn.to_i])
      compare(turn.to_i)
    end

    # Fin du combat (ma victoire ou ma défaite constatée dans ma simulation)
    def finish!(won)
      @won = won ? true : false
      @link.send_data('k' => 'pvp', 'a' => 'end', 'won' => @won)
      @status = :over
    end

    def forfeit
      @link.send_data('k' => 'pvp', 'a' => 'forfeit') if @link.ready?
      @won = false
      @status = :over
    end

    def cancel(reason = 'cancel')
      return false if %i[over cancelled].include?(@status)

      @link.send_data('k' => 'pvp', 'a' => 'cancel', 'why' => reason.to_s[0, 40]) if @link.ready?
      finish_cancel(reason)
      return false
    end

    # @return [Boolean] l'adversaire met trop de temps à répondre
    def timed_out?
      return !@waiting_since.nil? && Time.now - @waiting_since > @turn_timeout
    end

    # À appeler à chaque image
    # @return [Symbol]
    def update
      @link.poll.each do |event|
        case event['t']
        when 'closed' then peer_gone(event['why'] || 'connexion perdue')
        when 'data' then handle(event['data'])
        end
      end
      peer_gone('connexion perdue') if @link.closed?
      cancel('délai dépassé') if timed_out?
      return @status
    end

    # Vérifie et nettoie les actions
    # @return [Array<Hash>, nil]
    def self.clean_actions(actions)
      return nil unless actions.is_a?(Array) && actions.size.between?(0, 6)

      result = actions.map do |act|
        return nil unless act.is_a?(Hash) && ACTION_TYPES.include?(act['type'])

        clean = { 'type' => act['type'] }
        %w[slot target_bank target_pos mon who with bag_item].each do |key|
          next unless act.key?(key)
          return nil unless act[key].is_a?(Integer) && act[key].between?(-1, 999)

          clean[key] = act[key]
        end
        clean['extra'] = act['extra'].to_s[0, 20] if act['extra'].is_a?(String)
        clean
      end
      return result
    end

    private

    def handle(data)
      return unless data['k'] == 'pvp'

      case data['a']
      when 'team' then receive_team(data)
      when 'seed' then receive_seed(data)
      when 'act' then receive_actions(data)
      when 'sum' then receive_sum(data)
      when 'end' then receive_end(data)
      when 'forfeit' then (@won = true) && (@status = :over)
      when 'cancel' then finish_cancel(data['why'] || 'cancel')
      end
    end

    def receive_team(data)
      return if @theirs

      team = data['team']
      return cancel('équipe invalide') unless team.is_a?(Array) && team.size.between?(1, 6)

      team = team.first(@team_size)
      team.each do |mon|
        problem = Online::Codec.problem(mon, max_level: 100)
        return cancel("équipe refusée : #{problem}") if problem
        return cancel('espèce interdite') if @banned.include?(mon['id'])
      end
      @theirs = team
      @peer_battler = data['battler'].to_s
      advance
    end

    def receive_seed(data)
      return unless @status == :waiting_seed && !host?
      return cancel('graine invalide') unless data['seed'].is_a?(Integer) && data['seed'].between?(0, 2**31)

      @seed = data['seed']
      start_running
    end

    def receive_actions(data)
      return unless @status == :running
      return unless data['turn'].is_a?(Integer) && data['turn'].between?(0, 9999)

      clean = self.class.clean_actions(data['acts'])
      return cancel('action adverse invalide') unless clean

      @actions[data['turn']] ||= clean
      @waiting_since = nil
    end

    def receive_sum(data)
      return unless data['turn'].is_a?(Integer) && data['sum'].is_a?(String)

      @sums[data['turn']] = data['sum'][0, 64]
      compare(data['turn'])
    end

    def receive_end(data)
      @won = data['won'] == true ? false : true if @won.nil?
      @status = :over
    end

    def compare(turn)
      mine = @my_sums[turn]
      theirs = @sums[turn]
      return unless mine && theirs
      return if mine == theirs

      cancel('désynchronisation')
    end

    # Phase de départ : les deux équipes sont connues
    def advance
      return unless @status == :waiting_team && @mine && @theirs

      if host?
        @seed = SecureRandom.random_number(2**31)
        @link.send_data('k' => 'pvp', 'a' => 'seed', 'seed' => @seed)
        start_running
      else
        @status = :waiting_seed
      end
    end

    def start_running
      @status = :running
      @waiting_since = nil
    end

    def peer_gone(why)
      return if %i[over cancelled].include?(@status)

      # un adversaire qui se déconnecte en plein combat est considéré comme ayant abandonné
      if @status == :running
        @won = true
        @status = :over
        @reason = "adversaire parti (#{why})"
      else
        finish_cancel(why)
      end
    end

    def finish_cancel(reason)
      @reason ||= reason.to_s
      @status = :cancelled
    end

    public

    # Empreinte stable d'un état de combat (liste de nombres / chaînes)
    # @param state [Array]
    # @return [String]
    def self.digest(state)
      return Digest::SHA256.hexdigest(state.flatten.map(&:to_s).join('|'))[0, 16]
    end
  end
end
