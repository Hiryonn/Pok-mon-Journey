# Plugin pokesmart

Menu principal de PSDK en smartphone (pack PokeSmart), indépendant du plugin interface_pe.

## Contenu
- `scripts/00130 Menu Smartphone.rb` : le menu (module `UI::PokeSmart`, `ENABLED = false` pour le couper)
- graphismes : `graphics/interface/pokesmart/` (coque, icônes, barre d'état) et `wallpapers/`

## Construire le plugin
Depuis la racine du projet : `psdk.bat --util=plugin build pokesmart`
(ou double-clic sur `construire_plugin_pokesmart.bat`).
Le fichier `scripts/pokesmart.psdkplug` est créé ; PSDK l'installe au lancement suivant.

## Applis et icônes
Une image par appli dans `graphics/interface/pokesmart/` (44x22 : icône normale à gauche, sélectionnée à droite).
Table `APP_ICONS` (action => image), qui donne aussi l'ordre des applis :
Pokédex `icon_pokedex`, Équipe `icon_party`, Sac `icon_bag`, Carte `open_map`/`icon_map`, PC `open_pc`/`icon_pc`,
Journal `open_quest`/`icon_book`, Carte de dresseur `icon_trainercard`, Amis `open_friends`/`icon_friendlist`,
Sauvegarde `icon_save`, Options `icon_option`, Personnalisation `open_customization`/`icon_custom`,
Cadeau mystère `open_mystery_gift`/`icon_mysterygift`, Monture `open_mount`/`icon_mount`, Troupeaux `icon_pokemon`,
Jeu de cartes `open_card_game`/`icon_card`, Pension `open_daycare`/`icon_egg`, Appareil photo `open_camera`/`icon_camera`,
Pêche `open_fishing`/`icon_fishing`. Une appli inconnue prend `icon_debug`.
Pour activer une appli future : définir la méthode dans `GamePlay::Menu` puis
`GamePlay::Menu.register_button(:open_map) { true }` ; l'icône et le nom sont déjà prêts.

## Appli Troupeaux (radar)
Ajoutée par le plugin (`HERDS_APP = false` pour la retirer). Elle affiche dans le téléphone :
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
- **Icônes** : jeu d'icônes `ICON_SETS`. Une icône absente du dossier du jeu (ex. `motismart/`) est prise dans
  `graphics/interface/pokesmart/`. Sans choix, le jeu qui porte le nom de la coque est utilisé.
- **Fond d'écran** : « Selon le Pokémon », « Aucun », ou une des images du dossier `wallpapers/` (Fond 1, 2…,
  dans l'ordre des noms de fichiers ; ajouter une image au dossier l'ajoute à la liste). L'image est posée sur l'écran
  de la coque, calée en bas à droite (recadrée si elle dépasse). « Selon le Pokémon » : image `025_wallpaper.png`
  (numéro du Pokémon de tête) si elle existe, sinon selon son type (`TYPE_WALLPAPERS` : Plante `01_bottom`,
  Feu `02_bottom`, Eau `03_bottom`), sinon rien.
Haut / bas : aperçu direct ; A : garder ; B : annuler / revenir. Les choix sont enregistrés dans la sauvegarde
(`$user_data[:pokesmart]`).
