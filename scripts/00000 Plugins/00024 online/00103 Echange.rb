# encoding: utf-8
# Jeu en ligne : déroulement d'un échange entre deux joueurs (machine à états, indépendante de l'interface).
#
#   1. chacun choisit un Pokémon et l'envoie (offer)            → :choosing → :waiting_offer
#   2. chacun voit le Pokémon de l'autre (review)               → :review
#   3. chacun confirme ; la confirmation contient une empreinte des DEUX offres, identique des deux côtés
#      sinon l'échange est annulé (aucune des deux équipes n'est modifiée)  → :waiting_confirm
#   4. quand les deux confirmations concordent : :commit ; le jeu applique l'échange puis appelle #done!
# Un Pokémon n'est retiré de l'équipe qu'à l'étape :commit.
module Online
  class Trade
    # @return [Symbol]
    attr_reader :status
    # @return [Hash, nil] mon offre / celle de l'autre (Pokémon encodés)
    attr_reader :mine, :theirs
    # @return [String, nil] motif d'annulation
    attr_reader :reason

    # @param link [Online::Link]
    # @param max_level [Integer]
    def initialize(link, max_level: 100)
      @link = link
      @max_level = max_level
      @status = :choosing
      @mine = nil
      @theirs = nil
      @reason = nil
      @i_confirmed = false
      @peer_confirmed = nil
    end

    # @return [String] empreinte commune : l'offre de l'hôte puis celle de l'invité
    def digest
      return nil unless @mine && @theirs

      host_first = @link.role == 'host' ? [@mine, @theirs] : [@theirs, @mine]
      return Online::Codec.fingerprint(host_first)
    end

    # Envoie mon Pokémon
    # @param data [Hash] Pokémon encodé
    def offer(data)
      return unless @status == :choosing

      @mine = data
      @link.send_data('k' => 'trade', 'a' => 'offer', 'mon' => data)
      @status = :waiting_offer
      advance
    end

    # Accepte l'échange
    def confirm
      return unless @status == :review

      @i_confirmed = true
      @link.send_data('k' => 'trade', 'a' => 'confirm', 'h' => digest)
      @status = :waiting_confirm
      advance
    end

    def cancel(reason = 'cancel')
      return if %i[done cancelled commit].include?(@status)

      @link.send_data('k' => 'trade', 'a' => 'cancel', 'why' => reason.to_s[0, 40]) if @link.ready?
      finish_cancel(reason)
    end

    # L'échange a été appliqué dans l'équipe
    def done!
      return unless @status == :commit

      @link.send_data('k' => 'trade', 'a' => 'done')
      @status = :done
    end

    # À appeler à chaque image : lit les messages et fait avancer l'échange
    # @return [Symbol] statut
    def update
      @link.poll.each do |event|
        case event['t']
        when 'closed' then finish_cancel(event['why'] || 'closed') unless %i[done commit].include?(@status)
        when 'data' then handle(event['data'])
        end
      end
      finish_cancel('closed') if @link.closed? && !%i[done commit cancelled].include?(@status)
      return @status
    end

    private

    def handle(data)
      return unless data['k'] == 'trade'

      case data['a']
      when 'offer' then receive_offer(data['mon'])
      when 'confirm' then (@peer_confirmed = data['h'].to_s) && advance
      when 'cancel' then finish_cancel(data['why'] || 'cancel')
      end
    end

    def receive_offer(mon)
      return if @theirs

      problem = Online::Codec.problem(mon, max_level: @max_level)
      return cancel("offre refusée : #{problem}") if problem

      @theirs = mon
      advance
    end

    def advance
      @status = :review if @status == :waiting_offer && @mine && @theirs
      return unless @i_confirmed && @peer_confirmed

      if @peer_confirmed == digest
        @status = :commit
      else
        cancel('empreinte différente')
      end
    end

    def finish_cancel(reason)
      @reason ||= reason.to_s
      @status = :cancelled
    end
  end
end
