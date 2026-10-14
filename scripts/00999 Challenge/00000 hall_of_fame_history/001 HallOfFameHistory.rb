#######################################################################
# Hall of Fame History
#
# Author : Raty
# License : MIT
#
# Commands:
#   hall_of_fame_last
#   hall_of_fame_history
#
# Navigation in hall_of_fame_history:
#   left  = newer victory
#   right = older victory
#######################################################################

module GamePlay
  module HallOfFameHistory
    class << self
      attr_accessor :open_mode, :victories, :selected_victory
      attr_accessor :skip_next_registration, :text_window_offset_enabled
    end

    def self.history
      PFM.game_state.hall_of_fame&.player_victory || []
    end

    def self.sorted_history
      history.compact.sort_by { |entry| -entry_date_sort_value(entry) }
    end

    def self.latest_victory
      sorted_history.first
    end

    def self.entry_value(entry, key)
      return nil unless entry

      entry[key] || entry[key.to_s]
    end

    def self.entry_date_sort_value(entry)
      entry_date = entry_value(entry, :entry_date)
      return entry_date.to_i if entry_date.respond_to?(:to_i)

      0
    end

    def self.prepare_open(mode, victories: nil, selected_victory: nil)
      self.open_mode = mode
      self.victories = victories
      self.selected_victory = selected_victory
    end

    def self.clear_open_request
      self.open_mode = nil
      self.victories = nil
      self.selected_victory = nil
    end

    def initialize(filename_bgm = DEFAULT_BGM, context_of_victory = :league)
      @hall_of_fame_history_mode = HallOfFameHistory.open_mode
      @hall_of_fame_history_victories = HallOfFameHistory.victories
      @hall_of_fame_history_selected_victory = HallOfFameHistory.selected_victory
      HallOfFameHistory.clear_open_request

      if hall_of_fame_history_replay_mode?
        @hall_of_fame_history_original_actors = $actors
        $actors = hall_of_fame_history_display_team
      end

      HallOfFameHistory.skip_next_registration = hall_of_fame_history_replay_mode?
      super
    ensure
      HallOfFameHistory.skip_next_registration = false
    end

    def create_graphics
      HallOfFameHistory.text_window_offset_enabled = hall_of_fame_history_navigation_mode?
      super

      if hall_of_fame_history_last_mode?
        setup_hall_of_fame_history_final
      elsif hall_of_fame_history_navigation_mode?
        create_hall_of_fame_history_controls
        setup_hall_of_fame_history_navigation
        refresh_hall_of_fame_history_controls
      end
    ensure
      HallOfFameHistory.text_window_offset_enabled = false
    end

    def update_graphics
      super
      refresh_hall_of_fame_history_controls if hall_of_fame_history_navigation_active?
    end

    def update_inputs
      return false if hall_of_fame_history_navigation_active? && handle_hall_of_fame_history_navigation_input

      super
    end

    def update_mouse(_moved)
      return unless hall_of_fame_history_navigation_mode?

      update_mouse_ctrl_buttons(@hall_of_fame_history_buttons, hall_of_fame_history_mouse_actions)
      return false
    end

    def dispose
      dispose_hall_of_fame_history_controls
      super
    ensure
      $actors = @hall_of_fame_history_original_actors if @hall_of_fame_history_original_actors
    end

    private

    def hall_of_fame_history_replay_mode?
      hall_of_fame_history_last_mode? || hall_of_fame_history_navigation_mode?
    end

    def hall_of_fame_history_last_mode?
      @hall_of_fame_history_mode == :last
    end

    def hall_of_fame_history_navigation_mode?
      @hall_of_fame_history_mode == :history
    end

    def hall_of_fame_history_display_team
      team = HallOfFameHistory.entry_value(@hall_of_fame_history_selected_victory, :team)
      team ||= HallOfFameHistory.entry_value(@hall_of_fame_history_victories&.first, :team)
      team || @hall_of_fame_history_original_actors || []
    end

    def setup_hall_of_fame_history_final
      @animation_state = 3
      @anim_count = 0
      @parallel_update = false
      hide_hall_of_fame_intermediate_phase_elements
      setup_hall_of_fame_final_phase_elements
      apply_hall_of_fame_history_texts(show_entry_date: true)
    end

    def setup_hall_of_fame_history_navigation
      @hall_of_fame_history_index = 0
      @hall_of_fame_history_selected_victory = current_hall_of_fame_history_victory
      setup_hall_of_fame_history_final
      apply_current_hall_of_fame_history_victory
    end

    def hide_hall_of_fame_intermediate_phase_elements
      @type_background&.type_backgrounds&.each { |sprite| sprite.visible = false }
      @type_background&.type_foregrounds&.each { |sprite| sprite.visible = false }
      @pkm_battler_stack&.battlebacks&.each { |sprite| sprite.visible = false }
      @pkm_battler_stack&.battlefronts&.each { |sprite| sprite.visible = false }
      @pkm_battler_stack&.withcolorbacks&.each { |sprite| sprite.visible = false }
      @pkm_text_boxes&.each { |box| box.visible = false }
      @congrats_text_boxes&.each { |box| box.visible = false }
      @graveyard_stack&.sprites&.each { |sprite| sprite.visible = false }
      @graveyard_stack&.text_boxes&.each { |box| box.visible = false }
    end

    def setup_hall_of_fame_final_phase_elements
      @ball.opacity = 255 if @ball

      if @party_battler
        @party_battler.trainer_battler.set_position(@party_battler.trainer_battler.x, UI::Hall_of_Fame::Party_Battler_Stack::Y_TRAINER)
        @party_battler.pokemon_arr.each_with_index do |sprite, index|
          sprite.set_position(
            UI::Hall_of_Fame::Party_Battler_Stack::X_PARTY[index],
            UI::Hall_of_Fame::Party_Battler_Stack::Y_PARTY[index / 2]
          )
        end
      end

      if @league_champ_box
        @league_champ_box.y = @league_champ_box.y_final
        @league_champ_box.text.opacity = 255
      end

      if @trainer_infos_box
        @trainer_infos_box.y = @trainer_infos_box.y_final
        @trainer_infos_box.name.opacity = 255
        @trainer_infos_box.id_no.opacity = 255
        @trainer_infos_box.play_time.opacity = 255
      end
    end

    def apply_current_hall_of_fame_history_victory
      victory = current_hall_of_fame_history_victory
      return unless victory

      @hall_of_fame_history_selected_victory = victory
      apply_hall_of_fame_history_team(HallOfFameHistory.entry_value(victory, :team) || [])
      apply_hall_of_fame_history_texts(show_entry_date: true)
      refresh_hall_of_fame_history_controls
    end

    def apply_hall_of_fame_history_team(team)
      return unless @party_battler

      ensure_hall_of_fame_party_capacity(6)
      @party_battler.pokemon_arr.each_with_index do |sprite, index|
        sprite.set_position(
          UI::Hall_of_Fame::Party_Battler_Stack::X_PARTY[index],
          UI::Hall_of_Fame::Party_Battler_Stack::Y_PARTY[index / 2]
        )
        sprite.data = team[index]
      end
    end

    def ensure_hall_of_fame_party_capacity(size)
      while @party_battler.pokemon_arr.size < size
        index = @party_battler.pokemon_arr.size
        sprite = @party_battler.add_sprite(
          UI::Hall_of_Fame::Party_Battler_Stack::X_PARTY[index],
          UI::Hall_of_Fame::Party_Battler_Stack::Y_PARTY[index / 2],
          nil,
          type: UI::PokemonFaceSprite
        )
        @party_battler.pokemon_arr << sprite
      end
    end

    def apply_hall_of_fame_history_texts(show_entry_date: false)
      victory = @hall_of_fame_history_selected_victory
      return unless victory

      if show_entry_date && @league_champ_box
        @league_champ_box.text.text = format_hall_of_fame_history_entry_date(HallOfFameHistory.entry_value(victory, :entry_date))
      end

      play_time = HallOfFameHistory.entry_value(victory, :play_time)
      @trainer_infos_box.play_time.text = play_time.to_s if play_time && @trainer_infos_box
    end

    def create_hall_of_fame_history_controls
      @hall_of_fame_history_bar = Sprite.new(@viewport)
      @hall_of_fame_history_bar.set_bitmap('tcard/button_background', :interface)
      @hall_of_fame_history_bar.set_position(0, 214)
      @hall_of_fame_history_bar.z = 10_000

      @hall_of_fame_history_buttons = [
        UI::Hall_of_Fame::History_Control_Button.new(@viewport, 0, :LEFT),
        UI::Hall_of_Fame::History_Control_Button.new(@viewport, 1, :RIGHT)
      ]
      @hall_of_fame_history_buttons[0].text = hall_of_fame_previous_button_text
      @hall_of_fame_history_buttons[1].text = hall_of_fame_next_button_text
      @hall_of_fame_history_buttons.each { |button| button.z = 10_001 }

      @hall_of_fame_history_counter = Text.new(0, @viewport, 246, 13, 52, 16, '', 2, 1, 20)
      @hall_of_fame_history_counter.z = 10_001
      @hall_of_fame_history_counter.outline_thickness = 0
      @hall_of_fame_history_counter.draw_shadow = false
    end

    def refresh_hall_of_fame_history_controls
      return unless @hall_of_fame_history_buttons

      @hall_of_fame_history_buttons[0].opacity = can_show_previous_hall_of_fame_history_victory? ? 255 : 128
      @hall_of_fame_history_buttons[1].opacity = can_show_next_hall_of_fame_history_victory? ? 255 : 128
      @hall_of_fame_history_counter.text = hall_of_fame_history_counter_text if @hall_of_fame_history_counter
    end

    def hall_of_fame_history_counter_text
      format('%<index>d/%<count>d', index: @hall_of_fame_history_index + 1, count: @hall_of_fame_history_victories.size)
    end

    def handle_hall_of_fame_history_navigation_input
      if Input.trigger?(:LEFT)
        show_previous_hall_of_fame_history_victory
        return true
      elsif Input.trigger?(:RIGHT)
        show_next_hall_of_fame_history_victory
        return true
      end

      return false
    end

    def hall_of_fame_history_mouse_actions
      return [nil, nil] unless hall_of_fame_history_navigation_active?

      [
        (can_show_previous_hall_of_fame_history_victory? ? :show_previous_hall_of_fame_history_victory : nil),
        (can_show_next_hall_of_fame_history_victory? ? :show_next_hall_of_fame_history_victory : nil)
      ]
    end

    def show_previous_hall_of_fame_history_victory
      return unless can_show_previous_hall_of_fame_history_victory?

      @hall_of_fame_history_index -= 1
      apply_current_hall_of_fame_history_victory
    end

    def show_next_hall_of_fame_history_victory
      return unless can_show_next_hall_of_fame_history_victory?

      @hall_of_fame_history_index += 1
      apply_current_hall_of_fame_history_victory
    end

    def can_show_previous_hall_of_fame_history_victory?
      hall_of_fame_history_navigation_active? && @hall_of_fame_history_index.positive?
    end

    def can_show_next_hall_of_fame_history_victory?
      hall_of_fame_history_navigation_active? && @hall_of_fame_history_index < (@hall_of_fame_history_victories.size - 1)
    end

    def hall_of_fame_history_navigation_active?
      hall_of_fame_history_navigation_mode? && @animation_state.to_i == 3 && @hall_of_fame_history_victories&.size.to_i > 0
    end

    def current_hall_of_fame_history_victory
      @hall_of_fame_history_victories&.dig(@hall_of_fame_history_index)
    end

    def format_hall_of_fame_history_entry_date(entry_date)
      return '' unless entry_date.respond_to?(:strftime)

      return entry_date.strftime('%I:%M %p %m/%d/%y').sub(/\A0/, '') if hall_of_fame_english_language?

      entry_date.strftime('%H:%M %d/%m/%y')
    end

    def hall_of_fame_previous_button_text
      hall_of_fame_english_language? ? ': previous' : ': précédent'
    end

    def hall_of_fame_next_button_text
      hall_of_fame_english_language? ? ': next' : ': suivant'
    end

    def hall_of_fame_english_language?
      $options&.language == 'en'
    end

    def dispose_hall_of_fame_history_controls
      dispose_hall_of_fame_object(@hall_of_fame_history_bar)
      @hall_of_fame_history_bar = nil

      @hall_of_fame_history_buttons&.each { |button| dispose_hall_of_fame_object(button) }
      @hall_of_fame_history_buttons = nil

      dispose_hall_of_fame_object(@hall_of_fame_history_counter)
      @hall_of_fame_history_counter = nil
    end

    def dispose_hall_of_fame_object(object)
      return unless object

      if object.respond_to?(:disposed?)
        object.dispose unless object.disposed?
      else
        object.dispose
      end
    end
  end

  Hall_of_Fame.prepend(HallOfFameHistory)
