# Serveur en ligne — Pokémon Journey

Un seul fichier (`server.js`), aucune dépendance, Node 18 ou plus.

## Lancer
```
node server.js --port 7777 --data ./data
```
Ou avec Docker (`Dockerfile`) ou systemd (`pj-online.service`). Ouvre le port TCP choisi sur ta box / ton pare-feu, puis dans le jeu, `Data/configs/plugins/online.json` :
`"server_host": "ton.adresse.ou.ip"`, `"server_port": 7777`.

## Fantômes sur la carte
Par défaut seuls les amis se voient et peuvent s'inviter. `node server.js --ghosts everyone` : tous les joueurs d'une même carte se voient (les joueurs bloqués restent masqués). Côté jeu : `"ghosts": true` dans `online.json` (ou la page Studio « Jeu en ligne »).

## Chiffrement (TLS) — recommandé
Sans TLS, les jetons de compte circulent en clair. Avec un certificat (ex. Let's Encrypt pour ton nom de domaine) :
```
node server.js --tls-cert fullchain.pem --tls-key privkey.pem
```
puis `"server_tls": true` dans `online.json` (le nom dans `server_host` doit être celui du certificat).

## Fichiers du dossier de données
| Fichier | Rôle |
|---|---|
| `accounts.json` | comptes, amis, profils, boîte de réception (ne pas modifier serveur allumé) |
| `box.json` | dépôts de la boîte d'échange |
| `events.json` | tes évènements / distributions (modèle : `events.exemple.json`), relu automatiquement |
| `banned.json` | liste de codes amis suspendus, ex. `["ABCD2345"]`, relue automatiquement |
| `banned_words.txt` | mots interdits dans les pseudos, titres et surnoms (un par ligne) |
| `reports.json` | signalements envoyés par les joueurs |
| `backups/` | copie automatique toutes les 6 h (28 dernières gardées) |

## Limites et sécurité
- Le serveur ne fait pas confiance au client : tailles, débit, nombre de connexions par IP, Pokémon reconstruits champ par champ.
- Les classements sont déclaratifs (le serveur ne voit pas les combats) : à présenter comme des classements « d'honneur ».
- Pas de messagerie texte libre (volontairement, pour limiter la modération).
Le protocole est décrit dans `PROTOCOLE.md`.
