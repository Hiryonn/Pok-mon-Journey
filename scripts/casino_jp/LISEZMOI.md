# Casino JP : la machine à sous « version japonaise »

Machine alternative à celle du jeu : elle ne remplace pas `casino(:slotmachine, 2)`, elle se lance avec une autre commande.

## Utilisation
Dans un évent (commande Script), à la place de `casino(:slotmachine, 2)` :
```ruby
casino_jp        # vitesse 2
casino_jp(3)     # rouleaux plus rapides
```
Le reste de l'évent (question « Voulez-vous jouer ? », test du Pass-Jetons `$bag.contain_item?(:coin_case)`, jetons suffisants) ne change pas.
Les jetons sont ceux de la variable 41, comme dans les évents de la salle de jeux.

## Règles
- Haut / bas : mise de 1, 2 ou 3 jetons. A : lancer, puis A arrête les rouleaux un par un (de gauche à droite). B : quitter (entre deux parties).
- Le résultat est tiré au sort au lancement ; l'arrêt des rouleaux le fait apparaître sur la ligne du milieu.
- Gain = gain du symbole x mise : baie x2, Marill x5, Pikachu x10, 7 x50. Trois « Replay » : la partie suivante est gratuite.
- Rendement d'environ 90 % des jetons misés (simulé sur 200 000 parties). Tout se règle dans `00100 Configuration.rb` :
  `PAYOUT` (gains), `OUTCOMES` (chances, en pour mille), `SPEED_UNIT`, `COIN_VARIABLE`, `MAX_COINS`, sons `SE_*`.

## Fichiers
| Fichier | Rôle |
|---|---|
| `00100 Configuration.rb` | réglages et règles (tirage, arrêt des rouleaux, gains) |
| `00101 Scene.rb` | la scène (machine, rouleaux, chiffres, textes français / anglais) |
| `00102 Commandes.rb` | la commande `casino_jp` |

Graphismes : `graphics/interface/casino_jp/` (machine, symboles, chiffres, fonds), découpés dans la planche d'origine par
`python tools/casino-jp/decouper_planche.py` (planche : `tools/casino-jp/planche/Casino_Slot.png`).
Les textes japonais de la planche sont effacés : le plugin écrit les siens.

Construction : ajouter `casino_jp` à `construire_plugins.bat` (déjà fait), puis le lancer.
Non repris de la planche : la partie « Starter » avec Queulorior et ses dessins, les fonds animés.
