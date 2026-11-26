# Advanced Pokédex : page Données (d'après « Pokedex Data Page » pour Essentials, de Lucidious89)
#
# Dans le Pokédex Horizon, la page Données vient juste après la fiche (DROITE), avant Taille et Poids :
#   à gauche  les stats de base (barres colorées) et leur total ;
#   à droite  talents (dont le talent caché), groupes d'œufs, répartition des sexes, pas pour l'éclosion, taux de
#             capture et expérience de base, courbe d'expérience, EV donnés ;
#   en bas    l'habitat (réglé dans Studio, voir 00103 Infos Pokedex.rb) et la famille d'évolution.
# Touches : A ouvre la liste des capacités (niveau, CT, œuf, tuteur ; GAUCHE / DROITE changent de liste),
#           X les talents avec leur description, Y les évolutions de la famille avec leurs conditions.
# Graphismes : graphics/pokedex/pe/adv_data (fond) et graphics/pokedex/advanced/data/
#              (tools/advanced_pokedex/build_data_page.py)
module AdvancedPokedex
  module Data
    DIR = 'advanced/data/'
    WHITE = 10
    DARK = 0
    SMALL = 20
    # Textes [français, anglais]
    TEXTS = {
      page: %w[Données Data],
      stats: ['STATS DE BASE', 'BASE STATS'], profile: %w[PROFIL PROFILE],
      stat_names: [%w[PV Atq. Déf. A.Spé D.Spé Vit.], %w[HP Atk Def SpA SpD Spe]],
      total: %w[Total Total],
      abilities: %w[Talents Abilities], hidden: %w[Caché Hidden], eggs: %w[Oeufs Eggs], gender: %w[Sexe Gender],
      hatch: %w[Éclosion Hatch], catch: %w[Capture Catch], growth: %w[Croiss. Growth], ev: %w[EV EV],
      genderless: %w[Asexué Genderless], steps: ['%s pas', '%s steps'], base_exp: ['Exp. %d', 'Exp. %d'],
      unknown: %w[??? ???], none: %w[— —],
      help: ['A : Capacités   X : Talents   Y : Évolutions', 'A: Moves   X: Abilities   Y: Evolutions'],
      moves: %w[CAPACITÉS MOVES], move_tabs: [%w[Niveau CT Oeuf Tuteur], %w[Level TM Egg Tutor]],
      no_move: ['Aucune capacité.', 'No moves.'], start: %w[Départ Start], evo_level: %w[Évol. Evo.],
      abilities_title: %w[TALENTS ABILITIES], evolutions: %w[ÉVOLUTIONS EVOLUTIONS],
      no_evolution: ['Ce Pokémon n’évolue pas.', 'This Pokémon does not evolve.'],
      window_help: ['Haut / bas : choisir   B : retour', 'Up / down: select   B: back'],
      moves_help: ['Gauche / droite : liste   B : retour', 'Left / right: list   B: back'],
      categories: [%w[Physique Spéciale Statut], %w[Physical Special Status]],
      power: %w[Puiss. Power], accuracy: %w[Préc. Acc.]
    }.freeze
    # Courbes d'expérience de PSDK (experience_type)
    GROWTH = [%w[Rapide Fast], %w[Moyenne Medium], %w[Lente Slow], %w[Parabolique Parabolic], %w[Erratique Erratic],
              %w[Fluctuante Fluctuating]].freeze
    # Groupes d'œufs de PSDK (breed_groups) : [français, anglais, ligne de egg_groups.png]
    EGG_GROUPS = {
      0 => ['?', '?', 0], 1 => %w[Monstre Monster] + [2], 2 => ['Aquatique 1', 'Water 1', 3], 3 => %w[Insectoïde Bug] + [4],
      4 => %w[Aérien Flying] + [5], 5 => %w[Terrestre Field] + [6], 6 => %w[Féerique Fairy] + [7],
      7 => %w[Végétal Grass] + [8], 8 => ['Humanoïde', 'Human-Like', 9], 9 => ['Aquatique 3', 'Water 3', 10],
      10 => %w[Minéral Mineral] + [11], 11 => %w[Amorphe Amorphous] + [12], 12 => ['Aquatique 2', 'Water 2', 13],
      13 => %w[Métamorph Ditto] + [14], 14 => %w[Draconique Dragon] + [15], 15 => %w[Inconnu Undiscovered] + [1]
    }.freeze
    # Habitats (PokedexInfos) -> ligne de habitats.png
    HABITAT_ROWS = { grassland: 1, forest: 2, 'waters-edge': 3, sea: 4, cave: 5, mountain: 6, 'rough-terrain': 7,
                     urban: 8, rare: 9 }.freeze
    STATS = %i[base_hp base_atk base_dfe base_ats base_dfs base_spd].freeze
    EVS = %i[ev_hp ev_atk ev_dfe ev_ats ev_dfs ev_spd].freeze
    # Moments de la journée (condition dayNight)
    DAY_TIMES = { 0 => %w[la\ nuit night], 1 => %w[le\ matin morning], 2 => %w[le\ soir evening], 3 => %w[le\ jour day] }.freeze

    module_function

    def fr?
      return $options.nil? || $options.language.to_s == 'fr'
    end

    # @param key [Symbol]
    # @return [Object]
    def text(key)
      value = TEXTS[key]
      return value[fr? ? 0 : 1]
    end

    def file(name)
      return "#{DIR}#{name}"
    end

    # @param value [Integer]
    # @return [String] 4 480
    def number(value)
      return value.to_i.to_s.reverse.scan(/\d{1,3}/).join(fr? ? ' ' : ',').reverse
    end

    # @param form [Studio::CreatureForm]
    # @return [Array<Symbol>] talents (normal 1, normal 2, caché)
    def abilities(form)
      return Array(form.abilities).map { |a| a.to_s.to_sym }
    end

    # @param symbol [Symbol]
    # @return [String]
    def ability_name(symbol)
      return text(:none) if symbol.nil? || symbol == :__undef__

      return data_ability(symbol).name.to_s
    rescue StandardError
      return symbol.to_s
    end

    def ability_description(symbol)
      return data_ability(symbol).description.to_s
    rescue StandardError
      return ''
    end

    # @param form [Studio::CreatureForm]
    # @return [String] « Fuite / Adaptabilité »
    def normal_abilities(form)
      list = abilities(form).first(2).reject { |a| a == :__undef__ }.uniq
      return text(:none) if list.empty?

      return list.map { |a| ability_name(a) }.join(' / ')
    end

    def hidden_ability(form)
      list = abilities(form)
      return text(:none) if list.size < 3 || list[2] == :__undef__ || list.first(2).include?(list[2])

      return ability_name(list[2])
    end

    # @param id [Integer] groupe d'œufs de PSDK
    def egg_group_name(id)
      entry = EGG_GROUPS[id.to_i] || EGG_GROUPS[0]
      return entry[fr? ? 0 : 1]
    end

    def egg_group_row(id)
      return (EGG_GROUPS[id.to_i] || EGG_GROUPS[0])[2]
    end

    def growth_name(type)
      entry = GROWTH[type.to_i] || GROWTH[1]
      return entry[fr? ? 0 : 1]
    end

    # @return [String] « +1 D.Spé, +2 Atq. »
    def ev_text(form)
      names = text(:stat_names)
      list = EVS.each_with_index.map { |key, i| [form.send(key).to_i, names[i]] }.select { |value, _| value > 0 }
      return text(:none) if list.empty?

      return list.map { |value, name| "+#{value} #{name}" }.join(', ')
    rescue StandardError
      return text(:none)
    end

    # --- Famille d'évolution -------------------------------------------------------------------------
    # @param form [Studio::CreatureForm]
    # @param symbol [Symbol] espèce
    # @return [Array(Array<Array(Symbol, Integer)>, Array<Array>)] stades ([espèce, forme]) et liens
    #   [de, vers, conditions]
    def family(symbol, form)
      root = [form.baby_db_symbol.to_s.to_sym, form.baby_form.to_i]
      root = [symbol, form.form.to_i] if root.first.nil? || root.first == :__undef__ || root.first == :'' ||
                                          !creature_exist?(root.first)
      stages = [[root]]
      links = []
      known = [root]
      while stages.size < 6
        nexts = []
        stages.last.each do |(sym, frm)|
          evolutions_of(sym, frm).each do |evolution|
            target = [evolution.db_symbol.to_s.to_sym, evolution.form.to_i]
            next if known.include?(target) || !creature_exist?(target.first)

            known << target
            nexts << target
            links << [[sym, frm], target, evolution.conditions]
          end
        end
        break if nexts.empty?

        stages << nexts
      end
      return stages, links
    rescue StandardError => e
      log_error("Données du Pokédex : #{e.message}") if respond_to?(:log_error, true)
      return [[[symbol, form.form.to_i]]], []
    end

    def creature_exist?(symbol)
      return data_creature(symbol).db_symbol != :__undef__
    rescue StandardError
      return false
    end

    # Évolutions d'une forme (sans les Méga-Évolutions, condition « gemme »)
    def evolutions_of(symbol, form)
      data = data_creature_form(symbol, form)
      return Array(data.evolutions).reject { |evo| Array(evo.conditions).any? { |c| condition_type(c) == :gemme } }
    rescue StandardError
      return []
    end

    def condition_type(condition)
      return (condition.is_a?(Hash) ? (condition[:type] || condition['type']) : condition.type).to_s.to_sym
    end

    def condition_value(condition)
      return condition.is_a?(Hash) ? (condition[:value] || condition['value']) : condition.value
    end

    # @param conditions [Array]
    # @return [String] « N. 16 », « Pierre Eau », « Bonheur, la nuit »…
    def conditions_text(conditions)
      parts = Array(conditions).map { |c| condition_text(condition_type(c), condition_value(c)) }.compact
      return parts.empty? ? (fr? ? 'Condition spéciale' : 'Special condition') : parts.join(', ')
    end

    def condition_text(type, value)
      fr = fr?
      case type
      when :minLevel then return fr ? "Niveau #{value}" : "Level #{value}"
      when :maxLevel then return fr ? "Niveau #{value} max." : "Max. level #{value}"
      when :stone then return item_name(value)
      when :itemHold then return fr ? "Tient #{item_name(value)}" : "Holding #{item_name(value)}"
      when :trade then return value ? (fr ? 'Échange' : 'Trade') : nil
      when :tradeWith then return fr ? "Échange contre #{creature_name(value)}" : "Trade for #{creature_name(value)}"
      when :minLoyalty then return fr ? 'Bonheur' : 'Friendship'
      when :maxLoyalty then return fr ? 'Peu de bonheur' : 'Low friendship'
      when :dayNight
        time = DAY_TIMES[value.to_i]
        return time ? (fr ? "Pendant #{time[0]}" : "At #{time[1]}") : nil
      when :gender then return value.to_i == 1 ? (fr ? 'Mâle' : 'Male') : (fr ? 'Femelle' : 'Female')
      when :skill1, :skill2, :skill3, :skill4 then return fr ? "Connaît #{move_name(value)}" : "Knows #{move_name(value)}"
      when :weather then return fr ? "Météo : #{value}" : "Weather: #{value}"
      when :maps, :env then return fr ? 'Lieu particulier' : 'Special place'
      when :func then return fr ? 'Condition spéciale' : 'Special condition'
      end
      return nil
    end

    def item_name(symbol)
      return data_item(symbol).name.to_s
    rescue StandardError
      return symbol.to_s
    end

    def move_name(symbol)
      return data_move(symbol).name.to_s
    rescue StandardError
      return symbol.to_s
    end

    def creature_name(symbol)
      return data_creature(symbol).name.to_s
    rescue StandardError
      return symbol.to_s
    end

    # @return [Boolean] espèce vue dans le Pokédex
    def seen?(symbol)
      return $pokedex.creature_seen?(symbol)
    rescue StandardError
      return true
    end

    # @return [Texture, nil] icône d'une espèce
    def icon(symbol, form)
      id = data_creature(symbol).id
      return RPG::Cache.b_icon(PFM::Pokemon.icon_filename(id, form, false, false, false))
    rescue StandardError
      return nil
    end

    # --- Capacités ------------------------------------------------------------------------------------
    # @param form [Studio::CreatureForm]
    # @return [Array<Array<Array(String, Symbol)>>] 4 listes : [étiquette, capacité]
    def move_lists(form)
      set = Array(form.move_set)
      level = set.select(&:level_learnable?).sort_by(&:level).map { |m| [m.level.to_i <= 0 ? text(:evo_level) : "N.#{m.level}", m.move] }
      level = set.select(&:evolution_learnable?).map { |m| [text(:evo_level), m.move] } + level
      tech = set.select(&:tech_learnable?).map { |m| ['', m.move] }.sort_by { |_, move| move_name(move) }
      breed = set.select(&:breed_learnable?).map { |m| ['', m.move] }.uniq.sort_by { |_, move| move_name(move) }
      tutor = set.select(&:tutor_learnable?).map { |m| ['', m.move] }.uniq.sort_by { |_, move| move_name(move) }
      return [level, tech, breed, tutor]
    rescue StandardError => e
      log_error("Données du Pokédex : #{e.message}") if respond_to?(:log_error, true)
      return [[], [], [], []]
    end

    # @return [String] « Feu · Spéciale · Puiss. 90 · Préc. 100 · PP 15 »
    def move_summary(symbol)
      move = data_move(symbol)
      categories = text(:categories)
      category = { physical: 0, special: 1, status: 2 }[move.category.to_sym] || 2
      power = move.power.to_i > 0 ? move.power.to_s : '—'
      accuracy = move.accuracy.to_i > 0 ? move.accuracy.to_s : '—'
      type = data_type(move.type).name.to_s
      return "#{type} · #{categories[category]} · #{text(:power)} #{power} · #{text(:accuracy)} #{accuracy} · PP #{move.pp}"
    rescue StandardError
      return ''
    end

    def move_description(symbol)
      return data_move(symbol).description.to_s
    rescue StandardError
      return ''
    end
  end

  # Contenu de la page Données
  class DataPage < UI::SpriteStack
    D = Data
    STAT_Y = 44
    STAT_STEP = 14
    INFO_Y = 42
    INFO_STEP = 13
    BAR_W = 76
    ICON_STEP = 28
    PILL_W = 51
    GENDER_W = 48

    # @param viewport [Viewport]
    # @param silhouette [Shader] ombre des Pokémon jamais vus
    def initialize(viewport, silhouette)
      super(viewport, default_cache: :pokedex)
      @silhouette = silhouette
      create_panels
      create_band
      self.visible = false
    end

    # @param pokemon [PFM::Pokemon]
    # @param known [Boolean] données connues (Pokémon capturé)
    def show(pokemon, known)
      form = pokemon.data
      @form = form
      refresh_stats(form, known)
      refresh_profile(form, known)
      refresh_band(pokemon, form, known)
      self.visible = true
      hide_unused
    end

    # @param value [Boolean]
    def visible=(value)
      @shown = value
      super
      hide_unused if value
    end

    private

    def create_panels
      add_text(10, 28, 100, 13, D.text(:stats), color: D::WHITE) .tap { |t| t.bold = true if t.respond_to?(:bold=) }
      add_text(163, 28, 100, 13, D.text(:profile), color: D::WHITE).tap { |t| t.bold = true if t.respond_to?(:bold=) }
      names = D.text(:stat_names)
      @stat_values = []
      @stat_bars = []
      with_font(D::SMALL) do
        6.times do |i|
          y = STAT_Y + i * STAT_STEP
          add_text(10, y, 34, 13, names[i], color: D::DARK)
          @stat_values << add_text(42, y, 26, 13, '', 2, color: D::DARK)
          bar = add_sprite(72, y + 3, D.file('stat_bars'))
          bar.src_rect.set(0, i * 5, BAR_W, 5)
          @stat_bars << bar
        end
        add_text(10, STAT_Y + 6 * STAT_STEP + 2, 40, 13, D.text(:total), color: D::DARK)
        @total = add_text(42, STAT_Y + 6 * STAT_STEP + 2, 26, 13, '', 2, color: D::DARK)
        labels = %i[abilities hidden eggs gender hatch catch growth ev]
        @info = {}
        labels.each_with_index do |key, i|
          y = INFO_Y + i * INFO_STEP
          add_text(162, y, 46, 13, D.text(key), color: D::DARK)
          @info[key] = add_text(208, y, 104, 13, '', color: D::DARK)
        end
        @eggs = Array.new(2) do |i|
          pill = add_sprite(208 + i * 53, INFO_Y + 2 * INFO_STEP + 2, D.file('egg_groups'))
          pill.src_rect.set(0, 0, PILL_W, 11)
          [pill, add_text(208 + i * 53, INFO_Y + 2 * INFO_STEP, PILL_W, 13, '', 1, color: D::WHITE)]
        end
        gy = INFO_Y + 3 * INFO_STEP + 4
        @male_bar = add_sprite(208, gy, D.file('gender_bar'))
        @female_bar = add_sprite(208, gy, D.file('gender_bar'))
        @gender_label = add_text(258, INFO_Y + 3 * INFO_STEP, 54, 13, '', 2, color: D::DARK)
      end
    end

    def create_band
      @habitat = add_sprite(12, 165, D.file('habitats'))
      @habitat.src_rect.set(0, 0, 36, 36)
      @family = Array.new(10) { add_sprite(0, 0, nil) }
      @arrows = Array.new(5) { add_sprite(0, 0, D.file('arrow')) }
      with_font(D::SMALL) do
        # nom à droite du cadre de l'icône (dessous, il chevauchait le cadre)
        @habitat_name = add_text(56, 196, 62, 13, '', color: D::WHITE)
        @help = add_text(58, 196, 254, 13, D.text(:help), 2, color: D::WHITE)
        @more = add_text(282, 170, 30, 13, '', 2, color: D::WHITE)
      end
    end

    def refresh_stats(form, known)
      total = 0
      D::STATS.each_with_index do |key, i|
        value = form.send(key).to_i
        total += value
        @stat_values[i].text = known ? value.to_s : D.text(:unknown)
        @stat_bars[i].src_rect.width = known ? (BAR_W * [value, 200].min / 200.0).ceil.clamp(1, BAR_W) : 0
      end
      @total.text = known ? total.to_s : D.text(:unknown)
    end

    def refresh_profile(form, known)
      unknown = D.text(:unknown)
      @info[:abilities].text = known ? D.normal_abilities(form) : unknown
      @info[:hidden].text = known ? D.hidden_ability(form) : unknown
      groups = Array(form.breed_groups).map(&:to_i).uniq
      groups = [0] if groups.empty? || !known
      @egg_list = groups.first(2)
      @info[:eggs].text = ''
      @eggs.each_with_index do |(pill, label), i|
        id = @egg_list[i]
        pill.src_rect.set(0, D.egg_group_row(id || 0) * 11, PILL_W, 11)
        label.text = id ? D.egg_group_name(id) : ''
      end
      refresh_gender(form, known)
      @info[:hatch].text = known ? format(D.text(:steps), D.number(form.hatch_steps)) : unknown
      @info[:catch].text = known ? "#{form.catch_rate} · #{format(D.text(:base_exp), form.base_experience.to_i)}" : unknown
      @info[:growth].text = known ? D.growth_name(form.experience_type) : unknown
      @info[:ev].text = known ? D.ev_text(form) : unknown
    end

    def refresh_gender(form, known)
      rate = form.female_rate.to_f
      @gender_bars = known && rate >= 0
      if !known
        @info[:gender].text = D.text(:unknown)
      elsif rate < 0
        @info[:gender].text = D.text(:genderless)
      else
        male = ((100 - rate) * GENDER_W / 100.0).round
        @male_bar.src_rect.set(0, 0, male, 6)
        @female_bar.set_position(@x + 208 + male, @female_bar.y)
        @female_bar.src_rect.set(male, 6, GENDER_W - male, 6)
        @info[:gender].text = ''
        @gender_label.text = "#{format_rate(100 - rate)}/#{format_rate(rate)}"
      end
      @gender_label.text = '' unless @gender_bars
    end

    def format_rate(value)
      text = (value % 1).zero? ? value.to_i.to_s : value.round(1).to_s
      return D.fr? ? text.tr('.', ',') : text
    end

    def refresh_band(pokemon, form, known)
      habitat = known && defined?(::PokedexInfos) ? ::PokedexInfos.habitat(pokemon.db_symbol, pokemon.form) : nil
      row = D::HABITAT_ROWS[habitat.to_s.to_sym] || 0
      @habitat.src_rect.set(0, row * 36, 36, 36)
      @habitat_name.text = habitat ? ::PokedexInfos.habitat_name(pokemon.db_symbol, pokemon.form).to_s : ''
      @help.x = @x + (habitat ? 120 : 58)
      @help.width = habitat ? 192 : 254
      refresh_family(pokemon, form)
    end

    # Icônes de la famille, stade par stade (flèche entre deux stades)
    def refresh_family(pokemon, form)
      stages, = D.family(pokemon.db_symbol, form)
      # place gardée à droite pour « +n » quand toute la famille ne tient pas
      limit = stages.flatten(1).size * ICON_STEP + (stages.size - 1) * 12 > 250 ? 256 : 284
      x = 62
      shown = 0
      hidden = 0
      @family.each { |s| s.visible = false }
      @arrows.each { |s| s.visible = false }
      @arrow_on = []
      @family_on = []
      stages.each_with_index do |stage, index|
        if index > 0 && (arrow = @arrows[index - 1])
          arrow.set_position(@x + x, @y + 172)
          @arrow_on << arrow
          x += 12
        end
        stage.each do |(symbol, frm)|
          if shown >= @family.size || x > limit
            hidden += 1
            next
          end
          sprite = @family[shown]
          shown += 1
          texture = D.icon(symbol, frm)
          next unless texture

          sprite.bitmap = texture
          size = [texture.height, texture.width].min
          sprite.src_rect.set(0, 0, size, size)
          sprite.set_position(@x + x, @y + 162)
          seen = D.seen?(symbol)
          sprite.shader = seen ? nil : @silhouette
          sprite.opacity = symbol == pokemon.db_symbol ? 255 : 200
          @family_on << sprite
          x += ICON_STEP
        end
      end
      @more.text = hidden > 0 ? "+#{hidden}" : ''
    end

    def hide_unused
      @family&.each { |s| s.visible = @shown && @family_on&.include?(s) ? true : false }
      @arrows&.each { |s| s.visible = @shown && @arrow_on&.include?(s) ? true : false }
      on = @shown && @gender_bars ? true : false
      @male_bar&.visible = on
      @female_bar&.visible = on
      @eggs&.each_with_index do |(pill, label), i|
        pill.visible = label.visible = @shown && @egg_list && i < @egg_list.size ? true : false
      end
    end
  end

  # Fenêtre des listes (capacités, talents, évolutions)
  class DataWindow < UI::SpriteStack
    D = Data
    X = 8
    Y = 24
    ROWS = 7
    ROW_H = 14

    # @param viewport [Viewport]
    def initialize(viewport)
      super(viewport, X, Y, default_cache: :pokedex)
      @open = false
      @tabs = []
      add_sprite(0, 0, D.file('window'))
      @title = add_text(10, 4, 140, 16, '', color: D::WHITE)
      @selector = add_sprite(8, 0, D.file('row_selected'))
      @tab_sprites = Array.new(4) do |i|
        sprite = add_sprite(150 + i * 36, 5, D.file('tab'))
        sprite.src_rect.set(0, 0, 34, 14)
        sprite
      end
      with_font(D::SMALL) do
        @tab_texts = Array.new(4) { |i| add_text(150 + i * 36, 4, 34, 13, '', 1, color: D::WHITE) }
        @left = Array.new(ROWS) { |i| add_text(14, 26 + i * ROW_H, 44, 13, '', color: D::DARK) }
        @summary = add_text(14, 129, 276, 13, '', color: D::DARK)
        @description = add_text(14, 142, 276, 13, '', color: D::DARK)
        @help = add_text(14, 168, 276, 13, '', 2, color: D::DARK)
      end
      @names = Array.new(ROWS) { |i| add_text(56, 25 + i * ROW_H, 232, 16, '', color: D::DARK) }
      self.visible = false
    end

    # @return [Boolean]
    def open?
      return @open
    end

    # @param title [String]
    # @param lists [Array<Array<Hash>>] listes de lignes { left:, name:, summary:, text: }
    # @param tabs [Array<String>] noms des listes (vide : une seule liste)
    # @param help [String]
    def open(title, lists, tabs = [], help = D.text(:window_help))
      @title.text = title
      @lists = lists
      @tabs = tabs
      @tab = 0
      @index = 0
      @top = 0
      @help.text = help
      @open = true
      self.visible = true
      refresh
    end

    def close
      @open = false
      self.visible = false
    end

    # @return [Symbol, nil] :move, :tab, :close, :buzzer
    def update_input
      return close_input if Input.trigger?(:B)

      rows = current
      if Input.repeat?(:UP) || Input.repeat?(:DOWN)
        return :buzzer if rows.size <= 1

        @index = (@index + (Input.repeat?(:UP) ? -1 : 1)) % rows.size
        refresh
        return :move
      end
      if (Input.trigger?(:LEFT) || Input.trigger?(:RIGHT)) && @tabs.size > 1
        @tab = (@tab + (Input.trigger?(:LEFT) ? -1 : 1)) % @tabs.size
        @index = 0
        @top = 0
        refresh
        return :tab
      end
      return mouse_input
    end

    # @param value [Boolean]
    def visible=(value)
      super(value && @open)
      return unless @open && value

      @tab_sprites&.each_with_index { |s, i| s.visible = i < @tabs.size }
      @tab_texts&.each_with_index { |t, i| t.visible = i < @tabs.size }
      @selector&.visible = !current.empty?
    end

    private

    def close_input
      close
      return :close
    end

    def mouse_input
      return nil unless Mouse.trigger?(:LEFT)

      mx = Mouse.x - @x
      my = Mouse.y - @y
      @tabs.each_index do |i|
        next unless mx.between?(150 + i * 36, 183 + i * 36) && my.between?(4, 18)

        @tab = i
        @index = @top = 0
        refresh
        return :tab
      end
      row = (my - 26) / ROW_H
      return nil unless my >= 26 && row < ROWS && mx.between?(8, 296) && @top + row < current.size

      @index = @top + row
      refresh
      return :move
    end

    def current
      return @lists[@tab] || []
    end

    def refresh
      rows = current
      @top = @index if @index < @top
      @top = @index - ROWS + 1 if @index >= @top + ROWS
      ROWS.times do |i|
        row = rows[@top + i]
        @left[i].text = row ? row[:left].to_s : ''
        @names[i].text = row ? row[:name].to_s : (i == 0 && rows.empty? ? D.text(:no_move) : '')
      end
      @tab_sprites.each_with_index do |sprite, i|
        sprite.src_rect.set(0, i == @tab ? 14 : 0, 34, 14)
      end
      @tab_texts.each_with_index { |t, i| t.text = @tabs[i].to_s }
      selected = rows[@index]
      @selector.set_position(@x + 8, @y + 26 + (@index - @top) * ROW_H)
      @summary.text = selected ? selected[:summary].to_s : ''
      @description.multiline_text = selected ? selected[:text].to_s : '' if @description.respond_to?(:multiline_text=)
      self.visible = true
    end
  end
