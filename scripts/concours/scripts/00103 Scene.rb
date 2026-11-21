# Concours : la scène (écran dédié)
# Présentation des 4 concurrents, épreuves (Habillage, Danse, Jeu d'acteur), résultats, remise du ruban.
module Concours
  # Apparence d'un personnage (planche de 4 x 4 images, ligne 0 : de face)
  class CharsetSprite < Sprite
    DIRECTIONS = { down: 0, left: 1, right: 2, up: 3 }.freeze

    def initialize(viewport, name)
      super(viewport)
      @frame = 0
      @row = 0
      @walk = false
      @tick = rand(12)
      self.charset = name
    end

    def charset=(name)
      return self.visible = false if name.to_s.empty? || !RPG::Cache.character_exist?(name.to_s)

      self.bitmap = RPG::Cache.character(name.to_s)
      @fw = bitmap.width / 4
      @fh = bitmap.height / 4
      set_origin(@fw / 2, @fh)
      refresh
    end

    def turn(direction)
      @row = DIRECTIONS[direction] || 0
      refresh
    end

    def walking=(value)
      @walk = value
      @frame = 0 unless value
      refresh
    end

    def update
      return unless @walk && bitmap

      @tick += 1
      return if @tick < 10

      @tick = 0
      @frame = (@frame + 1) % 4
      refresh
    end

    private

    def refresh
      return unless @fw

      src_rect.set(@frame * @fw, @row * @fh, @fw, @fh)
    end
  end

  class StageScene < GamePlay::BaseCleanUpdate
    WHITE = 10
    FLOOR_Y = 168
    SLOTS = [40, 120, 200, 280].freeze
    MC_X = 160
    MC_Y = 136
    # @return [Array<Entrant>] classement final
    attr_reader :ranking

    # @param type [String]
    # @param rank [String]
    # @param entrants [Array<Entrant>]
    def initialize(type, rank, entrants)
      super()
      @type = type
      @rank = rank
      @entrants = entrants
      @steps = []
      @wait = 0
      @flash = 0
      @ranking = nil
      plan_intro
    end

    def update_inputs
      return true if (@wait -= 1) > 0

      until @steps.empty?
        kind, *args = @steps.shift
        run_step(kind, *args)
        return true if @wait > 0
      end
      @running = false
      return true
    end

    def update_graphics
      @pairs&.each { |pair| pair[:trainer].update; pair[:pokemon].update }
      @mc&.update
      update_flash
      update_moves
      return true
    end

    private

    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport)
      @stack.add_sprite(0, 0, Concours.file('scene'))
      @beam = @stack.add_sprite(0, 0, Concours.file('faisceau'))
      @beam.set_origin(32, 0)
      @beam.visible = false
      @mc = @stack.push_sprite(CharsetSprite.new(@viewport, Concours.setting('mc_charset')))
      @mc.set_position(MC_X, MC_Y)
      @pairs = @entrants.each_with_index.map do |entrant, i|
        trainer = @stack.push_sprite(CharsetSprite.new(@viewport, entrant.player ? player_charset : entrant.charset))
        trainer.set_position(SLOTS[i] - 13, FLOOR_Y)
        pokemon = @stack.push_sprite(CharsetSprite.new(@viewport, entrant.pokemon.character_name))
        pokemon.set_position(SLOTS[i] + 13, FLOOR_Y)
        pokemon.walking = true
        { trainer: trainer, pokemon: pokemon }
      end
      @title = Concours.add_banner(@stack, @type, @rank)
      @white = @stack.add_sprite(0, 0, Concours.file('blanc'))
      @white.opacity = 0
      @moves = []
      Concours.play_bgm(Concours.setting('hall_bgm'))
    end

    def player_charset
      name = $game_player.respond_to?(:character_name) ? $game_player.character_name.to_s : ''
      return name
    end

    # --- Déroulé ------------------------------------------------------------------------------------------------------
    def mc
      return "#{Concours.setting('mc_name')} : "
    end

    def plan_intro
      @steps << [:se, 'concours_foule'] << [:wait, 30] << [:turn_mc, :left] << [:wait, 12] << [:turn_mc, :right]
      @steps << [:wait, 12] << [:turn_mc, :down] << [:wait, 20]
      @steps << [:msg, Concours.t("#{mc}Le #{Concours.contest_name(@type, @rank)} va commencer !",
                                  "#{mc}The #{Concours.contest_name(@type, @rank)} is about to begin!")]
      @steps << [:msg, Concours.t("Je suis #{Concours.setting('mc_name')}, votre présentateur et l’un des juges !",
                                  "I'm #{Concours.setting('mc_name')}, your MC and one of the Judges!")]
      @steps << [:msg, Concours.t('Les résultats seront annoncés à la fin. Place aux concurrents !',
                                  "The results will be announced at the end. Let's meet our contestants!")]
      @entrants.each_with_index do |entrant, i|
        @steps << [:turn_mc, i < 2 ? :left : :right] << [:beam, i] << [:wait, 10]
        text = if entrant.player
                 Concours.t("Et enfin, l’entrée n° #{i + 1} : #{entrant.trainer} et #{entrant.name} !",
                            "And last but not least, entry number #{i + 1}: #{entrant.trainer} with #{entrant.name}!")
               else
                 Concours.t("Entrée n° #{i + 1} : #{entrant.trainer} et #{entrant.name} !",
                            "Entry number #{i + 1}: #{entrant.trainer} with #{entrant.name}!")
               end
        @steps << [:msg, text] << [:se, 'concours_foule'] << [:se, 'concours_sifflet'] << [:wait, 20]
        @steps << [:flash] << [:wait, 24] << [:flash] << [:wait, 30]
      end
      @steps << [:beam, nil] << [:turn_mc, :down] << [:wait, 20]
      plan_dressup
      plan_dance
      plan_acting
      @steps << [:msg, Concours.t("#{mc}Et voilà ! Toutes les épreuves sont terminées !", "#{mc}That's it, folks! All judging has been completed!")]
      @steps << [:flash] << [:wait, 20]
      @steps << [:msg, Concours.t('Quel Pokémon remportera le concours ? Place aux résultats !', 'Which Pokémon will be crowned the winner? Let’s announce the results!')]
      @steps << [:results]
    end

    def plan_dressup
      @theme = rand([Concours.themes.size, 1].max)
      @steps << [:msg, Concours.t('Commençons par l’épreuve visuelle ! Les concurrents habillent leurs Pokémon.',
                                  "Let's begin with the Visual Competition! Contestants, dress up your Pokémon!")]
      @steps << [:msg, Concours.t("Le thème de cette fois est... « #{Concours.theme_name(@theme)} » !",
                                  "OK, our theme this time is... \"#{Concours.theme_name(@theme)}\"!")]
      @steps << [:bgm, Concours.setting('judging_bgm')] << [:dressup] << [:wait, 30]
    end

    def plan_dance
      @steps << [:msg, Concours.t('Place à l’épreuve de danse ! Suivez bien le danseur principal !',
                                  "Next, it's the Dance Competition! Follow the lead dancer!")]
      @steps << [:dance] << [:wait, 20]
    end

    def plan_acting
      @steps << [:msg, Concours.t('Et maintenant, l’épreuve de jeu d’acteur ! Montrez vos capacités aux juges !',
                                  "And now, the Acting Competition! Show your moves to the Judges!")]
      @steps << [:acting] << [:wait, 20]
    end

    def run_step(kind, *args)
      case kind
      when :wait then @wait = args[0].to_i
      when :msg then display_message(args[0].to_s)
      when :se then Concours.play_se(args[0])
      when :bgm then Concours.play_bgm(args[0])
      when :turn_mc then @mc.turn(args[0])
      when :beam then show_beam(args[0])
      when :flash then flash
      when :dressup then run_dressup
      when :dance then run_dance
      when :acting then run_acting
      when :results then run_results
      when :award then run_award
      when :move_winner then move_winner
      end
    end

    def show_beam(index)
      @beam.visible = !index.nil?
      @beam.set_position(SLOTS[index], 20) if index
    end

    def flash
      @flash = 12
      Concours.play_se('concours_appareil', 80)
    end

    def update_flash
      return unless @white

      @white.opacity = @flash > 0 ? (@flash * 18).clamp(0, 220) : 0
      @flash -= 1 if @flash > 0
    end

    # --- Épreuves -----------------------------------------------------------------------------------------------------
    def player
      return @entrants.find(&:player)
    end

    def run_dressup
      if Concours.minigames?
        call_scene(DressupScene, player, @theme, @rank)
        call_scene(RevealScene, @entrants, @rank)
        Concours.play_bgm(Concours.setting('judging_bgm'))
        worn = player.worn.map { |piece| Array(piece).first }
      else
        worn = Concours.auto_dressup(player, @theme, @rank)
      end
      name = player.name
      text = if worn.empty?
               Concours.t("#{name} se présente sans accessoire...", "#{name} appears without any accessory...")
             else
               list = worn.uniq.first(3).map { |id| Concours.accessory_name(id) }.join(', ')
               more = worn.uniq.size > 3 ? Concours.t(' et d’autres', ' and more') : ''
               Concours.t("#{name} porte #{worn.size} accessoire#{worn.size > 1 ? 's' : ''} : #{list}#{more} !",
                          "#{name} wears #{worn.size} accessor#{worn.size > 1 ? 'ies' : 'y'}: #{list}#{more}!")
             end
      @steps.unshift([:msg, text], [:se, 'concours_foule'], [:flash], [:wait, 16])
    end

    def run_dance
      if Concours.minigames?
        call_scene(DanceScene, @entrants, @rank)
        Concours.play_bgm(Concours.setting('judging_bgm'))
        best = @entrants.max_by(&:dance)
        text = if best.player
                 Concours.t("#{player.name} a été le meilleur danseur !", "#{player.name} was the best dancer!")
               else
                 Concours.t("#{best.name} a été le meilleur danseur !", "#{best.name} was the best dancer!")
               end
      else
        great = nil
        @entrants.each do |entrant|
          result = Concours.auto_dance(entrant, @rank)
          great = result if entrant.player
        end
        text = if great[0] >= great[1]
                 Concours.t("#{player.name} a dansé avec brio !", "#{player.name} danced brilliantly!")
               elsif great[0] + great[1] > 0
                 Concours.t("#{player.name} a bien suivi le rythme.", "#{player.name} kept up with the beat.")
               else
                 Concours.t("#{player.name} s’est un peu emmêlé les pattes...", "#{player.name} got a little lost...")
               end
      end
      @pairs.each { |pair| pair[:pokemon].walking = true }
      @steps.unshift([:msg, text], [:se, 'concours_foule'])
    end

    def run_acting
      if Concours.minigames?
        call_scene(ActingScene, @entrants, @type, @rank)
        Concours.play_bgm(Concours.setting('judging_bgm'))
        text = Concours.t("#{player.name} a obtenu #{player.acting} points de jeu d’acteur !",
                          "#{player.name} earned #{player.acting} acting points!")
        return @steps.unshift([:msg, text], [:se, 'concours_coeur'], [:flash], [:wait, 16])
      end
      hearts = nil
      @entrants.each do |entrant|
        result = Concours.auto_acting(entrant, @type, @rank)
        hearts = result if entrant.player
      end
      moves = Concours.best_moves(player.pokemon, @type).first(2).map { |sym| data_move(sym).name rescue sym.to_s }
      shown = moves.empty? ? '' : Concours.t(" avec #{moves.join(' et ')}", " with #{moves.join(' and ')}")
      text = Concours.t("#{player.name} a séduit les juges#{shown} : #{hearts.sum} cœurs !",
                        "#{player.name} charmed the Judges#{shown}: #{hearts.sum} hearts!")
      @steps.unshift([:msg, text], [:se, 'concours_coeur'], [:flash], [:wait, 16])
    end

    def run_results
      bgm = $game_system.playing_bgm
      scene = nil
      call_scene(ResultsScene, @type, @rank, @entrants) { |s| scene = s }
      @ranking = scene&.ranking || Concours.ranking(@entrants)
      Concours.play_bgm(Concours.setting('win_bgm'))
      @winner = @ranking.first
      @steps.unshift([:move_winner], [:wait, 40], [:award])
    end

    def move_winner
      index = @entrants.index(@winner)
      pair = @pairs[index]
      side = index < 2 ? -1 : 1
      add_move(pair[:trainer], MC_X + side * 28, MC_Y)
      add_move(pair[:pokemon], MC_X + side * 56, MC_Y)
      @mc.turn(side < 0 ? :left : :right)
      show_beam(nil)
      @beam.set_position(MC_X, 6)
      @beam.visible = true
    end

    def add_move(sprite, x, y)
      @moves << { sprite: sprite, from: [sprite.x, sprite.y], to: [x, y], time: 0 }
    end

    def update_moves
      @moves.each do |move|
        move[:time] += 1
        t = (move[:time] / 30.0).clamp(0, 1)
        move[:sprite].set_position((move[:from][0] + (move[:to][0] - move[:from][0]) * t).round,
                                   (move[:from][1] + (move[:to][1] - move[:from][1]) * t).round)
      end
      @moves.reject! { |move| move[:time] >= 30 }
    end

    def run_award
      winner = @winner
      Concours.play_se('concours_foule')
      Concours.play_se('concours_sifflet')
      flash
      display_message(Concours.t("#{mc}Félicitations ! Applaudissons notre gagnant : #{winner.trainer} et #{winner.name} !",
                                 "#{mc}Congratulations! Let's recognize our winner: #{winner.trainer}'s #{winner.name}!"))
      ribbon = Concours.ribbon(@type, @rank)
      display_message(Concours.t("Le gagnant reçoit le #{Concours.ribbon_name(ribbon)} !", "Our winner is awarded the #{Concours.ribbon_name(ribbon)}!"))
      if winner.player
        winner.pokemon.add_ribbon(ribbon) if winner.pokemon.respond_to?(:add_ribbon)
        Concours.play_me('concours_accessoire')
        display_message(Concours.t("#{winner.name} reçoit le #{Concours.ribbon_name(ribbon)} !", "#{winner.name} received the #{Concours.ribbon_name(ribbon)}!"))
      end
      @mc.turn(:down)
      display_message(Concours.t("#{mc}Nous attendons avec impatience votre prochain défi !", "#{mc}We look forward to your next Contest challenge!"))
      flash
      @steps.unshift([:wait, 30], [:flash], [:wait, 30])
    end
  end
end
