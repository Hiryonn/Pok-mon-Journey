# Triple Triad : boosters (objets du sac qui donnent des cartes)
#
# Un booster est un objet de Studio (« Booster », « Pack de départ »…) relié dans Studio
# (Level design > Mini-jeux > Triple Triad > Boosters) à :
#   count      nombre de cartes (1 à 10)
#   cards      cartes possibles (vide : tous les Pokémon dont la carte est entre min_level et max_level)
#   min_level / max_level  niveaux des cartes (0 à 9, comme les adversaires)
#   rarity     les cartes fortes sortent plus rarement
# Utiliser l'objet depuis le sac l'ouvre : le paquet s'ouvre et les cartes sont montrées une à une (style Horizon),
# puis ajoutées à la collection.
# L'objet doit être « utilisable hors combat » (Studio) et « consommable » pour disparaître une fois ouvert.
#
# Commande d'évènement (Script) : triple_triad_booster(:booster_pack) -> ouvre un booster sans utiliser d'objet
module TripleTriad
  DEFAULT_BOOSTERS = [
    { item: 'booster_pack', count: 5, min_level: 0, max_level: 9, rarity: true, cards: [] },
    { item: 'starter_pack', count: 3, min_level: 0, max_level: 2, rarity: false,
      cards: %w[bulbasaur charmander squirtle chikorita cyndaquil totodile treecko torchic mudkip turtwig chimchar piplup snivy tepig
                oshawott chespin fennekin froakie rowlet litten popplio grookey scorbunny sobble sprigatito fuecoco quaxly] }
  ].freeze

  module_function

  # @return [Array<Hash>] boosters réglés dans Studio (ou ceux par défaut)
  def boosters
    list = config.boosters
    list = DEFAULT_BOOSTERS unless list.is_a?(Array)
    return list.map { |b| b.to_h.transform_keys(&:to_sym) }.reject { |b| b[:item].to_s.empty? }
  end

  # @param item [Symbol, String] db_symbol de l'objet
  # @return [Hash, nil]
  def booster(item)
    return boosters.find { |b| b[:item].to_s == item.to_s }
  end

  # Tire les cartes d'un booster (sans les donner)
  # @return [Array<Symbol>]
  def draw_booster(item)
    data = booster(item)
    return [] unless data

    count = data[:count].to_i.clamp(1, 10)
    pool = Array(data[:cards]).map(&:to_sym).select { |s| data_creature(s).db_symbol != :__undef__ }
    return Array.new(count) { pool.sample } unless pool.empty?

    low = data[:min_level].to_i.clamp(0, 9)
    high = data[:max_level].to_i.clamp(low, 9)
    pool = all_species.select { |s| Card.get(s).level.between?(low, high) }
    pool = all_species if pool.empty?
    return Array.new(count) { pool.sample } unless data[:rarity]

    # Rareté : une carte de niveau 0 sort 10 fois plus souvent qu'une carte de niveau 9
    weights = pool.map { |s| 10 - Card.get(s).level }
    total = weights.sum
    return Array.new(count) do
      roll = rand(total)
      pool.each_with_index.find { |_, i| (roll -= weights[i]) < 0 }&.first || pool.last
    end
  end

  # Ouvre un booster : tire les cartes, les ajoute à la collection et les montre
  # @param item [Symbol]
  # @param scene [GamePlay::Base] scène d'où on l'ouvre
  # @return [Array<Symbol>] cartes obtenues
  def open_booster(item, scene = $scene)
    reload if PSDK_CONFIG.debug?
    cards = draw_booster(item)
    return cards if cards.empty?

    news = cards.each_with_object([]) do |s, list|
      list << (count(s) == 0 && !list.include?(s))
      add(s)
    end
    scene.call_scene(GamePlay::TripleTriadBooster, item, cards, news)
    return cards
  end

  # Le sac sait ouvrir les objets réglés comme boosters (ajoutés à la volée : la liste vient de Studio)
  def register_booster_use(item)
    return if @registered_boosters&.include?(item)

    (@registered_boosters ||= []) << item
    PFM::ItemDescriptor.define_bag_use(item) do |data, scene|
      TripleTriad.open_booster(data.db_symbol, scene)
    end
  end
