# Advanced Pokédex : page Tâches (Pokédex Horizon), entre Données et Taille
#
# En haut : nom de l'espèce, niveau de recherche (barre et points / points nécessaires, coche verte une fois terminée).
# En dessous : les tâches (5 par écran ; A montre les suivantes s'il y en a plus), avec leurs paliers (orange quand ils
# sont atteints) et le compteur.
# Graphismes : graphics/pokedex/pe/adv_tasks et graphics/pokedex/advanced/tasks/ (tools/advanced_pokedex/build_tasks_page.py)
module AdvancedPokedex
  class TasksPage < UI::SpriteStack
    T = Tasks
    DIR = 'advanced/tasks/'
    WHITE = 10
    DARK = 0
    SMALL = 20
    ROWS = 5
    ROW_Y = 72
    ROW_H = 27
    PILL_W = 46
    BAR_W = 224
    TEXTS = {
      research: ['NIVEAU DE RECHERCHE', 'RESEARCH LEVEL'], complete: ['Recherche terminée !', 'Research complete!'],
      none: ['Pas de tâche pour ce Pokémon.', 'No tasks for this Pokémon.'], more: ['A : tâches suivantes', 'A: more tasks'],
      unknown: ['???', '???']
    }.freeze

    # @param viewport [Viewport]
    def initialize(viewport)
      super(viewport, default_cache: :pokedex)
      @shown = false
      @start = 0
      add_text(10, 27, 132, 13, text(:research), color: WHITE)
      @bar = add_sprite(13, 51, "#{DIR}bar")
      @bar.src_rect.set(0, 0, 0, 6)
      @stamp = add_sprite(292, 46, "#{DIR}complete")
      @rows = Array.new(ROWS) { |i| create_row(ROW_Y + i * ROW_H) }
      with_font(SMALL) do
        @points = add_text(240, 46, 50, 13, '', 2, color: DARK)
        @status = add_text(152, 28, 158, 13, '', 2, color: DARK)
        @empty = add_text(14, ROW_Y + 4, 292, 13, '', color: DARK)
      end
      self.visible = false
    end

    # @param species [Symbol]
    # @param known [Boolean] l'espèce a été vue
    def show(species, known)
      @species = species
      @known = known
      @tasks = known ? T.tasks_for(species) : []
      @start = 0 if @start >= @tasks.size
      refresh
      self.visible = true
    end

    # @return [Boolean] il y a d'autres tâches à montrer (A)
    def more?
      return @tasks && @tasks.size > ROWS
    end

    # Tâches suivantes
    def next_tasks
      @start = @start + ROWS >= @tasks.size ? 0 : @start + ROWS
      refresh
    end

    # @param value [Boolean]
    def visible=(value)
      @shown = value
      super
      hide_unused if value
    end

    private

    def text(key)
      return TEXTS[key][T.fr? ? 0 : 1]
    end

    def create_row(y)
      row = {}
      with_font(SMALL) do
        row[:label] = add_text(12, y, 250, 13, '', color: DARK)
        row[:pills] = Array.new(5) do |j|
          pill = add_sprite(12 + j * 50, y + 14, "#{DIR}threshold")
          pill.src_rect.set(0, 0, PILL_W, 11)
          [pill, add_text(12 + j * 50, y + 12, PILL_W, 13, '', 1, color: DARK)]
        end
      end
      row[:counter] = add_sprite(272, y + 3, "#{DIR}counter")
      row[:counter].src_rect.set(0, 0, 36, 22)
      row[:count] = add_text(272, y + 6, 36, 16, '', 1, color: WHITE)
      return row
    end

    def refresh
      points = @known ? T.points(@species) : 0
      needed = T.points_needed
      done = points >= needed
      @bar.src_rect.set(0, done ? 6 : 0, (BAR_W * [points, needed].min / needed.to_f).round, 6)
      @points.text = @known ? "#{points}/#{needed}" : text(:unknown)
      @status.text = done ? text(:complete) : (more? ? text(:more) : '')
      @empty.text = @known && @tasks.empty? ? text(:none) : ''
      @rows.each_with_index do |row, i|
        task = @tasks[@start + i]
        row[:task] = task
        next unless task

        progress = T.progress(@species, task)
        finished = progress >= task.thresholds.last
        row[:label].text = T.label(task)
        row[:pills].each_with_index do |(pill, number), j|
          threshold = task.thresholds[j]
          pill.src_rect.set(0, threshold && progress >= threshold ? 11 : 0, PILL_W, 11)
          number.text = threshold ? threshold.to_s : ''
          number.load_color(threshold && progress >= threshold ? WHITE : DARK)
        end
        row[:counter].src_rect.set(0, finished ? 22 : 0, 36, 22)
        row[:count].text = progress.to_s
      end
      @done = done
    end

    def hide_unused
      @stamp&.visible = @shown && @done ? true : false
      @rows&.each do |row|
        on = @shown && row[:task] ? true : false
        row[:label].visible = row[:counter].visible = row[:count].visible = on
        row[:pills].each_with_index do |(pill, number), j|
          pill.visible = number.visible = on && j < row[:task].thresholds.size
        end
      end
    end
  end
end

module GamePlay
  class AdvancedPokedex
    # Page Tâches (Pokédex Horizon seulement)
    module TasksPageScene
      def update_inputs
        return super unless @page == :tasks && Input.trigger?(:A)

        if @tasks_ui&.more?
          play_cursor_se
          @tasks_ui.next_tasks
        else
          play_buzzer_se
        end
        return false
      end

      private

      def refresh
        super
        tasks_page = @page == :tasks
        if tasks_page
          @texts&.visible = false
          @pokemon_sprite.visible = false
          @character_sprite.visible = false
          @scale.visible = false
          @tasks_ui ||= ::AdvancedPokedex::TasksPage.new(@viewport)
          @tasks_ui.show(@pokemon.db_symbol, $pokedex.creature_seen?(@pokemon.db_symbol))
        else
          @tasks_ui&.visible = false
        end
      end
    end
    prepend TasksPageScene
  end
end
