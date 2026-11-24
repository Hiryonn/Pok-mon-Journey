# Poffin : donner un poffin à un Pokémon (commande nourrir_poffin)
#   1. Poffins : haut / bas choisit, A prend le poffin, B quitte
#   2. Pokémon : haut / bas choisit, A donne le poffin (en haut : ce qu'il lui apporte), B revient aux poffins
# Le poffin mangé disparaît de la liste. Un Pokémon qui a déjà tout le lustre (255), ou aucune condition à gagner, n'en veut plus.
module GamePlay
  class PoffinFeeding < BaseCleanUpdate::FrameBalanced
    P = ::Poffin
    DARK = 0
    SMALL_FONT = 20
    SX = P::SCREEN_X
    SY = P::SCREEN_Y
    LIST_X = 36
    LIST_Y = 92
    LIST_W = 184
    ROW_H = 18
    ROWS = 5

    # @return [Boolean] au moins un poffin a été mangé
    attr_reader :fed

    def initialize
      super()
      @state = :poffins
      @index = 0
      @offset = 0
      @pokemon_index = 0
      @fed = false
      @message = nil
    end

    def update_inputs
      move_cursor
      if Input.trigger?(:A)
        action_a
      elsif Input.trigger?(:B)
        action_b
      end
      return false
    end

    def update_graphics
      return nil
    end

    private

    def move_cursor
      delta = Input.repeat?(:UP) ? -1 : (Input.repeat?(:DOWN) ? 1 : 0)
      return if delta == 0 || items.empty?

      key = @state == :poffins ? :@index : :@pokemon_index
      value = (instance_variable_get(key) + delta) % items.size
      instance_variable_set(key, value)
      @offset = value if value < @offset
      @offset = value - ROWS + 1 if value >= @offset + ROWS
      @offset = 0 if items.size <= ROWS
      @message = nil
      play_cursor_se
      refresh
    end

    # @return [Array] les poffins ou les Pokémon selon l'étape
    def items
      return @state == :poffins ? P.inventory : party
    end

    # @return [Array<PFM::Pokemon>]
    def party
      return ($actors || ($pokemon_party && $pokemon_party.actors) || []).to_a
    end

    def current
      return items[@state == :poffins ? @index : @pokemon_index]
    end

    def action_a
      return play_buzzer_se if items.empty?

      if @state == :poffins
        @state = :pokemon
        @offset = 0
        @message = nil
        play_decision_se
      else
        feed
      end
      refresh
    end

    def action_b
      play_cancel_se
      if @state == :pokemon
        @state = :poffins
        @offset = [@index - ROWS + 1, 0].max
        @message = nil
        refresh
      else
        @running = false
      end
    end

    def feed
      pokemon = current
      poffin = P.inventory[@index]
      result = pokemon && poffin && P.feed(pokemon, poffin)
      unless result
        @message = text(:refuse)
        return play_buzzer_se
      end
      P.inventory.delete_at(@index)
      @fed = true
      @message = "#{pokemon.given_name} : #{gains_text(result)}"
      play_decision_se
      @index = 0
      @offset = 0
      @state = :poffins
      @running = false if P.inventory.empty?
    end

    # @param result [Hash] { gains:, sheen: }
    # @return [String] ex. « +5 Épicé  +2 Lustre »
    def gains_text(result)
      parts = result[:gains].each_with_index.reject { |gain, _| gain <= 0 }.map { |gain, i| "+#{gain} #{P.flavor_name(P::FLAVORS[i])}" }
      parts << "+#{result[:sheen]} #{text(:sheen)}" if result[:sheen] > 0
      return parts.join('  ')
    end

    # --- Création --------------------------------------------------------------------------
    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @stack.add_sprite(0, 0, 'poffin/fond')
      @stack.add_sprite(SX, SY, 'poffin/fond_liste')
      @top = @stack.with_font(SMALL_FONT) { @stack.add_text(0, 5, 320, 14, '', 1, color: DARK) }
      @hint = @stack.with_font(SMALL_FONT) { @stack.add_text(0, 220, 320, 14, '', 1, color: DARK) }
      @rows = Array.new(ROWS) do |i|
        [@stack.with_font(SMALL_FONT) { @stack.add_text(SX + LIST_X, SY + LIST_Y + i * ROW_H, LIST_W - 40, 14, '', color: DARK) },
         @stack.with_font(SMALL_FONT) { @stack.add_text(SX + LIST_X + LIST_W - 40, SY + LIST_Y + i * ROW_H, 40, 14, '', 2, color: DARK) }]
      end
      @pofin = @stack.add_sprite(SX + 128, SY + 40, 'poffin/pofin_1')
      @pofin.zoom = 0.4
      @pofin.ox = @pofin.width / 2
      @pofin.oy = @pofin.height / 2
      refresh
    end

    def refresh
      @hint.text = @message || text(@state == :poffins ? :hint_poffins : :hint_pokemon)
      @rows.each_with_index do |(name, value), i|
        item = items[@offset + i]
        selected = @offset + i == (@state == :poffins ? @index : @pokemon_index)
        if item.nil?
          name.text = i.zero? ? text(@state == :poffins ? :none : :no_pokemon) : ''
          value.text = ''
        elsif @state == :poffins
          name.text = "#{selected ? '> ' : '  '}#{P.name(item)}"
          value.text = item['smoothness'].to_s
        else
          name.text = "#{selected ? '> ' : '  '}#{item.given_name}"
          value.text = item.egg? ? '' : "N.#{item.level}"
        end
      end
      refresh_top
    end

    # Le haut : saveurs du poffin choisi, ou ce qu'il apporterait au Pokémon choisi
    def refresh_top
      poffin = P.inventory[@index]
      @pofin.visible = poffin && poffin['kind'] != 'burnt' ? true : false
      @pofin.set_bitmap("poffin/pofin_#{poffin['tier']}", :interface) if @pofin.visible
      if poffin.nil?
        @top.text = ''
      elsif @state == :poffins
        @top.text = poffin['kind'] == 'burnt' ? text(:burnt) : P::FLAVORS.each_index.map { |i| "#{P.flavor_name(P::FLAVORS[i])} #{poffin['flavors'][i]}" }.join('  ')
      else
        effect = current && P.effect(current, poffin)
        @top.text = effect ? gains_text(effect) : text(:refuse)
      end
    end

    TEXTS = {
      hint_poffins: ['A : choisir   B : quitter', 'A: choose   B: quit'],
      hint_pokemon: ['A : donner à ce Pokémon   B : retour', 'A: feed this Pokémon   B: back'],
      none: ['Aucun poffin', 'No poffins'],
      no_pokemon: ['Aucun Pokémon', 'No Pokémon'],
      refuse: ['Il n\'en veut pas.', 'It doesn\'t want it.'],
      burnt: ['Poffin brûlé : aucun effet', 'Burnt poffin: no effect'],
      sheen: ['Lustre', 'Sheen']
    }.freeze

    # @param key [Symbol]
    # @return [String]
    def text(key)
      return TEXTS[key][P.language_index]
    end
  end
end
