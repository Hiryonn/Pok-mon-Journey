# Script décompilé depuis le bytecode du jeu (Ruby 3.0) — fichier d'origine : RMXP/006 BerryDex.rb
# Les commentaires et la mise en forme d'origine ne sont pas récupérables.

module UI
  BERRY_DEX_DEBUG_MODE = false
  BERRY_DEX_DEBUG_ICON_ASSET = "000_debug"
  BERRY_DEX_BLACK_TEXT_COLOR = Color.new(0, 0, 0)
  BERRY_DEX_TITLE_TEXT_COLOR = Color.new(75, 95, 123)
  BERRY_DEX_TRANSPARENT_TEXT_COLOR = Color.new(0, 0, 0, 0)
  BERRY_DEX_TRACKING_TITLE_OFFSET = [80, -7]
  BERRY_DEX_TRACKING_BOX_OFFSET = [0, 0]
  BERRY_DEX_TRACKING_SELECTOR_OFFSET = [-6, -3]

  def self.berry_dex_icon_filename(item)
    return BERRY_DEX_DEBUG_ICON_ASSET if BERRY_DEX_DEBUG_MODE

    item.icon
  end

  def self.berry_dex_present_berry_entries
    ((PFM.game_state.berries || {}).each_with_object([]) do |(map_id, events), entries|
      events.each do |event_id, data|
        next unless data && data[0] != 0
        item = (data_item(data[0]) rescue nil)
        next unless item&.is_berry
        berry_dex_repair_timer(data)
        entries << { map_id: map_id, event_id: event_id, data: data, item: item }
      end
    end).sort_by { |entry| [entry[:map_id], entry[:event_id]] }
  end

  def self.berry_dex_repair_timer(data)
    return unless data[1].to_i < 4 && data[3].to_i.positive?
    return if data[2].to_i.positive?

    data[2] = data[3]
  end

  def self.berry_dex_map_name(map_id)
    @berry_dex_map_infos ||= (load_data("Data/MapInfos.rxdata") rescue {})
    name = @berry_dex_map_infos[map_id]&.name.to_s
    name = PFM::Text.parse_string_for_messages(name) if defined?(PFM::Text)
    if name.empty?
      "Map #{map_id}"
    else
      name
    end
  end

  def self.berry_dex_event_position(map_id, event_id)
    @berry_dex_maps ||= {}
    map = @berry_dex_maps[map_id] ||= (load_data(format("Data/Map%03d.rxdata", map_id)) rescue nil)
    event = map&.events&.[](event_id)
    return [event.x, event.y] if event
  end

  def self.berry_dex_time_text(minutes)
    minutes = minutes.to_i.clamp(0, Float::INFINITY)
    hours = minutes / 60
    rest = minutes % 60
    if hours.zero?
      "#{rest}min"
    elsif rest.zero?
      "#{hours}h"
    else
      "#{hours}h#{format("%02d", rest)}"
    end
  end

  def self.style_berry_dex_text(*texts)
    texts.flatten.compact.each do |text|
      unless text.respond_to?(:draw_shadow=)
        next
      end

      text.draw_shadow = false
    end
  end

  def self.style_berry_dex_black_text(*texts)
    style_berry_dex_text(*texts)

    texts.flatten.compact.each do |text|
      unless text.respond_to?(:fill_color=)
        next
      end

      text.fill_color = BERRY_DEX_BLACK_TEXT_COLOR
      if text.respond_to?(:outline_color=)
        text.outline_color = BERRY_DEX_TRANSPARENT_TEXT_COLOR
      end
      if text.respond_to?(:outline_thickness=)
        text.outline_thickness = 0
      end
    end
  end

  def self.style_berry_dex_title_text(*texts)
    style_berry_dex_text(*texts)

    texts.flatten.compact.each do |text|
      unless text.respond_to?(:fill_color=)
        next
      end

      text.fill_color = BERRY_DEX_TITLE_TEXT_COLOR
      if text.respond_to?(:outline_color=)
        text.outline_color = BERRY_DEX_TRANSPARENT_TEXT_COLOR
      end
      if text.respond_to?(:outline_thickness=)
        text.outline_thickness = 0
      end
    end
  end

  class BerryDexControlButton < GenericBase::ControlButton
    KEY_ICON_X_OFFSET = 2

    def initialize(viewport, coords_index, key)
      @berry_dex_coords_index = coords_index
      super(viewport, coords_index, key)
      @key_button.set_position(@key_button.x + KEY_ICON_X_OFFSET, @key_button.y)
      @background.set_bitmap("0 base_ui/buttons", :interface)
      UI.style_berry_dex_text(@text)
      self.pressed = false
    end

    private

    def text_rect
      return [17, 3, 92, 13] if @berry_dex_coords_index == 0

      super
    end
  end

  class BerryDexBase < GenericBase
    private

    def background_filename
      "0 base_ui/background"
    end

    def button_background_filename
      "0 base_ui/frame_bottom"
    end

    def create_control_button
      @ctrl = Array.new(4) { |index| BerryDexControlButton.new(@viewport, index, @keys[index]) }
    end
  end

  class BerryDexInfo < SpriteStack
    BACKGROUND = "berry_dex/winsprite"
    ICON_POSITION = [61, 76]
    ICON_OFFSET = [-34, -60]
    NAME_POSITION = [44, 6]
    NAME_OFFSET = [0, 0]
    NAME_ALIGNMENT = 0
    DESCRIPTION_AREA = [14, 36, 100, 165]
    DESCRIPTION_TEXT_OFFSET = [0, -5]
    DESCRIPTION_LINE_SPACING = 10
    DESCRIPTION_FONT = 20
    DESCRIPTION_LINE_COUNT = 16
    SUMMARY_TITLES = { fr: { effect: "EFFET", culture: "CULTURE", cooking: "CUISINE" }, en: { effect: "EFFECT", culture: "BERRIES", cooking: "COOKING" } }

    SUMMARY_TITLE_TEXTS = SUMMARY_TITLES.values.flat_map(&:values)
    LABELS = { fr: { heal: "Soigne", restore: "Rend", all_moves: "à toutes capac.", may_confuse: "Confusion possible", raise: "Monte", low_hp: "à PV faibles", reduce: "Réduit", normal_attack: "sur attaque Normal", super_effective: "si super efficace", physical_hit: "sur coup physique", special_hit: "sur coup spécial", random_stat: "stat hasard", critical: "Critique augmente", hurt_attacker: "Blesse attaquant", happiness: "Bonheur", hp: "PV", pp: "PP", firmness: "Fermeté", yield: "Récolte", growth: "Pousse", drying: "Eau", natural_gift: "Don", pokeblock: "Pokébloc", better_pokeblock: "Bonus", smoothness: "Onct.", spicy: "Épi", dry: "Sec", sweet: "Suc", bitter: "Ame", sour: "Aci" }, en: { heal: "Heal", restore: "Restore", all_moves: "all moves", may_confuse: "May confuse", raise: "Raise", low_hp: "at low HP", reduce: "Reduce", normal_attack: "on Normal attack", super_effective: "if super effective", physical_hit: "on physical hit", special_hit: "on special hit", random_stat: "random stat", critical: "Critical up", hurt_attacker: "Hurts attacker", happiness: "Happiness", hp: "HP", pp: "PP", firmness: "Firmness", yield: "Yield", growth: "Growth", drying: "Dry.", natural_gift: "Nat. Gift", pokeblock: "Pokéblock", better_pokeblock: "Better", smoothness: "Smoothness", spicy: "Spicy", dry: "Dry", sweet: "Sweet", bitter: "Bitter", sour: "Sour" } }

    CONFUSING_HEAL_BERRIES = [:figy_berry, :wiki_berry, :mago_berry, :aguav_berry, :iapapa_berry]
    FIRMNESS_NAMES = { fr: { very_soft: "Très tend.", soft: "Tendre", hard: "Ferme", very_hard: "Dure", super_hard: "Très dure" }, en: { very_soft: "Very soft", soft: "Soft", hard: "Hard", very_hard: "Very hard", super_hard: "Super hard" } }

    POKEBLOCK_COLOR_NAMES = { fr: { red: "Rouge", blue: "Bleu", yellow: "Jaune", green: "Vert", pink: "Rose" }, en: { red: "Red", blue: "Blue", yellow: "Yellow", green: "Green", pink: "Pink" } }

    NATURAL_GIFT_TYPE_NAMES = { fr: { normal: "Normal", fire: "Feu", water: "Eau", electric: "Élec", grass: "Plante", ice: "Glace", fighting: "Combat", poison: "Poison", ground: "Sol", flying: "Vol", psychic: "Psy", bug: "Insecte", rock: "Roche", ghost: "Spectre", dragon: "Dragon", dark: "Ténèbres", steel: "Acier", fairy: "Fée" }, en: { normal: "Normal", fire: "Fire", water: "Water", electric: "Electric", grass: "Grass", ice: "Ice", fighting: "Fighting", poison: "Poison", ground: "Ground", flying: "Flying", psychic: "Psychic", bug: "Bug", rock: "Rock", ghost: "Ghost", dragon: "Dragon", dark: "Dark", steel: "Steel", fairy: "Fairy" } }

    STATUS_NAMES = { fr: { poison: "Poison", toxic: "Poison", paralysis: "Paralysie", burn: "Brûlure", sleep: "Sommeil", freeze: "Gel", confusion: "Confusion", flinch: "Peur", death: "K.O.", ko: "K.O." }, en: { poison: "Poison", toxic: "Poison", paralysis: "Paralysis", burn: "Burn", sleep: "Sleep", freeze: "Freeze", confusion: "Confusion", flinch: "Flinch", death: "K.O.", ko: "K.O." } }

    STAT_NAMES = { fr: { hp: "PV", atk: "Atq", dfe: "Déf", spd: "Vit", ats: "Atq.Sp", dfs: "Déf.Sp", acc: "Précis.", eva: "Esq." }, en: { hp: "HP", atk: "Atk", dfe: "Def", spd: "Speed", ats: "Sp.Atk", dfs: "Sp.Def", acc: "Acc.", eva: "Eva." } }

    TYPE_RESIST_BERRY_TYPES = { occa_berry: :fire, passho_berry: :water, wacan_berry: :electric, rindo_berry: :grass, yache_berry: :ice, chople_berry: :fighting, kebia_berry: :poison, shuca_berry: :ground, coba_berry: :flying, payapa_berry: :psychic, tanga_berry: :bug, charti_berry: :rock, kasib_berry: :ghost, haban_berry: :dragon, colbur_berry: :dark, babiri_berry: :steel, chilan_berry: :normal, roseli_berry: :fairy }

    SPECIAL_BERRY_EFFECTS = { fr: { enigma_berry: ["Soigne 25% PV", "si coup super eff."], lansat_berry: ["Critique augmente", "à PV faibles"], starf_berry: ["Monte stat hasard", "à PV faibles"], kee_berry: ["Monte Déf +1", "sur coup physique"], maranga_berry: ["Monte Déf.Sp +1", "sur coup spécial"], jaboca_berry: ["Blesse attaquant", "sur coup physique"], rowap_berry: ["Blesse attaquant", "sur coup spécial"] }, en: { enigma_berry: ["Heal 25% HP", "if super effective"], lansat_berry: ["Critical up", "at low HP"], starf_berry: ["Raise random stat", "at low HP"], kee_berry: ["Raise Def +1", "on physical hit"], maranga_berry: ["Raise Sp.Def +1", "on special hit"], jaboca_berry: ["Hurts attacker", "on physical hit"], rowap_berry: ["Hurts attacker", "on special hit"] } }

    def initialize(viewport)
      super(viewport, 3, 9, default_cache: :interface)
      create_sprites
    end

    def data=(item)
      super(item)
      refresh
    end

    private

    def create_sprites
      add_background(BACKGROUND)
      @icon = add_sprite(ICON_POSITION[0] + ICON_OFFSET[0], ICON_POSITION[1] + ICON_OFFSET[1], NO_INITIAL_IMAGE)
      @name = add_text(NAME_POSITION[0] + NAME_OFFSET[0], NAME_POSITION[1] + NAME_OFFSET[1], 116, 19, nil.to_s, NAME_ALIGNMENT, color: 10)
      @name.bold = false
      @description_lines = create_description_lines
      UI.style_berry_dex_text(@name)
    end

    def refresh
      item = @data
      return clear if item.nil?
      @name.text = item.exact_name
      refresh_description(berry_summary_lines(item))
      @icon.set_bitmap(UI.berry_dex_icon_filename(item), :icon)
      @icon.set_origin(@icon.width / 2, @icon.height / 2)
      @icon.visible = true
    end

    def clear
      @name.text = nil.to_s
      @description_lines.each { |line| line.text = nil.to_s }
      @icon.visible = false
    end

    def create_description_lines
      x = DESCRIPTION_AREA[0] + DESCRIPTION_TEXT_OFFSET[0]
      y = DESCRIPTION_AREA[1] + DESCRIPTION_TEXT_OFFSET[1]

      with_font(DESCRIPTION_FONT) do
        Array.new(DESCRIPTION_LINE_COUNT) do |index|
          text = add_text(x, y + DESCRIPTION_LINE_SPACING * index, description_text_width, DESCRIPTION_LINE_SPACING, nil.to_s, 0, nil, color: 0)
          UI.style_berry_dex_black_text(text)
          text
        end
      end
    end

    def refresh_description(lines)
      lines.each_with_index do |line, index|
        break unless @description_lines[index]
        text_sprite = @description_lines[index]
        text_sprite.text = line
        style_description_line(text_sprite, line)
      end

      @description_lines.drop(lines.size).each do |text_sprite|
        text_sprite.text = nil.to_s
        UI.style_berry_dex_black_text(text_sprite)
      end
    end

    def berry_summary_lines(item)
      lines = []
      append_summary_section(lines, summary_title(:effect), effect_summary_lines(item))
      append_summary_section(lines, summary_title(:culture), berry_data_lines(item.berry_data))
      append_summary_section(lines, summary_title(:cooking), cooking_data_lines(item.cooking_data))
      lines.first(DESCRIPTION_LINE_COUNT)
    end

    def append_summary_section(lines, title, content)
      content = content.compact.reject(&:empty?)
      return if content.empty?
      lines << nil.to_s unless lines.empty?
      lines << title
      lines.concat(content)
    end

    def effect_summary_lines(item)
      special_lines = special_berry_effect_lines(item)
      return special_lines.dup unless special_lines.empty?
      lines = []
      if item.is_a?(Studio::EVBoostItem)
        lines << "EV #{stat_name(item.stat)} #{signed_value(item.count)}"
        lines << loyalty_line(item)
      elsif item.is_a?(Studio::StatusConstantHealItem)
        lines << "#{label(:heal)} #{item.hp_count} #{label(:hp)}"
        lines << "#{label(:heal)} #{status_summary(item.status_list)}"
      elsif item.is_a?(Studio::StatusHealItem)
        lines << "#{label(:heal)} #{status_summary(item.status_list)}"
      elsif item.is_a?(Studio::AllPPHealItem)
        lines << "#{label(:restore)} #{item.pp_count} #{label(:pp)}"
        lines << label(:all_moves)
      elsif item.is_a?(Studio::PPHealItem)
        lines << "#{label(:restore)} #{item.pp_count} #{label(:pp)}"
      elsif item.is_a?(Studio::RateHealItem)
        lines << "#{label(:heal)} #{rate_percent(item.hp_rate)}% #{label(:hp)}"
        lines << label(:may_confuse) if CONFUSING_HEAL_BERRIES.include?(item.db_symbol)
      elsif item.is_a?(Studio::ConstantHealItem)
        lines << "#{label(:heal)} #{item.hp_count} #{label(:hp)}"
      elsif item.is_a?(Studio::StatBoostItem)
        lines << "#{label(:raise)} #{stat_name(item.stat)} #{signed_value(item.count)}"
        lines << label(:low_hp)
      end

      lines.compact
    end

    def special_berry_effect_lines(item)
      if type = TYPE_RESIST_BERRY_TYPES[item.db_symbol]
        lines = ["#{label(:reduce)} #{natural_gift_type_name(type)}"]
        lines << (type == :normal ? label(:normal_attack) : label(:super_effective))
        lines
      else
        localized(SPECIAL_BERRY_EFFECTS, item.db_symbol) || []
      end
    end

    def berry_data_lines(data)
      return [] unless data
      return english_berry_data_lines(data) if english?

      ["#{label(:firmness)} #{firmness_name(data.firmness)}", "#{label(:yield)} #{data.min_yield}-#{data.max_yield}", "#{label(:growth)} #{data.growth}h #{label(:drying)} #{data.drain_rate}h", "#{label(:natural_gift)} #{natural_gift_type_name(data.natural_gift_type)} #{data.natural_gift_power}"]
    end

    def cooking_data_lines(data)
      return [] unless data
      return english_cooking_data_lines(data) if english?

      ["#{label(:pokeblock)} #{pokeblock_color_name(data.pokeblock_color)}", "#{label(:better_pokeblock)} #{data.better_pokeblock_chance}%", "#{label(:smoothness)} #{data.smoothness}", "#{label(:spicy)} #{data.spicy_flavor} #{label(:dry)} #{data.dry_flavor}", "#{label(:sweet)} #{data.sweet_flavor} #{label(:bitter)} #{data.bitter_flavor} #{label(:sour)} #{data.sour_flavor}"]
    end

    def english_berry_data_lines(data)
      ["#{label(:firmness)} #{firmness_name(data.firmness)}", "#{label(:yield)} #{data.min_yield}-#{data.max_yield}", "#{label(:growth)} #{data.growth}h #{label(:drying)} #{data.drain_rate}h", "#{label(:natural_gift)} #{natural_gift_type_name(data.natural_gift_type)} #{data.natural_gift_power}"]
    end

    def english_cooking_data_lines(data)
      ["#{label(:pokeblock)} #{pokeblock_color_name(data.pokeblock_color)}", "#{label(:better_pokeblock)} #{data.better_pokeblock_chance}%", "#{label(:smoothness)} #{data.smoothness}", "#{label(:spicy)} #{data.spicy_flavor} #{label(:dry)} #{data.dry_flavor}", "#{label(:sweet)} #{data.sweet_flavor} #{label(:bitter)} #{data.bitter_flavor} #{label(:sour)} #{data.sour_flavor}"]
    end

    def style_description_line(text_sprite, text)
      if SUMMARY_TITLE_TEXTS.include?(text)
        UI.style_berry_dex_title_text(text_sprite)
      else
        UI.style_berry_dex_black_text(text_sprite)
      end
    end

    def status_summary(status_list)
      statuses = Array(status_list).compact
      if statuses.size > 3
        return "All status" if english?
        "Tout statut"
      else
        statuses.map { |status| status_name(status) }.join("/")
      end
    end

    def stat_name(stat)
      localized(STAT_NAMES, stat) || stat.to_s
    end

    def rate_percent(rate)
      (rate.to_f * 100).round
    end

    def signed_value(value)
      value = value.to_i
      if value.positive?
        "+#{value}"
      else
        value.to_s
      end
    end

    def loyalty_line(item)
      value = -item.loyalty_malus.to_i
      return if value.zero?

      "#{label(:happiness)} #{signed_value(value)}"
    end

    def firmness_name(firmness)
      localized(FIRMNESS_NAMES, firmness) || firmness.to_s
    end

    def pokeblock_color_name(color)
      localized(POKEBLOCK_COLOR_NAMES, color) || color.to_s
    end

    def natural_gift_type_name(type)
      localized(NATURAL_GIFT_TYPE_NAMES, type) || type.to_s
    end

    def status_name(status)
      localized(STATUS_NAMES, status) || status.to_s
    end

    def summary_title(key)
      localized(SUMMARY_TITLES, key) || key.to_s.upcase
    end

    def label(key)
      localized(LABELS, key) || key.to_s
    end

    def localized(source, key)
      values = source[language_key] || source[:fr]
      values[key] || source[:fr][key]
    end

    def language_key
      return :en if english?
      :fr
    end

    def english?
      $options&.language == "en"
    end

    def description_text_width
      DESCRIPTION_AREA[2] - DESCRIPTION_TEXT_OFFSET[0]
    end
  end

  class BerryDexButton < SpriteStack
    BACKGROUND = "berry_dex/but_list"
    SHADOW_BACKGROUND = "But_ListShadow"
    ICON_POSITION = [16, 6]
    ICON_OFFSET = [-15, -5]
    NUMBER_POSITION = [34, 2]
    NUMBER_OFFSET = [0, 0]
    NAME_POSITION = [34, 15]
    NAME_OFFSET = [0, 0]
    LIST_X = 163
    SELECTED_LIST_X = 147
    LIST_Y = 62
    BUTTON_OFFSET = 40

    def initialize(viewport, index)
      @list_index = index
      @selected = false
      super(viewport, LIST_X, LIST_Y, default_cache: :interface)
      create_sprites
      fix_position(index)
    end

    def data=(entry)
      number, item = entry
      return self.visible = false unless item
      self.visible = true
      @number.text = format("%03d", number)
      @name.text = item.exact_name
      @icon.set_bitmap(UI.berry_dex_icon_filename(item), :icon)
      @icon.visible = true
      refresh_obfuscator_visibility
    end

    def selected=(value)
      @selected = value
      refresh_obfuscator_visibility
      set_position(value ? SELECTED_LIST_X : LIST_X, y)
    end

    private

    def create_sprites
      add_background(BACKGROUND)
      @icon = add_sprite(ICON_POSITION[0] + ICON_OFFSET[0], ICON_POSITION[1] + ICON_OFFSET[1], NO_INITIAL_IMAGE)
      @number = add_text(NUMBER_POSITION[0] + NUMBER_OFFSET[0], NUMBER_POSITION[1] + NUMBER_OFFSET[1], 116, 16, nil.to_s, color: 10)
      @name = add_text(NAME_POSITION[0] + NAME_OFFSET[0], NAME_POSITION[1] + NAME_OFFSET[1], 116, 16, nil.to_s, color: 10)
      with_cache(:pokedex) { @obfuscator = add_foreground(SHADOW_BACKGROUND) }
      UI.style_berry_dex_text(@number, @name)
    end

    def refresh_obfuscator_visibility
      @obfuscator.visible = visible && !@selected
    end

    def fix_position(index)
      set_position(index.zero? ? SELECTED_LIST_X : LIST_X, y - BUTTON_OFFSET + index * BUTTON_OFFSET)
    end
  end

  class BerryDexTrackingRow < SpriteStack
    BACKGROUND = "dex_rewards/box_tracker"
    WIDTH = 264
    HEIGHT = 28
    ROW_GAP = 6
    LIST_X = 28
    LIST_Y = 42
    ROW_OFFSET = HEIGHT + ROW_GAP
    ICON_POSITION = [24, 14]
    NAME_RECT = [43, 2, 70, 13]
    PLACE_RECT = [43, 14, 70, 13]
    STAGE_RECT = [114, 2, 132, 13]
    WATER_RECT = [114, 14, 132, 13]
    FONT = 20
    STAGES = { fr: ["Graine", "Pousse", "Croissance", "Fleur", "Mûre"], en: ["Seed", "Sprout", "Growing", "Flower", "Ripe"] }

    LABELS = { fr: { water: "Arrosé", dry: "Sec", state: "Stade", watering: "arrosage" }, en: { water: "Wet", dry: "Dry", state: "Stage", watering: "watering" } }

    def initialize(viewport, index)
      super(viewport, LIST_X, LIST_Y + ROW_OFFSET * index, default_cache: :interface)
      create_sprites
    end

    def data=(entry)
      return self.visible = false unless entry
      self.visible = true
      item = entry[:item]
      @icon.set_bitmap(UI.berry_dex_icon_filename(item), :icon)
      @icon.set_origin(@icon.width / 2, @icon.height / 2)
      @name.text = item.exact_name
      @place.text = place_text(entry)
      @stage.text = stage_text(entry[:data])
      @water.text = water_text(entry[:data])
    end

    private

    def create_sprites
      @background = add_sprite(*UI::BERRY_DEX_TRACKING_BOX_OFFSET, BACKGROUND)
      @icon = add_sprite(*ICON_POSITION, NO_INITIAL_IMAGE)
      with_font(FONT) do
        @name = add_text(*NAME_RECT, nil.to_s, 0, nil, color: 10)
        @place = add_text(*PLACE_RECT, nil.to_s, 0, nil, color: 10)
        @stage = add_text(*STAGE_RECT, nil.to_s, 0, nil, color: 10)
        @water = add_text(*WATER_RECT, nil.to_s, 0, nil, color: 10)
      end

      UI.style_berry_dex_text(@name, @place, @stage, @water)
    end

    def place_text(entry)
      UI.berry_dex_map_name(entry[:map_id])
    end

    def stage_text(data)
      stage = data[1].to_i.clamp(0, 4)
      text = "#{label(:state)}#{label_separator}#{stage_label(stage)}"
      return text if stage >= 4
      remaining = [data[2].to_i + data[3].to_i * (3 - stage), 0].max
      "#{text} (#{UI.berry_dex_time_text(remaining)})"
    end

    def water_text(data)
      label_key = data[4].to_i.positive? ? :water : :dry
      "#{label(label_key)} (#{label(:watering)}#{label_separator}#{data[6].to_i.clamp(0, 4)}/4)"
    end

    def stage_label(stage)
      localized(STAGES)[stage] || stage.to_s
    end

    def label(key)
      localized(LABELS)[key] || key.to_s
    end

    def localized(source)
      source[language_key] || source[:fr]
    end

    def language_key
      return :en if $options&.language == "en"
      :fr
    end

    def label_separator
      return " : " if language_key == :fr
      ": "
    end
  end

  class BerryDexTrackingSelector < SpriteSheet
    ASSET = "dex_rewards/selector_tracker"
    FRAME_COUNT = 2

    def initialize(viewport)
      super(viewport, FRAME_COUNT, 1)
      set_bitmap(ASSET, :interface)
      select(0, 0)
      self.z = 1
    end

    def position_on(row, offset = UI::BERRY_DEX_TRACKING_SELECTOR_OFFSET)
      set_position(row.x + offset[0], row.y + offset[1])
    end

    def update_graphics
      self.sx = Graphics.frame_count / frame_duration % FRAME_COUNT
    end

    private

    def frame_duration
      if UI.respond_to?(:dex_list_selector_frame_duration)
        return UI.dex_list_selector_frame_duration
      end

      [((Graphics.frame_rate rescue 60) * 0.5).round, 1].max
    end
  end
