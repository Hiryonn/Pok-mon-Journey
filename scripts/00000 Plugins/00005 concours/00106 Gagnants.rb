# Concours : tableau des gagnants (dernier vainqueur de chaque concours, par type et par rang)
#   Flèches : choisir un concours   B : fermer
module Concours
  class WinnersScene < GamePlay::BaseCleanUpdate
    DARK = 0
    WHITE = 10
    COL_X = 68
    COL_W = 49
    ROW_Y = 48
    ROW_H = 30

    def initialize
      super()
      @col = 0
      @row = 0
    end

    def update_inputs
      if Input.repeat?(:RIGHT)
        move((@col + 1) % 5, @row)
      elsif Input.repeat?(:LEFT)
        move((@col - 1) % 5, @row)
      elsif Input.repeat?(:DOWN)
        move(@col, (@row + 1) % 4)
      elsif Input.repeat?(:UP)
        move(@col, (@row - 1) % 4)
      elsif Input.trigger?(:B) || Input.trigger?(:A)
        play_cancel_se
        @running = false
      end
      return true
    end

    def update_graphics
      @icons&.each { |icon| icon&.update }
      return true
    end

    private

    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport)
      @stack.add_sprite(0, 0, Concours.file('tableau'))
      @stack.add_text(6, 1, 300, 16, Concours.t('Tableau des gagnants', 'Contest winners'), color: WHITE)
      @stack.with_font(20) do
        Concours.type_ids.each_with_index do |type, i|
          x = (COL_X + i * COL_W + COL_W / 2 - 30).clamp(6, 252)
          y = 23 + (i % 2) * 12
          @stack.add_sprite(x, y, Concours.pill_file(type))
          @stack.add_text(x, y - 1, 60, 13, Concours.type_name(type), 1, color: WHITE)
        end
        Concours.rank_ids.each_with_index do |rank, i|
          @stack.add_sprite(8, ROW_Y + i * ROW_H + 9, Concours.file('ruban_rang'))
          @stack.add_text(25, ROW_Y + i * ROW_H + 10, 44, 13, Concours.rank_name(rank), color: DARK)
        end
      end
      @cursor = @stack.add_sprite(0, 0, Concours.file('curseur'))
      @cursor.zoom_x = 0.95 if @cursor.respond_to?(:zoom_x=)
      @icons = []
      Concours.rank_ids.each_with_index do |rank, r|
        Concours.type_ids.each_with_index do |type, c|
          pokemon = Concours.winner_pokemon(Concours.winner(type, rank))
          x = COL_X + c * COL_W + COL_W / 2
          y = ROW_Y + r * ROW_H + 15
          if pokemon
            icon = @stack.push(x, y, nil, type: UI::PokemonIconSprite)
            icon.data = pokemon
            @icons << icon
          else
            @stack.add_text(x - 10, y - 8, 20, 16, '—', 1, color: DARK)
          end
        end
      end
      @line1 = @stack.add_text(12, 182, 296, 16, '', color: DARK)
      @line2 = @stack.add_text(12, 198, 296, 16, '', color: DARK)
      @stack.with_font(20) { @line3 = @stack.add_text(12, 216, 296, 13, '', color: DARK) }
      refresh
    end

    def move(col, row)
      @col = col
      @row = row
      play_cursor_se
      refresh
    end

    def refresh
      @cursor.set_position(COL_X + @col * COL_W + COL_W / 2 - 22, ROW_Y + @row * ROW_H + 15 - 22)
      type = Concours.type_ids[@col]
      rank = Concours.rank_ids[@row]
      record = Concours.winner(type, rank)
      @line1.text = Concours.contest_name(type, rank)
      if record
        species = data_creature(record['species'].to_sym).name rescue record['species']
        @line2.text = Concours.t("#{record['trainer']} et #{record['name']} (#{species})", "#{record['trainer']} with #{record['name']} the #{species}")
        @line3.text = Concours.t("Score : #{record['score']} points", "Score: #{record['score']} points")
      else
        @line2.text = Concours.t('Personne n’a encore gagné ce concours.', 'Nobody has won this contest yet.')
        @line3.text = ''
      end
    end
  end
end
