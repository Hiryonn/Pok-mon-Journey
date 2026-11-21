# Page Studio « Tenues » (plugin wardrobe)

Page **Générateurs > Tenues** (à côté de Personnages) de Pokémon Studio : la liste des tenues du héros, sans toucher au code. La page écrit
`Data/configs/plugins/wardrobe.json`, que le plugin `wardrobe` lit en jeu (Félix et Ann y sont déjà).

## Ce qu'on y règle
- **Objet** : le dbSymbol de l'objet du sac. S'il n'existe pas, **Créer l'objet** écrit `Data/Studio/items/<objet>.json`
  (objets rares, id suivant), son icône (`graphics/icons/<objet>.png` = première case du charset) et son nom / sa description
  (`Data/Text/Dialogs/100012.csv` et `100013.csv`). Redémarrer Studio ensuite.
- **Nom, description** en français et en anglais ; **Pour** : garçons, filles ou les deux.
- **Sprites tout faits** : le charset (`graphics/characters`, 4x4 images) et l'image de face (`graphics/pictures`, 80x80), avec aperçu.
- **Pièces du générateur** : coiffure, haut, bas, chapeau, sac (et leur couleur). « (inchangé) » laisse la pièce du héros,
  « Aucun » retire le chapeau / le sac. Les sprites tout faits, s'il y en a, passent avant les pièces.
- **Enregistrer** écrit le JSON. **Retirer la tenue** l'enlève de la liste (l'objet Studio reste).

Si les textes de l'objet ne peuvent pas être ajoutés automatiquement (le CSV n'est pas aligné sur les ids), la page le dit :
ajouter alors la ligne à la main.

## Installation
1. `tools/studio-plugins/installer_pages.bat` (pages des plugins), puis `installer_wardrobe.bat`, Studio fermé.
2. Rouvrir Studio (Générateurs > Tenues). À relancer après chaque mise à jour de Studio.

## Fichiers
| Fichier | Rôle |
|---|---|
| `pj-wardrobe-main.js` | lecture / écriture des fichiers du projet (canaux `pj-wardrobe:*`) |
| `pj-wardrobe.js`, `pj-wardrobe.css` | la page |
| `installer_wardrobe.bat` / `.ps1` | installation dans Studio |

## Ressources (sprites tout faits)
L'onglet **Ressources** de la page fonctionne comme Personnages > Héros > Ressources : une case par état du héros (marche, course,
vélo, surf, pêche, escalade…), plus l'image de face (menus) et celle de dos (combat). Un clic ouvre la grille d'images du projet.
Un état laissé sur « auto » reprend la marche ; la marche et le dos sans choix reprennent les pièces du générateur.
Dans `wardrobe.json`, `sprites` est donc `{ "walk": "NPC_Felix", "run": "…", "front": "Felix", "back": "…" }` (l'ancien `charset` reste lu comme `walk`).
Ce changement demande aussi les scripts `generateur` et `wardrobe` à jour (état par état dans le jeu).
