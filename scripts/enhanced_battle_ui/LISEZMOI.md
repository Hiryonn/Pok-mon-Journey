# Enhanced Battle UI

Plugin PSDK inspiré de « Enhanced Battle UI » de Pokémon Essentials. Il fonctionne avec l'interface de combat PE
(plugin interface_horizon) ou avec l'interface de base de PSDK, en 1 contre 1 et en 2 contre 2.

## En combat

| Où | Touche | Effet |
|---|---|---|
| Choix de l'attaque | X | Ouvre / ferme le panneau des infos de l'attaque : type, catégorie, PP, puissance, précision, chance d'effet, particularités (contact, coup de poing, son…), description, et efficacité sur chaque adversaire. Le panneau suit l'attaque choisie. |
| Choix de l'action | Y | Choix d'un Pokémon sur le terrain (avec les Poké Balls des équipes), puis sa page d'infos : niveau, PV, types, statut, talent et objet (Pokémon du joueur), dernière attaque, modifications de stats, effets en cours (météo, champ, protections, pièges…) avec les tours restants et leur description. Gauche / droite : autre Pokémon, haut / bas : effets, B : retour. |
| Choix de l'action, combat sauvage | X | Lancer rapide de Poké Ball : gauche / droite pour choisir la Ball, A pour la lancer, Y pour sa description, B pour revenir. |

## Réglages

`scripts/00100 Configuration.rb` : touches, panneau qui reste ouvert, talent / objet des adversaires visibles,
cases d'efficacité, lancer rapide (`BALL_KEY = nil` pour garder « dernier objet utilisé » de PSDK), textes et effets.

## Images

`graphics/interface/enhanced_battle_ui` : faites par `tools/build_assets.py` à partir des assets d'Essentials
(réduits de moitié pour l'écran 320 x 240) :

    python tools/build_assets.py "<dossier Graphics/Plugins/Enhanced Battle UI>" "<racine du projet>"

Le fond du panneau d'attaque a une ligne par type du projet (Data/Studio/types) : relance le script après avoir ajouté un type.
