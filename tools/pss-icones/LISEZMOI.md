# Planches des icônes PSS

`planches/PSS_Icon_2.png` est la planche source : une grille de 22 lignes x 19 colonnes de cases de 40x40 sur fond vert
`(0,255,80)` (le bleu-vert `(0,128,128)` marque une case vide). `planches/PSS_Icon.png` est la même chose sur fond transparent,
présentée autrement (elle n'est pas utilisée par le script).

```
python tools/pss-icones/decouper_planches.py     (depuis la racine du projet ; nécessite Pillow)
```

écrit :
- `graphics/icones_pss/pieces/<catégorie>/<série>_<nom>.png` : 227 pièces de 40x40 sur fond transparent ;
- `Data/configs/plugins/icone_pss_pieces.json` : le catalogue (séries, couleurs, accessoires…), lu par Studio et par le plugin.

## Ce que contient la planche

| Lignes | Contenu |
|---|---|
| 0 à 3 | icônes toutes faites (non découpées : le générateur en crée de nouvelles) |
| 4 à 6 | hauts (13 couleurs pour la série A, 13 pour la série B), accessoires de la série A |
| 7 à 14 | **série A** : yeux (6), peau (3), frange (5 couleurs), coiffures (5 modèles x 5 couleurs, plus un 6e modèle en une pièce), chapeaux (28) |
| 15 à 21 | **série B** : yeux (6), peau (3), coiffures (4 modèles x 5 couleurs), chapeaux (19), accessoires |

Les pièces sont déjà à leur place dans la case : on les empile, de l'arrière vers l'avant :
cheveux (arrière), haut, peau, yeux, frange, cheveux (avant), accessoire, chapeau.

Chaque modèle de coiffure est fait de deux pièces par couleur (arrière et avant) ; la planche les range l'une après l'autre.
Les noms (« Barrettes », « Rubans », « Étoiles »…) sont ceux de la découpe : ils se changent dans la liste `accessoires` du
script (`decouper_planches.py`), puis on relance la découpe.
