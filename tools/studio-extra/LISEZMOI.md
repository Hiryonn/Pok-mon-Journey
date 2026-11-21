# Pokémon Studio Extra : installateur unique

`installer_studio_extra.bat` (à la racine du projet) réinstalle **tout** Studio Extra dans Pokémon Studio, en une fois.
À lancer **après chaque mise à jour de Studio** (une mise à jour remplace les fichiers de Studio et efface Studio Extra),
Studio fermé. On peut le relancer autant de fois qu'on veut : il repart toujours des fichiers d'origine de Studio.

Il demande s'il faut **bloquer les mises à jour automatiques** de Studio (conseillé : sinon Studio Extra disparaît à la
prochaine mise à jour, jusqu'à ce qu'on relance l'installateur).

## Ce qu'il fait

1. Copie les fichiers d'origine de Studio dans `resources\app\.vite\.pj-origine` (ou les remet en place s'il a déjà été lancé).
2. Installe toutes les pages : chaque `tools\studio-*\installer_*.ps1` est lu (fichiers, `index.html`, `preload.js`,
   `index.js`). Une nouvelle page avec son `installer_*.ps1` est donc prise automatiquement.
3. Modifie le code de Studio : menus et pages (`studio-plugins\patch_studio_pages.py`), PV des natures
   (`studio-natures\patch_natures_hp.py`), dossiers des icônes (`studio-plugins\patch_studio_icons.py`).
4. Thème rouge et nom « Pokémon Studio Extra » (`studio-theme\theme_rouge.py`) ; icône rouge et nom du `.exe`
   (`studio-theme\icone_exe.mjs`, si Node.js est installé). Si Windows garde l'ancienne icône :
   `studio-theme\rafraichir_icones.bat`.
5. Bloque (ou non) la recherche de mises à jour de Studio.

Il faut **Python 3** (et Node.js pour l'icône du `.exe`).

## Nouvelles versions de Studio

Le code de Studio est « minifié » : ses noms (`j`, `Aa`, `R$`…) changent à chaque version. `studio_patch.py` les
retrouve : chaque passage des correctifs est cherché avec des jokers à la place des noms, et les vrais noms sont repris
dans le texte ajouté. `symboles.json` contient des passages de la version de référence qui retrouvent les noms
utilisés seulement dans le texte ajouté.

Si l'installateur affiche « Version de Studio non reconnue » après une grosse mise à jour de Studio, il faut refaire
`symboles.json` avec `trouver_symboles.py` (outil de développement : voir l'en-tête du fichier) ou corriger le passage
indiqué dans le correctif.
