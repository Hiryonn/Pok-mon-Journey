# Résumé PE : cases et boutons des capacités
module UI
  module SummaryPE
    # Contenu commun d'un emplacement de capacité (fond coloré, nom, type, PP)
    module SlotContent
      private

      def create_slot_content
        @slot = add_sprite(0, 0, SummaryPE.file('move_slot'))
        @move_name = add_text(14, -1, 84, 16, '', color: DARK)
        with_font(SMALL_FONT) { @move_type = add_text(14, 13, 44, 13, '', color: DARK) }
        @pp_icon = add_sprite(58, 16, SummaryPE.file('pp'))
        with_font(SMALL_FONT) { @pp = add_text(68, 13, 30, 13, '', 2, color: DARK) }
      end

      # @param skill [PFM::Skill]
      def show_skill(skill)
        @slot.set_bitmap(SummaryPE.slot_file(skill.type), :interface)
        @move_name.text = skill.name.to_s
        @move_type.text = SummaryPE.type_name(skill.type)
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
        @selector = add_sprite(-2, -2, SummaryPE.file('move_selector'), type: Sprite::WithColor)
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
  end
end
