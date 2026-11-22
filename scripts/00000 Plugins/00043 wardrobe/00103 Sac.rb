# Wardrobe : l'onglet « Tenues » du sac
# Un onglet de plus après les poches du sac (quand le joueur possède au moins une tenue). Il montre les objets-tenues ;
# A enfile la tenue, A sur la tenue portée retrouve l'apparence d'origine. Le titre indique la tenue portée.
# Il n'existe que dans le sac « menu » du sac PE (interface_pe) ; Wardrobe::TAB_ENABLED = false le retire.
# Si quelque chose se passe mal (version de PSDK différente), l'onglet se désactive tout seul et le sac reste normal.
module Wardrobe
  # Un échec dans l'onglet le désactive jusqu'à la fin de la session
  @tab_failed = false

  class << self
    attr_accessor :tab_failed
  end
end

if defined?(UI::BagPE) && defined?(GamePlay::Bag)
  UI::BagPE::POCKET_TABS[:wardrobe] = 9 unless UI::BagPE::POCKET_TABS.frozen?

  module GamePlay
    class Bag
      module WardrobeTab
        public

        # Quitter l'onglet quand PSDK change de poche de son côté
        # @param index [Integer]
        def change_pocket(index)
          if @wardrobe_tab
            @wardrobe_tab = false
            @socket_index = (index + 1) % (@last_socket_index + 1) if @last_socket_index.to_i > 0 # force le rafraîchissement
          end
          super
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

          @pocket_ui = UI::BagPE::Tabs.new(@viewport, @pocket_indexes + [:wardrobe])
          @pocket_ui.index = @socket_index
          @pocket_name = UI::BagPE::Title.new(@viewport)
          update_pocket_name
        end

        def update_pocket_name
          return super unless @wardrobe_tab

          worn = ::Wardrobe.worn_item
          outfit = worn && ::Wardrobe.find(worn)
          @pocket_name.text = outfit ? "#{::Wardrobe.tab_name} (#{::Wardrobe.name_of(outfit)})" : ::Wardrobe.tab_name
        end

        # Gauche / droite : comme le sac PE, mais l'onglet des tenues vient après la dernière poche
        def update_socket_input
          return super unless wardrobe_tab?

          dir = Input.repeat?(:LEFT) ? -1 : (Input.repeat?(:RIGHT) ? 1 : 0)
          return true if dir == 0

          col = @index % UI::BagPE::COLUMNS
          at_edge = dir < 0 ? col == 0 : (col == UI::BagPE::COLUMNS - 1 || @index >= pe_last_item)
          play_cursor_se
          if at_edge
            return false if @searching

            wardrobe_move(dir)
          else
            pe_select(@index + dir)
          end
          return false
        rescue StandardError => e
          wardrobe_failure(e)
          return false
        end

        # @param dir [Integer] -1 ou 1
        def wardrobe_move(dir)
          total = @last_socket_index + 2
          current = @wardrobe_tab ? total - 1 : @socket_index
          target = (current + dir) % total
          if target == total - 1
            wardrobe_enter
          else
            change_pocket(target)
          end
        end

        def wardrobe_enter
          @wardrobe_tab = true
          @wardrobe_list = ::Wardrobe.owned_items
          @item_list = @wardrobe_list.dup
          @pocket_ui.index = @last_socket_index + 1
          update_pocket_name
          pe_select(0)
        end

        # Si PSDK a rechargé la liste de la poche, on remet celle des tenues
        def wardrobe_sync
          return if @item_list == @wardrobe_list

          @item_list = @wardrobe_list.dup
          pe_select(@index)
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
          log_error("Wardrobe : onglet du sac désactivé (#{error.class} : #{error.message})") if respond_to?(:log_error, true)
          return unless @wardrobe_tab

          @wardrobe_tab = false
          change_pocket(0) if respond_to?(:change_pocket, true)
        end
      end
      prepend WardrobeTab
    end
  end
end
