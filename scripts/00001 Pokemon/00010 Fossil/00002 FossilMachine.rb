# Script décompilé depuis le bytecode du jeu (Ruby 3.0) — fichier d'origine : RMXP/200 FossilMachine.rb
# Les commentaires et la mise en forme d'origine ne sont pas récupérables.

module PFM
  class Bag
    DNA_SEQUENCE_SOCKET = 9 unless const_defined?(:DNA_SEQUENCE_SOCKET, false)
    unless const_defined?(:DNA_SEQUENCE_POCKET_ID, false)
      DNA_SEQUENCE_POCKET_ID = DNA_SEQUENCE_SOCKET
    end

    module DNASequencePocket
      def initialize(*args)
        super
        ensure_dna_sequence_pocket
      end

      def convert_to_dot26
        begin
          super
        ensure
          ensure_dna_sequence_pocket
        end
      end

      def get_order(socket)
        ensure_dna_sequence_pocket if socket == self.class()::DNA_SEQUENCE_SOCKET
        super
      end

      def dna_sequence_socket
        self.class()::DNA_SEQUENCE_SOCKET
      end

      def ensure_dna_sequence_pocket
        @orders ||= []
        @orders[self.class()::DNA_SEQUENCE_SOCKET] ||= []
      end
    end

    unless ancestors.include?(DNASequencePocket)
      prepend(DNASequencePocket)
    end
  end

  class GameState
    on_expand_global_variables(:dna_sequence_bag_pocket) { @bag&.ensure_dna_sequence_pocket }

    attr_accessor(:selected_sequences_dnakit)
    attr_accessor(:selected_sequences_dnakit_slot_indexes)
    attr_accessor(:fossil_resurrection_data)
    on_initialize(:selected_sequences_dnakit) { @selected_sequences_dnakit = {} }
    on_initialize(:selected_sequences_dnakit_slot_indexes) { @selected_sequences_dnakit_slot_indexes = {} }
    on_initialize(:fossil_resurrection_data) { @fossil_resurrection_data = {} }
    on_expand_global_variables(:selected_sequences_dnakit) { ensure_selected_sequences_dnakit }

    on_expand_global_variables(:selected_sequences_dnakit_slot_indexes) { ensure_selected_sequences_dnakit }

    on_expand_global_variables(:fossil_resurrection_data) do
      next if @fossil_resurrection_data.is_a?(Hash)
      @fossil_resurrection_data = {}
    end

    def ensure_selected_sequences_dnakit
      @selected_sequences_dnakit = {} unless @selected_sequences_dnakit.is_a?(Hash)
      unless @selected_sequences_dnakit_slot_indexes.is_a?(Hash)
        @selected_sequences_dnakit_slot_indexes = {}
      end

      @selected_sequences_dnakit.delete_if { |_symbol, count| count.to_i <= 0 }
    end

    alias ensure_not_nil ensure_selected_sequences_dnakit

    def sync_selected_sequences_dnakit(symbols, slot_indexes = nil)
      @selected_sequences_dnakit = {}
      @selected_sequences_dnakit_slot_indexes = {}

      Array(symbols).each_with_index do |symbol, index|
        symbol = normalize_sequence_symbol(symbol)
        next unless symbol
        @selected_sequences_dnakit[symbol] = @selected_sequences_dnakit.fetch(symbol, 0).to_i + 1
        slot_index = Array(slot_indexes)[index]
        next if slot_index.nil?

        @selected_sequences_dnakit_slot_indexes[slot_index.to_i] = symbol
      end
    end

    def clear_sequences
      @selected_sequences_dnakit = {}
      @selected_sequences_dnakit_slot_indexes = {}
    end

    private

    def normalize_sequence_symbol(value)
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
  end
end

