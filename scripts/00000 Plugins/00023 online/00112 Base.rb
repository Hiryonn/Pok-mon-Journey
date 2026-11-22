# encoding: utf-8
# Jeu en ligne — étape 6 : visite de la base secrète d'un ami.
# Le serveur garde un instantané de ta base (fond, décorations, trophées) ; tes amis peuvent la visiter (lecture seule).
# Dépend du plugin base_secrete : sans lui, ces fonctions sont simplement absentes.
module Online
  module BaseShare
    module_function

    # @return [Boolean]
    def available?
      return defined?(::BaseSecrete) && defined?(GamePlay::BaseSecreteScene) ? true : false
    end

    # @return [Hash, nil] instantané de ma base
    def snapshot
      return nil unless available?

      placed = ::BaseSecrete.placed.map do |entry|
        data = { 'kind' => entry['kind'].to_s, 'id' => entry['id'].to_s, 'x' => entry['x'].to_i, 'y' => entry['y'].to_i }
        if entry['kind'].to_s == 'contest' && defined?(::Concours)
          type, rank = entry['id'].to_s.split('_', 2)
          record = ::Concours.winner(type, rank)
          data.merge!('species' => record['species'].to_s, 'form' => record['form'].to_i, 'shiny' => record['shiny'] ? true : false) if record
        end
        data
      end
      return { 'theme' => ::BaseSecrete.state['theme'].to_s, 'placed' => placed, 'greeting' => Online.state['base_greeting'].to_s }
    rescue StandardError, NoMethodError => e
      log_error("En ligne : base secrète (#{e.message})") if respond_to?(:log_error, true)
      return nil
    end

    # Ouvre la pièce d'un ami en lecture seule
    # @param reply [Hash] réponse 'base' du serveur
    def visit(reply)
      base = reply['base']
      saved = $user_data[:pj_base]
      $user_data[:pj_base] = { 'theme' => base['theme'].to_s, 'placed' => base['placed'].map(&:dup) }
      $scene.call_scene(GamePlay::BaseVisitScene, reply['user']['name'].to_s, base['greeting'].to_s, reply['visits'].to_i, Array(reply['recent']))
    ensure
      $user_data[:pj_base] = saved
    end
  end

  module Game
    module_function

    # Partage ma base avec le serveur (silencieux)
    def share_base(link)
      snap = Online::BaseShare.snapshot
      call_social(link, 'base_set', { 'base' => snap }, 'base_ok') if snap
    end

    # Visite la base d'un ami
    def visit_base(link, friend)
      unless Online::BaseShare.available?
        return say(Online.t("Cette partie n'a pas la base secrète.", "This game has no secret base."))
      end
      reply = call_social(link, 'base_visit', { 'code' => friend['id'] }, 'base')
      return say(error_text(reply)) if reply['t'] == 'error'

      Online::BaseShare.visit(reply)
    end
  end
end

if defined?(GamePlay::BaseSecreteScene)
module GamePlay
  # Visite de la base d'un ami : la pièce reste en lecture seule (B : quitter, A : mot de l'hôte et visiteurs récents)
  class BaseVisitScene < BaseSecreteScene
    # @param owner [String]
    # @param greeting [String]
    # @param visits [Integer]
    # @param recent [Array<String>]
    def initialize(owner, greeting, visits, recent)
      @owner = owner
      @greeting = greeting
      @visits = visits
      @recent = recent
      @info_page = 0
      super()
    end

    def update_inputs
      if Input.trigger?(:B)
        play_cancel_se
        @running = false
      elsif Input.trigger?(:A)
        @info_page = (@info_page + 1) % 3
        refresh_background
        play_cursor_se
      end
      return true
    end

    def update_graphics
      @cursor.visible = false
      return true
    end

    private

    def refresh_background
      @back.set_bitmap(B.file(B.fetch(B.theme, 'image')), :interface)
      line = case @info_page
             when 1 then @greeting.empty? ? Online.t("#{@owner} n'a pas laissé de mot.", "#{@owner} left no message.") : "#{@owner} : #{@greeting}"
             when 2 then @recent.empty? ? Online.t('Aucun visiteur récent.', 'No recent visitors.') : Online.t("Visiteurs : #{@recent.join(', ')}", "Visitors: #{@recent.join(', ')}")
             else Online.t("Base de #{@owner}  —  #{@visits} visite#{@visits > 1 ? 's' : ''}", "#{@owner}'s base  —  #{@visits} visit#{@visits == 1 ? '' : 's'}")
             end
      @title.text = "#{line}   #{Online.t('A : infos  B : quitter', 'A: info  B: exit')}"
    end

    def refresh_cursor; end

    def make_sprite(entry)
      @visit_entry = entry
      return super
    end

    # Les trophées de concours montrent le Pokémon gagnant de l'hôte (et non celui du visiteur)
    def draw(sprite, kind, id)
      entry = @visit_entry
      return super unless kind == 'contest' && entry && entry['species']

      creature = data_creature(entry['species'].to_sym)
      sprite.set_bitmap(PFM::Pokemon.icon_filename(creature.id, entry['form'].to_i, false, entry['shiny'] ? true : false, false), :b_icon)
      sprite.src_rect.set(0, 0, sprite.bitmap.width / 2, sprite.bitmap.height) if sprite.bitmap
      sprite.x = (B::CELL - sprite.src_rect.width) / 2
      sprite.y = (B::CELL - sprite.src_rect.height) / 2
    end
  end
end
end
