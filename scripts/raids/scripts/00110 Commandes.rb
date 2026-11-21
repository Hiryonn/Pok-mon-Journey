# Raids : commandes d'évènement (Script)
#
#   antre_raid                         antre de raid (l'évènement s'appelle « antre_raid », « antre_raid_max »…)
#     options : antre_raid(:max, pokemon: :charizard, rang: 5, taille: 3, tours: 12, ko: 4)
#   combat_raid(:charizard, style: :max, rang: 5)   combat de raid direct (pokemon: nil : au hasard selon le rang ;
#                                      autres options : niveau:, taille:, tours:, ko:, bouclier: (barres, 0 : aucun),
#                                      capture: false, recompenses: true)
#   raid_gagne?                        condition : le dernier raid a été gagné (capturé ou non)
#   raid_capture?                      condition : le boss du dernier raid a été capturé
#   aventure_raid(:max)                Aventure Raid (carte: n° de carte de raids_cartes.json ; sinon au choix)
#   aventure_reussie?                  condition : la dernière aventure a été terminée (boss battu)
#   remplir_antres                     tous les antres de raid retrouvent un Pokémon
#   vider_antre(id d'évènement)        l'antre redevient vide
#   raids_gagnes / antres_vaincus / aventures_terminees   compteurs de la partie
module Raids
  class << self
    # @return [Symbol, nil] issue du dernier raid (:win, :caught, :lost)
    attr_accessor :last_outcome
    # @return [Symbol, nil] issue de la dernière aventure
    attr_accessor :last_adventure
  end

  module_function

  # Options en français ou en anglais
  def command_options(options)
    out = {}
    { pokemon: :pokemon, rang: :rank, rank: :rank, niveau: :level, level: :level, taille: :size, size: :size, tours: :turns,
      turns: :turns, ko: :kos, kos: :kos, bouclier: :shield, shield: :shield, capture: :capture, type_tera: :tera_type,
      tera_type: :tera_type, recompenses: :rewards, rewards: :rewards, fond: :background, background: :background }.each do |from, to|
      out[to] = options[from] if options.key?(from)
    end
    return out
  end

  # Combat de raid direct
  def direct_raid(interpreter, species, style, options)
    rules = Rules.new(style: style, rank: options[:rank], size: options[:size], turns: options[:turns], kos: options[:kos],
                      tera_type: options[:tera_type], background: options[:background], capture: options.fetch(:capture, true))
    rules.shield_hp = options[:shield] if options.key?(:shield)
    if species.is_a?(PFM::Pokemon)
      boss = species
    else
      rules.rank ||= options[:level] ? rank_for_level(options[:level]) : random_rank
      boss = create_boss(rules, species)
      boss.level = options[:level] if options[:level]
    end
    make_boss(boss, rules) if species.is_a?(PFM::Pokemon)
    boss.hp = boss.max_hp
    Raids.last_outcome = nil
    start_battle(rules) do |outcome, battle_scene|
      Raids.last_outcome = outcome
      if %i[win caught].include?(outcome) && options[:rewards]
        rewards = generate_rewards(rules)
        rewards.each { |item, count| $bag.add_item(item, count) }
        battle_scene.call_scene(RewardsScene, rules, rewards, outcome)
      end
    end
    interpreter.instance_variable_set(:@wait_count, 2)
  end
end

class Interpreter
  # Antre de raid (évènement « antre_raid… »)
  def antre_raid(style = nil, **options)
    opts = Raids.command_options(options)
    opts[:style] = style if style
    Raids.den_interaction(self, @event_id, opts)
  end
  alias raid_den antre_raid

  # Combat de raid direct
  def combat_raid(pokemon = nil, style: :basic, **options)
    Raids.direct_raid(self, pokemon, style, Raids.command_options(options))
  end
  alias raid_battle combat_raid

  def raid_gagne?
    return %i[win caught].include?(Raids.last_outcome)
  end

  def raid_capture?
    return Raids.last_outcome == :caught
  end

  # Aventure Raid
  def aventure_raid(style = :max, carte: nil)
    Raids.last_adventure = Raids.start_adventure(style, carte)
  end
  alias raid_adventure aventure_raid

  def aventure_reussie?
    return Raids.last_adventure == :win
  end

  def remplir_antres
    store = Raids.dens
    store.delete_if { |key, _| key != :day }
    $game_map.events.each_value(&:pj_raid_den_refresh)
  end

  def vider_antre(event_id = @event_id)
    Raids.empty_den($game_map.map_id, event_id)
  end

  def raids_gagnes
    return Raids.stats[:won]
  end

  def antres_vaincus
    return Raids.stats[:dens]
  end

  def aventures_terminees
    return Raids.stats[:adventures]
  end
end
