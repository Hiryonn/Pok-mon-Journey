# Berrydex : champs de baies — ce qui se passe quand le joueur touche un emplacement
#
# L'appel de l'évènement commun « Berry tree » (réglage common_event) est remplacé par champ_de_baies :
#   objet laissé par un plant flétri -> nuisibles (combat, ou ils fuient si un Repousse agit) -> emplacement vide
#   (engrais, plantation) / plant qui pousse (arrosage, mauvaises herbes, déterrer) / plant mûr (cueillette)
module ChampsBaies
  module Interaction
    TEXTS = {
      withered: ['Il y a quelque chose par terre…\nVous avez trouvé : %<item>s !', 'There is something on the ground…\nYou found %<item>s!'],
      pests: ['La plante bouge… Des Pokémon sauvages s\'y cachent !', 'The plant is moving… Wild Pokémon are hiding in it!'],
      pests_fled: ['Le Repousse a fait fuir les Pokémon cachés dans la plante !', 'The Repel scared away the Pokémon hiding in the plant!'],
      soil: ['La terre est %<soil>s.', 'The soil is %<soil>s.'],
      empty: ['On peut planter une baie ici.', 'A Berry can be planted here.'],
      mulch_ask: ['Mettre de l\'engrais ?', 'Use some Mulch?'],
      mulch_done: ['Vous avez mis %<item>s dans la terre.', 'You spread %<item>s on the soil.'],
      mulch_on: ['Il y a %<item>s dans la terre.', 'There is %<item>s on the soil.'],
      plant_ask: ['Planter une baie ?', 'Plant a Berry?'],
      planted: ['Vous avez planté une %<berry>s.', 'You planted a %<berry>s.'],
      happy: ['La %<berry>s semble heureuse d\'être plantée ici !', 'The %<berry>s seemed happy to be planted here!'],
      unhappy: ['La %<berry>s ne semble pas aimer cet endroit…', 'The %<berry>s doesn\'t seem to like this place…'],
      stage0: ['Une %<berry>s a été plantée ici.', 'A %<berry>s was planted here.'],
      stage1: ['La %<berry>s a germé.', 'The %<berry>s has sprouted.'],
      stage2: ['La plante de %<berry>s grandit.', 'The %<berry>s plant is growing bigger.'],
      stage3: ['La plante de %<berry>s est en fleur !', 'The %<berry>s plant is in bloom!'],
      special: ['Il y a quelque chose de spécial dans cette plante…', 'There is something special about this plant…'],
      weeds: ['Des mauvaises herbes poussent autour de la plante.', 'Weeds are growing around the plant.'],
      weeds_ask: ['Arracher les mauvaises herbes ?', 'Pull out the weeds?'],
      weeds_done: ['Vous avez arraché les mauvaises herbes.', 'You pulled out the weeds.'],
      moist: ['La terre est humide.', 'The soil is moist.'],
      dry: ['La terre est sèche.', 'The soil is dry.'],
      water_ask: ['Arroser avec : %<item>s ?', 'Water it with the %<item>s?'],
      watered: ['Vous avez arrosé la plante.', 'You watered the plant.'],
      dig_ask: ['Déterrer la baie ?', 'Dig up the Berry?'],
      dig_keep: ['Vous avez déterré la %<berry>s.', 'You dug up the %<berry>s.'],
      dig_lost: ['Vous avez déterré la %<berry>s… mais elle est abîmée.', 'You dug up the %<berry>s… but it was ruined.'],
      ripe: ['Il y a %<count>d %<berry>s !\nLes cueillir ?', 'There are %<count>d %<berry>s!\nPick them?'],
      picked: ['Vous avez cueilli %<count>d %<berry>s !', 'You picked %<count>d %<berry>s!'],
      picked_soil: ['Le sol est redevenu %<soil>s.', 'The soil returned to its %<soil>s state.'],
      persistent: ['La plante repousse déjà !', 'The plant is already growing back!']
    }.freeze
    REPELS = %i[repel super_repel max_repel].freeze

    module_function

    def text(key, **args)
      list = TEXTS[key]
      return format(ChampsBaies.t(list[0], list[1]).gsub('\n', "\n"), **args)
    end
  end
end

