# Générateur de personnages (en jeu)

1. Dans Studio : **Générateurs > Personnages > Dossiers des pièces > Préparer pour le jeu**
   (copie les pièces dans `graphics/generateur` et écrit `Data/configs/plugins/generateur_pieces.json`).
2. Lancer `construire_plugins.bat`.
3. Dans un évènement, commande **Script** :
   - `personnaliser_joueur` : écran de création (le joueur doit valider)
   - `personnaliser_joueur(true)` : idem, B annule
   - `joueur_personnalise?` : condition, le joueur a déjà créé son personnage
   - `personnage_joueur_au_hasard` / `personnage_joueur_au_hasard('f')`

## Choix du genre

Sur l'écran de création, le joueur choisit le genre de son personnage (**Garçon** ou **Fille**, premier réglage de la
page « corps »). Les coiffures, tenues et accessoires proposés s'adaptent ensuite au genre choisi, et les choix qui ne
sont plus valables sont corrigés automatiquement. Le genre choisi met à jour l'interrupteur de genre de PSDK
(`Yuki::Sw::Gender`, activé pour une fille).

Avec `personnage_joueur_au_hasard`, le genre est tiré au sort ; `personnage_joueur_au_hasard('m')` ou
`personnage_joueur_au_hasard('f')` l'impose.

## Sprites

Le personnage utilise le charset `pj_joueur` (marche, course, vélo, nage, arrosage…)
et les battlers `pj_joueur` (dos) / `pj_joueur_front` (face), assemblés à la volée.
Pense à inclure `graphics/generateur` dans la version distribuée du jeu.

## Tenues toutes faites (plugin wardrobe)

`Generateur.apply(spec, true)` garde la clé `outfit_sprites` du personnage : le charset et l'image de face viennent alors de fichiers
(`graphics/characters`, `graphics/pictures`) au lieu des pièces. Sans le second argument (le générateur), cette clé est retirée.
