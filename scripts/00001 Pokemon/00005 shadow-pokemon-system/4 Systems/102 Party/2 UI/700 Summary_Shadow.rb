module UI
  # UI part displaying the heart of a Shadow Pokemon in the Summary. The experience of a Shadow
  # Pokemon is held back, so its gauge shows the lock on its heart instead.
  class Summary_Shadow < SpriteStack
    # Image of a lock the heart still holds
    BAR_FILLED = 'shadow/heart_bar_filled'
    # Image of a lock the heart has opened
    BAR_EMPTY = 'shadow/heart_bar_empty'
    # Width of one lock, in pixels. Five of them side by side span the width the experience bar
    # takes on the other pages.
    BAR_WIDTH = 15
    # Width of the dark border of a lock, which the filling never covers
    BAR_BORDER = 2
    # Where the gauge starts, the place the experience bar takes on the other pages
    GAUGE_ORIGIN = [30, 128]
    # How many lines the sentence at the foot of the page can take
    DOOR_LINE_COUNT = 2
    # Height of one of those lines, in pixels
    DOOR_LINE_HEIGHT = 16

    # Create a new shadow heart UI for the summary
    # @param viewport [Viewport]
    def initialize(viewport)
      super(viewport, 0, 0, default_cache: :interface)
      init_sprite
    end

    # Define the pokemon shown by this UI
    # @param pokemon [PFM::Pokemon]
    def data=(pokemon)
      return unless (self.visible = !pokemon.nil?)

      super
      refresh_lines(pokemon)
    end

    private

    def init_sprite
      create_background
      create_lines
      create_gauge
    end

    def create_background
      push(0, 0, 'summary/memo')
    end

    def create_lines
      with_surface(114, 19, 95) do
        add_line(0, PFM::ShadowTexts.message(:summary_title))
        add_line(1, PFM::ShadowTexts.message(:locked_heart))
        add_line(2, PFM::ShadowTexts.message(:opened_bars))
        add_line(3, PFM::ShadowTexts.message(:held_experience))
        @state_line = add_line(5, '')
        @heart_value = add_line(1, '', 2, color: 1, dx: 1)
        @bars_value = add_line(2, '', 2, color: 1, dx: 1)
        @experience_value = add_line(3, '', 2, color: 1, dx: 1)
      end
      # The band at the bottom of the page, where the memo page writes its own sentence. A text of
      # the engine never folds on its own, so a sentence that needs two lines carries the break.
      @door_lines = Array.new(DOOR_LINE_COUNT) { |index| add_text(13, 138 + index * DOOR_LINE_HEIGHT, 320, 16, '') }
    end

    # The gauge sits where the experience bar of the other pages sits, since it stands in for it. It
    # is drawn bar by bar rather than as one length, the heart of Pokemon XD counting five locks and
    # not a percentage.
    def create_gauge
      PFM::ShadowHeart::BARS.times { |index| push(*bar_position(index), BAR_EMPTY) }
      @filled_bars = Array.new(PFM::ShadowHeart::BARS) { |index| push(*bar_position(index), BAR_FILLED) }
    end

    # Where the lock of that rank sits
    # @param index [Integer]
    # @return [Array<Integer>]
    def bar_position(index)
      return [GAUGE_ORIGIN.first + index * BAR_WIDTH, GAUGE_ORIGIN.last]
    end

    # @param pokemon [PFM::Pokemon]
    def refresh_lines(pokemon)
      @heart_value.text = "#{(pokemon.shadow_heart_rate * 100).round} %"
      @bars_value.text = "#{pokemon.fully_opened_heart_bars} / #{PFM::ShadowHeart::BARS}"
      @experience_value.text = pokemon.held_experience.to_s
      @state_line.text = PFM::ShadowTexts.message(state_key(pokemon))
      refresh_door(pokemon)
      refresh_gauge(pokemon)
    end

    # Write the sentence at the foot of the page, spread over the lines it asks for
    # @param pokemon [PFM::Pokemon]
    def refresh_door(pokemon)
      # The dialog file carries the break as the \nl of the engine, which the text loader has already turned into one
      sentence = PFM::ShadowTexts.heart_door(pokemon.opened_heart_bars, pokemon.purifiable?).split("\n")
      @door_lines.each_with_index { |line, index| line.text = sentence[index].to_s }
    end

    # Light the locks the heart still holds. The one being worked on is cut to how far it has come,
    # so the gauge answers every point the heart loses and not only a whole lock.
    # @param pokemon [PFM::Pokemon]
    def refresh_gauge(pokemon)
      locked = pokemon.shadow_heart_rate * PFM::ShadowHeart::BARS
      @filled_bars.each_with_index { |bar, index| crop_bar(bar, (locked - index).clamp(0.0, 1.0)) }
    end

    # Show that much of a lock, from none of it to all of it. Cutting the source rather than hiding
    # the sprite, because showing the page turns every sprite of the stack back on.
    # @param bar [Sprite]
    # @param ratio [Float] from 0.0 to 1.0
    def crop_bar(bar, ratio)
      filling = ((BAR_WIDTH - BAR_BORDER * 2) * ratio).round
      bar.src_rect.width = filling.zero? ? 0 : filling + BAR_BORDER
    end

    # @param pokemon [PFM::Pokemon]
    # @return [Symbol]
    def state_key(pokemon)
      return :out_of_control if pokemon.unstable?
      return :ready_to_purify if pokemon.purifiable?

      return :calm
    end
  end
end
