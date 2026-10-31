# Résumé PE : page Infos
module UI
  module SummaryPE
    # Page 0 : informations générales
    class InfoPage < SpriteStack
      # Largeur de la jauge d'expérience
      EXP_WIDTH = 136

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 0, 0, default_cache: :interface)
        add_sprite(0, 0, SummaryPE.file('page_info'))
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
        add_text(100, 67, 67, 16, SummaryPE.summary_text(3), 2, color: WHITE)
        add_text(100, 84, 67, 16, SummaryPE.label(:species), 2, color: WHITE)
        @ot_label = add_text(100, 101, 67, 16, SummaryPE.summary_text(8), 2, color: WHITE)
        @exp_label = add_text(176, 118, 136, 16, SummaryPE.summary_text(10), color: WHITE)
        @next_label = add_text(176, 152, 136, 16, SummaryPE.summary_text(12), color: WHITE)
        @item_label = add_text(24, 173, 40, 16, text_get(23, 7), color: WHITE)
      end

      def create_values
        @type1 = add_sprite(175, 68, NO_INITIAL_IMAGE, type: Type1Sprite)
        @type2 = add_sprite(213, 68, NO_INITIAL_IMAGE, type: Type2Sprite)
        @species = add_text(178, 83, 136, 16, '', 2, color: WHITE)
        @ot = add_text(178, 100, 136, 16, '', 2, color: WHITE)
        @exp = add_text(178, 134, 136, 16, '', 2, color: WHITE)
        @next = add_text(178, 168, 136, 16, '', 2, color: WHITE)
        @exp_fill = add_sprite(180, 189, SummaryPE.file('exp_fill'))
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
        @species.text = pokemon.egg? ? SummaryPE.label(:egg) : pokemon.name.to_s
        @ot.text = pokemon.trainer_name.to_s
        @exp.text = pokemon.exp_text.to_s
        @next.text = pokemon.exp_remaining_text.to_s
        @exp_fill.src_rect.set(0, 0, (EXP_WIDTH * pokemon.exp_rate.to_f).clamp(0, EXP_WIDTH).round, 4)
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
  end
end
