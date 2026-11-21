# Étui à badges : la scène, aux couleurs Horizon
#
# Étui   : flèches = badge, L / R (ou gauche / droite au bord) = région, A = fiche du badge, B = quitter
# Fiche  : gauche / droite = badge précédent / suivant, A / B = retour à l'étui
# Souris : clic sur un badge (re-clic = fiche), molette = badge, clic sur les flèches = région, clic droit = retour
# Obtention (GamePlay::EtuiBadges.new(region, obtain: :id)) : le badge grossit avec des éclats, A / B pour fermer
module GamePlay
  class EtuiBadges < BaseCleanUpdate::FrameBalanced
    E = ::EtuiBadges
    DARK = 0
    WHITE = 9
    SMALL = 20
    BG = 'horizon/team/fond'
    HEADER = 'horizon/header'
    FOOTER = 'horizon/tcard/button_background'
    TITLE_X = 96
    TITLE_W = 128
    TRAY_X = 10
    TRAY_Y = 32
    TRAY_W = 300
    TRAY_H = 146
    SLOT = 48
    BADGE = 40
    COLUMNS = 4
    INFO_X = 6
    INFO_Y = 182
    # Fiche du badge
    NAME_Y = 34
    ACE_Y = 168
    PANEL_X = 132
    PANEL_Y = 34
    TABLE_X = 139
    TABLE_Y = 40
    TABLE_W = 172
    ROW_H = 19
    LABEL_W = 74
    VALUE_X = 215
    VALUE_W = 95
    STAGE_Y = 124
    STAGE_H = 82
    # Objet donné à UI::TypeSprite (il lit #type)
    TypeHolder = Struct.new(:type)

    # @param region [Integer, nil] région affichée (nil = celle du premier badge qui manque)
    # @param obtain [Symbol, String, nil] badge à montrer en grand (« Badge obtenu ! »)
    def initialize(region = nil, obtain: nil)
      super()
      @regions = E.regions
      @obtain = obtain ? E.badge(obtain) : nil
      region = E.region_of(@obtain) if @obtain
      region ||= @regions.find { |r| E.count(r) < E.region_badges(r).size } || @regions.first
      @region = [@regions.index(region.to_i) || 0, 0].max
      @index = @obtain ? (E.region_badges(region).index(@obtain) || 0) : 0
      @mode = @obtain ? :obtain : :tray
      @frame_count = 0
    end

    def update_inputs
      case @mode
      when :obtain then update_obtain_inputs
      when :card then update_card_inputs
      else update_tray_inputs
      end
      return false
    end

    def update_mouse(_moved)
      if Mouse.trigger?(:RIGHT)
        back
        return false
      end
      return true if @mode == :obtain

      if Mouse.wheel != 0
        delta = -Mouse.wheel
        Mouse.wheel = 0
        select((@index + (delta <=> 0)) % [badges.size, 1].max)
        return false
      end
      return true unless Mouse.trigger?(:LEFT)

      if Mouse.y < 26 && @regions.size > 1 && @mode == :tray
        change_region(Mouse.x < 160 ? -1 : 1) if Mouse.x < TITLE_X || Mouse.x > TITLE_X + TITLE_W
        return false
      end
      return true unless @mode == :tray

      slot = slot_at(Mouse.x, Mouse.y)
      return true unless slot

      slot == @index ? open_card : select(slot)
      return false
    end

    def update_graphics
      @frame_count += 1
      @cursor.src_rect.x = (@frame_count / 20).even? ? 0 : 52 if @cursor&.bitmap
      update_obtain_animation if @mode == :obtain
      return true
    end

    private

    # Badges de la région affichée
    def badges
      region = @regions[@region]
      return region ? E.region_badges(region) : []
    end

    def current
      return badges[@index]
    end

    def update_tray_inputs
      list = badges
      if Input.trigger?(:B)
        back
      elsif Input.trigger?(:A)
        open_card
      elsif Input.trigger?(:L) || Input.trigger?(:R)
        change_region(Input.trigger?(:R) ? 1 : -1)
      elsif Input.repeat?(:RIGHT)
        if (@index + 1) % columns == 0 || @index + 1 >= list.size
          @regions.size > 1 ? change_region(1) : select(@index - @index % columns)
        else
          select(@index + 1)
        end
      elsif Input.repeat?(:LEFT)
        if @index % columns == 0
          @regions.size > 1 ? change_region(-1, last: true) : select([@index + columns - 1, list.size - 1].min)
        else
          select(@index - 1)
        end
      elsif Input.repeat?(:DOWN) || Input.repeat?(:UP)
        next_index = @index + (Input.repeat?(:DOWN) ? columns : -columns)
        select(next_index % [list.size, 1].max) if rows > 1
      end
    end

    def update_card_inputs
      if Input.trigger?(:B) || Input.trigger?(:A)
        back
      elsif Input.repeat?(:RIGHT) || Input.repeat?(:DOWN)
        select((@index + 1) % [badges.size, 1].max)
      elsif Input.repeat?(:LEFT) || Input.repeat?(:UP)
        select((@index - 1) % [badges.size, 1].max)
      end
    end

    def update_obtain_inputs
      return unless @frame_count > 30 && (Input.trigger?(:A) || Input.trigger?(:B))

      play_decision_se
      @running = false
    end

    def back
      if @mode == :obtain
        @running = false if @frame_count > 30
        return
      end
      play_cancel_se
      return @running = false if @mode == :tray

      @mode = :tray
      refresh
    end

    # La fiche d'un badge pas obtenu ne s'ouvre que si le réglage le permet
    def open_card
      badge = current
      return play_buzzer_se unless badge && (E.obtained?(badge) || E.setting?(:show_unobtained))

      play_decision_se
      @mode = :card
      refresh
    end

    def change_region(delta, last: false)
      return if @regions.size < 2

      play_cursor_se
      @region = (@region + delta) % @regions.size
      @index = last ? [badges.size - 1, 0].max : 0
      refresh
    end

    def select(index)
      return if index == @index || badges.empty?

      badge = badges[index]
      return if @mode == :card && !(E.obtained?(badge) || E.setting?(:show_unobtained)) && !skip_to(index)

      play_cursor_se
      @index = index
      refresh
    end

    # Dans la fiche, passe les badges qu'on ne peut pas voir
    def skip_to(index)
      list = badges
      step = index == (@index + 1) % list.size ? 1 : -1
      list.size.times do
        index = (index + step) % list.size
        next unless E.obtained?(list[index]) || E.setting?(:show_unobtained)
        return false if index == @index

        play_cursor_se
        @index = index
        refresh
        return false
      end
      return false
    end

    # --- Placement des emplacements -----------------------------------------------------------
    def columns
      return badges.size <= 4 ? [badges.size, 1].max : COLUMNS
    end

    def rows
      return badges.size <= 4 ? 1 : 2
    end

    # @return [Array(Integer, Integer)] coin haut gauche de l'emplacement
    def slot_position(index)
      col = index % columns
      row = index / columns
      cell_w = TRAY_W / columns
      cell_h = TRAY_H / rows
      return [TRAY_X + col * cell_w + (cell_w - SLOT) / 2, TRAY_Y + row * cell_h + (cell_h - SLOT) / 2]
    end

    def slot_at(x, y)
      badges.size.times do |i|
        sx, sy = slot_position(i)
        return i if x.between?(sx, sx + SLOT - 1) && y.between?(sy, sy + SLOT - 1)
      end
      return nil
    end

    # --- Graphismes ----------------------------------------------------------------------------
    def create_graphics
      super
      create_frame
      create_tray
      create_info
      create_card
      create_obtain
      if @obtain
        me = E.setting(:obtain_me).to_s
        Audio.me_play(me) unless me.empty?
      end
      refresh
    end

    def stack(x = 0, y = 0)
      return UI::SpriteStack.new(@viewport, x, y, default_cache: :interface)
    end

    def picture(stack, x, y, name)
      return nil unless RPG::Cache.interface_exist?(name)

      return stack.add_sprite(x, y, name)
    end

    def create_frame
      @frame = stack
      unless picture(@frame, 0, 0, BG)
        bg = @frame.add_sprite(0, 0, UI::SpriteStack::NO_INITIAL_IMAGE)
        image = Image.new(320, 240)
        image.fill_rect(0, 0, 320, 240, Color.new(229, 243, 250))
        bg.bitmap = image.copy_to_bitmap(Bitmap.new(320, 240))
        image.dispose
      end
      picture(@frame, 0, 0, HEADER)
      picture(@frame, 0, 214, FOOTER)
      @title = @frame.add_text(TITLE_X, 5, TITLE_W, 16, '', 1, color: WHITE)
      @left_arrow = picture(@frame, TITLE_X - 12, 6, 'quest/arrow_frame_l')
      @right_arrow = picture(@frame, TITLE_X + TITLE_W + 4, 6, 'quest/arrow_frame_r')
      @frame.with_font(SMALL) do
        @total = @frame.add_text(6, 7, 84, 13, '', color: WHITE)
        @counter = @frame.add_text(232, 7, 82, 13, '', 2, color: WHITE)
        @help = @frame.add_text(8, 220, 304, 13, '', 1, color: WHITE)
      end
    end

    def create_tray
      @tray = stack
      @tray.add_sprite(TRAY_X, TRAY_Y, E.file('tray'))
      @slots = Array.new(8) { @tray.add_sprite(0, 0, E.file('slot')) }
      @badge_sprites = Array.new(8) { @tray.add_sprite(0, 0, UI::SpriteStack::NO_INITIAL_IMAGE, type: Sprite::WithColor) }
      @cursor = @tray.add_sprite(0, 0, E.file('cursor'))
      @cursor.src_rect.width = 52 if @cursor.bitmap
      @empty = @tray.add_text(0, 100, 320, 16, E.t('Aucun badge', 'No badges'), 1, color: DARK)
    end

    def create_info
      @info = stack(INFO_X, INFO_Y)
      @info.add_sprite(0, 0, E.file('info'))
      @info_name = @info.add_text(8, 1, 190, 16, '', color: DARK)
      @info.with_font(SMALL) do
        @info_location = @info.add_text(8, 16, 190, 13, '', color: DARK)
        @info_date = @info.add_text(196, 3, 104, 13, '', 2, color: DARK)
        @info_leader = @info.add_text(196, 16, 104, 13, '', 2, color: DARK)
      end
    end

    # Fiche : onglet du nom, badge en grand et Pokémon fétiche à gauche ; tableau et champion à droite
    def create_card
      @card = stack
      @card.add_sprite(0, NAME_Y, E.file('card_name'))
      @card.add_sprite(12, 62, E.file('card_badge'))
      @card_badge = @card.add_sprite(22, 72, UI::SpriteStack::NO_INITIAL_IMAGE, type: Sprite::WithColor)
      @card_ace_tab = @card.add_sprite(0, ACE_Y, E.file('card_ace'))
      @card_ace = @card.add_sprite(8, ACE_Y + 5, UI::SpriteStack::NO_INITIAL_IMAGE)
      @card.add_sprite(PANEL_X, PANEL_Y, E.file('card_panel'))
      @card.add_sprite(TABLE_X, TABLE_Y, E.file('card_table'))
      @card.add_sprite(TABLE_X, STAGE_Y, E.file('card_stage'))
      @card_leader = @card.add_sprite(0, 0, UI::SpriteStack::NO_INITIAL_IMAGE)
      @card_name = @card.add_text(4, NAME_Y + 3, 114, 16, '', 1, color: DARK)
      @card_ace_name = @card.add_text(46, ACE_Y + 27, 74, 16, '', 1, color: DARK)
      labels = [E.t('Obtenu le', 'Obtained'), E.t('Type', 'Type'), E.t('Lieu', 'Location'), E.t('Champion', 'Leader')]
      @card_values = []
      @card.with_font(SMALL) do
        @card_ace_label = @card.add_text(46, ACE_Y + 3, 74, 13, E.t('POKÉMON', 'ACE'), 1, color: DARK)
        @card_ace_label2 = @card.add_text(46, ACE_Y + 13, 74, 13, E.t('FÉTICHE', 'POKÉMON'), 1, color: DARK)
        labels.each_with_index do |label, i|
          y = TABLE_Y + 1 + i * (ROW_H + 1) + 3
          @card.add_text(TABLE_X + 1, y, LABEL_W, 13, label, 1, color: WHITE)
          @card_values << @card.add_text(VALUE_X, y, VALUE_W, 13, '', 1, color: DARK)
        end
      end
      @card_type = @card.add_sprite(VALUE_X + (VALUE_W - 32) / 2, TABLE_Y + ROW_H + 4, UI::SpriteStack::NO_INITIAL_IMAGE, type: UI::TypeSprite)
    end

    def create_obtain
      @obtain_ui = stack
      @obtain_shines = Array.new(8) { @obtain_ui.add_sprite(160, 110, E.file('shine')) }
      @obtain_shines.each { |s| s.set_origin(7, 7) }
      @obtain_badge = @obtain_ui.add_sprite(160, 110, UI::SpriteStack::NO_INITIAL_IMAGE)
      @obtain_name = @obtain_ui.add_text(0, 176, 320, 16, '', 1, color: DARK)
      @obtain_ui.with_font(SMALL) do
        @obtain_where = @obtain_ui.add_text(0, 194, 320, 13, '', 1, color: DARK)
      end
    end

    # --- Mise à jour -----------------------------------------------------------------------
    def refresh
      tray = @mode == :tray
      card = @mode == :card && current
      obtain = @mode == :obtain
      @tray.visible = tray
      @info.visible = tray
      @card.visible = card ? true : false
      @obtain_ui.visible = obtain
      arrows = @regions.size > 1 && tray
      [@left_arrow, @right_arrow].compact.each { |arrow| arrow.visible = arrows }
      region = @regions[@region]
      @title.text = if obtain then E.t('BADGE OBTENU !', 'BADGE OBTAINED!')
                    elsif card then E.t('INFOS DU BADGE', 'BADGE INFO')
                    else region ? E.region_name(region).upcase : E.t('BADGES', 'BADGES')
                    end
      @total.text = obtain || card ? '' : E.t("Total : #{E.count}", "Total: #{E.count}")
      @counter.text = if obtain || !region then ''
                      elsif card then E.t("N° #{E.number_of(current)}", "No. #{E.number_of(current)}")
                      else "#{E.count(region)} / #{badges.size}"
                      end
      @help.text = help_text(arrows)
      return refresh_obtain if obtain
      return refresh_card if card

      refresh_tray
      refresh_info
    end

    def help_text(arrows)
      case @mode
      when :obtain then E.t('A : Continuer', 'A: Continue')
      when :card then E.t('< > : Badge   B : Retour', '< >: Badge   B: Back')
      else
        arrows ? E.t('A : Détails   L / R : Région   B : Quitter', 'A: Details   L / R: Region   B: Quit') : E.t('A : Détails   B : Quitter', 'A: Details   B: Quit')
      end
    end

    def refresh_tray
      list = badges
      @empty.visible = list.empty?
      @slots.each_with_index do |slot, i|
        badge = list[i]
        sprite = @badge_sprites[i]
        slot.visible = sprite.visible = !badge.nil?
        next unless badge

        x, y = slot_position(i)
        slot.set_position(x, y)
        draw_badge(sprite, badge, x + (SLOT - BADGE) / 2, y + (SLOT - BADGE) / 2)
      end
      @cursor.visible = !list.empty?
      x, y = slot_position(@index)
      @cursor.set_position(x - 2, y - 2)
    end

    # Badge, version pas obtenue (image _off ou silhouette)
    def draw_badge(sprite, badge, x, y, size = BADGE)
      obtained = E.obtained?(badge)
      file, silhouette = E.image(badge, obtained)
      sprite.set_position(x, y)
      unless file
        sprite.visible = false
        return
      end
      sprite.set_bitmap(file, :interface)
      sprite.visible = true
      sprite.color = silhouette && !obtained ? [0.1, 0.15, 0.25, 0.85] : [0, 0, 0, 0]
      sprite.opacity = obtained ? 255 : 170
      zoom = size.to_f / [sprite.bitmap.width, 1].max
      sprite.zoom = zoom
    end

    def refresh_info
      badge = current
      @info.visible = !badge.nil?
      return unless badge

      obtained = E.obtained?(badge)
      @info_name.text = obtained || E.setting?(:name_always) ? E.name(badge) : '???'
      location = E.location(badge)
      @info_location.text = E.small(obtained || E.setting?(:location_always) ? location : '???')
      time = E.obtained_time(badge)
      @info_date.text = obtained ? (time ? E.date_text(time) : E.t('Obtenu', 'Obtained')) : E.t('Pas encore obtenu', 'Not obtained yet')
      leader = E.leader(badge)
      @info_leader.text = !leader.empty? && (obtained || E.setting?(:leader_always)) ? E.small(leader) : ''
    end

    def refresh_card
      badge = current
      obtained = E.obtained?(badge)
      draw_badge(@card_badge, badge, 22, 72, BADGE * 2)
      @card_name.text = obtained || E.setting?(:name_always) ? E.name(badge) : '???'
      time = E.obtained_time(badge)
      @card_values[0].text = obtained ? (time ? E.date_text(time) : '-') : '???'
      type = E.type(badge)
      show_type = type && (obtained || E.setting?(:type_always))
      @card_values[1].text = show_type ? '' : (type ? '???' : '-')
      @card_type.visible = show_type ? true : false
      @card_type.data = TypeHolder.new(type) if show_type
      @card_values[2].text = E.small(obtained || E.setting?(:location_always) ? fallback(E.location(badge)) : '???')
      leader_known = obtained || E.setting?(:leader_always)
      @card_values[3].text = E.small(leader_known ? fallback(E.leader(badge)) : '???')
      refresh_ace(badge, leader_known)
      refresh_leader(badge, leader_known)
    end

    def fallback(text)
      return text.to_s.empty? ? '-' : text
    end

    # Onglet du Pokémon fétiche (caché s'il n'y en a pas)
    def refresh_ace(badge, known)
      ace = E.ace(badge)
      @card_ace_tab.visible = @card_ace_label.visible = @card_ace_label2.visible = @card_ace_name.visible = !ace.nil?
      @card_ace.visible = !ace.nil? && known
      return unless ace

      @card_ace_name.text = known ? E.small(E.ace_name(badge)) : '???'
      return unless known

      creature = data_creature(ace)
      @card_ace.set_bitmap(PFM::Pokemon.icon_filename(creature.id, 0, false, false, false), :b_icon)
      w = @card_ace.bitmap.width
      h = @card_ace.bitmap.height
      @card_ace.src_rect.set(0, 0, w > h ? h : w, h)
    rescue StandardError
      @card_ace.visible = false
    end

    # Champion debout sur le sol quadrillé, centré
    def refresh_leader(badge, known)
      image = known ? E.leader_image(badge) : nil
      @card_leader.visible = !image.nil?
      return unless image

      @card_leader.set_bitmap(image[0], image[1] == :battler ? :battler : :interface)
      w = @card_leader.bitmap.width
      h = @card_leader.bitmap.height
      zoom = [80.0 / [w, h, 1].max, 1].min
      @card_leader.zoom = zoom
      @card_leader.set_position(TABLE_X + (TABLE_W - (w * zoom).round) / 2, STAGE_Y + STAGE_H - 2 - (h * zoom).round)
    end

    # --- Obtention -----------------------------------------------------------------------------
    def refresh_obtain
      badge = @obtain
      file, = E.image(badge, true)
      @obtain_badge.visible = !file.nil?
      if file
        @obtain_badge.set_bitmap(file, :interface)
        @obtain_badge.set_origin(@obtain_badge.bitmap.width / 2, @obtain_badge.bitmap.height / 2)
      end
      @obtain_name.text = E.name(badge)
      location = E.location(badge)
      leader = E.leader(badge)
      where = [location, leader.empty? ? nil : E.t("Champion : #{leader}", "Leader: #{leader}")].compact.reject(&:empty?)
      @obtain_where.text = E.small(where.join('  -  '))
      update_obtain_animation
    end

    def update_obtain_animation
      t = @frame_count
      grow = [t / 24.0, 1].min
      if @obtain_badge.bitmap
        target = 96.0 / [@obtain_badge.bitmap.width, 1].max
        @obtain_badge.zoom = target * (0.2 + 0.8 * grow) * (1 + (t < 24 ? 0 : 0.04 * Math.sin(t / 8.0)))
      end
      @obtain_shines.each_with_index do |shine, i|
        angle = (i * 45 + t * 2) * Math::PI / 180
        radius = 30 + 34 * grow
        shine.set_position(160 + (Math.cos(angle) * radius).round, 110 + (Math.sin(angle) * radius).round)
        shine.opacity = t < 12 ? 0 : (155 + 100 * Math.sin((t + i * 10) / 6.0)).round.clamp(0, 255)
      end
    end
  end
end
