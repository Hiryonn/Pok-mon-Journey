# PokeSmart : appli Amis (réseau social)
#
# Liste des amis rencontrés (pastille rouge = message non lu) ; A : ouvrir la conversation.
# Conversation : haut / bas pour passer d'un message à l'autre, gauche / droite pour choisir un bouton
# (« Quête » si le message propose une quête, « Défier » si l'ami est un dresseur assez proche), A pour valider,
# B pour revenir. Un défi range le téléphone et lance le combat contre le dresseur de l'ami.
module UI
  module PokeSmart
    # Textes de l'appli Amis : [français, anglais]
    FRIENDS_TEXTS = {
      empty: ['Aucun contact', 'No contacts'],
      no_message: ['Pas encore de message.', 'No message yet.'],
      quest: ['Quête', 'Quest'],
      battle: ['Défier', 'Battle'],
      rematch: ['Revanche', 'Rematch'],
      duel: ['Cartes', 'Cards'],
      quest_ok: ['Quête acceptée !', 'Quest accepted!'],
      quest_ko: ['Impossible', 'Not possible']
    }

    module_function

    # @param key [Symbol]
    # @return [String]
    def friends_text(key)
      return FRIENDS_TEXTS[key][french? ? 0 : 1]
    end

    # Apparence d'un contact : première image (en haut à gauche) de son personnage
    # @param sprite [Sprite]
    # @param character [String, nil] image de graphics/characters
    # @param size [Integer] taille maximale affichée (l'image est réduite si elle est plus grande)
    def draw_avatar(sprite, character, size)
      sprite.visible = false
      return if character.to_s.empty?

      sprite.set_bitmap(character.to_s, :character)
      fw = sprite.bitmap.width / 4
      fh = sprite.bitmap.height / 4
      sprite.src_rect.set(0, 0, fw, fh)
      zoom = [size.to_f / [fw, fh].max, 1.0].min
      sprite.zoom = zoom
      # centré dans le carré
      sprite.x += ((size - fw * zoom) / 2).round
      sprite.y += ((size - fh * zoom) / 2).round
      sprite.visible = true
    rescue StandardError
      sprite.visible = false
    end

    # Liste des amis
    class FriendList < SpriteStack
      ROW_WIDTH = 92
      ROW_SPACING = 22
      # @return [Integer]
      attr_reader :index
      # @return [Array<Hash>]
      attr_reader :friends

      # @param viewport [Viewport]
      # @param phone [Phone]
      # @param index [Integer]
      def initialize(viewport, phone, index)
        theme = phone.theme
        sx, sy, sw, sh = theme[:screen]
        top = theme[:grid][1]
        super(viewport, phone.x + sx + (sw - ROW_WIDTH) / 2, phone.y + top, default_cache: :interface)
        @friends = Friends.friends
        @index = index.clamp(0, [@friends.size - 1, 0].max)
        if @friends.empty?
          add_text(0, 2, ROW_WIDTH, 16, PokeSmart.friends_text(:empty), 1, color: phone.text_color)
          return
        end
        visible = [(sy + sh - top - 4) / ROW_SPACING, 1].max
        @first = (@index - visible + 1).clamp(0, [@friends.size - visible, 0].max)
        @friends[@first, visible].each_with_index do |friend, i|
          row = @first + i
          y = i * ROW_SPACING
          add_sprite(0, y, PokeSmart.file(row == @index ? 'choice_selected' : 'choice'))
          PokeSmart.draw_avatar(add_sprite(2, y + 1, nil), friend[:character], 16)
          add_text(21, y + 2, 60, 16, Friends.name(friend[:id]), 0, color: DARK)
          add_sprite(83, y + 5, PokeSmart.file('notif_dot')) if Friends.unread(friend[:id]) > 0
        end
        @shown = [visible, @friends.size - @first].min
      end

      # @return [Hash, nil] ami sélectionné
      def friend
        return @friends[@index]
      end

      # @return [Integer, nil] ligne sous la souris
      def hovered_row
        return nil if @friends.empty?

        mx = Mouse.x - x
        my = Mouse.y - y
        return nil unless mx.between?(0, ROW_WIDTH - 1) && my >= 0

        row = my / ROW_SPACING
        return row < @shown && my % ROW_SPACING < 18 ? @first + row : nil
      end
    end

    # Conversation avec un ami
    class Chat < SpriteStack
      # @return [Integer] message affiché (dans la boîte de réception)
      attr_reader :page
      # @return [Integer] bouton sélectionné
      attr_reader :button
      # @return [Array<Symbol>] boutons disponibles (:quest, :battle)
      attr_reader :actions

      # @param viewport [Viewport]
      # @param phone [Phone]
      # @param friend [Hash] contact
      # @param page [Integer, nil] message à afficher (nil = le premier non lu, sinon le dernier)
      # @param button [Integer]
      def initialize(viewport, phone, friend, page = nil, button = 0)
        theme = phone.theme
        sx, _sy, sw = theme[:screen]
        super(viewport, phone.x + sx + (sw - 96) / 2, phone.y + theme[:grid][1] - 2, default_cache: :interface)
        @friend = friend
        @id = friend[:id]
        @messages = Friends.inbox(@id)
        @page = page || first_unread
        @page = @page.clamp(0, [@messages.size - 1, 0].max)
        Friends.mark_read(@id, message[:id]) if message
        create_header(phone)
        create_message
        create_buttons(button)
      end

      # @return [Hash, nil] message affiché
      def message
        return @messages[@page]
      end

      # @return [Integer] nombre de messages
      def count
        return @messages.size
      end

      # @return [Symbol, nil] action du bouton sélectionné
      def action
        return @actions[@button]
      end

      private

      def first_unread
        index = @messages.index { |m| !Friends.read?(@id, m[:id]) }
        return index || [@messages.size - 1, 0].max
      end

      def create_header(phone)
        PokeSmart.draw_avatar(add_sprite(0, -4, nil), @friend[:character], 32)
        hearts = Friends.hearts(@id)
        5.times { |i| add_sprite(34 + i * 9, 12, PokeSmart.file(i < hearts ? 'heart_on' : 'heart_off')) }
        add_text(78, 8, 18, 14, "#{@messages.empty? ? 0 : @page + 1}/#{@messages.size}", 2, color: phone.text_color)
      end

      def create_message
        add_sprite(0, 30, PokeSmart.file('message_panel'))
        text = message ? Friends.text(message[:text_row]).to_s : PokeSmart.friends_text(:no_message)
        body = nil
        with_font(20) { body = add_text(4, 32, 88, 11, '', 0, color: DARK) }
        body.multiline_text = text if body.respond_to?(:multiline_text=)
        body.text = text unless body.respond_to?(:multiline_text=)
      end

      def create_buttons(button)
        @actions = []
        @actions << :quest if Friends.quest_offer(@id, message)
        @actions << :battle if Friends.can_battle?(@id)
        @actions << :duel if Friends.can_duel?(@id)
        @button = button.clamp(0, [@actions.size - 1, 0].max)
        width = @actions.size > 2 ? 30 : 46
        step = @actions.size > 2 ? 33 : 50
        @actions.each_with_index do |act, i|
          x = i * step
          back = add_sprite(x, 100, PokeSmart.file(i == @button ? 'button_small_selected' : 'button_small'))
          back.zoom_x = width / 46.0 if width != 46 && back.respond_to?(:zoom_x=)
          label = act == :battle && Friends.rematch?(@id) ? :rematch : act
          add_text(x, 102, width, 14, PokeSmart.friends_text(label), 1, color: DARK)
        end
      end
    end
  end
