# Protocole en ligne — Pokémon Journey (version 1)

Transport : TCP, **une ligne JSON par message** (UTF-8, `\n`), 64 Ko max par ligne.

## Serveur (mode « Serveur »)
Client → serveur
- `{"t":"hello","v":1,"name":"…","id":"…","token":"…"}` : `id`/`token` absents à la première connexion.
- `{"t":"ping"}` → `{"t":"pong"}` (keepalive toutes les 25 s ; le serveur coupe après 90 s sans message).
- `{"t":"room_create","kind":"trade"|"duel"}` → `{"t":"room","code":"ABCDE"}`
- `{"t":"room_join","code":"ABCDE"}` → `room_ready` aux deux joueurs.
- `{"t":"relay","data":{…}}` : transmis tel quel à l'autre joueur du salon.
- `{"t":"room_leave"}`

Serveur → client : `welcome` (`id`, `token` seulement à la création du compte), `room`, `room_ready` (`peer`, `role`), `relay` (`data`), `peer_left`, `room_closed`, `error` (`code`, `text`).

Sécurité : jeton stocké haché (SHA-256), limite de débit (20 msg/s), 8 connexions max par IP, salons expirés après 15 min, le serveur ne lit jamais le contenu de `data`.

## Direct (sans serveur)
L'hôte écoute sur `direct_port`, l'invité s'y connecte ; même format de lignes. Chaque côté envoie `{"t":"hello","role":"host"|"guest","name":"…"}` puis les messages `data`.

## Messages de jeu (dans `data`)
- Échange : `{"k":"trade","a":"offer","mon":{…}}`, `"confirm"` (avec `digest` SHA-256 des deux offres), `"cancel"`.
- Défi : `{"k":"duel","a":"team","team":[…]}`, `"start"`, `"result","won":bool`, `"cancel"`.
Les Pokémon sont des objets JSON à champs connus (espèce, niveau, IV/EV, attaques…), **jamais** du Marshal ; ils sont validés à la réception.

## Lancer le serveur
`node tools/online-server/server.js --port 7777 --data ./data` (Node 18+, aucune dépendance). Mets l'adresse et le port dans `Data/configs/plugins/online.json` (`server_host`, `server_port`).

## Étape 2 — combat en temps réel (lockstep), salon de type `duel`
Les deux jeux simulent le même combat avec la même graine ; seules les décisions circulent.
- `{"k":"pvp","a":"team","team":[…]}` équipes (validées comme pour l'échange)
- `{"k":"pvp","a":"seed","seed":N}` envoyé par l'hôte
- `{"k":"pvp","a":"act","turn":N,"acts":[{"type":"move|switch|flee","mon":0,"slot":1,"target_bank":1,"target_pos":0}]}` (banques du point de vue de l'envoyeur)
- `{"k":"pvp","a":"sum","turn":N,"sum":"…"}` empreinte de l'état après le tour ; différente → combat interrompu (désynchronisation)
- `{"k":"pvp","a":"end","won":bool}`, `"forfeit"`, `"cancel"`. Déconnexion en plein combat = abandon.
Commandes d'évènement : `online_combat`, `online_combats_gagnes`.

## Étape 3 — profil, amis, classements (connexion serveur sans salon)
Après `hello`, requêtes (réponse unique) :
- `profile_set {profile}` → `profile_ok` (champs bornés par le serveur : titre, équipe ≤ 6 espèces, Pokédex, badges, échanges, défis, combats en ligne)
- `profile_get {code}` → `profile` (soi-même ou un ami seulement)
- `friends_list` → `friends {friends:[{id,name,online,profile}], requests:[{id,name}]}`
- `friend_add {code}` → `friend_ok {a:"sent"|"accepted"}` (demande croisée = acceptée) ; `friend_answer {code,accept}` ; `friend_remove {code}`
- `board {board}` (`dex_caught`, `pvp_won`, `duels_won`, `trades`, `badges`) → `board {rows:[{rank,id,name,value}], me, total}`
Le serveur envoie `friend_notice` à un joueur connecté qui reçoit une demande. Limites : 100 amis, 50 demandes en attente.
Les chiffres du profil viennent du jeu : le serveur ne peut pas les vérifier (classements « d'honneur »). Commande d'évènement : `online_social`.

## Étape 4 — évènements et boîte d'échange mondiale
**Évènements** : `data/events.json` sur le serveur (modèle : `events.exemple.json`, relu automatiquement, sans redémarrage). Chaque évènement : `id`, `title`, `desc`, `start`/`end` (ISO), `code` facultatif, `reward` = `{"type":"item","item":"great_ball","count":5}` ou `{"type":"pokemon","mon":{…}}`. Un seul retrait par compte ; 10 codes ratés par heure maximum.
- `events_list` → `events` ; `event_claim {id, code}` → `event_reward {reward}`

**Boîte d'échange** (dépôt asynchrone, 1 dépôt par joueur, expire après 30 jours) :
- `box_deposit {mon, want:{species|null, min_level}}`, `box_list {species?}`, `box_mine`, `box_withdraw`
- `box_take {id, mon}` : le serveur vérifie l'espèce/niveau demandés, échange atomiquement et renvoie le Pokémon du dépôt ; celui du déposant va dans sa boîte de réception
- `box_collect` → `box_inbox {items:[{uid, mon, from}]}` ; `box_ack {uids}` (le client accuse réception **après** avoir ajouté le Pokémon)
Le serveur reconstruit chaque Pokémon reçu (liste blanche de champs, bornes IV/EV/niveau) ; le client le revalide avant de l'ajouter. Commande d'évènement : `online_monde`.

## Étape 5 — mise en service
- TLS facultatif : `--tls-cert/--tls-key` (serveur), `server_tls: true` (client, certificat vérifié).
- Modération : `block {code}`, `unblock {code}`, `report {code, reason}` (réponse `friend_ok`) ; `banned.json`, `banned_words.txt`, `reports.json` côté serveur. Un joueur bloqué ne peut ni t'ajouter (succès silencieux), ni rejoindre tes salons.
- Sauvegardes automatiques (`backups/`). Voir `README.md`, `Dockerfile`, `pj-online.service`.
- Commande d'évènement : `online_menu` (menu central : échange, combat, amis, monde).

## Étape 6 — visite de base, fantômes, invitations
- `base_set {base:{theme, placed:[{kind:item|ach|contest,id,x,y,species?,form?,shiny?}], greeting}}` → `base_ok` (80 décorations au plus, cases uniques, 10×7)
- `base_visit {code}` → `base {user, base, visits, recent}` (soi-même ou un ami ; compteur de visites et 5 derniers visiteurs)
- `listen {on}` : ce client accepte les invitations
- `presence {map,x,y,dir,skin}` (≥ 120 ms entre deux) : le serveur envoie `ghost {ghost:{id,name,map,x,y,dir,skin}}` aux amis présents sur la même carte (et l'instantané des amis déjà là), `ghost_gone {id}` quand on change de carte / se déconnecte ; `presence_off`
- `invite {to, kind:trade|duel|pvp, code}` : le joueur crée un salon puis invite ; l'invité reçoit `invite {from, kind, code}` et rejoint le salon. Un invité sans `listen` ou non visible → erreur `offline` ; 1 invitation / 8 s.
- Option serveur `--ghosts everyone` : tout le monde se voit (et peut s'inviter) sur une même carte, sauf joueurs bloqués. Défaut : amis seulement.
