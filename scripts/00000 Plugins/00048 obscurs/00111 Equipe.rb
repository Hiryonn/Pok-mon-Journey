# Écran d'équipe Horizon : jauge cœur en 5 barres sous la barre de PV + aura violette autour de la carte d'un Pokémon Obscur
# (sans ouvrir le résumé). Réglages : team_gauge (5 barres), team_aura (aura).
module UI
  module PartyPE
    class Card
      module ObscursTeam
        SEG_W = 10
        SEG_H = 3
        SEG_GAP = 1
        FILLED = [150, 70, 225].freeze
        EMPTY = [55, 38, 80].freeze

        def create_sprites
          super
          return unless Obscurs.setting('team_aura') || Obscurs.setting('team_gauge')

          @pj_aura = pj_frame(add_sprite(0, 0, NO_INITIAL_IMAGE))
          @pj_aura.visible = false
          @pj_segments = Array.new(5) { |i| pj_segment(add_sprite(46 + i * (SEG_W + SEG_GAP), 41, NO_INITIAL_IMAGE)) }
          @pj_segments.each { |sprite| sprite.visible = false }
        rescue StandardError => e
          Obscurs.log_error("équipe : #{e.message}") if Obscurs.respond_to?(:log_error)
        end

        def data=(value)
          super
          pj_refresh_obscur(value)
        end

        private

        def pj_frame(sprite)
          width = 150
          height = PartyPE::CARD_HEIGHT
          bmp = Bitmap.new(width, height)
          bmp.fill_rect(0, 0, width, height, Color.new(150, 70, 225, 70))
          bmp.clear_rect(2, 2, width - 4, height - 4)
          bmp.fill_rect(0, 0, width, 1, Color.new(190, 110, 255, 200))
          bmp.fill_rect(0, height - 1, width, 1, Color.new(190, 110, 255, 200))
          bmp.fill_rect(0, 0, 1, height, Color.new(190, 110, 255, 200))
          bmp.fill_rect(width - 1, 0, 1, height, Color.new(190, 110, 255, 200))
          sprite.bitmap = bmp
          return sprite
        end

        def pj_segment(sprite)
          bmp = Bitmap.new(SEG_W, SEG_H)
          bmp.fill_rect(0, 0, SEG_W, SEG_H, Color.new(255, 255, 255))
          sprite.bitmap = bmp
          return sprite
        end

        def pj_refresh_obscur(pokemon)
          shadow = pokemon.respond_to?(:shadow?) && pokemon.shadow? && !pokemon.egg?
          @pj_aura.visible = shadow && Obscurs.setting('team_aura') ? true : false if @pj_aura
          return unless @pj_segments

          show = shadow && Obscurs.setting('team_gauge') ? true : false
          stage = show ? pokemon.heart_stage : 0
          @pj_segments.each_with_index do |sprite, i|
            sprite.visible = show
            color = i < stage ? FILLED : EMPTY
            sprite.color.set(*color, 255) if sprite.respond_to?(:color) && sprite.color
          end
        rescue StandardError
          nil
        end
      end
      prepend ObscursTeam
    end
  end
end
