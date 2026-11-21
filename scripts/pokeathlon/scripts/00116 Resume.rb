# Pokéathlon : page du résumé (après l'arbre familial) : performances du jour (étoiles jusqu'au maximum de
# l'espèce), Jus de Noigrume bu, coupes gagnées par ce Pokémon.
if defined?(UI::SummaryPE::MemoPage) && UI::SummaryPE::ENABLED
  module UI
    module SummaryPE
      class PokeathlonPage < SpriteStack
        WHITE = 9
        DARK = 0

        def initialize(viewport)
          super(viewport, 0, 0, default_cache: :interface)
          add_sprite(0, 0, Pokeathlon.file('resume'))
          add_text(140, 61, 176, 16, Pokeathlon.t('Pokéathlon', 'Pokéathlon'), 1, color: WHITE)
          @stars = []
          Pokeathlon::STATS.each_with_index do |stat, i|
            add_text(142, 80 + i * 15, 80, 16, Pokeathlon.stat_name(stat), color: WHITE)
            @stars << Array.new(5) { |k| sp = add_sprite(232 + k * 15, 82 + i * 15, Pokeathlon.file('etoile')); sp.zoom = 1.4; sp }
          end
          with_font(20) do
            @juice = add_text(142, 160, 172, 13, '', color: WHITE)
            add_text(10, 51, 100, 13, Pokeathlon.t('Coupes gagnées', 'Courses won'), 1, color: DARK)
          end
          @courses = Array.new(5) do |i|
            y = 72 + i * 26
            badge = add_sprite(10, y, Pokeathlon.file('coupe_0'))
            medal = add_sprite(92, y + 3, Pokeathlon.file('medaille'))
            text = nil
            with_font(20) { text = add_text(34, y + 4, 58, 13, '', color: DARK) }
            [badge, medal, text]
          end
        end

        # 5 coupes affichées : celles gagnées par ce Pokémon d'abord
        def shown_courses(pokemon)
          list = Pokeathlon.courses
          won = pokemon.athlon_medals
          return (list.select { |c| won.include?(c['id']) } + list.reject { |c| won.include?(c['id']) }).first(5)
        end

        def data=(pokemon)
          @data = pokemon
          return unless (self.visible = pokemon ? true : false)
          return show_egg if pokemon.egg?

          perf = Pokeathlon.performance(pokemon)
          species = Pokeathlon.species_performance(pokemon.db_symbol, pokemon.form)
          Pokeathlon::STATS.each_with_index do |stat, i|
            @stars[i].each_with_index do |sp, k|
              frame = k < perf[stat] ? 0 : (k < species['max'][i] ? 1 : 2)
              sp.src_rect.set(frame * 9, 0, 9, 9)
            end
          end
          juice = pokemon.athlon_juice
          @juice.text = if juice && !juice.empty?
                          Pokeathlon.t('Jus : ', 'Juice: ') + juice.map { |st, v| "#{Pokeathlon.stat_name(st)} #{v > 0 ? '+' : ''}#{v}" }.join(', ')
                        else
                          Pokeathlon.t('Pas de Jus de Noigrume', 'No Aprijuice')
                        end
          shown = shown_courses(pokemon)
          @courses.each_with_index do |(badge, medal, text), i|
            course = shown[i]
            won = course && pokemon.athlon_medals.include?(course['id'])
            badge.visible = text.visible = !course.nil?
            medal.visible = won ? true : false
            next unless course

            badge.set_bitmap(Pokeathlon.course_icon(course), :interface)
            badge.opacity = won ? 255 : 110
            text.text = Pokeathlon.localized(course['name']).sub(/^(Coupe|Course) /i, '').sub(/ Course$/i, '')
          end
        end

        def visible=(value)
          super
          return unless value && @data && !@data.egg?

          shown = shown_courses(@data)
          @courses.each_with_index do |(badge, medal, text), i|
            badge.visible = text.visible = !shown[i].nil?
            medal.visible = shown[i] ? @data.athlon_medals.include?(shown[i]['id']) : false
          end
        end

        private

        def show_egg
          @stars.flatten.each { |sp| sp.src_rect.set(18, 0, 9, 9) }
          @juice.text = ''
        end
      end
    end
  end

  module GamePlay
    class Summary
      module PokeathlonPage
        private

        def create_uis
          super
          @uis << UI::SummaryPE::PokeathlonPage.new(@viewport)
        end
      end
      prepend PokeathlonPage
      remove_const(:LAST_STATE) if const_defined?(:LAST_STATE, false)
      LAST_STATE = UI::SummaryPE::FAMILY_PAGE + 1
    end
  end
end
