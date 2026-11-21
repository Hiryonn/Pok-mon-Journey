# Magasins : l'étalage (les objets sur 3 rayons de 6) ; on remplit un panier qui se paye à la caisse
#
# Flèches = objet, A = combien en mettre dans le panier (0 = le reposer), B = quitter l'étalage.
# Le total (« Total ») est celui du panier dans la monnaie de l'étalage ; il défile quand il change.
module GamePlay
  class Etalage < MagasinBase
    SHELF_X = 120
    SHELF_Y = 4
    COLUMNS = 6
    ROWS = 3
    SLOT_W = 31
    ROW_H = 58

    def initialize(shop_id)
      super
      @entries = @shop ? M.entries(@shop).reject { |e| M.pokemon?(e) }.first(COLUMNS * ROWS) : []
      @index = 0
    end

    def update_inputs
      return false unless @shop

      case @state
      when :message then update_message_inputs
      when :quantity then update_quantity_inputs
      else update_shelf_inputs
      end
    end

    def update_mouse(_moved)
      return false unless @shop

      case @state
      when :quantity then update_quantity_mouse
      when :browse then update_shelf_mouse
      else true
      end
    end

    private

    def current
      return @entries[@index]
    end

    def create_graphics
      super
      return unless @shop

      @money = UI::Magasin::CounterWindow.new(@viewport, 4, 4, M.t('Total', 'Bill'), ->(v) { amount(v) })
      @money.set(bill, instant: true)
      @counter = UI::Magasin::CounterWindow.new(@viewport, 4, 150, M.t('Panier', 'In basket'), ->(v) { M.number(v) })
      @counter.set(M.basket_count, instant: true)
      create_shelf
      create_info
      refresh
    end

    # Total du panier dans la monnaie de l'étalage
    def bill
      return M.basket_totals[M.fetch(@currency, :id).to_s].to_i
    end

    def slot_position(index)
      col = index % COLUMNS
      row = index / COLUMNS
      return [SHELF_X + 5 + col * SLOT_W, SHELF_Y + row * ROW_H + 14]
    end

    def create_shelf
      @shelf = stack(SHELF_X, SHELF_Y)
      @shelf.add_sprite(0, 0, M.file('shelf'))
      @icons = @entries.each_with_index.map do |entry, i|
        x, y = slot_position(i)
        sprite = @shelf.add_sprite(0, 0, UI::SpriteStack::NO_INITIAL_IMAGE)
        M.draw_icon(sprite, entry, x, y)
        sprite
      end
      @cursor = @shelf.add_sprite(0, 0, M.file('shelf_cursor'))
      @shelf.with_font(SMALL) { @tag = @shelf.add_text(0, 0, 34, 13, '', 1, color: WHITE) }
      @empty = @shelf.add_text(0, 80, 196, 16, M.t('Étalage vide', 'Empty shelf'), 1, color: DARK)
      @empty.visible = @entries.empty?
    end

    def refresh
      entry = current
      @cursor.visible = @tag.visible = !entry.nil?
      @icons.each_with_index { |sprite, i| sprite.opacity = M.remaining(@shop, @entries[i]) == 0 ? 90 : 255 }
      if entry
        x, y = slot_position(@index)
        @cursor.set_position(x - 1, y - 4)
        @tag.x = x - 1
        @tag.y = y + 33 - Text::Util::FOY
        left = M.remaining(@shop, entry)
        @tag.text = left == 0 ? M.t('Épuisé', 'Out') : M.number(M.price(@shop, entry))
      end
      refresh_info
    end

    def refresh_info
      entry = current
      return @info.show(nil, M.t('Il n\'y a rien sur cet étalage.', 'There is nothing on this shelf.')) unless entry

      text = "#{M.entry_name(entry)} : #{M.entry_descr(entry)}"
      in_basket = M.basket_quantity(@shop, entry)
      text = "#{M.t("Dans le panier : #{in_basket}.", "In basket: #{in_basket}.")} #{text}" if in_basket > 0
      @info.show(entry, text)
    end

    def update_shelf_inputs
      if Input.trigger?(:B)
        play_cancel_se
        @running = false
      elsif @entries.empty?
        return false
      elsif Input.repeat?(:RIGHT)
        move(1, 0)
      elsif Input.repeat?(:LEFT)
        move(-1, 0)
      elsif Input.repeat?(:DOWN)
        move(0, 1)
      elsif Input.repeat?(:UP)
        move(0, -1)
      elsif Input.trigger?(:A)
        pick(current)
      end
      return false
    end

    def update_shelf_mouse
      if Mouse.trigger?(:RIGHT)
        play_cancel_se
        @running = false
        return false
      end
      return true unless Mouse.trigger?(:LEFT)

      index = @entries.each_index.find do |i|
        x, y = slot_position(i)
        Mouse.x.between?(x, x + 31) && Mouse.y.between?(y - 4, y + 44)
      end
      return true unless index

      index == @index ? pick(current) : select(index)
      return false
    end

    def move(dx, dy)
      col = @index % COLUMNS
      row = @index / COLUMNS
      rows = (@entries.size + COLUMNS - 1) / COLUMNS
      if dx != 0
        count = [@entries.size - row * COLUMNS, COLUMNS].min
        col = (col + dx) % count
      else
        row = (row + dy) % rows
        col = [col, [@entries.size - row * COLUMNS, 1].max - 1].min
      end
      select(row * COLUMNS + col)
    end

    def select(index)
      return if index == @index

      play_cursor_se
      @index = index
      refresh
    end

    # Combien en mettre dans le panier ?
    def pick(entry)
      name = M.entry_name(entry)
      left = M.remaining(@shop, entry)
      have = M.basket_quantity(@shop, entry)
      if left == 0
        play_buzzer_se
        return show_message(M.t("Il n'y a plus de #{name} sur l'étalage.", "There are no more #{name} on the shelf."), entry)
      end
      max = max_for(entry)
      if max <= 0 && have == 0
        play_buzzer_se
        return show_message(M.t("Tu n'as pas assez d'argent pour mettre #{name} dans ton panier.",
                                "You don't have enough money to add #{name} to your basket."), entry)
      end
      play_decision_se
      question = if have > 0
                   M.t("Tu as #{have} #{name} dans ton panier. Combien en veux-tu ?", "You have #{have} #{name} in your basket. How many do you want?")
                 else
                   M.t("Combien de #{name} mettre dans ton panier ?", "How many #{name} do you want in your basket?")
                 end
      @info.show(entry, question)
      open_quantity(entry, have > 0 ? have : 1, 0, max) { |qty| set_quantity(entry, qty) unless qty.nil? || qty == have; refresh_info }
    end

    # Quantité maximale : argent (moins le reste du panier), stock, place dans le sac
    def max_for(entry)
      unit = M.price(@shop, entry)
      others = M.basket_totals([M.fetch(@shop, :id).to_s, M.entry_key(entry)])[M.fetch(@currency, :id).to_s].to_i
      max = unit > 0 ? (M.funds(@currency) - others) / unit : 99
      left = M.remaining(@shop, entry)
      max = [max, left].min if left
      max = [max, M::MAX_ITEMS - $bag.item_quantity(M.fetch(entry, :item).to_s.to_sym)].min
      return [[max, 99].min, 0].max
    end

    def set_quantity(entry, qty)
      M.set_basket(@shop, entry, qty)
      @money.set(bill)
      @counter.set(M.basket_count)
      qty > 0 ? play_buy_se : play_cancel_se
      refresh
    end
  end
end
