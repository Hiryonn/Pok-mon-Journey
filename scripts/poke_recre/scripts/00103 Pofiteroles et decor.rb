# Poké Récré : Pofiteroles, décors et décorations (images de X / Y, tools/poke_recre/build_xy.py)
#
# Pofiteroles (comme dans X / Y) : 5 saveurs (Sucrée, Mentholée, Aigre, Amère, Épicée) × 4 niveaux (Simple, Crème,
# Décorée, Deluxe), plus 6 spéciales (Célébration, Anniversaire, Printemps, Été, Automne, Hiver). Elles se gardent
# dans Poké Récré (pas dans le sac) et se donnent sur le plateau des friandises. Plus le niveau est haut, plus
# l'affection monte ; un Pokémon aime davantage la saveur que préfère sa nature (Mentholée = sec).
# On en gagne aux mini-jeux (selon les étoiles) ou par commande (donner_pofiterole).
#
# Décor : automatique (selon l'endroit) ou choisi parmi les anciens et les 34 de X / Y ; deux décorations posées à
# gauche et à droite du Pokémon. Les décorations se gagnent aux mini-jeux ou par commande (donner_decoration), ou
# sont toutes disponibles (réglage all_decorations).
#
# Réglages (Data/configs/plugins/poke_recre.json, « settings ») :
#   puff_affection   [[min, max] Simple, Crème, Décorée, Deluxe, spéciale]
#   puff_fullness    satiété d'une Pofiterole        puff_liked_bonus  % d'affection en plus pour la saveur aimée
#   all_decorations  toutes les décorations sont disponibles
#   start_decorations décorations données au départ
#   decoration_chance % de chance de gagner une décoration à un mini-jeu réussi (3 étoiles ou plus)
#   cure_pets        caresses pour guérir un Pokémon empoisonné, brûlé, gelé ou paralysé (0 : jamais)
#   hand_style       « xy » (main de X / Y) ou « classic »
module PokeRecre
  PUFF_FLAVORS = [
    ['sucree', 'Sucrée', 'Sweet', :sweet], ['mentholee', 'Mentholée', 'Mint', :dry], ['aigre', 'Aigre', 'Citrus', :sour],
    ['amere', 'Amère', 'Mocha', :bitter], ['epicee', 'Épicée', 'Spice', :spicy]
  ].freeze
  PUFF_LEVELS = [%w[simple Simple Basic], %w[creme Crème Frosted], %w[decoree Décorée Fancy], %w[deluxe Deluxe Deluxe]].freeze
  PUFF_SPECIALS = [%w[celebration Célébration Celebration], %w[anniversaire Anniversaire Birthday],
                   %w[printemps Printemps Spring], %w[ete Été Summer], %w[automne Automne Autumn], %w[hiver Hiver Winter]].freeze
  PUFF_SIZE = 64

  TYPE_NAMES = {
    'normal' => %w[Normal Normal], 'fire' => %w[Feu Fire], 'water' => %w[Eau Water], 'electric' => %w[Électrik Electric],
    'grass' => %w[Plante Grass], 'ice' => %w[Glace Ice], 'fighting' => %w[Combat Fighting], 'poison' => %w[Poison Poison],
    'ground' => %w[Sol Ground], 'flying' => %w[Vol Flying], 'psychic' => %w[Psy Psychic], 'bug' => %w[Insecte Bug],
    'rock' => %w[Roche Rock], 'ghost' => %w[Spectre Ghost], 'dragon' => %w[Dragon Dragon], 'dark' => %w[Ténèbres Dark],
    'steel' => %w[Acier Steel], 'fairy' => %w[Fée Fairy]
  }.freeze
  COLOR_NAMES = {
    'rouge' => %w[rouge red], 'bleu' => %w[bleu blue], 'orange' => %w[orange orange], 'vert' => %w[vert green],
    'violet' => %w[violet purple], 'marron' => %w[marron brown], 'jaune' => %w[jaune yellow], 'blanc' => %w[blanc white],
    'noir' => %w[noir black], 'rose' => %w[rose pink]
  }.freeze
  STYLE_NAMES = { 'pois' => %w[à\ pois dotted], 'rayures' => %w[rayé striped], 'carreaux' => %w[à\ carreaux checked] }.freeze
  OLD_BACKDROP_NAMES = {
    'field' => %w[Prairie Field], 'forest' => %w[Forêt Forest], 'cave' => %w[Grotte Cave], 'cave_dark' => %w[Grotte\ sombre Dark\ cave],
    'city' => %w[Ville City], 'mountain' => %w[Montagne Mountain], 'snow' => %w[Neige Snow], 'water' => %w[Mer Sea],
    'underwater' => %w[Fonds\ marins Underwater], 'indoor_a' => %w[Maison House], 'indoor_b' => %w[Maison\ 2 House\ 2],
    'indoor_c' => %w[Maison\ 3 House\ 3], 'champion' => %w[Salle\ du\ Maître Champion\ room],
    'elite_a' => %w[Conseil\ 4\ (1) Elite\ Four\ (1)], 'elite_b' => %w[Conseil\ 4\ (2) Elite\ Four\ (2)],
    'elite_c' => %w[Conseil\ 4\ (3) Elite\ Four\ (3)], 'elite_d' => %w[Conseil\ 4\ (4) Elite\ Four\ (4)]
  }.freeze

  module_function

  # --- Sauvegarde ---------------------------------------------------------------------------------------------------
  # @return [Hash] { 'puffs' => { id => nombre }, 'decorations' => [ids], 'backdrop' => 'auto' ou nom,
  #   'left' / 'right' => id ou nil, 'records' => { 'cueille' => points, 'jongle' => points }, 'plays' => {...} }
  def data
    $user_data[:pj_poke_recre] ||= {}
    d = $user_data[:pj_poke_recre]
    d['puffs'] ||= {}
    d['records'] ||= {}
    d['plays'] ||= {}
    d['backdrop'] ||= 'auto'
    unless d['decorations']
      d['decorations'] = Array(setting('start_decorations')).map(&:to_s).select { |id| decoration(id) }
    end
    return d
  end

  # --- Pofiteroles --------------------------------------------------------------------------------------------------
  # @return [Hash{String => Hash}] id => { name:, col:, row:, level: (0 à 4), flavor: (Symbol ou nil) }
  def puffs
    @puffs ||= begin
      list = {}
      PUFF_FLAVORS.each_with_index do |(fid, ffr, fen, taste), row|
        PUFF_LEVELS.each_with_index do |(lid, lfr, len), col|
          list["#{fid}_#{lid}"] = { fr: "Pofiterole #{ffr.downcase} (#{lfr})", en: "#{len} #{fen} Puff", col: col, row: row,
                                    level: col, flavor: taste }
        end
      end
      PUFF_SPECIALS.each_with_index do |(sid, sfr, sen), col|
        list[sid] = { fr: "Pofiterole #{sfr}", en: "#{sen} Puff", col: col, row: 5, level: 4, flavor: nil }
      end
      list
    end
  end

  def puff(id)
    return puffs[id.to_s]
  end

  def puff_name(id)
    entry = puff(id)
    return id.to_s unless entry

    return t(entry[:fr], entry[:en])
  end

  def puff_count(id)
    return data['puffs'][id.to_s].to_i
  end

  # @return [Integer] nouveau nombre
  def add_puff(id, count = 1)
    return 0 unless puff(id)

    value = [puff_count(id) + count.to_i, 0].max
    value.zero? ? data['puffs'].delete(id.to_s) : data['puffs'][id.to_s] = value
    return value
  end

  # Pofiteroles qu'on a, dans l'ordre de la planche
  def owned_puffs
    return puffs.keys.select { |id| puff_count(id) > 0 }
  end

  # Pofiterole au hasard pour un nombre d'étoiles (1 à 5)
  def random_puff(stars)
    level = [[0, 0, 0, 1, 2, 3][stars.to_i.clamp(0, 5)], 0].max
    return PUFF_SPECIALS.sample[0] if stars.to_i >= 5 && rand(100) < 15

    return "#{PUFF_FLAVORS.sample[0]}_#{PUFF_LEVELS[level][0]}"
  end

  # Récompenses d'un mini-jeu : Pofiteroles selon les étoiles (2 à 5 étoiles), parfois une décoration (3 étoiles ou plus)
  # @return [Array<String>] noms de ce qui a été gagné
  def give_rewards(stars)
    stars = stars.to_i
    gifts = []
    if stars > 0
      (stars >= 5 ? 2 : 1).times do
        id = random_puff(stars)
        add_puff(id)
        gifts << puff_name(id)
      end
    end
    if stars >= 3 && rand(100) < setting('decoration_chance').to_i
      id = random_new_decoration
      gifts << decoration_name(id) if id && unlock_decoration(id)
    end
    return gifts
  end

  # --- Décorations --------------------------------------------------------------------------------------------------
  # @return [Hash{String => Array}] id => [nom fr, nom en] (même ordre que la planche)
  def decorations
    @decorations ||= begin
      list = {}
      TYPE_NAMES.each { |type, (fr, en)| list["coeur_#{type}"] = ["Coussin cœur #{fr}", "#{en} heart cushion"] }
      TYPE_NAMES.each do |type, (fr, en)|
        list["#{type}_coussin_a"] = ["Coussin #{fr}", "#{en} cushion"]
        list["#{type}_coussin_b"] = ["Coussin #{fr} 2", "#{en} cushion 2"]
        list["#{type}_objet_a"] = ["Objet #{fr}", "#{en} item"]
        list["#{type}_objet_b"] = ["Objet #{fr} 2", "#{en} item 2"]
        list["#{type}_grand"] = ["Grand décor #{fr}", "Big #{en} decoration"]
      end
      shapes = { 'rond' => ['Coussin rond', 'round cushion'], 'plat' => ['Coussin plat', 'flat cushion'],
                 'etoile' => ['Coussin étoile', 'star cushion'], 'cube' => ['Cube', 'cube'] }
      %w[rouge bleu orange vert violet marron jaune blanc noir].each do |color|
        shapes.each { |shape, (fr, en)| list["#{shape}_#{color}"] = ["#{fr} #{COLOR_NAMES[color][0]}", "#{COLOR_NAMES[color][1].capitalize} #{en}"] }
      end
      clouds = { 'nuage_a' => ['Nuage', 'cloud'], 'nuage_b' => ['Nuage 2', 'cloud 2'], 'nuage_etoile' => ['Étoile nuage', 'cloud star'],
                 'nuage_cube' => ['Cube nuage', 'cloud cube'] }
      %w[rose bleu orange].each do |color|
        clouds.each { |shape, (fr, en)| list["#{shape}_#{color}"] = ["#{fr} #{COLOR_NAMES[color][0]}", "#{COLOR_NAMES[color][1].capitalize} #{en}"] }
      end
      STYLE_NAMES.each do |style, (sfr, sen)|
        shapes.each { |shape, (fr, en)| list["#{shape}_#{style}"] = ["#{fr} #{sfr}", "#{sen.capitalize} #{en}"] }
      end
      list['chic_chaise_a'] = ['Chaise chic', 'Chic chair']
      list['chic_chaise_b'] = ['Chaise chic 2', 'Chic chair 2']
      list['chic_table'] = ['Table chic', 'Chic table']
      list['chic_lit'] = ['Lit chic', 'Chic bed']
      list
    end
  end

  def decoration(id)
    return decorations[id.to_s]
  end

  def decoration_name(id)
    names = decoration(id)
    return names ? t(*names) : '—'
  end

  def decoration_file(id)
    return file("deco/#{id}")
  end

  def owned_decorations
    return decorations.keys if setting('all_decorations')

    owned = data['decorations']
    return decorations.keys.select { |id| owned.include?(id) }
  end

  def decoration_owned?(id)
    return owned_decorations.include?(id.to_s)
  end

  # @return [Boolean] true si elle est nouvelle
  def unlock_decoration(id)
    id = id.to_s
    return false unless decoration(id) && !data['decorations'].include?(id)

    data['decorations'] << id
    return true
  end

  # Décoration au hasard pas encore gagnée (nil s'il n'y en a plus)
  def random_new_decoration
    return decorations.keys.reject { |id| data['decorations'].include?(id) }.sample
  end

  # --- Décors -------------------------------------------------------------------------------------------------------
  NEW_BACKDROPS = (%w[normal fire water electric grass ice fighting poison ground flying psychic bug rock ghost dragon dark
                      steel fairy].map { |type| "type_#{type}" } +
                   %w[rouge bleu orange vert violet marron jaune blanc noir].map { |c| "couleur_#{c}" } +
                   %w[rose bleu orange].map { |c| "nuage_#{c}" } + %w[style_pois style_rayures style_carreaux salon]).freeze

  # Tous les choix : 'auto', anciens décors, puis ceux de X / Y
  def backdrop_choices
    return ['auto'] + BACKDROPS + NEW_BACKDROPS
  end

  def backdrop_name(name)
    name = name.to_s
    return t('Automatique', 'Automatic') if name == 'auto'
    return t(*OLD_BACKDROP_NAMES[name]) if OLD_BACKDROP_NAMES[name]

    kind, value = name.split('_', 2)
    case kind
    when 'type' then return t("Type #{TYPE_NAMES[value][0]}", "#{TYPE_NAMES[value][1]} type")
    when 'couleur' then return t("Poké Ball #{COLOR_NAMES[value][0]}", "#{COLOR_NAMES[value][1].capitalize} Poké Ball")
    when 'nuage' then return t("Nuages #{COLOR_NAMES[value][0]}s".sub('ss', 's'), "#{COLOR_NAMES[value][1].capitalize} clouds")
    when 'style' then return t({ 'pois' => 'Pois', 'rayures' => 'Rayures', 'carreaux' => 'Carreaux' }[value], value.capitalize)
    end
    return t('Salon chic', 'Chic room') if name == 'salon'

    return name
  end

  # Image du décor (choisi dans Poké Récré, sinon selon l'endroit)
  def backdrop_file
    chosen = data['backdrop'].to_s
    return file("fonds/#{chosen}") if NEW_BACKDROPS.include?(chosen)
    return file("bg_#{chosen}") if BACKDROPS.include?(chosen)

    auto = backdrop
    return file("fonds/#{auto}") if NEW_BACKDROPS.include?(auto)

    return file("bg_#{auto}")
  end
end

module PFM
  class Pokemon
    # Fait manger une Pofiterole (sans la retirer)
    # @return [Integer, false] affection gagnée, false s'il n'a plus faim
    def amie_feed_puff(id)
      entry = PokeRecre.puff(id)
      return false unless entry && fullness_level < 5

      ranges = Array(PokeRecre.setting('puff_affection'))
      gain = PokeRecre.roll(ranges[entry[:flavor] ? entry[:level] : 4] || [5, 10])
      liked = entry[:flavor] && respond_to?(:flavor_liked?) && flavor_liked?(entry[:flavor])
      gain += gain * PokeRecre.setting('puff_liked_bonus').to_i / 100 if liked
      gain = gain * 3 / 2 unless entry[:flavor]
      self.amie_affection = amie_affection + gain
      self.amie_fullness = amie_fullness + PokeRecre.setting('puff_fullness').to_i
      self.amie_enjoyment = amie_enjoyment + rand(10..20)
      return gain
    rescue StandardError
      return false
    end
  end
end
