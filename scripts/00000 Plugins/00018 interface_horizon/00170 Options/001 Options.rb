# Interface Horizon : options (GamePlay::Options), en pleine largeur
#
# - la description reste à gauche, la liste des options occupe tout le reste de la largeur (boutons élargis)
# - bandeau du haut sur toute la largeur (la plaque « OPTIONS » reste centrée)
# Le point (0, 0) de la scène est le coin haut gauche de TOUT l'écran (voir Ecran.adapter, gauche: true).
module UI
  module OptionsLarge
    # Écran plus large que 320 px ?
    # @return [Boolean]
    def self.wide?
      return defined?(::Ecran) && ::Ecran.grand? ? true : false
    end

    # @return [Integer] largeur de l'écran
    def self.full_width
      return wide? ? ::Ecran.logique_largeur : 320
    end

    # Bouton d'option élargi
    module ButtonLarge
      def initialize(viewport, index, option)
        super
        return unless OptionsLarge.wide?

        width = viewport.rect.width - UI::Options::Button::OPTION_BASE_X - 4
        @option_background.bitmap = ::Ecran.tranches('options/option', 40, 95, width)
        @option_value.x += (width - 135) / 2
      end
    end
  end

  module Options
    class Button
      prepend OptionsLarge::ButtonLarge
    end
  end
end

module GamePlay
  class Options
    # La scène occupe tout l'écran
    # @return [Boolean]
    def origine_gauche?
      return UI::OptionsLarge.wide?
    end

    module Large
      private

      # Liste des options : de la fin de la description jusqu'au bord droit de l'écran
      def create_viewport
        super
        return unless UI::OptionsLarge.wide?

        @button_viewport.dispose if @button_viewport && !@button_viewport.disposed?
        x = 160
        @button_viewport = Viewport.create(x, 45, UI::OptionsLarge.full_width - x, 156, 10_000)
      end

      def create_frame
        super
        return unless UI::OptionsLarge.wide?

        add_disposable(*::Ecran.elargir_plaque(@frame, 80, 240))
      end
    end

    prepend Large
  end
end
