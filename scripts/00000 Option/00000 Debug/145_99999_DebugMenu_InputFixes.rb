# Script décompilé depuis le bytecode du jeu (Ruby 3.0) — fichier d'origine : RMXP/99999_DebugMenu_InputFixes.rb
# Les commentaires et la mise en forme d'origine ne sont pas récupérables.

module DebugMenuMonkeyPatch
  module InputFixes
    def self.install!
      return false unless defined?(GamePlay::DebugMenu)
      return true if GamePlay::DebugMenu.ancestors.include?(self)
      GamePlay::DebugMenu.prepend(self)
      true
    end

    def confirm_pressed?
      enter_key = (Input::Keyboard::Enter rescue 13)
      enter_now = debug_menu_key_pressed?(enter_key)
      mapped_confirm = Input.trigger?(:A)
      triggered = mapped_confirm || enter_now && !@_enter_was_pressed
      @_enter_was_pressed = enter_now
      triggered
    end

    def cancel_pressed?
      escape_key = (Input::Keyboard::Escape rescue 27)
      esc_now = debug_menu_key_pressed?(escape_key)

      return false if @__debug_menu_text_editing && debug_menu_delete_pressed_raw? && !esc_now
      mapped_cancel = Input.trigger?(:B)
      triggered = mapped_cancel || esc_now && !@_escape_was_pressed
      @_escape_was_pressed = esc_now
      triggered
    end

    def display_number_input(prompt, default = 0)
      begin
        value = default.to_i.abs.to_s
        max_digits = 10
        negative = default.to_i < 0
        input_sprite = Sprite.new(@viewport)
        input_sprite.bitmap = Bitmap.new(250, 100)
        input_sprite.bitmap.fill_rect(0, 0, 250, 100, Color.new(30, 30, 50, 240))
        input_sprite.x = (Graphics.width - 250) / 2
        input_sprite.y = (Graphics.height - 100) / 2
        input_sprite.z = 60
        prompt_text = Text.new(0, @viewport, input_sprite.x, input_sprite.y + 10, 250, 20, prompt, 1, 1, 9)
        prompt_text.z = 61
        value_text = Text.new(0, @viewport, input_sprite.x, input_sprite.y + 40, 250, 20, (negative ? "-" : "") + value, 1, 1, 9)
        value_text.z = 61
        inst_text = Text.new(0, @viewport, input_sprite.x, input_sprite.y + 70, 250, 16, text_get(GamePlay::DebugMenu::TEXT_FILE_ID, 35), 1, 1, 9)
        inst_text.z = 61
        reset_input_states
        @__debug_menu_text_editing = true
        key_states = {}
        debug_menu_number_input_keys.each { |k| key_states[k] = debug_menu_key_pressed?(k) }
        result = nil
        loop do
          Graphics.update

          if confirm_pressed? || Mouse.trigger?(:LEFT)
            play_decision_se
            result = (negative ? -1 : 1) * value.to_i
            break
          end

          if debug_menu_escape_triggered?(key_states) || Mouse.trigger?(:RIGHT)
            play_cursor_se
            break
          end

          numeric_text_entered = false
          if input_text = Input.get_text
            value, negative, numeric_text_entered = debug_menu_apply_numeric_input(input_text, value, negative, max_digits)
            value_text.text = (negative ? "-" : "") + value if numeric_text_entered
          end

          raw_input = debug_menu_triggered_numeric_input(key_states)
          if !numeric_text_entered && raw_input
            value, negative = debug_menu_apply_numeric_input(raw_input, value, negative, max_digits)
            value_text.text = (negative ? "-" : "") + value
          end

          if debug_menu_delete_or_backspace_triggered?(key_states)
            value = value[(0...-1)]
            value = "0" if value.empty?
            value_text.text = (negative ? "-" : "") + value
          end

          if debug_menu_arrow_triggered?(key_states, debug_menu_up_key, debug_menu_right_key)
            play_cursor_se
            current_val = (negative ? -1 : 1) * value.to_i + 1
            negative = current_val < 0
            value = current_val.abs.to_s
            value_text.text = (negative ? "-" : "") + value
          end

          if debug_menu_arrow_triggered?(key_states, debug_menu_down_key, debug_menu_left_key)
            play_cursor_se
            current_val = (negative ? -1 : 1) * value.to_i - 1
            negative = current_val < 0
            value = current_val.abs.to_s
            value_text.text = (negative ? "-" : "") + value
          end
        end
        result
      ensure
        @__debug_menu_text_editing = false
        input_sprite&.bitmap&.dispose
        input_sprite&.dispose
        prompt_text&.dispose
        value_text&.dispose
        inst_text&.dispose
      end
    end

    def display_text_input(prompt, default = "")
      begin
        text_value = default.to_s
        input_sprite = Sprite.new(@viewport)
        input_sprite.bitmap = Bitmap.new(300, 100)
        input_sprite.bitmap.fill_rect(0, 0, 300, 100, Color.new(30, 30, 50, 240))
        input_sprite.x = (Graphics.width - 300) / 2
        input_sprite.y = (Graphics.height - 100) / 2
        input_sprite.z = 60
        prompt_text = Text.new(0, @viewport, input_sprite.x, input_sprite.y + 10, 300, 20, prompt, 1, 1, 9)
        prompt_text.z = 61
        value_text = Text.new(0, @viewport, input_sprite.x, input_sprite.y + 40, 300, 20, text_value, 1, 1, 9)
        value_text.z = 61
        inst_text = Text.new(0, @viewport, input_sprite.x, input_sprite.y + 70, 300, 16, text_get(GamePlay::DebugMenu::TEXT_FILE_ID, 34), 1, 1, 9)
        inst_text.z = 61
        reset_input_states
        @__debug_menu_text_editing = true
        key_states = {}
        [*(Input::Keyboard::A..Input::Keyboard::Z), *(Input::Keyboard::Num0..Input::Keyboard::Num9), Input::Keyboard::Backspace, debug_menu_delete_key, debug_menu_escape_key, (Input::Keyboard::OemMinus rescue 189)].each { |k| key_states[k] = debug_menu_key_pressed?(k) }
        result = nil
        loop do
          Graphics.update

          if confirm_pressed? || Mouse.trigger?(:LEFT)
            play_decision_se
            result = text_value
            break
          end

          if debug_menu_escape_triggered?(key_states) || Mouse.trigger?(:RIGHT)
            play_cursor_se
            break
          end

          if input_text = Input.get_text
            input_text.chars.each do |char|
              if char.match?(/[A-Za-z0-9_]/)
                text_value += char
                value_text.text = text_value
              end
            end
          end

          if debug_menu_delete_or_backspace_triggered?(key_states)
            text_value = text_value[(0...-1)]
            value_text.text = text_value
          end
        end
        result
      ensure
        @__debug_menu_text_editing = false
        input_sprite&.bitmap&.dispose
        input_sprite&.dispose
        prompt_text&.dispose
        value_text&.dispose
        inst_text&.dispose
      end
    end

    private

    def debug_menu_delete_key
      begin
        Input::Keyboard::Delete
      rescue StandardError
        46
      end
    end

    def debug_menu_escape_key
      begin
        Input::Keyboard::Escape
      rescue StandardError
        27
      end
    end

    def debug_menu_up_key
      begin
        Input::Keyboard::Up
      rescue StandardError
        nil
      end
    end

    def debug_menu_down_key
      begin
        Input::Keyboard::Down
      rescue StandardError
        nil
      end
    end

    def debug_menu_left_key
      begin
        Input::Keyboard::Left
      rescue StandardError
        nil
      end
    end

    def debug_menu_right_key
      begin
        Input::Keyboard::Right
      rescue StandardError
        nil
      end
    end

    def debug_menu_key_pressed?(key)
      begin
        return false unless key
        Input::Keyboard.press?(key)
      rescue StandardError
        false
      end
    end

    def debug_menu_delete_pressed_raw?
      debug_menu_key_pressed?(debug_menu_delete_key)
    end

    def debug_menu_delete_or_backspace_triggered?(key_states)
      backspace_key = Input::Keyboard::Backspace
      delete_key = debug_menu_delete_key
      backspace_now = debug_menu_key_pressed?(backspace_key)
      delete_now = debug_menu_key_pressed?(delete_key)
      backspace_triggered = backspace_now && !key_states[backspace_key]
      delete_triggered = delete_now && !key_states[delete_key]
      key_states[backspace_key] = backspace_now
      key_states[delete_key] = delete_now

      backspace_triggered || delete_triggered
    end

    def debug_menu_escape_triggered?(key_states)
      escape_key = debug_menu_escape_key
      escape_now = debug_menu_key_pressed?(escape_key)
      triggered = escape_now && !key_states[escape_key]
      key_states[escape_key] = escape_now
      triggered
    end

    def debug_menu_number_input_keys
      unless @__debug_menu_number_input_keys
        @__debug_menu_number_input_keys
        keys = []
        keys.concat((Input::Keyboard::Num0..Input::Keyboard::Num9).to_a)
        if Input::Keyboard.const_defined?(:Numpad0)
          keys.concat((Input::Keyboard::Numpad0..Input::Keyboard::Numpad9).to_a)
        end
        keys.concat([Input::Keyboard::Backspace, debug_menu_delete_key, debug_menu_escape_key, debug_menu_up_key, debug_menu_down_key, debug_menu_left_key, debug_menu_right_key, (Input::Keyboard::OemMinus rescue 189)])
      end

      @__debug_menu_number_input_keys = keys.compact.uniq
    end

    def debug_menu_apply_numeric_input(input_text, value, negative, max_digits)
      changed = false

      input_text.to_s.chars.each do |char|
        if char.match?(/[0-9]/) && value.length < max_digits
          value = value == "0" ? char : value + char
          changed = true
        elsif char == "-"
          negative = !negative
          changed = true
        end
      end

      [value, negative, changed]
    end

    def debug_menu_triggered_numeric_input(key_states)
      chars = +""
      changed = false

      debug_menu_digit_key_map.each do |key, char|
        next unless key
        now = debug_menu_key_pressed?(key)
        if now && !key_states[key]
          chars << char
          changed = true
        end

        key_states[key] = now
      end

      minus_key = (Input::Keyboard::OemMinus rescue 189)
      minus_now = debug_menu_key_pressed?(minus_key)
      if minus_now && !key_states[minus_key]
        chars << "-"
        changed = true
      end

      key_states[minus_key] = minus_now
      return chars if changed
    end

    def debug_menu_digit_key_map
      unless @__debug_menu_digit_key_map
        @__debug_menu_digit_key_map
        key_map = []
        key_map.concat((0..9).map { |digit| [Input::Keyboard.const_get("Num#{digit}"), digit.to_s] })
        if Input::Keyboard.const_defined?(:Numpad0)
          key_map.concat((0..9).map { |digit| [Input::Keyboard.const_get("Numpad#{digit}"), digit.to_s] })
        end
      end

      @__debug_menu_digit_key_map = key_map
    end

    def debug_menu_arrow_triggered?(key_states, *keys)
      keys.any? do |key|
        next false unless key
        now = debug_menu_key_pressed?(key)
        triggered = now && !key_states[key]
        key_states[key] = now
        triggered
      end
    end
  end
end

unless DebugMenuMonkeyPatch::InputFixes.install!
  debug_menu_install_trace = TracePoint.new(:end) do
    next debug_menu_install_trace.disable if DebugMenuMonkeyPatch::InputFixes.install!
  end
  debug_menu_install_trace.enable
end
