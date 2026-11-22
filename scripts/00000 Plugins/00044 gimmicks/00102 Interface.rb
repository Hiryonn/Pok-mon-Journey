# Gimmicks : onglet « ACTION » pendant le choix de l'attaque (Y) et icône dans les boîtes d'infos
module Gimmicks
  # Ordre des types dans les images Téra d'Essentials (tera_types.png, tab_tera.png)
  TERA_ROWS = %i[normal fighting flying poison ground rock bug ghost steel qmarks fire water grass electric psychic ice
                 dragon dark fairy stellar].freeze
  # Hauteur d'un onglet (tab_*.png)
  TAB_H = 23

  module_function

  # @param type [Symbol] db_symbol du type
  # @return [Integer] ligne dans les images Téra (0 si inconnu)
  def tera_row(type)
    return TERA_ROWS.index(type.to_sym) || 0
  end

  # Type Téra d'un Pokémon (branché par la mécanique Téracristal)
  # @param pokemon [PFM::Pokemon]
  # @return [Symbol]
  def tera_type_of(pokemon)
    handler = HANDLERS[:tera]
    return handler.respond_to?(:tera_type) ? handler.tera_type(pokemon) : :normal
  end

  # Onglet « ACTION » : une image par mécanique (éteint / allumé, Téra : éteint puis une ligne par type)
  class Tab < UI::SpriteStack
    # @param viewport [Viewport]
    def initialize(viewport)
      super(viewport, default_cache: :interface)
      @sheets = {}
      @current = nil
    end

    # @param kind [Symbol, nil] mécanique montrée (nil : aucune)
    # @param active [Boolean] mécanique choisie pour ce tour
    # @param battler [PFM::PokemonBattler]
    def show_kind(kind, active, battler)
      sheet = kind ? sheet_for(kind, battler) : nil
      @current = sheet
      if sheet
        sheet.sy = if kind == :tera
                     active ? Gimmicks.tera_row(Gimmicks.tera_type_of(battler)) + 1 : 0
                   else
                     active ? 1 : 0
                   end
      end
      self.visible = true
    end

    # Seule l'image de la mécanique montrée est visible
    # @param value [Boolean]
    def visible=(value)
      super
      @sheets&.each_value { |sheet| sheet.visible = value && sheet.equal?(@current) }
    end

    private

    def sheet_for(kind, battler)
      name = kind == :zmove && Gimmicks.ultra?(battler) ? 'tab_ultra' : "tab_#{kind}"
      return @sheets[name] if @sheets[name]
      return nil unless RPG::Cache.interface_exist?(Gimmicks.file(name))

      rows = RPG::Cache.interface(Gimmicks.file(name)).height / TAB_H
      return @sheets[name] = add_sprite(0, 0, Gimmicks.file(name), 1, rows, type: SpriteSheet)
    end
  end

  class << self
    # @return [Symbol, nil] mécanique choisie dans l'écran des attaques (affichage des boutons)
    attr_accessor :ui_kind
  end

  module_function

  # Nom affiché pour une attaque quand une mécanique est choisie (capacité Z, attaque Max)
  # @param kind [Symbol, nil]
  # @param battler [PFM::PokemonBattler]
  # @param move [Battle::Move]
  # @return [String, nil]
  def move_display_name(kind, battler, move)
    handler = kind && HANDLERS[kind]
    return nil unless handler.respond_to?(:display_name) && battler && move

    return handler.display_name(battler, move)
  end

  # @return [Boolean] l'attaque peut être choisie avec la mécanique
  def move_selectable?(kind, battler, move)
    handler = kind && HANDLERS[kind]
    return true unless handler.respond_to?(:selectable?)

    return handler.selectable?(battler, move)
  end

  # Ultra-Explosion (Necrozma) : branchée avec les capacités Z
  # @param battler [PFM::PokemonBattler]
  def ultra?(battler)
    handler = HANDLERS[:zmove]
    return handler.respond_to?(:ultra?) && handler.ultra?(battler)
  end
end

