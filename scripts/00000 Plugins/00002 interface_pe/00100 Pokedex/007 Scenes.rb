# Pokédex PE : habillage des scènes GamePlay::Dex et GamePlay::DexInfo
module GamePlay
  class Dex
    # Corrige la variante du Pokédex avant que PSDK ne la lise
    module PESafeVariant
      def initialize(pokedex = $pokedex)
        pokedex&.pe_ensure_valid_variant
        super
      end
    end
    prepend PESafeVariant

    # Données supplémentaires pour les lignes de la liste PE
    class Presenter
      # @param pokemon [PFM::Pokemon]
      # @return [Array(Integer, Integer)] nombre de captures et de rencontres de l'espèce
      def pe_entry_counts(pokemon)
        return @pokedex.creature_caught_count(pokemon.db_symbol).to_i, @pokedex.creature_fought(pokemon.db_symbol).to_i
      end

      # @param pokemon [PFM::Pokemon]
      # @param position [Integer] position dans la liste affichée (secours)
      # @return [Integer] numéro dans le Pokédex courant
      def pe_dex_number(pokemon, position)
        dex_data = data_dex(variant)
        index = dex_data&.creatures&.find_index { |creature| creature.db_symbol == pokemon.db_symbol }
        return index + dex_data.start_id if index

        return position + 1
      end
    end

    # Habillage PE du Pokédex (la logique de PSDK reste inchangée)
    module PEStyle
      private

      def create_graphics
        super
        create_pe_intro if UI::DexPE::PLAY_INTRO
      end

      def create_base_ui
        btn_texts = button_texts
        @base_ui = UI::DexPE::BaseUI.new(@viewport, btn_texts, [UI::GenericBase::DEFAULT_KEYS] * btn_texts.size)
        @ctrl = @base_ui.ctrl
      end

      def create_composition
        @composition = UI::DexPE::ListComposition.new(@viewport)
      end

      def create_creature_page
        @creature_page = UI::DexPE::CreaturePage.new(@viewport, @presenter.form_name_symbol)
      end

      # Les boutons du bas sont masqués : on ne les teste plus à la souris (true = rien de consommé)
      def update_mouse_ctrl_buttons(*_args)
        return true
      end

      def create_pe_intro
        @pe_intro = UI::DexPE::Intro.new(@viewport)
        @viewport.sort_z
      end

      def change_state(state)
        @base_ui.page = UI::DexPE::PAGES[state] || UI::DexPE::PAGES.first
        @creature_page.layout = state
        super
      end

      public

      def update_graphics
        super
        return unless @pe_intro

        @pe_intro.update
        @pe_intro = nil if @pe_intro.done?
      end

      # Les touches passent l'animation d'ouverture
      def update_inputs
        if @pe_intro
          @pe_intro.skip if Input.trigger?(:A) || Input.trigger?(:B)
          return false
        end
        return super
      end

      def update_mouse(moved)
        return false if @pe_intro
        return false if info_state? && pe_info_click

        return super
      end

      private

      # Clic sur un onglet de la fiche (Habitat / Formes / Cri / Retour)
      # @return [Boolean] true si le clic a été utilisé
      def pe_info_click
        return false unless Mouse.trigger?(:LEFT)

        action = @creature_page.nav_action(Mouse.x, Mouse.y)
        return false unless action

        send(action)
        return true
      end
    end
    prepend PEStyle if UI::DexPE::ENABLED
  end

  class DexInfo
    # Habillage PE de la page d'une seule créature
    module PEStyle
      private

      def create_base_ui
        @base_ui = UI::DexPE::BaseUI.new(@viewport, [[nil, nil, ext_text(9000, 12), ext_text(9000, 9)]], [UI::GenericBase::DEFAULT_KEYS])
        @base_ui.page = UI::DexPE::PAGES[1]
        @ctrl = @base_ui.ctrl
      end

      # Le cadre est déjà dessiné dans le fond PE
      def create_frame; end

      # Les boutons du bas sont masqués : on ne les teste plus à la souris (true = rien de consommé)
      def update_mouse_ctrl_buttons(*_args)
        return true
      end

      def create_creature_page
        @creature_page = UI::DexPE::CreaturePage.new(@viewport, @presenter.form_name_symbol)
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
    prepend PEStyle if UI::DexPE::ENABLED
  end
end
