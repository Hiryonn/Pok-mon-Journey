# Script décompilé depuis le bytecode du jeu (Ruby 3.0) — fichier d'origine : RMXP/99999_OverworldPokemonPokedex.rb
# Les commentaires et la mise en forme d'origine ne sont pas récupérables.

module Raty
  module OverworldPokemonPokedex
    CENTER_ALIGN_TAG = ":[align=center]:"
    NO_ALREADY_SEEN_TEXT = Object.new.freeze
    module_function

    def build_pokemon(db_symbol, form)
      PFM::Pokemon.new(db_symbol, 1, false, true, form.to_i)
    end

    def creature_data(db_symbol)
      data = data_creature(db_symbol)
      return if data.db_symbol == :__undef__

      data
    end

    def added_message(pokemon)
      pokemon_name = "\\c[2]#{pokemon.name}\\c[0]"
      if $options.language == "en"
        "#{CENTER_ALIGN_TAG}#{pokemon_name} has been added to the Pokédex!"
      else
        "#{CENTER_ALIGN_TAG}#{pokemon_name} a été ajouté au Pokédex !"
      end
    end

    def resolve_message_text(text)
      if text.is_a?(Array) && text.size == 2 && text.all? { |value| value.is_a?(Integer) }
        return ext_text(*text)
      end
      if text.is_a?(Array) && text[0] == :ext_text
        ext_text(text[1], text[2])
      elsif text.is_a?(Array) && text[0] == :text_get
        text_get(text[1], text[2])
      else
        text.to_s
      end
    end

    def visible_bounds_for(pokemon, fallback_bitmap)
      gif_reader = pokemon.respond_to?(:gif_face) ? pokemon.gif_face : nil
      return visible_gif_bounds(gif_reader) if gif_reader

      visible_bitmap_bounds(fallback_bitmap)
    end

    def visible_gif_bounds(gif_reader)
      begin
        return unless gif_reader
        min_x = gif_reader.width
        min_y = gif_reader.height
        max_x = -1
        max_y = -1
        original_frame = gif_reader.frame
        gif_reader.frame_count.times do |frame_index|
          frame_bitmap = Texture.new(gif_reader.width, gif_reader.height)
          gif_reader.frame = frame_index
          gif_reader.draw(frame_bitmap)
          bounds = visible_bitmap_bounds(frame_bitmap)
          frame_bitmap.dispose
          next unless bounds
          frame_min_x, frame_min_y, frame_width, frame_height = bounds
          frame_max_x = frame_min_x + frame_width - 1
          frame_max_y = frame_min_y + frame_height - 1
          min_x = frame_min_x if frame_min_x < min_x
          min_y = frame_min_y if frame_min_y < min_y
          max_x = frame_max_x if frame_max_x > max_x
          next max_y = frame_max_y if frame_max_y > max_y
        end
        return if max_x < min_x || max_y < min_y
        [min_x, min_y, max_x - min_x + 1, max_y - min_y + 1]
      ensure
        gif_reader.frame = original_frame if gif_reader && !original_frame.nil?
      end
    end

    def visible_bitmap_bounds(bitmap)
      begin
        return unless bitmap
        png_data = bitmap.to_png
        return unless png_data
        image = LiteRGSS::Image.new(png_data, true)
        min_x = image.width
        min_y = image.height
        max_x = -1
        max_y = -1
        0.upto(image.height - 1) do |y|
          0.upto(image.width - 1) do |x|
            alpha = image.get_pixel_alpha(x, y)
            next unless alpha && alpha > 0
            min_x = x if x < min_x
            min_y = y if y < min_y
            max_x = x if x > max_x
            next max_y = y if y > max_y
          end
        end
        return if max_x < min_x || max_y < min_y
        [min_x, min_y, max_x - min_x + 1, max_y - min_y + 1]
      ensure
        image&.dispose
      end
    end
  end
end