end

module PFM
  class Hall_of_Fame
    module HistoryRegisterGuard
      def register_victory(mode = :league)
        return if GamePlay::HallOfFameHistory.skip_next_registration

        super
      end
    end

    prepend HistoryRegisterGuard
  end
end

module UI
  module Hall_of_Fame
    class History_Control_Button < UI::GenericBase::ControlButton
      private

      def text_rect
        return [14, 3, 62, 13]
      end
    end

    module TrainerInfosTextBoxHistoryOffset
      def initialize(*args)
        @hall_of_fame_history_text_window_offset_enabled = GamePlay::HallOfFameHistory.text_window_offset_enabled
        super
      end

      def initial_coordinates
        x, y = super
        return [x, y] unless @hall_of_fame_history_text_window_offset_enabled

        [x, y - 16]
      end

      def y_final
        value = super
        return value unless @hall_of_fame_history_text_window_offset_enabled

        value - 16
      end

      def play_time_coordinates
        return super unless @hall_of_fame_history_text_window_offset_enabled

        [168, 5, 90, 16]
      end
    end

    Trainer_Infos_Text_Box.prepend(TrainerInfosTextBoxHistoryOffset)
  end
end

def hall_of_fame_last(filename_bgm = 'audio/bgm/Hall-of-Fame')
  victory = GamePlay::HallOfFameHistory.latest_victory
  return false unless victory

  GamePlay::HallOfFameHistory.prepare_open(:last, selected_victory: victory)
  GamePlay.open_hall_of_fame(filename_bgm, GamePlay::HallOfFameHistory.entry_value(victory, :mode) || :league)
  return true
end

def hall_of_fame_history(filename_bgm = 'audio/bgm/Hall-of-Fame')
  victories = GamePlay::HallOfFameHistory.sorted_history
  return false if victories.empty?

  GamePlay::HallOfFameHistory.prepare_open(:history, victories: victories, selected_victory: victories.first)
  GamePlay.open_hall_of_fame(filename_bgm, GamePlay::HallOfFameHistory.entry_value(victories.first, :mode) || :league)
  return true
end
