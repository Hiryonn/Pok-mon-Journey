# Plugin « advanced_pokedex » : pages Données, Tâches, Taille et Poids du Pokédex

Compare la taille et le poids d'un Pokémon avec des personnages (le joueur par défaut), comme dans Pokémon Essentials.

## Installation
1. `construire_plugins.bat` à la racine du projet (reconstruit et installe tous les plugins).
2. Studio : `tools/studio-advanced-pokedex/installer_advanced_pokedex.bat` (l'éditeur Smartphone doit être installé), puis redémarre Studio.

## En jeu
Dans la fiche d'un Pokémon du Pokédex : **DROITE** ouvre la page Données (Pokédex Horizon), puis Tâches, Taille et Poids.
- Gauche / droite : page Données ↔ Tâches ↔ Taille ↔ Poids (gauche sur la première page : retour à la fiche)
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

## Habillage Pokédex Horizon
Avec le plugin interface_horizon (Pokédex Horizon actif), les pages prennent le style de la fiche PE
(`interface_horizon/scripts/00100 Pokedex/008 Advanced Pokedex.rb`, fonds `graphics/pokedex/pe/adv_height` et `adv_weight`) :
bandeau avec la Poké Ball et le nom, cadre blanc, deux bandes d'infos, barre du bas Fiche / Taille / Poids / Perso. (cliquable).
Réglage « Habillage » dans Studio : Automatique, Pokédex Horizon ou Essentials.

## Couleur, habitat, génération (page Pokémon de Studio)
Bloc « Couleur, habitat, génération » ajouté à côté du bloc Pokédex de la page Pokémon ; un clic ouvre la fenêtre de réglage
(couleur du Pokédex, habitat de la liste ou personnalisé, génération : 0 = Fakemon, vide = d'après le n° national).
Pour une forme autre que 0 : « Toute l'espèce » ou « Forme N seulement ».
Fichier : `Data/configs/plugins/pokedex_infos.json`. En jeu : `pokemon.dex_color`, `dex_habitat`, `dex_generation`, `fakemon?`,
`PokedexInfos.color_name(:bulbasaur)`, `PokedexInfos.creatures(generation: 0)` (voir `00103 Infos Pokedex.rb`).

## Page Données (Pokédex Horizon)
D'après « Pokedex Data Page » d'Essentials (Lucidious89), `scripts/00105 Page Donnees.rb` :
- stats de base en barres colorées et total ;
- talents et talent caché, groupes d'œufs (pastilles colorées), répartition des sexes, pas d'éclosion, taux de capture,
  expérience de base, courbe d'expérience, EV donnés ;
- habitat (réglé dans Studio) et famille d'évolution (silhouette pour les Pokémon jamais vus) ;
- **A** (ou la case « Capac. » de la barre du bas) : capacités par niveau, CT, œuf, tuteur (gauche / droite) avec type,
  catégorie, puissance, précision, PP et description ;
- **X** (ou clic sur le cadre de droite) : talents avec leur description ;
- **Y** (ou clic sur la bande du bas) : évolutions de la famille et leurs conditions (??? pour un Pokémon jamais vu).
Graphismes : `graphics/pokedex/pe/adv_data.png` et `graphics/pokedex/advanced/data/`
(`tools/advanced_pokedex/build_data_page.py`). Sans le Pokédex Horizon (habillage Essentials), seules Taille et Poids
existent.

## Page Tâches (Pokédex Horizon)
Tâches de recherche comme le Pokédex de Légendes Arceus (d'après « Pokedex Tasks » de dewm3734),
`scripts/00106 Taches.rb` (règles et suivi) et `scripts/00107 Page Taches.rb` (page) :
- chaque palier atteint donne 1 point ; la recherche est terminée à 10 points (coche verte) ;
- tâches suivies en jouant : capturés (et la nuit), vaincus, vaincus avec un type, capacité vue en combat, évolutions,
  combats gagnés en tenant un objet ;
- sans liste réglée, chaque espèce reçoit : capturer, vaincre, voir utiliser une de ses capacités, vaincre avec un type
  super efficace, évoluer (s'il évolue) ;
- 5 tâches par écran, **A** (ou « Suite ») montre les suivantes.
Réglages : `Data/configs/plugins/pokedex_tasks.json` (`points_needed`, `auto_tasks`, paliers par type, tâches par espèce).
Commandes : `tache_pokedex(:bulbasaur, :move, :vine_whip, 1)`, `recherche_pokedex(:bulbasaur)`,
`recherche_terminee?(:bulbasaur)`, `nombre_recherches_terminees`.
Graphismes : `graphics/pokedex/pe/adv_tasks.png`, `graphics/pokedex/advanced/tasks/` (`tools/advanced_pokedex/build_tasks_page.py`).
