# Montures : touche raccourci et roue des montures
#
# Sur la carte, la touche des montures (réglage key, R par défaut : touche G du clavier) :
#   - appui court : monter sur la dernière monture (une monture d'eau sur l'eau), ou descendre ;
#   - appui long (réglage hold_frames) : roue des montures (gauche / droite ou souris pour choisir, A pour monter,
#     B ou la touche pour fermer). « Descendre » est la première case quand le joueur est sur une monture.
module Montures
  module_function

  # Le joueur peut utiliser la touche maintenant
  def key_ready?
    return false unless available?
    return false if $game_system.map_interpreter.running? || $game_system.menu_disabled
    return false if $game_temp.message_window_showing || $game_player.moving? || $game_player.jumping?

    return $game_map.map_id != Configs.scene_title_config.intro_movie_map_id
  rescue StandardError
    return false
  end

  # Monture appelée par l'appui court
  # @return [Hash, nil]
  def quick_mount
    list = unlocked
    list = list.select { |m| water?(m) } if $game_player.surfing?
    list = list.select { |m| land?(m) } unless $game_player.surfing?
    return list.find { |m| m['id'] == data['last'] } || list.find { |m| m['id'] == data['land'] } || list.first
  end

  # Appui court : monter ou descendre
  # @return [String, nil] message d'erreur
  def toggle
    return leave if riding?

    mount = quick_mount
    return t('Aucune monture ne peut aller ici.', 'No mount can go here.') unless mount

    return call(mount)
  end
end

class Scene_Map
  module MonturesKey
    private

    def update_scene_calling
      super
      pj_update_mount_key if $scene == self && @running != false
    end

    def pj_update_mount_key
      key = Montures.key
      hold = Montures.setting('hold_frames').to_i.clamp(4, 120)
      if Input.press?(key)
        return @pj_mount_hold = 0 unless Montures.key_ready? || (@pj_mount_hold || 0) > 0

        @pj_mount_hold = (@pj_mount_hold || 0) + 1
        return unless @pj_mount_hold == hold

        @pj_mount_hold = -1
        $game_player.straighten
        call_scene(GamePlay::MonturesWheel)
      else
        held = @pj_mount_hold.to_i
        @pj_mount_hold = 0
        return unless held > 0 && held < hold && Montures.key_ready?

        error = Montures.toggle
        display_message(error) if error
      end
    end
  end
  prepend MonturesKey
end

module GamePlay
  # Roue des montures (par-dessus la carte)
  class MonturesWheel < BaseCleanUpdate
    WHITE = 9
    CENTER = [160, 120].freeze
    RADIUS = 86

    def initialize
      super()
      @items = []
      @items << :dismount if Montures.riding?
      @items.concat(Montures.unlocked)
      current = Montures.current
      @index = current ? @items.index { |m| m.is_a?(Hash) && m['id'] == current['id'] } || 0 : 0
      @tick = 0
    end

    def update_inputs
      if Input.trigger?(:B) || Input.trigger?(Montures.key) || Mouse.trigger?(:RIGHT)
        play_cancel_se
        return @running = false
      end
      return choose if Input.trigger?(:A)

      delta = (Input.repeat?(:RIGHT) || Input.repeat?(:DOWN) ? 1 : 0) - (Input.repeat?(:LEFT) || Input.repeat?(:UP) ? 1 : 0)
      return select((@index + delta) % @items.size) if delta != 0 && @items.size > 1

      return update_mouse_wheel
    end

    def update_graphics
      @tick += 1
      @cursor.opacity = 190 + (Math.sin(@tick / 6.0) * 60).round
      @icons.each { |icon| icon.update if icon.respond_to?(:update) }
      return true
    end

    private

    def update_mouse_wheel
      index = slot_at(Mouse.x, Mouse.y)
      return true unless index

      select(index) if index != @index && Mouse.moved
      choose if Mouse.trigger?(:LEFT)
      return true
    end

    def slot_at(x, y)
      @items.each_index do |i|
        sx, sy = slot_position(i)
        return i if (x - sx)**2 + (y - sy)**2 <= 17**2
      end
      return nil
    end

    def slot_position(index)
      angle = -Math::PI / 2 + 2 * Math::PI * index / [@items.size, 1].max
      return [CENTER[0] + (RADIUS * Math.cos(angle)).round, CENTER[1] + (RADIUS * Math.sin(angle)).round]
    end

    def select(index)
      play_cursor_se
      @index = index
      refresh
    end

    def choose
      item = @items[@index]
      return play_buzzer_se unless item

      current = Montures.current
      error = if item == :dismount || (current && item['id'] == current['id'])
                Montures.leave
              else
                Montures.call(item)
              end
      if error
        play_buzzer_se
        display_message(error)
      else
        play_decision_se
        @running = false
      end
    end

    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @stack.add_sprite(0, 0, Montures.file('roue_fond'))
      current = Montures.current
      @icons = []
      @items.each_with_index do |item, i|
        x, y = slot_position(i)
        @stack.add_sprite(x - 17, y - 17, Montures.file('case'))
        if item == :dismount
          @stack.add_sprite(x - 16, y - 16, Montures.file('descendre'))
        else
          icon = @stack.push(x, y - 2, nil, type: UI::PokemonIconSprite)
          icon.data = Montures.pokemon(item)
          @icons << icon
          @stack.add_sprite(x - 20, y - 20, Montures.file('montee')) if current && current['id'] == item['id']
        end
      end
      @cursor = @stack.add_sprite(0, 0, Montures.file('curseur'))
      @stack.add_sprite(100, 98, Montures.file('panneau'))
      @name = @stack.add_text(102, 101, 116, 16, '', 1, color: WHITE)
      @powers = Array.new(7) { @stack.add_sprite(0, 121, Montures.file('pouvoirs')) }
      @stack.with_font(20) do
        @empty = @stack.add_text(102, 120, 116, 13, '', 1, color: WHITE)
        @hint = @stack.add_text(0, 226, 320, 13, Montures.t('← → : choisir   A : monter / descendre   B : fermer',
                                                            '← → : choose   A: ride / get off   B: close'), 1, color: WHITE)
      end
      @stack.add_text(0, 112, 320, 16, Montures.t('Aucune monture', 'No mount'), 1, color: WHITE) if @items.empty?
      refresh
    end

    def refresh
      item = @items[@index]
      x, y = slot_position(@index)
      @cursor.set_position(x - 20, y - 20)
      @cursor.visible = !item.nil?
      if item == :dismount
        @name.text = Montures.t('Descendre', 'Get off')
        show_powers([])
      elsif item
        @name.text = Montures.name(item)
        show_powers(item['powers'])
      else
        @name.text = ''
        show_powers([])
      end
    end

    def show_powers(list)
      list = list.first(@powers.size)
      left = 160 - list.size * 8
      @powers.each_with_index do |sprite, i|
        power = list[i]
        sprite.visible = !power.nil?
        next unless power

        sprite.src_rect.set(Montures::POWERS.keys.index(power) * 14, 0, 14, 14)
        sprite.x = left + i * 16
      end
      @empty.text = list.empty? && @items[@index].is_a?(Hash) ? Montures.t('Promenade', 'Ride') : ''
    end
  end
end
