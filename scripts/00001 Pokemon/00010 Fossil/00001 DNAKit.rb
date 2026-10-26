# Script décompilé depuis le bytecode du jeu (Ruby 3.0) — fichier d'origine : RMXP/200 DNAKit.rb
# Les commentaires et la mise en forme d'origine ne sont pas récupérables.

module GamePlay
  class << self
    attr_accessor(:dnakit_interface_class)

    def open_dnakit_interface(mode = nil, &block)
      current_scene.call_scene(dnakit_interface_class || DNAKitInterface, mode, &block)
    end
  end

  class DNAKitInterface < BaseCleanUpdate::FrameBalanced
    MOUSE_ACTIONS = [:action_a, nil, nil, :action_b].freeze
    SELECTION_MOUSE_ACTIONS = [:action_a, nil, nil, :action_b].freeze
    ASSET_FOLDER = "9 dnakit"
    BACKGROUND_ASSET = "#{ASSET_FOLDER}/background"
    KIT_ASSET = "#{ASSET_FOLDER}/kit"
    SCREEN_ASSET = "#{ASSET_FOLDER}/screen"
    SELECTOR_ASSET = "#{ASSET_FOLDER}/selector"
    ADN_ASSET = "#{ASSET_FOLDER}/adn_animated"
    KIT_POSITION = [0, 0].freeze
    GRID_ORIGIN = [60, 122].freeze
    GRID_COLUMNS = 8
    GRID_ROWS = 2
    GRID_SLOT_WIDTH = 24
    GRID_SLOT_HEIGHT = 24
    MAX_VISIBLE_ITEMS = GRID_COLUMNS * GRID_ROWS
    DNA_SEQUENCE_SOCKET = 9
    SELECTED_ICON_Y_OFFSET = -2
    SELECTOR_FRAME_COUNT = 4
    SELECTOR_FRAME_DURATION = 0.4
    SELECTOR_X_OFFSET = 4
    SELECTOR_Y_OFFSET = 3
    SELECTOR_BOTTOM_ROW_Y_OFFSET = 4
    ICON_BOTTOM_ROW_Y_OFFSET = 4
    CHOICE_OVERLAY_ASSET = "#{ASSET_FOLDER}/choice"
    BACKGROUND_Z = 0
    KIT_Z = 1
    ICON_Z = 2
    SELECTOR_Z = 3
    OVERLAY_Z = 30
    OVERLAY_TEXT_Z = 31
    SELECTED_ITEM_NAME_Z = 100
    SELECTED_ITEM_NAME_Y = -123
    CHOICE_TEXT_Y = 68
    CHOICE_TEXT_HEIGHT = 16
    SCREEN_HOLOGRAM_SHADER_ENABLED = true
    SCREEN_HOLOGRAM_SHADER_NAME = :raty_dnakit_screen_hologram
    SCREEN_HOLOGRAM_OPACITY = 30
    SCREEN_HOLOGRAM_TIME_SCALE = 1.0 / 5
    SCREEN_HOLOGRAM_COLOR = [0.35, 0.95, 1.0, 1.0].freeze
    SCREEN_HOLOGRAM_SCAN_INTENSITY = 0.16
    SCREEN_HOLOGRAM_GLITCH_INTENSITY = 0.0
    SCREEN_HOLOGRAM_FLICKER_STRENGTH = 0.1
    SCREEN_HOLOGRAM_COLOR_MIX = 1.0
    SCREEN_HOLOGRAM_SWEEP_STRENGTH = 0.22
    SCREEN_HOLOGRAM_SCAN_FREQUENCY = 18.0
    SCREEN_HOLOGRAM_GLITCH_FREQUENCY = 18.0
    SCREEN_HOLOGRAM_FLICKER_FREQUENCY = 35.0
    SCREEN_HOLOGRAM_SWEEP_FREQUENCY = 0.18
    SCREEN_HOLOGRAM_FRAGMENT_SHADER = "uniform sampler2D texture;\nuniform float time;\nuniform vec4 holo_color;\nuniform float scan_intensity;\nuniform float glitch_intensity;\nuniform float flicker_strength;\nuniform float color_mix;\nuniform float sweep_strength;\nuniform float scan_frequency;\nuniform float glitch_frequency;\nuniform float flicker_frequency;\nuniform float sweep_frequency;\n\nfloat random_value(vec2 seed) {\n  return fract(sin(dot(seed, vec2(12.9898, 78.233))) * 43758.5453);\n}\n\nvoid main() {\n  vec2 uv = gl_TexCoord[0].xy;\n  vec4 base_frag = texture2D(texture, uv);\n  vec4 frag = texture2D(texture, uv);\n\n  if (base_frag.a <= 0.001) {\n    frag = vec4(0.0);\n  } else {\n    float time_step = floor(time * glitch_frequency);\n    float glitch_band = step(0.82, random_value(vec2(floor(uv.y * 96.0), time_step)));\n    float x_jitter = (random_value(vec2(time_step, floor(uv.y * 160.0))) - 0.5) * glitch_intensity * glitch_band;\n    vec2 sample_uv = clamp(vec2(uv.x + x_jitter, uv.y), vec2(0.0, 0.0), vec2(1.0, 1.0));\n\n    frag = texture2D(texture, sample_uv);\n    float luma = dot(frag.rgb, vec3(0.299, 0.587, 0.114));\n    float scan = 0.5 + 0.5 * sin((uv.y * 220.0) - (time * scan_frequency));\n    float flicker = 1.0 - flicker_strength + flicker_strength * (0.5 + 0.5 * sin(time * flicker_frequency));\n    float sweep_center = fract(time * sweep_frequency);\n    float sweep = 1.0 - smoothstep(0.0, 0.18, abs(uv.y - sweep_center));\n\n    vec3 hologram = mix(frag.rgb, holo_color.rgb * (0.45 + luma * 1.15), color_mix);\n    hologram += holo_color.rgb * scan * scan_intensity;\n    hologram += holo_color.rgb * sweep * sweep_strength;\n\n    frag.rgb = hologram * flicker;\n    frag.a = min(frag.a, base_frag.a) * (0.92 + (scan * 0.08));\n  }\n  gl_FragColor = frag;\n}\n"

    attr_reader(:return_data)

    def initialize(mode = nil)
      super()
      @mode = mode
      @selected_slot_index = nil
      @return_data = nil
      @choice_overlay_state = nil
    end

    def update_inputs
      if choice_overlay_active?
        if Input.trigger?(:B)
          action_b
        else
          action_a if Input.trigger?(:A)
        end
        true
      else
        if Input.trigger?(:B)
          action_b
        elsif Input.trigger?(:A)
          action_a
        elsif Input.trigger?(:LEFT)
          move_selection(:left)
        elsif Input.trigger?(:RIGHT)
          move_selection(:right)
        elsif Input.trigger?(:UP)
          move_selection(:up)
        else
          move_selection(:down) if Input.trigger?(:DOWN)
        end
        true
      end
    end

    def update_mouse(moved)
      update_mouse_ctrl_buttons(@base_ui.ctrl, mouse_actions) if @base_ui
      return true if choice_overlay_active?
      update_mouse_slot_selection if moved
      if Mouse.trigger?(:LEFT) && hovered_slot_index
        set_selected_slot(hovered_slot_index, play_sound: false)
        action_a
      end

      true
    end

    def update_graphics
      @base_ui&.update_background_animation
      @selector_animation&.update
      @adn_animation&.update
      update_screen_hologram_shader
      true
    end

    private

    def create_graphics
      create_viewport
      create_base_ui
      create_background
      create_kit
      create_slot_icons
      create_selector
      create_adn_animation
      create_choice_overlay
      create_texts
      refresh_selection_visuals
      refresh_choice_overlay
    end

    def create_viewport
      @viewport = Viewport.create(:main, 10000)
    end

    def create_base_ui
      @base_ui = UI::SettingsBase.new(@viewport, button_texts)
    end

    def create_background
      @background = create_interface_sprite(0, 0, BACKGROUND_ASSET, BACKGROUND_Z)
    end

    def create_kit
      @kit = create_interface_sprite(*KIT_POSITION, KIT_ASSET, KIT_Z)
      create_screen
    end

    def create_screen
      @screen = create_interface_sprite(*KIT_POSITION, SCREEN_ASSET, KIT_Z)
      apply_screen_hologram_shader
    end

    def create_slot_icons
      @slot_icons = {}
      @slot_item_ids = dna_sequence_item_ids.first(MAX_VISIBLE_ITEMS)
      @disabled_slot_indexes = disabled_slot_indexes_from_selected_sequences

      @slot_item_ids.each_with_index do |item_id, slot_index|
        sprite = create_item_icon_sprite(*slot_position(slot_index), data_item(item_id), ICON_Z)
        apply_disabled_visual_to_slot_icon(sprite) if disabled_slot?(slot_index)
        @slot_icons[slot_index] = sprite
      end

      @selected_slot_index = first_selectable_slot_index
    end

    def create_interface_sprite(x, y, asset, z)
      Sprite.new(@viewport).set_bitmap(asset, :interface).set_position(x, y).set_z(z)
    end

    def create_item_icon_sprite(x, y, item, z)
      Sprite.new(@viewport).set_bitmap(item.icon, :icon).set_position(x, y).set_z(z)
    end

    def apply_screen_hologram_shader
      @screen.opacity = SCREEN_HOLOGRAM_OPACITY
      return unless SCREEN_HOLOGRAM_SHADER_ENABLED
      ensure_screen_hologram_shader_registered
      @screen.shader = Shader.create(SCREEN_HOLOGRAM_SHADER_NAME)
      update_screen_hologram_shader
    end

    def update_screen_hologram_shader
      return unless SCREEN_HOLOGRAM_SHADER_ENABLED && @screen&.shader
      @screen.opacity = SCREEN_HOLOGRAM_OPACITY
      @screen.shader.set_float_uniform("time", Graphics.frame_count.to_f / Graphics.frame_rate * SCREEN_HOLOGRAM_TIME_SCALE)
      @screen.shader.set_float_uniform("holo_color", SCREEN_HOLOGRAM_COLOR)
      @screen.shader.set_float_uniform("scan_intensity", SCREEN_HOLOGRAM_SCAN_INTENSITY)
      @screen.shader.set_float_uniform("glitch_intensity", SCREEN_HOLOGRAM_GLITCH_INTENSITY)
      @screen.shader.set_float_uniform("flicker_strength", SCREEN_HOLOGRAM_FLICKER_STRENGTH)
      @screen.shader.set_float_uniform("color_mix", SCREEN_HOLOGRAM_COLOR_MIX)
      @screen.shader.set_float_uniform("sweep_strength", SCREEN_HOLOGRAM_SWEEP_STRENGTH)
      @screen.shader.set_float_uniform("scan_frequency", SCREEN_HOLOGRAM_SCAN_FREQUENCY)
      @screen.shader.set_float_uniform("glitch_frequency", SCREEN_HOLOGRAM_GLITCH_FREQUENCY)
      @screen.shader.set_float_uniform("flicker_frequency", SCREEN_HOLOGRAM_FLICKER_FREQUENCY)
      @screen.shader.set_float_uniform("sweep_frequency", SCREEN_HOLOGRAM_SWEEP_FREQUENCY)
      @screen.shader.set_float_uniform("tone", @screen.tone) if @screen.respond_to?(:tone)
    end

    def ensure_screen_hologram_shader_registered
      return if self.class().instance_variable_get(:@screen_hologram_shader_registered)
      Shader.register(SCREEN_HOLOGRAM_SHADER_NAME, SCREEN_HOLOGRAM_FRAGMENT_SHADER, tone_process: true, alpha_process: true)

      self.class().instance_variable_set(:@screen_hologram_shader_registered, true)
    end

    def create_selector
      @selector = SpriteSheet.new(@viewport, SELECTOR_FRAME_COUNT, 1)
      @selector.set_bitmap(SELECTOR_ASSET, :interface)
      @selector.z = SELECTOR_Z
      start_selector_animation
    end

    def create_texts
      @texts = UI::SpriteStack.new(@viewport)
      @selected_item_name = add_flat_text(0, SELECTED_ITEM_NAME_Y, 320, 320, "TEST", 1, Color.new(255, 255, 255), z: SELECTED_ITEM_NAME_Z)
      @choice_overlay_text = add_flat_text(0, CHOICE_TEXT_Y, Graphics.width, CHOICE_TEXT_HEIGHT, "", 1, Color.new(255, 255, 255), z: OVERLAY_TEXT_Z)

      refresh_texts
    end

    def refresh_texts
      return unless @selected_item_name
      item = selected_item
      @selected_item_name.text = item ? item.name : ""
      @selected_item_name.visible = true
    end

    def add_flat_text(x, y, width, height, text, align, fill_color, sizeid: 0, z: 3)
      text_sprite = @texts.add_text(x, y, width, height, text, align, color: 9, sizeid: sizeid)
      text_sprite.z = z
      text_sprite.fill_color = fill_color
      text_sprite.outline_color = Color.new(0, 0, 0, 0)
      text_sprite.outline_thickness = 0
      text_sprite.draw_shadow = false
      text_sprite
    end

    def start_selector_animation
      ya = Yuki::Animation
      sequence = []
      SELECTOR_FRAME_COUNT.times do |frame_index|
        sequence << ya.send_command_to(@selector, :sx=, frame_index)
        sequence << ya.wait(SELECTOR_FRAME_DURATION)
      end

      @selector_animation = ya.timed_loop_animation(SELECTOR_FRAME_DURATION * SELECTOR_FRAME_COUNT, sequence, []).start
    end

    def create_adn_animation
      frame_count = 62
      frame_duration = 0.01
      @adn_animated_left = SpriteSheet.new(@viewport, frame_count, 1)
      @adn_animated_left.set_bitmap(ADN_ASSET, :interface)
      @adn_animated_left.z = ICON_Z
      @adn_animated_left.x = 71
      @adn_animated_left.y = 27
      @adn_animated_right = SpriteSheet.new(@viewport, frame_count, 1)
      @adn_animated_right.set_bitmap(ADN_ASSET, :interface)
      @adn_animated_right.z = ICON_Z
      @adn_animated_right.x = 230
      @adn_animated_right.y = 27
      ya = Yuki::Animation
      sequence = []
      frame_count.times do |frame_index|
        sequence << ya.send_command_to(@adn_animated_left, :sx=, frame_index)
        sequence << ya.send_command_to(@adn_animated_right, :sx=, frame_index)

        sequence << ya.wait(frame_duration)
      end

      @adn_animation = ya.timed_loop_animation(frame_duration * frame_count, sequence, []).start
    end

    def create_choice_overlay
      @choice_overlay = Sprite.new(@viewport)
      @choice_overlay.bitmap = RPG::Cache.interface(CHOICE_OVERLAY_ASSET)
      @choice_overlay.x = 0
      @choice_overlay.y = 0
      @choice_overlay.z = OVERLAY_Z
      @choice_overlay.visible = false
    end

    def move_selection(direction)
      target_index = slot_index_in_direction(direction)
      return play_buzzer_se unless target_index

      set_selected_slot(target_index)
    end

    def slot_index_in_direction(direction)
      return unless @selected_slot_index
      target_index = @selected_slot_index

      loop do
        return unless slot_can_move_in_direction?(target_index, direction)
        target_index += slot_direction_delta(direction)
        return target_index if selectable_slot?(target_index)
      end
    end

    def slot_can_move_in_direction?(index, direction)
      column = index % GRID_COLUMNS
      row = index / GRID_COLUMNS
      case direction
      when :left then return !column.zero?
      when :right then return column < GRID_COLUMNS - 1
      when :up then return !row.zero?
      when :down then row < GRID_ROWS - 1
      else
        return false
      end
    end

    def slot_direction_delta(direction)
      case direction
      when :left then return -1
      when :right then return 1
      when :up then return -GRID_COLUMNS
      when :down then GRID_COLUMNS
      else
        return 0
      end
    end

    def update_mouse_slot_selection
      hovered_index = hovered_slot_index
      return set_selected_slot(hovered_index, play_sound: false) if hovered_index
    end

    def hovered_slot_index(mouse_x = Mouse.x, mouse_y = Mouse.y)
      return unless mouse_x.between?(GRID_ORIGIN[0], grid_right - 1)
      return unless mouse_y.between?(GRID_ORIGIN[1], grid_bottom - 1)
      column = (mouse_x - GRID_ORIGIN[0]) / GRID_SLOT_WIDTH
      row = (mouse_y - GRID_ORIGIN[1]) / GRID_SLOT_HEIGHT
      slot_index = row * GRID_COLUMNS + column
      return slot_index if selectable_slot?(slot_index)
    end

    def set_selected_slot(index, play_sound: true)
      return unless selectable_slot?(index)
      return if @selected_slot_index == index
      @selected_slot_index = index
      play_cursor_se if play_sound
      refresh_selection_visuals
    end

    def refresh_selection_visuals
      refresh_selector_position
      refresh_slot_icon_positions
      refresh_texts
    end

    def refresh_selector_position
      return unless @selector
      unless @selected_slot_index
        @selector.visible = false
        return
      end

      x, y = slot_position(@selected_slot_index)
      y += SELECTOR_BOTTOM_ROW_Y_OFFSET if selected_slot_row == 1
      @selector.set_position(x + SELECTOR_X_OFFSET, y + SELECTOR_Y_OFFSET)
      @selector.visible = true
    end

    def refresh_slot_icon_positions
      @slot_icons&.each do |slot_index, sprite|
        x, y = slot_position(slot_index)
        y += ICON_BOTTOM_ROW_Y_OFFSET if slot_index / GRID_COLUMNS == 1
        y += SELECTED_ICON_Y_OFFSET if slot_index == @selected_slot_index
        sprite.set_position(x, y)
      end
    end

    def slot_position(index)
      [GRID_ORIGIN[0] + index % GRID_COLUMNS * GRID_SLOT_WIDTH, GRID_ORIGIN[1] + index / GRID_COLUMNS * GRID_SLOT_HEIGHT]
    end

    def selected_slot_column
      @selected_slot_index % GRID_COLUMNS
    end

    def selected_slot_row
      @selected_slot_index / GRID_COLUMNS
    end

    def grid_right
      GRID_ORIGIN[0] + GRID_COLUMNS * GRID_SLOT_WIDTH
    end

    def grid_bottom
      GRID_ORIGIN[1] + GRID_ROWS * GRID_SLOT_HEIGHT
    end

    def dna_sequence_item_ids
      socket = dna_sequence_socket

      $bag.get_order(socket).flat_map do |item_id|
        next [] unless item_id && item_id != 0
        item = data_item(item_id)
        next [] unless item.socket == socket

        Array.new($bag.item_quantity(item.db_symbol), item.db_symbol)
      end
    end

    def dna_sequence_socket
      if defined?(GamePlay::Bag::DNA_SEQUENCE_SOCKET)
        GamePlay::Bag::DNA_SEQUENCE_SOCKET
      else
        DNA_SEQUENCE_SOCKET
      end
    end

    def disabled_slot_indexes_from_selected_sequences
      return [] unless selection_mode?
      remaining_counts = selected_sequences_dnakit_counts
      disabled_indexes = exact_disabled_slot_indexes_from_selected_sequences(remaining_counts)

      disabled_indexes_from_remaining_sequence_counts(remaining_counts, disabled_indexes)
    end

    def exact_disabled_slot_indexes_from_selected_sequences(remaining_counts)
      slot_map = selected_sequences_dnakit_slot_indexes
      disabled_indexes = []

      slot_map.each do |slot_index, expected_symbol|
        slot_index = slot_index.to_i
        item_id = @slot_item_ids[slot_index]
        next unless item_id
        item_symbol = normalize_dna_sequence_symbol(item_id)
        expected_symbol = normalize_dna_sequence_symbol(expected_symbol)
        next unless item_symbol && expected_symbol
        next unless item_symbol == expected_symbol
        next unless remaining_counts[item_symbol].to_i.positive?
        disabled_indexes << slot_index
        remaining_counts[item_symbol] -= 1
      end

      disabled_indexes
    end

    def disabled_indexes_from_remaining_sequence_counts(remaining_counts, disabled_indexes)
      @slot_item_ids.each_with_index do |item_id, slot_index|
        next if disabled_indexes.include?(slot_index)
        symbol = normalize_dna_sequence_symbol(item_id)
        next unless symbol
        next unless remaining_counts[symbol].to_i.positive?
        disabled_indexes << slot_index
        remaining_counts[symbol] -= 1
      end

      disabled_indexes
    end

    def selected_sequences_dnakit_counts
      return {} unless PFM.game_state.respond_to?(:selected_sequences_dnakit)
      counts = PFM.game_state.selected_sequences_dnakit || {}

      counts.each_with_object({}) do |(symbol, count), result|
        symbol = normalize_dna_sequence_symbol(symbol)
        next unless symbol
        next unless count.to_i.positive?

        result[symbol] = count.to_i
      end
    end

    def normalize_dna_sequence_symbol(value)
      begin
        return if value.nil?
        return data_item(value).db_symbol if value.is_a?(Integer)
        return value.db_symbol if value.respond_to?(:db_symbol)
        return value.to_sym if value.respond_to?(:to_sym)
        value
      rescue StandardError
        value.to_sym if value.respond_to?(:to_sym)
        value
      end
    end

    def disabled_slot?(index)
      @disabled_slot_indexes&.include?(index)
    end

    def first_selectable_slot_index
      @slot_icons.keys.sort.find { |slot_index| selectable_slot?(slot_index) }
    end

    def selected_sequences_dnakit_slot_indexes
      return {} unless PFM.game_state.respond_to?(:selected_sequences_dnakit_slot_indexes)
      slot_map = PFM.game_state.selected_sequences_dnakit_slot_indexes || {}
      return {} unless slot_map.is_a?(Hash)

      slot_map.each_with_object({}) do |(slot_index, symbol), result|
        next if slot_index.nil? || symbol.nil?

        result[slot_index.to_i] = normalize_dna_sequence_symbol(symbol)
      end
    end

    def selectable_slot?(index)
      !index.nil? && @slot_icons&.key?(index) && !disabled_slot?(index)
    end

    def button_texts
      if selection_mode?
        [choose_label, nil, nil, leave_label]
      elsif discard_confirmation_active?
        [confirm_label, nil, nil, cancel_label]
      elsif discard_choice_active?
        [discard_label, nil, nil, cancel_label]
      else
        [select_label, nil, nil, leave_label]
      end
    end

    def mouse_actions
      return SELECTION_MOUSE_ACTIONS if selection_mode? || choice_overlay_active?

      MOUSE_ACTIONS
    end

    def selection_mode?
      @mode == :selection
    end

    def choice_overlay_active?
      discard_choice_active? || discard_confirmation_active?
    end

    def discard_choice_active?
      @choice_overlay_state == :action
    end

    def discard_confirmation_active?
      @choice_overlay_state == :confirm
    end

    def action_a
      return play_buzzer_se unless selected_item_id
      return play_buzzer_se if disabled_slot?(@selected_slot_index)

      if selection_mode?
        play_decision_se
        @return_data = { item_id: selected_item_id, slot_index: @selected_slot_index }
        @running = false
      else
        return confirm_discard_selected_item if discard_confirmation_active?
        if discard_choice_active?
          play_decision_se
          return open_discard_confirmation
        end
        play_decision_se
        open_discard_choice
      end
    end

    def selected_item_id
      return unless @selected_slot_index

      @slot_item_ids[@selected_slot_index]
    end

    def selected_item
      item_id = selected_item_id
      return unless item_id

      data_item(item_id)
    end

    def action_b
      if choice_overlay_active?
        play_cancel_se
        close_choice_overlay
        nil
      else
        play_cancel_se
        @running = false
      end
    end

    def open_discard_choice
      @choice_overlay_state = :action
      refresh_choice_overlay
    end

    def open_discard_confirmation
      @choice_overlay_state = :confirm
      refresh_choice_overlay
    end

    def close_choice_overlay
      @choice_overlay_state = nil
      refresh_choice_overlay
    end

    def refresh_choice_overlay
      @choice_overlay.visible = choice_overlay_active? if @choice_overlay
      refresh_choice_overlay_text
      refresh_texts
      @base_ui.button_texts = button_texts if @base_ui
    end

    def refresh_choice_overlay_text
      return unless @choice_overlay_text

      unless choice_overlay_active?
        @choice_overlay_text.visible = false
        @choice_overlay_text.text = ""
        return
      end

      @choice_overlay_text.text = choice_overlay_text
      @choice_overlay_text.visible = true
    end

    def choice_overlay_text
      return discard_confirmation_text if discard_confirmation_active?

      action_choice_text
    end

    def selected_item_name_for_choice
      selected_item&.exact_name || selected_item&.name || ""
    end

    def action_choice_text
      return "What do you want to do?" if language == :en
      "Quelle action faire ?"
    end

    def discard_confirmation_text
      if language == :en
        "Discard #{selected_item_name_for_choice}?"
      else
        "Jeter #{selected_item_name_for_choice} ?"
      end
    end

    def choose_label
      return "choose" if language == :en
      "choisir"
    end

    def confirm_label
      return "confirm" if language == :en
      "confirmer"
    end

    def discard_label
      return "discard" if language == :en
      "jeter"
    end

    def select_label
      return "select" if language == :en
      "choisir"
    end

    def cancel_label
      return "cancel" if language == :en
      "annuler"
    end

    def leave_label
      quit = $options.language == "en" ? "quit" : "quitter"
      quit
    end

    def language
      return :en if $options.language == "en"
      :fr
    end

    def confirm_discard_selected_item
      item_id = selected_item_id
      return play_buzzer_se unless item_id
      $bag.remove_item(item_id, 1)
      play_decision_se
      close_choice_overlay
      reload_slot_icons(@selected_slot_index)
    end

    def reload_slot_icons(preferred_index = nil)
      dispose_slot_icons
      @slot_icons = {}
      @slot_item_ids = dna_sequence_item_ids.first(MAX_VISIBLE_ITEMS)
      @disabled_slot_indexes = disabled_slot_indexes_from_selected_sequences
      @slot_item_ids.each_with_index do |item_id, slot_index|
        sprite = create_item_icon_sprite(*slot_position(slot_index), data_item(item_id), ICON_Z)
        apply_disabled_visual_to_slot_icon(sprite) if disabled_slot?(slot_index)
        @slot_icons[slot_index] = sprite
      end

      @selected_slot_index = next_selectable_slot_index(preferred_index)
      refresh_selection_visuals
    end

    def dispose_slot_icons
      @slot_icons&.each_value do |sprite|
        next sprite.dispose if sprite && (!sprite.respond_to?(:disposed?) || !sprite.disposed?)
      end
    end

    def next_selectable_slot_index(preferred_index)
      selectable_indexes = @slot_icons.keys.sort.select { |slot_index| selectable_slot?(slot_index) }
      return if selectable_indexes.empty?
      return selectable_indexes.first unless preferred_index
      return preferred_index if selectable_indexes.include?(preferred_index)

      selectable_indexes.find { |slot_index| preferred_index && slot_index > preferred_index } || selectable_indexes.last
    end

    def apply_disabled_visual_to_slot_icon(sprite)
      if sprite.respond_to?(:opacity=)
        sprite.opacity = 128
      end

      if sprite.respond_to?(:tone=)
        sprite.tone = Tone.new(-80, -80, -80, 255)
      end
    end
  end
end

GamePlay.dnakit_interface_class = GamePlay::DNAKitInterface

def open_dnakit_interface(mode = nil)
  GamePlay.open_dnakit_interface(mode)
end

def dnakit_interface(mode = nil)
  GamePlay.open_dnakit_interface(mode)
end