module GamePlay
  class << self
    attr_accessor(:fossil_machine_ui_class)
    attr_accessor(:fossil_bag_class)
    attr_accessor(:adn_bag_class)
    attr_accessor(:pending_fossil_resurrection_result)

    def open_fossil_machine_ui(&block)
      if fossil_resurrection_in_progress?
        if fossil_resurrection_ready?
          self.pending_fossil_resurrection_result = resolve_fossil_resurrection
        else
          if $scene&.respond_to?(:display_message)
            $scene.display_message(fossil_resurrection_in_progress_message)
          end
          return
        end
      else
        current_scene.call_scene(fossil_machine_ui_class || FossilMachineUI, &block)
      end
    end

    def fossil_resurrection_in_progress?
      $game_switches && $game_switches[FossilMachineUI::RESURRECTION_SWITCH_ID]
    end

    def fossil_resurrection_ready?
      fossil_resurrection_data[:remaining_seconds].to_i <= 0
    end

    def resolve_fossil_resurrection
      data = fossil_resurrection_data
      success = data[:success]
      pokemon = success ? give_resolved_fossil_pokemon(data[:pokemon_symbol]) : nil
      success &&= !pokemon.nil?
      clear_fossil_resurrection_data

      { success: success, pokemon: pokemon }
    end

    def give_resolved_fossil_pokemon(pokemon_symbol)
      return if pokemon_symbol.nil?
      pokemon = PFM::Pokemon.new(pokemon_symbol.to_sym, 5, false, false)
      added = PFM.game_state.add_pokemon(pokemon)
      return unless added
      post_resurrection_webhook_if_shiny(pokemon)
      pokemon
    end

    def post_resurrection_webhook_if_shiny(pokemon)
      return unless pokemon&.shiny?
      return unless defined?(DiscordWebhooks) && DiscordWebhooks.respond_to?(:post_ressurect)

      DiscordWebhooks.post_ressurect(pokemon)
    end

    def clear_fossil_resurrection_data
      $game_switches[FossilMachineUI::RESURRECTION_SWITCH_ID] = false if $game_switches
      PFM.game_state.fossil_resurrection_data = {} if PFM.game_state
    end

    def take_pending_fossil_resurrection_result
      result = pending_fossil_resurrection_result
      self.pending_fossil_resurrection_result = nil
      result
    end

    def fossil_resurrection_in_progress_message
      data = fossil_resurrection_data
      duration = blue_text(format_fossil_resurrection_duration(data[:remaining_seconds]))
      fossil_name = blue_text(data[:fossil_name])

      if fossil_machine_language == :en
        "There is still #{duration} of incubation left for #{fossil_name}."
      else
        "Il reste encore #{duration} d'incubation à #{fossil_name}."
      end
    end

    def fossil_resurrection_data
      data = PFM.game_state&.fossil_resurrection_data
      data = {} unless data.is_a?(Hash)
      duration_seconds = data[:duration_seconds] || data["duration_seconds"] || data[:remaining_seconds] || data["remaining_seconds"] || fake_fossil_resurrection_seconds

      started_at = data[:started_at] || data["started_at"]
      remaining_seconds = started_at ? [duration_seconds.to_i - (Time.now.to_i - started_at.to_i), 0].max : duration_seconds.to_i

      { fossil_name: data[:fossil_name] || data["fossil_name"] || fake_fossil_resurrection_name, pokemon_symbol: data[:pokemon_symbol] || data["pokemon_symbol"], success_rate: data[:success_rate] || data["success_rate"] || 0.0, success: truthy_fossil_resurrection_value(data[:success] || data["success"]), duration_seconds: duration_seconds.to_i, remaining_seconds: remaining_seconds, started_at: started_at }
    end

    def truthy_fossil_resurrection_value(value)
      value == true || value.to_s == "true"
    end

    def fake_fossil_resurrection_name
      return "unknown" if fossil_machine_language == :en
      "inconnu"
    end

    def fake_fossil_resurrection_seconds
      FossilMachineUI::RESURRECTION_REFERENCE_SECONDS
    end

    def format_fossil_resurrection_duration(seconds)
      FossilMachineUI.format_duration(seconds.to_i, fossil_machine_language)
    end

    def blue_text(text)
      "\\c[1]#{text}\\c[0]"
    end

    def fossil_machine_language
      return Raty.language_symbol_stp if defined?(Raty) && Raty.respond_to?(:language_symbol_stp)
      :fr
    end

    def open_bag_to_select_fossil(&block)
      current_scene.call_scene(fossil_bag_class || FossilBag, &block)
    end

    def open_bag_to_select_adn(&block)
      return open_dnakit_interface(:selection, &block) if respond_to?(:open_dnakit_interface)

      current_scene.call_scene(adn_bag_class || ADNBag, &block)
    end
  end

  class Bag
    unless const_defined?(:DNA_SEQUENCE_SOCKET, false)
      DNA_SEQUENCE_SOCKET = PFM::Bag::DNA_SEQUENCE_SOCKET
    end

    POCKET_NAMES[DNA_SEQUENCE_SOCKET] ||= "Séquences ADN"
  end

  class Shop
    private

    def MAX_DNAKIT_ITEMS
      GamePlay::DNAKitInterface::MAX_VISIBLE_ITEMS
    end

    def COUNT_DNAKIT_ITEMS
      $bag.get_order(GamePlay::Bag::DNA_SEQUENCE_SOCKET).select { |id| id && id != 0 && dna_sequence_item?(id) }.sum { |id| $bag.item_quantity(data_item(id).db_symbol).to_i }
    end

    def MSG_DNAKIT_FULL
      return "Il n'y aura pas la place dans le Kit ADN !" if $options.language == "fr"
      "There won't be enough space in the DNA Kit!"
    end

    def dna_sequence_item?(item_id = @list_item[@index])
      data_item(item_id).socket == GamePlay::Bag::DNA_SEQUENCE_SOCKET
    end

    def launch_buy_sequence
      dnakit_full = dna_sequence_item? && COUNT_DNAKIT_ITEMS() >= MAX_DNAKIT_ITEMS()

      if dnakit_full
        $scene.display_message(MSG_DNAKIT_FULL())
        nil
      else
        return buy_unlimited_use_item if data_item(@list_item[@index]).is_limited == false
        buy_limited_use_item
      end
    end

    def buy_limited_use_item
      return if amount_selection(@list_price[@index], @list_item[@index])
      return if $game_variables[::Yuki::Var::EnteredNumber] == 0
      quantity = $game_variables[::Yuki::Var::EnteredNumber]
      dnakit_will_be_full = dna_sequence_item? && COUNT_DNAKIT_ITEMS() + quantity > MAX_DNAKIT_ITEMS()

      if dnakit_will_be_full
        $scene.display_message(MSG_DNAKIT_FULL())
        nil
      else
        return if confirm_buy(@list_price[@index], @list_item[@index], quantity)
        money_checkout(quantity)
      end
    end
  end

  module BagDNAPocketIconPatch
    module PocketListDNAFallback
      private

      def add_pocket_sprite(pocket_id)
        pocket_id = 1 if pocket_id == GamePlay::Bag::DNA_SEQUENCE_SOCKET
        super(pocket_id)
      end
    end

    module_function

    def apply
      return if UI::Bag::PocketList.ancestors.include?(PocketListDNAFallback)

      UI::Bag::PocketList.prepend(PocketListDNAFallback)
    end
  end

  BagDNAPocketIconPatch.apply

  module FossilMachineData
    FOSSIL_TO_POKEMON = { dome_fossil: :kabuto, helix_fossil: :omanyte, old_amber: :aerodactyl, root_fossil: :lileep, claw_fossil: :anorith, skull_fossil: :cranidos, armor_fossil: :shieldon, plume_fossil: :archen, cover_fossil: :tirtouga, jaw_fossil: :tyrunt, sail_fossil: :amaura }.freeze

    TYPE_TO_ADN = { rock: :adn_roche, water: :adn_eau, flying: :adn_vol, grass: :adn_plante, bug: :adn_insecte, steel: :adn_acier, dragon: :adn_dragon, ice: :adn_glace }.freeze

    module_function

    def fossil_item?(db_symbol)
      FOSSIL_TO_POKEMON.key?(normalize_symbol(db_symbol))
    end

    def pokemon_symbol_for(db_symbol)
      FOSSIL_TO_POKEMON[normalize_symbol(db_symbol)]
    end

    def adn_symbol_for_type(type_symbol)
      TYPE_TO_ADN[normalize_symbol(type_symbol)]
    end

    def normalize_symbol(value)
      return value.db_symbol if value.respond_to?(:db_symbol)
      return value.to_sym if value.respond_to?(:to_sym)

      value
    end
  end

  class FossilBag < Bag
    def initialize
      super(:hold)
    end

    private

    def load_pockets
      @pocket_indexes = [1]
      @pocket_names = [get_text(GamePlay::Bag::POCKET_NAMES[1])]
    end

    def load_item_list
      super
      @item_list = @item_list.select { |item_id| FossilMachineData.fossil_item?(data_item(item_id)) }
      @index = 0
      @last_index = @item_list.size
    end

    alias reload_item_list load_item_list

    def button_texts
      hold_texts = GamePlay::Bag::CTRL_TEXTS_PER_MODE[:hold]
      if defined?(Raty) && Raty.respond_to?(:language_symbol_stp) && Raty.language_symbol_stp == :en
        ["choose", get_text(hold_texts[1]), get_text(hold_texts[2]), get_text(hold_texts[3])]
      else
        ["choisir", get_text(hold_texts[1]), get_text(hold_texts[2]), get_text(hold_texts[3])]
      end
    end
  end

  class ADNBag < Bag
    def initialize
      super(:adn)
    end

    private

    def load_pockets
      @pocket_indexes = [GamePlay::Bag::DNA_SEQUENCE_SOCKET]
      @pocket_names = [GamePlay::Bag::POCKET_NAMES[GamePlay::Bag::DNA_SEQUENCE_SOCKET]]
    end

    def load_item_list
      @item_list = $bag.get_order(GamePlay::Bag::DNA_SEQUENCE_SOCKET).select { |item_id| data_item(item_id).socket == GamePlay::Bag::DNA_SEQUENCE_SOCKET }

      @index = 0
      @last_index = @item_list.size
    end

    alias reload_item_list load_item_list

    def action_a
      item_id = @item_list[@index]
      return action_b if item_id.nil?
      return play_buzzer_se if item_id == 0
      play_decision_se
      @running = false
      @return_data = item_id
    end

    def button_texts
      hold_texts = GamePlay::Bag::CTRL_TEXTS_PER_MODE[:hold]
      if defined?(Raty) && Raty.respond_to?(:language_symbol_stp) && Raty.language_symbol_stp == :en
        ["choose", get_text(hold_texts[1]), get_text(hold_texts[2]), get_text(hold_texts[3])]
      else
        ["choisir", get_text(hold_texts[1]), get_text(hold_texts[2]), get_text(hold_texts[3])]
      end
    end
  end

  class FossilMachineBaseUI < UI::SettingsBase
    BACKGROUND_FRAME_COUNT = 5
    BACKGROUND_FRAME_DURATION = 0.5

    def update_background_animation
      return unless @background&.bitmap
      frame_index = absolute_animation_frame_index(@background_animation_started_at, BACKGROUND_FRAME_DURATION, BACKGROUND_FRAME_COUNT)
      return if frame_index == @background_frame_index
      @background_frame_index = frame_index
      refresh_background_frame
    end

    private

    def background_filename
      "8 fossile/background"
    end

    def create_background_animation
      @background_animation_started_at = animation_time_reference
      @background_frame_index = 0
      refresh_background_frame
    end

    def refresh_background_frame
      return unless @background&.bitmap
      frame_width = @background.bitmap.width / BACKGROUND_FRAME_COUNT
      frame_height = @background.bitmap.height
      frame_x = frame_width * @background_frame_index
      @background.src_rect.set(frame_x, 0, frame_width, frame_height)
    end

    def absolute_animation_frame_index(started_at, frame_duration, frame_count)
      return 0 unless started_at && frame_duration.positive? && frame_count.positive?
      elapsed = animation_time_reference - started_at
      (elapsed / frame_duration).floor % frame_count
    end

    def animation_time_reference
      begin
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      rescue StandardError
        Graphics.current_time.to_f
      end
    end
  end

  class FossilMachineUI < BaseCleanUpdate::FrameBalanced
    attr_reader(:return_data)
    DEBUG_ASSET_PREVIEW_ONLY = false
    MOUSE_ACTIONS = [:action_a, :action_x, nil, :action_b].freeze
    DEBUG_MOUSE_ACTIONS = [nil, nil, nil, :action_b].freeze
    FOCUS_NEIGHBORS = { fossil: { right: :adn_1 }, adn_1: { left: :fossil, down: :adn_2 }, adn_2: { left: :fossil, up: :adn_1 } }.freeze

    TEXT_Z = 20
    SPRITE_Z = 10
    PANEL_Z = 1
    SELECTOR_Z = 12
    OVERLAY_Z = 30
    OVERLAY_TEXT_Z = 31
    SELECT_ARROW_MARGIN = 4
    SELECT_ARROW_OFFSET = [-2, 0].freeze
    SELECT_ARROW_FRAME_COUNT = 2
    SELECT_ARROW_FRAME_DURATION = 0.5
    FOSSIL_DISPLAY_OFFSET = [0, -1].freeze
    RESURRECTION_PROCESS_MINUTES = 10
    RESURRECTION_REFERENCE_RARITY = 45.0
    RESURRECTION_REFERENCE_SECONDS = RESURRECTION_PROCESS_MINUTES * 60
    RESURRECTION_SWITCH_ID = 581
    RESULT_MODAL_HEIGHT = 214
    RESULT_SPRITE_SIZE = 64
    RESULT_SHINY_CRY_DELAY = 0.45
    RESULT_SHINY_COLUMNS = 12
    RESULT_SHINY_ROWS = 10
    RESULT_SHINY_FRAME_COUNT = RESULT_SHINY_COLUMNS * RESULT_SHINY_ROWS
    RESULT_SHINY_DURATION = 1.5
    SCAN_ANIMATION_DURATION = 3.0
    SCAN_SWEEP_DURATION = 1.0
    SCAN_SWEEP_SE = "audio/se/select"
    SCAN_SWEEP_SE_VOLUME = 90
    SCAN_SWEEP_SE_PITCH = 100
    SCAN_SWEEP_HEIGHT = 0.045
    SCAN_SWEEP_STRENGTH = 1.15
    SCAN_SWEEP_COLOR = [1.0, 0.08, 0.04, 1.0].freeze
    SCAN_SHADER_NAME = :raty_fossil_machine_scan
    SCAN_SHADER_FRAGMENT = "uniform sampler2D texture;\nuniform float scan_progress;\nuniform float sweep_height;\nuniform float sweep_strength;\nuniform vec4 sweep_color;\n\nvoid main() {\n  vec2 uv = gl_TexCoord[0].xy;\n  vec4 frag = texture2D(texture, uv);\n\n  if (frag.a <= 0.001) {\n    frag = vec4(0.0);\n  } else {\n    float distance_to_ray = abs(uv.y - scan_progress);\n    float ray = 1.0 - smoothstep(0.0, sweep_height, distance_to_ray);\n    float ray_core = 1.0 - smoothstep(0.0, sweep_height * 0.24, distance_to_ray);\n    vec3 glow = sweep_color.rgb * ray * sweep_strength;\n    vec3 core = vec3(1.0) * ray_core * sweep_strength * 0.45;\n\n    frag.rgb = min(frag.rgb + glow + core, vec3(1.0));\n  }\n\n  gl_FragColor = frag;\n}\n"

    OFFSET_Y = 10
    INFO_PANEL = { x: 64, y: 65 + OFFSET_Y, width: 148, height: 64 }.freeze
    FOSSIL_PANEL = { x: INFO_PANEL[:x] + INFO_PANEL[:width] - 64, y: INFO_PANEL[:y], width: 64, height: 64 }.freeze
    ADN_1_PANEL = { x: 224, y: 65 + OFFSET_Y, width: 32, height: 32 }.freeze
    ADN_2_PANEL = { x: 224, y: 97 + OFFSET_Y, width: 32, height: 32 }.freeze
    INFO_TEXT_X = 67
    INFO_TEXT_Y = 65 + OFFSET_Y
    INFO_TEXT_WIDTH = 70
    INFO_TEXT_HEIGHT = 16
    PANEL_FILL = Color.new(190, 200, 204, 225)
    PANEL_INNER = Color.new(228, 234, 230, 235)
    PANEL_BORDER = Color.new(21, 31, 36, 255)
    PANEL_ACCENT = Color.new(67, 129, 150, 255)
    PANEL_FOCUS = Color.new(245, 231, 132, 255)
    PANEL_FOCUS_OVERLAY = Color.new(245, 231, 132, 72)
    ADN_DISABLED_FILL = Color.new(150, 157, 158, 190)
    SCAN_FILL = Color.new(38, 72, 88, 235)
    SCAN_DISABLED_FILL = Color.new(102, 112, 116, 220)
    WHITE_TEXT = Color.new(255, 255, 255)
    DARK_TEXT = Color.new(18, 27, 31)
    MUTED_TEXT = Color.new(84, 94, 98)
    ACTION_TEXT = Color.new(255, 0, 0)
    SUCCESS_TEXT = Color.new(0, 160, 0)

    def self.format_duration(seconds, language = :fr)
      seconds = seconds.to_i
      minutes = seconds / 60
      remaining_seconds = seconds % 60
      parts = []
      if minutes.positive?
        parts << duration_unit(minutes, language, "minute", "minutes", "minute", "minutes")
      end
      if remaining_seconds.positive? || parts.empty?
        parts << duration_unit(remaining_seconds, language, "seconde", "secondes", "second", "seconds")
      end

      parts.join(" ")
    end

    def self.duration_unit(value, language, fr_singular, fr_plural, en_singular, en_plural)
      label = language == :en ? (value == 1 ? en_singular : en_plural) : value == 1 ? fr_singular : fr_plural

      "#{value} #{label}"
    end

    def initialize
      super()
      @selected_fossil_symbol = nil
      @selected_fossil_item = nil
      @target_pokemon_symbol = nil
      @target_pokemon = nil
      @selected_adn_symbols = [nil, nil]
      @selected_adn_items = [nil, nil]
      @selected_adn_slot_indexes = [nil, nil]
      @adn_choice_index = nil
      @resurrection_confirmation_active = false
      @result_modal_active = false
      @resurrection_result_success = nil
      @resurrection_result_pokemon = nil
      @result_cry_play_at = nil
      @result_shiny_animation_started_at = nil
      @scanned = false
      @scan_animation_started_at = nil
      @scan_animation_last_sweep_index = nil
      @fossil_icon_shader_before_scan = nil
      @pending_resurrection_result = GamePlay.take_pending_fossil_resurrection_result
      @focus = :fossil
      @return_data = nil
      sync_selected_sequences_dnakit
    end

    def update_inputs
      if DEBUG_ASSET_PREVIEW_ONLY
        action_b if Input.trigger?(:B)
        true
      else
        return true if scan_animation_active?
        if adn_choice_active?
          if Input.trigger?(:B)
            action_b
          elsif Input.trigger?(:A)
            action_a
          else
            action_x if Input.trigger?(:X)
          end
          true
        elsif result_modal_active?
          if Input.trigger?(:B)
            action_b
          else
            action_a if Input.trigger?(:A)
          end
          true
        elsif resurrection_confirmation_active?
          if Input.trigger?(:B)
            action_b
          else
            action_a if Input.trigger?(:A)
          end
          true
        else
          if Input.trigger?(:B)
            action_b
          elsif Input.trigger?(:LEFT)
            move_focus(:left)
          elsif Input.trigger?(:RIGHT)
            move_focus(:right)
          elsif Input.trigger?(:UP)
            move_focus(:up)
          elsif Input.trigger?(:DOWN)
            move_focus(:down)
          elsif Input.trigger?(:A)
            action_a
          elsif Input.trigger?(:X)
            action_x
          else
            return true
          end
          true
        end
      end
    end

    def update_mouse(moved)
      if DEBUG_ASSET_PREVIEW_ONLY
        update_mouse_ctrl_buttons(@base_ui.ctrl, DEBUG_MOUSE_ACTIONS) if @base_ui
        true
      else
        return true if scan_animation_active?
        update_mouse_ctrl_buttons(@base_ui.ctrl, MOUSE_ACTIONS) if @base_ui
        return true if overlay_active?
        update_mouse_focus if moved
        return true unless Mouse.trigger?(:LEFT)
        if mouse_over_panel?(FOSSIL_PANEL)
          set_focus(:fossil)
          action_a
        elsif mouse_over_panel?(ADN_1_PANEL) && adn_slot_enabled?(0)
          action_adn_slot(0)
        else
          action_adn_slot(1) if mouse_over_panel?(ADN_2_PANEL) && adn_slot_enabled?(1)
        end
        true
      end
    end

    def update_graphics
      @base_ui.update_background_animation
      @pokemon_sprite&.update
      @result_pokemon_sprite&.update
      update_result_modal_audio
      update_result_shiny_animation
      update_scan_animation
      update_selection_arrow_animation
      true
    end

    def dispose
      clear_selected_sequences_dnakit
      return super if defined?(super)
    end

    private

    def create_graphics
      create_viewport
      create_base_ui
      create_panels
      create_sprites
      create_texts
      refresh_display
      open_pending_resurrection_result
    end

    def create_base_ui
      @base_ui = FossilMachineBaseUI.new(@viewport, button_texts)
    end

    def create_panels
      @screen_sprite = Sprite.new(@viewport)
      @screen_sprite.bitmap = RPG::Cache.interface("8 fossile/screen")
      @screen_sprite.x = 0
      @screen_sprite.y = 0
      @screen_sprite.z = 0
      @info_panel_sprite = asset_panel_sprite(INFO_PANEL, "8 fossile/panel_infos", PANEL_Z)
      @adn_1_panel_sprite = asset_panel_sprite(ADN_1_PANEL, "8 fossile/panel_adn", PANEL_Z)
      @adn_2_panel_sprite = asset_panel_sprite(ADN_2_PANEL, "8 fossile/panel_adn", PANEL_Z)
      create_selection_arrow
      create_choice_adn_overlay
      create_resurrection_modal_overlay
      create_result_modal_overlay
    end

    def create_sprites
      @fossil_icon = Sprite.new(@viewport)
      @fossil_icon.z = SPRITE_Z
      @fossil_icon.visible = false

      @adn_icons = Array.new(2) do
        sprite = Sprite.new(@viewport)
        sprite.z = SPRITE_Z
        sprite.visible = false
        sprite
      end

      @pokemon_sprite = UI::PokemonFaceSprite.new(@viewport)
      @pokemon_sprite.z = SPRITE_Z
      @pokemon_sprite.visible = false
      @result_pokemon_sprite = UI::PokemonFaceSprite.new(@viewport)
      @result_pokemon_sprite.z = OVERLAY_TEXT_Z
      @result_pokemon_sprite.visible = false
      @result_shiny_sprite = Sprite.new(@viewport)
      @result_shiny_sprite.bitmap = RPG::Cache.animation("shiny")
      @result_shiny_sprite.z = OVERLAY_TEXT_Z + 1
      @result_shiny_sprite.visible = false
      frame_width = @result_shiny_sprite.bitmap.width / RESULT_SHINY_COLUMNS
      frame_height = @result_shiny_sprite.bitmap.height / RESULT_SHINY_ROWS
      @result_shiny_sprite.ox = frame_width / 2.0
      @result_shiny_sprite.oy = frame_height / 2.0
      @result_shiny_sprite.src_rect.set(0, 0, frame_width, frame_height)
      @silhouette_shader = Shader.create(:color_shader)
      @silhouette_shader.set_float_uniform("color", Color.new(0, 0, 0, 255))
      @pokemon_sprite.shader = @silhouette_shader
    end

    def create_texts
      @texts = UI::SpriteStack.new(@viewport)
      @info_line_1 = add_flat_text(INFO_TEXT_X, INFO_TEXT_Y, INFO_TEXT_WIDTH, INFO_TEXT_HEIGHT, "", 0, Color.new(0, 0, 0))
      @info_line_2 = add_flat_text(INFO_TEXT_X, INFO_TEXT_Y + INFO_TEXT_HEIGHT, INFO_TEXT_WIDTH, INFO_TEXT_HEIGHT, "", 0, Color.new(0, 0, 0))
      @info_line_4 = add_flat_text(INFO_TEXT_X, INFO_TEXT_Y + INFO_TEXT_HEIGHT * 2, INFO_TEXT_WIDTH, INFO_TEXT_HEIGHT, "", 0, Color.new(0, 0, 0))
      @info_line_3 = add_flat_text(INFO_TEXT_X, INFO_TEXT_Y + INFO_TEXT_HEIGHT * 3, INFO_TEXT_WIDTH, INFO_TEXT_HEIGHT, "", 0, ACTION_TEXT)
      choice_text_y = ((214 - INFO_TEXT_HEIGHT * 2) / 2.0).floor
      @adn_choice_text_line_1 = add_flat_text(0, choice_text_y, Graphics.width, INFO_TEXT_HEIGHT, "", 1, Color.new(0, 0, 0), z: OVERLAY_TEXT_Z)
      @adn_choice_text_prefix = add_flat_text(0, choice_text_y + INFO_TEXT_HEIGHT, 1, INFO_TEXT_HEIGHT, "", 0, Color.new(0, 0, 0), z: OVERLAY_TEXT_Z)
      @adn_choice_text_item = add_flat_text(0, choice_text_y + INFO_TEXT_HEIGHT, 1, INFO_TEXT_HEIGHT, "", 0, ACTION_TEXT, z: OVERLAY_TEXT_Z)
      @adn_choice_text_suffix = add_flat_text(0, choice_text_y + INFO_TEXT_HEIGHT, 1, INFO_TEXT_HEIGHT, "", 0, Color.new(0, 0, 0), z: OVERLAY_TEXT_Z)
      choice_adn_text_segments.each { |text| text.visible = false }
      @resurrection_confirm_line_1 = add_flat_text(0, 0, Graphics.width, INFO_TEXT_HEIGHT, "", 1, Color.new(0, 0, 0), z: OVERLAY_TEXT_Z)
      @resurrection_confirm_line_3 = add_flat_text(0, 0, Graphics.width, INFO_TEXT_HEIGHT, "", 1, Color.new(0, 0, 0), z: OVERLAY_TEXT_Z)
      @resurrection_confirm_duration_prefix = add_flat_text(0, 0, 1, INFO_TEXT_HEIGHT, "", 0, Color.new(0, 0, 0), z: OVERLAY_TEXT_Z)
      @resurrection_confirm_duration_value = add_flat_text(0, 0, 1, INFO_TEXT_HEIGHT, "", 0, ACTION_TEXT, z: OVERLAY_TEXT_Z)
      @resurrection_confirm_duration_suffix = add_flat_text(0, 0, 1, INFO_TEXT_HEIGHT, "", 0, Color.new(0, 0, 0), z: OVERLAY_TEXT_Z)
      @resurrection_confirm_item_prefixes = Array.new(3) do
        add_flat_text(0, 0, 1, INFO_TEXT_HEIGHT, "", 0, Color.new(0, 0, 0), z: OVERLAY_TEXT_Z)
      end

      @resurrection_confirm_item_names = Array.new(3) do
        add_flat_text(0, 0, 1, INFO_TEXT_HEIGHT, "", 0, ACTION_TEXT, z: OVERLAY_TEXT_Z)
      end

      resurrection_confirmation_texts.each { |text| text.visible = false }
      @result_modal_prefix = add_flat_text(0, 0, 1, INFO_TEXT_HEIGHT, "", 0, Color.new(0, 0, 0), z: OVERLAY_TEXT_Z)
      @result_modal_status = add_flat_text(0, 0, 1, INFO_TEXT_HEIGHT, "", 0, SUCCESS_TEXT, z: OVERLAY_TEXT_Z)
      result_modal_texts.each { |text| text.visible = false }
    end

    def button_texts
      if result_modal_active?
        return [nil, nil, nil, "close"] if language == :en
        [nil, nil, nil, "fermer"]
      elsif resurrection_confirmation_active?
        return ["confirm", nil, nil, "cancel"] if language == :en
        ["confirmer", nil, nil, "annuler"]
      elsif adn_choice_active?
        return ["replace", "remove", nil, "cancel"] if language == :en
        ["remplacer", "retirer", nil, "annuler"]
      else
        quit = $options.language == "en" ? "quit" : "quitter"
        if language == :en
          ["choose", action_button_label, nil, quit]
        else
          ["choisir", action_button_label, nil, quit]
        end
      end
    end

    def action_a
      if result_modal_active?
        play_buzzer_se
        return
      end

      return confirm_resurrection if resurrection_confirmation_active?
      return replace_adn_choice if adn_choice_active?

      case @focus
      when :fossil
        play_decision_se
        return select_fossil_from_bag
      when :adn_1 then return action_adn_slot(0)
      when :adn_2 then action_adn_slot(1)
      else
        return play_buzzer_se
      end
    end

    def action_x
      return delete_adn_choice if adn_choice_active?
      return missing_fossil_feedback unless @selected_fossil_symbol
      scanned_now = !@scanned
      if @scanned
        play_decision_se
        open_resurrection_confirmation
        nil
      else
        play_decision_se
        start_scan_animation(scanned_now)
      end
    end

    def action_b
      if result_modal_active?
        play_cancel_se
        close_resurrection_result
        nil
      elsif resurrection_confirmation_active?
        play_cancel_se
        close_resurrection_confirmation
        nil
      elsif adn_choice_active?
        play_cancel_se
        close_adn_choice
        nil
      else
        play_cancel_se
        close_fossil_machine
      end
    end

    def select_fossil_from_bag
      item_id = -1
      GamePlay.open_bag_to_select_fossil { |scene| item_id = scene.return_data }
      return if item_id == -1 || item_id.nil?
      fossil_symbol = normalize_item_symbol(item_id)
      unless FossilMachineData.fossil_item?(fossil_symbol)
        play_buzzer_se
        display_message(invalid_fossil_message)
        return
      end

      @selected_fossil_symbol = fossil_symbol
      @selected_fossil_item = data_item(fossil_symbol)
      @target_pokemon_symbol = FossilMachineData.pokemon_symbol_for(fossil_symbol)
      @target_pokemon = PFM::Pokemon.new(@target_pokemon_symbol, 1, false, true)
      @selected_adn_symbols = [nil, nil]
      @selected_adn_items = [nil, nil]
      @selected_adn_slot_indexes = [nil, nil]
      sync_selected_sequences_dnakit
      @scanned = false
      @adn_choice_index = nil
      @resurrection_confirmation_active = false
      @result_modal_active = false
      @resurrection_result_success = nil
      @resurrection_result_pokemon = nil
      @result_cry_play_at = nil
      stop_result_shiny_animation
      stop_scan_animation
      @return_data = current_return_data
      refresh_display
    end

    def select_adn_from_bag(index)
      return disabled_adn_slot_feedback(index) unless adn_slot_enabled?(index)
      choice_data = -1
      GamePlay.open_bag_to_select_adn { |scene| choice_data = scene.return_data }
      return if choice_data == -1 || choice_data.nil?
      item_id, dnakit_slot_index = extract_adn_choice_data(choice_data)
      return if item_id.nil?
      adn_symbol = normalize_item_symbol(item_id)
      unless data_item(adn_symbol).socket == GamePlay::Bag::DNA_SEQUENCE_SOCKET
        play_buzzer_se
        display_message(invalid_adn_message)
        return
      end

      @selected_adn_symbols[index] = adn_symbol
      @selected_adn_items[index] = data_item(adn_symbol)
      @selected_adn_slot_indexes[index] = dnakit_slot_index
      sync_selected_sequences_dnakit
      @return_data = current_return_data
      set_focus(:adn_2) if index.zero? && adn_slot_enabled?(1)
      refresh_display
    end

    def missing_fossil_feedback
      play_buzzer_se
      display_message(missing_fossil_message)
    end

    def missing_fossil_for_adn_feedback
      play_buzzer_se
      display_message(missing_fossil_for_adn_message)
    end

    def disabled_adn_slot_feedback(index)
      return missing_fossil_for_adn_feedback unless @selected_fossil_symbol
      return missing_scan_for_adn_feedback unless @scanned

      play_buzzer_se
    end

    def missing_scan_for_adn_feedback
      play_buzzer_se
      display_message(missing_scan_for_adn_message)
    end

    def refresh_display
      refresh_adn_panel_assets
      refresh_fossil_sprite
      refresh_adn_sprites
      refresh_pokemon_sprite
      refresh_texts
      refresh_choice_adn_overlay
      refresh_resurrection_modal_overlay
      refresh_result_modal_overlay
      refresh_choice_adn_text
      refresh_resurrection_confirmation_texts
      refresh_result_modal_text
      refresh_result_pokemon_sprite
      refresh_scan_button
      refresh_focus_visuals
      return apply_debug_asset_preview_visibility if DEBUG_ASSET_PREVIEW_ONLY
    end

    def refresh_fossil_sprite
      unless @selected_fossil_item && (!@scanned || scan_animation_active?)
        return @fossil_icon.visible = false
      end

      @fossil_icon.set_bitmap(@selected_fossil_item.icon, :icon)
      @fossil_icon.src_rect.set(0, 0, @fossil_icon.bitmap.width, @fossil_icon.bitmap.height)
      visible_bounds = visible_bitmap_bounds(@fossil_icon.bitmap)
      if visible_bounds
        src_x, src_y, src_width, src_height = visible_bounds
        @fossil_icon.ox = src_x + src_width / 2.0
        @fossil_icon.oy = src_y + src_height / 2.0
      else
        @fossil_icon.ox = @fossil_icon.bitmap.width / 2.0
        @fossil_icon.oy = @fossil_icon.bitmap.height / 2.0
      end

      @fossil_icon.zoom = 1.25
      @fossil_icon.x = fossil_display_center_x
      @fossil_icon.y = fossil_display_center_y
      @fossil_icon.visible = true
    end

    def scan_animation_active?
      !@scan_animation_started_at.nil?
    end

    def start_scan_animation(move_to_adn_after_scan)
      @scan_animation_started_at = animation_time_reference
      @scan_animation_last_sweep_index = nil
      @move_to_adn_after_scan = move_to_adn_after_scan
      refresh_fossil_sprite
      apply_scan_shader
      update_scan_animation
      refresh_focus_visuals
    end

    def update_scan_animation
      return unless scan_animation_active?
      elapsed = animation_time_reference - @scan_animation_started_at
      if elapsed >= SCAN_ANIMATION_DURATION
        finish_scan_animation
        return
      end

      update_scan_sweep_audio(elapsed)
      update_scan_shader(elapsed)
    end

    def finish_scan_animation
      move_to_adn_after_scan = @move_to_adn_after_scan
      stop_scan_animation
      @scanned = true
      @return_data = current_return_data
      set_focus(:adn_1) if move_to_adn_after_scan && adn_slot_enabled?(0)
      refresh_display
    end

    def stop_scan_animation
      return unless scan_animation_active?
      @fossil_icon.shader = @fossil_icon_shader_before_scan if @fossil_icon
      @fossil_icon_shader_before_scan = nil
      @scan_animation_started_at = nil
      @scan_animation_last_sweep_index = nil
      @move_to_adn_after_scan = nil
    end

    def apply_scan_shader
      ensure_scan_shader_registered
      @fossil_icon_shader_before_scan = @fossil_icon.shader
      @fossil_icon.shader = Shader.create(SCAN_SHADER_NAME)
      update_scan_shader(0)
    end

    def update_scan_shader(elapsed)
      return unless @fossil_icon&.shader
      sweep_index = (elapsed / scan_sweep_duration).floor
      sweep_progress = elapsed % scan_sweep_duration / scan_sweep_duration
      sweep_progress = 1.0 - sweep_progress if sweep_index.odd?
      @fossil_icon.shader.set_float_uniform("scan_progress", sweep_progress)
      @fossil_icon.shader.set_float_uniform("sweep_height", SCAN_SWEEP_HEIGHT)
      @fossil_icon.shader.set_float_uniform("sweep_strength", SCAN_SWEEP_STRENGTH)
      @fossil_icon.shader.set_float_uniform("sweep_color", SCAN_SWEEP_COLOR)
    end

    def update_scan_sweep_audio(elapsed)
      sweep_index = (elapsed / scan_sweep_duration).floor
      return if sweep_index == @scan_animation_last_sweep_index
      @scan_animation_last_sweep_index = sweep_index
      play_scan_sweep_se
    end

    def scan_sweep_duration
      [SCAN_SWEEP_DURATION.to_f, 0.01].max
    end

    def play_scan_sweep_se
      return if SCAN_SWEEP_SE.nil? || SCAN_SWEEP_SE.to_s.empty?

      Audio.se_play(SCAN_SWEEP_SE, SCAN_SWEEP_SE_VOLUME, SCAN_SWEEP_SE_PITCH)
    end

    def ensure_scan_shader_registered
      return if self.class().instance_variable_get(:@scan_shader_registered)
      Shader.register(SCAN_SHADER_NAME, SCAN_SHADER_FRAGMENT, alpha_process: true)
      self.class().instance_variable_set(:@scan_shader_registered, true)
    end

    def refresh_adn_sprites
      [ADN_1_PANEL, ADN_2_PANEL].each_with_index do |panel, index|
        icon = @adn_icons[index]
        item = @selected_adn_items[index]
        unless item && adn_slot_enabled?(index)
          icon.visible = false
          next
        end

        icon.set_bitmap(item.icon, :icon)
        icon.ox = icon.bitmap.width / 2
        icon.oy = icon.bitmap.height / 2
        icon.zoom = 1.0
        icon.x = panel_center_x(panel)
        icon.y = panel_center_y(panel)
        icon.visible = true
      end
    end

    def refresh_pokemon_sprite
      return @pokemon_sprite.visible = false unless @target_pokemon && @scanned
      @pokemon_sprite.data = @target_pokemon
      @pokemon_sprite.shader = @silhouette_shader
      @pokemon_sprite.src_rect.set(0, 0, @pokemon_sprite.bitmap.width, @pokemon_sprite.bitmap.height)
      visible_bounds = pokemon_visible_bounds(@target_pokemon, @pokemon_sprite.bitmap)
      if visible_bounds
        src_x, src_y, src_width, src_height = visible_bounds
        @pokemon_sprite.ox = src_x + src_width / 2.0
        @pokemon_sprite.oy = src_y + src_height / 2.0
        @pokemon_sprite.zoom = silhouette_zoom_for(src_width, src_height)
      else
        @pokemon_sprite.ox = @pokemon_sprite.bitmap.width / 2.0
        @pokemon_sprite.oy = @pokemon_sprite.bitmap.height / 2.0
        @pokemon_sprite.zoom = silhouette_zoom_for(@pokemon_sprite.bitmap.width, @pokemon_sprite.bitmap.height)
      end

      @pokemon_sprite.x = fossil_display_center_x
      @pokemon_sprite.y = fossil_display_center_y
      @pokemon_sprite.visible = true
    end

    def refresh_texts
      if @selected_fossil_item
        name_line_1, name_line_2 = info_name_lines(@selected_fossil_item.exact_name)
        @info_line_1.text = name_line_1
        @info_line_2.text = name_line_2
        @info_line_3.text = @scanned ? info_status_scanned_line : info_status_waiting_line
        @info_line_4.visible = @scanned
        @info_line_4.text = @scanned ? success_probability_line : ""
      else
        @info_line_1.text = ""
        @info_line_2.text = ""
        @info_line_3.text = info_empty_action_line
        @info_line_4.visible = false
        @info_line_4.text = ""
      end
    end

    def refresh_adn_panel_assets
      refresh_adn_panel_asset(@adn_1_panel_sprite, adn_slot_enabled?(0))
      refresh_adn_panel_asset(@adn_2_panel_sprite, adn_slot_enabled?(1))
    end

    def refresh_adn_panel_asset(sprite, enabled)
      return unless sprite
      asset_name = enabled ? "8 fossile/panel_adn" : "8 fossile/panel_adn_disabled"
      current_asset_name = sprite.instance_variable_get(:@asset_name)
      return if current_asset_name == asset_name
      sprite.set_bitmap(asset_name, :interface)
      sprite.instance_variable_set(:@asset_name, asset_name)
    end

    def refresh_scan_button
      @base_ui.button_texts = button_texts if @base_ui
    end

    def apply_debug_asset_preview_visibility
      @info_panel_sprite.visible = false if @info_panel_sprite
      @adn_1_panel_sprite.visible = false if @adn_1_panel_sprite
      @adn_2_panel_sprite.visible = false if @adn_2_panel_sprite
      @fossil_icon.visible = false if @fossil_icon
      @pokemon_sprite.visible = false if @pokemon_sprite
      @adn_icons&.each { |sprite| sprite.visible = false }
      @selection_arrow.visible = false if @selection_arrow
      @choice_adn_overlay.visible = false if @choice_adn_overlay
      @resurrection_modal_overlay.visible = false if @resurrection_modal_overlay
      @result_modal_overlay.visible = false if @result_modal_overlay
      choice_adn_text_segments.each { |text| text.visible = false }
      resurrection_confirmation_texts.each { |text| text.visible = false }
      result_modal_texts.each { |text| text.visible = false }
      @result_pokemon_sprite.visible = false if @result_pokemon_sprite
      @result_shiny_sprite.visible = false if @result_shiny_sprite
      @texts.visible = false if @texts
    end

    def update_mouse_focus
      return set_focus(:fossil) if mouse_over_panel?(FOSSIL_PANEL)
      return set_focus(:adn_1) if mouse_over_panel?(ADN_1_PANEL) && adn_slot_enabled?(0)
      return set_focus(:adn_2) if mouse_over_panel?(ADN_2_PANEL) && adn_slot_enabled?(1)
    end

    def move_focus(direction)
      current_focus = focus_enabled?(@focus) ? @focus : :fossil
      target_focus = FOCUS_NEIGHBORS.dig(current_focus, direction)
      return play_buzzer_se unless target_focus
      return play_buzzer_se unless focus_enabled?(target_focus)
      set_focus(target_focus)
      play_cursor_se
    end

    def set_focus(value)
      return if @focus == value
      @focus = value
      refresh_focus_visuals
    end

    def refresh_focus_visuals
      @focus = :fossil unless focus_enabled?(@focus)

      refresh_selection_arrow
    end

    def refresh_selection_arrow
      return unless @selection_arrow

      if overlay_active?
        @selection_arrow.visible = false
        return
      end

      panel = selected_focus_panel
      unless panel
        @selection_arrow.visible = false
        return
      end

      @selection_arrow.x = panel[:x] + panel[:width] + SELECT_ARROW_MARGIN + SELECT_ARROW_OFFSET[0]
      @selection_arrow.y = panel[:y] + ((panel[:height] - @selection_arrow.bitmap.height) / 2.0).floor + SELECT_ARROW_OFFSET[1]
      @selection_arrow.visible = true
    end

    def current_return_data
      { fossil: @selected_fossil_symbol, pokemon: @target_pokemon_symbol, adn_1: @selected_adn_symbols[0], adn_2: @selected_adn_symbols[1], success_rate: @scanned ? success_probability : nil, scanned: @scanned }
    end

    def action_adn_slot(index)
      unless adn_slot_enabled?(index)
        disabled_adn_slot_feedback(index)
        return
      end

      unless $bag.contain_item?(:kit_adn)
        play_buzzer_se
        message = $options.language == "fr" ? "Il vous faut un Kit ADN d'abord !" : "You need a DNA Kit before!"
        $scene.display_message(message)
        return
      end

      set_focus(index.zero? ? :adn_1 : :adn_2)
      if @selected_adn_items[index]
        play_decision_se
        open_adn_choice(index)
        nil
      else
        play_decision_se
        select_adn_from_bag(index)
      end
    end

    def adn_choice_active?
      !@adn_choice_index.nil?
    end

    def resurrection_confirmation_active?
      @resurrection_confirmation_active
    end

    def result_modal_active?
      @result_modal_active
    end

    def overlay_active?
      adn_choice_active? || resurrection_confirmation_active? || result_modal_active? || scan_animation_active?
    end

    def open_adn_choice(index)
      @adn_choice_index = index
      refresh_display
    end

    def close_adn_choice
      @adn_choice_index = nil
      refresh_display
    end

    def open_resurrection_confirmation
      @resurrection_confirmation_active = true
      refresh_display
    end

    def close_resurrection_confirmation
      @resurrection_confirmation_active = false
      refresh_display
    end

    def open_resurrection_result(success, pokemon = nil)
      @result_modal_active = true
      @resurrection_result_success = success
      @resurrection_result_pokemon = pokemon
      @result_cry_play_at = nil
      stop_result_shiny_animation
      refresh_display
      play_buzzer_se unless success
      play_resurrection_result_shiny_animation if success && pokemon&.shiny?
      return play_resurrection_result_cry if success && pokemon
    end

    def open_pending_resurrection_result
      return unless @pending_resurrection_result
      result = @pending_resurrection_result
      @pending_resurrection_result = nil
      open_resurrection_result(result[:success], result[:pokemon])
    end

    def close_resurrection_result
      @result_modal_active = false
      @result_cry_play_at = nil
      stop_result_shiny_animation
      close_fossil_machine

      refresh_display
    end

    def replace_adn_choice
      return play_buzzer_se unless adn_choice_active?
      index = @adn_choice_index
      @adn_choice_index = nil
      refresh_display
      play_decision_se
      select_adn_from_bag(index)
    end

    def delete_adn_choice
      return play_buzzer_se unless adn_choice_active?
      index = @adn_choice_index
      @adn_choice_index = nil

      @selected_adn_symbols[index] = nil
      @selected_adn_items[index] = nil
      @selected_adn_slot_indexes[index] = nil
      sync_selected_sequences_dnakit
      @return_data = current_return_data
      play_decision_se
      refresh_display
    end

    def confirm_resurrection
      return play_buzzer_se unless resurrection_confirmation_active?
      @resurrection_confirmation_active = false
      consumed_items = resurrection_consumed_item_symbols
      process_seconds = resurrection_process_seconds
      success_rate = success_probability
      success = resurrection_roll_success?
      consume_resurrection_items(consumed_items)
      $game_switches[RESURRECTION_SWITCH_ID] = true
      register_fossil_resurrection_data(process_seconds, success_rate, success)
      @return_data = current_return_data.merge(resurrection_confirmed: true, consumed_items: consumed_items, process_minutes: process_seconds / 60.0, process_seconds: process_seconds, resurrection_success: success, resurrection_pending: true)

      play_decision_se
      close_fossil_machine
    end

    def consume_resurrection_items(item_symbols)
      item_symbols.each { |item_symbol| $bag.remove_item(item_symbol, 1) }
    end

    def register_fossil_resurrection_data(duration_seconds, success_rate, success)
      PFM.game_state.fossil_resurrection_data = { fossil_symbol: @selected_fossil_symbol, fossil_name: @selected_fossil_item&.exact_name.to_s, pokemon_symbol: @target_pokemon_symbol, success_rate: success_rate, success: success, duration_seconds: duration_seconds, remaining_seconds: duration_seconds, started_at: Time.now.to_i }
    end

    def resurrection_roll_success?
      rand * 100.0 < success_probability
    end

    def give_resurrection_pokemon
      pokemon = PFM::Pokemon.new(@target_pokemon_symbol, 1, false, false)
      added = PFM.game_state.add_pokemon(pokemon)
      return unless added
      post_resurrection_webhook_if_shiny(pokemon)
      pokemon
    end

    def post_resurrection_webhook_if_shiny(pokemon)
      return unless pokemon&.shiny?
      return unless defined?(DiscordWebhooks) && DiscordWebhooks.respond_to?(:post_ressurect)

      DiscordWebhooks.post_ressurect(pokemon)
    end

    def play_resurrection_result_cry
      begin
        return unless @resurrection_result_pokemon && $game_system
        if @resurrection_result_pokemon.shiny?
          Audio.se_play("audio/se/se_shiny")
          @result_cry_play_at = animation_time_reference + RESULT_SHINY_CRY_DELAY
          return
        end
        form = @resurrection_result_pokemon.respond_to?(:form) ? @resurrection_result_pokemon.form.to_i : 0
        $game_system.cry_play(@resurrection_result_pokemon.id, form: form)
      rescue StandardError
        nil
      end
    end

    def update_result_modal_audio
      begin
        return unless @result_cry_play_at && animation_time_reference >= @result_cry_play_at
        return unless @resurrection_result_pokemon && result_modal_active?
        @result_cry_play_at = nil
        form = @resurrection_result_pokemon.respond_to?(:form) ? @resurrection_result_pokemon.form.to_i : 0
        $game_system.cry_play(@resurrection_result_pokemon.id, form: form)
      rescue StandardError
        @result_cry_play_at = nil
      end
    end

    def play_resurrection_result_shiny_animation
      return unless @result_pokemon_sprite&.visible && @result_shiny_sprite&.bitmap
      @result_shiny_animation_started_at = animation_time_reference
      @result_shiny_sprite.x = @result_pokemon_sprite.x
      @result_shiny_sprite.y = @result_pokemon_sprite.y
      refresh_result_shiny_animation_frame(0)
      @result_shiny_sprite.visible = true
    end

    def update_result_shiny_animation
      return unless @result_shiny_animation_started_at && @result_shiny_sprite&.visible
      @result_shiny_sprite.x = @result_pokemon_sprite.x
      @result_shiny_sprite.y = @result_pokemon_sprite.y
      frame_index = ((animation_time_reference - @result_shiny_animation_started_at) / result_shiny_frame_duration).floor
      return stop_result_shiny_animation if frame_index >= RESULT_SHINY_FRAME_COUNT

      refresh_result_shiny_animation_frame(frame_index)
    end

    def focus_enabled?(focus)
      case focus
      when :fossil then return true
      when :adn_1 then return adn_slot_enabled?(0)
      when :adn_2 then adn_slot_enabled?(1)
      else
        return false
      end
    end

    def adn_slot_enabled?(index)
      return false unless @selected_fossil_symbol && @scanned
      return true if index.zero?

      target_pokemon_type_count >= 2
    end

    def target_pokemon_type_count
      return 0 unless @target_pokemon

      [@target_pokemon.type1, @target_pokemon.type2, @target_pokemon.type3].compact.uniq.reject(&:zero?).size
    end

    def target_pokemon_adn_symbols
      return [] unless @target_pokemon

      [@target_pokemon.type1, @target_pokemon.type2, @target_pokemon.type3].compact.uniq.reject(&:zero?).map { |type_id| FossilMachineData.adn_symbol_for_type(data_type(type_id).db_symbol) }.compact
    end

    def correct_dna_count
      selected_symbols = @selected_adn_symbols.compact.uniq
      expected_symbols = target_pokemon_adn_symbols
      selected_symbols.count { |symbol| expected_symbols.include?(symbol) }
    end

    def success_probability
      return 0.0 unless @target_pokemon

      fossil_success_rate(@target_pokemon.rareness, correct_dna_count)
    end

    def resurrection_process_seconds
      return RESURRECTION_REFERENCE_SECONDS unless @target_pokemon

      spawn_time_from_rarity(@target_pokemon.rareness)
    end

    def spawn_time_from_rarity(rarity)
      rarity = rarity.to_f
      return RESURRECTION_REFERENCE_SECONDS if rarity <= 0

      (RESURRECTION_REFERENCE_SECONDS * (RESURRECTION_REFERENCE_RARITY / rarity)).round
    end

    def fossil_success_rate(catch_rate, correct_dna_count)
      base = 10.0
      rarity_bonus = catch_rate.to_f / 255.0 * 80.0
      dna_bonus = case correct_dna_count
      when 1 then 15.0
      when 2 then 40.0
      else
        0.0
      end

      base + rarity_bonus + dna_bonus
    end

    def normalize_item_symbol(item_id)
      begin
        data_item(item_id).db_symbol
      rescue StandardError
        item_id.to_sym if item_id.respond_to?(:to_sym)
        item_id
      end
    end

    def rect_sprite_from(rect, fill_color, border_color, z)
      rect_sprite(rect[:x], rect[:y], rect[:width], rect[:height], fill_color, border_color, z)
    end

    def asset_panel_sprite(rect, asset_name, z)
      sprite = Sprite.new(@viewport)
      sprite.set_bitmap(asset_name, :interface)
      sprite.instance_variable_set(:@asset_name, asset_name)
      sprite.x = rect[:x]
      sprite.y = rect[:y]
      sprite.z = z
      sprite
    end

    def create_choice_adn_overlay
      return unless choice_adn_overlay_available?
      @choice_adn_overlay = Sprite.new(@viewport)
      @choice_adn_overlay.bitmap = RPG::Cache.interface("8 fossile/choice_adn")
      @choice_adn_overlay.x = 0
      @choice_adn_overlay.y = 0
      @choice_adn_overlay.z = OVERLAY_Z
      @choice_adn_overlay.visible = false
    end

    def create_resurrection_modal_overlay
      return unless resurrection_modal_overlay_available?
      @resurrection_modal_overlay = Sprite.new(@viewport)
      @resurrection_modal_overlay.bitmap = RPG::Cache.interface("8 fossile/ressurect_modal")
      @resurrection_modal_overlay.x = 0
      @resurrection_modal_overlay.y = 0
      @resurrection_modal_overlay.z = OVERLAY_Z
      @resurrection_modal_overlay.visible = false
    end

    def create_result_modal_overlay
      return unless result_modal_overlay_available?
      @result_modal_overlay = Sprite.new(@viewport)
      @result_modal_overlay.bitmap = RPG::Cache.interface("8 fossile/result_modal")
      @result_modal_overlay.x = 0
      @result_modal_overlay.y = 0
      @result_modal_overlay.z = OVERLAY_Z
      @result_modal_overlay.visible = false
    end

    def refresh_choice_adn_overlay
      return unless @choice_adn_overlay

      @choice_adn_overlay.visible = adn_choice_active?
    end

    def refresh_resurrection_modal_overlay
      return unless @resurrection_modal_overlay

      @resurrection_modal_overlay.visible = resurrection_confirmation_active?
    end

    def refresh_result_modal_overlay
      return unless @result_modal_overlay

      @result_modal_overlay.visible = result_modal_active?
    end

    def refresh_choice_adn_text
      return if choice_adn_text_segments.empty?
      visible = adn_choice_active? && !@choice_adn_overlay.nil?
      unless visible
        choice_adn_text_segments.each do |text|
          text.visible = false
          text.text = ""
        end
        return
      end

      line_1, prefix, item_name, suffix = adn_choice_prompt_parts
      layout_choice_adn_text_segments(line_1, prefix, item_name, suffix)
    end

    def refresh_resurrection_confirmation_texts
      return if resurrection_confirmation_texts.empty?

      unless resurrection_confirmation_active?
        resurrection_confirmation_texts.each do |text|
          text.visible = false
          text.text = ""
        end
        return
      end

      header, duration_line, items_header, items = resurrection_confirmation_lines
      layout_resurrection_confirmation_texts(header, duration_line, items_header, items)
    end

    def refresh_result_modal_text
      return if result_modal_texts.empty?

      unless result_modal_active?
        result_modal_texts.each do |text|
          text.visible = false
          text.text = ""
        end
        return
      end

      prefix, status = resurrection_result_text_parts
      layout_centered_text_segments(result_modal_text_y, [[@result_modal_prefix, prefix], [@result_modal_status, status]])
      @result_modal_status.fill_color = result_modal_success? ? SUCCESS_TEXT : ACTION_TEXT
    end

    def refresh_result_pokemon_sprite
      unless result_modal_active? && result_modal_success? && @resurrection_result_pokemon
        return @result_pokemon_sprite.visible = false
      end

      @result_pokemon_sprite.data = @resurrection_result_pokemon
      @result_pokemon_sprite.shader = nil
      @result_pokemon_sprite.src_rect.set(0, 0, @result_pokemon_sprite.bitmap.width, @result_pokemon_sprite.bitmap.height)
      visible_bounds = pokemon_visible_bounds(@resurrection_result_pokemon, @result_pokemon_sprite.bitmap)
      if visible_bounds
        src_x, src_y, src_width, src_height = visible_bounds
        @result_pokemon_sprite.ox = src_x + src_width / 2.0
        @result_pokemon_sprite.oy = src_y + src_height / 2.0
        @result_pokemon_sprite.zoom = result_modal_zoom_for(src_width, src_height)
      else
        @result_pokemon_sprite.ox = @result_pokemon_sprite.bitmap.width / 2.0
        @result_pokemon_sprite.oy = @result_pokemon_sprite.bitmap.height / 2.0
        @result_pokemon_sprite.zoom = result_modal_zoom_for(@result_pokemon_sprite.bitmap.width, @result_pokemon_sprite.bitmap.height)
      end

      @result_pokemon_sprite.x = result_modal_sprite_center_x
      @result_pokemon_sprite.y = result_modal_sprite_center_y
      @result_pokemon_sprite.visible = true
    end

    def create_selection_arrow
      @selection_arrow_animation_started_at = animation_time_reference
      @selection_arrow_frame_index = 0
      @selection_arrow = Sprite.new(@viewport)
      @selection_arrow.set_bitmap("8 fossile/selector_arrow", :interface)
      @selection_arrow.z = SELECTOR_Z
      @selection_arrow.visible = false
      refresh_selection_arrow_frame
      refresh_selection_arrow
    end

    def update_selection_arrow_animation
      return unless @selection_arrow&.bitmap
      frame_index = absolute_animation_frame_index(@selection_arrow_animation_started_at, SELECT_ARROW_FRAME_DURATION, SELECT_ARROW_FRAME_COUNT)
      return if frame_index == @selection_arrow_frame_index
      @selection_arrow_frame_index = frame_index
      refresh_selection_arrow_frame
    end

    def refresh_selection_arrow_frame
      return unless @selection_arrow&.bitmap
      frame_width = @selection_arrow.bitmap.width / SELECT_ARROW_FRAME_COUNT
      @selection_arrow.src_rect.set(frame_width * @selection_arrow_frame_index, 0, frame_width, @selection_arrow.bitmap.height)
    end

    def rect_sprite(x, y, width, height, fill_color, border_color, z)
      sprite = Sprite.new(@viewport)
      sprite.bitmap = rect_bitmap(width, height, fill_color, border_color)
      sprite.x = x
      sprite.y = y
      sprite.z = z
      sprite
    end

    def rect_bitmap(width, height, fill_color, border_color)
      bitmap = Bitmap.new(width, height)
      bitmap.fill_rect(0, 0, width, height, border_color)
      bitmap.fill_rect(2, 2, width - 4, height - 4, fill_color)
      bitmap.fill_rect(4, 4, width - 8, 1, PANEL_ACCENT) if width > 12 && height > 12
      bitmap
    end

    def add_flat_text(x, y, width, height, text, align, fill_color, sizeid: 0, z: TEXT_Z)
      text_sprite = @texts.add_text(x, y, width, height, text, align, color: 9, sizeid: sizeid)
      text_sprite.z = z
      text_sprite.fill_color = fill_color
      text_sprite.outline_color = Color.new(0, 0, 0, 0)
      text_sprite.outline_thickness = 0
      text_sprite.draw_shadow = false
      text_sprite
    end

    def panel_center_x(panel)
      panel[:x] + panel[:width] / 2
    end

    def panel_center_y(panel)
      panel[:y] + panel[:height] / 2
    end

    def mouse_over_panel?(panel)
      Mouse.x.between?(panel[:x], panel[:x] + panel[:width]) && Mouse.y.between?(panel[:y], panel[:y] + panel[:height])
    end

    def choice_adn_overlay_available?
      RPG::Cache.interface_exist?("8 fossile/choice_adn")
    end

    def resurrection_modal_overlay_available?
      RPG::Cache.interface_exist?("8 fossile/ressurect_modal")
    end

    def result_modal_overlay_available?
      RPG::Cache.interface_exist?("8 fossile/result_modal")
    end

    def choice_adn_text_segments
      [@adn_choice_text_line_1, @adn_choice_text_prefix, @adn_choice_text_item, @adn_choice_text_suffix].compact
    end

    def resurrection_confirmation_texts
      [@resurrection_confirm_line_1, @resurrection_confirm_line_3, @resurrection_confirm_duration_prefix, @resurrection_confirm_duration_value, @resurrection_confirm_duration_suffix, *@resurrection_confirm_item_prefixes.to_a, *@resurrection_confirm_item_names.to_a].compact
    end

    def result_modal_texts
      [@result_modal_prefix, @result_modal_status].compact
    end

    def layout_resurrection_confirmation_texts(header, duration_parts, items_header, items)
      total_line_count = 4 + items.size
      start_y = ((214 - INFO_TEXT_HEIGHT * total_line_count) / 2.0).floor
      @resurrection_confirm_line_1.x = 0
      @resurrection_confirm_line_1.y = start_y
      @resurrection_confirm_line_1.width = Graphics.width
      @resurrection_confirm_line_1.text = header.to_s
      @resurrection_confirm_line_1.visible = true
      layout_centered_text_segments(start_y + INFO_TEXT_HEIGHT, [[@resurrection_confirm_duration_prefix, duration_parts[0].to_s], [@resurrection_confirm_duration_value, duration_parts[1].to_s], [@resurrection_confirm_duration_suffix, duration_parts[2].to_s]])

      @resurrection_confirm_line_3.x = 0
      @resurrection_confirm_line_3.y = start_y + INFO_TEXT_HEIGHT * 3
      @resurrection_confirm_line_3.width = Graphics.width
      @resurrection_confirm_line_3.text = items_header.to_s
      @resurrection_confirm_line_3.visible = true

      resurrection_confirmation_item_segments.each_with_index do |(prefix_sprite, item_sprite), index|
        item_name = items[index].to_s
        unless items[index]
          prefix_sprite.visible = false
          prefix_sprite.text = ""
          item_sprite.visible = false
          item_sprite.text = ""
          next
        end

        line_y = start_y + INFO_TEXT_HEIGHT * (4 + index)
        prefix_text = "- "
        prefix_width = [prefix_sprite.text_width(prefix_text), 1].max
        item_width = [item_sprite.text_width(item_name), 1].max
        total_width = prefix_width + item_width
        current_x = ((Graphics.width - total_width) / 2.0).floor
        prefix_sprite.x = current_x
        prefix_sprite.y = line_y
        prefix_sprite.width = prefix_width
        prefix_sprite.text = prefix_text
        prefix_sprite.visible = true
        item_sprite.x = current_x + prefix_width
        item_sprite.y = line_y
        item_sprite.width = item_width
        item_sprite.text = item_name
        item_sprite.visible = true
      end
    end

    def resurrection_confirmation_item_segments
      @resurrection_confirm_item_prefixes.to_a.zip(@resurrection_confirm_item_names.to_a)
    end

    def pokemon_visible_bounds(pokemon, fallback_bitmap)
      @pokemon_visible_bounds_cache ||= {}
      cache_key = pokemon_visible_bounds_cache_key(pokemon)
      if @pokemon_visible_bounds_cache.key?(cache_key)
        return @pokemon_visible_bounds_cache[cache_key]
      end

      gif_reader = pokemon.respond_to?(:gif_face) ? pokemon.gif_face : nil
      bounds = gif_reader ? visible_gif_bounds(gif_reader) : visible_bitmap_bounds(fallback_bitmap)
      @pokemon_visible_bounds_cache[cache_key] = bounds
    end

    def pokemon_visible_bounds_cache_key(pokemon)
      [pokemon.db_symbol, pokemon.respond_to?(:form) ? pokemon.form : nil, pokemon.respond_to?(:female?) ? pokemon.female? : nil, pokemon.respond_to?(:shiny?) ? pokemon.shiny? : nil, pokemon.respond_to?(:egg?) ? pokemon.egg? : nil]
    end

    def silhouette_zoom_for(width, height)
      zoom_for_fit(width, height, fossil_display_area_width, fossil_display_area_height)
    end

    def result_modal_zoom_for(width, height)
      zoom_for_fit(width, height, RESULT_SPRITE_SIZE, RESULT_SPRITE_SIZE)
    end

    def zoom_for_fit(width, height, area_width, area_height)
      zoom = 1.0
      while zoom > 0.1 && (width * zoom > area_width || height * zoom > area_height)
        zoom = (zoom - 0.1).round(1)
      end

      zoom
    end

    def fossil_display_area_width
      [FOSSIL_PANEL[:width], 1].max
    end

    def fossil_display_area_height
      [FOSSIL_PANEL[:height], 1].max
    end

    def fossil_display_center_x
      panel_center_x(FOSSIL_PANEL) + FOSSIL_DISPLAY_OFFSET[0]
    end

    def fossil_display_center_y
      panel_center_y(FOSSIL_PANEL) + FOSSIL_DISPLAY_OFFSET[1]
    end

    def result_modal_success?
      @resurrection_result_success == true
    end

    def result_modal_text_y
      return ((RESULT_MODAL_HEIGHT - INFO_TEXT_HEIGHT) / 2.0).floor unless result_modal_success?

      result_modal_content_top_y
    end

    def result_modal_content_top_y
      ((RESULT_MODAL_HEIGHT - result_modal_content_height) / 2.0).floor
    end

    def result_modal_content_height
      INFO_TEXT_HEIGHT + INFO_TEXT_HEIGHT + RESULT_SPRITE_SIZE
    end

    def result_modal_sprite_center_x
      Graphics.width / 2.0
    end

    def result_modal_sprite_center_y
      result_modal_content_top_y + INFO_TEXT_HEIGHT * 2 + RESULT_SPRITE_SIZE / 2.0
    end

    def result_shiny_frame_duration
      RESULT_SHINY_DURATION / RESULT_SHINY_FRAME_COUNT.to_f
    end

    def refresh_result_shiny_animation_frame(frame_index)
      return unless @result_shiny_sprite&.bitmap
      frame_width = @result_shiny_sprite.bitmap.width / RESULT_SHINY_COLUMNS
      frame_height = @result_shiny_sprite.bitmap.height / RESULT_SHINY_ROWS
      column = frame_index % RESULT_SHINY_COLUMNS
      row = frame_index / RESULT_SHINY_COLUMNS
      @result_shiny_sprite.src_rect.set(column * frame_width, row * frame_height, frame_width, frame_height)
    end

    def stop_result_shiny_animation
      @result_shiny_animation_started_at = nil
      @result_shiny_sprite.visible = false if @result_shiny_sprite
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

    def selected_focus_panel
      case @focus
      when :fossil then return FOSSIL_PANEL
      when :adn_1
        return ADN_1_PANEL if adn_slot_enabled?(0)
        return
      when :adn_2 then return ADN_2_PANEL if adn_slot_enabled?(1)
      else
        return
      end
    end

    def layout_choice_adn_text_segments(line_1, prefix, item_name, suffix)
      @adn_choice_text_line_1.text = line_1.to_s
      @adn_choice_text_line_1.visible = !line_1.to_s.empty?

      layout_centered_text_segments(@adn_choice_text_prefix.y, [[@adn_choice_text_prefix, prefix.to_s], [@adn_choice_text_item, item_name.to_s], [@adn_choice_text_suffix, suffix.to_s]])
    end

    def layout_centered_text_segments(y, segments)
      widths = segments.map { |text_sprite, content| [text_sprite.text_width(content), 1].max }

      total_width = widths.sum
      current_x = ((Graphics.width - total_width) / 2.0).floor

      segments.each_with_index do |(text_sprite, content), index|
        text_sprite.x = current_x
        text_sprite.y = y
        text_sprite.width = widths[index]
        text_sprite.text = content
        text_sprite.visible = !content.empty?
        current_x += widths[index]
      end
    end

    def absolute_animation_frame_index(started_at, frame_duration, frame_count)
      return 0 unless started_at && frame_duration.positive? && frame_count.positive?
      elapsed = animation_time_reference - started_at
      (elapsed / frame_duration).floor % frame_count
    end

    def animation_time_reference
      begin
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      rescue StandardError
        Graphics.current_time.to_f
      end
    end

    def language
      return Raty.language_symbol_stp if defined?(Raty) && Raty.respond_to?(:language_symbol_stp)
      :fr
    end

    def choose_fossil_label
      return "FOSSIL ICON" if language == :en
      "ICONE FOSSILE"
    end

    def info_name_lines(text)
      [fossil_name_prefix, text.to_s]
    end

    def info_empty_action_line
      return "Choose a fossil" if language == :en
      "Choisis un fossile"
    end

    def fossil_name_prefix
      return "Fossil:" if language == :en
      "Fossile :"
    end

    def info_status_waiting_line
      return "To scan" if language == :en
      "Scan nécessaire"
    end

    def info_status_scanned_line
      return "DNA Sequencing" if language == :en
      "Séquençage ADN"
    end

    def adn_1_label
      return "DNA 1" if language == :en
      "ADN 1"
    end

    def adn_2_label
      return "DNA 2" if language == :en
      "ADN 2"
    end

    def status_empty_line
      return "Select a fossil sample." if language == :en
      "Sélectionne un fossile."
    end

    def status_waiting_line
      return "Silhouette hidden." if language == :en
      "Silhouette masquée."
    end

    def status_scanned_line
      return "Silhouette revealed." if language == :en
      "Silhouette révelée."
    end

    def scan_label
      return "scan" if language == :en
      "scan"
    end

    def resurrection_button_label
      return "start" if language == :en
      "démarrer"
    end

    def current_action_label
      return resurrection_button_label if @scanned
      scan_label
    end

    def action_button_label
      return unless @selected_fossil_symbol

      current_action_label
    end

    def success_probability_line
      "#{success_probability_prefix}#{format("%.1f%%", success_probability)}"
    end

    def success_probability_prefix
      return "Success: " if language == :en
      "Succès : "
    end

    def adn_choice_prompt_parts
      item_name = @selected_adn_items[@adn_choice_index]&.exact_name.to_s
      return ["What do you want to do", "with ", item_name, "?"] if language == :en

      ["Quelle action veux-tu effectuer", "avec ", item_name, " ?"]
    end

    def resurrection_confirmation_lines
      items = resurrection_consumed_item_names
      header = language == :en ? "Start the resurrection?" : "Es-tu sûr de lancer la résurrection ?"
      duration_value = formatted_resurrection_process_duration
      duration_parts = language == :en ? ["The process will take ", duration_value, "."] : ["Le processus durera ", duration_value, "."]

      items_header = items.size <= 1 ? (language == :en ? "The following item will be consumed:" : "L'objet suivant sera consommé :") : language == :en ? "The following items will be consumed:" : "Les objets suivants seront consommés :"

      [header, duration_parts, items_header, items]
    end

    def formatted_resurrection_process_duration
      self.class().format_duration(resurrection_process_seconds, language)
    end

    def resurrection_consumed_items
      [@selected_fossil_item, *@selected_adn_items.compact].compact
    end

    def resurrection_consumed_item_names
      resurrection_consumed_items.map(&:exact_name)
    end

    def resurrection_consumed_item_symbols
      resurrection_consumed_items.map(&:db_symbol)
    end

    def resurrection_result_text_parts
      if language == :en
        ["Result: ", result_modal_success? ? "Success" : "Failure"]
      else
        ["Résultat : ", result_modal_success? ? "Succès" : "Échec"]
      end
    end

    def missing_fossil_message
      return "Choose a fossil first." if language == :en
      "Choisis d'abord un fossile."
    end

    def missing_fossil_for_adn_message
      return "Choose a fossil before selecting DNA." if language == :en
      "Il faut d'abord un fossile."
    end

    def missing_scan_for_adn_message
      return "Scan the fossil before selecting DNA." if language == :en
      "Il faut d'abord scanner le fossile."
    end

    def invalid_fossil_message
      return "This item is not a compatible fossil." if language == :en
      "Cet objet n'est pas un fossile compatible."
    end

    def invalid_adn_message
      return "This item is not a DNA sequence." if language == :en
      "Cet objet n'est pas une séquence ADN."
    end

    def sync_selected_sequences_dnakit
      PFM.game_state.sync_selected_sequences_dnakit(@selected_adn_symbols, @selected_adn_slot_indexes)
    end

    def clear_selected_sequences_dnakit
      PFM.game_state.clear_sequences
    end

    def extract_adn_choice_data(choice_data)
      return [choice_data, nil] unless choice_data.is_a?(Hash)
      item_id = choice_data[:item_id] || choice_data["item_id"] || choice_data[:db_symbol] || choice_data["db_symbol"] || choice_data[:symbol] || choice_data["symbol"]

      slot_index = choice_data[:slot_index] || choice_data["slot_index"]

      [item_id, slot_index]
    end

    def close_fossil_machine
      clear_selected_sequences_dnakit
      @running = false
    end
  end
end

GamePlay.fossil_machine_ui_class = GamePlay::FossilMachineUI
GamePlay.fossil_bag_class = GamePlay::FossilBag
GamePlay.adn_bag_class = GamePlay::ADNBag

def open_fossil_machine_ui
  GamePlay.open_fossil_machine_ui
end

def fossil_machine_ui
  GamePlay.open_fossil_machine_ui
end
