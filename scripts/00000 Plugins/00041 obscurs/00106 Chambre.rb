# Pokémon Obscurs : Chambre de purification (façon XD)
#
# 9 ensembles : un Pokémon Obscur au centre et jusqu'à 4 Pokémon normaux autour. À chaque pas, la jauge du
# Pokémon Obscur baisse de chamber_gauge × tempo, avec tempo = 1 + 0,5 par Pokémon autour + 0,5 par lien du cercle
# où le type du Pokémon est super efficace sur le suivant (+0,5 si le dernier est super efficace sur le Pokémon Obscur).
# Une fois sa jauge vide, le Pokémon Obscur peut être purifié depuis la Chambre.
# Les Pokémon sont pris dans l'équipe et y reviennent (ou vont au PC si l'équipe est pleine).
module Obscurs
  module_function

  # @return [Array<Array>] [Pokémon Obscur ou nil, autres Pokémon (4 places, nil : vide)]
  def chamber
    sets = data['chamber']
    sets.map! { |set| set.is_a?(Array) ? set : [] }
    sets.each { |set| set.fill(nil, set.size...(1 + CHAMBER_SIZE)) }
    return sets
  end

  # @return [Float] tempo d'un ensemble
  def tempo(set)
    shadow = set[0]
    others = set[1..].compact
    return 0 unless shadow

    value = 1 + others.size * 0.5
    return value if others.empty?

    if others.size >= 2
      others.each_with_index do |pokemon, i|
        value += 0.5 if super_effective?(pokemon, others[(i + 1) % others.size])
      end
    end
    value += 0.5 if super_effective?(others.last, shadow)
    return value
  end

  def super_effective?(attacker, defender)
    return data_type(attacker.type1).hit(data_type(defender.type1).db_symbol) > 1
  rescue StandardError
    return false
  end

  # Chaque pas : la jauge des Pokémon Obscurs de la Chambre baisse
  def chamber_step
    base = setting('chamber_gauge').to_f
    return if base <= 0

    data['pj_chamber_rest'] ||= {}
    chamber.each_with_index do |set, i|
      shadow = set[0]
      next unless shadow&.shadow? && shadow.heart_gauge > 0

      rest = data['pj_chamber_rest'][i].to_f + base * tempo(set)
      amount = rest.floor
      data['pj_chamber_rest'][i] = rest - amount
      shadow.change_heart_gauge(-amount) if amount > 0
    end
  end

  # Remet un Pokémon dans l'équipe (ou au PC)
  def give_back(pokemon)
    return if pokemon.nil?
    return $actors << pokemon if $actors.size < 6

    $storage.store(pokemon)
  end

  # Ouvre la Chambre de purification
  def open_chamber
    $scene.call_scene(ChamberScene)
  end

  class ChamberScene < GamePlay::BaseCleanUpdate
    WHITE = 10
    DARK = 0
    CELL = 44
    GRID_X = 10
    GRID_Y = 30
    CENTER = [234, 104].freeze
    # Places autour du centre : haut, droite, bas, gauche
    AROUND = [[234, 58], [282, 104], [234, 150], [186, 104]].freeze

    def initialize
      super()
      @set = 0
      @slot = 0
      @mode = :sets
    end

    def update_inputs
      update_mouse_hover
      @mode == :sets ? update_sets : update_slots
      return true
    end

    def update_graphics
      @cursor.opacity = 180 + (Math.sin(Graphics.frame_count / 6.0) * 70).round
      @icons&.each { |icon| icon.update if icon.respond_to?(:update) }
      return true
    end

    private

    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport)
      @stack.add_sprite(0, 0, Obscurs.file('chambre'))
      @stack.add_text(0, 2, 320, 16, Obscurs.t('Chambre de purification', 'Purify Chamber'), 1, color: WHITE)
      @grid_icons = Array.new(CHAMBER_SETS) do |i|
        x = GRID_X + (i % 3) * CELL
        y = GRID_Y + (i / 3) * CELL
        @stack.add_sprite(x, y, Obscurs.file('case'))
        icon = @stack.push(x + 22, y + 18, nil, type: UI::PokemonIconSprite)
        bars = @stack.add_sprite(x + 7, y + 34, Obscurs.file('jauge_petite'))
        [icon, bars]
      end
      @icons = [@stack.push(*CENTER, nil, type: UI::PokemonIconSprite)] +
               AROUND.map { |pos| @stack.push(*pos, nil, type: UI::PokemonIconSprite) }
      @gauge_back = @stack.add_sprite(172, 186, Obscurs.file('jauge_fond'))
      @gauge = @stack.add_sprite(174, 188, Obscurs.file('jauge'))
      @set_title = @stack.add_text(160, 22, 152, 16, '', 1, color: WHITE)
      @tempo_text = @stack.add_text(160, 196, 152, 16, '', 1, color: WHITE)
      @info_text = @stack.add_text(160, 168, 152, 16, '', 1, color: WHITE)
      @hint = @stack.add_text(4, 220, 312, 16, '', 0, color: WHITE)
      @cursor = @stack.add_sprite(0, 0, Obscurs.file('curseur'))
      refresh
    end

    def chamber
      return Obscurs.chamber
    end

    def refresh
      chamber.each_with_index do |set, i|
        icon, bars = @grid_icons[i]
        icon.data = set[0]
        icon.visible = !set[0].nil?
        bars.visible = !set[0].nil?
        bars.src_rect.set(0, 0, set[0]&.shadow? ? 6 * set[0].heart_stage : 30, 4) if set[0]
      end
      set = chamber[@set]
      @icons.each_with_index do |icon, i|
        icon.data = set[i]
        icon.visible = !set[i].nil?
      end
      shadow = set[0]
      @set_title.text = Obscurs.t("Ensemble #{@set + 1}", "Set #{@set + 1}")
      @gauge.visible = @gauge_back.visible = shadow&.shadow? ? true : false
      if shadow&.shadow?
        @gauge.src_rect.set(0, 0, (136.0 * shadow.heart_gauge / shadow.max_heart_gauge).ceil, 6)
        @info_text.text = shadow.purifiable? ? Obscurs.t('Prêt à être purifié !', 'Ready to be purified!') : shadow.given_name
        @tempo_text.text = Obscurs.t("Tempo : ×#{format('%.1f', Obscurs.tempo(set))}", "Tempo: ×#{format('%.1f', Obscurs.tempo(set))}")
      else
        @info_text.text = shadow ? Obscurs.t("#{shadow.given_name} (purifié)", "#{shadow.given_name} (purified)") : ''
        @tempo_text.text = ''
      end
      @hint.text = if @mode == :sets
                     Obscurs.t('A : choisir l’ensemble   B : quitter', 'A: choose set   B: exit')
                   else
                     Obscurs.t('A : placer / reprendre   B : retour', 'A: place / take   B: back')
                   end
      place_cursor
    end

    def place_cursor
      if @mode == :sets
        @cursor.set_position(GRID_X + (@set % 3) * CELL - 1, GRID_Y + (@set / 3) * CELL - 1)
      else
        x, y = @slot == 0 ? CENTER : AROUND[@slot - 1]
        @cursor.set_position(x - 22, y - 22)
      end
    end

    # --- Ensembles ----------------------------------------------------------------------------------------------------
    def update_sets
      if Input.trigger?(:B) || Mouse.trigger?(:RIGHT)
        play_cancel_se
        return @running = false
      end
      return enter_set if Input.trigger?(:A)

      dx = (Input.repeat?(:RIGHT) ? 1 : 0) - (Input.repeat?(:LEFT) ? 1 : 0)
      dy = (Input.repeat?(:DOWN) ? 1 : 0) - (Input.repeat?(:UP) ? 1 : 0)
      return if dx == 0 && dy == 0

      play_cursor_se
      @set = ((@set / 3 + dy) % 3) * 3 + (@set % 3 + dx) % 3
      refresh
    end

    def enter_set
      play_decision_se
      @mode = :slots
      @slot = 0
      refresh
    end

    def update_mouse_hover
      return unless Mouse.trigger?(:LEFT)

      CHAMBER_SETS.times do |i|
        x = GRID_X + (i % 3) * CELL
        y = GRID_Y + (i / 3) * CELL
        next unless Mouse.x.between?(x, x + CELL - 3) && Mouse.y.between?(y, y + CELL - 3)

        @set = i
        @mode = :slots
        @slot = 0
        return refresh
      end
      return unless @mode == :slots

      ([CENTER] + AROUND).each_with_index do |(x, y), i|
        next unless Mouse.x.between?(x - 20, x + 20) && Mouse.y.between?(y - 20, y + 20)

        @slot = i
        refresh
        return choose_slot
      end
    end

    # --- Places d'un ensemble -----------------------------------------------------------------------------------------
    def update_slots
      if Input.trigger?(:B) || Mouse.trigger?(:RIGHT)
        play_cancel_se
        @mode = :sets
        return refresh
      end
      return choose_slot if Input.trigger?(:A)

      target = if Input.trigger?(:UP) then @slot == 3 ? 0 : 1
               elsif Input.trigger?(:DOWN) then @slot == 1 ? 0 : 3
               elsif Input.trigger?(:LEFT) then @slot == 2 ? 0 : 4
               elsif Input.trigger?(:RIGHT) then @slot == 4 ? 0 : 2
               end
      return unless target

      play_cursor_se
      @slot = target
      refresh
    end

    def choose_slot
      set = chamber[@set]
      pokemon = set[@slot]
      return place_pokemon(set) unless pokemon

      choices = [Obscurs.t('Reprendre', 'Take back'), Obscurs.t('Annuler', 'Cancel')]
      choices.unshift(Obscurs.t('Purifier', 'Purify')) if @slot == 0 && pokemon.purifiable?
      choice = display_message(Obscurs.t("Que faire de #{pokemon.given_name} ?", "What to do with #{pokemon.given_name}?"), 1, *choices)
      label = choices[choice.to_i]
      if label == Obscurs.t('Purifier', 'Purify')
        call_scene(PurifyScene, pokemon)
      elsif label == Obscurs.t('Reprendre', 'Take back')
        set[@slot] = nil
        Obscurs.give_back(pokemon)
        play_decision_se
      end
      refresh
    end

    def place_pokemon(set)
      index = -1
      call_scene(GamePlay.party_menu_class, $actors, :map) { |menu| index = menu.return_data }
      return refresh if index.nil? || index < 0

      pokemon = $actors[index]
      return refresh unless pokemon
      if pokemon.egg?
        display_message(Obscurs.t('Un Œuf ne peut pas entrer dans la Chambre.', "An Egg can't enter the Chamber."))
      elsif @slot == 0 && !pokemon.shadow?
        display_message(Obscurs.t('Le centre est réservé à un Pokémon Obscur.', 'The center is for a Shadow Pokémon.'))
      elsif @slot != 0 && pokemon.shadow?
        display_message(Obscurs.t('Un Pokémon Obscur se place au centre.', 'A Shadow Pokémon goes in the center.'))
      elsif $actors.count { |other| !other.egg? && !other.dead? } <= 1 && !pokemon.dead?
        display_message(Obscurs.t('C’est votre dernier Pokémon en état de se battre !', "That's your last Pokémon able to battle!"))
      else
        $actors.delete_at(index)
        set[@slot] = pokemon
        play_decision_se
      end
      refresh
    end
  end
end
