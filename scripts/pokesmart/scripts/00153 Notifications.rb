# PokeSmart : notifications du téléphone
# Une bannière glisse en haut de la carte pendant quelques secondes (avec un son), pour prévenir le joueur
# (raids rares, etc.). Les autres plugins appellent UI::PokeSmart::Notify.push(texte, titre: 'Raids').
module UI
  module PokeSmart
    module Notify
      DURATION = 240
      WIDTH = 220
      HEIGHT = 30
      Z = 40_000

      module_function

      # @param text [String]
      # @param title [String]
      def queue
        return (@queue ||= [])
      end

      def push(text, title: nil)
        queue << [title.to_s, text.to_s]
      end

      # Une bannière à la fois, tant que la carte est affichée
      def update
        if @stack
          @frame += 1
          offset = @frame < 20 ? -HEIGHT + (@frame * (HEIGHT + 6) / 20) : (@frame > DURATION - 20 ? -((@frame - DURATION + 20) * (HEIGHT + 6) / 20) + 6 : 6)
          @stack.y = offset
          close if @frame >= DURATION
        elsif (item = queue.shift)
          open(*item)
        end
      rescue StandardError => e
        log_error("PokeSmart : notification (#{e.message})") if respond_to?(:log_error, true)
        close
      end

      def open(title, text)
        @viewport = Viewport.create(:main, Z)
        @stack = UI::SpriteStack.new(@viewport, 50, -HEIGHT)
        back = @stack.add_sprite(0, 0, UI::SpriteStack::NO_INITIAL_IMAGE)
        bmp = Bitmap.new(WIDTH, HEIGHT)
        bmp.fill_rect(0, 0, WIDTH, HEIGHT, Color.new(20, 24, 40, 235))
        bmp.fill_rect(0, 0, WIDTH, 1, Color.new(120, 180, 255, 255))
        bmp.fill_rect(0, HEIGHT - 1, WIDTH, 1, Color.new(120, 180, 255, 255))
        back.bitmap = bmp
        @stack.add_text(6, 1, WIDTH - 12, 12, title.to_s, 0, color: 1) unless title.to_s.empty?
        @stack.with_font(20) { @stack.add_text(6, 13, WIDTH - 12, 14, text.to_s, 0, color: 9) }
        @frame = 0
        $game_system.se_play($data_system.decision_se) if $game_system && $data_system
      end

      def close
        @stack&.dispose
        @stack = nil
        @viewport&.dispose
        @viewport = nil
      end
    end
  end
end

class Scene_Map
  module PokeSmartNotify
    def update
      super
      UI::PokeSmart::Notify.update
    end
  end
  prepend PokeSmartNotify
end
