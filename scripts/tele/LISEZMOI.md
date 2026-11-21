# Télé

Une télé pour donner des informations au joueur (inspirée de celle de Pokémon Platine) : 8 chaînes, des programmes présentés par
5 présentateurs, chacun avec ses pages de texte. Les programmes pas encore regardés sont marqués « NOUVEAU ».

## Commandes d'évent (Script)
```ruby
tele_regarder                         # ouvre la télé (choix de la chaîne) ; vrai si un programme a été regardé jusqu'au bout
tele_regarder(3)                      # ouvre directement la chaîne 3 (de 1 à 8)
tele_diffuser('aide', 3, 'Astuce', 2, 'Texte de la page 1', 'Texte de la page 2')
                                      # ajoute (ou remplace) un programme : id, chaîne 1-8, titre, présentateur 1-5, pages
tele_retirer('aide')                  # retire un programme diffusé
tele_programmes(3)                    # nombre de programmes (de la chaîne 3, ou de toutes sans argument)
tele_nouveau?(3)                      # vrai s'il reste un programme pas encore regardé (chaîne 3, ou toutes)
tele_vu?('aide')                      # vrai si le programme a été regardé jusqu'au bout
```
Le titre et les pages peuvent être des tableaux `[français, anglais]`. Un texte trop long est coupé automatiquement entre les mots
et réparti sur plusieurs écrans de 3 lignes. Remplacer un programme (même id) le rend de nouveau « NOUVEAU ».
Les programmes diffusés et ceux déjà vus sont sauvegardés avec la partie (`$user_data[:television]`, 60 programmes au maximum).

## Jouer
- **Chaînes** : gauche / droite change de chaîne, **A** l'ouvre (une chaîne vide fait un bruit d'erreur), **B** quitte.
- **Programmes** : haut / bas, **A** regarde, **B** revient aux chaînes.
- **Programme** : **A** passe à l'écran suivant ; le dernier **A** termine le programme (il n'est plus « nouveau »). **B** revient à la liste.

## Programmes fixes
Dans `00100 Configuration.rb`, `STATIC_PROGRAMS` contient les programmes toujours disponibles (un programme de bienvenue en exemple) :
```ruby
{'id' => 'bienvenue', 'channel' => 2, 'presenter' => 1, 'title' => ['Titre', 'Title'],
 'pages' => [['Texte français', 'English text'], 'Un texte sans traduction']}
```
Les noms des chaînes (`CHANNELS`) et des présentateurs (`PRESENTERS`) se changent au même endroit. Les images sont `chaine_1` à `8`
et `presentateur_1` à `5` dans `graphics/interface/tele/` (ordre de la planche : mystères, Pokémon, grotte, boutiques, légendes, habitats,
concours, carte).

## Fichiers
| Fichier | Rôle |
|---|---|
| `00100 Configuration.rb` | chaînes, présentateurs, programmes fixes, stockage, découpage du texte |
| `00101 Scene Television.rb` | chaînes, liste des programmes, lecture |
| `00102 Commandes.rb` | commandes d'évent |
| `tools/tele/decouper_tele.py` | découpe `tools/tele/planche/TV_Screen.png` vers `graphics/interface/tele/` |