module GamePlay
  class << self
    attr_accessor(:overworld_pokemon_pokedex_scene_class)

    def open_overworld_pokemon_pokedex_scene(pokemon, message)
      current_scene.call_scene(overworld_pokemon_pokedex_scene_class || OverworldPokemonPokedexScene, pokemon, message, fade_out_params: [:transition, 0], fade_in_params: [:transition, 0])
    end
  end

  class OverworldPokemonPokedexScene < BaseCleanUpdate::FrameBalanced
    VIEWPORT_Z = 10000
    BACKGROUND_Z = 0
    SPRITE_Z = 1

    def initialize(pokemon, message)
      super(false)
      @pokemon = pokemon
      @message = message
      @message_started = false
      define_main_begin_fade(:transition, 0)
      define_main_end_fade(:transition, 0)
    end

    def update_inputs
      return false if @message_started
      @message_started = true
      display_message_and_wait(@message)
      @running = false
      false
    end

    def update_graphics
      @pokemon_sprite&.update
      true
    end

    private

    def create_graphics
      create_viewport
      create_background
      create_pokemon_sprite
    end

    def create_viewport
      @viewport = Viewport.create(:main, VIEWPORT_Z)
    end

    def create_background
      @background = Sprite.new(@viewport)
      @background.set_bitmap("mark_seen_bg", :interface)
      @background.set_position(0, 0)
      @background.z = BACKGROUND_Z
    end

    def create_pokemon_sprite
      @pokemon_sprite = UI::PokemonFaceSprite.new(@viewport, false)
      @pokemon_sprite.z = SPRITE_Z
      @pokemon_sprite.data = @pokemon
      center_pokemon_sprite
    end

    def center_pokemon_sprite
      bounds = Raty::OverworldPokemonPokedex.visible_bounds_for(@pokemon, @pokemon_sprite.bitmap)
      if bounds
        min_x, min_y, width, height = bounds
        @pokemon_sprite.ox = min_x + width / 2.0
        @pokemon_sprite.oy = min_y + height / 2.0
      elsif @pokemon_sprite.bitmap
        @pokemon_sprite.ox = @pokemon_sprite.bitmap.width / 2.0
        @pokemon_sprite.oy = @pokemon_sprite.bitmap.height / 2.0
      end

      @pokemon_sprite.set_position(Graphics.width / 2, Graphics.height / 2)
    end
  end
end

GamePlay.overworld_pokemon_pokedex_scene_class = GamePlay::OverworldPokemonPokedexScene

class Interpreter
  def ow_pokemon_seen(db_symbol, already_seen_text = Raty::OverworldPokemonPokedex::NO_ALREADY_SEEN_TEXT, form = nil)
    data = Raty::OverworldPokemonPokedex.creature_data(db_symbol)
    unless data
      return log_error("Unknown Pokemon db_symbol for ow_pokemon_seen: #{db_symbol.inspect}")
    end

    form_id = form || 0
    pokemon = Raty::OverworldPokemonPokedex.build_pokemon(data.db_symbol, form_id)
    already_seen = form.nil? ? $pokedex.creature_seen?(pokemon.db_symbol) : $pokedex.creature_seen?(pokemon.db_symbol, pokemon.form)
    if already_seen
      return true if already_seen_text.equal?(Raty::OverworldPokemonPokedex::NO_ALREADY_SEEN_TEXT)
      $game_system.cry_play(pokemon.id, form: pokemon.form)
      text = Raty::OverworldPokemonPokedex.resolve_message_text(already_seen_text)
      message(text) unless text.empty?
      @wait_count = 2
      true
    else
      $game_system.cry_play(pokemon.id, form: pokemon.form)
      $pokedex.mark_seen(pokemon.db_symbol, pokemon.form)
      GamePlay.open_overworld_pokemon_pokedex_scene(pokemon, Raty::OverworldPokemonPokedex.added_message(pokemon))
      @wait_count = 2
    end
  end
end
