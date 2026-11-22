# encoding: utf-8
# Base secrète : la pièce
#   Flèches : déplacer le curseur   A : poser une décoration (case vide) / retirer ou déplacer (case occupée)
#   X : changer de fond   B : quitter
module GamePlay
  class BaseSecreteScene < GamePlay::BaseCleanUpdate
    B = ::BaseSecrete
    WHITE = 10
    DARK = 0
    PAGE = 7
    ROW_Y = 52
    ROW_STEP = 22

    def initialize
      super()
      @cx = B::GRID_W / 2
      @cy = B::GRID_H / 2
      @mode = :room
      @picked = nil
      @held = nil
    end

    def update_inputs
      case @mode
      when :room then update_room
      when :picker then update_picker
      end
      return true
    end

    def update_graphics
      @blink = (@blink || 0) + 1
      @cursor.visible = @mode == :room && (@blink / 20).even?
      return true
    end

    def dispose
      @decor&.each(&:dispose)
      @top_viewport&.dispose
      super
    end

    private

    # --- Pièce -----------------------------------------------------------------------------------------------
    def update_room
      if Input.repeat?(:LEFT) then move_cursor(-1, 0)
      elsif Input.repeat?(:RIGHT) then move_cursor(1, 0)
      elsif Input.repeat?(:UP) then move_cursor(0, -1)
      elsif Input.repeat?(:DOWN) then move_cursor(0, 1)
      elsif Input.trigger?(:X)
        B.next_theme
        refresh_background
        play_cursor_se
      elsif Input.trigger?(:A)
        confirm
      elsif Input.trigger?(:B)
        return cancel
      end
    end

    def cancel
      if @held
        B.placed << @held
        @held = nil
        refresh_decor
        play_cancel_se
      else
        play_cancel_se
        @running = false
      end
    end

    def move_cursor(dx, dy)
      @cx = (@cx + dx) % B::GRID_W
      @cy = (@cy + dy) % B::GRID_H
      play_cursor_se
      refresh_cursor
    end

    def confirm
      if @held
        return play_buzzer_se if B.at(@cx, @cy)

        @held['x'] = @cx
        @held['y'] = @cy
        B.placed << @held
        @held = nil
        refresh_decor
        play_decision_se
      elsif (entry = B.at(@cx, @cy))
        choice = display_message(B.t('Que faire ?', 'What to do?'), 1, B.t('Déplacer', 'Move'), B.t('Ranger', 'Put away'), B.t('Annuler', 'Cancel'))
        case choice
        when 0
          @held = B.placed.delete(entry)
          refresh_decor
        when 1
          B.remove(@cx, @cy)
          refresh_decor
        end
      else
        open_picker
      end
    end

    # --- Choix d'une décoration --------------------------------------------------------------------------------
    def open_picker
      @choices = B.choices
      if @choices.empty?
        display_message(B.t('Rien à poser : achetez des décorations dans les Magasins, ou gagnez des succès et des concours !',
                            'Nothing to place: buy decorations in the shops, or earn achievements and contests!'))
        return
      end
      if B.full?
        return display_message(B.t('La pièce ne peut plus accueillir d’objets.', 'The room cannot hold any more objects.'))
      end

      @mode = :picker
      @pindex = 0
      @pfirst = 0
      @picker.visible = true
      refresh_picker
    end

    def update_picker
      if Input.repeat?(:DOWN) then move_picker(1)
      elsif Input.repeat?(:UP) then move_picker(-1)
      elsif Input.trigger?(:B)
        close_picker
        play_cancel_se
      elsif Input.trigger?(:A)
        choice = @choices[@pindex]
        close_picker
        if B.place(choice, @cx, @cy)
          play_decision_se
          refresh_decor
        else
          play_buzzer_se
        end
      end
    end

    def close_picker
      @picker.visible = false
      @mode = :room
    end

    def move_picker(delta)
      @pindex = (@pindex + delta) % @choices.size
      @pfirst = @pindex < @pfirst ? @pindex : (@pindex >= @pfirst + PAGE ? @pindex - PAGE + 1 : @pfirst)
      play_cursor_se
      refresh_picker
    end

    # --- Affichage ---------------------------------------------------------------------------------------------
    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport)
      @back = @stack.add_sprite(0, 0, B.file(B.fetch(B.theme, 'image')))
      @title = @stack.add_text(6, 0, 308, 14, '', color: WHITE)
      @decor = []
      @cursor = @stack.add_sprite(0, 0, B.file('curseur'))
      @top_viewport = Viewport.create(:main, @viewport.z + 1)
      @picker = UI::SpriteStack.new(@top_viewport)
      @picker.add_sprite(12, 32, B.file('panneau'))
      @picker_title = @picker.add_text(20, 36, 280, 14, B.t('Poser…', 'Place…'), color: WHITE)
      @rows = Array.new(PAGE) do |i|
        y = ROW_Y + i * ROW_STEP
        back = @picker.add_sprite(22, y, B.file('ligne'))
        icon = @picker.add_sprite(24, y - 5, UI::SpriteStack::NO_INITIAL_IMAGE)
        text = @picker.add_text(52, y + 3, 244, 14, '', color: WHITE)
        [back, icon, text]
      end
      @picker.visible = false
      refresh_background
      refresh_decor
      refresh_cursor
    end

    def refresh_background
      @back.set_bitmap(B.file(B.fetch(B.theme, 'image')), :interface)
      @title.text = "#{B.localized(B.fetch(B.theme, 'name'))}  —  #{B.t('A : poser / ranger   X : fond   B : quitter', 'A: place / put away   X: theme   B: exit')}"
    end

    def refresh_cursor
      @cursor.set_position(@cx * B::CELL, B::TOP + @cy * B::CELL)
    end

    # Une décoration par case posée
    def refresh_decor
      @decor.each(&:dispose)
      @decor = B.placed.map { |entry| make_sprite(entry) }.compact
      @cursor.z = 50 if @cursor.respond_to?(:z=)
    end

    def make_sprite(entry)
      sprite = Sprite.new(@viewport)
      draw(sprite, entry['kind'], entry['id'])
      sprite.x += entry['x'] * B::CELL
      sprite.y += B::TOP + entry['y'] * B::CELL
      sprite.z = 10 + entry['y']
      return sprite
    rescue StandardError
      sprite&.dispose
      return nil
    end

    # Image d'une décoration, centrée dans une case de 32 x 32 (en 0, 0)
    def draw(sprite, kind, id)
      case kind
      when 'item'
        sprite.set_bitmap(data_item(id.to_sym).icon, :icon)
      when 'ach'
        achievement = ::Succes.all.find { |a| ::Succes.fetch(a, :id).to_s == id.to_s }
        ::Succes.draw_icon(sprite, achievement, 0, 0) if achievement
        return
      when 'contest'
        type, rank = id.split('_', 2)
        record = ::Concours.winner(type, rank)
        creature = record ? data_creature(record['species'].to_sym) : nil
        sprite.set_bitmap(PFM::Pokemon.icon_filename(creature.id, record['form'].to_i, false, record['shiny'] ? true : false, false), :b_icon) if creature
        sprite.src_rect.set(0, 0, sprite.bitmap.width / 2, sprite.bitmap.height) if sprite.bitmap
      end
      w = sprite.src_rect.width
      h = sprite.src_rect.height
      sprite.x = (B::CELL - w) / 2
      sprite.y = (B::CELL - h) / 2
    end

    def refresh_picker
      @rows.each_with_index do |(back, icon, text), i|
        choice = @choices[@pfirst + i]
        [back, icon, text].each { |sprite| sprite.visible = !choice.nil? }
        next unless choice

        back.set_bitmap(B.file(@pfirst + i == @pindex ? 'ligne_select' : 'ligne'), :interface)
        y = ROW_Y + i * ROW_STEP
        make_icon(icon, choice, 24, y - 5)
        label = choice['kind'] == 'item' ? "#{choice['name']}  ×#{choice['count']}" : "#{trophy_label(choice['kind'])} #{choice['name']}"
        text.text = label
      end
    end

    def trophy_label(kind)
      return kind == 'ach' ? B.t('Succès :', 'Achievement:') : B.t('Concours :', 'Contest:')
    end

    # Icône d'une ligne du choix
    def make_icon(sprite, choice, x, y)
      draw(sprite, choice['kind'], choice['id'])
      sprite.x += x
      sprite.y += y
      sprite.zoom = 0.75 if sprite.respond_to?(:zoom=)
    rescue StandardError
      sprite.visible = false
    end
  end
end