module BattleUI
  class SkillChoice
    # @return [Symbol, nil] mécanique choisie pour ce tour
    attr_reader :pj_gimmick

    module PJGimmicks
      # @param pokemon [PFM::PokemonBattler]
      def reset(pokemon)
        @pj_gimmick = nil
        @pj_options = pj_gimmick_options(pokemon)
        super
        pj_refresh_tab
      end

      # @param pokemon [PFM::PokemonBattler]
      # @param move [Battle::Move]
      def encore_reset(pokemon, move)
        @pj_gimmick = nil
        @pj_options = []
        super
      end

      # Y : mécanique suivante (aucune → 1re → 2e… → aucune)
      # @return [Boolean] une mécanique est possible
      def pj_next_gimmick
        return false if @pj_options.nil? || @pj_options.empty?

        list = [nil] + @pj_options
        @pj_gimmick = list[(list.index(@pj_gimmick).to_i + 1) % list.size]
        @mega_enabled = @pj_gimmick == :mega
        self.data = @pokemon if @pokemon
        pj_refresh_tab
        return true
      end

      # @return [Array<Symbol>]
      def pj_options
        return @pj_options || []
      end

      # Les boutons affichent les capacités Z / attaques Max quand la mécanique est choisie
      # @param pokemon [PFM::PokemonBattler]
      def data=(pokemon)
        Gimmicks.ui_kind = @pj_gimmick
        super
      ensure
        Gimmicks.ui_kind = nil
      end

      private

      # Capacité Z : seules les attaques compatibles peuvent être choisies
      def validate
        move = @pokemon&.moveset&.[](@index)
        return super if @pj_gimmick.nil? || Gimmicks.move_selectable?(@pj_gimmick, @pokemon, move)

        play_buzzer_se
      end

      def create_sprites
        super
        x, y = pj_tab_position
        @pj_tab = add_sprite(x, y, nil, type: Gimmicks::Tab)
      end

      # Au-dessus de la bande du bas de l'Interface Horizon, sinon à la place du bouton méga de PSDK
      def pj_tab_position
        return 2, BattleUI::PJ::PANEL_Y - Gimmicks::TAB_H if defined?(BattleUI::PJ) && BattleUI::PJ.active?

        return 2, 160
      end

      def pj_refresh_tab
        return unless @pj_tab

        kind = @pj_gimmick || pj_options.first
        @pj_tab.show_kind(kind, !@pj_gimmick.nil?, @pokemon)
      end

      # @param pokemon [PFM::PokemonBattler]
      def pj_gimmick_options(pokemon)
        return [] unless pokemon && @scene.respond_to?(:logic)

        chosen = @scene.respond_to?(:pj_chosen_gimmicks) ? @scene.pj_chosen_gimmicks : []
        return @scene.logic.pj_gimmicks.available(pokemon, chosen)
      rescue StandardError => e
        log_error("Gimmicks : #{e.message}") if respond_to?(:log_error, true)
        return []
      end

      # Ligne d'aide de l'Interface Horizon (« Y : Téracristal »…)
      # @param pokemon [PFM::PokemonBattler]
      def pj_special_hint(pokemon)
        return super if @pj_gimmick.nil? && pj_options.empty?

        label = Gimmicks.text(@pj_gimmick ? :"#{@pj_gimmick}_short" : :wheel_short)
        return defined?(BattleUI::PJ) ? BattleUI::PJ.key_names(format(Gimmicks.text(:hint), label)) : format(Gimmicks.text(:hint), label)
      end
    end
    prepend PJGimmicks

    class MoveButton
      module PJGimmicks
        # @param pokemon [PFM::PokemonBattler]
        def data=(pokemon)
          super
          kind = Gimmicks.ui_kind
          kind ||= :dynamax if pokemon.respond_to?(:pj_dynamax?) && pokemon.pj_dynamax?
          return unless kind && @data && (label = @name || @text).respond_to?(:text=)

          name = Gimmicks.move_display_name(kind, pokemon, @data)
          label.text = name if name
          self.opacity = Gimmicks.move_selectable?(kind, pokemon, @data) ? 255 : 128
        end
      end
      prepend PJGimmicks
    end

    class SubChoice
      module PJGimmicks
        private

        # Y : ouvre la roue des mécaniques (remplace le bouton méga de PSDK)
        def action_y
          return super unless @choice.respond_to?(:pj_open_wheel)
          return play_buzzer_se unless @choice.pj_open_wheel

          play_decision_se
        end
      end
      prepend PJGimmicks
    end

    class SpecialButton
      module PJGimmicks
        # Le bouton méga de PSDK est remplacé par l'onglet ACTION
        def visible=(value)
          super(@type == :mega ? false : value)
        end
      end
      prepend PJGimmicks
    end
  end

  # Icône de la mécanique dans la boîte d'infos (méga, Dynamax, type Téra…)
  class InfoBar
    module PJGimmicks
      def data=(value)
        super
        pj_refresh_gimmick_icon(value)
      end

      # L'icône reste cachée quand le Pokémon n'a pas de mécanique
      # @param value [Boolean]
      def visible=(value)
        super
        @pj_gimmick_icon.visible = value && @pj_icon_on if @pj_gimmick_icon
      end

      private

      def create_sprites
        super
        @pj_icon_on = false
        @pj_gimmick_icon = add_sprite(*pj_gimmick_icon_position, nil)
        @pj_gimmick_icon.visible = false
      end

      def pj_gimmick_icon_position
        pe = defined?(BattleUI::PJ) && BattleUI::PJ.active?
        return enemy? ? [pe ? 124 : 2, 3] : [pe ? 12 : 2, 2]
      end

      # @param pokemon [PFM::PokemonBattler]
      def pj_refresh_gimmick_icon(pokemon)
        return unless @pj_gimmick_icon

        name, row = pj_gimmick_icon_name(pokemon)
        @pj_icon_on = name && RPG::Cache.interface_exist?(Gimmicks.file(name)) ? true : false
        return @pj_gimmick_icon.visible = false unless @pj_icon_on

        @pj_gimmick_icon.set_bitmap(Gimmicks.file(name), :interface)
        if row
          @pj_gimmick_icon.src_rect.set(0, row * 16, 16, 16)
        else
          @pj_gimmick_icon.src_rect.set(0, 0, @pj_gimmick_icon.bitmap.width, @pj_gimmick_icon.bitmap.height)
        end
        @pj_gimmick_icon.visible = @stack.first&.visible ? true : false
      end

      # @return [Array(String, Integer)] image et ligne (types Téra)
      def pj_gimmick_icon_name(pokemon)
        return nil unless pokemon.is_a?(PFM::PokemonBattler)
        return 'icon_mega' if pokemon.mega_evolved?

        case pokemon.pj_gimmick
        when :dynamax
          # L'icône disparaît à la fin du Dynamax (3 tours, changement de Pokémon…)
          return nil unless pokemon.respond_to?(:pj_dynamax?) && pokemon.pj_dynamax?

          return pokemon.respond_to?(:pj_gigantamax?) && pokemon.pj_gigantamax? ? 'icon_gmax' : 'icon_dynamax'
        when :tera then return ['tera_types', Gimmicks.tera_row(Gimmicks.tera_type_of(pokemon))]
        when :zmove then return Gimmicks.ultra?(pokemon) ? 'icon_ultra' : nil
        end
        return nil
      end
    end
    prepend PJGimmicks
  end
end
