# Pokéathlon : Mixeur à Noigrumes (commande mixeur_noigrumes)
#
# Écran du mixeur : Noigrumes dedans, avancement du mélange (pas), saveurs, douceur, verres restants.
# Actions : ajouter un Noigrume du sac, goûter, donner un verre à un Pokémon de l'équipe, quitter.
module GamePlay
  class PokeathlonBlender < BaseCleanUpdate
    WHITE = 9
    DARK = 0
    FLAVOR_COLORS = { 'spicy' => [232, 72, 72], 'dry' => [72, 120, 232], 'sweet' => [240, 120, 184], 'bitter' => [72, 184, 96],
                      'sour' => [240, 200, 48] }.freeze

    def initialize
      super()
      @choice_index = 0
    end

    def update_inputs
      return true if $game_temp.message_window_showing

      if Input.trigger?(:B) || Mouse.trigger?(:RIGHT)
        play_cancel_se
        @running = false
      elsif Input.trigger?(:A) || Mouse.trigger?(:LEFT)
        open_menu
      end
      return true
    end

    def update_graphics
      @icons&.each(&:update)
      return true
    end

    private

    def create_graphics
      super
      refresh
    end

    def refresh
      @stack&.dispose
      @icons = []
      s = @stack = UI::SpriteStack.new(@viewport, default_cache: :interface)
      s.add_sprite(0, 0, Pokeathlon.file('fond_menu'))
      s.add_sprite(0, 0, Pokeathlon.file('titre'))
      s.add_text(0, 4, 320, 16, Pokeathlon.t('Mixeur à Noigrumes', 'Apricorn Blender'), 1, color: WHITE)
      s.add_sprite(10, 26, Pokeathlon.file('panneau_epreuve'))
      b = Pokeathlon.blender
      slots = Pokeathlon.setting('juice_apricorns').to_i.clamp(1, 10)
      start = 160 - slots * 15
      slots.times do |i|
        s.add_sprite(start + i * 30, 32, Pokeathlon.file('case_noigrume'))
        item = b['apricorns'][i]
        next unless item

        icon = s.push(start + i * 30 + 3, 35, nil, type: UI::ItemSprite)
        icon.data = item.to_sym
      end
      s.add_text(20, 64, 280, 16, state_text, 1, color: WHITE)
      flavors = Pokeathlon.juice_flavors
      effect = Pokeathlon.blender_state == :empty ? {} : Pokeathlon.juice_effect
      Pokeathlon::FLAVORS.each_with_index do |flavor, i|
        y = 86 + i * 18
        stat = Pokeathlon::FLAVOR_STAT[flavor]
        s.add_text(22, y, 70, 16, Pokeathlon.localized(Pokeathlon::FLAVOR_NAMES[flavor]), color: WHITE)
        s.add_sprite(92, y + 4, Pokeathlon.file('barre_fond'))
        bar = s.add_sprite(93, y + 5, Pokeathlon.file("barre_#{flavor}"))
        bar.src_rect.width = (flavors[i] * 100 / 63.0).round.clamp(0, 100)
        s.with_font(20) { s.add_text(200, y + 2, 30, 13, flavors[i].to_s, 2, color: WHITE) }
        value = effect[stat].to_i
        text = "#{Pokeathlon.stat_name(stat)} #{value > 0 ? '+' : ''}#{value}"
        s.with_font(20) { s.add_text(238, y + 2, 66, 13, value != 0 ? text : '', color: WHITE) }
      end
      mild = b['mild'].to_i
      s.with_font(20) do
        s.add_text(22, 178, 140, 13, Pokeathlon.t("Douceur : #{mild}", "Mildness: #{mild}"), color: WHITE)
        s.add_text(160, 178, 140, 13, Pokeathlon.t("Points : #{Pokeathlon.points}", "Points: #{Pokeathlon.points}"), 2, color: WHITE)
      end
      s.add_sprite(0, 222, Pokeathlon.file('aide'))
      s.with_font(20) { s.add_text(0, 224, 320, 14, Pokeathlon.t('A : actions   B : quitter', 'A: actions   B: quit'), 1, color: WHITE) }
    end

    def state_text
      b = Pokeathlon.blender
      case Pokeathlon.blender_state
      when :empty
        return Pokeathlon.t('Le mixeur est vide.', 'The blender is empty.')
      when :mixing
        steps = Pokeathlon.setting('juice_steps').to_i
        return Pokeathlon.t("Mélange : #{b['steps'].to_i} / #{steps} pas", "Blending: #{b['steps'].to_i} / #{steps} steps")
      else
        return Pokeathlon.t("Jus prêt ! Verres : #{b['uses'].to_i}", "Juice ready! Glasses: #{b['uses'].to_i}")
      end
    end

    def open_menu
      play_decision_se
      choices = [Pokeathlon.t('Ajouter un Noigrume', 'Add an Apricorn'), Pokeathlon.t('Goûter', 'Taste'),
                 Pokeathlon.t('Donner un verre', 'Give a glass'), Pokeathlon.t('Quitter', 'Quit')]
      case display_message(Pokeathlon.t('Que faire ?', 'What will you do?'), 1, *choices)
      when 0 then add_menu
      when 1 then taste
      when 2 then give
      when 3 then @running = false
      end
    end

    def add_menu
      list = Pokeathlon.apricorn_items.select { |item| $bag.contain_item?(item) }
      return display_message(Pokeathlon.t('Tu n’as aucun Noigrume.', 'You don’t have any Apricorns.')) if list.empty?

      names = list.map { |item| "#{data_item(item).name} ×#{$bag.item_quantity(item)}" }
      choice = display_message(Pokeathlon.t('Quel Noigrume ajouter ?', 'Which Apricorn?'), 1, *names, Pokeathlon.t('Retour', 'Back'))
      return if choice.nil? || choice >= list.size

      if Pokeathlon.blender_state == :ready &&
         display_message(Pokeathlon.t('Le jus prêt sera jeté. Continuer ?', 'The ready juice will be thrown away. Continue?'), 1,
                         Pokeathlon.t('Oui', 'Yes'), Pokeathlon.t('Non', 'No')) != 0
        return
      end

      error = Pokeathlon.add_apricorn(list[choice])
      return display_message(error) if error

      Pokeathlon.play_se('point')
      refresh
      steps = Pokeathlon.setting('juice_steps').to_i
      display_message(Pokeathlon.t("#{data_item(list[choice]).name} ajouté ! Le jus sera prêt dans #{steps} pas.",
                                   "#{data_item(list[choice]).name} added! The juice will be ready in #{steps} steps."))
    end

    def taste
      case Pokeathlon.blender_state
      when :empty then display_message(Pokeathlon.t('Le mixeur est vide.', 'The blender is empty.'))
      when :mixing then display_message(Pokeathlon.t('Le mélange n’est pas prêt… ', 'It isn’t ready… ') + Pokeathlon.taste_text)
      else display_message(Pokeathlon.taste_text)
      end
    end

    def give
      return display_message(Pokeathlon.t('Il n’y a pas de jus prêt.', 'There is no juice ready.')) unless Pokeathlon.blender_state == :ready

      index = -1
      call_scene(GamePlay::Party_Menu, $actors, :map) { |scene| index = scene.return_data }
      pokemon = index >= 0 ? $actors[index] : nil
      return unless pokemon
      return display_message(Pokeathlon.t('Un Œuf ne peut pas boire de jus.', 'An Egg can’t drink juice.')) if pokemon.egg?

      effect = Pokeathlon.give_juice(pokemon)
      refresh
      parts = effect.map { |stat, v| "#{Pokeathlon.stat_name(stat)} #{v > 0 ? '+' : ''}#{v}" }
      text = parts.empty? ? Pokeathlon.t('rien ne change', 'nothing changes') : parts.join(', ')
      display_message(Pokeathlon.t("#{pokemon.given_name} a bu le jus ! (#{text})", "#{pokemon.given_name} drank the juice! (#{text})"))
    end
  end
end
