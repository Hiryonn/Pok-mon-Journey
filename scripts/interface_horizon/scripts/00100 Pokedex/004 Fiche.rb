# Pokédex Horizon : fiche d'un Pokémon
module UI
  module DexPE
    # Grand sprite du Pokémon + étiquette de nom (liste) ; dans l'état infos le nom passe dans le bandeau titre
    class FacePanel < SpriteStack
      # Décalage du sprite entre l'état liste et la fiche (cadre blanc à gauche de la fiche)
      INFO_OFFSET_X = 8
      INFO_OFFSET_Y = -53

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, DexPE.left, 0, default_cache: :pokedex)
        @sprite = add_sprite(52, 178, NO_INITIAL_IMAGE, type: PokemonFaceSprite)
        @ball = add_sprite(4, 191, DexPE.file('ball_on'))
        # Nom centré dans la partie sombre de l'étiquette (entre la Poké Ball et la coupe en biais)
        @name = add_text(20, 191, 76, 16, :name_upper, 1, type: SymText, color: WHITE)
        @name.bold = true
        @label_visible = true
      end

      def update_graphics
        @sprite.update
      end

      # @param view [GamePlay::Dex::CreatureView]
      def data=(view)
        super(view.pokemon)
        shown = view.displayed?
        @sprite.visible = shown
        @ball.set_bitmap(DexPE.file(view.caught ? 'ball_on' : 'ball_off'), :pokedex)
        @ball.visible = @name.visible = shown && @label_visible
      end

      # Place le panneau selon l'état
      # @param state [Integer]
      def layout=(state)
        state == 1 ? set_position(DexPE.left + INFO_OFFSET_X, INFO_OFFSET_Y) : set_position(DexPE.left, 0)
        @label_visible = state != 1
        @ball.visible = @name.visible = @label_visible && @sprite.visible
      end

      # @param value [Boolean]
      def visible=(value)
        super
        @ball.visible = @name.visible = false if value && !@label_visible
      end
    end

    # Fiche du Pokémon (état infos), d'après la maquette fournie : bandeau titre avec « Retour »,
    # types, tableau (espèce, taille, poids, rencontres), barre des formes, description et onglets
    # Habitat / Formes / Cri en bas (cliquables).
    class InfoPanel < SpriteStack
      TABLE_X = 128
      TABLE_Y = 40
      TABLE_STEP = 17
      # Zones cliquables => action de GamePlay::Dex (souris)
      NAV_Y = 219..236

      # Pages du plugin advanced_pokedex dans la barre du bas, entre Habitat et Cri : [page, action de la scène]
      ADVANCED_PAGES = [%i[data advanced_data], %i[tasks advanced_tasks], %i[height advanced_height], %i[weight advanced_weight]].freeze

      # @return [Boolean] si la barre du bas montre les pages Données / Tâches / Taille / Poids
      def self.advanced_pages?
        return defined?(::AdvancedPokedex) && defined?(GamePlay::AdvancedPokedex) ? true : false
      end

      # @return [Array] cases du milieu de la barre [x, largeur, action, page]
      def self.advanced_slots
        e = DexPE.extra
        width = (212 + e) / ADVANCED_PAGES.size.to_f
        return ADVANCED_PAGES.each_with_index.map { |(page, action), i| [(56 + i * width).round, width.floor, action, page] }
      end

      # @return [Array] zones de la barre du bas (x relatifs au bord gauche de l'écran)
      def self.nav_zones
        e = DexPE.extra
        middle = if advanced_pages?
                   advanced_slots.map { |x, width, action, _page| [x..(x + width - 1), action] }
                 else
                   [[56..(268 + e), :action_x]]
                 end
        return [[0..52, :action_a], *middle, [(272 + e)..(319 + e), :action_y]]
      end

      # @param page [Symbol]
      # @return [String]
      def self.advanced_label(page)
        return ::AdvancedPokedex::Data.text(:page) if page == :data && defined?(::AdvancedPokedex::Data)
        return $options.nil? || $options.language.to_s == 'fr' ? 'Tâches' : 'Tasks' if page == :tasks

        return ::AdvancedPokedex.label(page.to_s)
      rescue StandardError
        return page.to_s.capitalize
      end

      # @return [Array] zone du bouton Retour
      def self.back_zone
        return [(250 + DexPE.extra)..(319 + DexPE.extra), 0..21]
      end

      # @param viewport [Viewport]
      # @param form_name_symbol [Symbol]
      def initialize(viewport, form_name_symbol)
        super(viewport, DexPE.left, 0, default_cache: :pokedex)
        extra = DexPE.extra
        @form_name_symbol = form_name_symbol
        @ball = add_sprite(4, 4, DexPE.file('ball_on'))
        @title = add_text(40, 3, 136, 16, :pokedex_name, type: SymText, color: WHITE)
        @title.bold = true
        with_font(SMALL_FONT) { add_text(200 + extra, 5, 114, 13, "#{DexPE.label(:back)}  »", 2, color: WHITE) }
        @type1 = add_sprite(211 + extra, 22, NO_INITIAL_IMAGE, true, type: Type1Sprite)
        @type2 = add_sprite(267 + extra, 22, NO_INITIAL_IMAGE, true, type: Type2Sprite)
        @rows = %i[pokedex_species pokedex_height pokedex_weight].map.with_index do |method, i|
          add_text(TABLE_X, TABLE_Y + i * TABLE_STEP, 188 + extra, 16, method, type: SymText, color: WHITE)
        end
        @encountered = add_text(TABLE_X, TABLE_Y + 3 * TABLE_STEP, 188 + extra, 16, '', color: WHITE)
        @unknown = add_text(TABLE_X, TABLE_Y, 188 + extra, 16, '???', color: WHITE)
        @forms = add_text(124, 116, 196 + extra, 16, '', 1, color: WHITE)
        @description = add_text(5, 138, 310 + extra, 16, '', color: WHITE)
        @nav = [add_text(0, 220, 52, 16, DexPE.key_label(10), 1, color: WHITE)]
        if self.class.advanced_pages?
          # pages du plugin advanced_pokedex (Formes : touche X)
          with_font(SMALL_FONT) do
            self.class.advanced_slots.each do |x, width, _action, page|
              @nav << add_text(x, 221, width, 13, self.class.advanced_label(page), 1, color: WHITE)
            end
          end
        else
          @nav << add_text(56, 220, 212 + extra, 16, DexPE.key_label(11), 1, color: WHITE)
        end
        @nav << add_text(272 + extra, 220, 48, 16, DexPE.key_label(12), 1, color: WHITE)
        @single_page = false
      end

      # @param view [GamePlay::Dex::CreatureView]
      def data=(view)
        super(view.pokemon)
        pokemon = view.pokemon
        caught = view.caught
        @ball.set_bitmap(DexPE.file(caught ? 'ball_on' : 'ball_off'), :pokedex)
        [@type1, @type2, *@rows].each { |sprite| sprite.visible = false } unless caught
        @type2.visible = false if caught && pokemon.type2 == 0
        @unknown.visible = !caught
        @encountered.text = format(DexPE.label(:encountered), $pokedex&.creature_fought(pokemon.db_symbol).to_i)
        @forms.text = forms_text(pokemon)
        @description.multiline_text = view.description.to_s
        hide_single_page_nav
      end

      # @param value [Boolean]
      def visible=(value)
        super
        @unknown.visible = false if value && @rows.first.visible
        hide_single_page_nav
      end

      # Page seule (GamePlay::DexInfo) : seul « Cri » reste en bas
      def single_page!
        @single_page = true
        hide_single_page_nav
      end

      # Action déclenchée par un clic à cet endroit
      # @param mx [Integer]
      # @param my [Integer]
      # @return [Symbol, nil]
      def nav_action(mx, my)
        mx -= DexPE.left
        zone = self.class.back_zone
        return :action_b if zone[0].include?(mx) && zone[1].include?(my)
        return nil unless NAV_Y.include?(my)

        self.class.nav_zones.each_with_index do |(range, action), i|
          next if @single_page && (i == 0 || action == :action_x)

          return action if range.include?(mx)
        end
        return nil
      end

      private

      # Page seule : pas d'Habitat ni de Formes (les pages du plugin advanced_pokedex restent)
      def hide_single_page_nav
        return unless @single_page

        @nav[0].visible = false
        @nav[1].visible = false unless self.class.advanced_pages?
      end

      # Nom de la forme, ou « Aucune autre forme… » quand il n'y a rien à faire défiler avec X
      # @param pokemon [PFM::Pokemon]
      # @return [String]
      def forms_text(pokemon)
        options = GamePlay::Dex::Presenter.new.form_options(pokemon)
        return DexPE.label(:no_forms) if options.size <= 1

        return pokemon.public_send(@form_name_symbol).to_s
      rescue StandardError
        return ''
      end
    end

    # Page d'une créature (même interface que UI::Dex::CreaturePage)
    class CreaturePage < SpriteStack
      # @param viewport [Viewport]
      # @param form_name_symbol [Symbol]
      def initialize(viewport, form_name_symbol)
        super(viewport, default_cache: :pokedex)
        @face = FacePanel.new(viewport)
        @info = InfoPanel.new(viewport, form_name_symbol)
        @last_view = nil
      end

      # @param view [GamePlay::Dex::CreatureView]
      def face_data=(view)
        @face.data = view
      end

      # @param view [GamePlay::Dex::CreatureView]
      def details_data=(view)
        @last_view = view
        @info.data = view
      end

      # @param view [GamePlay::Dex::CreatureView]
      def data=(view)
        self.face_data = view
        self.details_data = view
      end

      # @param value [Boolean]
      def face_visible=(value)
        @face.visible = value
      end

      # @param value [Boolean]
      def details_visible=(value)
        @info.visible = value
        @info.data = @last_view if value && @last_view
      end

      # @param state [Integer]
      def layout=(state)
        @face.layout = state
      end

      # @return [Symbol, nil] action de la fiche sous la souris
      def nav_action(mx, my)
        return @info.visible ? @info.nav_action(mx, my) : nil
      end

      # Page seule (GamePlay::DexInfo)
      def single_page!
        @info.single_page!
      end

      def update_graphics
        @face.update_graphics
      end
    end
  end
end
