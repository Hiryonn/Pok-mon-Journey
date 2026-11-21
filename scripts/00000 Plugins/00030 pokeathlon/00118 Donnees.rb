# Pokéathlon : Données du Pokéathlon (commande donnees_pokeathlon)
#
# Points, total gagné, coupes jouées ; record de chaque épreuve avec médaille ou couronne ; coupes gagnées.
module GamePlay
  class PokeathlonData < BaseCleanUpdate
    WHITE = 9

    PER_PAGE = 5

    def update_inputs
      pages = (Pokeathlon.courses.size - 1) / PER_PAGE + 1
      delta = (Input.trigger?(:RIGHT) ? 1 : 0) - (Input.trigger?(:LEFT) ? 1 : 0)
      if delta != 0 && pages > 1
        @page = (@page + delta) % pages
        play_cursor_se
        refresh_wins
        return true
      end
      if Input.trigger?(:A) || Input.trigger?(:B) || Mouse.trigger?(:LEFT) || Mouse.trigger?(:RIGHT)
        play_cancel_se
        @running = false
      end
      return true
    end

    private

    def refresh_wins
      @wins&.dispose
      store = Pokeathlon.data
      courses = Pokeathlon.courses
      pages = (courses.size - 1) / PER_PAGE + 1
      won = courses.count { |c| store['wins'][c['id']].to_i > 0 }
      text = Pokeathlon.t("Coupes gagnées : #{won} / #{courses.size}", "Courses won: #{won} / #{courses.size}")
      text = "< #{text}  (#{@page + 1}/#{pages}) >" if pages > 1
      @wins_title.text = text
      w = @wins = UI::SpriteStack.new(@viewport, default_cache: :interface)
      page = courses[@page * PER_PAGE, PER_PAGE] || []
      width = 284 / PER_PAGE
      page.each_with_index do |course, i|
        x = 18 + i * width + (width - 50) / 2
        sprite = w.add_sprite(x, 174, Pokeathlon.course_icon(course))
        sprite.opacity = store['wins'][course['id']].to_i > 0 ? 255 : 110
        w.add_text(x + 24, 177, 30, 16, "×#{store['wins'][course['id']].to_i}", color: WHITE)
      end
    end

    def create_graphics
      super
      store = Pokeathlon.data
      s = @stack = UI::SpriteStack.new(@viewport, default_cache: :interface)
      s.add_sprite(0, 0, Pokeathlon.file('fond_menu'))
      s.add_sprite(0, 0, Pokeathlon.file('titre'))
      s.add_text(0, 4, 320, 16, Pokeathlon.t('Données du Pokéathlon', 'Pokéathlon Data'), 1, color: WHITE)
      s.add_sprite(10, 26, Pokeathlon.file('panneau_epreuve'))
      s.with_font(20) do
        s.add_text(18, 31, 92, 13, Pokeathlon.t("Points : #{store['points']}", "Points: #{store['points']}"), color: WHITE)
        s.add_text(112, 31, 100, 13, Pokeathlon.t("Total : #{store['total']}", "Total: #{store['total']}"), 1, color: WHITE)
        s.add_text(210, 31, 92, 13, Pokeathlon.t("Coupes : #{store['played']}", "Courses: #{store['played']}"), 2, color: WHITE)
      end
      Pokeathlon::EVENTS.each_with_index do |id, i|
        x = 18 + (i / 5) * 146
        y = 50 + (i % 5) * 22
        record = store['records'][id]
        fmt = Pokeathlon.event_class(id).allocate
        s.with_font(20) do
          s.add_text(x, y + 2, 82, 13, Pokeathlon.event_name(id), color: WHITE)
          s.add_text(x + 82, y + 2, 40, 13, record.nil? ? '-' : fmt.score_text(record), 2, color: WHITE)
        end
        award = Pokeathlon.award(id, record)
        s.add_sprite(x + 124, y, Pokeathlon.file(award == :crown ? 'couronne' : 'medaille')) if award
      end
      s.with_font(20) { @wins_title = s.add_text(18, 160, 284, 13, '', 1, color: WHITE) }
      @page = 0
      refresh_wins
      s.add_sprite(0, 222, Pokeathlon.file('aide'))
      s.with_font(20) { s.add_text(0, 224, 320, 14, Pokeathlon.t('A / B : retour', 'A / B: back'), 1, color: WHITE) }
    end
  end
end
