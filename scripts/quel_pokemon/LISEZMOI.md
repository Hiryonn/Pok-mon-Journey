# Quel est ce Pokémon ?

Mini-jeu : un Pokémon à deviner chaque jour (date de l'ordinateur du joueur), d'après sa silhouette,
avec le fond, le jingle et les sons de « Who's that Pokémon ».

- Studio : **Level design > Mini-jeux > Quel est ce Pokémon** (`tools/studio-quelpokemon/installer_quelpokemon.bat`,
  Studio fermé, puis `construire_plugins.bat` une fois). Aperçu du Pokémon du jour et des 7 suivants (même tirage
  qu'en jeu), Pokémon possibles (numéros, vus dans le Pokédex ou liste), réponses proposées, essais, récompenses,
  bonus de série.
- Réglages : `Data/configs/plugins/quel_pokemon.json`.
- Images / sons : `graphics/interface/minigames/whosthatpokemon.png`, `audio/se/minigames/WhosThatPokemon.ogg`,
  `Correct.ogg`, `Incorrect.ogg`.

## Commandes (Script)

```ruby
quel_est_ce_pokemon                 # lance la partie du jour (une seule par jour)
quel_est_ce_pokemon(variable: 12)   # 1 trouvé, 2 raté, 3 déjà joué aujourd'hui
quel_pokemon_joue_aujourdhui?       # true / false
quel_pokemon_serie                  # jours trouvés d'affilée
```
