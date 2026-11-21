# Gimmicks — Méga-Évolution, capacités Z, Dynamax / Gigamax, Téracristal

Plugin PSDK de Pokémon Journey, avec l'interface de combat PE (plugin interface_horizon).

## Règles

- Chaque mécanique s'utilise **une fois par combat et par dresseur**.
- Un Pokémon qui utilise une mécanique **n'a plus accès aux autres** jusqu'à la fin du combat.
- Les quatre peuvent servir dans le même combat, chacune avec un Pokémon différent.
- Un Pokémon qui tient une méga-gemme ou un cristal Z peut quand même choisir Téracristal ou Dynamax.

## En combat

Pendant le choix de l'attaque, **Y** ouvre la roue des mécaniques : toutes celles possibles pour le Pokémon
apparaissent en cercle, on pointe la bonne avec les flèches (diagonales comprises) ou la souris, **A** la choisit
(A sur la mécanique déjà choisie l'annule), **B** ou **Y** referme la roue. L'onglet « ACTION » au-dessus des attaques
montre la mécanique choisie pour ce tour. Avec une capacité Z ou le
Dynamax, les boutons montrent les capacités Z / attaques Max. La mécanique utilisée s'affiche dans la boîte d'infos
(méga, Dynamax / Gigamax, type Téra, Ultra-Explosion).

Cinématique façon Pokémon Essentials (le dresseur arrive, le terrain s'assombrit, sphère Méga, cristal Téra, lignes de vitesse
au moment de la nouvelle forme) ; **A** ou **B** la passe. Un Pokémon Téracristallisé reste couvert du motif de son type
(`graphics/interface/gimmicks/tera_patterns/<type>.png`) jusqu'à la fin du combat.

| Mécanique | Objet clé (sac) | Le Pokémon |
|---|---|---|
| Méga-Évolution | Méga-Anneau (objet « Permet la méga-évolution ») | tient sa méga-gemme (évolution « méga-gemme » dans Studio) |
| Capacités Z | Bracelet Z (`z_ring`, `z_power_ring`) | tient un cristal Z ; cristal de type : attaques de ce type ; cristal exclusif : son attaque |
| Dynamax / Gigamax | Poignet Dynamax (`dynamax_band`) | 3 tours, PV x (1,5 + 0,05 x niveau Dynamax), attaques Max ; Gigamax avec le facteur Gigamax |
| Téracristal | Orbe Téracristal (`tera_orb`) | prend son type Téra ; l'Orbe se recharge quand l'équipe est soignée |

Les dresseurs adverses s'en servent aussi (l'objet clé dans leur sac, ou coché dans Studio : Données > Gimmicks >
<mécanique> > Dresseurs). Un Pokémon sauvage ne s'en sert que si une commande d'évènement l'autorise pour le prochain combat.

## Studio

**Données > Gimmicks** (`tools/studio-gimmicks/installer_gimmicks.bat`, Studio fermé), une sous-section par mécanique :
- Méga-gemmes : objets clés, Pokémon qui méga-évoluent (forme méga + méga-gemme), dresseurs (objet clé, gemme tenue) ;
- Capacités Z : objets clés, cristaux de type et exclusifs, dresseurs (objet clé, cristal tenu) ;
- Téracristal : Orbe Téracristal, type Téra par défaut de chaque Pokémon, dresseurs (objet clé, type Téra de l'équipe) ;
- Dynamax : durée, niveau, facteur Gigamax (général ou par Pokémon), Dynamax interdit, dresseurs (objet clé, Gigamax, niveau).

Chaque page a aussi les réglages communs (cinématique, dresseurs adverses, chance par tour) ; les quatre pages sont
enregistrées ensemble.

Enregistré dans `Data/configs/plugins/gimmicks.json`.

## Commandes d'évènement

Éditeur d'évènements > Insérer une commande > onglet **Plugins** > Gimmicks, ou en Script :

| Commande | Effet |
|---|---|
| `gimmick_actif(:tera, false)` | désactive (true : active) une mécanique pour la suite de la partie |
| `gimmick_sauvage(:dynamax, :tera)` | le prochain Pokémon sauvage pourra utiliser ces mécaniques |
| `type_tera(0, :fire)` | type Téra du 1er Pokémon de l'équipe (`:stellar` : Stellaire) |
| `facteur_gigamax(0, true)` | facteur Gigamax du 1er Pokémon |
| `niveau_dynamax(0, 10)` | niveau Dynamax (0 à 10) du 1er Pokémon |
| `recharger_orbe_tera` | recharge l'Orbe Téracristal |

## Images

`graphics/interface/gimmicks` : faites par `tools/build_assets.py` à partir des ressources d'Essentials (Dynamax,
Terastallization, Z-Power), réduites de moitié pour l'écran 320 x 240 :

    python tools/build_assets.py "<dossier contenant Dynamax, Terastallization et Z-Power>" "<racine du projet>"

Les formes Méga (30, 31…) et Gigamax (40, 41) utilisent les sprites du projet.

## Styles de combat (Légendes Arceus)
Fichiers `00120` à `00122` (ancien plugin `styles_pla`, d'après « PLA Battle Styles » de Lucidious89) : Style Puissant et
Style Rapide dans la roue des mécaniques, maîtrise des capacités (niveaux, Graine Maîtrise, dresseurs, sauvages).
Réglages : `Data/configs/plugins/styles_pla.json` ; graphismes : `graphics/interface/styles_pla/`
(`tools/styles_pla/build_assets.py`) ; son : `audio/se/pla_style.ogg`.
