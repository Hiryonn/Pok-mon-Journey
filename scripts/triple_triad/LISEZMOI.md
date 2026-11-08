# Plugin « triple_triad » : Triple Triad comme dans Pokémon Essentials

Jeu de cartes Pokémon sur un plateau 3x3. Chaque carte a 4 valeurs (haut, droite, bas, gauche) de 1 à 10 (A),
calculées depuis les stats de base du Pokémon (comme Essentials). Poser une carte à côté d'une carte adverse
la capture si la valeur qui la touche est plus grande. À la fin, le plus de cartes (plateau + main) gagne.

## Installation
`construire_plugins.bat` à la racine du projet (reconstruit et installe tous les plugins).

## En jeu
- Avant le duel : choix des 5 cartes (A : ajouter, B : retirer / abandonner, Y : les 5 meilleures automatiquement).
- Duel : haut / bas pour la carte, A, puis flèches pour la case, A (B : revenir). Souris possible.
- Pile ou face pour savoir qui commence. L'adversaire joue le coup qui lui rapporte le plus.
- À la fin (règle par défaut « une carte ») : le gagnant prend une carte du perdant (le joueur la choisit).

## Commandes d'évent (Script)
```ruby
give_triad_card(:pikachu, 2, message: true)   # donner des cartes (il en faut 5 pour jouer)
triple_triad_duel('Léo', 2, 5)                # duel : cartes adverses de niveau 2 à 5 (sur 9)
triple_triad_duel('Léo', 0, 9, [:open, :same, :plus, :trade_none], nil, variable: 12)
triple_triad_duel('Léo', 0, 9, [], [:pikachu, :eevee, :snorlax, :mew, :ditto])   # cartes imposées
triple_triad_won?                             # dernier duel gagné ?
triple_triad_collection                       # voir ses cartes
triple_triad_shop                             # boutique (Pokémon vus), ou triple_triad_shop([:pikachu, :eevee])
triple_triad_sell                             # vendre (moitié du prix)
triad_card_count(:pikachu) / triad_card_total / take_triad_card(:pikachu)
```
Résultat d'un duel : 1 victoire, 2 défaite, 3 égalité, 0 abandon ou pas assez de cartes.

## Règles
open (main adverse visible), random (5 cartes au hasard), same (Pareil), samewall (Pareil mur),
plus (Plus), elements (cases à type : +1 / -1), suddendeath (mort subite en cas d'égalité),
trade_none / trade_one (défaut) / trade_direct (chacun garde ce qu'il a capturé) / trade_all.

## Graphismes
`graphics/interface/triple_triad/` : fond et cartes réduits de tes images (dessinées en double taille),
dos de carte, curseur, fond de la liste de cartes.
