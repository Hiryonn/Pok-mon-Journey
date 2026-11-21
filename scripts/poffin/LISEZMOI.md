# Poffin

Cuisiner des poffins avec des baies (cuisson inspirée de Pokémon Platine), puis les donner aux Pokémon pour améliorer leurs
conditions de concours (Sang-froid, Beauté, Charme, Intelligence, Robustesse) et leur lustre.

## Commandes d'évent (Script)
```ruby
cuisiner_poffin                       # choisir des baies du sac et cuisiner (vrai si un poffin a été fait)
nourrir_poffin                        # ouvre la boîte à poffins pour en donner un à un Pokémon de l'équipe (vrai si un poffin a été mangé)
nombre_poffins                        # condition d'évent : combien de poffins a le joueur
donner_poffin([20, 0, 0, 0, 10], 15)  # ajoute un poffin : saveurs (épicé, sec, doux, amer, acide) et douceur
```
Les poffins sont gardés dans `$user_data[:poffins]` (sauvegardés avec la partie, 100 au maximum).

## Jouer
1. **Baies** : haut / bas choisit une baie du sac, **A** l'ajoute (4 au plus, la même plusieurs fois si on en a assez),
   **B** retire la dernière (ou quitte), **Y** passe à la cuisson. Les saveurs prévues s'affichent en haut.
2. **Cuisson** : **A** lance. Tourner avec les flèches : haut, droite, bas, gauche, haut... (dans un sens ou dans l'autre).
   Trop lentement : le feu monte (anneau bleu, jaune puis rouge) et le poffin finit par brûler ; trop vite : la pâte déborde.
   La cuillère montre le sens, la flèche verte / bleue l'allure. Au bout de 20 secondes : « FINI ! ».
3. **Résultat** : le nom, les saveurs et la douceur ; **A** range le poffin dans la liste. Les baies sont consommées au début de la cuisson.

## Règles (simplifiées par rapport à Platine)
- Saveur = somme des saveurs des baies - nombre de baies ; douceur = douceur moyenne - nombre de baies.
  Les saveurs et la douceur de chaque baie viennent des données de Studio (`Data/Studio/items/*berry*.json`, `cookingData`).
- Bien tourner garde toute la valeur (de 60 % à 100 % selon le temps bien tourné), chaque débordement retire 5 %.
- Paliers (plus forte saveur) : simple, moelleux (25), riche (60) ; les images `pofin_1` à `pofin_3` suivent le palier.
- Manger un poffin ajoute la moitié de ses saveurs aux conditions (255 chacune, 510 en tout) et sa douceur au lustre (255).
  Un Pokémon qui n'a plus rien à gagner n'en veut pas. Un poffin brûlé n'a aucun effet.
- Tout se règle dans `00100 Configuration.rb` : durée, allure (`PACE_MIN` / `PACE_MAX`), chaleur, paliers, `GAIN_FACTOR`.
- Les conditions sont lues dans `pokemon.contest_conditions` et `pokemon.sheen` (ceux du résumé, page Concours).

## Fichiers
| Fichier | Rôle |
|---|---|
| `00100 Configuration.rb` | réglages, baies, recette, poffins du joueur, effet sur un Pokémon |
| `00101 Scene Cuisine.rb` | choix des baies, cuisson, résultat |
| `00102 Scene Boite.rb` | boîte à poffins : liste triable, détail des saveurs, écran « donner » avec pentagone des concours |
| `00103 Commandes.rb` | les commandes d'évent |

Graphismes : `graphics/interface/poffin/` (écrans de 256x192 posés au centre de l'écran de 320x240), découpés dans la planche
d'origine par `python tools/poffin/decouper_planche.py` (planche : `tools/poffin/planche/Poffin_Baking.png`).
Construction : `construire_plugins.bat` (le plugin est dans la liste).

## Boîte à poffins

`nourrir_poffin` ouvre la boîte (liste de 5 lignes, saveurs et douceur du poffin sélectionné).

| Touche | Effet |
|---|---|
| Haut / Bas | choisir un poffin |
| A | donner le poffin : écran du Pokémon avec pentagone (prévisualisation du gain) |
| X | changer le tri (date, niveau, douceur, nom) |
| B | quitter |

Un poffin brûlé est refusé par le Pokémon. Les images `donner_fond` et `donner_damier` sont découpées mais pas utilisées.
Les images de la boîte sont générées par `tools/poffin/decouper_boite.py`.
