# Tournoi : commandes d'évènement (commande Script)
#   tournoi(:coupe_debutant)                 tournoi réglé dans Studio (renvoie la place du joueur, 1 : vainqueur)
#   tournoi_gagne?(:coupe_debutant)          condition : le dernier essai de ce tournoi a été gagné
#   tournoi_place(:coupe_debutant)           place du joueur au dernier essai (0 : jamais joué)
#   tournois_gagnes(:coupe_debutant)         nombre de victoires (sans argument : tous les tournois)
#   combat_selection(:trainer_3, nombre: 3)  combat avec écran de sélection d'équipe
#   combat_selection_gagne?                  condition : le dernier combat avec sélection a été gagné
#   selection_equipe(:trainer_3, nombre: 3)  écran de sélection seul : l'équipe est réduite jusqu'à la fin du
#                                            prochain combat (lancé ensuite par la commande de combat de Studio)
# Options des règles (en plus de celles du tournoi) : nombre:, double:, niveau_max:, objets: (:montrer, :cacher,
#   :aucun), voir_adversaire:, choix_adversaire: (:hasard, :premiers, :forts), sac:, exp:, soin:, abandon:, fond:,
#   musique:
class Interpreter
  TOURNOI_OPTIONS = {
    nombre: 'pick', pick: 'pick', niveau_max: 'max_level', max_level: 'max_level', objets: 'items', items: 'items',
    voir_adversaire: 'show_opponent', show_opponent: 'show_opponent', choix_adversaire: 'opponent_pick',
    opponent_pick: 'opponent_pick', sac: 'bag', bag: 'bag', exp: 'exp', soin: 'heal', heal: 'heal',
    abandon: 'cancel', cancel: 'cancel', fond: 'background', background: 'background', musique: 'battle_bgm',
    battle_bgm: 'battle_bgm'
  }.freeze
  TOURNOI_VALUES = {
    montrer: 'show', cacher: 'hide', aucun: 'none', hasard: 'random', premiers: 'first', forts: 'strongest'
  }.freeze

  # Règles passées à une commande (noms français ou anglais)
  # @return [Hash]
  def tournoi_options(options)
    out = {}
    options.each do |key, value|
      if %i[double].include?(key.to_sym)
        out['mode'] = value ? 2 : 1
      elsif (name = TOURNOI_OPTIONS[key.to_sym])
        value = TOURNOI_VALUES[value] || value if value.is_a?(Symbol)
        out[name] = value.is_a?(Symbol) ? value.to_s : value
      end
    end
    return out
  end

  # Tournoi réglé dans Studio
  # @param id [Symbol, String]
  # @return [Integer, nil] place du joueur
  def tournoi(id, **options)
    return Tournoi.start_cup(id, tournoi_options(options))
  end

  def tournoi_gagne?(id = Tournoi.last_cup)
    return false unless id

    return Tournoi.record(id)['last'].to_i == 1
  end

  def tournoi_place(id = Tournoi.last_cup)
    return 0 unless id

    return Tournoi.record(id)['last'].to_i
  end

  def tournois_gagnes(id = nil)
    return Tournoi.record(id)['won'].to_i if id

    return Tournoi.stats.values.sum { |record| record['won'].to_i }
  end

  # Combat contre un dresseur de Studio avec écran de sélection
  # @param trainer [Integer, Symbol] dresseur de Studio
  def combat_selection(trainer, **options)
    return Tournoi.selection_battle(trainer, Tournoi.rules(nil, tournoi_options(options)))
  end

  def combat_selection_gagne?
    return Tournoi.last_selection == 0
  end

  # Écran de sélection seul (l'équipe est réduite jusqu'à la fin du prochain combat)
  def selection_equipe(trainer, **options)
    return Tournoi.select_only(trainer, Tournoi.rules(nil, tournoi_options(options)))
  end
end
