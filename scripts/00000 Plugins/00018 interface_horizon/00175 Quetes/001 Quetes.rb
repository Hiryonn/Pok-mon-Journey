# Interface Horizon : journal de quêtes (GamePlay::QuestUI), en pleine largeur
#
# - bandeau, pied de page, boutons de quête, description, objectifs et barre de défilement occupent toute la largeur
# Le point (0, 0) de la scène est le coin haut gauche de TOUT l'écran (voir Ecran.adapter, gauche: true).
module UI
  module QuestLarge
    # @return [Boolean]
    def self.wide?
      return defined?(::Ecran) && ::Ecran.grand? ? true : false
    end

    # @return [Integer] largeur gagnée par rapport à 320
    def self.extra
      return wide? ? ::Ecran.logique_largeur - 320 : 0
    end

    # Cadre de la scène : bandeau (plaque centrale gardée) et pied de page sur toute la largeur
    module FrameLarge
      def initialize(viewport)
        super
        return unless QuestLarge.wide?

        width = 320 + QuestLarge.extra
        plate = 152
        px = (width - plate) / 2
        pieces = [[0, 0, px, 28, 10, 0, 70, 28], [px, 0, plate, 28, 84, 0, plate, 28],
                  [px + plate, 0, width - px - plate, 28, 240, 0, 70, 28], [0, 214, width, 26, 0, 214, 320, 26]]
        self.bitmap = ::Ecran.composer(UI::Quest::QuestFrame::FILENAME, :interface, width, pieces)
      end
    end

    # Bouton de quête élargi
    module ButtonLarge
      private

      def create_frame
        super
        return unless QuestLarge.wide?

        width = 282 + QuestLarge.extra
        @frame.bitmap = ::Ecran.tranches(frame_filepath, 20, 262, width)
        @frame.src_rect.set(0, 0, width, 20)
        @frame_border.bitmap = ::Ecran.tranches('quest/win_border', 20, 262, width)
      end
    end

    # Barre de défilement collée au bord droit
    module ScrollBarLarge
      def initialize(viewport)
        super
        set_position(310 + QuestLarge.extra, UI::Quest::ScrollBar::BASE_Y) if QuestLarge.wide?
      end
    end

    # Liste des objectifs : texte plus large, flèches au bord droit
    module ObjectiveListLarge
      private

      def create_text
        return super unless QuestLarge.wide?

        @text = add_text(0, 0, 272 + QuestLarge.extra, 16, '')
      end

      def create_arrows
        super
        return unless QuestLarge.wide?

        @arrow_up.set_position(257 + QuestLarge.extra, 3)
        @arrow_down.set_position(257 + QuestLarge.extra, 59)
      end
    end

    # Description et objectif courant : texte plus large
    module CompositionLarge
      private

      def create_quest_description
        return super unless QuestLarge.wide?

        @description = Text.new(0, @sub_viewport, 27, 62, 272 + QuestLarge.extra, 16, '')
        update_quest_description unless current_list.nil?
        @sub_viewport.rect.height = 61
      end

      def create_quest_current_objective
        return super unless QuestLarge.wide?

        @current_objective = Text.new(0, @sub_viewport, 27, 129, 272 + QuestLarge.extra, 16, '', 0, nil, 10)
        update_quest_current_objective if current_list
      end
    end
  end

  module Quest
    class QuestFrame
      prepend QuestLarge::FrameLarge
    end

    class QuestButton
      prepend QuestLarge::ButtonLarge
    end

    class ScrollBar
      prepend QuestLarge::ScrollBarLarge
    end

    class ObjectiveList
      prepend QuestLarge::ObjectiveListLarge
    end

    class Composition
      prepend QuestLarge::CompositionLarge
    end
  end
end

module GamePlay
  class QuestUI
    # La scène occupe tout l'écran
    # @return [Boolean]
    def origine_gauche?
      return UI::QuestLarge.wide?
    end

    module Large
      private

      # Zone des objectifs : toute la largeur utile
      def create_viewport
        super
        return unless UI::QuestLarge.wide?

        @sub_viewport2.dispose if @sub_viewport2 && !@sub_viewport2.disposed?
        @sub_viewport2 = Viewport.create(27, 62, 272 + UI::QuestLarge.extra, 64, 21_000)
      end
    end

    prepend Large
  end
end
