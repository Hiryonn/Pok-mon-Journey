# Pokédex style Noir & Blanc pour Pokémon Journey
#
# Remplace l'habillage du Pokédex de PSDK (GamePlay::Dex et GamePlay::DexInfo) sans toucher à sa logique :
# navigation, filtres, formes, cris, carte, souris restent ceux de PSDK.
#
# Graphismes : graphics/pokedex/bw/
#   bg_list / bg_info / bg_map : fonds 320x240 (bandeau POKÉDEX, cadres, tableau, zone de description)
#   row / row_selected / row_unseen : lignes de la liste (212x38)
#   pill_caught / pill_seen : pastilles « capturés » et « rencontrés » d'une ligne
#   ball_on / ball_off : Poké Ball allumée (capturé) ou éteinte (vu seulement)
#   scroll_track / scroll_thumb : barre de défilement
#   intro_bg / device_closed / device_open : petite animation d'ouverture
#
# Pour revenir au Pokédex d'origine : passer ENABLED à false (ou supprimer ce fichier).
module UI
  module DexBW
    # Active ou non le Pokédex BW
    ENABLED = true
    # Joue l'animation d'ouverture (appareil qui s'ouvre) en entrant dans le Pokédex
    PLAY_INTRO = true
    # Dossier des graphismes (dans graphics/pokedex/)
    PATH = 'bw/'
    # Fond affiché pour chaque état du Pokédex (0 = liste, 1 = infos, 2 = carte)
    PAGES = %w[bg_list bg_info bg_map]
    # Couleur de texte claire (texte blanc avec ombre) et sombre
    WHITE = 10
    DARK = 0
    # Police fine (PowerGreenSmall) utilisée pour les petits chiffres
    SMALL_FONT = 20

    # Textes de la fiche absents des fichiers de PSDK : [français, anglais]
    LABELS = {
      back: ['Retour', 'Back'],
      no_forms: ['Aucune autre forme…', 'No known forms...'],
      encountered: ['Rencontrés : %d', 'Encountered: %d']
    }

    # Charge un graphisme BW
    # @param name [String]
    # @return [String]
    def self.file(name)
      return "#{PATH}#{name}"
    end

    # @param key [Symbol]
    # @return [String]
    def self.label(key)
      return LABELS[key][$options&.language == 'fr' ? 0 : 1]
    end

    # Libellé d'une touche du Pokédex sans le « : » de PSDK (ex. « : habitat » -> « Habitat »)
    # @param text_id [Integer] texte du fichier 9000
    # @return [String]
    def self.key_label(text_id)
      text = ext_text(9000, text_id).to_s.sub(/\A[:\s]+/, '')
      return text[0].to_s.upcase + text[1..].to_s
    end

    # Base de l'interface (fond + barre de boutons du bas)
    class BaseUI < GenericBaseMultiMode
      # Change le fond affiché
      # @param name [String] nom du fond dans graphics/pokedex/bw/
      def page=(name)
        @background.set_bitmap(DexBW.file(name), :pokedex)
      end

      # Pas de barre de boutons : une bande bleue est dessinée dans le fond à la place
      # @param value [Array<String>]
      def button_texts=(value)
        super
        hide_bottom_buttons
      end

      def hide_win_text
        super
        hide_bottom_buttons
      end

      private

      def hide_bottom_buttons
        @ctrl&.each { |button| button.visible = false }
        @button_background&.visible = false
      end

      def create_background
        @background = add_sprite(0, 0, NO_INITIAL_IMAGE).set_z(-10)
        @background.set_bitmap(DexBW.file(PAGES.first), :pokedex)
        create_background_animation
      end

      # Le fond BW est fixe (pas de défilement comme le fond générique)
      def create_background_animation
        @background_animation = nil
        @on_update_background_animation = nil
      end
    end

    # Ligne de la liste : hexagone avec l'icône, numéro, nom et pastilles capturés / rencontrés
    class Row < SpriteStack
      # Largeur et hauteur d'une ligne
      WIDTH = 212
      HEIGHT = 38
      # Position des pastilles dans la ligne
      PILL_X = 166
      PILL_CAUGHT_Y = 4
      PILL_SEEN_Y = 20
      # Zone du numéro et du nom
      TEXT_X = 36
      TEXT_WIDTH = 128

      # @param viewport [Viewport]
      # @param x [Integer]
      # @param y [Integer]
      def initialize(viewport, x, y)
        super(viewport, x, y, default_cache: :pokedex)
        create_sprites
        @selected = nil
        @unseen = nil
      end

      # Affiche une entrée du Pokédex
      # @param view [GamePlay::Dex::CreatureView]
      # @param number [Integer] numéro dans le Pokédex courant
      # @param caught_count [Integer] nombre de captures de l'espèce
      # @param seen_count [Integer] nombre de rencontres de l'espèce
      # @param selected [Boolean] si la ligne est sélectionnée
      def set_entry(view, number, caught_count, seen_count, selected)
        seen = view.displayed?
        apply_look(selected, !seen)
        @number.text = format('N°%03d', number)
        @name.text = seen ? view.pokemon.name : '???'
        @icon.visible = seen
        @icon.data = view.pokemon if seen
        [@pill_caught, @pill_seen, @caught_count, @seen_count].each { |sprite| sprite.visible = seen }
        @caught_count.text = caught_count.to_s
        @seen_count.text = seen_count.to_s
      end

      private

      # Change le fond et la couleur des textes selon l'état
      # @param selected [Boolean]
      # @param unseen [Boolean]
      def apply_look(selected, unseen)
        return if @selected == selected && @unseen == unseen

        @selected = selected
        @unseen = unseen
        @background.set_bitmap(DexBW.file(selected ? 'row_selected' : (unseen ? 'row_unseen' : 'row')), :pokedex)
        color = selected ? DARK : WHITE
        @number.load_color(color)
        @name.load_color(color)
      end

      def create_sprites
        @background = add_background(DexBW.file('row'))
        @icon = add_sprite(17, 19, NO_INITIAL_IMAGE, type: PokemonIconSprite)
        # Numéro et nom centrés dans la bande, entre l'hexagone (x 34) et les pastilles (x 166)
        with_font(SMALL_FONT) { @number = add_text(TEXT_X, 5, TEXT_WIDTH, 13, '', 1, color: WHITE) }
        @name = add_text(TEXT_X, 18, TEXT_WIDTH, 16, '', 1, color: WHITE)
        @pill_caught = add_sprite(PILL_X, PILL_CAUGHT_Y, DexBW.file('pill_caught'))
        @pill_seen = add_sprite(PILL_X, PILL_SEEN_Y, DexBW.file('pill_seen'))
        with_font(SMALL_FONT) do
          @caught_count = add_text(PILL_X + 12, PILL_CAUGHT_Y + 1, 26, 13, '0', 1, color: WHITE)
          @seen_count = add_text(PILL_X + 12, PILL_SEEN_Y + 1, 26, 13, '0', 1, color: WHITE)
        end
      end
    end

    # Barre de défilement verticale (même interface que UI::Dex::ScrollBar)
    class ScrollBar < SpriteStack
      # @return [Integer]
      attr_reader :index
      # @return [Integer]
      attr_reader :max_index
      BASE_X = 316
      BASE_Y = 34
      # Course du curseur (hauteur de la piste - hauteur du curseur)
      HEIGHT = 164

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, BASE_X, BASE_Y, default_cache: :pokedex)
        add_background(DexBW.file('scroll_track'))
        @button = add_sprite(0, 0, DexBW.file('scroll_thumb'))
        @index = 0
        @max_index = 1
      end

      # @param value [Integer]
      def index=(value)
        @index = value.clamp(0, @max_index)
        @button.y = BASE_Y + HEIGHT * @index / @max_index
      end

      # @param value [Integer]
      def max_index=(value)
        @max_index = value <= 0 ? 1 : value
        self.index = 0
      end

      # @return [Integer, nil]
      def mouse_index
        return nil unless simple_mouse_in?

        return drag_mouse_index
      end

      # @return [Integer]
      def drag_mouse_index
        _, local_y = translate_mouse_coords
        return (local_y * @max_index / HEIGHT).clamp(0, @max_index)
      end
    end

    # Compteurs globaux « PRIS » / « VUS » en haut à gauche de la liste
    class Counters < SpriteStack
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 0, 34, default_cache: :pokedex)
        with_font(SMALL_FONT) do
          add_text(2, 4, 44, 13, ext_text(9000, 21), 2, color: WHITE)
          add_text(2, 20, 44, 13, ext_text(9000, 20), 2, color: WHITE)
          @caught = add_text(60, 4, 26, 13, '0', 1, color: WHITE)
          @seen = add_text(60, 20, 26, 13, '0', 1, color: WHITE)
        end
      end

      # @param seen [Integer]
      # @param caught [Integer]
      def update_counts(seen, caught)
        @seen.text = seen.to_s
        @caught.text = caught.to_s
      end
    end

    # Composition de l'état « liste » (même interface que UI::Dex::DexListComposition)
    class ListComposition < SpriteStack
      # Nombre de lignes visibles
      BUTTON_COUNT = 5
      # Position de la première ligne et écart entre deux lignes
      ROW_X = 104
      ROW_Y = 32
      ROW_STEP = 36
      # Index de la ligne où reste la sélection quand la liste défile
      CURSOR_SLOT = 2
      # @return [ScrollBar]
      attr_reader :scrollbar
      # @return [Array<Row>]
      attr_reader :buttons
      # @return [Counters]
      attr_reader :seen_got

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport)
        @buttons = Array.new(BUTTON_COUNT) { |slot| Row.new(viewport, ROW_X, ROW_Y + slot * ROW_STEP) }
        @scrollbar = ScrollBar.new(viewport)
        @seen_got = Counters.new(viewport)
        # Cadre d'origine de PSDK, gardé pour la carte (état 2)
        @map_frame = Sprite.new(viewport)
        @map_frame.set_bitmap('frame', :pokedex)
      end

      def update; end

      # @return [Boolean]
      def done?
        return true
      end

      # @param state [Integer] 0 = liste, 1 = infos, 2 = carte
      def change_state(state)
        list = state == 0
        @buttons.each { |row| row.visible = list }
        @scrollbar.visible = list
        @seen_got.visible = list
        @map_frame.visible = state == 2
      end

      # @param selected_creatures [Array<Studio::Dex::CreatureInfo>]
      # @param pokemonlist [PFM::Pokemon]
      # @param index [Integer]
      # @param visible [Boolean]
      # @param presenter [GamePlay::Dex::Presenter]
      def update_list(selected_creatures, pokemonlist, index, visible, presenter)
        size = selected_creatures.size
        update_scrollbar(size, index, visible)
        base_index = calc_base_index(size, index)
        @buttons.each_with_index do |row, slot|
          position = base_index + slot
          creature = selected_creatures[position]
          row.visible = (visible && creature && position >= 0) ? true : false
          next unless row.visible

          presenter.configure_creature(pokemonlist, creature)
          view = presenter.view_for(pokemonlist)
          caught_count, seen_count = presenter.bw_entry_counts(pokemonlist)
          row.set_entry(view, presenter.bw_dex_number(pokemonlist, position), caught_count, seen_count, position == index)
        end
      end

      # @param seen [Integer]
      # @param caught [Integer]
      def update_seen_got(seen, caught)
        @seen_got.update_counts(seen, caught)
      end

      # Premier index affiché : la sélection reste sur la ligne du milieu, sans laisser de trou en haut ou en bas
      # @param size [Integer]
      # @param index [Integer]
      # @return [Integer]
      def calc_base_index(size, index)
        return 0 if size <= BUTTON_COUNT

        return (index - CURSOR_SLOT).clamp(0, size - BUTTON_COUNT)
      end

      # @return [Integer, nil]
      def mouse_hovered_slot
        @buttons.each_with_index do |row, slot|
          return slot if row.visible && row.simple_mouse_in?
        end
        return nil
      end

      private

      def update_scrollbar(size, index, visible)
        @scrollbar.visible = visible && size > 1
        return unless @scrollbar.visible

        @scrollbar.max_index = size - 1
        @scrollbar.index = index
      end
    end

    # Grand sprite du Pokémon + étiquette de nom (liste) ; dans l'état infos le nom passe dans le bandeau titre
    class FacePanel < SpriteStack
      # Décalage du sprite entre l'état liste et la fiche (cadre blanc à gauche de la fiche)
      INFO_OFFSET_X = 8
      INFO_OFFSET_Y = -53

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 0, 0, default_cache: :pokedex)
        @sprite = add_sprite(52, 178, NO_INITIAL_IMAGE, type: PokemonFaceSprite)
        @ball = add_sprite(4, 191, DexBW.file('ball_on'))
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
        @ball.set_bitmap(DexBW.file(view.caught ? 'ball_on' : 'ball_off'), :pokedex)
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
        @ball = add_sprite(4, 4, DexBW.file('ball_on'))
        @title = add_text(40, 3, 136, 16, :pokedex_name, type: SymText, color: WHITE)
        @title.bold = true
        with_font(SMALL_FONT) { add_text(200, 5, 114, 13, "#{DexBW.label(:back)}  »", 2, color: WHITE) }
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
          add_text(x, 220, width, 16, DexBW.key_label(text_id), 1, color: WHITE)
        end
        @single_page = false
      end

      # @param view [GamePlay::Dex::CreatureView]
      def data=(view)
        super(view.pokemon)
        pokemon = view.pokemon
        caught = view.caught
        @ball.set_bitmap(DexBW.file(caught ? 'ball_on' : 'ball_off'), :pokedex)
        [@type1, @type2, *@rows].each { |sprite| sprite.visible = false } unless caught
        @type2.visible = false if caught && pokemon.type2 == 0
        @unknown.visible = !caught
        @encountered.text = format(DexBW.label(:encountered), $pokedex&.creature_fought(pokemon.db_symbol).to_i)
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
        return DexBW.label(:no_forms) if options.size <= 1

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

    # Animation d'ouverture : l'appareil apparaît, s'ouvre puis laisse place au Pokédex
    class Intro
      # Durée totale (secondes)
      DURATION = 0.9
      # Centre de l'appareil à l'écran
      CENTER = [160, 128]

      # @param viewport [Viewport]
      def initialize(viewport)
        @background = Sprite.new(viewport)
        @background.set_bitmap(DexBW.file('intro_bg'), :pokedex)
        @device = Sprite.new(viewport)
        @device.set_bitmap(DexBW.file('device_closed'), :pokedex)
        @device.set_origin(28, 28)
        @device.set_position(*CENTER)
        @background.z = 20_000
        @device.z = 20_001
        @opened = false
        self.progress = 0
        @animation = Yuki::Animation.scalar(DURATION, self, :progress=, 0.0, 1.0)
        @animation.start
        Audio.se_play('audio/se/se_gui_pokedex_open') rescue nil
      end

      def update
        return if @disposed

        @animation.update
        dispose if @animation.done?
      end

      # @return [Boolean]
      def done?
        return @disposed == true
      end

      # Passe directement à la fin
      def skip
        dispose
      end

      # @param value [Float] avancement de 0 à 1
      def progress=(value)
        return if @disposed

        if value < 0.35
          zoom = 0.5 + 1.5 * (value / 0.35)
          opacity = 255
        elsif value < 0.6
          open_device
          zoom = 2 + 0.2 * ((value - 0.35) / 0.25)
          opacity = 255
        else
          open_device
          fade = (value - 0.6) / 0.4
          zoom = 2.2 + 2 * fade
          opacity = (255 * (1 - fade)).to_i
        end
        @device.zoom = zoom
        @device.opacity = opacity
        @background.opacity = opacity
      end

      private

      def open_device
        return if @opened

        @opened = true
        @device.set_bitmap(DexBW.file('device_open'), :pokedex)
      end

      def dispose
        return if @disposed

        @disposed = true
        @device.dispose unless @device.disposed?
        @background.dispose unless @background.disposed?
      end
    end
  end
