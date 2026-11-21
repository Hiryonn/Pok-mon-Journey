# Insignes

Des distinctions pour les Pokémon, comme les rubans : 168 insignes (6 couleurs x 28) tirés de la planche de médailles.
Chaque Pokémon garde ses insignes (sauvegardés avec lui) et les montre dans son résumé, page **Insignes** (après le Mémo).

## Donner un insigne
Dans un évent (commande Script) ; le numéro est la place du Pokémon dans l'équipe (0 = le premier) :
```ruby
donner_insigne(0, :or_crown_4)     # vrai s'il est ajouté, faux s'il l'avait déjà ou s'il n'existe pas
retirer_insigne(0, :or_crown_4)
insigne?(0, :or_crown_4)           # condition d'évent
nombre_insignes(0)
donner_tous_les_insignes(0)        # pour tester la page
```
Identifiants : `<couleur>_<motif>_<palier>` : couleurs `bronze bleu rouge rose or argent` ;
motifs `ball heart sun crown` (paliers 1 à 4), `stars` (1 à 6), `wing_ball wing_sun wing_heart wing_crown honor mystery` (sans palier).
Exemples : `bronze_ball_1`, `or_crown_4`, `argent_stars_6`, `rose_wing_heart`, `bleu_honor`.
La liste complète est dans `Data/configs/plugins/insignes.json`.

## Dans le résumé
Page 7 (après le Mémo) : grille de 5 x 3 insignes. **A** sélectionne (curseur), les flèches déplacent le curseur et font défiler,
le nom et la description s'affichent dans le cadre gris, **B** revient (puis gauche / droite changent de page comme d'habitude).
Sans sélection, le cadre gris montre le Pokémon ; sans insigne, la page indique « Aucun insigne ».
Cette page est dans le plugin `interface_pe` (`scripts/00110 Resume/012 Page Insignes.rb`).

## Modifier ou ajouter
- Noms et descriptions (français / anglais) : à la main dans `insignes.json`. Ne pas relancer `tools/insignes/decouper_planche.py`
  sans `--sans-catalogue`, il réécrit le catalogue.
- Nouvel insigne : une image 32x32 dans `graphics/interface/insignes/` et une entrée dans `insignes.json`
  (`id`, `nom` [fr, en], `description` [fr, en]).

## Construction
`construire_plugins.bat` (le plugin `insignes` est dans la liste, ainsi que `interface_pe` pour la page).
Images : `python tools/insignes/decouper_planche.py` (planche : `tools/insignes/planche/Medal.png`).