class Interpreter
  # Interaction avec l'emplacement de baie de l'évènement (ou de event_id)
  def champ_de_baies(event_id = @event_id)
    growth = ChampsBaies::Growth
    map_id = $game_map.map_id
    growth.learn_spot(map_id, event_id)
    data = growth.berries_of(map_id)[event_id]
    ex = growth.extra(map_id, event_id)
    return champ_pick_withered(ex) if (!data || data[0] == 0) && ex[:withered_item]
    return champ_empty(map_id, event_id, ex) if !data || data[0] == 0
    return if ex[:pests] && ChampsBaies.setting('pests') && champ_pests(map_id, event_id, data, ex)
    return champ_ripe(map_id, event_id, data, ex) if data[1] >= 4

    champ_growing(map_id, event_id, data, ex)
  ensure
    ChampsBaies::Growth.refresh_event($game_map.map_id, event_id) if $game_map
  end
  alias interagir_baie champ_de_baies

  # Plante une baie sans passer par le sac
  # @param event_id [Integer]
  # @param berry [Symbol, Integer]
  def planter_baie(event_id, berry)
    return ChampsBaies::Growth.plant_at($game_map.map_id, event_id, berry)
  end

  # @return [Boolean] la baie de l'emplacement est mûre
  def baies_mures?(event_id = @event_id)
    data = ChampsBaies::Growth.berries_of($game_map.map_id)[event_id]
    return data && data[0] != 0 && data[1] >= 4 ? true : false
  end

  module ChampsBaiesCommonEvent
    # L'évènement commun des baies devient champ_de_baies
    def command_117
      if ChampsBaies.enabled? && @parameters[0] == ChampsBaies.setting('common_event').to_i && $game_map&.events&.key?(@event_id)
        champ_de_baies(@event_id)
        return true
      end
      return super
    end
  end
  prepend ChampsBaiesCommonEvent

  private

  def champ_text(key, **args)
    return ChampsBaies::Interaction.text(key, **args)
  end

  def champ_berry_name(data)
    return ChampsBaies.item_name(data[0])
  end

  def champ_pick_withered(ex)
    item = ex.delete(:withered_item)
    $bag.add_item(item, 1)
    message(champ_text(:withered, item: ChampsBaies.item_name(item)))
  end

  # Nuisibles : @return [Boolean] l'interaction s'arrête là
  def champ_pests(map_id, event_id, data, ex)
    message(champ_text(:pests))
    ex[:pests] = false
    ex[:pest_clock] = 0
    if ChampsBaies.setting('repel_on_pests') && PFM.game_state.repel_count.to_i > 0
      message(champ_text(:pests_fled))
      return false
    end
    pest = ChampsBaies.pest_for(data_item(data[0]).db_symbol)
    return false unless pest

    ChampsBaies::Growth.refresh_event(map_id, event_id)
    call_battle_wild(pest[0], pest[1])
    return true
  end

  def champ_soil_message(ex)
    soil = ChampsBaies.soil(ex[:soil])
    return unless soil && ChampsBaies.setting('zone_message')

    message(champ_text(:soil, soil: ChampsBaies.local(ChampsBaies.fetch(soil, 'plant'))))
  end

  # Emplacement vide : engrais puis baie
  def champ_empty(map_id, event_id, ex)
    champ_soil_message(ex)
    message(champ_text(:empty))
    champ_mulch(ex)
    return unless yes_no_choice(champ_text(:plant_ask))

    berry = nil
    $scene.call_scene(GamePlay.bag_class, :berry) { |scene| berry = scene.return_data }
    return if berry.nil? || berry.to_i <= 0 || !data_item(berry).is_berry || !$bag.contain_item?(berry)

    berry_id = data_item(berry).id
    $bag.remove_item(berry_id, 1)
    Yuki::Berries.init if Yuki::Berries.data.nil?
    Yuki::Berries.plant(event_id, berry_id)
    ex = ChampsBaies::Growth.extra(map_id, event_id)
    name = ChampsBaies.item_name(berry_id)
    message(champ_text(:planted, berry: name))
    return unless ChampsBaies.setting('zone_message')

    if ex[:pref_zone] || ex[:pref_soil]
      message(champ_text(:happy, berry: name))
    elsif ex[:unpref_zone]
      message(champ_text(:unhappy, berry: name))
    end
  end

  def champ_mulch(ex)
    if ex[:mulch]
      message(champ_text(:mulch_on, item: ChampsBaies.item_name(ex[:mulch])))
      return
    end
    list = ChampsBaies.config.mulches.keys.map(&:to_sym).select { |m| (data_item(m).id rescue 0) > 0 && $bag.contain_item?(m) }
    return if list.empty?

    names = list.map { |m| ChampsBaies.item_name(m) }
    choice = message(champ_text(:mulch_ask), names.size + 1, *names, ChampsBaies.t('Annuler', 'Cancel'))
    return if choice.nil? || choice >= list.size

    ex[:mulch] = list[choice]
    $bag.remove_item(list[choice], 1)
    message(champ_text(:mulch_done, item: names[choice]))
  end

  # Plant qui pousse : stade, mauvaises herbes, arrosage, déterrer
  def champ_growing(map_id, event_id, data, ex)
    growth = ChampsBaies::Growth
    name = champ_berry_name(data)
    message(champ_text(:"stage#{data[1]}", berry: name))
    message(champ_text(:special)) if ex[:mutation] && data[1] >= 1
    if ex[:weeds] && ChampsBaies.setting('weeds')
      message(champ_text(:weeds))
      if yes_no_choice(champ_text(:weeds_ask))
        ex[:weeds] = false
        ex[:weed_clock] = 0
        message(champ_text(:weeds_done))
      end
    end
    if data[1] == 0 && ChampsBaies.setting('dig_up') && yes_no_choice(champ_text(:dig_ask))
      champ_dig_up(map_id, event_id, data, ex, name)
      return
    end
    if growth.watered?(data)
      message(champ_text(:moist))
      return
    end
    message(champ_text(:dry))
    can = ChampsBaies.watering_can
    return if !can && ChampsBaies.setting('need_can')
    return unless yes_no_choice(champ_text(:water_ask, item: can ? ChampsBaies.item_name(can) : ChampsBaies.t('de l\'eau', 'water')))

    growth.water(data, ex)
    message(champ_text(:watered))
  end

  def champ_dig_up(map_id, event_id, data, ex, name)
    berry = data[0]
    if rand(100) < ChampsBaies.setting('dig_up_keep_chance').to_i
      $bag.add_item(berry, 1)
      message(champ_text(:dig_keep, berry: name))
    else
      message(champ_text(:dig_lost, berry: name))
    end
    champ_clear(map_id, event_id, data, ex)
  end

  # Emplacement vidé (sol, zone et position gardés ; l'engrais part avec la plante)
  def champ_clear(map_id, event_id, data, ex)
    data[0] = 0
    keep = ex.slice(:x, :y, :soil, :zone)
    ex.clear
    ex.merge!(keep)
    ChampsBaies::Growth.refresh_event(map_id, event_id)
  end

  # Plant mûr : cueillette (avec la mutation), plant durable
  def champ_ripe(map_id, event_id, data, ex)
    growth = ChampsBaies::Growth
    amount = growth.harvest_amount(data, ex)
    name = champ_berry_name(data)
    return unless yes_no_choice(champ_text(:ripe, count: amount, berry: name))

    mutated = 0
    if ex[:mutation] && ChampsBaies.setting('mutations')
      mutated = [ex[:mutation][1].to_i, amount].min
      mutated = [mutated, amount - 1].min if amount > 1
    end
    $bag.add_item(data[0], amount - mutated)
    message(champ_text(:picked, count: amount - mutated, berry: name)) if amount - mutated > 0
    if mutated > 0
      $bag.add_item(ex[:mutation][0], mutated)
      message(champ_text(:picked, count: mutated, berry: ChampsBaies.item_name(ex[:mutation][0])))
    end
    if rand(100) < ChampsBaies.setting('persistent_chance').to_i
      growth.replant(data, ex, ChampsBaies.setting('persistent_stage').to_i.clamp(0, 3))
      ex[:replants] = ex[:replants].to_i + 1
      ex[:mutation] = nil
      ex[:mutation_tried] = false
      message(champ_text(:persistent))
    else
      champ_clear(map_id, event_id, data, ex)
      soil = ChampsBaies.soil(ex[:soil])
      message(champ_text(:picked_soil, soil: ChampsBaies.local(ChampsBaies.fetch(soil, 'picked')))) if soil && ChampsBaies.setting('zone_message')
    end
  end
end
