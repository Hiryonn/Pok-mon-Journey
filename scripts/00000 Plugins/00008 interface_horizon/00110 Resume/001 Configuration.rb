# Résumé du Pokémon (GamePlay::Summary) au style de la planche « Summary »
#
# Pages (gauche / droite pour changer) :
#   0 Infos      : sprite dans l'hexagone, types, espèce, D.O., expérience, objet tenu
#   1 Stats      : capacités en aperçu + tableau stats / IV / EV, nature, talent
#   2 Capacités  : liste sélectionnable + panneau « i » (description, puissance, précision)
#   3 Concours   : même liste que Capacités ; graphe des conditions à droite, ou la description
#                  de concours de la capacité quand on en sélectionne une (A)
#   4 Souvenirs  : style de la page Mémo ; grille des rubans et insignes à droite (tri, rangs regroupés,
#                  déplacement, titre : plugin Souvenirs) et, dans le cadre gris, le bilan du Pokémon ou le
#                  souvenir sélectionné (nom, catégorie, rang, description, titre)
#   5 Mémo       : date et lieu de rencontre, niveau, nature
#   6 Arbre familial : parents et grands-parents (notés quand un œuf est pondu à la pension) ;
#                  un œuf peut aussi l'ouvrir (gauche / droite passe de l'œuf à son arbre)
# La logique de PSDK (changement de Pokémon, ordre des capacités, choix d'une capacité, souris) est conservée.
# Le bandeau du haut est cliquable : ⇕ Pokémon suivant, « / » page précédente / suivante, ⮐ retour.
#
# Graphismes : graphics/interface/summary_pe/
# Pour revenir au résumé d'origine : passer ENABLED à false (ou supprimer ce dossier).
module UI
  module SummaryPE
    # Active ou non le nouveau résumé
    ENABLED = true

    # Dossier des graphismes (dans graphics/interface/)
    DIR = 'summary_pe/'

    # Index de la page mémo ajoutée après les rubans
    MEMO_PAGE = 5

    # Index de la page arbre familial (après le mémo)
    FAMILY_PAGE = 6

    # Couleurs de texte de PSDK (graphics/windowskins/_colors.png)
    WHITE = 9

    CYAN = 14

    YELLOW = 16

    RED = 12

    GREEN = 13

    DARK = 0

    # Police fine (PowerGreenSmall)
    SMALL_FONT = 20

    # Couleurs des noms de stats (PV, Attaque, Défense, Atq. Spé., Déf. Spé., Vitesse)
    STAT_COLORS = [[0xfe, 0xc2, 0xcc], [0xf6, 0x84, 0x84], [0x9f, 0xb6, 0xdf], [0xb9, 0x9e, 0xd5], [0x88, 0xdb, 0xdb], [0x9f, 0xe5, 0x9d]]

    # Textes absents des fichiers de PSDK : [français, anglais]
    LABELS = {
      species: ['Espèce', 'Species'],
      moves: ['Capacités', 'Battle Moves'],
      nature: ['Nature', 'Nature'],
      egg: ['Œuf', 'Egg'],
      contest: ['Concours', 'Contest'],
      ribbons: ['Rubans', 'Ribbons'],
      met: ['Rencontré au N. %d.', 'Met at level %d.'],
      date: ['%d/%m/%Y', '%m/%d/%Y'],
      family: ['Arbre familial', 'Family Tree'],
      unknown: ['Inconnu', 'Unknown']
    }

    module_function

    # @param name [String]

    # @return [String] chemin du graphisme
    def file(name)
      return "#{DIR}#{name}"
    end

    # @param key [Symbol]
    # @return [String]
    def label(key)
      texts = LABELS[key]
      return $options&.language == 'fr' ? texts[0] : texts[1]
    end

    # Texte du fichier 27 de PSDK (libellés du résumé, déjà traduits)
    # @param index [Integer]
    # @return [String]
    def summary_text(index)
      return text_file_get(27)[index].to_s
    end

    # Enlève les balises de couleur des textes PSDK
    # @param text [String]
    # @return [String]
    def strip_markup(text)
      return text.to_s.gsub(/\[VAR [^\]]*\]/, '').gsub(/\\c\[\d+\]/, '')
    end

    # Nom du graphisme de l'emplacement de capacité selon son type
    # @param type_id [Integer]
    # @return [String]
    def slot_file(type_id)
      name = file("move_slot_#{type_id}")
      return RPG::Cache.interface_exist?(name) ? name : file('move_slot')
    end

    # Nom du type en majuscules (ex. SPECTRE)
    # @param type_id [Integer]
    # @return [String]
    def type_name(type_id)
      return data_type(type_id).name.to_s.upcase
    rescue StandardError
      return ''
    end
  end
end
