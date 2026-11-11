# Gimmicks — Méga-Évolution, capacités Z, Dynamax / Gigamax, Téracristal

Plugin PSDK de Pokémon Journey, avec l'interface de combat PE (plugin interface_pe).

## Règles

- Chaque mécanique s'utilise **une fois par combat et par dresseur**.
- Un Pokémon qui utilise une mécanique **n'a plus accès aux autres** jusqu'à la fin du combat.
- Les quatre peuvent servir dans le même combat, chacune avec un Pokémon différent.
- Un Pokémon qui tient une méga-gemme ou un cristal Z peut quand même choisir Téracristal ou Dynamax.

## En combat

Pendant le choix de l'attaque, **Y** fait défiler les mécaniques possibles pour le Pokémon : un onglet « ACTION »
apparaît au-dessus des attaques (éteint, puis allumé quand la mécanique est choisie). Avec une capacité Z ou le
Dynamax, les boutons montrent les capacités Z / attaques Max. La mécanique utilisée s'affiche dans la boîte d'infos
(méga, Dynamax / Gigamax, type Téra, Ultra-Explosion).

Cinématique façon Pokémon Essentials (zoom sur le Pokémon et son dresseur) ; **A** ou **B** la passe.

| Mécanique | Objet clé (sac) | Le Pokémon |
|---|---|---|
| Méga-Évolution | Méga-Anneau (objet « Permet la méga-évolution ») | tient sa méga-gemme (évolution « méga-gemme » dans Studio) |
| Capacités Z | Bracelet Z (`z_ring`, `z_power_ring`) | tient un cristal Z ; cristal de type : attaques de ce type ; cristal exclusif : son attaque |
| Dynamax / Gigamax | Poignet Dynamax (`dynamax_band`) | 3 tours, PV x (1,5 + 0,05 x niveau Dynamax), attaques Max ; Gigamax avec le facteur Gigamax |
| Téracristal | Orbe Téracristal (`tera_orb`) | prend son type Téra ; l'Orbe se recharge quand l'équipe est soignée |

Les dresseurs adverses s'en servent aussi (l'objet clé dans leur sac, ou coché dans Studio : Plugins > Gimmicks >
Dresseurs). Un Pokémon sauvage ne s'en sert que si une commande d'évènement l'autorise pour le prochain combat.

## Studio

**Plugins > Gimmicks** (`tools/studio-gimmicks/installer_gimmicks.bat`, Studio fermé) :
- Réglages : mécaniques actives au début de la partie, cinématique, dresseurs, Dynamax, Orbe Téracristal ;
- Pokémon : type Téra par défaut, facteur Gigamax d'office, Dynamax interdit ;
- Dresseurs : mécaniques utilisables, type Téra / Gigamax / niveau Dynamax de chaque Pokémon de l'équipe.

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
