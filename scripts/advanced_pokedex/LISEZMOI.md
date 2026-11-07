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

## Studio : Plugins > Advanced Pokédex
Aperçu en direct (mêmes images et mêmes calculs qu'en jeu) :
- personnages : nom (vide = nom du joueur), taille (m), poids (kg), image dans graphics/ et image de la planche ;
- mise en page : curseurs, ou glisser le Pokémon, le personnage ou la balance dans l'aperçu ;
- textes « Taille » / « Poids » (fr / en), couleur des silhouettes, titres, onglets.
Enregistrer écrit `Data/configs/plugins/advanced_pokedex.json` et met le plugin à jour.

## Graphismes (graphics/pokedex/advanced/)
bg_height, bg_weight (320x240), title_height, title_weight, tab_height, tab_weight (haut : inactif, bas : actif),
scale (11 images de la balance, de haut en bas : plateau gauche en haut → en bas).
