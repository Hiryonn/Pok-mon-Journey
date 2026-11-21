# Wardrobe : l'onglet « Tenues » du sac Horizon (interface_horizon)
# Même comportement que dans le sac PE (00103) : un onglet après les poches, A enfile la tenue, A sur la tenue
# portée retrouve l'apparence d'origine, le titre indique la tenue portée.
# L'icône (chemise) est la 9e colonne de graphics/interface/bag_horizon/pockets.png (tools/wardrobe/icone_sac_horizon.py).
# Wardrobe::TAB_ENABLED = false le retire ; en cas d'erreur, l'onglet se désactive tout seul et le sac reste normal.
# Ce fichier se charge après interface_horizon (ordre alphabétique des plugins) : ses méthodes passent avant HorizonStyle.
module Wardrobe
  @tab_failed = false unless instance_variable_defined?(:@tab_failed)

  class << self
    attr_accessor :tab_failed unless method_defined?(:tab_failed)
  end
end

if defined?(UI::BagHorizon) && defined?(GamePlay::Bag)
  UI::BagHorizon::POCKET_ICONS[:wardrobe] = 8 unless UI::BagHorizon::POCKET_ICONS.frozen?

  module GamePlay
    class Bag
      module WardrobeTabHorizon
        public

        # @param index [Integer] poche réelle, ou le rang juste après la dernière poche : l'onglet des tenues
        def change_pocket(index)
          if wardrobe_tab? && index == @last_socket_index + 1
            super(0)
            wardrobe_enter
          else
            @wardrobe_tab = false
            super
          end
        rescue StandardError => e
          wardrobe_failure(e)
        end

        # Garde la liste des tenues si une action de PSDK (tri...) a rechargé celle de la poche
        def update_inputs
          result = super
          wardrobe_sync if @wardrobe_tab
          return result
        rescue StandardError => e
          wardrobe_failure(e)
          return result
        end

        private

        # @return [Boolean] l'onglet existe dans ce sac
        def wardrobe_tab?
          return false if ::Wardrobe.tab_failed
          return @wardrobe_tab_exists unless @wardrobe_tab_exists.nil?

          @wardrobe_tab_exists = ::Wardrobe::TAB_ENABLED && @mode == :menu && ::Wardrobe.ready? &&
                                 !::Wardrobe.owned_items.empty? && @last_socket_index.is_a?(Integer)
        end

        def create_pocket_ui
          return super unless wardrobe_tab?

          @pocket_ui = UI::BagHorizon::Pockets.new(@viewport, @pocket_indexes + [:wardrobe])
          @pocket_ui.index = @socket_index
          @pocket_name = UI::BagHorizon::Title.new(@viewport)
          update_pocket_name
        end

        def update_pocket_name
          return super unless @wardrobe_tab

          worn = ::Wardrobe.worn_item
          outfit = worn && ::Wardrobe.find(worn)
          @pocket_name.text = outfit ? "#{::Wardrobe.tab_name} (#{::Wardrobe.name_of(outfit)})" : ::Wardrobe.tab_name
        end

        # Gauche / droite : l'onglet des tenues vient après la dernière poche
        def update_socket_input
          return super unless wardrobe_tab?

          dir = Input.repeat?(:LEFT) ? -1 : (Input.repeat?(:RIGHT) ? 1 : 0)
          return true if dir == 0

          total = @last_socket_index + 2
          current = @wardrobe_tab ? total - 1 : @socket_index
          target = (current + dir) % total
          play_horizon_pocket_se
          if target == total - 1
            change_pocket(target)
          else
            @socket_index = target
            change_pocket(target)
          end
          return false
        rescue StandardError => e
          wardrobe_failure(e)
          return false
        end

        def wardrobe_enter
          @wardrobe_tab = true
          @wardrobe_list = ::Wardrobe.owned_items
          @pocket_ui.index = @last_socket_index + 1
          update_pocket_name
          wardrobe_refresh
        end

        # Remet la liste des tenues à l'écran
        def wardrobe_refresh
          @item_list = @wardrobe_list.dup
          @index = 0
          @last_index = [@item_list.size - 1, 0].max
          update_item_button_list if respond_to?(:update_item_button_list, true)
          @scroll_bar.index = @index if @scroll_bar.respond_to?(:index=)
          update_info
        end

        # Si PSDK a rechargé la liste de la poche, on remet celle des tenues
        def wardrobe_sync
          return if @item_list == @wardrobe_list

          index = @index.to_i
          wardrobe_refresh
          horizon_select(index) if respond_to?(:horizon_select, true)
        end

        # A : enfiler la tenue (ou retrouver l'apparence d'origine si elle est déjà portée)
        def action_a
          return super unless @wardrobe_tab

          item = @item_list[@index]
          outfit = item && ::Wardrobe.find(item)
          return play_buzzer_se unless outfit

          ::Wardrobe.worn?(item) ? ::Wardrobe.restore : ::Wardrobe.wear(outfit)
          play_decision_se
          update_pocket_name
        rescue StandardError => e
          wardrobe_failure(e)
        end

        # L'onglet pose problème : on le quitte et on le désactive
        # @param error [StandardError]
        def wardrobe_failure(error)
          ::Wardrobe.tab_failed = true
          log_error("Wardrobe : onglet du sac Horizon désactivé (#{error.class} : #{error.message})") if respond_to?(:log_error, true)
          return unless @wardrobe_tab

          @wardrobe_tab = false
          @pocket_ui.index = 0 if @pocket_ui
          method(:change_pocket).super_method&.call(0)
        rescue StandardError
          nil
        end
      end
      prepend WardrobeTabHorizon
    end
  end
end
