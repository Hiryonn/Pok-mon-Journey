# Script décompilé depuis le bytecode du jeu (Ruby 3.0) — fichier d'origine : RMXP/99999_BallChanger.rb
# Les commentaires et la mise en forme d'origine ne sont pas récupérables.

module BallChanger
  module_function

  PRICE = 10000

  def money_check
    PFM.game_state.money >= PRICE
  end

  def choose_creature
    GamePlay.open_party_menu_to_select_pokemon($actors)
    if $game_variables[43] != -1
      @pokemon = $actors[$game_variables[43]]
      return false if @pokemon.egg?
      log_error("Pokémon selected : #{@pokemon.given_name} - Captured with : #{@pokemon.captured_with}")
      PFM::Text.set_variable("[pokemonName]", @pokemon.given_name)
      true
    else
      false
    end
  end

  def choose_ball
    result = false
    GamePlay.open_bag_to_give_ball do |scene|
      item = scene.return_data
      next log_error("No item selected") if item == -1

      ball_item = data_item(item)
      log_error("Item selected : #{item}")
      log_error("ball item : #{ball_item.inspect}")
      @ball_item_id = item
      @ball_item = ball_item

      result = true
    end

    result
  end

  def selected_pokemon
    @pokemon
  end

  def selected_ball_item
    @ball_item
  end

  def selected_ball_item_id
    @ball_item_id
  end

  def reset_selection
    @pokemon = nil
    @ball_item = nil
    @ball_item_id = nil
  end

  def apply_selected_ball
    return false unless @pokemon && @ball_item && @ball_item_id
    return false unless money_check
    return false if @pokemon.captured_with == @ball_item.id

    $bag.remove_item(@ball_item_id, 1)
    PFM.game_state.money -= PRICE

    @pokemon.captured_with = @ball_item.id
    Audio.se_play("audio/se/purchase_sound", 100)
    log_error("Ball changed for #{@pokemon.given_name} to #{@ball_item_id}")
    true
  end

  def choose_and_apply_ball
    result = false

    GamePlay.open_bag_to_give_ball do |scene|
      item = scene.return_data
      next log_error("No item selected") if item == -1

      ball_item = data_item(item)
      log_error("Item selected : #{item}")
      log_error("ball item : #{ball_item.inspect}")

      $bag.remove_item(item, 1)
      PFM.game_state.money -= PRICE

      @pokemon.captured_with = ball_item.id
      Audio.se_play("audio/se/purchase_sound", 100)
      log_error("Ball changed for #{@pokemon.given_name} to #{item}")

      result = true
    end

    result
  end
end

module GamePlay
  class Bag < BaseCleanUpdate::FrameBalanced
    remove_const(:POCKETS_PER_MODE) if const_defined?(:POCKETS_PER_MODE)

    POCKETS_PER_MODE = { menu: [1, 2, 6, 3, 5, 4, 8], battle: [1, 2, 6, 4], berry: [4], hold: [1, 2, 6, 4], shop: [1, 2, 6, 4], ball: [2] }
  end
end

module GamePlay
  class Bag
    remove_const(:CHOICE_MODE_A) if const_defined?(:CHOICE_MODE_A)

    CHOICE_MODE_A = { menu: :choice_a_menu, berry: :choice_a_berry, hold: :choice_a_hold, shop: :choice_a_shop, map: :choice_a_map, battle: :choice_a_battle, ball: :choice_a_hold }
  end
end

module GamePlay
  class << self
    def open_bag_to_give_ball(&block)
      current_scene.call_scene(bag_class, :ball, &block)
    end
  end
end

module GamePlay
  class << self
    attr_accessor(:ball_changer_ui_class)

    def open_ball_changer_ui
      BallChanger.reset_selection
      current_scene.call_scene(ball_changer_ui_class)
    end
  end
end

