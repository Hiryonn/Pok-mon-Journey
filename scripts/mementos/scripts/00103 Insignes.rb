# Souvenirs : insignes gagnés en jeu
#
# Pokémon sauvages (chaque combat sauvage, sauf les Pokémon errants) : un essai (trois avec le Charme Insigne) parmi
#   Rareté (1/20x), humeur au hasard (1/2x), Sociabilité (1/x), météo de la carte (1/x), moment de la journée (1/x),
#   Pêche (1/(x/2), en pêchant), Curry (1/(x/2), attiré par le Miel ou Doux Parfum), Destin (1/(x/2), le jour de
#   l'anniversaire du joueur) ; x = mark_ratio (50). Mini / Colosse : taille 0 / 255 (si size_marks).
# En route (Pokémon de l'équipe, ni œufs ni K.O.) :
#   Partenaire  tous les partner_steps pas, Pokémon très attaché (200+) : 1/(2x), 1/x avec le Charme Insigne
#   Trouvaille  objet ramassé par terre : le premier Pokémon, 1/(2x), 1/x avec le Charme Insigne
#   Gourmet     baies cueillies ou achetées : chaque Pokémon, 1/(x/2), 1/(x/4) avec le Charme Insigne
module Mementos
  # Durée (en images) pendant laquelle un Pokémon attiré (Miel, Doux Parfum) peut recevoir l'insigne Curry
  LURE_FRAMES = 1200
  WEATHER_MARKS = {
    rain: :rainy_mark, hardrain: :stormy_mark, sunny: :dry_mark, hardsun: :dry_mark, sandstorm: :sandstorm_mark,
    hail: :blizzard_mark, snow: :snowy_mark, fog: :misty_mark, strong_winds: :cloudy_mark
  }.freeze

  module_function

  def ratio
    return [setting('mark_ratio').to_i, 2].max
  end

  # Un Pokémon a été attiré (Miel, Doux Parfum, arbre à miel)
  def lure!
    @lure_frame = Graphics.frame_count
  end

  def lured?
    return @lure_frame && Graphics.frame_count - @lure_frame <= LURE_FRAMES
  end

  # --- Sauvages ----------------------------------------------------------------------------------
  # @param pokemon [PFM::Pokemon]
  # @param fishing [Boolean]
  def apply_wild_marks(pokemon, fishing = false)
    size_mark(pokemon)
    return unless setting?('wild_marks')

    mark = nil
    (charm? ? 3 : 1).times do
      mark = roll_wild_mark(fishing)
      break if mark
    end
    pokemon.add_ribbon(mark) if mark
  end

  def size_mark(pokemon)
    return unless setting?('size_marks')

    pokemon.add_ribbon(:mini_mark) if pokemon.pj_scale == 0
    pokemon.add_ribbon(:jumbo_mark) if pokemon.pj_scale == 255
  end

  # @return [Symbol, nil]
  def roll_wild_mark(fishing)
    r = ratio
    return :rare_mark if rand(r * 20) == 0
    return of_category(:personality).sample if rand(r * 2) == 0
    return :uncommon_mark if rand(r) == 0
    return weather_mark if weather_mark && rand(r) == 0
    return time_mark if rand(r) == 0
    return :fishing_mark if fishing && rand(r / 2) == 0
    return :curry_mark if lured? && rand(r / 2) == 0
    return :destiny_mark if anniversary? && rand(r / 2) == 0

    return nil
  end

  def time_mark
    return :dawn_mark if $env.morning?
    return :dusk_mark if $env.sunset?
    return :sleepy_time_mark if $env.night?

    return :lunchtime_mark
  rescue StandardError
    return :lunchtime_mark
  end

  def weather_mark
    return WEATHER_MARKS[$env.current_weather_db_symbol]
  rescue StandardError
    return nil
  end

  # --- En route ----------------------------------------------------------------------------------
  # @return [Array<PFM::Pokemon>] Pokémon de l'équipe en état
  def able_party
    return ($actors || []).compact.reject { |pokemon| pokemon.egg? || pokemon.dead? }
  end

  def give_chance(pokemon, mark, odds)
    return false if pokemon.nil? || pokemon.ribbon?(mark) || rand([odds.to_i, 1].max) > 0

    pokemon.add_ribbon(mark)
    return true
  end

  def step!
    steps = store[:steps].to_i + 1
    if steps >= [setting('partner_steps').to_i, 1].max
      steps = 0
      able_party.each do |pokemon|
        give_chance(pokemon, :partner_mark, ratio * (charm? ? 1 : 2)) if pokemon.loyalty >= 200
      end
    end
    store[:steps] = steps
  end

  def item_found!
    give_chance(able_party.first, :itemfinder_mark, ratio * (charm? ? 1 : 2))
  end

  def berries_gained!
    odds = ratio / (charm? ? 4 : 2)
    able_party.each { |pokemon| give_chance(pokemon, :gourmand_mark, odds) }
  end

  def berry?(item)
    return data_item(item).is_berry ? true : false
  rescue StandardError
    return false
  end

  # Protège le jeu : un souci dans les insignes ne doit jamais bloquer une action
  def safely(label)
    yield
  rescue StandardError => e
    log_error("Souvenirs (#{label}) : #{e.message}") if respond_to?(:log_error, true)
  end
