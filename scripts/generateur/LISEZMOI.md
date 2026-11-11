# Générateur de personnages (en jeu)

1. Dans Studio : **Générateurs > Personnages > Dossiers des pièces > Préparer pour le jeu**
   (copie les pièces dans `graphics/generateur` et écrit `Data/configs/plugins/generateur_pieces.json`).
2. Lancer `construire_plugins.bat`.
3. Dans un évènement, commande **Script** :
   - `personnaliser_joueur` : écran de création (le joueur doit valider)
   - `personnaliser_joueur(true)` : idem, B annule
   - `joueur_personnalise?` : condition, le joueur a déjà créé son personnage
   - `personnage_joueur_au_hasard` / `personnage_joueur_au_hasard('f')`

Le personnage utilise le charset `pj_joueur` (marche, course, vélo, nage, arrosage…)
et les battlers `pj_joueur` (dos) / `pj_joueur_front` (face), assemblés à la volée.
Pense à inclure `graphics/generateur` dans la version distribuée du jeu.
