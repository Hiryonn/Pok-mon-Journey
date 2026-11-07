# Équipe PE : carte d'un Pokémon (remplace UI::TeamButton, mêmes informations)
module UI
  module PartyPE
    class Card < TeamButton
      # États de la planche : normal, choisi, K.O., K.O. choisi, œuf, œuf choisi
      def update_background
        offset = if data.egg?
                   @selected ? 5 : 4
                 elsif @data.hp <= 0
                   @selected ? 3 : 2
                 else
                   @selected ? 1 : 0
                 end
        @background.src_rect.y = PartyPE::CARD_HEIGHT * offset
      end

      # @param value [Boolean]
      def selected=(value)
        @selected = value
        update_background
        @item_sprite.sy = value ? 1 : 0
        @item_text.load_color(value ? PartyPE::DARK : PartyPE::WHITE)
      end

      def show_item_name
        return if @data.egg?

        @item_sprite.visible = @item_text.visible = true
        @hp_texts.each { |sprite| sprite.visible = false }
      end

      def hide_item_name
        @item_sprite.visible = @item_text.visible = false
        return unless @data

        @hp_texts.each { |sprite| sprite.visible = !@data.egg? }
      end

      private

      def initial_coordinates
        return PartyPE::CARDS[@index % 6]
      end

      def fix_initial_position_cause_dev_is_lazy; end

      def background_name
        return PartyPE.file('card')
      end

      def create_sprites
        white = PartyPE::WHITE
        @background = add_sprite(0, 0, background_name)
        @background.src_rect.height = PartyPE::CARD_HEIGHT
        @icon = add_sprite(22, 24, NO_INITIAL_IMAGE, type: PokemonIconSprite)
        add_text(46, 2, 82, 16, :given_name, type: SymText, color: white)
        no_egg add_sprite(132, 6, NO_INITIAL_IMAGE, type: GenderSprite)
        no_egg add_sprite(34, 36, 'team/Item', type: HoldSprite)
        with_font(PartyPE::SMALL_FONT) do
          no_egg add_text(46, 18, 54, 13, :level_pokemon_number, type: SymText, color: white)
        end
        no_egg add_sprite(112, 20, NO_INITIAL_IMAGE, type: StatusSprite)
        @hp = no_egg add_custom_sprite(create_hp_bar)
        @hp_texts = [@hp]
        with_font(PartyPE::SMALL_FONT) do
          @hp_texts << no_egg(add_text(102, 31, 44, 13, :hp_text, 2, type: SymText, color: white))
        end
        @item_sprite = add_sprite(44, 31, PartyPE.file('item_band'), 1, 2, type: SpriteSheet)
        @item_text = add_text(48, 31, 96, 16, :item_name, type: SymText, color: white)
        @item_sprite.visible = @item_text.visible = false
      end

      # @return [UI::Bar]
      def create_hp_bar
        bar = UI::Bar.new(@viewport, @x + 46, @y + 35, RPG::Cache.interface('team/HPBars'), 53, 4, 0, 0, 3)
        bar.data_source = :hp_rate
        return bar
      end
    end
  end
end