end

module PFM
  module ItemDescriptor
    # Avant de chercher l'effet d'un objet, on prépare ceux des boosters
    module TripleTriadBoosters
      def actions(item_id)
        sym = data_item(item_id).db_symbol
        TripleTriad.register_booster_use(sym) if TripleTriad.booster(sym)
        return super
      rescue StandardError => e
        log_error("Triple Triad : booster (#{e.message})") if respond_to?(:log_error, true)
        return super
      end
    end
    singleton_class.prepend(TripleTriadBoosters)
  end
end

module GamePlay
  # Ouverture d'un booster, aux couleurs Horizon : le paquet tremble, s'ouvre dans un éclair,
  # puis les cartes arrivent face cachée et se retournent une à une
  class TripleTriadBooster < BaseCleanUpdate::FrameBalanced
    TT = ::TripleTriad
    DARK = 0
    WHITE = 9
    SMALL = 20
    # Cadre clair du milieu
    PANEL_X = 10
    PANEL_Y = 32
    PANEL_W = 300
    PANEL_H = 178
    # Écart entre les cartes
    STEP = 52
    # Images entre deux cartes retournées, durée du tremblement et de l'éclair
    REVEAL_DELAY = 20
    SHAKE_TIME = 36
    FLASH_TIME = 16

    # @param item [Symbol] objet du booster
    # @param cards [Array<Symbol>]
    # @param news [Array<Boolean>] cartes que le joueur n'avait pas encore
    def initialize(item, cards, news = [])
      super()
      @item = item
      @cards = cards
      @news = news
      @revealed = 0
      @frame = 0
      @state = :shake
    end

    def update_inputs
      return false unless Input.trigger?(:A) || Input.trigger?(:B) || Mouse.trigger?(:LEFT)

      case @state
      when :shake, :flash
        open_pack
        reveal(@revealed) while @revealed < @cards.size
      when :reveal
        reveal(@revealed) while @revealed < @cards.size
      else
        play_decision_se
        @running = false
      end
      refresh_help
      return false
    end

    def update_graphics
      @frame += 1
      case @state
      when :shake then update_shake
      when :flash then update_flash
      when :reveal then update_reveal
      end
      blink = (@frame / 20).even?
      @tags.each_with_index { |tag, i| tag.each { |sprite| sprite.visible = i < @revealed && @news[i] && (blink || @state == :done) } }
      return true
    end

    private

    # --- Animation -------------------------------------------------------------------------------
    def update_shake
      t = @frame
      @pack.x = @pack_x + (t > 8 ? (Math.sin(t * 1.4) * [t / 6, 4].min).round : 0)
      @pack.zoom = 3 + [t - SHAKE_TIME + 8, 0].max * 0.12
      open_pack if t >= SHAKE_TIME
    end

    def open_pack
      return unless @state == :shake

      @state = :flash
      @frame = 0
      @pack.visible = false
      @flash.visible = true
      @flash.opacity = 255
      @sprites.each { |sprite| sprite.visible = true }
      @shadows.each { |sprite| sprite.visible = true }
      play_decision_se
      refresh_help
    end

    def update_flash
      @flash.opacity = 255 - 255 * @frame / FLASH_TIME
      return if @frame < FLASH_TIME

      @flash.visible = false
      @state = :reveal
      @frame = REVEAL_DELAY - 6
      refresh_help
    end

    def update_reveal
      return unless @frame >= REVEAL_DELAY

      @frame = 0
      reveal(@revealed)
      refresh_help
    end

    def reveal(index)
      return if index >= @cards.size

      @flash.visible = false
      @state = :reveal
      @sprites[index].visible = true
      @shadows[index].visible = true
      @sprites[index].hidden = false
      @names[index].visible = true
      @revealed = index + 1
      play_cursor_se
      @state = :done if @revealed >= @cards.size
    end

    def refresh_help
      @help.text = case @state
                   when :done then TT.t('A : Continuer', 'A: Continue')
                   when :shake then TT.t('A : Ouvrir', 'A: Open')
                   else TT.t('A : Tout montrer', 'A: Show all')
                   end
    end

    # --- Graphismes ------------------------------------------------------------------------------
    def create_graphics
      super
      @base = UI::SpriteStack.new(@viewport, default_cache: :interface)
      picture('horizon/team/fond', 0, 0)
      picture('horizon/header', 0, 0)
      picture('horizon/tcard/button_background', 0, 214)
      @base.add_sprite(PANEL_X, PANEL_Y, TT.file('booster_panel'))
      @base.add_text(96, 5, 128, 16, booster_name.upcase, 1, color: WHITE)
      @base.with_font(SMALL) do
        @base.add_text(232, 7, 82, 13, TT.t("#{@cards.size} carte#{@cards.size > 1 ? 's' : ''}", "#{@cards.size} card#{@cards.size > 1 ? 's' : ''}"), 2, color: WHITE)
        @base.add_text(6, 7, 84, 13, TT.t("Total : #{TT.total_count}", "Total: #{TT.total_count}"), color: WHITE)
        @help = @base.add_text(8, 220, 304, 13, '', 1, color: WHITE)
      end
      create_cards
      create_pack
      refresh_help
    end

    def picture(name, x, y)
      return @base.add_sprite(x, y, name) if RPG::Cache.interface_exist?(name)

      return nil
    end

    def booster_name
      return data_item(@item).name.to_s
    rescue StandardError
      return @item.to_s
    end

    # Le paquet (icône de l'objet en grand) au centre du cadre
    def create_pack
      @pack = @base.add_sprite(0, 0, UI::SpriteStack::NO_INITIAL_IMAGE)
      icon = data_item(@item).icon rescue nil
      if icon && RPG::Cache.icon_exist?(icon)
        @pack.set_bitmap(icon, :icon)
        @pack.set_origin(@pack.bitmap.width / 2, @pack.bitmap.height / 2)
      end
      @pack_x = PANEL_X + PANEL_W / 2
      @pack.set_position(@pack_x, PANEL_Y + PANEL_H / 2)
      @pack.zoom = 3
      @flash = @base.add_sprite(0, 0, TT.file('booster_flash'))
      @flash.zoom_x = 40
      @flash.zoom_y = 30
      @flash.visible = false
    rescue StandardError
      @pack_x = PANEL_X + PANEL_W / 2
    end

    def create_cards
      rows = @cards.size > 5 ? 2 : 1
      per_row = rows == 2 ? (@cards.size + 1) / 2 : @cards.size
      @sprites = []
      @shadows = []
      @names = []
      @tags = []
      @cards.each_with_index do |s, i|
        row = i >= per_row ? 1 : 0
        col = i - row * per_row
        in_row = row == 1 ? @cards.size - per_row : per_row
        x = PANEL_X + (PANEL_W - (in_row - 1) * STEP - TT::CARD_W) / 2 + col * STEP
        y = rows == 2 ? PANEL_Y + 18 + row * 80 : PANEL_Y + 52
        shadow = @base.add_sprite(x - 2, y + TT::CARD_H - 3, TT.file('booster_shadow'))
        shadow.visible = false
        @shadows << shadow
        sprite = UI::TripleTriad::CardSprite.new(@viewport)
        sprite.set(TT::Card.get(s), 0, true)
        sprite.set_position(x, y)
        sprite.visible = false
        @sprites << sprite
        @base.with_font(SMALL) do
          label = @base.add_text(x - 8, y + TT::CARD_H + 3, TT::CARD_W + 16, 13, TT::Card.get(s).name, 1, color: DARK)
          label.visible = false
          @names << label
          tag = @base.add_sprite(x - 6, y - 10, TT.file('booster_new'))
          text = @base.add_text(x - 6, y - 11, 52, 13, TT.t('Nouveau !', 'New!'), 1, color: DARK)
          tag.visible = text.visible = false
          @tags << [tag, text]
        end
      end
    end
  end
end

class Interpreter
  # Ouvre un booster sans utiliser d'objet (cadeau d'un personnage, etc.)
  # @param item [Symbol] booster réglé dans Studio (ex. :booster_pack)
  # @return [Array<Symbol>] cartes obtenues
  def triple_triad_booster(item)
    cards = TripleTriad.open_booster(item.to_sym, $scene)
    @wait_count = 2
    return cards
  end
  alias ouvrir_booster triple_triad_booster
end