end

module GamePlay
  class Menu
    module SmartStyle
      public

      # Appli Amis : liste des amis rencontrés
      def open_friends
        UI::PokeSmart::Friends.deliver
        @friend_index = 0
        show_friend_list
      end

      # Ferme l'appli Amis
      def close_friends
        @friends_view&.dispose
        @friends_view = nil
        @friends_mode = nil
        rebuild_phone # pastille des messages non lus
      end

      private

      # @param index [Integer]
      def show_friend_list(index = @friend_index || 0)
        @friends_view&.dispose
        @friends_mode = :list
        @friends_view = UI::PokeSmart::FriendList.new(@viewport, @phone, index)
        hide_home_buttons
        @phone.title = @buttons[@index]&.name
      end

      # @param friend [Hash]
      # @param page [Integer, nil]
      # @param button [Integer]
      def show_chat(friend, page = nil, button = 0)
        @friends_view&.dispose
        @friends_mode = :chat
        @chat_friend = friend
        @friends_view = UI::PokeSmart::Chat.new(@viewport, @phone, friend, page, button)
        @phone.title = UI::PokeSmart::Friends.name(friend[:id])
      end

      # Liste : haut / bas, A pour ouvrir, B pour fermer ; conversation : haut / bas (messages),
      # gauche / droite (boutons), A (bouton), B (retour à la liste)
      def update_friends_inputs
        view = @friends_view
        if @friends_mode == :list
          if Input.repeat?(:UP) || Input.repeat?(:DOWN)
            return false if view.friends.size < 2

            play_cursor_se
            @friend_index = (view.index + (Input.repeat?(:UP) ? -1 : 1)) % view.friends.size
            show_friend_list(@friend_index)
          elsif Input.trigger?(:A)
            return false unless view.friend

            play_decision_se
            show_chat(view.friend)
          elsif Input.trigger?(:B)
            play_cancel_se
            close_friends
          else
            return true
          end
        elsif Input.repeat?(:UP) || Input.repeat?(:DOWN)
          target = (view.page + (Input.repeat?(:UP) ? -1 : 1)).clamp(0, [view.count - 1, 0].max)
          return false if target == view.page

          play_cursor_se
          show_chat(@chat_friend, target)
        elsif Input.repeat?(:LEFT) || Input.repeat?(:RIGHT)
          return false if view.actions.size < 2

          play_cursor_se
          show_chat(@chat_friend, view.page, (view.button + 1) % view.actions.size)
        elsif Input.trigger?(:A)
          friends_action
        elsif Input.trigger?(:B)
          play_cancel_se
          show_friend_list
        else
          return true
        end
        return false
      end

      # Bouton de la conversation : accepter la quête ou défier l'ami
      def friends_action
        view = @friends_view
        friends = UI::PokeSmart::Friends
        case view.action
        when :quest
          if friends.accept_quest(@chat_friend[:id], view.message)
            play_decision_se
            show_chat(@chat_friend, view.page)
            @phone.title = UI::PokeSmart.friends_text(:quest_ok)
          else
            play_buzzer_se if respond_to?(:play_buzzer_se, true)
            @phone.title = UI::PokeSmart.friends_text(:quest_ko)
          end
        when :duel
          play_decision_se
          @call_skill_process = friends.duel_proc(@chat_friend[:id])
          @friends_view&.dispose
          @friends_view = nil
          @friends_mode = nil
          @quiting = true
        when :battle
          play_decision_se
          @call_skill_process = friends.battle_proc(@chat_friend[:id])
          @friends_view&.dispose
          @friends_view = nil
          @friends_mode = nil
          @quiting = true
        end
      end

      # Souris : clic sur un ami pour l'ouvrir, clic droit pour revenir
      def update_friends_mouse
        if Mouse.trigger?(:RIGHT)
          play_cancel_se
          @friends_mode == :chat ? show_friend_list : close_friends
        elsif Mouse.trigger?(:LEFT) && @friends_mode == :list && (row = @friends_view.hovered_row)
          play_decision_se
          @friend_index = row
          show_chat(@friends_view.friends[row])
        elsif Mouse.trigger?(:LEFT) && @friends_mode == :chat && @friends_view.action
          friends_action
        end
        return false
      end
    end

    if UI::PokeSmart::ENABLED
      register_button(:open_friends) { UI::PokeSmart::FRIENDS_APP } unless ACTION_LIST.include?(:open_friends)
    end
  end
end
