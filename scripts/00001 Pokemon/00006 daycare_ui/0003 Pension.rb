module GamePlay
  # Daycare screen
  class PensionUI < BaseCleanUpdate::FrameBalanced
    def initialize(daycare_id = $game_variables[GamePlay::PENSION_DAYCARE_VARIABLE])
      super(true)
      @daycare_id = daycare_id.to_i
      @counter = 0
      @pokemon_sprites = []
      @pokemon_gif_readers = []
    end

    # Update the scene inputs.
    # @return [Boolean]
    def update_inputs
      return close_scene_on_window_shutdown unless Graphics.window
      return @running = false if Input.trigger?(:B)

      true
    end

    # Allow mouse cancel on the bottom-right button.
    # @param _moved [Boolean]
    # @return [Boolean]
    def update_mouse(_moved)
      if Mouse.trigger?(:left)
        @mouse_button_cancel.set_press(@mouse_button_cancel.simple_mouse_in?)
      elsif Mouse.released?(:left)
        @running = false if @mouse_button_cancel.simple_mouse_in?
        @mouse_button_cancel.set_press(false)
      end
      true
    end

    # Update the animated background, daycare egg animation and gif battlers.
    # @return [void]
    def update_graphics
      @base_ui.update_background_animation
      update_pokemon_gif_animation
      update_egg_frame if @egg_sprite
    end

    private

    # Create the Pension UI graphics.
    # @return [void]
    def create_graphics
      return close_scene_on_window_shutdown unless Graphics.window

      create_viewport
      create_base_ui
      load_data
      create_frame
      create_sprites
      create_texts
    end

    # Create the generic base used by the Pension UI.
    # @return [void]
    def create_base_ui
      @base_ui = UI::GenericBase.new(@viewport, button_texts)
      @mouse_button_cancel = @base_ui.ctrl.last
    end

    # Load the daycare data shown by the UI.
    # @return [void]
    def load_data
      @count = $daycare.pokemon_count(@daycare_id)
      @pokemon1 = $daycare.get_full_pokemon(@daycare_id, 0)
      @pokemon2 = $daycare.get_full_pokemon(@daycare_id, 1)
      @egg_available = $daycare.has_egg?(@daycare_id)
    end

    # Create the daycare header frame according to the current language.
    # @return [void]
    def create_frame
      asset_name = $options.language == 'fr' ? 'daycare/frame_fr' : 'daycare/frame_en'
      @frame = Sprite.new(@viewport).set_bitmap(asset_name, :interface)
      @frame.z = 1
    end

    # Create the daycare boxes and egg frame.
    # @return [void]
    def create_sprites
      if @count.zero?
        @box_text = Sprite.new(@viewport).set_bitmap('daycare/box_text', :interface)
        @box_text.set_position(20, 65)
      end

      if @count >= 1
        @box_left = Sprite.new(@viewport).set_bitmap('daycare/box_left', :interface)
        @box_left.z = 2
      end

      if @count >= 2
        @box_right = Sprite.new(@viewport).set_bitmap('daycare/box_right', :interface)
        @box_right.z = 3
      end

      return unless @egg_available

      @egg_box = Sprite.new(@viewport).set_bitmap('daycare/egg_box', :interface)
      @egg_box.z = 4
      @egg_sprite = Sprite.new(@viewport).set_bitmap('daycare/egg_frame', :interface)
      @egg_sprite.x = 154
      @egg_sprite.y = 107
      @egg_sprite.z = 5
      @egg_sprite.src_rect.set(0, 0, 12, 15)
    end

    # Create the texts and sprites shown by the daycare UI.
    # @return [void]
    def create_texts
      @texts = UI::SpriteStack.new(@viewport)
      create_empty_message if @count.zero?
      create_pokemon_panel(@pokemon1, 0) if @pokemon1
      create_pokemon_panel(@pokemon2, 1) if @pokemon2
      @texts.z = 8
    end

    # Create the empty daycare message.
    # @return [void]
    def create_empty_message
      add_flat_text(@texts, 30, 87, 240, 16, empty_daycare_text, 0, color: 0)
    end

    # Create the content of one Pokemon panel.
    # @param pokemon [PFM::Pokemon]
    # @param index [Integer]
    # @return [void]
    def create_pokemon_panel(pokemon, index)
      offset = panel_offset(index)

      create_ball_icon(pokemon, offset)
      create_shiny_icon(pokemon, offset)
      create_gender_icon(pokemon, offset)
      create_name_text(pokemon, offset)
      create_level_text(pokemon, index, offset)
      create_pokemon_sprite(pokemon, index)
    end

    # Create the Pokeball icon of one stored Pokemon.
    # @param pokemon [PFM::Pokemon]
    # @param offset [Integer]
    # @return [void]
    def create_ball_icon(pokemon, offset)
      ball = Sprite.new(@viewport).set_bitmap(data_item(pokemon.captured_with).icon, :icon)
      ball.zoom = 0.5
      ball.set_position(36 + offset, 53)
      ball.z = 7
    end

    # Create the shiny icon of one stored Pokemon.
    # @param pokemon [PFM::Pokemon]
    # @param offset [Integer]
    # @return [void]
    def create_shiny_icon(pokemon, offset)
      return unless pokemon.shiny?

      shiny = Sprite.new(@viewport).set_bitmap('shiny', :interface)
      shiny.zoom = 1
      shiny.set_position(117 + offset, 56)
      shiny.z = 7
    end

    # Create the gender icon of one stored Pokemon.
    # @param pokemon [PFM::Pokemon]
    # @param offset [Integer]
    # @return [void]
    def create_gender_icon(pokemon, offset)
      return if pokemon.gender.zero?

      gender = @texts.add_sprite(129 + offset, 55, nil, type: UI::GenderSprite)
      gender.data = pokemon
    end

    # Create the displayed Pokemon name.
    # @param pokemon [PFM::Pokemon]
    # @param offset [Integer]
    # @return [void]
    def create_name_text(pokemon, offset)
      add_flat_text(@texts, 40 + offset, 52, 96, 16, pokemon.given_name.to_s, 1, color: 9, sizeid: 0)
    end

    # Create the displayed level text of one stored Pokemon.
    # @param pokemon [PFM::Pokemon]
    # @param index [Integer]
    # @param offset [Integer]
    # @return [void]
    def create_level_text(pokemon, index, offset)
      earned_level = $daycare.lvl_earned(@daycare_id, index)
      text = if $options.language == 'fr'
               "Niveau : #{pokemon.level} (+#{earned_level})"
             else
               "Level : #{pokemon.level} (+#{earned_level})"
             end
      add_flat_text(@texts, 40 + offset, 173, 96, 16, text, 1, color: 9, sizeid: 0)
    end

    # Create the Pokemon battler sprite shown in a daycare box.
    # @param pokemon [PFM::Pokemon]
    # @param panel_index [Integer]
    # @return [void]
    def create_pokemon_sprite(pokemon, panel_index)
      sprite = Sprite.new(@viewport)
      sprite.z = 6
      sprite.visible = false
      gif_reader = nil

      if (gif_reader = pokemon.gif_face)
        sprite.bitmap = Texture.new(gif_reader.width, gif_reader.height)
        gif_reader.update(sprite.bitmap)
        bottom_padding = compute_bottom_transparent_padding(sprite.bitmap)
        apply_gif_pokemon_position(sprite, panel_index, bottom_padding)
      else
        filename = PFM::Pokemon.front_filename(pokemon.id, pokemon.form, pokemon.female?, pokemon.shiny?, false)
        sprite.set_bitmap(RPG::Cache.poke_front(filename, pokemon.shiny? ? 1 : 0), :battler)
        sprite.set_position(39 + panel_offset(panel_index), 74)
        sprite.ox = 0
        sprite.oy = 0
      end

      sprite.visible = true
      @pokemon_sprites[panel_index] = sprite
      @pokemon_gif_readers[panel_index] = gif_reader
    end

    # Update the animated daycare egg frame.
    # @return [void]
    def update_egg_frame
      @counter += 1
      if @counter == 60
        @egg_sprite.src_rect.set(12, 0, 12, 15)
      elsif @counter >= 120
        @counter = 0
        @egg_sprite.src_rect.set(0, 0, 12, 15)
      end
    end

    # Update the gif readers of Pokemon that use animated faces.
    # @return [void]
    def update_pokemon_gif_animation
      @pokemon_gif_readers.each_with_index do |gif_reader, index|
        next unless gif_reader && @pokemon_sprites[index]&.bitmap

        gif_reader.update(@pokemon_sprites[index].bitmap)
      end
    end

    # Compute the transparent bottom padding of a gif bitmap.
    # @param bitmap [Texture]
    # @return [Integer]
    def compute_bottom_transparent_padding(bitmap)
      png_data = bitmap&.to_png
      return 0 unless png_data

      image = LiteRGSS::Image.new(png_data, true)
      padding = 0
      (image.height - 1).downto(0) do |y|
        row_has_pixel = false
        0.upto(image.width - 1) do |x|
          alpha = image.get_pixel_alpha(x, y)
          if alpha && alpha > 0
            row_has_pixel = true
            break
          end
        end
        break if row_has_pixel

        padding += 1
      end
      padding
    ensure
      image&.dispose
    end

    # Apply the correct position to a gif battler so it sits inside its white box.
    # @param sprite [Sprite]
    # @param panel_index [Integer]
    # @param bottom_padding [Integer]
    # @return [void]
    def apply_gif_pokemon_position(sprite, panel_index, bottom_padding)
      sprite.ox = sprite.bitmap.width / 2
      sprite.oy = 0
      sprite.x = pokemon_gif_center_x(panel_index)
      sprite.y = pokemon_gif_bottom_y(panel_index) - (sprite.bitmap.height - bottom_padding.to_i)
    end

    # Return the horizontal offset of a panel.
    # @param panel_index [Integer]
    # @return [Integer]
    def panel_offset(panel_index)
      panel_index == 1 ? 145 : 0
    end

    # Return the X center used to align gif battlers in the left/right white box.
    # @param panel_index [Integer]
    # @return [Integer]
    def pokemon_gif_center_x(panel_index)
      return 181 + (103 / 2) + 1 if panel_index == 1

      36 + (103 / 2) + 1
    end

    # Return the bottom Y used to align gif battlers in the left/right white box.
    # @param panel_index [Integer]
    # @return [Integer]
    def pokemon_gif_bottom_y(panel_index)
      return 71 + 102 - 10 if panel_index == 1

      71 + 102 - 10
    end

    # Add a text without shadow, matching the original Pension style.
    # @param stack [UI::SpriteStack]
    # @param args [Array]
    # @param kwargs [Hash]
    # @return [Text]
    def add_flat_text(stack, *args, **kwargs)
      text = stack.add_text(*args, **kwargs)
      text.draw_shadow = false
      text
    end

    # Stop the daycare scene chain when the window was closed.
    # @return [false]
    def close_scene_on_window_shutdown
      $scene = nil
      @running = false
    end

    # Return the empty daycare sentence.
    # @return [String]
    def empty_daycare_text
      $options.language == 'fr' ? "Il n'y a pas de Pokémon à la pension." : 'No Pokemon in Day Care.'
    end

    # Return the GenericBase button texts.
    # @return [Array<String>]
    def button_texts
      [nil, nil, nil, $options.language == 'fr' ? 'Quitter' : 'Quit']
    end
  end
end

GamePlay.pension_ui_class = GamePlay::PensionUI