end

module PFM
  # Les Pokémon sauvages reçoivent leurs insignes au début du combat
  class Wild_Battle
    module MementoMarks
      def configure_battle(enemy_arr, battle_id)
        fishing = !@fish_battle.nil?
        if enemy_arr.is_a?(Array)
          Mementos.safely('sauvages') do
            enemy_arr.each { |pokemon| Mementos.apply_wild_marks(pokemon, fishing) if pokemon.is_a?(PFM::Pokemon) && !roaming?(pokemon) }
          end
        end
        return super
      end
    end
    prepend MementoMarks
  end

  # Insigne Partenaire : pas du joueur
  class GameState
    module MementoSteps
      def increase_steps
        super
        Mementos.safely('pas') { Mementos.step! }
      end
    end
    prepend MementoSteps
  end

  # Doux Parfum attire les Pokémon (insigne Curry)
  if defined?(SKILL_PROCESS) && SKILL_PROCESS[:sweet_scent]
    sweet_scent = SKILL_PROCESS[:sweet_scent]
    SKILL_PROCESS[:sweet_scent] = proc do |pkmn, skill, test = false|
      Mementos.lure! unless test
      next sweet_scent.call(pkmn, skill, test)
    end
  end

  # Le Miel aussi (même effet que dans PSDK)
  module ItemDescriptor
    define_bag_use(:honey) do
      next($scene.display_message(text_get(39, 7).clone)) unless $wild_battle.available?

      Mementos.lure!
      $scene.return_to_scene(::Scene_Map)
      $game_system.map_interpreter.launch_common_event(1)
    end
  end
end

class Interpreter
  module MementoEvents
    # Objet ramassé : insigne Trouvaille
    def pick_item(item_id, count = 1, no_delete = false)
      before = $bag.item_quantity(item_id.is_a?(Symbol) ? item_id : data_item(item_id).db_symbol)
      result = super
      Mementos.safely('objet') do
        after = $bag.item_quantity(item_id.is_a?(Symbol) ? item_id : data_item(item_id).db_symbol)
        Mementos.item_found! if after > before
      end
      return result
    end

    # Arbre à miel : Pokémon attiré
    def honey_tree_event(id)
      Mementos.lure!
      return super
    end
  end
  prepend MementoEvents
end

# Baies cueillies dans les arbres : insigne Gourmet
module Yuki
  module Berries
    module MementoBerries
      def take(event_id)
        amount = super
        Mementos.safely('baies') { Mementos.berries_gained! if amount.to_i > 0 }
        return amount
      end
    end
    singleton_class.prepend(MementoBerries)
  end
end

module GamePlay
  # Baies achetées (boutique de PSDK)
  class Shop
    module MementoShop
      private

      def money_checkout(nb)
        item = @list_item[@index]
        super
        Mementos.safely('boutique') { Mementos.berries_gained! if Mementos.berry?(item) }
      end
    end
    prepend MementoShop if method_defined?(:money_checkout) || private_method_defined?(:money_checkout)
  end
end
