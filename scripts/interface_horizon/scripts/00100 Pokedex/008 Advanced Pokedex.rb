# Pokédex Horizon : habillage des pages Données, Tâches, Taille et Poids du plugin « advanced_pokedex »
#
# Utilisé automatiquement par GamePlay::AdvancedPokedex quand ce plugin et le Pokédex Horizon sont actifs
# (réglage « Habillage » de Studio : Plugins > Advanced Pokédex). Sans le plugin advanced_pokedex, ce fichier ne fait rien.
#
# Graphismes : graphics/pokedex/pe/adv_data, adv_tasks, adv_height, adv_weight (fonds 320x240 : bandeau, cadres blancs, bandes
# d'infos et barre du bas comme la fiche)
module UI
  module DexPE
    # Habillage PE (ajouté à la scène avec extend)
    module AdvancedTheme
      # Cadres de texte [x, y, largeur, décalage de la 2e ligne]
      BOXES = [[16, 177, 132, 16], [173, 177, 132, 16]].freeze
      # Barre du bas : [x, largeur, action] (mêmes cases que la fiche : 0-48, 52-268, 272-319)
      NAV = [[0, 48, :back], [52, 54, :data], [106, 54, :tasks], [160, 54, :height], [214, 54, :weight], [272, 48, :character]].freeze
      NAV_Y = 219..236
      # Couleur des onglets inactifs de la barre du bas
      INACTIVE = 11
      # Textes [français, anglais]
      TEXTS = { back: %w[Fiche Info], character: %w[Perso. Char.], moves: %w[Capac. Moves], more: %w[Suite More] }.freeze

      private

      def theme_background(page)
        return DexPE.file("adv_#{page}")
      end

      def theme_boxes
        return BOXES
      end

      def theme_text_color
        return WHITE
      end

      def theme_silhouette_color
        return ::AdvancedPokedex.get(:silhouette_color_pe)
      end

      def create_theme_graphics
        @pe_header = UI::SpriteStack.new(@viewport, default_cache: :pokedex)
        @pe_ball = @pe_header.add_sprite(4, 4, DexPE.file('ball_on'))
        @pe_title = @pe_header.add_text(40, 3, 136, 16, '', color: WHITE)
        @pe_title.bold = true
        @pe_page = @pe_header.with_font(SMALL_FONT) { @pe_header.add_text(200, 5, 114, 13, '', 2, color: WHITE) }
        @pe_nav = NAV.map do |x, width, action|
          text = @pe_header.add_text(x, 220, width, 16, '', 1, color: WHITE)
          [action, text]
        end
      end

      def refresh_theme
        caught = ::AdvancedPokedex.available?(@pokemon)
        @pe_ball.set_bitmap(DexPE.file(caught ? 'ball_on' : 'ball_off'), :pokedex)
        @pe_title.text = known? || seen? ? @pokemon.name.to_s : '???'
        @pe_page.text = pe_page_label(@page)
        lang = $options&.language == 'fr' ? 0 : 1
        @pe_nav.each do |action, text|
          case action
          when :data, :tasks, :height, :weight
            text.text = pe_page_label(action)
            text.load_color(action == @page ? WHITE : INACTIVE)
          when :character
            # Page Données : la case de droite ouvre les capacités ; page Tâches : tâches suivantes
            if @page == :tasks
              more = defined?(::AdvancedPokedex::Tasks) && ::AdvancedPokedex::Tasks.tasks_for(@pokemon.db_symbol).size > 5
              text.text = TEXTS[:more][lang]
              text.load_color(more ? WHITE : INACTIVE)
            else
              text.text = TEXTS[@page == :data ? :moves : :character][lang]
              text.load_color(@page == :data || @characters.size > 1 ? WHITE : INACTIVE)
            end
          else
            text.text = TEXTS[action][lang]
          end
        end
      end

      # @param page [Symbol]
      # @return [String]
      def pe_page_label(page)
        return ::AdvancedPokedex::Data.text(:page) if page == :data && defined?(::AdvancedPokedex::Data)
        return $options&.language.to_s == 'fr' || $options.nil? ? 'Tâches' : 'Tasks' if page == :tasks

        return ::AdvancedPokedex.label(page.to_s)
      end

      public

      # Clics : barre du bas (fiche, taille, poids, personnage) et cadre du personnage
      def update_mouse(moved)
        return false if @data_window&.open?
        # Page Données : clics sur les cadres (talents, évolutions) gérés par la page
        return super if @page == :data && Mouse.trigger?(:LEFT) && !NAV_Y.include?(Mouse.y)
        return true unless Mouse.trigger?(:LEFT)

        mx = Mouse.x
        my = Mouse.y
        if NAV_Y.include?(my)
          _, _, action = NAV.find { |x, width, _| mx.between?(x, x + width - 1) }
          case action
          when :back then close_to_info
          when :data, :tasks, :height, :weight then action == @page || !pages.include?(action) ? play_buzzer_se : change_page(action)
          when :character
            if @page == :data
              open_data_window(:moves)
            elsif @page == :tasks
              @tasks_ui&.more? ? (play_cursor_se; @tasks_ui.next_tasks) : play_buzzer_se
            else
              next_character
            end
          else return true
          end
          return false
        end
        return true if %i[data tasks].include?(@page) || !(my.between?(176, 211) && mx >= 163)

        next_character
        return false
      end
    end
  end
end
