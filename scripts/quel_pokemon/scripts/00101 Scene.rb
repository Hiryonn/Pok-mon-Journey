# Quel est ce Pokémon ? : la scène (silhouette, réponses, révélation)
module GamePlay
  class QuelPokemon < BaseCleanUpdate::FrameBalanced
    QP = ::QuelPokemon
    # Fond fait pour 512 x 384 (Essentials) : réduit à l'écran
    BG_ZOOM = 320 / 512.0
    # Centre de la tache blanche du fond (sur l'écran)
    POKEMON_X = 92
    POKEMON_Y = 96
    # Taille du Pokémon (ses images font 96 px)
    POKEMON_ZOOM = 1.5

    # @return [Integer] 1 trouvé, 2 raté, 3 déjà joué
    attr_reader :result

    def initialize
      super()
      @cfg = QP.config
      @answer, @choices = QP.daily(QP.today, @cfg)
      @result = QP::ALREADY
      @state = :start
    end

    def update_inputs
      case @state
      when :start then start_game
      when :finish then @running = false
      end
      return false
    end

    def update_graphics
      return true
    end

    private

    def create_graphics
      super
      @background = Sprite.new(@viewport)
      if RPG::Cache.interface_exist?(QP::BACKGROUND)
        @background.set_bitmap(QP::BACKGROUND, :interface)
        @background.zoom = BG_ZOOM
      end
      @pokemon = Sprite::WithColor.new(@viewport)
      @pokemon.z = 10
      @pokemon.visible = false
      return unless @answer

      filename = PFM::Pokemon.front_filename(data_creature(@answer).id, 0, false, false, false)
      @pokemon.bitmap = RPG::Cache.poke_front(filename)
      width = [@pokemon.bitmap.width, @pokemon.bitmap.height].min
      @pokemon.src_rect.set(0, 0, width, @pokemon.bitmap.height)
      @pokemon.set_origin(width / 2, @pokemon.bitmap.height / 2)
      @pokemon.set_position(POKEMON_X, POKEMON_Y)
    rescue StandardError => e
      log_error("Quel est ce Pokémon : image de #{@answer} (#{e.message})") if respond_to?(:log_error, true)
    end

    def start_game
      @state = :finish
      unless @answer
        display_message(QP.t('Aucun Pokémon à deviner (réglages de Studio).', 'No Pokémon to guess (Studio settings).'))
        return
      end
      data = QP.save_data
      if QP.played_today?
        reveal(false)
        text = data[:result] == QP::WIN ? QP.t("Tu as déjà trouvé aujourd'hui : c'était #{QP.name_of(@answer)} !", "You already found it today: it was #{QP.name_of(@answer)}!")
                                         : QP.t("Tu as déjà joué aujourd'hui : c'était #{QP.name_of(@answer)}.", "You already played today: it was #{QP.name_of(@answer)}.")
        display_message(text)
        display_message(QP.t('Reviens demain pour un nouveau Pokémon !', 'Come back tomorrow for a new Pokémon!'))
        return
      end
      silhouette
      Audio.se_play(QP::SE_INTRO) rescue nil
      wait(40)
      play_rounds
    end

    def play_rounds
      tries = @cfg[:tries].to_i.clamp(1, 3)
      choices = @choices.dup
      found = false
      tries.times do |attempt|
        names = choices.map { |db| QP.name_of(db) }
        question = attempt == 0 ? QP.t('Quel est ce Pokémon ?', "Who's that Pokémon?") : QP.t("Encore un essai ! Quel est ce Pokémon ?", 'One more try! Who is it?')
        index = display_message(question, 1, *names)
        picked = choices[index.to_i] || choices.first
        if picked == @answer
          found = true
          break
        end
        Audio.se_play(QP::SE_WRONG) rescue nil
        choices.delete(picked)
        display_message(QP.t("Non, ce n'est pas #{QP.name_of(picked)}…", "No, it's not #{QP.name_of(picked)}...")) if attempt < tries - 1
      end
      finish(found)
    end

    def finish(found)
      data = QP.save_data
      data[:day] = QP.today
      data[:played] = data[:played].to_i + 1
      reveal(true)
      if found
        Audio.se_play(QP::SE_CORRECT) rescue nil
        data[:streak] = data[:streak].to_i + 1
        data[:best] = [data[:best].to_i, data[:streak]].max
        data[:wins] = data[:wins].to_i + 1
        data[:result] = @result = QP::WIN
        display_message(QP.t("C'est #{QP.name_of(@answer)} !", "It's #{QP.name_of(@answer)}!"))
        give_rewards(@cfg[:rewards], @cfg[:money].to_i)
        every = @cfg[:streak_every].to_i
        if every > 0 && (data[:streak] % every).zero?
          display_message(QP.t("#{data[:streak]} jours d'affilée ! Bonus !", "#{data[:streak]} days in a row! Bonus!"))
          give_rewards(@cfg[:streak_rewards], 0)
        elsif data[:streak] > 1
          display_message(QP.t("Série : #{data[:streak]} jours d'affilée.", "Streak: #{data[:streak]} days in a row."))
        end
      else
        Audio.se_play(QP::SE_WRONG) rescue nil
        data[:streak] = 0
        data[:result] = @result = QP::LOSE
        display_message(QP.t("Dommage… C'était #{QP.name_of(@answer)} !", "Too bad... It was #{QP.name_of(@answer)}!"))
      end
      $pokedex.mark_seen(@answer, forced: true) if @cfg[:mark_seen] && $pokedex.respond_to?(:mark_seen) rescue nil
      display_message(QP.t('Reviens demain pour un nouveau Pokémon !', 'Come back tomorrow for a new Pokémon!'))
    end

    # @param list [Array<Hash>] [{ item, quantity }]
    # @param money [Integer]
    def give_rewards(list, money)
      Array(list).each do |reward|
        item = (reward['item'] || reward[:item]).to_s
        quantity = (reward['quantity'] || reward[:quantity] || 1).to_i
        next if item.empty? || quantity <= 0

        begin
          $bag.add_item(item.to_sym, quantity)
          display_message(QP.t("Tu reçois #{quantity > 1 ? "#{quantity} × " : ''}#{data_item(item.to_sym).name} !", "You got #{quantity > 1 ? "#{quantity} × " : ''}#{data_item(item.to_sym).name}!"))
        rescue StandardError => e
          log_error("Quel est ce Pokémon : objet #{item} (#{e.message})") if respond_to?(:log_error, true)
        end
      end
      return unless money > 0

      PFM.game_state.add_money(money)
      display_message(QP.t("Tu reçois #{money} $ !", "You got $#{money}!"))
    end

    # --- Pokémon ---------------------------------------------------------------------
    def silhouette
      @pokemon.visible = true
      @pokemon.set_color([0, 0, 0, 1])
      @pokemon.zoom = POKEMON_ZOOM * 0.2
      12.times do |i|
        @pokemon.zoom = POKEMON_ZOOM * (0.2 + 0.8 * (i + 1) / 12.0)
        wait(1)
      end
    end

    # @param animate [Boolean] la couleur revient doucement (et le cri)
    def reveal(animate)
      @pokemon.visible = true
      @pokemon.zoom = POKEMON_ZOOM
      if animate
        24.times do |i|
          @pokemon.set_color([1, 1, 1, 1 - (i + 1) / 24.0])
          wait(1)
        end
        cry
      end
      @pokemon.set_color([0, 0, 0, 0])
    end

    def cry
      pokemon = PFM::Pokemon.new(@answer, 1)
      Audio.se_play(pokemon.cry) unless pokemon.cry.to_s.empty?
    rescue StandardError
      nil
    end

    def wait(frames)
      frames.times do
        Graphics.update
        update_graphics
      end
    end
  end
end
