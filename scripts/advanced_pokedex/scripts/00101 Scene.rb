# Advanced Pokédex : scène des pages Taille et Poids
module GamePlay
  class AdvancedPokedex < BaseCleanUpdate
    PAGES = %i[height weight].freeze
    # Durée (images) d'un cran de la balance pendant l'animation
    SCALE_STEP_TIME = 3
    # Personnage choisi la dernière fois (gardé entre deux ouvertures)
    @last_character = 0
    class << self
      attr_accessor :last_character
    end

    # @return [Boolean] si le joueur est revenu à la fiche avec GAUCHE (et non B)
    attr_reader :back_to_info

    # @param pokemon [PFM::Pokemon]
    # @param dex [GamePlay::Dex, nil] Pokédex appelant (haut / bas changent de Pokémon)
    # @param page [Symbol] :height ou :weight
    def initialize(pokemon, dex = nil, page = :height)
      super()
      AdvancedPokedex.reload_config
      @pokemon = pokemon
      @dex = dex
      @page = PAGES.include?(page) ? page : :height
      @characters = ::AdvancedPokedex.characters
      @character_index = (self.class.last_character || 0) % @characters.size
      @scale_frame = 5
      @scale_target = 5
      @scale_timer = 0
      @back_to_info = false
    end

    # Relit les réglages (modifiés dans Studio) en mode debug
    def self.reload_config
      ::AdvancedPokedex.reload if PSDK_CONFIG.debug?
    end

    def update_inputs
      if Input.trigger?(:B)
        play_cancel_se
        @running = false
      elsif Input.trigger?(:LEFT)
        @page == :height ? close_to_info : change_page(:height)
      elsif Input.trigger?(:RIGHT)
        @page == :height ? change_page(:weight) : play_buzzer_se
      elsif Input.repeat?(:UP) || Input.repeat?(:DOWN)
        change_pokemon(Input.repeat?(:UP) ? -1 : 1)
      elsif Input.trigger?(:A)
        next_character
      else
        return true
      end
      return false
    end

    def update_mouse(_moved)
      return true unless Mouse.trigger?(:LEFT)

      mx = Mouse.x
      my = Mouse.y
      ::AdvancedPokedex::TABS.each do |page, (x, y)|
        next unless mx.between?(x, x + 42) && my.between?(y, y + 13)

        change_page(page) unless page == @page
        return false
      end
      return true unless my.between?(176, 231)

      next_character if mx >= 162
      return false
    end

    def update_graphics
      return true if @scale_frame == @scale_target || @page != :weight

      @scale_timer += 1
      return true if @scale_timer < SCALE_STEP_TIME

      @scale_timer = 0
      @scale_frame += @scale_target > @scale_frame ? 1 : -1
      place_weight_sprites
      return true
    end

    private

    def create_viewport
      @viewport = Viewport.create(:main, 60_000)
    end

    def create_graphics
      super
      @background = Sprite.new(@viewport)
      @title = Sprite.new(@viewport)
      @tabs = ::AdvancedPokedex::TABS.to_h do |page, (x, y)|
        sprite = Sprite.new(@viewport).set_bitmap("#{::AdvancedPokedex::DIR}tab_#{page}", :pokedex)
        sprite.set_position(x, y)
        sprite.src_rect.set(0, 0, sprite.bitmap.width, sprite.bitmap.height / 2)
        [page, sprite]
      end
      @scale = Sprite.new(@viewport).set_bitmap("#{::AdvancedPokedex::DIR}scale", :pokedex)
      @pokemon_sprite = Sprite.new(@viewport)
      @character_sprite = Sprite.new(@viewport)
      @silhouette = Shader.create(:color_shader)
      @silhouette.set_float_uniform('color', ::AdvancedPokedex.color(::AdvancedPokedex.get(:silhouette_color)))
      @texts = UI::SpriteStack.new(@viewport)
      @names = []
      @labels = []
      @values = []
      ::AdvancedPokedex::BOXES.each do |x, y, width|
        @names << @texts.add_text(x, y, width, 16, '', 0, color: 0)
        @labels << @texts.add_text(x, y + 20, width, 16, '', 0, color: 0)
        @values << @texts.add_text(x, y + 20, width, 16, '', 2, color: 0)
      end
      refresh
    end

    # Redessine la page
    def refresh
      dir = ::AdvancedPokedex::DIR
      @background.set_bitmap("#{dir}bg_#{@page}", :pokedex)
      @title.set_bitmap("#{dir}title_#{@page}", :pokedex)
      @title.set_position(::AdvancedPokedex::TITLE[0] - @title.bitmap.width / 2, ::AdvancedPokedex::TITLE[1])
      @title.visible = ::AdvancedPokedex.get(:show_titles) != false
      @tabs.each do |page, sprite|
        h = sprite.bitmap.height / 2
        sprite.src_rect.set(0, page == @page ? h : 0, sprite.bitmap.width, h)
        sprite.visible = ::AdvancedPokedex.get(:show_tabs) != false
      end
      refresh_texts
      @page == :height ? refresh_height : refresh_weight
    end

    # @return [Hash]
    def character
      return @characters[@character_index]
    end

    # @return [Boolean] si la taille et le poids du Pokémon sont connus
    def known?
      return true unless ::AdvancedPokedex.get(:require_caught)

      return $pokedex.creature_caught?(@pokemon.db_symbol)
    rescue StandardError
      return true
    end

    def refresh_texts
      key = @page.to_s
      label = ::AdvancedPokedex.label(key)
      @names[0].text = known? || seen? ? @pokemon.name.to_s : '???'
      @names[1].text = ::AdvancedPokedex.character_name(character)
      @labels.each { |text| text.text = label }
      @values[0].text = known? ? format_value(key, key == 'height' ? @pokemon.height : @pokemon.weight) : '???'
      @values[1].text = format_value(key, character[key.to_sym].to_f)
    end

    # @return [Boolean]
    def seen?
      return $pokedex.creature_seen?(@pokemon.db_symbol)
    rescue StandardError
      return true
    end

    # Valeur formatée comme dans le Pokédex (m / kg, ou pieds / livres selon les textes)
    # @param key [String]
    # @param value [Float]
    # @return [String]
    def format_value(key, value)
      if key == 'height'
        text = ext_text(9000, 71)
        return format(text, value) if text.downcase.end_with?('m')

        inches = (value * 39.3701).to_i
        return format(text, inches / 12, inches % 12)
      end
      text = ext_text(9000, 70)
      return format(text, text.downcase.end_with?('kg') ? value : (value * 2.20462).ceil(2))
    rescue StandardError
      return key == 'height' ? format('%.2f m', value) : format('%.1f kg', value)
    end

    # --- Taille ---------------------------------------------------------------
    def refresh_height
      @scale.visible = false
      cfg = ::AdvancedPokedex
      pokemon_height = known? ? @pokemon.height.to_f : 0
      character_height = character[:height].to_f
      tallest = [pokemon_height, character_height, 0.01].max
      px_per_m = cfg.get(:height_max).to_f / tallest
      base_y = cfg.get(:height_base_y).to_i
      show_pokemon = (known? || seen?) && pokemon_height > 0
      texture = show_pokemon ? @pokemon.battler_face : nil
      place(@pokemon_sprite, texture, nil, pokemon_height * px_per_m, cfg.get(:height_pokemon_x).to_i, base_y, true)
      texture = cfg.character_texture(character)
      rect = texture ? cfg.character_rect(texture, character) : nil
      place(@character_sprite, texture, rect, character_height * px_per_m, cfg.get(:height_character_x).to_i, base_y, true)
    end

    # --- Poids ----------------------------------------------------------------
    def refresh_weight
      @scale.visible = true
      @scale_target = known? ? scale_frame_for(@pokemon.weight.to_f, character[:weight].to_f) : 5
      @scale_timer = 0
      place_weight_sprites
    end

    # @param pokemon_weight [Float]
    # @param character_weight [Float]
    # @return [Integer] image de la balance (0 : plateau gauche en haut, 10 : plateau gauche en bas)
    def scale_frame_for(pokemon_weight, character_weight)
      return 5 if pokemon_weight <= 0 || character_weight <= 0

      ratio = Math.log2(pokemon_weight / character_weight)
      return (5 + (ratio * 1.5).round).clamp(0, ::AdvancedPokedex::SCALE_FRAMES - 1)
    end

    def place_weight_sprites
      cfg = ::AdvancedPokedex
      sx = cfg.get(:weight_scale_x).to_i
      sy = cfg.get(:weight_scale_y).to_i
      frame_h = @scale.bitmap.height / ::AdvancedPokedex::SCALE_FRAMES
      @scale.set_position(sx, sy)
      @scale.src_rect.set(0, @scale_frame * frame_h, @scale.bitmap.width, frame_h)
      (left_x, left_y), (right_x, right_y) = ::AdvancedPokedex::PANS[@scale_frame]
      offset = cfg.get(:pan_offset).to_i
      texture = (known? || seen?) ? @pokemon.battler_face : nil
      place(@pokemon_sprite, texture, nil, cfg.get(:weight_pokemon_size).to_f, sx + left_x, sy + left_y + offset, false, 56)
      texture = cfg.character_texture(character)
      rect = texture ? cfg.character_rect(texture, character) : nil
      place(@character_sprite, texture, rect, cfg.get(:weight_character_size).to_f, sx + right_x, sy + right_y + offset, false, 56)
    end

    # Place un sprite debout : centré sur x, pieds sur base_y, partie visible haute de height pixels
    # @param sprite [Sprite]
    # @param texture [Texture, nil]
    # @param rect [Array<Integer>, nil] partie de la texture (planche)
    # @param height [Float] hauteur affichée (pixels)
    # @param x [Integer]
    # @param base_y [Integer]
    # @param silhouette [Boolean]
    # @param max_width [Integer, nil]
    def place(sprite, texture, rect, height, x, base_y, silhouette, max_width = nil)
      sprite.visible = !texture.nil? && height > 0
      return unless sprite.visible

      sprite.bitmap = texture
      rect ||= [0, 0, texture.width, texture.height]
      sprite.src_rect.set(*rect)
      bx, by, bw, bh = ::AdvancedPokedex.bbox(texture, rect)
      zoom = [height, 1].max / bh.to_f
      zoom = [zoom, max_width / bw.to_f].min if max_width
      sprite.zoom = zoom
      sprite.set_position((x - (bx + bw / 2.0) * zoom).round, (base_y - (by + bh) * zoom).round)
      sprite.shader = silhouette ? @silhouette : nil
    end

    # --- Actions --------------------------------------------------------------
    def change_page(page)
      play_cursor_se
      @page = page
      @scale_frame = 5
      refresh
    end

    def next_character
      return play_buzzer_se if @characters.size <= 1

      play_cursor_se
      @character_index = (@character_index + 1) % @characters.size
      self.class.last_character = @character_index
      refresh
    end

    def change_pokemon(delta)
      return play_buzzer_se unless @dex.respond_to?(:advanced_dex_step)

      pokemon = @dex.advanced_dex_step(delta)
      return play_buzzer_se unless pokemon

      play_cursor_se
      @pokemon = pokemon
      @scale_frame = 5
      refresh
    end

    def close_to_info
      play_cancel_se
      @back_to_info = true
      @running = false
    end
  end
end
