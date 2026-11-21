# Magasins : le comptoir (liste des articles par catégorie, achat, vente au vendeur)
#
# Menu : Acheter / Vendre / Quitter. Liste : haut / bas = article, gauche / droite = catégorie (page), A = acheter,
# B = retour au menu. Quantité : haut / bas = 1, gauche / droite = 10. Souris : clic, molette, clic droit = retour.
module GamePlay
  class Magasin < MagasinBase
    LIST_X = 120
    LIST_Y = 4
    ROW_TOP = 20
    ROW_HEIGHT = 16
    ROWS = 10

    def initialize(shop_id)
      super
      @seller = M.seller(M.fetch(@shop || {}, :seller))
      @pages = []
      @page = 0
      @index = 0
      @top = 0
      build_pages
    end

    def update_inputs
      return false unless @shop

      case @state
      when :choice then update_choice_inputs
      when :message then update_message_inputs
      when :quantity then update_quantity_inputs
      when :closing then update_closing
      else update_list_inputs
      end
    end

    def update_mouse(_moved)
      return false unless @shop

      case @state
      when :choice then update_choice_mouse
      when :quantity then update_quantity_mouse
      when :browse then update_list_mouse
      else true
      end
    end

    def update_graphics
      super
      @closing_frames += 1 if @state == :closing
      return true
    end

    private

    def say(key, values = {})
      return M.line(@seller, key, values)
    end

    # Catégories : poches du sac (dans l'ordre du sac), puis les Pokémon
    def build_pages
      return unless @shop

      groups = M.entries(@shop).group_by { |e| M.entry_pocket(e) }
      order = M::POCKETS.keys + [M::POKEMON_POCKET]
      @pages = order.select { |p| groups[p] }.map { |p| [p, groups[p]] }
      @page = @page.clamp(0, [@pages.size - 1, 0].max)
    end

    def current_entries
      return @pages.dig(@page, 1) || []
    end

    def current
      return current_entries[@index]
    end

    def create_graphics
      super
      return unless @shop

      create_money_window
      @counter = UI::Magasin::CounterWindow.new(@viewport, 4, 150, M.t('Dans le sac', 'In bag'), ->(v) { M.number(v) })
      create_list
      create_info
      open_menu(true)
    end

    def create_list
      @list = stack(LIST_X, LIST_Y)
      @list.add_sprite(0, 0, M.file('list'))
      @pocket_icon = @list.add_sprite(4, 2, 'bag_horizon/pockets')
      @title = @list.add_text(22, 1, 110, 16, '', color: WHITE)
      @list.with_font(SMALL) { @page_text = @list.add_text(120, 3, 70, 13, '', 2, color: WHITE) }
      @cursor = @list.add_sprite(2, ROW_TOP - 1, M.file('cursor'))
      @rows = Array.new(ROWS) do |i|
        y = ROW_TOP + i * ROW_HEIGHT
        name = @list.add_text(6, y, 118, 16, '', color: WHITE)
        tag = @list.add_sprite(122, y + 3, M.file('tag_discount'))
        tag_text = nil
        price = nil
        @list.with_font(SMALL) do
          tag_text = @list.add_text(122, y + 2, 26, 11, '', 1, color: WHITE)
          price = @list.add_text(130, y + 2, 60, 13, '', 2, color: WHITE)
        end
        { name: name, tag: tag, tag_text: tag_text, price: price }
      end
      @empty = @list.add_text(0, 80, 196, 16, M.t('Rien à vendre', 'Nothing for sale'), 1, color: WHITE)
    end

    # --- Menu ------------------------------------------------------------------------------------------
    def open_menu(first = false)
      @state = :browse
      refresh_list
      @info.show(nil, first ? say(:welcome) : M.t('Autre chose ?', 'Anything else?'))
      choices = [M.t('Acheter', 'Buy')]
      choices << M.t('Vendre', 'Sell') if M.fetch(@currency, :kind).to_s == 'money'
      choices << M.t('Quitter', 'Quit')
      @menu_choices = choices
      open_choice(choices) do |i|
        case choices[i]
        when M.t('Acheter', 'Buy') then start_buying
        when M.t('Vendre', 'Sell') then start_selling
        else close_shop
        end
      end
    end

    def start_buying
      @state = :browse
      @buying = true
      refresh_list
      refresh_info
    end

    def start_selling
      @info.show(nil, say(:sell))
      call_scene(GamePlay::Bag, :shop)
      @money.set(M.funds(@currency))
      open_menu
    end

    def close_shop
      @buying = false
      refresh_list
      @info.show(nil, say(:goodbye))
      @state = :closing
      @closing_frames = 0
    end

    # Au revoir : A / B ou une seconde, après le défilement de l'argent
    def update_closing
      done = Input.trigger?(:A) || Input.trigger?(:B) || Mouse.trigger?(:LEFT) || Mouse.trigger?(:RIGHT) || @closing_frames > 60
      @running = false if done && !@money.rolling?
      return false
    end

    # --- Liste ---------------------------------------------------------------------------------------
    def update_list_inputs
      if Input.trigger?(:B)
        play_cancel_se
        @buying = false
        open_menu
        return false
      end

      entries = current_entries
      if Input.repeat?(:DOWN) && entries.any?
        select(@index + 1 >= entries.size ? 0 : @index + 1)
      elsif Input.repeat?(:UP) && entries.any?
        select(@index - 1 < 0 ? entries.size - 1 : @index - 1)
      elsif (Input.repeat?(:RIGHT) || Input.repeat?(:LEFT)) && @pages.size > 1
        play_cursor_se
        @page = (@page + (Input.repeat?(:RIGHT) ? 1 : -1)) % @pages.size
        @index = @top = 0
        refresh_list
        refresh_info
      elsif Input.trigger?(:A) && current
        buy(current)
      end
      return false
    end

    def update_list_mouse
      if Mouse.trigger?(:RIGHT)
        play_cancel_se
        @buying = false
        open_menu
        return false
      end
      if Mouse.wheel != 0
        select((@index - Mouse.wheel).clamp(0, [current_entries.size - 1, 0].max))
        Mouse.wheel = 0
        return false
      end
      return true unless Mouse.trigger?(:LEFT)

      mx = Mouse.x - LIST_X
      my = Mouse.y - LIST_Y - ROW_TOP
      return true unless mx.between?(0, 195) && my >= 0

      index = @top + my / ROW_HEIGHT
      return true if my / ROW_HEIGHT >= ROWS || index >= current_entries.size

      index == @index ? buy(current) : select(index)
      return false
    end

    def select(index)
      return if index == @index

      play_cursor_se
      @index = index
      refresh_list
      refresh_info
    end

    def refresh_list
      entries = current_entries
      @empty.visible = entries.empty?
      page = @pages[@page]
      pocket = page ? page[0] : 1
      @title.text = page ? M.pocket_name(pocket) : ''
      @page_text.text = @pages.size > 1 ? M.t("Page #{@page + 1}/#{@pages.size}", "Page #{@page + 1}/#{@pages.size}") : ''
      icon = { 1 => 0, 2 => 2, 3 => 3, 4 => 4, 5 => 7, 6 => 1, 7 => 5, 8 => 6 }[pocket]
      @pocket_icon.visible = !icon.nil? && page
      @pocket_icon.src_rect.set((icon || 0) * 14, 14, 14, 14)
      @index = @index.clamp(0, [entries.size - 1, 0].max)
      @top = @index if @index < @top
      @top = @index - ROWS + 1 if @index >= @top + ROWS
      @cursor.visible = @buying && entries.any?
      @cursor.y = @list.y + ROW_TOP - 1 + (@index - @top) * ROW_HEIGHT
      @rows.each_with_index { |row, i| refresh_row(row, entries[@top + i]) }
      @counter.label = pocket == M::POKEMON_POCKET ? M.t('Équipe', 'Party') : M.t('Dans le sac', 'In bag')
    end

    def refresh_row(row, entry)
      row.each_value { |s| s.visible = !entry.nil? }
      return unless entry

      left = M.remaining(@shop, entry)
      row[:name].text = M.entry_name(entry)
      row[:name].opacity = left == 0 ? 120 : 255
      mod = M.modifier(@shop, entry)
      row[:tag].visible = row[:tag_text].visible = mod != 0 && left != 0
      row[:tag].set_bitmap(M.file(mod < 0 ? 'tag_discount' : 'tag_overcharge'), :interface)
      row[:tag_text].text = mod < 0 ? "#{mod}%" : "+#{mod}%"
      row[:price].text = left == 0 ? M.t('Rupture', 'Sold out') : amount(M.price(@shop, entry))
      row[:price].opacity = left == 0 ? 160 : 255
      row[:name].width = mod != 0 && left != 0 ? 114 : 124
    end

    def refresh_info
      entry = current
      unless entry && @buying
        @info.show(nil, @buying ? M.t('Rien à vendre ici.', 'Nothing for sale here.') : '')
        return
      end
      text = M.entry_descr(entry)
      left = M.remaining(@shop, entry)
      text = "#{M.t('En stock', 'In stock')} : #{left}. #{text}" if left
      @info.show(entry, text)
      if M.pokemon?(entry)
        @counter.set($actors.size, instant: true)
      else
        @counter.set($bag.item_quantity(M.fetch(entry, :item).to_s.to_sym), instant: true)
      end
    end

    # --- Achat ---------------------------------------------------------------------------------------
    def buy(entry)
      name = M.entry_name(entry)
      if M.remaining(@shop, entry) == 0
        play_buzzer_se
        return show_message(say(:out_of_stock, item: name), entry)
      end
      unit = M.price(@shop, entry)
      max = M.max_quantity(@shop, entry)
      if max <= 0
        play_buzzer_se
        full = !M.pokemon?(entry) && $bag.item_quantity(M.fetch(entry, :item).to_s.to_sym) >= M::MAX_ITEMS
        return show_message(say(full ? :bag_full : :no_money, item: name), entry)
      end
      play_decision_se
      return confirm(entry, 1) if M.pokemon?(entry) || max == 1

      @info.show(entry, say(:ask_quantity, item: name, price: M.number(unit), currency: M.currency_symbol(@currency)))
      open_quantity(entry, 1, 1, max) { |qty| qty ? confirm(entry, qty) : refresh_info }
    end

    def confirm(entry, qty)
      total = M.price(@shop, entry) * qty
      @info.show(entry, say(:confirm, item: M.entry_name(entry), qty: qty, total: M.number(total), currency: M.currency_symbol(@currency)))
      open_choice([M.t('Oui', 'Yes'), M.t('Non', 'No')]) do |i|
        i == 0 ? pay(entry, qty, total) : refresh_info
      end
    end

    def pay(entry, qty, total)
      if M.funds(@currency) < total
        play_buzzer_se
        return show_message(say(:no_money, item: M.entry_name(entry)), entry)
      end
      M.pay(@currency, total)
      @money.set(M.funds(@currency))
      play_buy_se
      bonus = M.give(@shop, entry, qty)
      refresh_list
      refresh_info
      text = say(:thanks, item: M.entry_name(entry), qty: qty, total: M.number(total), currency: M.currency_symbol(@currency))
      text += " #{say(:bonus, bonus: M.bonus_text(bonus))}" unless bonus.empty?
      show_message(text, entry)
    end

    def after_message
      refresh_list
      refresh_info
    end
  end
end
