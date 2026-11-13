# Enhanced Battle UI — réglages et données communes
#
# Ajoute au combat :
#   - Infos de l'attaque (touche X pendant le choix de l'attaque) : type, catégorie, PP, puissance, précision,
#     chance d'effet, particularités (contact, son, coup de poing…), description et efficacité sur chaque cible
#   - Infos des combattants (touche Y pendant le choix de l'action) : choix d'un Pokémon sur le terrain, puis
#     niveaux, statut, modifications de stats, dernière attaque utilisée, effets en cours (météo, terrain,
#     protections, pièges…) avec les tours restants et leur description
#
# Images : graphics/interface/enhanced_battle_ui (faites avec tools/build_assets.py depuis les assets d'Essentials)
module BattleUI
  module EBUI
    # Active le plugin
    ENABLED = true
    # Touche des infos de l'attaque (pendant le choix de l'attaque)
    MOVE_INFO_KEY = :X
    # Touche des infos des combattants (pendant le choix de l'action)
    BATTLER_INFO_KEY = :Y
    # Le panneau des infos de l'attaque reste ouvert d'une attaque à l'autre (il se ferme avec X ou B)
    KEEP_MOVE_PANEL = true
    # Touche du lancer rapide de Poké Ball pendant le choix de l'action, en combat sauvage
    # (remplace « dernier objet utilisé » de PSDK ; nil pour désactiver)
    BALL_KEY = :X
    # Montre le talent et l'objet des Pokémon adverses (sinon : seulement ceux du joueur)
    SHOW_FOE_ABILITY = false
    # Montre l'efficacité de l'attaque sur les adversaires (cases en haut à droite)
    SHOW_EFFECTIVENESS = true
    # Dossier des images (dans graphics/interface)
    DIR = 'enhanced_battle_ui/'
    # Polices : 0 = normale, 20 = petite (Data/configs/texts_config.json)
    FONT = 0
    SMALL_FONT = 20
    # Couleurs des textes (palette de PSDK)
    WHITE = 10
    DARK = 0
    # Position du panneau des infos de l'attaque sans l'Interface Horizon (interface de base de PSDK)
    # (avec l'Interface Horizon, le panneau est posé juste au-dessus de la bande du bas, à MOVE_PANEL_GAP_PE pixels)
    MOVE_PANEL_GAP_PE = 2
    MOVE_PANEL_Y = 4
    # Particularités des attaques : nom de l'image => test sur Studio::Move (même ordre que move_flags.png)
    FLAGS = [
      [:contact, ->(m) { m.is_direct }],
      [:punching, ->(m) { m.is_punch }],
      [:biting, ->(m) { m.is_bite }],
      [:slicing, ->(m) { m.is_slicing_attack }],
      [:sound, ->(m) { m.is_sound_attack }],
      [:pulse, ->(m) { m.is_pulse }],
      [:bomb, ->(m) { m.is_ballistics }],
      [:powder, ->(m) { m.is_powder }],
      [:dance, ->(m) { m.is_dance }],
      [:wind, ->(m) { m.is_wind }],
      [:high_critical, ->(m) { m.critical_rate.to_i > 1 }],
      [:thaws_user, ->(m) { m.is_unfreeze }],
      [:no_protect, ->(m) { !m.is_blocable && m.category != :status }],
      [:no_mirror_move, ->(m) { !m.is_mirror_move }],
      [:tramples_minimize, ->(m) { TRAMPLES_MINIMIZE.include?(m.db_symbol) }],
      [:electrocute_user, ->(m) { %i[supercell_slam].include?(m.db_symbol) }]
    ]
    # Attaques qui font double dégâts à un Pokémon qui a utilisé Lilliput
    TRAMPLES_MINIMIZE = %i[stomp body_slam dragon_rush heat_crash heavy_slam flying_press steamroller
                           phantom_force shadow_force malicious_moonsault supercell_slam].freeze

    # Textes : [français, anglais]
    TEXTS = {
      pp: %w[PP PP], power: %w[Pui Pow], accuracy: %w[Pré Acc], effect: %w[Eff Eff],
      turn: ['Tour %d', 'Turn %d'], wild: %w[Sauvage Wild], level: ['N. %d', 'Lv. %d'],
      used: ['Utilisée : %s', 'Used: %s'], none_used: ['Utilisée : aucune', 'Used: none'],
      ability: %w[Talent Abil.], item: %w[Objet Item], no_item: ['Aucun', 'None'],
      no_effect: ['Aucun effet en cours', 'No active effects'],
      stats: [['Attaque', 'Défense', 'Atq. Spé.', 'Déf. Spé.', 'Vitesse', 'Précision', 'Esquive', 'Critique'],
              ['Attack', 'Defense', 'Sp. Atk', 'Sp. Def', 'Speed', 'Accuracy', 'Evasion', 'Crit. Hit']],
      info_help: ['Gauche / Droite : Pokémon   B : retour', 'Left / Right: Pokémon   B: back'],
      ball_left: ['A : lancer', 'A: throw'], ball_right: ['Y : description', 'Y: description'],
      ball_close: ['Y : fermer', 'Y: close'],
      no_ball: ['Vous n\'avez pas de Poké Ball !', 'You don\'t have any Poké Balls!'],
      hint_choice_ball: ['X : Ball   Y : infos', 'X: Ball   Y: info'],
      infinite: ['--', '--'], layers: ['x%d', 'x%d'], hp: ['%d/%d', '%d/%d']
    }

    # Effets affichés : nom de l'effet (Battle::Effects) => [[nom FR, description FR], [nom EN, description EN]]
    EFFECTS = {
      # Météo (nom du temps de $env)
      rain: [['Pluie', 'Augmente la puissance des attaques Eau et baisse celle des attaques Feu.'],
             ['Rain', 'Boosts Water moves and weakens Fire moves.']],
      hardrain: [['Pluie battante', 'Les attaques Feu échouent. Les attaques Eau sont plus fortes.'],
                 ['Heavy Rain', 'Fire moves fail. Water moves are stronger.']],
      sunny: [['Soleil', 'Augmente la puissance des attaques Feu et baisse celle des attaques Eau.'],
              ['Sunlight', 'Boosts Fire moves and weakens Water moves.']],
      hardsun: [['Soleil intense', 'Les attaques Eau échouent. Les attaques Feu sont plus fortes.'],
                ['Harsh Sunlight', 'Water moves fail. Fire moves are stronger.']],
      sandstorm: [['Tempête de sable', 'Blesse les Pokémon qui ne sont pas Roche, Sol ou Acier. Déf. Spé. des Roche x1,5.'],
                  ['Sandstorm', 'Hurts non Rock, Ground or Steel Pokémon. Rock types get more Sp. Def.']],
      hail: [['Grêle', 'Blesse les Pokémon qui ne sont pas de type Glace à chaque tour.'],
             ['Hail', 'Hurts non Ice-type Pokémon each turn.']],
      snow: [['Neige', 'La Défense des Pokémon de type Glace augmente.'],
             ['Snow', 'Boosts the Defense of Ice-type Pokémon.']],
      fog: [['Brouillard', 'La précision de tous les Pokémon baisse.'], ['Fog', 'Lowers the accuracy of every Pokémon.']],
      strong_winds: [['Vent mystérieux', 'Les attaques super efficaces contre le type Vol le sont moins.'],
                     ['Strong Winds', 'Weakens moves that are super effective on Flying types.']],
      # Champs
      electric_terrain: [['Champ Électrifié', 'Les Pokémon au sol ne peuvent pas s\'endormir. Attaques Électrik plus fortes.'],
                         ['Electric Terrain', 'Grounded Pokémon can\'t fall asleep. Boosts Electric moves.']],
      grassy_terrain: [['Champ Herbu', 'Les Pokémon au sol récupèrent des PV à chaque tour. Attaques Plante plus fortes.'],
                       ['Grassy Terrain', 'Grounded Pokémon recover HP each turn. Boosts Grass moves.']],
      misty_terrain: [['Champ Brumeux', 'Protège les Pokémon au sol des statuts. Attaques Dragon moins fortes.'],
                      ['Misty Terrain', 'Protects grounded Pokémon from status. Weakens Dragon moves.']],
      psychic_terrain: [['Champ Psychique', 'Bloque les attaques prioritaires. Attaques Psy plus fortes.'],
                        ['Psychic Terrain', 'Blocks priority moves. Boosts Psychic moves.']],
      # Tout le terrain
      trick_room: [['Distorsion', 'Les Pokémon les plus lents agissent en premier.'],
                   ['Trick Room', 'Slower Pokémon move first.']],
      gravity: [['Gravité', 'Les Pokémon sont cloués au sol et la précision augmente.'],
                ['Gravity', 'Pokémon are grounded and accuracy rises.']],
      magic_room: [['Zone Magique', 'Les objets tenus n\'ont plus d\'effet.'], ['Magic Room', 'Held items have no effect.']],
      wonder_room: [['Zone Étrange', 'La Défense et la Défense Spéciale sont échangées.'],
                    ['Wonder Room', 'Defense and Sp. Def are swapped.']],
      mud_sport: [['Lance-Boue', 'Les attaques Électrik sont moins fortes.'], ['Mud Sport', 'Weakens Electric moves.']],
      water_sport: [['Tourniquet', 'Les attaques Feu sont moins fortes.'], ['Water Sport', 'Weakens Fire moves.']],
      fairy_lock: [['Verrou Enchanté', 'Personne ne peut fuir ni être changé au prochain tour.'],
                   ['Fairy Lock', 'No one can flee or switch next turn.']],
      ion_deluge: [['Déluge Plasmique', 'Les attaques Normal deviennent Électrik.'],
                   ['Ion Deluge', 'Normal moves become Electric.']],
      happy_hour: [['Étrennes', 'L\'argent gagné à la fin du combat est doublé.'], ['Happy Hour', 'Prize money is doubled.']],
      # Côté du terrain
      reflect: [['Protection', 'Les dégâts des attaques physiques sont réduits de moitié.'],
                ['Reflect', 'Halves damage from physical moves.']],
      light_screen: [['Mur Lumière', 'Les dégâts des attaques spéciales sont réduits de moitié.'],
                     ['Light Screen', 'Halves damage from special moves.']],
      aurora_veil: [['Voile Aurore', 'Les dégâts des attaques physiques et spéciales sont réduits.'],
                    ['Aurora Veil', 'Reduces damage from physical and special moves.']],
      tailwind: [['Vent Arrière', 'La Vitesse des Pokémon de ce côté est doublée.'],
                 ['Tailwind', 'Doubles the Speed of Pokémon on this side.']],
      safeguard: [['Rune Protect', 'Protège les Pokémon de ce côté des statuts.'],
                  ['Safeguard', 'Protects this side from status conditions.']],
      mist: [['Brume', 'Empêche les baisses de stats.'], ['Mist', 'Prevents stat drops.']],
      lucky_chant: [['Air Veinard', 'Empêche les coups critiques contre ce côté.'],
                    ['Lucky Chant', 'Prevents critical hits against this side.']],
      spikes: [['Picots', 'Blessent les Pokémon qui entrent au sol de ce côté.'],
               ['Spikes', 'Hurt grounded Pokémon switching in on this side.']],
      toxic_spikes: [['Pics Toxik', 'Empoisonnent les Pokémon qui entrent au sol de ce côté.'],
                     ['Toxic Spikes', 'Poison grounded Pokémon switching in on this side.']],
      stealth_rock: [['Piège de Roc', 'Blesse les Pokémon qui entrent selon leur faiblesse à la Roche.'],
                     ['Stealth Rock', 'Hurts Pokémon switching in, based on Rock weakness.']],
      sticky_web: [['Toile Gluante', 'Baisse la Vitesse des Pokémon qui entrent au sol.'],
                   ['Sticky Web', 'Lowers the Speed of grounded Pokémon switching in.']],
      rainbow: [['Arc-en-ciel', 'Les effets secondaires des attaques arrivent plus souvent.'],
                ['Rainbow', 'Added effects of moves happen more often.']],
      sea_of_fire: [['Mer de Feu', 'Blesse les Pokémon de ce côté à chaque tour.'],
                    ['Sea of Fire', 'Hurts Pokémon on this side each turn.']],
      swamp: [['Marécage', 'La Vitesse des Pokémon de ce côté baisse fortement.'],
              ['Swamp', 'Greatly lowers the Speed of Pokémon on this side.']],
      # Place sur le terrain
      wish: [['Vœu', 'Le Pokémon à cette place récupère des PV à la fin du prochain tour.'],
             ['Wish', 'The Pokémon here recovers HP at the end of next turn.']],
      future_sight: [['Prescience', 'Une attaque va frapper cette place dans quelques tours.'],
                     ['Future Sight', 'An attack will hit this spot in a few turns.']],
      healing_wish: [['Vœu Soin', 'Le prochain Pokémon à cette place sera soigné.'],
                     ['Healing Wish', 'The next Pokémon here will be healed.']],
      lunar_dance: [['Danse Lune', 'Le prochain Pokémon à cette place sera soigné.'],
                    ['Lunar Dance', 'The next Pokémon here will be healed.']],
      # Pokémon
      confusion: [['Confusion', 'Le Pokémon peut se blesser au lieu d\'attaquer.'],
                  ['Confusion', 'The Pokémon may hurt itself instead of attacking.']],
      attract: [['Attraction', 'Le Pokémon est amoureux et peut ne pas attaquer.'],
                ['Infatuation', 'The Pokémon is in love and may not attack.']],
      leech_seed_mark: [['Vampigraine', 'Le Pokémon perd des PV à chaque tour au profit de l\'adversaire.'],
                   ['Leech Seed', 'The Pokémon loses HP to the foe each turn.']],
      substitute: [['Clonage', 'Un clone encaisse les attaques à la place du Pokémon.'],
                   ['Substitute', 'A substitute takes hits for the Pokémon.']],
      taunt: [['Provoc', 'Le Pokémon ne peut utiliser que des attaques qui font des dégâts.'],
              ['Taunt', 'The Pokémon can only use damaging moves.']],
      encore: [['Encore', 'Le Pokémon doit répéter sa dernière attaque.'],
               ['Encore', 'The Pokémon must repeat its last move.']],
      disable: [['Entrave', 'Une attaque du Pokémon est bloquée.'], ['Disable', 'One of the Pokémon\'s moves is disabled.']],
      torment: [['Tourmente', 'Le Pokémon ne peut pas utiliser la même attaque deux fois de suite.'],
                ['Torment', 'The Pokémon can\'t use the same move twice in a row.']],
      heal_block: [['Anti-Soin', 'Le Pokémon ne peut pas récupérer de PV.'], ['Heal Block', 'The Pokémon can\'t recover HP.']],
      embargo: [['Embargo', 'Le Pokémon ne peut pas utiliser d\'objet.'], ['Embargo', 'The Pokémon can\'t use items.']],
      perish_song: [['Requiem', 'Le Pokémon sera K.O. à la fin du compte à rebours.'],
                    ['Perish Song', 'The Pokémon faints when the count reaches zero.']],
      curse: [['Malédiction', 'Le Pokémon perd des PV à chaque tour.'], ['Curse', 'The Pokémon loses HP each turn.']],
      nightmare: [['Cauchemar', 'Le Pokémon endormi perd des PV à chaque tour.'],
                  ['Nightmare', 'The sleeping Pokémon loses HP each turn.']],
      bind: [['Piégé', 'Le Pokémon est bloqué et perd des PV à chaque tour.'],
             ['Bound', 'The Pokémon is trapped and loses HP each turn.']],
      cantswitch: [['Bloqué', 'Le Pokémon ne peut pas être changé ni fuir.'], ['Trapped', 'The Pokémon can\'t switch or flee.']],
      ingrain: [['Racines', 'Le Pokémon récupère des PV mais ne peut pas être changé.'],
                ['Ingrain', 'The Pokémon recovers HP but can\'t switch.']],
      aqua_ring: [['Anneau Hydro', 'Le Pokémon récupère des PV à chaque tour.'], ['Aqua Ring', 'The Pokémon recovers HP each turn.']],
      focus_energy: [['Puissance', 'Le Pokémon fait plus facilement des coups critiques.'],
                     ['Focus Energy', 'The Pokémon lands critical hits more easily.']],
      dragon_cheer: [['Cri Draconique', 'Le Pokémon fait plus facilement des coups critiques.'],
                     ['Dragon Cheer', 'The Pokémon lands critical hits more easily.']],
      laser_focus: [['Affilage', 'La prochaine attaque sera un coup critique.'], ['Laser Focus', 'The next move will be a critical hit.']],
      magnet_rise: [['Vol Magnétik', 'Le Pokémon flotte : les attaques Sol ne le touchent pas.'],
                    ['Magnet Rise', 'The Pokémon levitates and avoids Ground moves.']],
      telekinesis: [['Lévikinésie', 'Le Pokémon flotte et se fait toucher plus facilement.'],
                    ['Telekinesis', 'The Pokémon floats and is easier to hit.']],
      smack_down: [['Anti-Air', 'Le Pokémon est cloué au sol.'], ['Smack Down', 'The Pokémon is grounded.']],
      drowsiness: [['Bâillement', 'Le Pokémon va s\'endormir à la fin du prochain tour.'],
                   ['Drowsy', 'The Pokémon will fall asleep at the end of next turn.']],
      yawn: [['Bâillement', 'Le Pokémon va s\'endormir à la fin du prochain tour.'],
             ['Drowsy', 'The Pokémon will fall asleep at the end of next turn.']],
      stockpile: [['Stockage', 'Le Pokémon a stocké de l\'énergie.'], ['Stockpile', 'The Pokémon has stockpiled energy.']],
      charge: [['Chargeur', 'La prochaine attaque Électrik est plus forte.'], ['Charge', 'The next Electric move is stronger.']],
      minimize: [['Lilliput', 'Le Pokémon est minuscule.'], ['Minimize', 'The Pokémon has shrunk.']],
      foresight: [['Clairvoyance', 'Le Pokémon peut être touché par les attaques Normal et Combat.'],
                  ['Foresight', 'The Pokémon can be hit by Normal and Fighting moves.']],
      miracle_eye: [['Œil Miracle', 'Le Pokémon peut être touché par les attaques Psy.'],
                    ['Miracle Eye', 'The Pokémon can be hit by Psychic moves.']],
      uproar: [['Brouhaha', 'Personne ne peut s\'endormir.'], ['Uproar', 'No one can fall asleep.']],
      salt_cure: [['Salaison', 'Le Pokémon perd des PV à chaque tour.'], ['Salt Cure', 'The Pokémon loses HP each turn.']],
      tar_shot: [['Goudronnage', 'Le Pokémon est plus sensible au Feu et sa Vitesse a baissé.'],
                 ['Tar Shot', 'The Pokémon is weaker to Fire and slower.']],
      syrup_bomb: [['Bombe au Sirop', 'La Vitesse du Pokémon baisse à chaque tour.'],
                   ['Syrup Bomb', 'The Pokémon\'s Speed drops each turn.']],
      throat_chop: [['Exécu-Son', 'Le Pokémon ne peut pas utiliser d\'attaque sonore.'],
                    ['Throat Chop', 'The Pokémon can\'t use sound moves.']],
      no_retreat: [['Ultime Bastion', 'Le Pokémon ne peut pas être changé ni fuir.'], ['No Retreat', 'The Pokémon can\'t switch or flee.']],
      imprison: [['Possessif', 'Les adversaires ne peuvent pas utiliser les attaques connues par ce Pokémon.'],
                 ['Imprison', 'Foes can\'t use moves this Pokémon knows.']],
      autotomize: [['Allègement', 'Le Pokémon est plus léger.'], ['Autotomize', 'The Pokémon became lighter.']],
      roost: [['Atterrissage', 'Le Pokémon a perdu son type Vol pour ce tour.'], ['Roost', 'The Pokémon lost its Flying type this turn.']],
      transform: [['Morphing', 'Le Pokémon s\'est transformé.'], ['Transform', 'The Pokémon has transformed.']],
      change_type: [['Type changé', 'Le type du Pokémon a changé.'], ['Type change', 'The Pokémon\'s type has changed.']],
      ability_suppressed: [['Talent supprimé', 'Le talent du Pokémon n\'a plus d\'effet.'],
                           ['Ability suppressed', 'The Pokémon\'s ability has no effect.']],
      lock_on: [['Verrouillage', 'La prochaine attaque du Pokémon touchera à coup sûr.'],
                ['Lock-On', 'The Pokémon\'s next move will surely hit.']],
      destiny_bond: [['Prélèvem. Destin', 'Si le Pokémon est mis K.O., son adversaire le sera aussi.'],
                     ['Destiny Bond', 'If the Pokémon faints, its attacker faints too.']],
      grudge: [['Rancune', 'Si le Pokémon est mis K.O., l\'attaque utilisée perd tous ses PP.'],
               ['Grudge', 'If the Pokémon faints, the move used loses all its PP.']],
      powder: [['Nuée de Poudre', 'Si le Pokémon utilise une attaque Feu, elle explose et le blesse.'],
               ['Powder', 'If the Pokémon uses a Fire move, it explodes and hurts it.']],
      rage: [['Frénésie', 'L\'Attaque du Pokémon augmente quand il est touché.'],
             ['Rage', 'The Pokémon\'s Attack rises when it is hit.']],
      glaive_rush: [['Raid Coupant', 'Le Pokémon subit des dégâts doublés jusqu\'à son prochain tour.'],
                    ['Glaive Rush', 'The Pokémon takes double damage until its next turn.']]
    }

    module_function

    # @return [Integer] 0 = français, 1 = anglais
    def lang
      return $options&.language == 'fr' ? 0 : 1
    end

    # @param key [Symbol]
    # @return [String, Array]
    def text(key)
      return key_names(TEXTS[key][lang])
    end

    # Remplace les touches du jeu (« X : », « Y : »…) par les touches du clavier réglées
    # (par défaut Y = touche B du clavier, X = V, A = C, B = X)
    # @param str [String]
    # @return [String]
    def key_names(str)
      return str unless str.is_a?(String)

      return str.gsub(/(?<![[:alpha:]])([ABXY])(?= ?:)/) { key_label(Regexp.last_match(1)) }
    end

    # @param key [String] A, B, X ou Y
    # @return [String] nom de la touche du clavier
    def key_label(key)
      code = Input::Keys[key.to_sym]&.first
      @key_labels ||= {}
      return @key_labels[[key, code]] ||= begin
        name = PFM::Text.get_key_name(key.downcase).to_s
        name.empty? || name == 'KeyError' ? key : name
      end
    rescue StandardError
      return key
    end

    # @return [Boolean]
    def enabled?
      return ENABLED && $game_temp.vs_type.to_i <= 2
    end

    # @return [Boolean] l'interface de combat PE (plugin interface_horizon) est active
    def pe_ui?
      return defined?(BattleUI::PJ) && BattleUI::PJ.respond_to?(:active?) && BattleUI::PJ.active?
    end

    # @param name [String]
    # @return [String]
    def file(name)
      return "#{DIR}#{name}"
    end

    # @param key [Symbol]
    # @return [Array(String, String), nil] nom et description de l'effet
    def effect_text(key)
      return EFFECTS[key]&.dig(lang)
    end

    # Multiplicateur d'efficacité (types seulement)
    # @param move [Battle::Move]
    # @param target [PFM::PokemonBattler]
    # @return [Float, nil] nil pour une attaque de statut
    def effectiveness(move, target)
      return nil if !target || move.status?

      attack = data_type(move.type)
      types = [target.type1, target.type2, target.type3].map(&:to_i).reject(&:zero?).uniq
      return types.inject(1.0) { |factor, type| factor * attack.hit(data_type(type).db_symbol) }
    rescue StandardError
      return nil
    end

    # Case d'efficacité : 0 ?, 1 immunisé, 2 peu efficace, 3 super efficace, 4 normal
    # @param factor [Float, nil]
    # @return [Integer]
    def effectiveness_frame(factor)
      return 0 if factor.nil?
      return 1 if factor <= 0
      return 2 if factor < 1
      return 3 if factor > 1

      return 4
    end

    # Niveau de coup critique (0 à 3)
    # @param battler [PFM::PokemonBattler]
    # @return [Integer]
    def critical_stage(battler)
      stage = 0
      stage += 2 if battler.effects.has?(:focus_energy)
      stage += battler.type_dragon? ? 2 : 1 if battler.effects.has?(:dragon_cheer)
      stage += 1 if battler.has_ability?(:super_luck)
      item = battler.battle_item_db_symbol
      stage += 1 if %i[scope_lens razor_claw].include?(item)
      stage += 2 if %i[leek stick].include?(item) && %i[farfetch_d sirfetch_d farfetchd sirfetchd].include?(battler.db_symbol)
      stage += 2 if item == :lucky_punch && battler.db_symbol == :chansey
      return stage.clamp(0, 3)
    rescue StandardError
      return 0
    end

    # Nom du dresseur d'un combattant
    # @param logic [Battle::Logic]
    # @param battler [PFM::PokemonBattler]
    # @return [String]
    def owner_name(logic, battler)
      return $trainer.name if battler.bank == 0 && battler.from_player_party?

      name = logic.battle_info.trainer_name(battler).to_s
      return name.empty? ? text(:wild) : name
    rescue StandardError
      return battler.bank == 0 ? $trainer.name : text(:wild)
    end
  
    # Petite étiquette de type (32 x 11) : graphics/interface/enhanced_battle_ui/types_<langue>.png
    # (faite par tools/types/build_types.py, une ligne par id de type)
    class TypeLabel < SpriteSheet
      HEIGHT = 11

      # @param viewport [Viewport]
      # @param source [Symbol] méthode qui donne l'id du type (:type, :type1, :type2)
      def initialize(viewport, source = :type)
        super(viewport, 1, 1)
        @source = source
        name = "types_#{$options&.language}"
        name = 'types_en' unless RPG::Cache.interface_exist?(EBUI.file(name))
        set_bitmap(EBUI.file(name), :interface)
        self.nb_y = [bitmap.height / HEIGHT, 1].max
      end

      # @param object [Object] objet qui répond à la méthode source (attaque, Pokémon)
      def data=(object)
        id = object ? object.public_send(@source).to_i : 0
        self.visible = id > 0
        self.sy = id if visible
      end
    end
  end
end