end

module GamePlay
  class << self
    attr_accessor(:berry_dex_class)

    def open_berry_dex
      current_scene.call_scene(berry_dex_class)
    end
  end

  class BerryDex < BaseCleanUpdate::FrameBalanced
    ACTIONS = [:action_A, nil, nil, :action_B]
    TRACKING_ACTIONS = [nil, nil, nil, :action_B]
    FRAME_ASSET_FR = "berry_dex/frame_fr"
    FRAME_ASSET_EN = "berry_dex/frame_en"
    FRAME_Z = 490
    LIST_SIZE = 6
    TRACKING_LIST_SIZE = 5
    TRACKING_REFRESH_INTERVAL = 30
    BERRY_DEX_LIST_SELECTOR_OFFSET = [-2, -2]
    TRACKING_BUTTON_TEXTS = { fr: ": suivi", en: ": tracker" }

    TRACKING_TITLE_TEXTS = { fr: "SUIVI", en: "TRACKER" }

    TRACKING_EMPTY_TEXTS = { fr: "Aucune baie présente", en: "No berry present" }

    include(UI)

    def initialize
      super()
      @berries = berry_items
      @index = 0
      @page = :list
      @tracking_index = 0
      @tracking_entries = []
      Mouse.wheel = 0
    end

    def update_inputs
      return action_B if Input.trigger?(:B)
      return action_A if Input.trigger?(:A) && !tracking_page?
      return update_tracking_inputs if tracking_page?
      return if @berries.empty?
      max_index = @berries.size - 1
      return update_index if index_changed(:@index, :UP, :DOWN, max_index)

      if index_changed!(:@index, :LEFT, :RIGHT, max_index)
        9.times { index_changed!(:@index, :LEFT, :RIGHT, max_index) }
        update_index
      elsif Mouse.wheel != 0
        @index = (@index - Mouse.wheel).clamp(0, max_index)
        Mouse.wheel = 0
        update_index
      end
    end

    def update_mouse(_moved = false)
      update_mouse_ctrl_buttons(@ctrl, tracking_page? ? TRACKING_ACTIONS : ACTIONS, true)
    end

    def update_graphics
      @base_ui.update_background_animation
      if tracking_page?
        update_tracking_graphics
      else
        update_arrow
      end

      true
    end

    def create_graphics
      create_viewport
      create_base_ui
      create_frame
      create_info
      create_list
      create_arrow
      create_scroll_bar
      create_tracking_page
      update_index
    end

    private

    def berry_items
      each_data_item.select { |item| item && item.db_symbol != :__undef__ && item.is_berry }.sort_by { |item| [item.position, item.id] }
    end

    def create_viewport
      @viewport = Viewport.create(:main, 50000)
      @stack = SpriteStack.new(@viewport, default_cache: :pokedex)
    end

    def create_base_ui
      @base_ui = UI::BerryDexBase.new(@viewport, list_button_texts)
      @ctrl = @base_ui.ctrl
    end

    def create_frame
      @frame = Sprite.new(@viewport).set_bitmap(frame_asset, :interface)
      @frame.z = FRAME_Z
    end

    def frame_asset
      return FRAME_ASSET_FR if $options&.language == "fr"
      FRAME_ASSET_EN
    end

    def create_info
      @info = UI::BerryDexInfo.new(@viewport)
    end

    def create_list
      @list = Array.new(LIST_SIZE) { |index| UI::BerryDexButton.new(@viewport, index) }
    end

    def create_arrow
      @arrow = UI::DexListSelector.new(@viewport)
    end

    def create_scroll_bar
      @scrollbar = @stack.add_sprite(309, 36, "scroll")
      @scrollbut = @stack.add_sprite(308, 41, "but_scroll")
    end

    def create_tracking_page
      @tracking_stack = SpriteStack.new(@viewport)
      offset = $options.language == "en" ? 16 : 0
      @tracking_stack.with_font(20) do
        @tracking_title = @tracking_stack.add_text(UI::BERRY_DEX_TRACKING_TITLE_OFFSET[0] + offset, 17 + UI::BERRY_DEX_TRACKING_TITLE_OFFSET[1], 320, 13, localized(TRACKING_TITLE_TEXTS), 1, nil, color: 10)

        @tracking_empty = @tracking_stack.add_text(0, 113, 320, 13, localized(TRACKING_EMPTY_TEXTS), 1, nil, color: 10)
      end

      UI.style_berry_dex_text(@tracking_title, @tracking_empty)
      @tracking_title.z = FRAME_Z + 1
      @tracking_rows = Array.new(TRACKING_LIST_SIZE) { |index| UI::BerryDexTrackingRow.new(@viewport, index) }
      @tracking_selector = UI::BerryDexTrackingSelector.new(@viewport)
      @tracking_stack.visible = false
      @tracking_rows.each { |row| row.visible = false }
      @tracking_selector.visible = false
    end

    def update_index
      update_info
      update_list
    end

    def update_info
      @info.data = @berries[@index]
    end

    def update_list
      visible = !@berries.empty?
      @arrow.visible = @scrollbar.visible = @scrollbut.visible = visible
      return @list.each { |button| button.visible = false } unless visible
      @scrollbut.y = 41 + 150 * @index / (@berries.size - 1) if @berries.size > 1
      base_index = calc_base_index

      @list.each_with_index do |button, offset|
        pos = base_index + offset
        item = @berries[pos]
        next button.visible = false unless item && pos >= 0

        if button.selected = pos == @index
          @arrow.position_on(button, BERRY_DEX_LIST_SELECTOR_OFFSET)
        end

        button.data = [pos + 1, item]
      end
    end

    def update_tracking_inputs
      Mouse.wheel = 0 if @tracking_entries.empty?
      return if @tracking_entries.empty?
      max_index = tracking_max_index
      return update_tracking_list if index_changed(:@tracking_index, :UP, :DOWN, max_index)

      if index_changed!(:@tracking_index, :LEFT, :RIGHT, max_index)
        5.times { index_changed!(:@tracking_index, :LEFT, :RIGHT, max_index) }
        update_tracking_list
      elsif Mouse.wheel != 0
        @tracking_index = (@tracking_index - Mouse.wheel).clamp(0, max_index)
        Mouse.wheel = 0
        update_tracking_list
      end
    end

    def update_tracking_graphics
      Yuki::TJN.update if defined?(Yuki::TJN)
      @tracking_selector.update_graphics if @tracking_selector&.visible
      return update_tracking_list if (Graphics.frame_count % TRACKING_REFRESH_INTERVAL).zero?
    end

    def update_tracking_list
      @tracking_entries = UI.berry_dex_present_berry_entries
      @tracking_index = @tracking_index.clamp(0, tracking_max_index)
      empty = @tracking_entries.empty?
      @tracking_empty.visible = empty
      @scrollbar.visible = @scrollbut.visible = !empty
      @tracking_selector.visible = !empty
      @scrollbut.y = tracking_scroll_y unless empty
      base_index = tracking_base_index

      @tracking_rows.each_with_index do |row, offset|
        pos = base_index + offset
        row.data = @tracking_entries[pos]
        next @tracking_selector.position_on(row) if pos == @tracking_index && row.visible
      end
    end

    def update_arrow
      return unless @arrow&.visible

      @arrow.update_graphics
    end

    def calc_base_index
      return -1 if @berries.size < 5
      return @index - 2 if @index >= 2

      -1
    end

    def tracking_scroll_y
      max_index = tracking_max_index
      return 41 if max_index.zero?

      41 + 150 * @tracking_index / max_index
    end

    def tracking_max_index
      [@tracking_entries.size - 1, 0].max
    end

    def tracking_base_index
      return 0 if @tracking_entries.size <= TRACKING_LIST_SIZE

      [[@tracking_index - 2, 0].max, @tracking_entries.size - TRACKING_LIST_SIZE].min
    end

    def log_tracking_entries_locations
      @tracking_entries.each do |entry|
        position = UI.berry_dex_event_position(entry[:map_id], entry[:event_id])
        location = UI.berry_dex_map_name(entry[:map_id])
        location = "#{location} (#{position[0]}, #{position[1]})" if position
        log_error("[BerryDex] #{entry[:item].exact_name} : map #{entry[:map_id]} - #{location}")
      end
    end

    def action_A
      play_decision_se
      open_tracking_page
    end

    def action_B
      play_cancel_se
      return close_tracking_page if tracking_page?

      @running = false
    end

    def open_tracking_page
      @page = :tracking
      @tracking_index = 0
      Mouse.wheel = 0
      @tracking_entries = UI.berry_dex_present_berry_entries
      log_tracking_entries_locations
      refresh_page_visibility
      update_tracking_list
    end

    def close_tracking_page
      @page = :list
      Mouse.wheel = 0
      refresh_page_visibility
      update_index
    end

    def refresh_page_visibility
      tracking = tracking_page?
      @frame.visible = true
      @info.visible = !tracking
      @arrow.visible = false
      @list.each { |button| button.visible = false } if tracking
      @tracking_stack.visible = tracking
      @tracking_rows.each { |row| row.visible = false } unless tracking
      @tracking_selector.visible = false unless tracking
      @base_ui.button_texts = tracking ? tracking_button_texts : list_button_texts
    end

    def tracking_page?
      @page == :tracking
    end

    def list_button_texts
      [localized(TRACKING_BUTTON_TEXTS), nil, nil, ext_text(9000, 9)]
    end

    def tracking_button_texts
      [nil, nil, nil, ext_text(9000, 9)]
    end

    def localized(source)
      source[$options&.language == "en" ? :en : :fr] || source[:fr]
    end
  end
end

GamePlay.berry_dex_class = GamePlay::BerryDex
