# Montures : appli Monture du téléphone (liste des montures débloquées, aux couleurs de l'interface Horizon)
#
# Haut / bas : monture, A : menu (Monter / Descendre, Voler, Flairer), B : retour. Souris : clic, molette.
# Monter, Descendre, Voler et Flairer ramènent sur la carte.
module GamePlay
  class MonturesApp < BaseCleanUpdate::FrameBalanced
    DARK = 0
    WHITE = 9
    SMALL = 20
    BG = 'horizon/team/fond'
    HEADER = 'horizon/header'
    FOOTER = 'horizon/tcard/button_background'
    LIST_X = 6
    LIST_Y = 32
    ROW_HEIGHT = 46
    ROWS = 4

    def initialize
      super()
      @list = Montures.unlocked
      current = Montures.current
      @index = current ? @list.index { |m| m['id'] == current['id'] }.to_i : 0
      @top = 0
    end

    def update_inputs
      if Input.trigger?(:B)
        play_cancel_se
        return @running = false
      end
      return open_actions if Input.trigger?(:A)

      if Input.repeat?(:DOWN) && !@list.empty?
        select((@index + 1) % @list.size)
      elsif Input.repeat?(:UP) && !@list.empty?
        select((@index - 1) % @list.size)
      end
      return true
    end

    def update_mouse(_moved)
      if Mouse.trigger?(:RIGHT)
        play_cancel_se
        @running = false
        return false
      end
      if Mouse.wheel != 0
        delta = -Mouse.wheel
        Mouse.wheel = 0
        select((@index + (delta <=> 0)).clamp(0, [@list.size - 1, 0].max)) unless @list.empty?
        return false
      end
      return true unless Mouse.trigger?(:LEFT)

      row = row_at(Mouse.x, Mouse.y)
      return true unless row

      row == @index ? open_actions : select(row)
      return false
    end

    def update_graphics
      @rows.each { |row| row[:icon].update if row[:icon].respond_to?(:update) }
      return true
    end

    private

    def row_at(x, y)
      return nil unless x.between?(LIST_X, LIST_X + 307) && y >= LIST_Y

      row = (y - LIST_Y) / ROW_HEIGHT
      return nil if row >= ROWS || (y - LIST_Y) % ROW_HEIGHT >= 44

      index = @top + row
      return index < @list.size ? index : nil
    end

    def select(index)
      return if index == @index

      play_cursor_se
      @index = index
      refresh
    end

    # Menu de la monture choisie
    def open_actions
      mount = @list[@index]
      return play_buzzer_se unless mount

      play_decision_se
      riding = Montures.current && Montures.current['id'] == mount['id']
      actions = [riding ? :leave : :ride]
      actions << :fly if Montures.power?(mount, 'fly')
      actions << :search if Montures.power?(mount, 'search')
      actions << :cancel
      labels = actions.map do |a|
        { ride: Montures.t('Monter', 'Ride'), leave: Montures.t('Descendre', 'Get off'), fly: Montures.t('Voler', 'Fly'),
          search: Montures.t('Flairer', 'Search'), cancel: Montures.t('Annuler', 'Cancel') }[a]
      end
      choice = display_message(Montures.t("Que faire avec #{Montures.name(mount)} ?", "What to do with #{Montures.name(mount)}?"), 1, *labels)
      do_action(actions[choice.to_i], mount)
    end

    def do_action(action, mount)
      error = case action
              when :ride then Montures.call(mount)
              when :leave then Montures.leave
              when :fly then fly(mount)
              when :search then Montures.search(mount)
              else return refresh
              end
      if error
        display_message(error)
        return refresh
      end
      return_to_scene(Scene_Map) unless action == :fly
    end

    def fly(mount)
      error = Montures.refusal_fly
      return error if error

      return Montures.fly(mount)
    end

    def create_graphics
      super
      @frame = UI::SpriteStack.new(@viewport, default_cache: :interface)
      if RPG::Cache.interface_exist?(BG)
        @frame.add_sprite(0, 0, BG)
      else
        bg = @frame.add_sprite(0, 0, UI::SpriteStack::NO_INITIAL_IMAGE)
        bg.bitmap = Bitmap.new(320, 240)
        bg.bitmap.fill_rect(0, 0, 320, 240, Color.new(229, 243, 250))
        bg.bitmap.update
      end
      @frame.add_sprite(0, 0, HEADER) if RPG::Cache.interface_exist?(HEADER)
      @frame.add_sprite(0, 214, FOOTER) if RPG::Cache.interface_exist?(FOOTER)
      @frame.add_text(96, 5, 128, 16, Montures.t('Montures', 'Mounts'), 1, color: WHITE)
      @frame.with_font(SMALL) do
        @counter = @frame.add_text(232, 7, 82, 13, '', 2, color: WHITE)
        @frame.add_text(8, 220, 304, 13, Montures.t('A : choisir   B : retour   Touche des montures : roue',
                                                    'A: choose   B: back   Mount key: wheel'), 1, color: WHITE)
      end
      create_rows
      @empty = @frame.add_text(0, 104, 320, 16, Montures.t('Aucune monture pour le moment', 'No mount yet'), 1, color: DARK)
      refresh
    end

    def create_rows
      @rows = Array.new(ROWS) do |i|
        row = UI::SpriteStack.new(@viewport, LIST_X, LIST_Y + i * ROW_HEIGHT, default_cache: :interface)
        bg = row.add_sprite(0, 0, Montures.file('ligne'))
        sel = row.add_sprite(0, 0, Montures.file('ligne_sel'))
        icon = row.push(21, 20, nil, type: UI::PokemonIconSprite)
        name = row.add_text(44, 4, 170, 16, '', color: DARK)
        tag = row.add_sprite(258, 26, Montures.file('etiquette'))
        species = speed = tag_text = nil
        row.with_font(SMALL) do
          species = row.add_text(44, 24, 104, 13, '', color: DARK)
          speed = row.add_text(176, 6, 126, 13, '', 2, color: DARK)
          tag_text = row.add_text(258, 26, 44, 13, Montures.t('Montée', 'Riding'), 1, color: WHITE)
        end
        powers = Array.new(8) { |k| row.add_sprite(150 + k * 15, 25, Montures.file('pouvoirs')) }
        { stack: row, bg: bg, sel: sel, icon: icon, name: name, species: species, speed: speed, tag: tag, tag_text: tag_text,
          powers: powers }
      end
    end

    def refresh
      @top = @index - ROWS + 1 if @index >= @top + ROWS
      @top = @index if @index < @top
      current = Montures.current
      @counter.text = @list.empty? ? '' : "#{@index + 1} / #{@list.size}"
      @empty.visible = @list.empty?
      @rows.each_with_index do |row, i|
        mount = @list[@top + i]
        row[:stack].visible = !mount.nil?
        next unless mount

        row[:sel].visible = @top + i == @index
        row[:bg].visible = !row[:sel].visible
        row[:icon].data = Montures.pokemon(mount)
        row[:name].text = Montures.name(mount)
        species = Montures.species_name(mount)
        row[:species].text = species == Montures.name(mount) ? '' : species
        row[:speed].text = speed_text(mount)
        riding = current && current['id'] == mount['id']
        row[:tag].visible = row[:tag_text].visible = riding ? true : false
        list = mount['powers'].first(riding ? 7 : 8)
        row[:powers].each_with_index do |sprite, k|
          power = list[k]
          sprite.visible = !power.nil?
          sprite.src_rect.set(Montures::POWERS.keys.index(power) * 14, 0, 14, 14) if power
        end
      end
    end

    def speed_text(mount)
      speed = mount['speed'].to_i.clamp(1, 6)
      water = mount['water_only'] && Montures.water?(mount)
      place = water ? Montures.t('eau', 'water') : (Montures.water?(mount) ? Montures.t('terre et eau', 'land & water') : Montures.t('terre', 'land'))
      return "#{Montures.t('Vitesse', 'Speed')} #{speed} · #{place}"
    end
  end

  class Menu
    def open_mount
      call_scene(GamePlay::MonturesApp)
    end

    register_button(:open_mount) { Montures.available? } unless ACTION_LIST.include?(:open_mount)
  end
end

module Montures
  module_function

  # @return [String, nil] pourquoi on ne peut pas voler
  def refusal_fly
    return t('Impossible de voler ici.', "You can't fly here.") unless $game_switches[Yuki::Sw::Env_CanFly]
    return t('Impossible de voler sur l’eau.', "You can't fly from the water.") if $game_player.surfing?

    return nil
  end
end
