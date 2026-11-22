# PokeSmart : barre d'état (moment de la journée, batterie, réseau, connexion Internet)
module UI
  module PokeSmart
    module_function

    # Moment de la journée : système jour / nuit de PSDK, sinon l'heure de l'ordinateur
    # @return [Symbol] :morning, :day, :evening ou :night
    def time_of_day
      if $env
        return :morning if $env.morning?
        return :day if $env.day?
        return :evening if $env.sunset?
        return :night if $env.night?
      end
      hour = Time.now.hour
      return :morning if hour.between?(6, 10)
      return :day if hour.between?(11, 17)
      return :evening if hour.between?(18, 20)

      return :night
    rescue StandardError
      return :day
    end

    # Réseau selon la zone : extérieur (vol autorisé) 4 barres, grotte / donjon 0, bâtiment 2.
    # Une zone sans vol mais avec des Pokémon sauvages (forêt, marais…) compte comme l'extérieur.
    # @return [Integer] 0 à 4
    def network_level
      map_forced = defined?($game_map) && $game_map && NETWORK_BY_MAP[$game_map.map_id]
      return map_forced.clamp(0, 4) if map_forced

      zone = $env.current_zone_data
      forced = zone && NETWORK_BY_ZONE[zone.id]
      return forced.clamp(0, 4) if forced
      return NETWORK_OUTSIDE if $game_switches[Yuki::Sw::Env_CanFly]

      name = "#{$env.current_zone_name.to_s.downcase} "
      return NETWORK_CAVE if $env.cave? || NO_NETWORK_WORDS.any? { |word| name.include?(word) }
      return NETWORK_OUTSIDE if zone && !zone.wild_groups.to_a.empty?

      return NETWORK_BUILDING
    rescue StandardError
      return NETWORK_OUTSIDE
    end

    # Batterie selon le moment de la journée, ou Pikachu si un Pikachu est dans l'équipe
    # @return [String] 20, 40, 60, 80 ou pika
    def battery_level
      return 'pika' if ($actors || []).compact.any? { |pokemon| !pokemon.egg? && PIKA_SPECIES.include?(pokemon.db_symbol) }

      return BATTERY_BY_TIME[PokeSmart.time_of_day]
    rescue StandardError
      return '80'
    end

    # Test de connexion Internet en tâche de fond (le jeu ne se bloque pas pendant le test)
    module Internet
      @connected = false
      @checked_at = nil
      @thread = nil

      module_function

      # @return [Boolean] dernier résultat connu
      def connected?
        refresh
        return @connected
      end

      # Relance un test si le dernier date de plus de INTERNET_CHECK_DELAY secondes
      def refresh
        return if @thread&.alive?
        return if @checked_at && Time.now - @checked_at < INTERNET_CHECK_DELAY

        @checked_at = Time.now
        @thread = Thread.new do
          @connected = INTERNET_HOSTS.any? { |host, port| reachable?(host, port) }
        end
      end

      # @return [Boolean]
      def reachable?(host, port)
        require 'socket' unless defined?(Socket)
        Socket.tcp(host, port, connect_timeout: INTERNET_TIMEOUT).close
        return true
      rescue StandardError, ScriptError
        return false
      end
    end
  end
end
