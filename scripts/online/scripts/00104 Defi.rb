# encoding: utf-8
# Jeu en ligne : défi d'équipe entre deux joueurs (étape 1).
# Chaque joueur envoie son équipe ; chacun affronte ensuite, sur sa console, l'équipe de l'autre dirigée par l'IA du jeu.
# Les deux scores sont échangés à la fin. (Le combat en direct, tour par tour, est prévu à l'étape suivante.)
#   :choosing → :waiting_team → :ready (les deux équipes sont là) → :fighting → :waiting_result → :done
module Online
  class Duel
    attr_reader :status, :mine, :theirs, :reason
    # @return [Boolean, nil] true si j'ai battu l'équipe de l'autre / si l'autre a battu la mienne
    attr_reader :my_win, :their_win

    # @param link [Online::Link]
    # @param team_size [Integer]
    # @param level_cap [Integer] 0 : aucun
    # @param banned [Array<String>]
    def initialize(link, team_size: 3, level_cap: 50, banned: [])
      @link = link
      @team_size = team_size.to_i.clamp(1, 6)
      @level_cap = level_cap.to_i
      @banned = Array(banned).map(&:to_s)
      @status = :choosing
      @mine = nil
      @theirs = nil
      @reason = nil
      @my_win = nil
      @their_win = nil
      @start_me = false
      @start_peer = false
    end

    attr_reader :team_size, :level_cap, :peer_battler

    # @param team [Array<Hash>] Pokémon encodés
    def offer(team)
      return unless @status == :choosing

      @mine = team.first(@team_size)
      @link.send_data('k' => 'duel', 'a' => 'team', 'team' => @mine, 'size' => @team_size, 'cap' => @level_cap, 'battler' => Online.my_battler)
      @status = :waiting_team
      advance
    end

    # Les deux joueurs sont prêts : le combat peut commencer
    def start
      return unless @status == :ready

      @start_me = true
      @link.send_data('k' => 'duel', 'a' => 'start')
      advance
    end

    # Résultat de mon combat contre l'équipe de l'autre
    # @param won [Boolean]
    def result!(won)
      @my_win = won ? true : false
      @link.send_data('k' => 'duel', 'a' => 'result', 'won' => @my_win)
      @status = @their_win.nil? ? :waiting_result : :done
    end

    def cancel(reason = 'cancel')
      return if %i[done cancelled].include?(@status)

      @link.send_data('k' => 'duel', 'a' => 'cancel', 'why' => reason.to_s[0, 40]) if @link.ready?
      finish_cancel(reason)
    end

    # @return [Symbol]
    def update
      @link.poll.each do |event|
        case event['t']
        when 'closed' then finish_cancel(event['why'] || 'closed') unless %i[done].include?(@status)
        when 'data' then handle(event['data'])
        end
      end
      finish_cancel('closed') if @link.closed? && !%i[done cancelled].include?(@status)
      return @status
    end

    private

    def handle(data)
      return unless data['k'] == 'duel'

      case data['a']
      when 'team' then receive_team(data)
      when 'start' then (@start_peer = true) && advance
      when 'result' then receive_result(data)
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

    def receive_result(data)
      @their_win = data['won'] == true
      @status = :done unless @my_win.nil?
    end

    def advance
      @status = :ready if @status == :waiting_team && @mine && @theirs
      @status = :fighting if @status == :ready && @start_me && @start_peer
    end

    def finish_cancel(reason)
      @reason ||= reason.to_s
      @status = :cancelled
    end
  end
end
