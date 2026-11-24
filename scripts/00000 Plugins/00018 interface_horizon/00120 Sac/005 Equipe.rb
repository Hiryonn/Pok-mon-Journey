# Sac Horizon : l'équipe à gauche (icône, niveau, PV ; APTE / PAS APTE selon l'objet choisi)
module UI
  module BagHorizon
    # États de panel_round.png / panel_rect.png (une image de 50 pixels par état)
    PANEL_STATES = { normal: 0, selected: 1, ko: 2, ko_selected: 3, able: 4, able_selected: 5 }.freeze

    # Case d'un Pokémon
    class Panel < SpriteStack
      # @param viewport [Viewport]
      # @param index [Integer] place dans l'équipe (0 à 5)
      def initialize(viewport, index)
        x = BagHorizon.party_x + (index % 2) * PANEL_STEP_X
        y = PARTY_Y - 1 + (index / 2) * PANEL_STEP_Y
        super(viewport, x, y, default_cache: :interface)
        @background = add_sprite(0, 0, BagHorizon.file(index == 0 ? 'panel_round' : 'panel_rect')).set_z(4)
        @background.src_rect.height = PANEL_HEIGHT
        @icon = add_sprite(17, 18, NO_INITIAL_IMAGE, type: PokemonIconSprite).set_z(5)
        @level_icon = add_sprite(34, 8, BagHorizon.file('lv')).set_z(5)
        with_font(SMALL_FONT) do
          @level = add_text(34, 14, 20, 13, '', color: WHITE)
          @able = add_text(0, 34, 55, 13, '', 1, color: WHITE)
        end
        @shiny = add_sprite(45, 30, BagHorizon.file('shiny')).set_z(5)
        @pokerus = add_sprite(36, 30, BagHorizon.file('pokerus')).set_z(5)
        @pokerus.src_rect.height = 8
        @hp = UI::Bar.new(viewport, x + 3, y + 40, RPG::Cache.interface(BagHorizon.file('hp_bar')), 47, 3, 1, 1, 3)
        [@level, @able].each { |text| text.z = 5 }
      end

      # @param pokemon [PFM::Pokemon, nil]
      # @param able [Boolean, Symbol, nil] nil : on montre les PV ; true / false / :learnt : APTE / PAS APTE / APPRIS
      def set(pokemon, able = nil)
        self.visible = !pokemon.nil?
        @hp.visible = false
        return unless pokemon

        @icon.data = pokemon
        egg = pokemon.egg?
        ko = !egg && pokemon.hp <= 0
        @level_icon.visible = @level.visible = !egg
        @level.text = pokemon.level.to_s
        @shiny.visible = !egg && pokemon.shiny?
        @pokerus.visible = !egg && (pokemon.pokerus_affected? || pokemon.pokerus_cured?)
        @pokerus.src_rect.y = pokemon.pokerus_affected? ? 8 : 0
        state = ko ? :ko : :normal
        if able.nil? || egg
          @able.visible = false
          @hp.visible = !egg
          @hp.rate = pokemon.hp_rate
        else
          @able.visible = true
          @able.text = able_text(able)
          state = :able if able == true
        end
        @background.src_rect.y = PANEL_STATES[state] * PANEL_HEIGHT
      end

      # Animation de l'icône
      def update
        @icon.update if @icon.visible
      end

      private

      def able_text(able)
        return BagHorizon.t('APPRIS', 'LEARNED') if able == :learnt
        return able ? BagHorizon.t('APTE', 'ABLE') : BagHorizon.t('PAS APTE', 'NOT ABLE')
      end
    end

    # Les 6 cases de l'équipe
    class Party
      # @param viewport [Viewport]
      def initialize(viewport)
        @frame = Sprite.new(viewport).set_bitmap(BagHorizon.file('party_frame'), :interface)
        @frame.set_position(BagHorizon.party_x, PARTY_Y)
        @frame.z = 3
        @panels = Array.new(6) { |i| Panel.new(viewport, i) }
      end

      def update
        @panels.each(&:update)
      end

      # @param team [Array<PFM::Pokemon>]
      # @param item_id [Integer, Symbol, nil] objet choisi
      # @param scene [GamePlay::Base]
      def refresh(team, item_id, scene)
        wrapper = BagHorizon.creature_wrapper(item_id)
        @panels.each_with_index do |panel, i|
          pokemon = team[i]
          panel.set(pokemon, pokemon && wrapper ? BagHorizon.able(wrapper, pokemon, scene) : nil)
        end
      end
    end

    module_function

    # Soins : on garde les PV affichés
    HEAL_CLASSES = %i[ConstantHealItem RateHealItem StatusHealItem PPHealItem].freeze

    # Objet qui se donne à un Pokémon et dont on montre APTE / PAS APTE (CT, pierres, vitamines… ; pas les soins)
    # @return [PFM::ItemDescriptor::Wrapper, nil]
    def creature_wrapper(item_id)
      return nil if item_id.nil? || item_id == 0

      item = data_item(item_id)
      return nil if HEAL_CLASSES.any? { |name| Studio.const_defined?(name) && item.is_a?(Studio.const_get(name)) }

      wrapper = PFM::ItemDescriptor.actions(item_id)
      return nil if wrapper.no_effect || wrapper.chen
      return nil unless wrapper.open_skill_learn || wrapper.on_creature_choice?

      return wrapper
    rescue StandardError
      return nil
    end

    # @return [Boolean, Symbol] true, false ou :learnt (capacité déjà connue)
    def able(wrapper, pokemon, scene)
      return false if pokemon.egg?
      return :learnt if wrapper.open_skill_learn && pokemon.skill_learnt?(wrapper.open_skill_learn)

      return wrapper.on_creature_choice(pokemon, scene) ? true : false
    rescue StandardError
      return false
    end
  end
end