end

module PFM
  class Pokedex
    # Pokédex utilisé quand la variante enregistrée n'existe pas dans Studio
    BW_FALLBACK_VARIANT = :national

    # Remet le Pokédex sur une variante qui existe et contient des créatures.
    # PSDK démarre sur :regional, qui n'existe pas dans ce projet : depuis PSDK 26.61 l'ouverture plante.
    # @return [Symbol] la variante retenue
    def bw_ensure_valid_variant
      return @variant if bw_valid_variant?(@variant)

      candidates = @seen_variants.to_a + [BW_FALLBACK_VARIANT]
      candidates.concat(each_data_dex.map(&:db_symbol))
      fallback = candidates.find { |variant| bw_valid_variant?(variant) }
      self.variant = fallback if fallback
      @seen_variants.delete_if { |variant| !bw_valid_variant?(variant) }
      return @variant
    end

    private

    # @param variant [Symbol]
    # @return [Boolean]
    def bw_valid_variant?(variant)
      dex = each_data_dex.find { |data| data.db_symbol == variant }
      return dex && !dex.creatures.empty? ? true : false
    end
  end
end

module GamePlay
  class Dex
    # Corrige la variante du Pokédex avant que PSDK ne la lise
    module BWSafeVariant
      def initialize(pokedex = $pokedex)
        pokedex&.bw_ensure_valid_variant
        super
      end
    end
    prepend BWSafeVariant

    # Données supplémentaires pour les lignes de la liste BW
    class Presenter
      # @param pokemon [PFM::Pokemon]
      # @return [Array(Integer, Integer)] nombre de captures et de rencontres de l'espèce
      def bw_entry_counts(pokemon)
        return @pokedex.creature_caught_count(pokemon.db_symbol).to_i, @pokedex.creature_fought(pokemon.db_symbol).to_i
      end

      # @param pokemon [PFM::Pokemon]
      # @param position [Integer] position dans la liste affichée (secours)
      # @return [Integer] numéro dans le Pokédex courant
      def bw_dex_number(pokemon, position)
        dex_data = data_dex(variant)
        index = dex_data&.creatures&.find_index { |creature| creature.db_symbol == pokemon.db_symbol }
        return index + dex_data.start_id if index

        return position + 1
      end
    end

    # Habillage BW du Pokédex (la logique de PSDK reste inchangée)
    module BWStyle
      private

      def create_graphics
        super
        create_bw_intro if UI::DexBW::PLAY_INTRO
      end

      def create_base_ui
        btn_texts = button_texts
        @base_ui = UI::DexBW::BaseUI.new(@viewport, btn_texts, [UI::GenericBase::DEFAULT_KEYS] * btn_texts.size)
        @ctrl = @base_ui.ctrl
      end

      def create_composition
        @composition = UI::DexBW::ListComposition.new(@viewport)
      end

      def create_creature_page
        @creature_page = UI::DexBW::CreaturePage.new(@viewport, @presenter.form_name_symbol)
      end

      # Les boutons du bas sont masqués : on ne les teste plus à la souris (true = rien de consommé)
      def update_mouse_ctrl_buttons(*_args)
        return true
      end

      def create_bw_intro
        @bw_intro = UI::DexBW::Intro.new(@viewport)
        @viewport.sort_z
      end

      def change_state(state)
        @base_ui.page = UI::DexBW::PAGES[state] || UI::DexBW::PAGES.first
        @creature_page.layout = state
        super
      end

      public

      def update_graphics
        super
        return unless @bw_intro

        @bw_intro.update
        @bw_intro = nil if @bw_intro.done?
      end

      # Les touches passent l'animation d'ouverture
      def update_inputs
        if @bw_intro
          @bw_intro.skip if Input.trigger?(:A) || Input.trigger?(:B)
          return false
        end
        return super
      end

      def update_mouse(moved)
        return false if @bw_intro
        return false if info_state? && bw_info_click

        return super
      end

      private

      # Clic sur un onglet de la fiche (Habitat / Formes / Cri / Retour)
      # @return [Boolean] true si le clic a été utilisé
      def bw_info_click
        return false unless Mouse.trigger?(:LEFT)

        action = @creature_page.nav_action(Mouse.x, Mouse.y)
        return false unless action

        send(action)
        return true
      end
    end
    prepend BWStyle if UI::DexBW::ENABLED
  end

  class DexInfo
    # Habillage BW de la page d'une seule créature
    module BWStyle
      private

      def create_base_ui
        @base_ui = UI::DexBW::BaseUI.new(@viewport, [[nil, nil, ext_text(9000, 12), ext_text(9000, 9)]], [UI::GenericBase::DEFAULT_KEYS])
        @base_ui.page = UI::DexBW::PAGES[1]
        @ctrl = @base_ui.ctrl
      end

      # Le cadre est déjà dessiné dans le fond BW
      def create_frame; end

      # Les boutons du bas sont masqués : on ne les teste plus à la souris (true = rien de consommé)
      def update_mouse_ctrl_buttons(*_args)
        return true
      end

      def create_creature_page
        @creature_page = UI::DexBW::CreaturePage.new(@viewport, @presenter.form_name_symbol)
        @creature_page.layout = 1
        @creature_page.single_page!
        @creature_page.details_visible = true
      end

      public

      # Clics sur « Cri » et « Retour »
      def update_mouse(moved)
        if Mouse.trigger?(:LEFT) && (action = @creature_page.nav_action(Mouse.x, Mouse.y))
          send(action)
          return false
        end
        return super
      end
    end
    prepend BWStyle if UI::DexBW::ENABLED
  end
end
