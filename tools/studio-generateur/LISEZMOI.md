# Générateur de personnages (Pokémon Studio)

Onglet **Données > Personnages > Générateur** : assemble un personnage (genre, peau, coiffure, haut, bas, chapeau, sac et leurs
couleurs, ou tout au hasard avec des cadenas pour garder des pièces) et écrit dans le projet :

| Sprite | Fichier |
|---|---|
| Marche / Course / Vélo | `graphics/characters/<nom>_<m\|f>_walk`, `_run`, `_cycle_roll` |
| Nage | `graphics/characters/<nom>_<m\|f>_swim` |
| Arrosage (baies) | `graphics/characters/<nom>_<m\|f>_misc2` |
| Dresseur de face | `graphics/battlers/Battlers DS/<nom>_<m\|f>` |
| Dresseur de dos | `graphics/battlers/<nom>_<m\|f>_back` |

Pour le joueur : `$game_player.set_appearance_set('<nom>')` (PSDK prend `<nom>_m_walk`, `<nom>_f_run`…).

Les pièces sont lues dans des dossiers hors du projet (réglables en bas de la page) :
- dossier « automatique » : sous-dossiers `overworld walk`, `overworld run`, `overworld bike`, `trainer front male`…
  contenant `base(s)`, `hair`, `tops` / `clothing`, `bottoms`, `hats`, `carrying stuff` ;
- dossiers Nage / Arrosage : `Base`, `Hair`, `Tops`, `Bottoms`… avec des fichiers « Pièce (couleur).png ».

Réglages et personnages gardés : `Data/configs/generateur_personnages.json`.

Installation : `installer_generateur.bat` (Studio fermé), après `tools/studio-plugins/installer_pages.bat`.

## Recoloration

Onglet **Données > Personnages > Recoloration** : choisis un PNJ (`graphics/characters/npc_*.png`) ou un dresseur
(`graphics/battlers/Battlers DS`). Ses couleurs sont regroupées en zones (contours, peau, gris, puis par teinte) :
change la teinte, la saturation et la luminosité de chaque zone, ou 🎲 Au hasard (les zones verrouillées sont gardées).
**Enregistrer** écrit la nouvelle image à côté de l'originale, sous un autre nom (`<original>_recolor1`…).
