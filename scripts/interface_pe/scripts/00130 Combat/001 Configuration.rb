# Interface PE — combat : interface de combat retravaillée (boîtes d'infos, menu d'action, attaques, Safari)
#
# Images : graphics/interface/battle_pj (découpées des assets fournis, sources dans battle_pj/source)
# Les combats à 3 contre 3 gardent l'interface de base de PSDK.
module BattleUI
  module PJ
    # Active l'interface
    ENABLED = true
    # Dossier des images (dans graphics/interface)
    DIR = 'battle_pj/'
    # Couleurs des textes (palette de PSDK)
    WHITE = 10
    DARK = 0
    # Grille 2 x 2 des boutons (attaques, actions, Safari), en bas à droite
    # (tout tient dans la bande sombre du bas, avec une marge de 4 pixels)
    GRID_X = 128
    GRID_Y = 180
    CELL_W = 94
    CELL_H = 28
    # Position de la bande sombre du bas (64 pixels de haut)
    PANEL_Y = 176
    # Boîtes d'infos : [x, y] en 1 contre 1, puis décalage entre deux boîtes en 2 contre 2
    ENEMY_BOX = [0, 6]
    ENEMY_BOX_DOUBLE = [0, 2]
    ENEMY_OFFSET = [0, 27]
    PLAYER_BOX = [182, 144]
    PLAYER_BOX_DOUBLE = [182, 112]
    PLAYER_OFFSET = [0, 31]
    # Remonte le Pokémon du joueur (en pixels) : il est posé sur la bande du bas (176)
    PLAYER_SPRITE_RAISE = 6
    # Cache les Poké Balls de l'équipe du joueur (nombre de Pokémon)
    HIDE_PLAYER_PARTY_BALLS = true
    # Garde la boîte d'infos du Pokémon du joueur affichée pendant les choix
    KEEP_PLAYER_BAR = true
    # Textes : [français, anglais]
    TEXTS = {
      attack: %w[Attaque Fight], bag: %w[Sac Bag], pokemon: %w[Pokémon Pokémon], flee: %w[Fuite Run],
      safari_ball: ['Safari Ball', 'Safari Ball'], bait: %w[Appât Bait], mud: %w[Boue Mud],
      what: ['Que doit faire', 'What will'], what_end: ['%s ?', '%s do?'],
      hint_choice: ['X : objet   Y : infos', 'X: item   Y: info'],
      hint_skill: ['X : description', 'X: description'], hint_short: ['X : descr.', 'X: descr.'],
      hint_mega: ['Y : méga', 'Y: mega'], power: ['Puissance :', 'Power:'], accuracy: ['Précision :', 'Accuracy:']
    }

    module_function

    # @param key [Symbol]
    # @return [String]
    def text(key)
      return key_names(TEXTS[key][$options&.language == 'fr' ? 0 : 1])
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

    # @return [Boolean] si l'interface s'applique (pas en 3 contre 3)
    def active?
      return ENABLED && $game_temp.vs_type != 3
    end

    # @param name [String]
    # @return [String] chemin de l'image (graphics/interface)
    def file(name)
      return "#{DIR}#{name}"
    end

    # Multiplicateur d'efficacité d'une attaque sur une cible (types seulement)
    # @param move [Battle::Move]
    # @param target [PFM::PokemonBattler, nil]
    # @return [Float, nil] nil si l'attaque est de statut ou sans cible
    def effectiveness(move, target)
      return nil if !target || move.status?

      attack = data_type(move.type)
      return [target.type1, target.type2, target.type3].reject { |t| t.to_i == 0 }.uniq.inject(1.0) do |factor, type|
        factor * attack.hit(data_type(type).db_symbol)
      end
    rescue StandardError
      return nil
    end

    # Ligne de l'image effectiveness.png : —, ¼, ½, 1, 2, 4
    # @param factor [Float]
    # @return [Integer]
    def effectiveness_row(factor)
      return 0 if factor <= 0
      return 1 if factor <= 0.25
      return 2 if factor < 1
      return 3 if factor == 1
      return 4 if factor < 4

      return 5
    end
  end
end
