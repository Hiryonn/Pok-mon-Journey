# Résumé PE : page Souvenirs (rubans et insignes, d'après « Improved Mementos » d'Essentials)
#
# A : choisir un souvenir, puis A dessus pour le menu :
#   Donner le titre / Retirer le titre, Déplacer (tri « Tous » : A sur la nouvelle place), Trier, Retour
# Tris : Tous, Rangs regroupés (seul le plus haut rang de chaque ruban est montré), Rubans, Insignes, Concours,
#        Ligue, Combat, Mémorial, Spécial (seuls ceux que le Pokémon possède sont proposés)
# Sans le plugin Souvenirs (scripts/mementos), la page garde le fonctionnement des rubans de PSDK.
module UI
  module SummaryPE
    LABELS[:ribbons] = %w[Souvenirs Mementos]
    LABELS[:mementos_ribbons] = ['Rubans :', 'Ribbons:']
    LABELS[:mementos_marks] = ['Insignes :', 'Marks:']
    LABELS[:mementos_title] = ['Titre :', 'Title:']
    LABELS[:mementos_none] = %w[aucun none]
    LABELS[:mementos_rank] = %w[Rang Rank]
    LABELS[:mementos_give] = ['Donner le titre', 'Confer title']
    LABELS[:mementos_remove] = ['Retirer le titre', 'Remove title']
    LABELS[:mementos_move] = %w[Déplacer Move]
    LABELS[:mementos_sort] = %w[Trier Sort]
    LABELS[:mementos_back] = %w[Retour Back]
    LABELS[:mementos_what] = ['Que faire avec %s ?', 'What to do with the %s?']
    LABELS[:mementos_sort_what] = ['Montrer quels souvenirs ?', 'Show which mementos?']
    LABELS[:mementos_titled] = ['%s porte maintenant le titre « %s ».', '%s is now known as %s.']

    # Ruban avec les sélecteurs du design (blanc = curseur, or = ruban qui donne le titre, bleu = ruban déplacé)
    class RibbonIcon < RibbonSprite
      def select_move(value)
        @move_selector.visible = value ? true : false
      end

      def data=(ribbon)
        super
        @move_selector.visible = false unless ribbon
      end

      private

      def create_sprites
        @ribbon = add_sprite(0, 0, NO_INITIAL_IMAGE)
        @selector = add_sprite(0, 0, SummaryPE.file('ribbon_selector'))
        @title_selector = add_sprite(0, 0, SummaryPE.file('ribbon_title'))
        @move_selector = add_sprite(0, 0, SummaryPE.file('memento_move'))
        @move_selector.visible = false
      end
    end

    # Page 4 : souvenirs, au style de la page Mémo
    class RibbonsPage < Summary_Ribbons
      # Grille des rubans dans la bande sombre de droite
      GRID_X = 140
      GRID_Y = 84
      RIBBON_ROWS = 2
      # Flèches de défilement
      ARROW_X = 224
      ARROW_UP_Y = 79
      ARROW_DOWN_Y = 166
      # Zone de texte dans le cadre gris
      INFO_X = 10
      INFO_Y = 54
      INFO_WIDTH = 100
      LINE_HEIGHT = 16
      SMALL_LINE = 12
      STAR_STEP = 10
      MAX_STARS = 5

      # @return [Array<PFM::Ribbon>] souvenirs montrés (selon le tri)
      attr_reader :list
      # @return [Symbol] tri en cours
      attr_reader :filter

      def initialize(viewport)
        @list = []
        @filter = :all
        super
      end

      # @param creature [PFM::Pokemon]
      def data=(creature)
        @filter = default_filter(creature)
        @moving = nil
        refresh_list(creature)
        super
      end

      def mementos?
        return defined?(::Mementos) ? true : false
      end

      def moving?
        return !@moving.nil?
      end

      def update_inputs
        return if @data.nil? || @list.empty?

        if Input.repeat?(:RIGHT)
          change_index(1)
        elsif Input.repeat?(:LEFT)
          change_index(-1)
        elsif Input.repeat?(:DOWN)
          change_index(COLUMNS)
        elsif Input.repeat?(:UP)
          change_index(-COLUMNS)
        end
      end

      def change_index(delta)
        next_index = (@ribbon_index + delta).clamp(0, @list.size - 1)
        return if next_index == @ribbon_index

        $game_system.se_play($data_system.cursor_se)
        @ribbon_index = next_index
        adjust_offset
        update_ribbons
      end

      # Garde le ruban sélectionné visible dans la grille de 2 lignes
      def adjust_offset
        return if @ribbon_index.negative?

        @offset += COLUMNS while @ribbon_index >= @offset + COLUMNS * RIBBON_ROWS
        @offset = [@offset - COLUMNS, 0].max while @ribbon_index < @offset
      end

      def update_ribbons
        return if @data.nil?

        refresh_list(@data) if @list.empty? && !@data.ribbons.empty?
        @ribbon_sprites.each_with_index do |sprite, index|
          ribbon = @list[@offset + index]
          sprite.data = ribbon
          sprite.visible = visible && ribbon ? true : false
          sprite.select(@offset + index == @ribbon_index)
          sprite.select_title(visible && ribbon && @data.title_ribbon == ribbon)
          sprite.select_move(visible && ribbon && @moving == @offset + index)
        end
        @no_ribbon_text.visible = visible && @list.empty?
        update_header
        update_description
      end

      # Ancien comportement de PSDK (A sur un ruban : titre), utilisé sans le plugin Souvenirs
      def set_title
        return play_buzzer_se unless (ribbon = @list[@ribbon_index])&.gives_title?

        play_decision_se
        @data.title_ribbon = @data.title_ribbon == ribbon ? nil : ribbon
        update_ribbons
      end

      # Menu du souvenir sélectionné (A)
      # @param scene [GamePlay::Summary]
      def memento_menu(scene)
        return set_title unless mementos?
        return finish_move if moving?
        return play_buzzer_se unless (ribbon = @list[@ribbon_index])

        play_decision_se
        ids = []
        if @data.title_ribbon == ribbon
          ids << :remove
        elsif ribbon.gives_title? && !scene_in_battle?(scene)
          ids << :give
        end
        ids << :move if @filter == :all && @list.size > 1
        ids << :sort << :back
        names = ids.map { |id| SummaryPE.label(:"mementos_#{id}") }
        choice = scene.display_message(format(SummaryPE.label(:mementos_what), ribbon.name), 1, *names)
        case ids[choice.to_i]
        when :give then give_title(scene, ribbon)
        when :remove
          @data.title_ribbon = nil
          update_ribbons
        when :move
          @moving = @ribbon_index
          update_ribbons
        when :sort then sort_menu(scene)
        end
      end

      # B pendant un déplacement : l'annule
      def cancel_move
        @moving = nil
        update_ribbons
      end

      private

      def scene_in_battle?(_scene)
        return $game_temp.in_battle ? true : false
      end

      def default_filter(creature)
        return :all unless mementos? && creature
        return :rank if Mementos.setting?('collapse_ranks') && creature.memento_type?(:rank)

        return :all
      end

      def refresh_list(creature = @data)
        @list = if creature.nil?
                  []
                elsif mementos?
                  creature.mementos(@filter)
                else
                  creature.ribbons.dup
                end
      end

      def give_title(scene, ribbon)
        @data.title_ribbon = ribbon
        update_ribbons
        scene.display_message(format(SummaryPE.label(:mementos_titled), @data.given_name, @data.given_name_with_title))
      end

      # Échange la place de deux souvenirs (tri « Tous » : la liste est celle du Pokémon)
      def finish_move
        from = @moving
        to = @ribbon_index
        @moving = nil
        ribbons = @data.ribbons
        if from && to && from != to && ribbons[from] && ribbons[to]
          ribbons[from], ribbons[to] = ribbons[to], ribbons[from]
          play_decision_se
        else
          play_cancel_se
        end
        refresh_list
        update_ribbons
      end

      def sort_menu(scene)
        filters = Mementos::FILTERS.select { |f| f == :all || @data.memento_type?(f) }
        names = filters.map { |f| f == @filter ? "» #{Mementos.filter_name(f)}" : Mementos.filter_name(f) }
        names << SummaryPE.label(:mementos_back)
        choice = scene.display_message(SummaryPE.label(:mementos_sort_what), 1, *names).to_i
        return if choice >= filters.size

        @filter = filters[choice]
        refresh_list
        @ribbon_index = @list.empty? ? -1 : 0
        @offset = 0
        update_ribbons
      end

      def init_sprites
        SummaryPE.widen_page(add_sprite(0, 0, SummaryPE.file('page_mementos')), 'page_mementos')
        @header_text = add_text(146, 64, 110, 16, SummaryPE.label(:ribbons), color: WHITE)
        @count_text = add_text(250 + SummaryPE.extra, 64, 62, 16, '', 2, color: WHITE)
        RIBBON_ROWS.times do |row|
          COLUMNS.times do |col|
            @ribbon_sprites << add_sprite(GRID_X + SummaryPE.extra / 2 + col * SPACING_X, GRID_Y + row * SPACING_Y, NO_INITIAL_IMAGE, type: RibbonIcon)
          end
        end
        @arrow_up = add_sprite(ARROW_X + SummaryPE.extra / 2, ARROW_UP_Y, SummaryPE.file('memento_arrow_up'))
        @arrow_down = add_sprite(ARROW_X + SummaryPE.extra / 2, ARROW_DOWN_Y, SummaryPE.file('memento_arrow_down'))
        @name_text = add_text(INFO_X, INFO_Y, INFO_WIDTH, 16, '', color: DARK)
        @name_text.bold = true
        with_font(SMALL_FONT) do
          @kind_text = add_text(INFO_X, INFO_Y, INFO_WIDTH, 13, '', color: DARK)
          @description_text = add_text(INFO_X, INFO_Y, INFO_WIDTH, 13, '', color: DARK)
          @title_text = add_text(INFO_X, INFO_Y, INFO_WIDTH, 13, '', color: DARK)
        end
        @stars = Array.new(MAX_STARS) { add_sprite(0, 0, SummaryPE.file('memento_star')) }
        @no_ribbon_text = add_text(146, 112, 168 + SummaryPE.extra, 16, text_get(74, 52), 1, color: WHITE)
      end

      # Tri et nombre de souvenirs dans la bande sombre
      def update_header
        @header_text.text = mementos? && @filter != :all ? Mementos.filter_name(@filter) : SummaryPE.label(:ribbons)
        @count_text.text = if @list.empty?
                             ''
                           elsif @ribbon_index >= 0
                             "#{@ribbon_index + 1}/#{@list.size}"
                           else
                             @list.size.to_s
                           end
        @arrow_up.visible = visible && @offset > 0
        @arrow_down.visible = visible && @offset + COLUMNS * RIBBON_ROWS < @list.size
      end

      # Dans le cadre gris : le souvenir sélectionné, ou le bilan du Pokémon
      def update_description
        return if @data.nil?

        @stars.each { |star| star.visible = false }
        return update_overview if @ribbon_index.negative? || @list.empty?

        ribbon = @list[@ribbon_index]
        y = INFO_Y
        y = place(@name_text, ribbon.name, y, LINE_HEIGHT) + 1
        y = place(@kind_text, kind_line(ribbon), y, SMALL_LINE)
        y = place_stars(ribbon, y)
        y = place(@description_text, ribbon.description, y + 2, SMALL_LINE) + 4
        title = ribbon.title.to_s.empty? ? SummaryPE.label(:mementos_none) : build_title(ribbon)
        place(@title_text, "#{SummaryPE.label(:mementos_title)} #{title}", y, SMALL_LINE)
      end

      def update_overview
        return [@name_text, @kind_text, @description_text, @title_text].each { |text| text.text = '' } if @data.ribbons.empty?

        marks = mementos? ? @data.ribbons.count(&:mark?) : 0
        y = place(@name_text, @data.given_name.to_s, INFO_Y, LINE_HEIGHT) + 2
        counts = "#{SummaryPE.label(:mementos_ribbons)} #{@data.ribbons.size - marks}"
        counts += "\n#{SummaryPE.label(:mementos_marks)} #{marks}" if mementos?
        y = place(@kind_text, counts, y, SMALL_LINE) + 4
        y = place(@description_text, SummaryPE.label(:mementos_title), y, SMALL_LINE)
        title = @data.title? ? @data.given_name_with_title : SummaryPE.label(:mementos_none)
        place(@title_text, title, y, SMALL_LINE)
      end

      # « Insigne · Humeur »
      def kind_line(ribbon)
        return '' unless mementos?

        return "#{Mementos.kind_name(ribbon)} · #{Mementos.category_name(ribbon)}"
      end

      # Étoiles du rang (« Rang 12/40 » au-delà de 5 rangs)
      def place_stars(ribbon, y)
        return y unless mementos? && ribbon.max_rank > 1

        rank = @data.memento_rank(ribbon)
        if ribbon.max_rank > MAX_STARS
          return place(@kind_text, "#{kind_line(ribbon)}\n#{SummaryPE.label(:mementos_rank)} #{rank}/#{ribbon.max_rank}", @kind_text.y + Text::Util::FOY, SMALL_LINE)
        end

        ribbon.max_rank.times do |i|
          star = @stars[i]
          star.set_bitmap(SummaryPE.file(i < rank ? 'memento_star' : 'memento_star_off'), :interface)
          star.set_position(INFO_X + i * STAR_STEP, y + 1)
          star.visible = visible
        end
        return y + 11
      end

      # Écrit un texte (sur plusieurs lignes si besoin) et renvoie la position sous lui
      def place(text, content, y, line_height)
        text.y = y - Text::Util::FOY
        text.multiline_text = content.to_s
        return y + line_height * (text.text.count("\n") + 1)
      end

      # Titre complet (« Pikachu l'Affamé », « Pikachu de Sacha »)
      def build_title(ribbon)
        return Mementos.full_title(ribbon, @data) if mementos?

        return "#{@data.given_name} #{ribbon.title}"
      end
    end
  end
end
