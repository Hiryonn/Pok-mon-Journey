# Pokéblocs : état des Pokémon (conditions de concours et Lustre), et Pokébloc donné à manger
#   Gauche / Droite (ou Haut / Bas) : Pokémon   A : donner le Pokébloc   B : retour
module Pokeblocs
  class ConditionScene < GamePlay::BaseCleanUpdate
    DARK = 0
    WHITE = 10
    BAR_X = 142
    BAR_Y = 42
    ROW_H = 22
    # @return [Boolean] le Pokébloc a été mangé
    attr_reader :eaten

    # @param block [Hash, nil] Pokébloc à donner (nil : simple consultation)
    # @param party [Array<PFM::Pokemon>]
    def initialize(block = nil, party = $actors)
      super()
      @block = block
      @party = party.reject(&:egg?)
      @index = 0
      @eaten = false
      @anim = nil
    end

    def update_inputs
      return true if @anim

      if (Input.repeat?(:RIGHT) || Input.repeat?(:DOWN)) && @party.size > 1
        change((@index + 1) % @party.size)
      elsif (Input.repeat?(:LEFT) || Input.repeat?(:UP)) && @party.size > 1
        change((@index - 1) % @party.size)
      elsif Input.trigger?(:A) && @block
        give
      elsif Input.trigger?(:B)
        play_cancel_se
        @running = false
      end
      return true
    end

    def update_graphics
      @face&.update
      @icons&.each(&:update)
      update_animation if @anim
      return true
    end

    private

    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport)
      @stack.add_sprite(0, 0, Pokeblocs.file('etat'))
      title = @block ? Pokeblocs.t("Donner : #{Pokeblocs.name(@block)}", "Give: #{Pokeblocs.name(@block)}") : Pokeblocs.t('État des Pokémon', 'Condition')
      @stack.add_text(6, 1, 240, 16, title, color: WHITE)
      @block_icon = @stack.add_sprite(298, 1, @block ? Pokeblocs.icon(@block) : nil)
      @face = @stack.push(66, 150, nil, type: UI::PokemonFaceSprite)
      @name_text = @stack.add_text(8, 160, 120, 16, '', color: DARK)
      @stack.with_font(20) do
        @nature_text = @stack.add_text(8, 178, 120, 13, '', color: DARK)
        @likes_text = @stack.add_text(8, 192, 120, 13, '', color: DARK)
        @dislikes_text = @stack.add_text(8, 206, 120, 13, '', color: DARK)
        @hint = @stack.add_text(132, 222, 186, 13, hint_text, 1, color: DARK)
      end
      names = Pokeblocs.stat_names
      @bars = Array.new(6) do |i|
        y = BAR_Y + i * ROW_H
        visible = i < 5 || Pokeblocs.sheen?
        label = @stack.add_text(BAR_X, y - 14, 100, 16, names[i], color: DARK)
        slot = @stack.add_sprite(BAR_X - 2, y - 1, Pokeblocs.file('barre_fond'))
        bar = @stack.add_sprite(BAR_X, y, Pokeblocs.file('barres'))
        value = @stack.add_text(BAR_X + 96, y - 14, 70, 16, '', 2, color: DARK)
        arrow = @stack.add_sprite(BAR_X + 132, y - 6, Pokeblocs.file('fleche'))
        arrow.visible = false
        [label, slot, bar, value].each { |s| s.visible = visible }
        { bar: bar, value: value, arrow: arrow, row: i, visible: visible }
      end
      @icons = @party.each_with_index.map do |pokemon, i|
        icon = @stack.push(150 + i * 28, 194, nil, type: UI::PokemonIconSprite)
        icon.data = pokemon
        icon
      end
      @selector = @stack.add_sprite(0, 0, Pokeblocs.file('ligne'))
      @selector.src_rect.set(0, 0, 26, 18)
      @selector.opacity = 160
      @flying = @stack.add_sprite(0, 0, @block ? Pokeblocs.icon(@block) : nil)
      @flying.visible = false
      refresh
    end

    def hint_text
      return Pokeblocs.t('A : donner   B : retour', 'A: give   B: back') if @block

      return Pokeblocs.t('B : retour', 'B: back')
    end

    def change(index)
      @index = index
      play_cursor_se
      refresh
    end

    def pokemon
      return @party[@index]
    end

    def refresh(values = nil)
      return if @party.empty?

      @face.data = pokemon
      @name_text.text = "#{pokemon.given_name}  #{Pokeblocs.t('N.', 'Lv.')}#{pokemon.level}"
      nature = data_nature(pokemon.nature_db_symbol) rescue nil
      @nature_text.text = Pokeblocs.t("Nature : #{nature_name}", "Nature: #{nature_name}")
      @likes_text.text = Pokeblocs.t("Aime : #{flavor_name(nature&.liked_flavor)}", "Likes: #{flavor_name(nature&.liked_flavor)}")
      @dislikes_text.text = Pokeblocs.t("N’aime pas : #{flavor_name(nature&.disliked_flavor)}", "Dislikes: #{flavor_name(nature&.disliked_flavor)}")
      draw_bars(values || Pokeblocs.conditions(pokemon))
      @icons.each_with_index { |icon, i| icon.opacity = i == @index ? 255 : 150 }
      @selector.set_position(150 + @index * 28 - 13, 186)
    end

    def nature_name
      return data_nature(pokemon.nature_db_symbol).name.to_s rescue pokemon.nature_db_symbol.to_s
    end

    def flavor_name(flavor)
      return '—' if flavor.nil? || flavor.to_s.empty? || flavor.to_s == 'none'

      index = FLAVORS.index(flavor.to_sym)
      return '—' unless index

      return (Pokeblocs.fr? ? %w[Épicé Sec Sucré Amer Acide] : %w[Spicy Dry Sweet Bitter Sour])[index]
    end

    def draw_bars(values)
      @bars.each_with_index do |row, i|
        value = values[i].to_i.clamp(0, 255)
        row[:bar].src_rect.set(0, i * 7, (128 * value / 255.0).round, 6)
        row[:bar].visible = row[:visible] && value > 0
        row[:value].text = value >= 255 ? 'MAX' : value.to_s
      end
    end

    def give
      reason = Pokeblocs.refusal(pokemon, @block)
      if reason
        play_buzzer_se
        display_message(reason)
        return
      end
      play_decision_se
      @taste = Pokeblocs.taste(pokemon, @block)
      @before, @after = Pokeblocs.feed(pokemon, @block)
      @eaten = true
      @anim = 0
      @flying.visible = true
      @block_icon.visible = false
    end

    # Le Pokébloc vole jusqu'au Pokémon, puis les barres montent
    def update_animation
      @anim += 1
      if @anim <= 30
        t = @anim / 30.0
        @flying.set_position(298 + (58 - 298) * t, 2 + (96 - 2) * t - Math.sin(t * Math::PI) * 30)
      elsif @anim == 31
        @flying.visible = false
        Audio.se_play(pokemon.cry) rescue nil
      elsif @anim <= 70
        t = (@anim - 31) / 39.0
        draw_bars(@before.each_with_index.map { |v, i| v + (@after[i] - v) * t })
      elsif @anim == 71
        draw_bars(@after)
        @bars.each { |row| row[:arrow].visible = row[:visible] && @after[row[:row]] > @before[row[:row]] }
      elsif @anim == 80
        finish_message
        @anim = nil
        @running = false
      end
    end

    def finish_message
      name = pokemon.given_name
      text = case @taste
             when :liked then Pokeblocs.t("#{name} a adoré le #{Pokeblocs.name(@block)} !", "#{name} happily ate the #{Pokeblocs.name(@block)}!")
             when :disliked then Pokeblocs.t("#{name} n’a pas trop aimé le #{Pokeblocs.name(@block)}...", "#{name} disdainfully ate the #{Pokeblocs.name(@block)}...")
             else Pokeblocs.t("#{name} a mangé le #{Pokeblocs.name(@block)}.", "#{name} ate the #{Pokeblocs.name(@block)}.")
             end
      display_message(text)
      raised = (0...5).select { |i| @after[i] > @before[i] }.map { |i| Pokeblocs.stat_names[i] }
      return if raised.empty?

      list = raised.size == 1 ? raised.first : "#{raised[0..-2].join(', ')} #{Pokeblocs.t('et', 'and')} #{raised.last}"
      display_message(Pokeblocs.t("#{list} #{raised.size == 1 ? 'augmente' : 'augmentent'} !", "#{list} rose!"))
      @bars.each { |row| row[:arrow].visible = false }
    end
  end
end
