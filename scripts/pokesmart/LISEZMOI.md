# Plugin pokesmart

Menu principal de PSDK en smartphone (pack PokeSmart), indépendant du plugin interface_pe.

## Contenu
Scripts (`scripts/`, chargés dans l'ordre du nom) :

| Fichier | Rôle |
| --- | --- |
| `00130 Configuration.rb` | Tous les réglages : coques (`THEMES`), icônes, fonds, réseau, batterie, applis (`ENABLED = false` coupe le téléphone) |
| `00131 Personnalisation.rb` | Choix enregistrés (coque, icônes, fond d'écran), chemins des images, noms des fonds |
| `00132 Barre d'etat.rb` | Moment de la journée, batterie, réseau, test Internet |
| `00133 Telephone.rb` | Classe `Phone` : coque, fond d'écran, barre d'état, titre |
| `00134 Appli.rb` | Classe `AppButton` : une case d'appli |
| `00135 Liste de choix.rb` | Classe `ListPicker` : liste de l'appli Personnaliser |
| `00137 Reglages Studio.rb` | Lecture des réglages faits dans Pokémon Studio (onglet Smartphone) |
| `00136 Radar.rb` | Pokémon sauvages de la zone + classe `Radar` (appli Pokénav) |
| `00140 Menu.rb` | Le menu PSDK habillé en téléphone (grille, souris, entrée / sortie) |
| `00141 App Pokenav.rb` | Ouverture / fermeture du radar |
| `00142 App Personnaliser.rb` | Rubriques Coque / Icônes / Fond d'écran |

Graphismes : `graphics/interface/pokesmart/` (coque, icônes, barre d'état), `motismart/` et `wallpapers/`.

## Construire le plugin
Depuis la racine du projet : `psdk.bat --util=plugin build pokesmart`.
Le fichier `scripts/pokesmart.psdkplug` est créé ; PSDK l'installe au lancement suivant.

## Applis et icônes
Une image par appli dans `graphics/interface/pokesmart/` (44x22 : icône normale à gauche, sélectionnée à droite),
et ses variantes `icon_xxx_01.png`, `icon_xxx_02.png`… choisies dans Personnaliser → Icônes.
Table `APP_ICONS` (action => image), qui donne aussi l'ordre des applis :
Pokédex `icon_pokedex`, Équipe `icon_party`, Sac `icon_bag`, Carte `open_map`/`icon_map`, PC `open_pc`/`icon_pc`,
Journal `open_quest`/`icon_book`, Carte de dresseur `icon_trainercard`, Amis `open_friends`/`icon_friendlist`,
Sauvegarde `icon_save`, Options `icon_option`, Personnalisation `open_customization`/`icon_custom`,
Cadeau mystère `open_mystery_gift`/`icon_mysterygift`, Monture `open_mount`/`icon_mount`, Pokénav `open_pokenav`/`icon_pokemon`,
Jeu de cartes `open_card_game`/`icon_card`, Pension `open_daycare`/`icon_egg`, Appareil photo `open_camera`/`icon_camera`,
Pêche `open_fishing`/`icon_fishing`. Une appli inconnue prend `icon_debug`.
Pour activer une appli future : définir la méthode dans `GamePlay::Menu` puis
`GamePlay::Menu.register_button(:open_map) { true }` ; l'icône et le nom sont déjà prêts.

## Appli Pokénav (radar)
Ajoutée par le plugin (`POKENAV_APP = false` pour la retirer). Elle affiche dans le téléphone :
- le nom de la zone ;
- les Pokémon sauvages des groupes actifs ici (conditions de carte et d'interrupteur de Studio respectées) :
  « ? » si jamais vu, l'icône si vu, l'icône + Poké Ball si capturé ;
- le marqueur bleu si la zone n'a que des rencontres sur l'eau / à la canne, orange sinon ;
- le moment de la journée.
Haut / bas pour faire défiler au-delà de 9 Pokémon, A / B / clic pour revenir aux applis.

## Appli Personnaliser
Ajoutée par le plugin (`CUSTOMIZATION_APP = false` pour la retirer). Trois rubriques :
- **Coque** : PokeSmart (par défaut, `DEFAULT_THEME`) ou Motismart. Chaque coque est décrite dans `THEMES`
  (positions de l'écran, de la barre d'état, du titre, de la grille…) et a son dossier d'images.
- **Icônes** : réglées appli par appli. La liste montre les applis qui ont des variantes ; pour l'icône de base
  `icon_bag.png`, les variantes sont `icon_bag_01.png`, `icon_bag_02.png`… (jusqu'à `MAX_ICON_VARIANTS`).
  « Classique » = l'icône de base. Ajouter une image `icon_xxx_NN.png` ajoute une variante, sans toucher au script.
- **Fond d'écran** : « Selon le Pokémon », « Aucun », ou une des images du dossier `wallpapers/` (Fond 1, 2…,
  dans l'ordre des noms de fichiers ; ajouter une image au dossier l'ajoute à la liste). L'image est posée sur l'écran
  de la coque, calée en bas à droite (recadrée si elle dépasse). « Selon le Pokémon » : image `025_wallpaper.png`
  (numéro du Pokémon de tête) si elle existe, sinon selon son type (`TYPE_WALLPAPERS` : Plante `001_wallpaper`,
  Feu `004_wallpaper`, Eau `007_wallpaper`), sinon rien.
  Les fonds `NNN_wallpaper.png` (un par Pokémon) sont listés par numéro avec le nom du Pokémon, après d'éventuels
  fonds libres (autre nom de fichier) ; gauche / droite fait défiler la liste page par page.
Haut / bas : aperçu direct ; A : garder ; B : annuler / revenir. Les choix sont enregistrés dans la sauvegarde
(`$user_data[:pokesmart]`).

## Réglages depuis Pokémon Studio
Avec la version personnalisée de Studio, **Base de données > Plugins > Smartphone** (ou Ctrl+Maj+M) ouvre l'éditeur :
ordre des applis (glisser-déposer sur l'aperçu), applis cachées, noms (une colonne par langue), icône par défaut
de chaque appli, coque et fond d'écran par défaut. Il écrit :
- `Data/configs/plugins/pokesmart_config.json` : ordre, applis cachées, valeurs par défaut (lu par `00137 Reglages Studio.rb`) ;
- `Data/Text/Dialogs/9100.csv` : noms des applis (lus avec `ext_text(9100, ligne)`).
Sans ces fichiers, le plugin garde son comportement habituel. Le joueur peut toujours changer coque, icônes et fond
dans l'appli Personnaliser : les réglages Studio sont les valeurs de départ.
