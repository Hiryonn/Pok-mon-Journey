# Plugin « advanced_pokedex » : pages Taille et Poids du Pokédex

Compare la taille et le poids d'un Pokémon avec des personnages (le joueur par défaut), comme dans Pokémon Essentials.

## Installation
1. `construire_plugins.bat` à la racine du projet (reconstruit et installe tous les plugins).
2. Studio : `tools/studio-advanced-pokedex/installer_advanced_pokedex.bat` (l'éditeur Smartphone doit être installé), puis redémarre Studio.

## En jeu
Dans la fiche d'un Pokémon du Pokédex : **DROITE** ouvre la page Taille.
- Gauche / droite : page Taille ↔ Poids (gauche sur Taille : retour à la fiche)
- Haut / bas : Pokémon précédent / suivant
- A (ou clic sur le cadre de droite) : personnage suivant
- B : retour
Par défaut, seulement pour les Pokémon capturés (réglable).

## Studio : Données > Pokédex > Taille / Poids
Aperçu en direct (mêmes images et mêmes calculs qu'en jeu) :
- personnages : nom (vide = nom du joueur), taille (m), poids (kg), image dans graphics/ et image de la planche ;
- mise en page : curseurs, ou glisser le Pokémon, le personnage ou la balance dans l'aperçu ;
- textes « Taille » / « Poids » (fr / en), couleur des silhouettes, titres, onglets.
Enregistrer écrit `Data/configs/plugins/advanced_pokedex.json` et met le plugin à jour.

## Graphismes (graphics/pokedex/advanced/)
bg_height, bg_weight (320x240), title_height, title_weight, tab_height, tab_weight (haut : inactif, bas : actif),
scale (11 images de la balance, de haut en bas : plateau gauche en haut → en bas).

## Habillage Pokédex PE
Avec le plugin interface_pe (Pokédex PE actif), les pages prennent le style de la fiche PE
(`interface_pe/scripts/00100 Pokedex/008 Advanced Pokedex.rb`, fonds `graphics/pokedex/pe/adv_height` et `adv_weight`) :
bandeau avec la Poké Ball et le nom, cadre blanc, deux bandes d'infos, barre du bas Fiche / Taille / Poids / Perso. (cliquable).
Réglage « Habillage » dans Studio : Automatique, Pokédex PE ou Essentials.

## Couleur, habitat, génération (page Pokémon de Studio)
Bloc « Couleur, habitat, génération » ajouté à côté du bloc Pokédex de la page Pokémon ; un clic ouvre la fenêtre de réglage
(couleur du Pokédex, habitat de la liste ou personnalisé, génération : 0 = Fakemon, vide = d'après le n° national).
Pour une forme autre que 0 : « Toute l'espèce » ou « Forme N seulement ».
Fichier : `Data/configs/plugins/pokedex_infos.json`. En jeu : `pokemon.dex_color`, `dex_habitat`, `dex_generation`, `fakemon?`,
`PokedexInfos.color_name(:bulbasaur)`, `PokedexInfos.creatures(generation: 0)` (voir `00103 Infos Pokedex.rb`).