end

module GamePlay
  class AdvancedPokedex
    # Page Données (Pokédex Horizon seulement)
    module DataPageScene
      private

      def refresh
        super
        refresh_data_page
      end

      def refresh_data_page
        data_page = @page == :data
        @texts&.visible = !data_page
        if data_page
          @pokemon_sprite.visible = false
          @character_sprite.visible = false
          @scale.visible = false
          @data_ui ||= ::AdvancedPokedex::DataPage.new(@viewport, @silhouette)
          @data_window ||= ::AdvancedPokedex::DataWindow.new(@viewport)
          @data_ui.show(@pokemon, known?)
        else
          @data_ui&.visible = false
          @data_window&.close
        end
      end

      # Capacités (A), talents (X), évolutions (Y)
      def open_data_window(kind)
        return play_buzzer_se unless known?

        play_decision_se
        d = ::AdvancedPokedex::Data
        form = @pokemon.data
        case kind
        when :moves
          lists = d.move_lists(form).map do |list|
            list.map { |left, move| { left: left, name: d.move_name(move), summary: d.move_summary(move), text: d.move_description(move) } }
          end
          @data_window.open(d.text(:moves), lists, d.text(:move_tabs), d.text(:moves_help))
        when :abilities
          names = d.abilities(form)
          rows = names.each_with_index.reject { |a, i| a == :__undef__ || names.first(i).include?(a) }.map do |ability, i|
            { left: i == 2 ? d.text(:hidden) : '', name: d.ability_name(ability), summary: '', text: d.ability_description(ability) }
          end
          @data_window.open(d.text(:abilities_title), [rows])
        when :evolutions
          _, links = d.family(@pokemon.db_symbol, form)
          rows = links.map do |(from, to, conditions)|
            seen = d.seen?(to.first) || d.seen?(from.first)
            { left: '', name: "#{seen_name(from.first)} > #{seen_name(to.first)}",
              summary: seen ? d.conditions_text(conditions) : d.text(:unknown), text: '' }
          end
          rows = [{ left: '', name: d.text(:no_evolution), summary: '', text: '' }] if rows.empty?
          @data_window.open(d.text(:evolutions), [rows])
        end
      end

      # @return [String] nom de l'espèce, ou ??? si elle n'a jamais été vue
      def seen_name(symbol)
        d = ::AdvancedPokedex::Data
        return d.seen?(symbol) ? d.creature_name(symbol) : d.text(:unknown)
      end

      public

      def update_inputs
        if @data_window&.open?
          case @data_window.update_input
          when :move, :tab then play_cursor_se
          when :close then play_cancel_se
          when :buzzer then play_buzzer_se
          end
          return false
        end
        return super unless @page == :data

        if Input.trigger?(:A)
          open_data_window(:moves)
        elsif Input.trigger?(:X)
          open_data_window(:abilities)
        elsif Input.trigger?(:Y)
          open_data_window(:evolutions)
        else
          return super
        end
        return false
      end

      def update_mouse(moved)
        return false if @data_window&.open?

        if @page == :data && Mouse.trigger?(:LEFT)
          mx = Mouse.x
          my = Mouse.y
          if my.between?(26, 153) && mx >= 157
            open_data_window(:abilities)
            return false
          elsif my.between?(157, 210)
            open_data_window(:evolutions)
            return false
          end
        end
        return @page == :data ? true : super
      end
    end
    prepend DataPageScene
  end
end
