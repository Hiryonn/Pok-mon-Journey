# Interface Horizon : carte de dresseur (GamePlay::TCard), en pleine largeur
#
# - les 8 badges sur 2 rangées de 4, le portrait et les infos du dresseur collés au bord droit
# - les barres « badges » et « temps de jeu » occupent toute la largeur
# Le point (0, 0) de la scène est le coin haut gauche de TOUT l'écran (voir Ecran.adapter, gauche: true).
module GamePlay
  class TCard
    # La scène occupe tout l'écran
    # @return [Boolean]
    def origine_gauche?
      return TCardLarge.wide?
    end

    module TCardLarge
      # @return [Boolean]
      def self.wide?
        return defined?(::Ecran) && ::Ecran.grand? ? true : false
      end

      # @return [Integer] largeur de l'écran
      def self.full_width
        return wide? ? ::Ecran.logique_largeur : 320
      end

      # @return [Integer] largeur gagnée par rapport à 320
      def self.extra
        return full_width - 320
      end

      # Position d'un badge
      # @param index [Integer]
      # @return [Array(Integer, Integer)]
      def self.badge_position(index)
        return 21 + 70 * (index % 4), 41 + 58 * (index / 4)
      end

      # Fond recomposé à partir des cadres de l'image d'origine
      # @return [Bitmap]
      def self.background
        w = full_width
        e = extra
        panel = w - 107
        pieces = [[0, 5, w, 14, 100, 5, 100, 14],
                  [panel, 25, 98, 18, 213, 25, 98, 18], [panel + 8, 48, 82, 75, 221, 48, 82, 75], [panel, 127, 98, 18, 213, 127, 98, 18],
                  [w - 21, 223, 17, 15, 299, 223, 17, 15]]
        8.times { |i| pieces << [20 + 70 * (i % 4), 40 + 58 * (i / 4), 34, 34, 13, 29, 34, 34] }
        [155, 189].each do |y|
          bar = w - 36
          pieces << [18, y, 12, 18, 118, y, 12, 18] << [30, y, bar - 24, 18, 130, y, 169, 18] << [18 + bar - 12, y, 12, 18, 299, y, 12, 18]
        end
        return ::Ecran.composer('tcard/background', :interface, w, pieces) if e > 0

        return nil
      end

      private

      def create_sub_background
        super
        bitmap = TCardLarge.background
        @sub_background.bitmap = bitmap if bitmap
      end

      def create_trainer_sprite
        super
        @trainer_sprite.x += TCardLarge.extra
      end

      def create_badge_sprites
        super
        return unless TCardLarge.wide?

        @badges.each_with_index { |sprite, index| sprite.set_position(*TCardLarge.badge_position(index)) }
      end

      def create_money
        return super unless TCardLarge.wide?

        @texts.add_text(225 + TCardLarge.extra, 4, 88, 16, "#{PFM.game_state.money}$", 2, color: 9)
      end

      def create_name
        return super unless TCardLarge.wide?

        @texts.add_text(217 + TCardLarge.extra, 26, 96, 16, $trainer.name, 1, color: 9)
      end

      def create_do
        return super unless TCardLarge.wide?

        @texts.add_text(217 + TCardLarge.extra, 128, 96, 16, format('%<text>s %<id>05d', text: text_get(34, 2), id: $trainer.id % 100_000), color: 9)
      end

      def create_badge
        return super unless TCardLarge.wide?

        @texts.add_text(26, 156, TCardLarge.full_width - 52, 16, "#{text_get(25, 1)} #{$trainer.badge_counter}", color: 9)
      end

      def create_play_time
        return super unless TCardLarge.wide?

        @texts.add_text(26, 190, TCardLarge.full_width - 52, 16, "#{text_get(25, 5)} #{current_play_time}", color: 9)
      end
    end

    prepend TCardLarge
  end
end