module GamePlay
  class BallChangerUI < BaseCleanUpdate
    MOUSE_ACTIONS = [:action_a, :action_x, nil, :action_b].freeze
    TITLE_X = 78
    TITLE_Y = 4
    TEXT_Z = 9
    SELECTED_BOX_ANIM_INTERVAL = 120
    BOX_RIGHT_OFFSET_X = 145
    BOX_POKEMON_X = 39
    BOX_POKEMON_Y = 74
    BOX_BALL_X = 36
    BOX_BALL_Y = 52
    LEFT_WHITE_X = 36
    LEFT_WHITE_Y = 71
    LEFT_WHITE_WIDTH = 103
    LEFT_WHITE_HEIGHT = 102
    RIGHT_WHITE_X = 181
    RIGHT_WHITE_Y = 71
    RIGHT_WHITE_WIDTH = 103
    RIGHT_WHITE_HEIGHT = 102
    HEADER_TEXT_X = 40
    HEADER_TEXT_Y = 53
    HEADER_TEXT_WIDTH = 96
    BOTTOM_TEXT_X = 40
    BOTTOM_TEXT_Y = 173
    BOTTOM_TEXT_WIDTH = 96
    GENDER_ICON_X = 129
    GENDER_ICON_Y = 54
    SHINY_ICON_X = 115
    SHINY_ICON_Y = 71
    INFO_TEXT_X = 8
    INFO_TEXT_Y = 5
    INFO_TEXT_WIDTH = 110
    POKEMON_GIF_BOTTOM_MARGIN = 10
    LEFT_PANEL = { x: 12, y: 40, width: 132, height: 116 }.freeze
    RIGHT_PANEL = { x: 176, y: 40, width: 132, height: 116 }.freeze

    def initialize
      super(true)
      message_initialize(false, 20000, @viewport)
      @selected_pokemon = nil
      @selected_ball_item = nil
      @focus = :pokemon
      @selected_box_frame = 0
      @selected_box_timer = 0
      @pokemon_gif_reader = nil
      @pokemon_gif_bottom_padding = nil
    end

    def update_inputs
      if Input.trigger?(:B)
        @running = false
      elsif Input.trigger?(:LEFT)
        move_focus_left
      elsif Input.trigger?(:RIGHT)
        move_focus_right
      elsif Input.trigger?(:A)
        handle_action
      elsif Input.trigger?(:X)
        handle_apply
      else
        return true
      end

      true
    end

    def update_graphics
      @base_ui.update_background_animation
      update_pokemon_gif_animation
      update_selected_box_animation
    end

    def update_mouse(moved)
      if moved
        if mouse_over_panel?(LEFT_PANEL)
          set_focus(:pokemon)
        else
          set_focus(:ball) if mouse_over_panel?(RIGHT_PANEL)
        end
      end

      update_mouse_ctrl_buttons(@base_ui.ctrl, MOUSE_ACTIONS) if @base_ui
      return true unless Mouse.trigger?(:LEFT)

      if mouse_over_panel?(LEFT_PANEL)
        set_focus(:pokemon)
        handle_select_pokemon
      elsif mouse_over_panel?(RIGHT_PANEL)
        set_focus(:ball)
        handle_select_ball
      end

      true
    end

    private

    def action_a
      handle_action
    end

    def action_x
      handle_apply
    end

    def action_b
      play_cancel_se if respond_to?(:play_cancel_se)
      @running = false
    end

    def create_graphics
      create_viewport
      create_base_ui
      create_placeholders
    end

    def create_base_ui
      @base_ui = UI::SettingsBase.new(@viewport, button_texts)
      @base_ui.ctrl.last
    end

    def create_placeholders
      create_background_assets
      create_panels
      create_selection_sprites
      create_texts
      update_focus_visuals
    end

    def create_background_assets
      @frame_sprite = Sprite.new(@viewport)
      @frame_sprite.set_bitmap("ball_changer/frame", :interface)
      @frame_sprite.x = 0
      @frame_sprite.y = 0
      @frame_sprite.z = 0
      @money_box_sprite = Sprite.new(@viewport)
      @money_box_sprite.set_bitmap("ball_changer/box_money", :interface)
      @money_box_sprite.x = 0
      @money_box_sprite.y = 0
      @money_box_sprite.z = 1
      @box_left_sprite = Sprite.new(@viewport)
      @box_left_sprite.set_bitmap("ball_changer/box_left", :interface)
      @box_left_sprite.x = 0
      @box_left_sprite.y = 0
      @box_left_sprite.z = 1
      @box_left_selected_sprite = Sprite.new(@viewport)
      @box_left_selected_sprite.set_bitmap("ball_changer/box_left_selected", :interface)
      @box_left_selected_sprite.x = 0
      @box_left_selected_sprite.y = 0
      @box_left_selected_sprite.z = 2
      @box_left_selected_sprite.visible = false
      setup_selected_box_sprite(@box_left_selected_sprite)
      @box_right_sprite = Sprite.new(@viewport)
      @box_right_sprite.set_bitmap("ball_changer/box_right", :interface)
      @box_right_sprite.x = 0
      @box_right_sprite.y = 0
      @box_right_sprite.z = 1
      @box_right_selected_sprite = Sprite.new(@viewport)
      @box_right_selected_sprite.set_bitmap("ball_changer/box_right_selected", :interface)
      @box_right_selected_sprite.x = 0
      @box_right_selected_sprite.y = 0
      @box_right_selected_sprite.z = 2
      @box_right_selected_sprite.visible = false
      setup_selected_box_sprite(@box_right_selected_sprite)
    end

    def create_panels
      @panels = []
    end

    def create_selection_sprites
      @pokemon_sprite = Sprite.new(@viewport)
      @pokemon_sprite.set_position(pokemon_sprite_x, pokemon_sprite_y)
      @pokemon_sprite.z = 6
      @pokemon_sprite.visible = false
      @pokemon_ball_sprite = Sprite.new(@viewport)
      @pokemon_ball_sprite.z = 7
      @pokemon_ball_sprite.visible = false
      @ball_icon_sprite = Sprite.new(@viewport)
      @ball_icon_sprite.z = 6
      @ball_icon_sprite.visible = false
      @gender_sprite = Sprite.new(@viewport)
      @gender_sprite.z = 7
      @gender_sprite.visible = false
      @shiny_sprite = Sprite.new(@viewport)
      @shiny_sprite.z = 7
      @shiny_sprite.visible = false
    end

    def create_texts
      language = Raty.language_symbol_stp
      labels = ui_labels(language)
      @ui_labels = labels
      @texts = UI::SpriteStack.new(@viewport)
      add_flat_text(@texts, HEADER_TEXT_X, HEADER_TEXT_Y, HEADER_TEXT_WIDTH, 16, labels[:pokemon_label], 1, color: 9, sizeid: 0).z = TEXT_Z
      add_flat_text(@texts, HEADER_TEXT_X + BOX_RIGHT_OFFSET_X, HEADER_TEXT_Y, HEADER_TEXT_WIDTH, 16, labels[:ball_label], 1, color: 9, sizeid: 0).z = TEXT_Z
      @pokemon_placeholder_text = add_flat_text(@texts, BOTTOM_TEXT_X, BOTTOM_TEXT_Y, BOTTOM_TEXT_WIDTH, 16, labels[:pokemon_placeholder], 1, color: 10, sizeid: 0)
      @pokemon_placeholder_text.z = TEXT_Z
      @pokemon_value_text = add_flat_text(@texts, BOTTOM_TEXT_X, BOTTOM_TEXT_Y, BOTTOM_TEXT_WIDTH, 16, "", 1, color: 9, sizeid: 0)
      @pokemon_value_text.z = TEXT_Z
      @ball_placeholder_text = add_flat_text(@texts, BOTTOM_TEXT_X + BOX_RIGHT_OFFSET_X, BOTTOM_TEXT_Y, BOTTOM_TEXT_WIDTH, 16, labels[:ball_placeholder], 1, color: 10, sizeid: 0)
      @ball_placeholder_text.z = TEXT_Z
      @ball_value_text = add_flat_text(@texts, BOTTOM_TEXT_X + BOX_RIGHT_OFFSET_X, BOTTOM_TEXT_Y, BOTTOM_TEXT_WIDTH, 16, "", 1, color: 9, sizeid: 0)
      @ball_value_text.z = TEXT_Z
      @money_label_text = add_flat_text(@texts, INFO_TEXT_X, INFO_TEXT_Y, INFO_TEXT_WIDTH, 16, "", 0, color: 9)
      @money_label_text.z = TEXT_Z
      @money_value_text = add_flat_text(@texts, INFO_TEXT_X, INFO_TEXT_Y, INFO_TEXT_WIDTH, 16, "", 2, color: 9)
      @money_value_text.z = TEXT_Z
      @price_label_text = add_flat_text(@texts, INFO_TEXT_X, INFO_TEXT_Y + 12, INFO_TEXT_WIDTH, 16, "", 0, color: 9)
      @price_label_text.z = TEXT_Z
      @price_value_text = add_flat_text(@texts, INFO_TEXT_X, INFO_TEXT_Y + 12, INFO_TEXT_WIDTH, 16, "", 2, color: 9)
      @price_value_text.z = TEXT_Z
      update_selection_texts
      update_price_texts
    end

    def ui_labels(language)
      if language == :en
        { title: "BALL CHANGER", pokemon_label: "Pokemon", ball_label: "Ball", pokemon_placeholder: "No Pokemon", ball_placeholder: "No Ball", price_label: "Price", money_label: "Money" }
      else
        { title: "BALL CHANGER", pokemon_label: "Pokémon", ball_label: "Ball", pokemon_placeholder: "Aucun Pokémon", ball_placeholder: "Aucune Ball", price_label: "Prix", money_label: "Argent" }
      end
    end

    def button_texts
      quit = $options.language == "en" ? "quit" : "quitter"
      language = Raty.language_symbol_stp
      apply_text = language == :en ? "apply" : "appliquer"
      select_text = language == :en ? "select" : "choisir"
      [select_text, apply_text, nil, quit]
    end

    def handle_select_pokemon
      return unless BallChanger.choose_creature
      @selected_pokemon = BallChanger.selected_pokemon
      update_selection_texts
    end

    def handle_select_ball
      return unless BallChanger.choose_ball
      @selected_ball_item = BallChanger.selected_ball_item
      update_selection_texts
    end

    def update_selection_texts
      if @selected_pokemon
        @pokemon_placeholder_text.visible = false
        @pokemon_value_text.visible = true
        @pokemon_value_text.text = @selected_pokemon.given_name
      else
        @pokemon_value_text.visible = false
        @pokemon_placeholder_text.visible = true
      end

      if @selected_ball_item
        @ball_placeholder_text.visible = false
        @ball_value_text.visible = true
        @ball_value_text.text = @selected_ball_item.exact_name
      else
        @ball_value_text.visible = false
        @ball_placeholder_text.visible = true
      end

      update_selection_sprites
    end

    def update_price_texts
      unless @price_label_text && @price_value_text && @money_label_text && @money_value_text
        return
      end

      labels = @ui_labels || ui_labels(Raty.language_symbol_stp)
      @money_label_text.text = "#{labels[:money_label]} :"
      @money_value_text.text = "#{format_money_value(PFM.game_state.money)}$"
      @price_label_text.text = "#{labels[:price_label]} :"
      @price_value_text.text = "#{format_money_value(BallChanger::PRICE)}$"
    end

    def format_money_value(amount)
      amount.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
    end

    def update_focus_visuals
      @box_left_selected_sprite.visible = @focus == :pokemon if @box_left_selected_sprite
      @box_right_selected_sprite.visible = @focus == :ball if @box_right_selected_sprite
    end

    def setup_selected_box_sprite(sprite)
      return unless sprite&.bitmap
      frame_height = sprite.bitmap.height / 2
      sprite.src_rect.set(0, 0, sprite.bitmap.width, frame_height)
    end

    def update_selected_box_animation
      return unless @box_left_selected_sprite && @box_right_selected_sprite
      @selected_box_timer += 1
      return if @selected_box_timer < SELECTED_BOX_ANIM_INTERVAL
      @selected_box_timer = 0
      @selected_box_frame = (@selected_box_frame + 1) % 2
      update_selected_box_frame(@box_left_selected_sprite)
      update_selected_box_frame(@box_right_selected_sprite)
    end

    def update_selected_box_frame(sprite)
      return unless sprite&.bitmap
      frame_height = sprite.bitmap.height / 2
      sprite.src_rect.set(0, frame_height * @selected_box_frame, sprite.bitmap.width, frame_height)
    end

    def update_selection_sprites
      update_pokemon_sprite if @pokemon_sprite

      if @selected_pokemon
        pokemon_ball_item = data_item(@selected_pokemon.captured_with)
        update_ball_icon(@pokemon_ball_sprite, pokemon_ball_item&.icon, pokemon_ball_x, pokemon_ball_y)
      else
        update_ball_icon(@pokemon_ball_sprite, nil, pokemon_ball_x, pokemon_ball_y)
      end

      update_ball_icon(@ball_icon_sprite, @selected_ball_item&.icon, ball_icon_x, ball_icon_y, center: true, zoom: 1.0)
      update_gender_and_shiny
    end

    def move_focus_left
      if @focus == :ball
        play_cursor_se
        set_focus(:pokemon)
      else
        play_buzzer_se
      end
    end

    def move_focus_right
      if @focus == :pokemon
        play_cursor_se
        set_focus(:ball)
      else
        play_buzzer_se
      end
    end

    def handle_action
      case @focus
      when :pokemon then return handle_select_pokemon
      when :ball then handle_select_ball
      else
        return play_buzzer_se
      end
    end

    def handle_apply
      status = apply_status
      if status != :ok
        play_buzzer_se
        $scene.display_message(apply_message(status))
        nil
      elsif BallChanger.apply_selected_ball
        play_decision_se
        update_selection_sprites
        update_price_texts
        $scene.display_message(apply_message(:success))
      else
        play_buzzer_se
        $scene.display_message(apply_message(:failed))
      end
    end

    def can_apply?
      apply_status == :ok
    end

    def apply_status
      return :missing_both if @selected_pokemon.nil? && @selected_ball_item.nil?
      return :missing_pokemon if @selected_pokemon.nil?
      return :missing_ball if @selected_ball_item.nil?
      return :no_money unless BallChanger.money_check
      return :same_ball if @selected_pokemon.captured_with == @selected_ball_item.id
      :ok
    end

    def apply_message(status)
      language = Raty.language_symbol_stp
      if language == :en
        return "Done! The Pokemon's ball has been updated." if status == :success
        if status == :same_ball
          return "No change: a similar type of ball is already used by this Pokemon."
        end
        return "Choose a Pokemon first." if status == :missing_pokemon
        return "Choose a ball first." if status == :missing_ball
        return "Choose a Pokemon and a ball first." if status == :missing_both
        return "Not enough money to apply the change." if status == :no_money
        "Something went wrong. Please try again."
      else
        return "C'est fait ! La ball du Pokémon a été mise à jour." if status == :success
        if status == :same_ball
          return "Aucun changement : ce type de ball est déjà utilisé par ce Pokémon."
        end
        return "Choisis d'abord un Pokémon." if status == :missing_pokemon
        return "Choisis d'abord une ball." if status == :missing_ball
        return "Choisis d'abord un Pokémon et une ball." if status == :missing_both
        return "Pas assez d'argent pour appliquer le changement." if status == :no_money
        "Une erreur est survenue. Réessaie."
      end
    end

    def set_focus(value)
      return if @focus == value
      @focus = value
      update_focus_visuals
    end

    def update_gender_and_shiny
      if @selected_pokemon && !@selected_pokemon.egg?
        if @selected_pokemon.gender != 0
          filename = @selected_pokemon.gender == 2 ? "ball_changer/girl" : "ball_changer/boy"
          @gender_sprite.set_bitmap(filename, :interface)
          @gender_sprite.set_position(GENDER_ICON_X, GENDER_ICON_Y)
          @gender_sprite.visible = true
        else
          @gender_sprite.visible = false
        end
        if @selected_pokemon.shiny
          @shiny_sprite.set_bitmap("ball_changer/shiny", :interface)
          @shiny_sprite.zoom = 0.05
          @shiny_sprite.set_position(SHINY_ICON_X, SHINY_ICON_Y)
          return @shiny_sprite.visible = true
        end
        @shiny_sprite.visible = false
      else
        @gender_sprite.visible = false
        @shiny_sprite.visible = false
      end
    end

    def update_pokemon_sprite
      if @selected_pokemon
        gif_reader = @selected_pokemon.gif_face
        if gif_reader
          if @pokemon_gif_reader != gif_reader
            @pokemon_sprite.bitmap&.dispose if @pokemon_gif_reader
            @pokemon_gif_reader = gif_reader
            @pokemon_sprite.bitmap = Texture.new(gif_reader.width, gif_reader.height)
            @pokemon_gif_bottom_padding = nil
          end
          @pokemon_gif_reader.update(@pokemon_sprite.bitmap)
          @pokemon_gif_bottom_padding ||= compute_bottom_transparent_padding(@pokemon_sprite.bitmap)
          apply_gif_pokemon_position(@pokemon_gif_bottom_padding)
        else
          @pokemon_sprite.bitmap&.dispose if @pokemon_gif_reader
          @pokemon_gif_reader = nil
          @pokemon_gif_bottom_padding = nil
          filename = PFM::Pokemon.front_filename(@selected_pokemon.id, @selected_pokemon.form, @selected_pokemon.female?, @selected_pokemon.shiny?, false)
          @pokemon_sprite.set_bitmap(RPG::Cache.poke_front(filename, @selected_pokemon.shiny? ? 1 : 0), :battler)
          @pokemon_sprite.ox = 0
          @pokemon_sprite.oy = 0
          @pokemon_sprite.x = pokemon_sprite_x
          @pokemon_sprite.y = pokemon_sprite_y
        end
        @pokemon_sprite.visible = true
      else
        @pokemon_sprite.bitmap&.dispose if @pokemon_gif_reader
        @pokemon_gif_reader = nil
        @pokemon_gif_bottom_padding = nil
        @pokemon_sprite.visible = false
      end
    end

    def update_pokemon_gif_animation
      return unless @pokemon_gif_reader && @pokemon_sprite&.bitmap

      @pokemon_gif_reader.update(@pokemon_sprite.bitmap)
    end

    def compute_bottom_transparent_padding(bitmap)
      begin
        return 0 unless bitmap
        png_data = bitmap.to_png
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
    end

    def apply_gif_pokemon_position(bottom_padding)
      return unless @pokemon_sprite&.bitmap
      bottom_padding ||= 0
      @pokemon_sprite.ox = @pokemon_sprite.bitmap.width / 2
      @pokemon_sprite.oy = 0
      @pokemon_sprite.x = pokemon_gif_center_x
      @pokemon_sprite.y = pokemon_gif_bottom_y - (@pokemon_sprite.bitmap.height - bottom_padding)
    end

    def update_ball_icon(sprite, icon, x, y, center: false, zoom: 0.5)
      return unless sprite

      if icon
        sprite.set_bitmap(icon, :icon)
        sprite.x = x
        sprite.y = y
        if center
          sprite.ox = sprite.bitmap.width / 2
          sprite.oy = sprite.bitmap.height / 2
        else
          sprite.ox = 0
          sprite.oy = 0
        end
        sprite.zoom = zoom
        sprite.visible = true
      else
        sprite.visible = false
      end
    end

    def pokemon_sprite_x
      BOX_POKEMON_X
    end

    def pokemon_sprite_y
      BOX_POKEMON_Y
    end

    def pokemon_gif_center_x
      LEFT_WHITE_X + LEFT_WHITE_WIDTH / 2 + 1
    end

    def pokemon_gif_bottom_y
      LEFT_WHITE_Y + LEFT_WHITE_HEIGHT - POKEMON_GIF_BOTTOM_MARGIN
    end

    def pokemon_ball_x
      BOX_BALL_X
    end

    def pokemon_ball_y
      BOX_BALL_Y
    end

    def ball_icon_x
      RIGHT_WHITE_X + RIGHT_WHITE_WIDTH / 2 + 1
    end

    def ball_icon_y
      RIGHT_WHITE_Y + RIGHT_WHITE_HEIGHT / 2 + 1
    end

    def add_flat_text(stack, *args, **kwargs)
      text = stack.add_text(*args, **kwargs)
      text.draw_shadow = false
      text
    end

    def mouse_over_panel?(panel)
      Mouse.x.between?(panel[:x], panel[:x] + panel[:width]) && Mouse.y.between?(panel[:y], panel[:y] + panel[:height])
    end
  end
end

GamePlay.ball_changer_ui_class = GamePlay::BallChangerUI
