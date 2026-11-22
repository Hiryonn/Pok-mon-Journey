# Succès : la scène (liste par catégorie, puis fiche du succès), aux couleurs du Pokédex Horizon
#
# Liste : haut / bas = succès, gauche / droite = catégorie, A = fiche, B = quitter
# Fiche : haut / bas = succès précédent / suivant, B = retour à la liste
# Souris : molette, clic sur un succès (re-clic = fiche), clic droit = retour
module GamePlay
  class Succes < BaseCleanUpdate::FrameBalanced
    S = ::Succes
    DARK = 0
    WHITE = 9
    SMALL = 20
    BG = 'horizon/team/fond'
    HEADER = 'horizon/header'
    FOOTER = 'horizon/tcard/button_background'
    TITLE_X = 96
    TITLE_W = 128
    TITLE_Y = 5
    LIST_X = 6
    LIST_Y = 30
    ROW_HEIGHT = 36
    ROWS = 5
    # Texte de l'objectif selon la condition : [français, anglais] (%{n} = valeur, %{target} = nom)
    GOALS = {
      'dex_seen' => ['Voir %{n} Pokémon', 'See %{n} Pokémon'],
      'dex_caught' => ['Capturer %{n} Pokémon', 'Catch %{n} Pokémon'],
      'species' => ['Capturer %{target}', 'Catch %{target}'],
      'badges' => ['Obtenir %{n} badge(s)', 'Earn %{n} badge(s)'],
      'money' => ['Avoir %{n} P', 'Have %{n} P'],
      'item' => ['Avoir %{target} x%{n}', 'Have %{target} x%{n}'],
      'level' => ['Un Pokémon au niveau %{n}', 'A Pokémon at level %{n}'],
      'steps' => ['Faire %{n} pas', 'Walk %{n} steps'],
      'play_time' => ['Jouer %{n} heure(s)', 'Play %{n} hour(s)'],
      'quests' => ['Terminer %{n} quête(s)', 'Complete %{n} quest(s)'],
      'berries' => ['Trouver %{n} baie(s)', 'Find %{n} berries'],
      'achievements' => ['Obtenir %{n} autre(s) succès', 'Unlock %{n} other achievement(s)'],
      'variable' => ['Progression', 'Progress'],
      'counter' => ['Progression', 'Progress']
    }.freeze

    def initialize(category = nil)
      super()
      S.check_all
      @tabs = [nil] + S.categories.map { |c| S.fetch(c, :id).to_s }.select { |id| S.all.any? { |a| S.fetch(a, :category).to_s == id } }
      @tab = [@tabs.index(category&.to_s) || 0, 0].max
      @index = 0
      @top = 0
      @mode = :list
      filter
    end

    def update_inputs
      return @mode == :list ? update_list_inputs : update_card_inputs
    end

    def update_mouse(_moved)
      if Mouse.trigger?(:RIGHT)
        back
        return false
      end
      if Mouse.wheel != 0
        delta = -Mouse.wheel
        Mouse.wheel = 0
        select(@index + (delta <=> 0))
        return false
      end
      return true unless Mouse.trigger?(:LEFT) && @mode == :list

      row = row_at(Mouse.x, Mouse.y)
      return true unless row

      row == @index ? open_card : select(row)
      return false
    end

    def update_graphics
      return true
    end

    private

    # Succès de la catégorie affichée
    def filter
      tab = @tabs[@tab]
      @list = tab ? S.all.select { |a| S.fetch(a, :category).to_s == tab } : S.all
      @index = @index.clamp(0, [@list.size - 1, 0].max)
    end

    def update_list_inputs
      if Input.trigger?(:B)
        back
      elsif Input.trigger?(:A)
        open_card
      elsif Input.repeat?(:DOWN)
        select(@index + 1 >= @list.size ? 0 : @index + 1, wrap: true)
      elsif Input.repeat?(:UP)
        select(@index - 1 < 0 ? @list.size - 1 : @index - 1, wrap: true)
      elsif Input.repeat?(:RIGHT) || Input.repeat?(:LEFT)
        change_tab(Input.repeat?(:RIGHT) ? 1 : -1)
      end
      return false
    end

    def update_card_inputs
      if Input.trigger?(:B) || Input.trigger?(:A)
        back
      elsif Input.repeat?(:DOWN)
        select(@index + 1 >= @list.size ? 0 : @index + 1, wrap: true)
      elsif Input.repeat?(:UP)
        select(@index - 1 < 0 ? @list.size - 1 : @index - 1, wrap: true)
      end
      return false
    end

    def back
      play_cancel_se
      return @running = false if @mode == :list

      @mode = :list
      refresh
    end

    def open_card
      return play_buzzer_se if @list.empty?

      play_decision_se
      @mode = :card
      refresh
    end

    def change_tab(delta)
      return if @tabs.size < 2

      play_cursor_se
      @tab = (@tab + delta) % @tabs.size
      @index = @top = 0
      filter
      refresh
    end

    def select(index, wrap: false)
      index = index.clamp(0, [@list.size - 1, 0].max) unless wrap
      return if index == @index || @list.empty?

      play_cursor_se
      @index = index
      refresh
    end

    def current
      return @list[@index]
    end

    # @return [Integer, nil] succès sous la souris
    def row_at(x, y)
      return nil unless x.between?(LIST_X, LIST_X + 307) && y >= LIST_Y

      row = (y - LIST_Y) / ROW_HEIGHT
      return nil if row >= ROWS || (y - LIST_Y) % ROW_HEIGHT >= 34

      index = @top + row
      return index < @list.size ? index : nil
    end

    # Succès secret pas encore obtenu
    def hidden?(achievement)
      return S.secret?(achievement) && !S.unlocked?(S.fetch(achievement, :id))
    end

    # --- Graphismes ------------------------------------------------------------------
    def create_graphics
      super
      create_frame
      create_rows
      create_card
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
        bg.bitmap = Bitmap.new(320, 240)
        bg.bitmap.fill_rect(0, 0, 320, 240, Color.new(229, 243, 250))
        bg.bitmap.update
      end
      picture(@frame, 0, 0, HEADER)
      picture(@frame, 0, 214, FOOTER)
      @title = @frame.add_text(TITLE_X, TITLE_Y, TITLE_W, 16, '', 1, color: WHITE)
      @left_arrow = picture(@frame, TITLE_X - 12, 6, 'quest/arrow_frame_l')
      @right_arrow = picture(@frame, TITLE_X + TITLE_W + 4, 6, 'quest/arrow_frame_r')
      @frame.with_font(SMALL) do
        @score = @frame.add_text(6, 7, 84, 13, '', color: WHITE)
        @counter = @frame.add_text(232, 7, 82, 13, '', 2, color: WHITE)
        @help = @frame.add_text(8, 220, 304, 13, '', 1, color: WHITE)
      end
    end

    def create_rows
      @rows = Array.new(ROWS) do |i|
        row = stack(LIST_X, LIST_Y + i * ROW_HEIGHT)
        bg = row.add_sprite(0, 0, S.file('row'))
        row.add_sprite(2, 1, S.file('frame'))
        icon = row.add_sprite(2, 1, UI::SpriteStack::NO_INITIAL_IMAGE)
        lock = row.add_sprite(6, 5, S.file('lock'))
        name = row.add_text(40, 2, 190, 16, '', color: DARK)
        descr = progress = date = points = nil
        points_bg = row.add_sprite(272, 3, S.file('points'))
        row.with_font(SMALL) do
          descr = row.add_text(40, 19, 190, 13, '', color: DARK)
          progress = row.add_text(236, 3, 36, 13, '', color: DARK)
          date = row.add_text(232, 19, 70, 13, '', 2, color: DARK)
          points = row.add_text(272, 3, 30, 14, '', 1, color: WHITE)
        end
        check = row.add_sprite(254, 3, S.file('check'))
        bar = row.add_sprite(236, 22, S.file('bar'))
        fill = row.add_sprite(237, 23, S.file('bar_fill'))
        { stack: row, bg: bg, icon: icon, lock: lock, name: name, descr: descr, progress: progress, date: date,
          points: points, points_bg: points_bg, check: check, bar: bar, fill: fill }
      end
      @empty = stack.add_text(0, 110, 320, 16, S.t('Aucun succès', 'No achievements'), 1, color: DARK)
    end

    def create_card
      @card = stack(LIST_X, LIST_Y + 2)
      @card.add_sprite(0, 0, S.file('card'))
      @card.add_sprite(10, 10, S.file('frame'))
      @card_icon = @card.add_sprite(10, 10, UI::SpriteStack::NO_INITIAL_IMAGE)
      @card_lock = @card.add_sprite(14, 14, S.file('lock'))
      @card_name = @card.add_text(50, 8, 210, 16, '', color: DARK)
      @card_points_bg = @card.add_sprite(268, 10, S.file('points'))
      @card.with_font(SMALL) do
        @card_category = @card.add_text(50, 26, 210, 13, '', color: DARK)
        @card_points = @card.add_text(268, 10, 30, 14, '', 1, color: WHITE)
        @card_descr = @card.add_text(10, 50, 288, 13, '', color: DARK)
        @card_goal = @card.add_text(10, 118, 200, 13, '', color: DARK)
        @card_progress = @card.add_text(200, 118, 98, 13, '', 2, color: DARK)
        @card_reward = @card.add_text(10, 144, 288, 13, '', color: DARK)
        @card_date = @card.add_text(10, 160, 288, 13, '', color: DARK)
      end
      @card_bar = @card.add_sprite(6, 132, S.file('bar_big'))
      @card_fill = @card.add_sprite(7, 133, S.file('bar_big_fill'))
    end

    # --- Mise à jour -----------------------------------------------------------------
    def refresh
      list = @mode == :list
      @rows.each { |r| r[:stack].visible = list }
      @card.visible = !list && !current.nil?
      @empty.visible = list && @list.empty?
      tabs = @tabs.size > 1 && list
      [@left_arrow, @right_arrow].compact.each { |arrow| arrow.visible = tabs }
      tab = @tabs[@tab]
      @title.text = tab ? S.category_name(tab) : S.t('SUCCÈS', 'ACHIEVEMENTS')
      @counter.text = "#{@list.count { |a| S.unlocked?(S.fetch(a, :id)) }} / #{@list.size}"
      @score.text = "#{S.total_points} pts"
      @help.text = if list
                     tabs ? S.t('A : Détails   < > : Catégorie   B : Quitter', 'A: Details   < >: Category   B: Quit') : S.t('A : Détails   B : Quitter', 'A: Details   B: Quit')
                   else
                     S.t('Haut / Bas : Succès   B : Retour', 'Up / Down: Achievement   B: Back')
                   end
      list ? refresh_rows : refresh_card
    end

    def refresh_rows
      @top = @index if @index < @top
      @top = @index - ROWS + 1 if @index >= @top + ROWS
      @top = @top.clamp(0, [@list.size - ROWS, 0].max)
      @rows.each_with_index do |row, i|
        achievement = @list[@top + i]
        row[:stack].visible = !achievement.nil?
        next unless achievement

        refresh_row(row, achievement, @top + i == @index)
      end
    end

    def refresh_row(row, achievement, selected)
      id = S.fetch(achievement, :id)
      done = S.unlocked?(id)
      secret = hidden?(achievement)
      row[:bg].set_bitmap(S.file(selected ? 'row_selected' : (done ? 'row_done' : 'row')), :interface)
      row[:lock].visible = secret
      row[:icon].visible = false
      S.draw_icon(row[:icon], achievement, row[:stack].x + 2, row[:stack].y + 1) unless secret
      row[:icon].opacity = done ? 255 : 110
      row[:name].text = secret ? S.t('Succès secret', 'Secret achievement') : S.name(achievement)
      row[:descr].text = secret ? '???' : short(S.descr(achievement), 36)
      points = S.points(achievement)
      row[:points].visible = row[:points_bg].visible = points > 0
      row[:points].text = points.to_s
      row[:check].visible = done
      row[:date].text = done ? date_text(S.unlock_time(id)) : ''
      progress = done || secret ? nil : S.progress(achievement)
      row[:progress].text = progress ? "#{progress[0]}/#{progress[1]}" : ''
      row[:bar].visible = row[:fill].visible = !progress.nil?
      row[:fill].src_rect.width = progress ? (62 * progress[0] / [progress[1], 1].max) : 0
    end

    def refresh_card
      achievement = current
      return unless achievement

      id = S.fetch(achievement, :id)
      done = S.unlocked?(id)
      secret = hidden?(achievement)
      @card_lock.visible = secret
      @card_icon.visible = false
      S.draw_icon(@card_icon, achievement, @card.x + 10, @card.y + 10) unless secret
      @card_icon.opacity = done ? 255 : 110
      @card_name.text = secret ? S.t('Succès secret', 'Secret achievement') : S.name(achievement)
      category = S.category_name(S.fetch(achievement, :category))
      @card_category.text = category
      points = S.points(achievement)
      @card_points.visible = @card_points_bg.visible = points > 0
      @card_points.text = points.to_s
      @card_descr.multiline_text = secret ? S.t('Continue ton aventure pour découvrir ce succès.', 'Keep playing to discover this achievement.') : small(S.descr(achievement))
      @card_goal.text = secret ? '' : goal_text(achievement)
      progress = secret ? nil : S.progress(achievement)
      progress = [progress[1], progress[1]] if progress && done
      @card_progress.text = progress ? "#{progress[0]} / #{progress[1]}" : ''
      @card_bar.visible = @card_fill.visible = !progress.nil?
      @card_fill.src_rect.width = progress ? (294 * progress[0] / [progress[1], 1].max) : 0
      reward = S.reward_text(achievement)
      @card_reward.text = reward.empty? || secret ? '' : small(S.t("Récompense : #{reward}", "Reward: #{reward}"))
      time = S.unlock_time(id)
      @card_date.text = done && time ? S.t("Obtenu le #{date_text(time)} à #{time.strftime('%H:%M')}", "Unlocked on #{date_text(time)} at #{time.strftime('%H:%M')}") : S.t('Pas encore obtenu', 'Not unlocked yet')
    end

    # @return [String]
    def goal_text(achievement)
      type = S.condition_type(achievement)
      texts = GOALS[type]
      return '' unless texts

      target = S.fetch(S.condition(achievement), :target).to_s
      name = case type
             when 'species' then (data_creature(target.to_sym).name rescue target)
             when 'item' then (data_item(target.to_sym).name rescue target)
             else target
             end
      return small(format(S.t(texts[0], texts[1]), n: S.goal(achievement), target: name))
    end

    def date_text(time)
      return '' unless time

      return S.t(time.strftime('%d/%m/%Y'), time.strftime('%Y-%m-%d'))
    end

    # Coupe un texte trop long pour une ligne
    def short(text, max)
      text = small(text).tr("\n", ' ')
      return text.size > max ? "#{text[0, max - 3].rstrip}..." : text
    end

    # La petite police n'a pas l'apostrophe typographique
    def small(text)
      return text.to_s.tr('’‘', "''")
    end
  end
end
