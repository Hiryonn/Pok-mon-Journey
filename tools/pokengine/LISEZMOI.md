# Importer des créatures Pokéngine (free to use)

`importer_pokengine.py` convertit une créature téléchargée de [pokengine.org](https://pokengine.org) en créature de ton projet
(images + JSON de Studio + textes). Il ne contacte jamais le site : le site interdit les robots, tu télécharges toi-même.
**Vérifie la permission de chaque créature** (« Free to use with credit » : crédit obligatoire). Le script écrit
`CREDITS_POKENGINE.md` avec les auteurs, à reprendre dans les crédits du jeu.

## Ce qu'il faut pour chaque créature
Dans un même dossier (ex. `telechargements/`) :
- la **fiche en PDF** (imprimer la page en PDF, avec la liste des capacités dépliée : bouton « Expand ») : `Geckrow - Pokéngine.pdf`
- les images : `<code>.webp` (icône), `<code>_1.webp` (face), `<code>_2.webp` (dos). Le code est dans le titre de la fiche,
  entre parenthèses (ex. `00xjjwow`).

## Lancer
Le plus simple : double-clique sur **`importer_pokengine.bat`** (il lit le dossier `telechargements` à côté de lui, le crée au premier lancement, installe Pillow/pypdf si besoin). Glisse un autre dossier sur le .bat pour l'utiliser ; `importer_pokengine.bat telechargements essai` n'écrit rien.
En ligne de commande :
```
python3 importer_pokengine.py telechargements chemin/du/projet --dry-run     # essai : n'écrit rien
python3 importer_pokengine.py telechargements chemin/du/projet
```
Besoin de Python 3, de Pillow (`pip install pillow`) et, pour lire un PDF, de `pdftotext` (poppler) ou de `pip install pypdf`.

## Ce qui est écrit
- `graphics/pokedex/pokefront|pokeback|pokeicon/<id>.png` (face et dos à leur taille d'origine, posés en bas d'un cadre 96 x 96 transparent ; `--scale 2` pour les agrandir ; icône 64 x 32) ;
  les versions shiny sont des copies des normales (à refaire à la main si l'auteur en fournit).
- `Data/Studio/pokemon/<nom>.json` : types, stats, talents, taille, poids, courbe d'expérience, groupes d'œufs, œuf, capacités
  (par niveau / à apprendre / œuf), évolution par niveau. Les capacités et talents inconnus du projet sont listés et ignorés.
- `Data/Text/Dialogs/100000|100001|100002.csv` : nom, catégorie, description (anglais dans toutes les langues, à traduire).
- la créature est ajoutée au dex `national_fakedex` (`--dex autre_dex`, ou `--dex aucun`).
- `importes.json` : mémoire des imports. Une évolution vers une créature pas encore importée est mise en attente et
  ajoutée automatiquement quand tu importes l'autre fiche (relance simplement le script).

Les numéros des créatures commencent à 10000 (10000, 10001, …), bien au-dessus des Pokémon du jeu. Une créature déjà importée garde
son ancien numéro. `--start-id` pour en choisir un autre.

## Refaire des créatures déjà importées
- Seulement les images (ex. après un changement de taille) : `importer_pokengine.bat telechargements images`
  (`--images-seulement`). Le JSON, les textes et le dex ne sont pas touchés : ce que tu as réglé dans Studio est gardé.
- Tout (JSON et textes compris, ce qui écrase tes modifications) : `importer_pokengine.bat telechargements refaire` (`--force`).

## Valeurs que la fiche ne donne pas
Taux de capture, ratio de genre et points d'effort sont des images sur la fiche : le script met 45, 50 % de femelles et 0, et te
le dit. Pour les régler, place un `overrides.json` à côté des fiches :
```json
{ "geckrow": { "catchRate": 190, "femaleRate": 12.5, "evHp": 1 } }
```
(clé = nom en minuscules ou code Pokéngine ; les champs sont ceux du JSON de Studio). Le cri est vide (`--cry 0001.ogg` pour en prendre un),
et il n'y a ni sprite de personnage ni empreinte.

## Options utiles
`--scale 1|2|2.5|auto` (agrandissement des sprites, 1 par défaut ; auto = plus grand entier qui rentre), `--icon-scale`, `--force` (refaire une créature déjà importée).

Après l'import, rouvre Studio : il régénère ses fichiers de textes.

## Follower (`_3`)

Si tu mets l'image `code_3.webp` (ou `code (3).webp`) à côté des autres, elle est convertie en planche de follower au format RPG Maker
(4 colonnes x 4 lignes : bas, gauche, droite, haut ; les 2 images d'animation Pokéngine sont répétées) et écrite dans
`graphics/characters/<id>.png` et `<id>s.png`. Les champs `character` / `characterShiny` du JSON sont remplis.
Si gauche et droite sont inversés dans le jeu, ajoute `--follower-inverse`. Avec « images », un Pokémon déjà importé reçoit son follower.

## Formes de Pokémon existants : `importer_formes_pokengine.bat`

Même principe, mais la fiche devient **une forme** d'un Pokémon déjà dans le projet (rien n'est créé ailleurs) :
- dossier `tools\pokengine\telechargements_formes` : fiche + images (`code`, `code_1`, `code_2`, `code_3`) ;
- le Pokémon de base est trouvé avec le nom de la fiche (`Alolan Vulpix` → `vulpix`) ; sinon un fichier `formes.json` dans ce dossier :
  `{"code_pokengine": "vulpix"}` ;
- le numéro de forme est le suivant libre du Pokémon (`--form-id` pour en imposer un) ;
- ajoutés : la forme dans `Data/Studio/pokemon/<base>.json` (stats, types, talents, capacités), son nom et sa description
  (`Data/Text/Dialogs/100067` et `100068`), et les images `<id>_<forme>.png` (combat, icône, follower) ;
- mêmes options : « essai », « images », « refaire ». La mémoire est `formes_importees.json`.

## Capacités : `importer_capacites_pokengine.bat`

Imprime en PDF la page d'une capacité Pokéngine (ex. « Bolt In ») et mets-la dans `tools\pokengine\telechargements_capacites`.
Le script crée `Data/Studio/moves/<symbole>.json` (id à partir de 10000, `--start-id` pour changer) et ajoute le nom et la description
dans `Data/Text/Dialogs/100006` et `100007`.
Lu sur la fiche : type, catégorie, puissance, précision, PP, contact, copiable, cible, description.
**Devinés** depuis le texte (à vérifier dans Studio, le script les liste) : hausses/baisses de stats, statut, chance de l'effet.
Non importés : l'animation, la priorité, les autres drapeaux (morsure, poing, son…). `overrides_capacites.json` dans le dossier des fiches
corrige un champ : `{"07nonuuq": {"priority": 1, "battleEngineAimedTarget": "adjacent_foe"}}`.
Les fiches qui ne sont pas des capacités sont ignorées, et inversement. Mémoire : `capacites_importees.json`.

## Ce qui est lu dans le dessin du PDF (`pdf_barres.py`)

Trois infos ne sont pas écrites en texte sur la fiche mais dessinées ; le script les lit avec `pypdf` (installé par les `.bat`) :
- **Catch rate** : part verte de la barre x 255 (ramenée à une valeur usuelle : 45, 190, 255…) ;
- **Gender** : bleu = mâles, rose = femelles, barre vide = asexué (`femaleRate` -1) ;
- **Effort points** : un carré par point, coloré comme la stat (rose PV, rouge Att, bleu Def, violet Att Spé, cyan Déf Spé, vert Vit).
Si la fiche est en `.txt` ou que pypdf manque, les valeurs par défaut sont utilisées (et listées dans « À vérifier »).
Le **nom de la forme de base** est maintenant créé aussi (`Data/Text/Dialogs/100067`), sinon Studio affichait « Bulbizarre » ; les
Pokémon déjà importés sont réparés au prochain lancement. Pour qu'un Pokémon déjà importé prenne aussi capture / genre / effort,
relance avec « refaire » (le JSON est réécrit : tes réglages Studio sur lui sont perdus).
La permission « Do not use » d'une fiche n'est pas bloquante : elle est seulement notée dans CREDITS_POKENGINE.md.

## Noms composés : nom + forme

Sur Pokéngine, « Mobipup Green » = le Pokémon **Mobipup**, forme **Green**. Le script lit donc le premier mot comme nom du Pokémon
(symbole `mobipup`, texte 100000 « Mobipup ») et le reste comme nom de forme (100067 « Green »). Un nom d'un seul mot (Geckrow) n'a pas
de forme : le nom de forme reprend le nom. Pour une vraie exception (« Mr. Mime »), mets un fichier `noms.json` dans le dossier des fiches :
`{"code_pokengine": ["Mr. Mime", ""]}` (nom, forme). Les Pokémon déjà importés sous l'ancien nom (`mobipup_green`) sont renommés
automatiquement au prochain lancement (fichier, textes, dex). Dans `importer_formes_pokengine.bat`, « Mobipup Pink » devient la forme
« Pink » de `mobipup`.

## Talents (collections HUB et Uranium)
1. `creer_talents_pokengine.bat` (Studio fermé) crée les 66 talents manquants dans la base (JSON + noms/descriptions anglais) ; les 6 déjà présents sont ignorés. Option `essai`.
2. `construire_plugins.bat` construit le plugin `extra_abilities_additions` (un fichier .rb par talent, 71 talents codés sur 72 (seule la pêche de Reel In manque), écrits avec l'API du moteur : Battle::Effects::Ability).
3. Taste Buds est codé (Baies/Herbes consommées : effet reproduit sur les alliés vivants via `Battle::Effects::Item`).
4. Limites : **Reel In** ne double pas les chances de pêche hors combat (point d'accroche introuvable dans la doc du moteur) ; Perceive bloque Morphing et Imposteur (Illusion seulement si la classe existe) ; Clairvoyance met le compte à rebours de Prescience/Carnar à 1 (à vérifier en jeu) ;
   Filthy Surge crée un Terrain Sale simple (Poison x1,3) et Acid Cloud une Pluie Acide (1/16 des PV par tour, sauf Poison) ; Double Tap, Mechanic Shift, Time Twist, Tight Grip dépendent de classes du moteur à vérifier en jeu.
