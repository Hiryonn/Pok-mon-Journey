# Pokéathlon : Jus de Noigrume (mixeur)
#
# On met jusqu'à juice_apricorns Noigrumes dans le mixeur (une par une, retirées du sac). Le jus est prêt après
# juice_steps pas, pour juice_uses verres. Saveurs (épicé, sec, sucré, amer, acide) : somme des Noigrumes (réglage
# apricorns), 63 au plus chacune, 100 au total. La douceur monte avec les pas (1 tous les 20 pas, 255 au plus).
# Effet d'un verre : performance de la saveur la plus forte +1 (+2 si elle vaut 24 ou plus), deuxième saveur +1 si elle
# vaut 12 ou plus, saveur la plus faible -1 si la douceur est sous 60. Un nouveau jus remplace l'ancien.
module Pokeathlon
  module_function

  # @return [Hash] { 'apricorns' => [objets], 'steps' => pas, 'ready' => prêt, 'uses' => verres, 'mild' => douceur }
  def blender
    store = data
    store['juice'] ||= { 'apricorns' => [], 'steps' => 0, 'ready' => false, 'uses' => 0, 'mild' => 0 }
    return store['juice']
  end

  # @return [Array<Integer>] saveurs d'un Noigrume
  def apricorn_flavors(item)
    own = fetch(config.apricorns, item.to_s)
    own = DEFAULT_APRICORNS[item.to_s] unless own.is_a?(Array) && own.size == 5
    return (own || [0] * 5).map(&:to_i)
  end

  # Noigrumes (objets qui ont des saveurs)
  # @return [Array<Symbol>]
  def apricorn_items
    list = (DEFAULT_APRICORNS.keys + (config.apricorns.is_a?(Hash) ? config.apricorns.keys.map(&:to_s) : [])).uniq
    return list.map(&:to_sym).select { |item| (data_item(item).db_symbol rescue nil) == item }
  end

  # @return [Array<Integer>] saveurs du jus
  def juice_flavors
    sum = [0] * 5
    blender['apricorns'].each { |item| apricorn_flavors(item).each_with_index { |v, i| sum[i] += v } }
    sum.map! { |v| v.clamp(0, 63) }
    total = sum.sum
    sum.map! { |v| (v * 100 / total.to_f).floor } if total > 100
    return sum
  end

  # @return [Symbol] :empty, :mixing, :ready
  def blender_state
    b = blender
    return :empty if b['apricorns'].empty?

    return b['ready'] ? :ready : :mixing
  end

  def blender_full?
    return blender['apricorns'].size >= setting('juice_apricorns').to_i.clamp(1, 10)
  end

  # Ajoute un Noigrume du sac
  # @return [String, nil] erreur
  def add_apricorn(item)
    b = blender
    return t('Le mélange n’est pas terminé.', 'The blend isn’t finished yet.') if blender_state == :mixing && b['steps'].to_i > 0
    return t('Le mixeur est plein.', 'The blender is full.') if b['apricorns'].size >= setting('juice_apricorns').to_i.clamp(1, 10)
    return t('Tu n’en as pas.', 'You don’t have any.') unless $bag.contain_item?(item.to_sym)

    $bag.remove_item(item.to_sym, 1)
    b['apricorns'] = [] if b['ready']
    b['apricorns'] << item.to_s
    b['ready'] = false
    b['steps'] = 0
    b['uses'] = setting('juice_uses').to_i.clamp(1, 99)
    return nil
  end

  # Un pas : le mélange avance, la douceur monte
  def blender_step
    b = $user_data && $user_data[:pj_athlon] && $user_data[:pj_athlon]['juice']
    return unless b && !b['apricorns'].to_a.empty?

    b['steps'] = b['steps'].to_i + 1
    b['ready'] = true if !b['ready'] && b['steps'] >= setting('juice_steps').to_i
    b['mild'] = (b['mild'].to_i + 1).clamp(0, 255) if b['steps'] % 20 == 0
  end

  # Effet d'un verre : { performance => +n / -n }
  def juice_effect
    flavors = juice_flavors
    order = (0...5).sort_by { |i| [-flavors[i], i] }
    effect = {}
    strong = order[0]
    effect[FLAVOR_STAT[FLAVORS[strong]]] = flavors[strong] >= 24 ? 2 : 1 if flavors[strong] > 0
    second = order[1]
    effect[FLAVOR_STAT[FLAVORS[second]]] = 1 if flavors[second] >= 12
    weak = order[4]
    if flavors[weak] < flavors[strong] && blender['mild'].to_i < 60 && !effect.key?(FLAVOR_STAT[FLAVORS[weak]])
      effect[FLAVOR_STAT[FLAVORS[weak]]] = -1
    end
    return effect
  end

  # Donne un verre à un Pokémon
  # @return [Hash, nil] effet (nil si pas de jus)
  def give_juice(pokemon)
    return nil unless blender_state == :ready && pokemon && !pokemon.egg?

    effect = juice_effect
    pokemon.pj_athlon_juice = effect
    b = blender
    b['uses'] = b['uses'].to_i - 1
    if b['uses'] <= 0
      b['apricorns'] = []
      b['ready'] = false
      b['steps'] = 0
      b['mild'] = 0
    end
    return effect
  end

  # Phrase de goût
  def taste_text
    flavors = juice_flavors
    strong = (0...5).max_by { |i| flavors[i] }
    level = flavors[strong]
    name = localized(FLAVOR_NAMES[FLAVORS[strong]])
    return t('Le jus n’a presque pas de goût.', 'The juice has almost no taste.') if level <= 0

    strength = if level >= 40 then t('très', 'very')
               elsif level >= 20 then t('assez', 'quite')
               else t('un peu', 'a bit')
               end
    mild = blender['mild'].to_i >= 60 ? t(' Il est doux.', ' It is mild.') : ''
    return t("Il est #{strength} #{name.downcase}.#{mild}", "It's #{strength} #{name.downcase}.#{mild}")
  end
end

Scheduler::EventTasks.on(:end_step, 'Pokeathlon', -1) do
  Pokeathlon.blender_step
rescue StandardError => e
  log_error("Pokéathlon : #{e.message}") if respond_to?(:log_error, true)
end
