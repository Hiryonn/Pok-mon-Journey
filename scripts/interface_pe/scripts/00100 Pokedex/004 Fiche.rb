# Pokédex PE : fiche d'un Pokémon
module UI
  module DexPE
    # Grand sprite du Pokémon + étiquette de nom (liste) ; dans l'état infos le nom passe dans le bandeau titre
    class FacePanel < SpriteStack
      # Décalage du sprite entre l'état liste et la fiche (cadre blanc à gauche de la fiche)
      INFO_OFFSET_X = 8
      INFO_OFFSET_Y = -53

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 0, 0, default_cache: :pokedex)
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
        state == 1 ? set_position(INFO_OFFSET_X, INFO_OFFSET_Y) : set_position(0, 0)
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
      NAV = [[0..52, :action_a], [56..268, :action_x], [272..319, :action_y]]
      BACK_ZONE = [250..319, 0..21]

      # @param viewport [Viewport]
      # @param form_name_symbol [Symbol]
      def initialize(viewport, form_name_symbol)
        super(viewport, 0, 0, default_cache: :pokedex)
        @form_name_symbol = form_name_symbol
        @ball = add_sprite(4, 4, DexPE.file('ball_on'))
        @title = add_text(40, 3, 136, 16, :pokedex_name, type: SymText, color: WHITE)
        @title.bold = true
        with_font(SMALL_FONT) { add_text(200, 5, 114, 13, "#{DexPE.label(:back)}  »", 2, color: WHITE) }
        @type1 = add_sprite(211, 22, NO_INITIAL_IMAGE, true, type: Type1Sprite)
        @type2 = add_sprite(267, 22, NO_INITIAL_IMAGE, true, type: Type2Sprite)
        @rows = %i[pokedex_species pokedex_height pokedex_weight].map.with_index do |method, i|
          add_text(TABLE_X, TABLE_Y + i * TABLE_STEP, 188, 16, method, type: SymText, color: WHITE)
        end
        @encountered = add_text(TABLE_X, TABLE_Y + 3 * TABLE_STEP, 188, 16, '', color: WHITE)
        @unknown = add_text(TABLE_X, TABLE_Y, 188, 16, '???', color: WHITE)
        @forms = add_text(124, 116, 196, 16, '', 1, color: WHITE)
        @description = add_text(5, 138, 310, 16, '', color: WHITE)
        @nav = [[0, 52, 10], [56, 212, 11], [272, 48, 12]].map do |x, width, text_id|
          add_text(x, 220, width, 16, DexPE.key_label(text_id), 1, color: WHITE)
        end
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
        return :action_b if BACK_ZONE[0].include?(mx) && BACK_ZONE[1].include?(my)
        return nil unless NAV_Y.include?(my)

        NAV.each_with_index do |(range, action), i|
          next if @single_page && i < 2

          return action if range.include?(mx)
        end
        return nil
      end

      private

      def hide_single_page_nav
        @nav[0].visible = @nav[1].visible = false if @single_page
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
