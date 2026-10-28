# Résumé du Pokémon (GamePlay::Summary) au style de la planche « Summary »
#
# Pages (gauche / droite pour changer) :
#   0 Infos      : sprite dans l'hexagone, types, espèce, D.O., expérience, objet tenu
#   1 Stats      : capacités en aperçu + tableau stats / IV / EV, nature, talent
#   2 Capacités  : liste sélectionnable + panneau « i » (description, puissance, précision)
#   3 Concours et 4 Rubans : pages d'origine de PSDK (pas d'assets fournis pour elles)
#   5 Mémo       : date et lieu de rencontre, niveau, nature
# La logique de PSDK (changement de Pokémon, ordre des capacités, choix d'une capacité, souris) est conservée.
# Le bandeau du haut est cliquable : ⇕ Pokémon suivant, « / » page précédente / suivante, ⮐ retour.
#
# Graphismes : graphics/interface/summary_bw/
# Pour revenir au résumé d'origine : passer ENABLED à false (ou supprimer ce fichier).
module UI
  module SummaryBW
    # Active ou non le nouveau résumé
    ENABLED = true
    # Dossier des graphismes (dans graphics/interface/)
    DIR = 'summary_bw/'
    # Index de la page mémo ajoutée après les rubans
    MEMO_PAGE = 5
    # Couleurs de texte de PSDK (graphics/windowskins/_colors.png)
    WHITE = 9
    CYAN = 14
    YELLOW = 16
    RED = 12
    GREEN = 13
    DARK = 0
    # Police fine (PowerGreenSmall)
    SMALL_FONT = 20
    # Couleurs des noms de stats (PV, Attaque, Défense, Atq. Spé., Déf. Spé., Vitesse)
    STAT_COLORS = [[0xfe, 0xc2, 0xcc], [0xf6, 0x84, 0x84], [0x9f, 0xb6, 0xdf], [0xb9, 0x9e, 0xd5], [0x88, 0xdb, 0xdb], [0x9f, 0xe5, 0x9d]]
    # Textes absents des fichiers de PSDK : [français, anglais]
    LABELS = {
      species: ['Espèce', 'Species'],
      moves: ['Capacités', 'Battle Moves'],
      nature: ['Nature', 'Nature'],
      egg: ['Œuf', 'Egg'],
      met: ['Rencontré au N. %d.', 'Met at level %d.'],
      date: ['%d/%m/%Y', '%m/%d/%Y']
    }

    module_function

    # @param name [String]
    # @return [String] chemin du graphisme
    def file(name)
      return "#{DIR}#{name}"
    end

    # @param key [Symbol]
    # @return [String]
    def label(key)
      texts = LABELS[key]
      return $options&.language == 'fr' ? texts[0] : texts[1]
    end

    # Texte du fichier 27 de PSDK (libellés du résumé, déjà traduits)
    # @param index [Integer]
    # @return [String]
    def summary_text(index)
      return text_file_get(27)[index].to_s
    end

    # Enlève les balises de couleur des textes PSDK
    # @param text [String]
    # @return [String]
    def strip_markup(text)
      return text.to_s.gsub(/\[VAR [^\]]*\]/, '').gsub(/\\c\[\d+\]/, '')
    end

    # Nom du graphisme de l'emplacement de capacité selon son type
    # @param type_id [Integer]
    # @return [String]
    def slot_file(type_id)
      name = file("move_slot_#{type_id}")
      return RPG::Cache.interface_exist?(name) ? name : file('move_slot')
    end

    # Nom du type en majuscules (ex. SPECTRE)
    # @param type_id [Integer]
    # @return [String]
    def type_name(type_id)
      return data_type(type_id).name.to_s.upcase
    rescue StandardError
      return ''
    end

    # Base de l'interface : grille animée + barre de boutons du bas
    class BaseUI < GenericBaseMultiMode
      # Vitesse de défilement de la grille (pixels par seconde) et taille d'une case
      GRID_SPEED = 5
      GRID_SIZE = 12

      def update_background_animation
        step = (Graphics.current_time * GRID_SPEED).to_i % GRID_SIZE
        @background.set_position(-step, step - GRID_SIZE)
      end

      private

      def create_background
        @background = add_sprite(0, -GRID_SIZE, SummaryBW.file('grid')).set_z(-10)
      end

      def create_background_animation
        @background_animation = nil
        @on_update_background_animation = nil
      end
    end

    # Contenu commun d'un emplacement de capacité (fond coloré, nom, type, PP)
    module SlotContent
      private

      def create_slot_content
        @slot = add_sprite(0, 0, SummaryBW.file('move_slot'))
        @move_name = add_text(14, -1, 84, 16, '', color: DARK)
        with_font(SMALL_FONT) { @move_type = add_text(14, 13, 44, 13, '', color: DARK) }
        @pp_icon = add_sprite(58, 16, SummaryBW.file('pp'))
        with_font(SMALL_FONT) { @pp = add_text(68, 13, 30, 13, '', 2, color: DARK) }
      end

      # @param skill [PFM::Skill]
      def show_skill(skill)
        @slot.set_bitmap(SummaryBW.slot_file(skill.type), :interface)
        @move_name.text = skill.name.to_s
        @move_type.text = SummaryBW.type_name(skill.type)
        @pp.text = skill.pp_text.to_s
      end
    end

    # Emplacement de capacité non interactif (aperçu de la page stats)
    class MoveSlot < SpriteStack
      include SlotContent

      # @param viewport [Viewport]
      # @param x [Integer]
      # @param y [Integer]
      def initialize(viewport, x, y)
        super(viewport, x, y, default_cache: :interface)
        create_slot_content
      end

      # @param skill [PFM::Skill, nil]
      def data=(skill)
        @data = skill
        self.visible = skill ? true : false
        show_skill(skill) if skill
      end

      # @param value [Boolean]
      def visible=(value)
        super(value && @data ? true : false)
      end
    end

    # Liste des capacités : position des emplacements
    SLOT_X = 0
    SLOT_Y = 83
    SLOT_STEP = 29

    # Capacité sélectionnable (même interface que UI::Summary_Skill)
    class SkillButton < SpriteStack
      include SlotContent
      # Couleur quand la capacité est en cours de déplacement
      SELECTED_COLOR = Color.new(0, 200, 0, 255)
      # Pas de teinte
      NO_SELECT_COLOR = Color.new(0, 0, 0, 0)
      # @return [Boolean]
      attr_reader :selected
      # @return [Boolean]
      attr_reader :moving

      # @param viewport [Viewport]
      # @param index [Integer]
      def initialize(viewport, index)
        super(viewport, SLOT_X, SLOT_Y + index * SLOT_STEP, default_cache: :interface)
        @selected = false
        @selector = add_sprite(-2, -2, SummaryBW.file('move_selector'), type: Sprite::WithColor)
        create_slot_content
        self.moving = false
      end

      # @param skill [PFM::Skill, nil]
      def data=(skill)
        @data = skill
        return unless (self.visible = skill ? true : false)

        show_skill(skill)
        @selector.visible = @selected
        self.moving = false
      end

      # @param value [Boolean]
      def visible=(value)
        super(value && @data ? true : false)
        @selector.visible = (value && (@selected || @moving)) ? true : false
      end

      # @return [Boolean]
      def visible
        return @slot.visible
      end

      # @param selected [Boolean]
      def selected=(selected)
        @selected = selected
        @selector.visible = (selected || @moving) && @data ? true : false
      end

      # @param moving [Boolean]
      def moving=(moving)
        @moving = moving
        @selector.visible = (moving || @selected) && @data ? true : false
        @selector.set_color(moving ? SELECTED_COLOR : NO_SELECT_COLOR)
      end
    end

    # Bandeau du haut + grand sprite du Pokémon (partagé par les pages)
    class Header < SpriteStack
      # Position du grand sprite selon la page (bas-centre) ; absent = caché
      FACE_POSITIONS = {0 => [72, 165], 3 => [55, 119], 4 => [55, 119], MEMO_PAGE => [59, 173]}
      # Zones cliquables du bandeau
      BUTTONS = {switch: 0..15, prev: 218..251, next: 252..285, back: 286..319}
      BUTTON_Y = 4..23
      # Pokémon dont le nom contient déjà le genre
      NO_GENDER = %i[nidoranf nidoranm]

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 0, 0, default_cache: :interface)
        add_sprite(0, 4, SummaryBW.file('header'))
        @name = add_text(18, 6, 120, 16, '', color: WHITE)
        @shiny = add_sprite(0, 10, SummaryBW.file('shiny'))
        @status = add_sprite(0, 9, NO_INITIAL_IMAGE, type: StatusSprite)
        @gender = add_sprite(0, 10, SummaryBW.file('gender_m'))
        @level = add_text(150, 6, 58, 16, '', 2, color: WHITE)
        @face = add_sprite(*FACE_POSITIONS[0], NO_INITIAL_IMAGE, type: PokemonFaceSprite)
        @page = 0
      end

      def update_graphics
        @face.update
      end

      # @param pokemon [PFM::Pokemon]
      def data=(pokemon)
        @data = pokemon
        egg = pokemon.egg?
        @face.data = pokemon
        @name.text = pokemon.given_name.to_s
        x = @name.x + @name.real_width + 3
        @shiny.visible = pokemon.shiny && !egg
        @shiny.x = x
        x += 12 if @shiny.visible
        @status.data = pokemon
        @status.visible = !egg && pokemon.status.to_i != 0
        @status.x = x
        @level.text = egg ? '' : "#{SummaryBW.summary_text(29)} #{pokemon.level}"
        @gender.visible = !egg && !NO_GENDER.include?(pokemon.db_symbol) && [1, 2].include?(pokemon.gender)
        @gender.set_bitmap(SummaryBW.file(pokemon.gender == 2 ? 'gender_f' : 'gender_m'), :interface)
        @gender.x = @level.x + @level.width - @level.real_width - 9
        self.page = @page
      end

      # Place le grand sprite selon la page affichée
      # @param index [Integer]
      def page=(index)
        @page = index
        position = FACE_POSITIONS[index]
        @face.visible = position ? true : false
        @face.set_position(*position) if position
      end

      # Bouton du bandeau sous la souris
      # @param mx [Integer]
      # @param my [Integer]
      # @return [Symbol, nil] :switch, :prev, :next ou :back
      def button_at(mx, my)
        return nil unless BUTTON_Y.include?(my)

        return BUTTONS.find { |_, range| range.include?(mx) }&.first
      end
    end

    # Page 0 : informations générales
    class InfoPage < SpriteStack
      # Largeur de la jauge d'expérience
      EXP_WIDTH = 136

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 0, 0, default_cache: :interface)
        add_sprite(0, 0, SummaryBW.file('page_info'))
        create_labels
        create_values
      end

      # @param pokemon [PFM::Pokemon]
      def data=(pokemon)
        @data = pokemon
        return unless (self.visible = pokemon ? true : false)

        refresh(pokemon)
      end

      # @param value [Boolean]
      def visible=(value)
        super
        hide_egg_details if value && @data&.egg?
        @item_icon.visible = false if value && !holding_item?
      end

      private

      def create_labels
        add_text(100, 67, 67, 16, SummaryBW.summary_text(3), 2, color: WHITE)
        add_text(100, 84, 67, 16, SummaryBW.label(:species), 2, color: WHITE)
        @ot_label = add_text(100, 101, 67, 16, SummaryBW.summary_text(8), 2, color: WHITE)
        @exp_label = add_text(176, 118, 136, 16, SummaryBW.summary_text(10), color: WHITE)
        @next_label = add_text(176, 152, 136, 16, SummaryBW.summary_text(12), color: WHITE)
        @item_label = add_text(24, 173, 40, 16, text_get(23, 7), color: WHITE)
      end

      def create_values
        @type1 = add_sprite(175, 68, NO_INITIAL_IMAGE, type: Type1Sprite)
        @type2 = add_sprite(213, 68, NO_INITIAL_IMAGE, type: Type2Sprite)
        @species = add_text(178, 83, 136, 16, '', 2, color: WHITE)
        @ot = add_text(178, 100, 136, 16, '', 2, color: WHITE)
        @exp = add_text(178, 134, 136, 16, '', 2, color: WHITE)
        @next = add_text(178, 168, 136, 16, '', 2, color: WHITE)
        @exp_fill = add_sprite(180, 189, SummaryBW.file('exp_fill'))
        @item = add_text(57, 172, 102, 16, '', color: WHITE)
        @ball = add_sprite(15, 79, NO_INITIAL_IMAGE, ox: 16, oy: 16)
        @ball.zoom = 0.5
        @item_icon = add_sprite(129, 137, NO_INITIAL_IMAGE, type: ItemSprite)
      end

      # @return [Boolean]
      def holding_item?
        item = @data&.item_holding
        return item && item != 0 && item != :__undef__ ? true : false
      end

      # @param pokemon [PFM::Pokemon]
      def refresh(pokemon)
        @type1.data = pokemon
        @type2.data = pokemon
        @species.text = pokemon.egg? ? SummaryBW.label(:egg) : pokemon.name.to_s
        @ot.text = pokemon.trainer_name.to_s
        @exp.text = pokemon.exp_text.to_s
        @next.text = pokemon.exp_remaining_text.to_s
        @exp_fill.zoom_x = (EXP_WIDTH * pokemon.exp_rate.to_f).clamp(0, EXP_WIDTH)
        @ball.set_bitmap(data_item(pokemon.captured_with).icon, :icon)
        @item.text = holding_item? ? pokemon.item_name.to_s : ''
        @item_icon.data = pokemon.item_holding if holding_item?
        @item_icon.visible = holding_item?
        hide_egg_details if pokemon.egg?
      end

      def hide_egg_details
        [@type1, @type2, @ot, @ot_label, @exp, @next, @exp_fill, @exp_label, @next_label, @item, @item_label, @item_icon].each do |sprite|
          sprite.visible = false
        end
      end
    end

    # Page 1 : aperçu des capacités + stats / IV / EV, nature et talent
    class StatsPage < SpriteStack
      # Première ligne du tableau et hauteur d'une ligne
      ROW_Y = 49
      ROW_HEIGHT = 17
      # Méthodes des valeurs, IV et EV (PV, Atq, Déf, Atq Spé, Déf Spé, Vit)
      VALUES = %i[hp_text atk_basis dfe_basis ats_basis dfs_basis spd_basis]
      IVS = %i[iv_hp_text iv_atk_text iv_dfe_text iv_ats_text iv_dfs_text iv_spd_text]
      EVS = %i[ev_hp_text ev_atk_text ev_dfe_text ev_ats_text ev_dfs_text ev_spd_text]
      # Libellés du fichier 27 pour chaque stat
      LABEL_IDS = [15, 18, 20, 22, 24, 26]

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 0, 0, default_cache: :interface)
        add_sprite(0, 0, SummaryBW.file('page_stats'))
        add_text(15, 64, 84, 16, SummaryBW.label(:moves), color: WHITE)
        @slots = Array.new(4) { |i| MoveSlot.new(viewport, SLOT_X, SLOT_Y + i * SLOT_STEP) }
        create_table
      end

      def update; end

      # @param pokemon [PFM::Pokemon]
      def data=(pokemon)
        @data = pokemon
        return unless (self.visible = pokemon ? true : false)

        @slots.each_with_index { |slot, i| slot.data = pokemon.skills_set[i] }
        VALUES.each_with_index { |method, i| @values[i].text = pokemon.public_send(method).to_s }
        IVS.each_with_index { |method, i| @ivs[i].text = pokemon.public_send(method).to_s }
        EVS.each_with_index { |method, i| @evs[i].text = pokemon.public_send(method).to_s }
        @nature.text = pokemon.nature_name.to_s
        @ability.text = pokemon.ability_name.to_s
        refresh_nature(pokemon)
      end

      # @param value [Boolean]
      def visible=(value)
        super
        @slots.each { |slot| slot.visible = value }
        refresh_nature(@data) if value && @data
      end

      private

      def create_table
        @values = []
        @ivs = []
        @evs = []
        @signs = []
        LABEL_IDS.each_with_index do |text_id, i|
          y = ROW_Y + i * ROW_HEIGHT
          label = add_text(104, y, 52, 16, SummaryBW.summary_text(text_id), color: WHITE)
          label.fill_color = Color.new(*STAT_COLORS[i])
          @signs << add_text(157, y, 6, 16, '', color: WHITE)
          @values << add_text(163, y, 104, 16, '', 2, color: WHITE)
          @ivs << add_text(271, y, 22, 16, '', 2, color: YELLOW)
          @evs << add_text(295, y, 22, 16, '', 2, color: WHITE)
        end
        add_text(104, ROW_Y + 6 * ROW_HEIGHT, 56, 16, SummaryBW.label(:nature), color: WHITE)
        add_text(104, ROW_Y + 7 * ROW_HEIGHT, 56, 16, text_get(33, 142), color: WHITE)
        @nature = add_text(163, ROW_Y + 6 * ROW_HEIGHT, 154, 16, '', 2, color: WHITE)
        @ability = add_text(163, ROW_Y + 7 * ROW_HEIGHT, 154, 16, '', 2, color: WHITE)
      end

      # Colore la stat augmentée (vert, +) et diminuée (rouge, -) par la nature
      # @param pokemon [PFM::Pokemon]
      def refresh_nature(pokemon)
        nature = pokemon.nature.partition.with_index { |_, i| i != 3 }.flatten(1)
        @signs[0].text = ''
        @values[0].load_color(WHITE)
        1.upto(5) do |i|
          rate = nature[i].to_i
          color = rate > 100 ? GREEN : (rate < 100 ? RED : WHITE)
          @values[i].load_color(color)
          @signs[i].text = rate > 100 ? '+' : (rate < 100 ? '-' : '')
          @signs[i].load_color(color)
        end
      end
    end

    # Page 2 : capacités sélectionnables + panneau de détails
    class MovesPage < Summary_Skills
      private

      def init_sprite
        push(0, 0, SummaryBW.file('page_moves'))
        add_text(15, 64, 84, 16, SummaryBW.label(:moves), color: WHITE)
        add_text(110, 173, 96, 16, SummaryBW.summary_text(37), color: WHITE)
        add_text(214, 173, 98, 16, SummaryBW.summary_text(39), color: WHITE)
        create_move_info
        @skills = Array.new(4) { |index| SkillButton.new(@viewport, index) }
      end

      def create_move_info
        @move_info = SpriteStack.new(@viewport, default_cache: :interface)
        @move_info.add_text(126, 48, 186, 16, :name, type: SymText, color: WHITE)
        @move_info.add_text(110, 72, 204, 16, :description, type: SymMultilineText, color: WHITE)
        @move_info.push(110, 155, nil, type: TypeSprite)
        @move_info.push(146, 155, nil, type: CategorySprite)
        @move_info.add_text(110, 173, 96, 16, :power_text, 2, type: SymText, color: WHITE)
        @move_info.add_text(214, 173, 98, 16, :accuracy_text, 2, type: SymText, color: WHITE)
      end
    end

    # Page 5 : mémo (date, lieu, niveau de rencontre, nature)
    class MemoPage < SpriteStack
      TEXT_X = 146
      TEXT_Y = 64
      TEXT_WIDTH = 168
      LINE_HEIGHT = 16

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 0, 0, default_cache: :interface)
        add_sprite(0, 0, SummaryBW.file('page_memo'))
        @lines = [WHITE, CYAN, WHITE, WHITE].map { |color| add_text(TEXT_X, TEXT_Y, TEXT_WIDTH, 16, '', color: color) }
      end

      # @param pokemon [PFM::Pokemon]
      def data=(pokemon)
        @data = pokemon
        return unless (self.visible = pokemon ? true : false)

        paragraphs = pokemon.egg? ? egg_paragraphs(pokemon) : memo_paragraphs(pokemon)
        y = TEXT_Y
        @lines.each_with_index do |text, i|
          content = paragraphs[i].to_s
          text.visible = !content.empty?
          next if content.empty?

          text.y = y - Text::Util::FOY
          text.multiline_text = content
          y += LINE_HEIGHT * (text.text.count("\n") + 1)
        end
      end

      # @param value [Boolean]
      def visible=(value)
        super
        @lines.each { |text| text.visible = false if text.text.to_s.strip.empty? }
      end

      private

      # @param pokemon [PFM::Pokemon]
      # @return [Array<String>] date, lieu, niveau, nature
      def memo_paragraphs(pokemon)
        nature = nature_sentence(pokemon)
        if (mem = pokemon.memo_text)
          return [custom_memo(pokemon, mem), '', '', nature]
        end

        time = Time.at(pokemon.captured_at.to_i)
        return [time.strftime(SummaryBW.label(:date)), pokemon.captured_zone_name.to_s,
                format(SummaryBW.label(:met), pokemon.captured_level.to_i), nature]
      end

      # Mémo personnalisé (pokemon.memo_text) : même traitement que PSDK, sans les balises de couleur
      def custom_memo(pokemon, mem)
        time = Time.at(pokemon.captured_at.to_i)
        hash = {'[VAR NUM2(0002)]' => time.strftime('%d'), '[VAR NUM2(0001)]' => time.strftime('%m'), '[VAR NUM2(0000)]' => time.strftime('%Y'),
                '[VAR NUM3(0003)]' => pokemon.captured_level.to_s, '[VAR LOCATION(0004)]' => pokemon.captured_zone_name, '[VAR 0105(0004)]' => pokemon.captured_zone_name}
        return SummaryBW.strip_markup(parse_text(mem[0] || 28, mem[1] || 25, hash))
      end

      # @param pokemon [PFM::Pokemon]
      # @return [String] ex. « Calme de nature. »
      def nature_sentence(pokemon)
        text = Studio::Text.get(28, 0).dup
        match = text.match(/\[VAR COLOR\(0002\)\]([^\[]*)\[VAR COLOR\(0000\)\]/)
        text.sub!(match[1], pokemon.nature_name.to_s) if match
        return SummaryBW.strip_markup(text)
      rescue StandardError
        return pokemon.nature_name.to_s
      end

      # Textes d'un œuf (repris de UI::Summary_Memo)
      # @param pokemon [PFM::Pokemon]
      def egg_paragraphs(pokemon)
        time = pokemon.egg_at ? Time.at(pokemon.egg_at) : Time.new
        hash = {'[VAR NUM2(0007)]' => time.strftime('%d'), '[VAR NUM2(0002)]' => time.strftime('%d'), '[VAR NUM2(0006)]' => time.strftime('%m'),
                '[VAR NUM2(0001)]' => time.strftime('%m'), '[VAR NUM2(0005)]' => time.strftime('%Y'), '[VAR NUM2(0000)]' => time.strftime('%Y'),
                '[VAR LOCATION(0008)]' => pokemon.egg_zone_name, '[VAR 0105(0008)]' => pokemon.egg_zone_name, '[VAR NUM3(0003)]' => pokemon.captured_level.to_s,
                '[VAR LOCATION(0004)]' => pokemon.captured_zone_name, '[VAR 0105(0004)]' => pokemon.captured_zone_name}
        how = (pokemon.egg_how_obtained == :received ? 79 : 80) + (pokemon.data.hatch_steps >= 10_240 ? 2 : 0)
        steps = pokemon.step_remaining
        step_id = steps > 10_240 ? 87 : (steps > 2_560 ? 86 : (steps > 1_280 ? 85 : 84))
        return [SummaryBW.strip_markup(parse_text(28, how, hash)), '', '', SummaryBW.strip_markup(parse_text(28, step_id))]
      rescue StandardError
        return ['', '', '', '']
      end
    end
  end
end

module GamePlay
  class Summary
    # Habillage du résumé (la logique de PSDK reste inchangée)
    module BWStyle
      private

      def create_base
        @base_ui = UI::SummaryBW::BaseUI.new(@viewport, load_texts, KEYS, ctrl_id_state)
        init_win_text
      end

      def create_uis
        @uis = [UI::SummaryBW::InfoPage.new(@viewport), UI::SummaryBW::StatsPage.new(@viewport), UI::SummaryBW::MovesPage.new(@viewport),
                UI::Summary_Contest.new(@viewport), UI::Summary_Ribbons.new(@viewport), UI::SummaryBW::MemoPage.new(@viewport)]
      end

      def create_top_ui
        @top = UI::SummaryBW::Header.new(@viewport)
      end

      def update_ui_visibility
        super
        @top.page = @index
      end

      # La page mémo utilise les mêmes boutons que la page stats
      def ctrl_id_state
        return ctrl_id_state_stats_page if @index == UI::SummaryBW::MEMO_PAGE

        return super
      end

      def update_inputs_view
        if @index == UI::SummaryBW::MEMO_PAGE
          update_inputs_basic
          return true
        end
        return super
      end

      # L'échange rapide par petits boutons de PSDK n'existe pas dans ce design
      def update_mouse_switch_skill(_skill, _index); end

      # Après un changement d'ordre des capacités, l'aperçu de la page stats suit
      def update_input_a_skill_ui
        result = super
        @uis[1].data = @pokemon
        return result
      end

      public

      def update_mouse(moved)
        super
        update_header_mouse
      end

      private

      # Clics sur le bandeau du haut
      def update_header_mouse
        return unless Mouse.trigger?(:LEFT)

        busy = @selecting_move || @selecting_ribbon || @skill_index.to_i >= 0
        case @top.button_at(Mouse.x, Mouse.y)
        when :switch
          mouse_next if @mode == :view && @party.size > 1 && !busy
        when :prev
          mouse_left unless busy
        when :next
          mouse_right unless busy
        when :back
          busy ? mouse_cancel : mouse_quit
        end
      end
    end

    if UI::SummaryBW::ENABLED
      prepend BWStyle
      # Une page de plus (mémo) après les rubans
      remove_const(:LAST_STATE)
      LAST_STATE = UI::SummaryBW::MEMO_PAGE
    end
  end
end
