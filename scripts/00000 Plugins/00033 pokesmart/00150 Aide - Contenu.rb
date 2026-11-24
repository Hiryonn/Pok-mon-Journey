# PokeSmart : contenu de l'appli Aide (tutoriels en jeu)
#
# HELP_CATEGORIES : rubriques → tutoriels → pages. Chaque page est [français, anglais] ou [français, anglais, 'image'].
# Une page tient dans l'écran du téléphone (environ 130 caractères). Pour ajouter un tutoriel :
#   UI::PokeSmart::HELP_CATEGORIES.find { |c| c[:id] == :combat }[:topics] << { name: ['Titre', 'Title'], pages: [['Page 1', 'Page 1']] }
# Les noms de rubrique et de tutoriel doivent rester courts (environ 14 caractères).
module UI
  module PokeSmart
    # Affiche l'appli Aide
    HELP_APP = true
    # Dossier des images d'exemple (dans graphics/interface/) : une page [français, anglais, 'nom'] affiche aide/nom.png
    HELP_IMAGE_DIR = 'aide/'
    # Nom de l'appli (titre de l'écran)
    HELP_TITLE = ['Aide', 'Help']

    # @param name [Array<String>] [français, anglais]
    # @param pages [Array<Array<String>>] pages [français, anglais]
    # @return [Hash]
    def self.help_topic(name, *pages)
      return { name: name, pages: pages }
    end

    HELP_CATEGORIES = [
      {
        id: :phone, name: ['Téléphone', 'Phone'], topics: [
          help_topic(['Les applis', 'Apps'],
                     ["Flèches : choisir une appli.\nA : l'ouvrir.\nB : ranger le téléphone.\nL / R : changer de page.",
                      "Arrows: pick an app.\nA: open it.\nB: put the phone away.\nL / R: change page."],
                     ["La souris marche aussi : survole et clique une appli, ou clique le bouton rond du bas pour ranger le téléphone.",
                      'The mouse works too: hover and click an app, or click the round button to put the phone away.'],
                     ['Les applis du bas (Sauvegarde, Options…) sont visibles sur toutes les pages.',
                      'The apps at the bottom (Save, Options...) are shown on every page.']),
          help_topic(["Barre d'état", 'Status bar'],
                     ['En haut : réseau (selon la zone), Wi-Fi (connexion Internet de ton ordinateur), heure et batterie.',
                      'On top: signal (depends on the area), Wi-Fi (your computer\'s Internet), time and battery.'],
                     ['Réseau : 4 barres dehors, 2 dans un bâtiment, aucune dans une grotte ou un donjon.',
                      'Signal: 4 bars outside, 2 inside a building, none in a cave or dungeon.'],
                     ['La batterie suit le moment de la journée. Avec un Pikachu dans l\'équipe, c\'est la batterie Pikachu !',
                      'The battery follows the time of day. With a Pikachu in your party, it is the Pikachu battery!']),
          help_topic(['PC à distance', 'Remote PC'],
                     ["L'appli PC ouvre tes boîtes de stockage de n'importe où, mais seulement s'il y a du réseau.",
                      'The PC app opens your storage boxes from anywhere, but only with a signal.'],
                     ['Dans une grotte ou un donjon, le téléphone affiche « Pas de réseau ». Sors à l\'air libre pour y accéder.',
                      'In a cave or dungeon the phone shows "No signal". Go outside to use it.']),
          help_topic(['Pokénav', 'PokéNav'],
                     ['Le Pokénav liste les Pokémon sauvages de la zone : ceux de la terre d\'abord, puis ceux de l\'eau (marqueur bleu).',
                      'The PokéNav lists the wild Pokémon of the area: land ones first, then water ones (blue marker).'],
                     ['Le moment de la journée est indiqué. Haut / bas : faire défiler. A ou B : revenir.',
                      'The time of day is shown. Up / down: scroll. A or B: go back.']),
          help_topic(['Appareil photo', 'Camera'],
                     ['L\'appareil photo range le téléphone et affiche un viseur.\nA : prendre la photo.\nB : revenir.',
                      'The camera puts the phone away and shows a viewfinder.\nA: take the photo.\nB: back.'],
                     ['Les photos (sans le viseur) sont enregistrées dans le dossier « Photos » du jeu : photo_000.png, photo_001.png…',
                      'Photos (without the viewfinder) are saved in the game\'s "Photos" folder: photo_000.png, photo_001.png...']),
          help_topic(['Personnaliser', 'Customize'],
                     ['Personnaliser change la coque, les icônes et le fond d\'écran.\nHaut / bas : choisir.\nA : garder.\nB : annuler.',
                      'Customize changes the case, icons and wallpaper.\nUp / down: choose.\nA: keep.\nB: cancel.'],
                     ['Le choix s\'affiche en direct. Fond d\'écran automatique : l\'image du Pokémon de tête, sinon selon son type.',
                      'Your choice shows live. Automatic wallpaper: the lead Pokémon\'s picture, else by its type.'],
                     ['Icônes : choisis appli par appli une des variantes proposées.',
                      'Icons: pick one of the variants, app by app.']),
          help_topic(['Amis', 'Friends'],
                     ['L\'appli Amis liste les personnages rencontrés. Un point rouge signale un message non lu.',
                      'The Friends app lists the characters you met. A red dot means an unread message.'],
                     ['A ouvre un ami, haut / bas change de message. Selon le message, tu peux accepter une quête ou lancer un combat.',
                      'A opens a friend, up / down changes message. Depending on it, you can accept a quest or start a battle.'])
        ]
      },
      {
        id: :combat, name: ['Combat', 'Battle'], topics: [
          help_topic(["Infos d'attaque", 'Move info'],
                     ['Pendant le choix de l\'attaque, X affiche ses détails : type, catégorie, PP, puissance, précision, effets.',
                      'While choosing a move, X shows its details: type, category, PP, power, accuracy, effects.'],
                     ['Il indique aussi l\'efficacité de l\'attaque sur chaque cible. Pratique pour éviter les erreurs !',
                      'It also shows the move\'s effectiveness on each target. Handy to avoid mistakes!']),
          help_topic(['Infos terrain', 'Field info'],
                     ['Pendant le choix de l\'action, Y ouvre la liste des Pokémon sur le terrain : niveaux, statut, stats modifiées.',
                      'While choosing an action, Y lists the Pokémon on the field: levels, status, stat changes.'],
                     ['Tu y vois la dernière attaque utilisée et les effets en cours (météo, terrain, protections, pièges) avec leurs tours restants.',
                      'You also see the last move used and ongoing effects (weather, terrain, screens, traps) with turns left.']),
          help_topic(['Mécaniques', 'Gimmicks'],
                     ['Pendant le choix de l\'attaque, Y ouvre la roue des mécaniques : Méga, capacité Z, Dynamax / Gigamax, Téracristal.',
                      'While choosing a move, Y opens the gimmick wheel: Mega, Z-Move, Dynamax / Gigantamax, Terastal.'],
                     ['Flèches ou souris pour pointer, A pour choisir.',
                      'Arrows or mouse to point, A to choose.'],
                     ['Une mécanique par combat et par dresseur. Un Pokémon qui en a utilisé une n\'a plus accès aux autres.',
                      'One gimmick per battle and per trainer. A Pokémon that used one cannot use the others.'],
                     ['Les quatre peuvent servir dans le même combat, chacune avec un Pokémon différent.',
                      'All four can be used in one battle, each with a different Pokémon.']),
          help_topic(['Styles PLA', 'PLA styles'],
                     ['Style Puissant et Style Rapide (Légendes Arceus) : Y pendant le choix de l\'attaque, dans la roue des mécaniques.',
                      'Strong and Agile styles (Legends Arceus): Y while choosing a move, in the gimmick wheel.'],
                     ['Seules les capacités maîtrisées s\'en servent. Le style dure 2 tours, puis 3 tours d\'attente.',
                      'Only mastered moves can use it. A style lasts 2 turns, then 3 turns of waiting.'],
                     ['Puissant : plus de dégâts, mais le Pokémon agit en dernier. Rapide : moins de dégâts, mais il agit en premier.',
                      'Strong: more damage, but the Pokémon acts last. Agile: less damage, but it acts first.'],
                     ['Une capacité apprise par niveau est maîtrisée environ 10 niveaux plus tard. La Graine Maîtrise en fait maîtriser une autre.',
                      'A level-up move is mastered about 10 levels later. The Mastery Seed masters another one.']),
          help_topic(['Raids', 'Raids'],
                     ['Un raid oppose 1 à 3 de tes Pokémon à un boss géant. Il y a 4 styles : Antre de raid, Brèche Ultra, Dynamax, Téracristal.',
                      'A raid pits 1 to 3 of your Pokémon against a giant boss. 4 styles: Raid, Ultra, Dynamax, Tera.'],
                     ['Sous la moitié de ses PV, le boss se met derrière un bouclier. Casse-le avec des attaques efficaces ou celles du style.',
                      'Below half HP the boss gets a shield. Break it with effective moves or style moves.'],
                     ['Le combat est perdu quand le compteur de tours ou de K.O. tombe à 0. Encourager remplace la Fuite.',
                      'You lose when the turn or K.O. counter hits 0. Cheering replaces Run.'],
                     ['Une fois battu, le boss peut être capturé avec une Poké Ball du sac. Un antre donne aussi des objets.',
                      'Once beaten, the boss can be caught with a Poké Ball from the bag. A den also gives items.']),
          help_topic(['Statuts', 'Statuses'],
                     ['De nouveaux statuts existent, comme le Saignement. Une icône près du nom du Pokémon l\'indique.',
                      'New statuses exist, like Bleeding. An icon next to the Pokémon\'s name shows it.'],
                     ['Selon le statut : dégâts à la fin de chaque tour, stats baissées ou soins réduits. Certains types sont immunisés.',
                      'Depending on the status: damage each turn, lowered stats or reduced healing. Some types are immune.']),
          help_topic(['Pokémon Obscurs', 'Shadow Pokémon'],
                     ['Un Pokémon Obscur a le cœur fermé : une jauge de 5 barres doit se vider avant de pouvoir le purifier.',
                      'A Shadow Pokémon has a closed heart: a 5-bar gauge must empty before it can be purified.'],
                     ['La jauge baisse en combattant, en marchant, à la Pension, avec les Parfums et l\'Appel (à la place de Fuite).',
                      'The gauge drops by battling, walking, at the Day Care, with Scents and the Call (instead of Run).'],
                     ['Les Pokémon Obscurs des dresseurs se capturent avec le Snatcheur ou une Snatch Ball.',
                      'Trainers\' Shadow Pokémon can be caught with the Snag Machine or a Snag Ball.']),
          help_topic(['Talents', 'Abilities'],
                     ['Pokémon Journey ajoute des capacités et des talents. Leur description est dans le résumé du Pokémon.',
                      'Pokémon Journey adds moves and abilities. Their description is in the Pokémon summary.'],
                     ['Nouveautés : Pluie Acide (1/16 des PV par tour, sauf Poison) et Terrain Sale (attaques Poison x1,3).',
                      'New: Acid Rain (1/16 HP per turn, except Poison) and Filthy Terrain (Poison moves x1.3).'])
        ]
      },
      {
        id: :pokemon, name: ['Pokémon', 'Pokémon'], topics: [
          help_topic(['Poké Récré', 'Pokémon-Amie'],
                     ['Ouvre Poké Récré par l\'appli du téléphone, ou en parlant au Pokémon qui te suit.',
                      'Open Pokémon-Amie from the phone app, or by talking to your follower.'],
                     ['Trois jauges : affection (ne baisse pas), satiété et bonne humeur (baissent en marchant).',
                      'Three gauges: affection (never drops), fullness and mood (drop as you walk).'],
                     ['Caresse ton Pokémon ou donne-lui à manger pour les remplir.',
                      'Pet your Pokémon or feed it to fill them.'],
                     ['Évoli devient Nymphali en montant de niveau avec une capacité Fée et au moins 2 cœurs d\'affection.',
                      'Eevee becomes Sylveon when leveling up with a Fairy move and at least 2 affection hearts.']),
          help_topic(['Souvenirs', 'Mementos'],
                     ['Les rubans, insignes et titres sont dans le résumé du Pokémon (Interface Horizon), page des souvenirs.',
                      'Ribbons, marks and titles are in the Pokémon summary (Horizon UI), mementos page.'],
                     ['Les Pokémon sauvages peuvent avoir un insigne (heure, météo, humeur, rareté, pêche…). Le Charme Insigne les rend plus fréquents.',
                      'Wild Pokémon can have a mark (time, weather, mood, rarity, fishing...). The Mark Charm makes them more frequent.'],
                     ['Choisis un souvenir pour donner un titre au Pokémon : « Pikachu l\'Affamé ». Il s\'affiche en combat.',
                      'Pick a memento to give your Pokémon a title. It is shown in battle.']),
          help_topic(['Variantes', 'Variants'],
                     ['Un Pokémon peut être Cuivré, Argenté, Doré, Prismatique ou Radiant. C\'est rare !',
                      'A Pokémon can be Copper, Silver, Gold, Prismatic or Radiant. It is rare!'],
                     ['Cuivré, Argenté et Doré sont recolorés. Prismatique est en arc-en-ciel avec un halo de cristal.',
                      'Copper, Silver and Gold are recolored. Prismatic is rainbow with a crystal halo.'],
                     ['Radiant : sprites spéciaux. Un Pokémon sans sprite Radiant ne peut pas l\'être.',
                      'Radiant: special sprites. A Pokémon without a Radiant sprite cannot be one.']),
          help_topic(['Pokémon visibles', 'Overworld Pokémon'],
                     ['Des Pokémon sauvages se promènent sur la carte. Les repérer permet de choisir lesquels affronter.',
                      'Wild Pokémon roam the map. Spotting them lets you choose which ones to fight.'],
                     ['Toucher un Pokémon lance le combat contre lui. Certains fuient quand tu t\'approches, d\'autres te foncent dessus.',
                      'Touching a Pokémon starts the battle against it. Some flee as you approach, others charge you.'],
                     ['Ils changent à chaque fois que tu arrives sur une carte. Leur niveau, forme et couleur sont ceux du combat.',
                      'They change each time you enter a map. Their level, form and color are the ones you will fight.']),
          help_topic(['Barons et Dominants', 'Alphas and Totems'],
                     ['Une marque rouge près de la barre de vie : c\'est un Baron, plus haut niveau, IV parfaits et plus d\'expérience.',
                      'A red mark near the HP bar means an Alpha: higher level, perfect IVs and more experience.'],
                     ['Une marque dorée et une lueur dorée : c\'est un Monarque, plus rare et un peu plus fort encore qu\'un Baron.',
                      'A golden mark and a golden glow: a Noble, rarer and a little stronger than an Alpha.'],
                     ['Une marque blanche : c\'est un Dominant. Une aura l\'enveloppe au début du combat et augmente une statistique.',
                      'A white mark means a Totem. An aura surrounds it at the start of battle and raises a stat.'],
                     ['Capturé, il reste Baron ou Dominant : son icône s\'affiche en combat et son passif caché lui donne +1 à une stat.',
                      'Once caught, it stays an Alpha or Totem: its icon shows in battle and its hidden passive gives +1 to a stat.'],
                     ['Une apparition massive rassemble plusieurs Pokémon d\'une même espèce, avec plus de chances de chromatique.',
                      'A mass outbreak gathers many Pokémon of one species, with a better shiny chance.'],
                     ['Un chromatique joue un son à son apparition et reste sur la carte tant que tu ne l\'as pas affronté.',
                      'A shiny plays a sound when it appears and stays on the map until you battle it.']),
          help_topic(['Natures et PV', 'Natures & HP'],
                     ['Certaines natures modifient aussi les PV max (par exemple +10 % ou -10 %).',
                      'Some natures also change max HP (for example +10% or -10%).'],
                     ['Quand la nature change (Menthe), les PV perdus sont conservés. Munja garde toujours 1 PV max.',
                      'When the nature changes (Mint), lost HP are kept. Shedinja always keeps 1 max HP.']),
          help_topic(['Pokédex avancé', 'Advanced Dex'],
                     ['Dans la fiche d\'un Pokémon du Pokédex, DROITE ouvre la page Taille, puis la page Poids.',
                      'In a Pokédex entry, RIGHT opens the Height page, then the Weight page.'],
                     ['Tu y compares le Pokémon à des personnages. A : personnage suivant. Haut / bas : autre Pokémon. B : retour.',
                      'You compare the Pokémon with characters. A: next character. Up / down: other Pokémon. B: back.']),
          help_topic(['Berrydex', 'Berrydex'],
                     ['Le Berrydex est l\'encyclopédie des baies : taille, fermeté, saveurs, pousse et récolte.',
                      'The Berrydex is the berry encyclopedia: size, firmness, flavors, growth and harvest.'],
                     ['Une baie est « trouvée » dès qu\'elle entre dans ton sac. Les autres restent en « ????? » (selon les réglages).',
                      'A berry is "found" once it enters your bag. Others stay as "?????" (depending on settings).'])
        ]
      },
      {
        id: :hero, name: ['Héros et tenues', 'Hero & outfits'], topics: [
          help_topic(['Ton personnage', 'Your character'],
                     ['Le générateur de personnages te laisse créer ton héros : base, cheveux, haut, bas, chapeau et sac.',
                      'The character generator lets you create your hero: base, hair, top, bottom, hat and bag.'],
                     ['Ton personnage est assemblé en jeu et suit toutes les cartes, de la marche à la nage.',
                      'Your character is assembled in game and follows you everywhere, from walking to swimming.']),
          help_topic(['Tenues', 'Outfits'],
                     ['Une tenue est un objet du sac. Dans l\'onglet « Tenues » du sac, A la fait porter.',
                      'An outfit is a bag item. In the bag\'s "Outfits" tab, A wears it.'],
                     ['Tu peux aussi les essayer dans une salle d\'essayage. « Ma tenue » rend ton apparence d\'origine.',
                      'You can also try them in a fitting room. "My outfit" gives back your original look.']),
          help_topic(['Icône PSS', 'PSS icon'],
                     ['L\'icône PSS est ta photo de profil pour le mode en ligne. Les autres joueurs la voient.',
                      'The PSS icon is your profile picture for online mode. Other players see it.'],
                     ['Choisis peau, yeux, sourcils, haut, coiffure, frange, chapeau et accessoire. Coiffure et chapeau sont obligatoires.',
                      'Pick skin, eyes, eyebrows, top, hairstyle, fringe, hat and accessory. Hairstyle and hat are required.']),
          help_topic(['Montures', 'Mounts'],
                     ['Appelle un Pokémon monture et déplace-toi sur son dos : nager, escalader, voler, flairer les objets cachés…',
                      'Call a mount Pokémon and ride it: swim, climb, fly, sniff out hidden items...'],
                     ['Appel : touche raccourci (appui = monter / descendre, appui long = roue des montures) ou appli Monture.',
                      'Call: shortcut key (press = mount / dismount, long press = mount wheel) or the Mount app.'],
                     ['Les CS marchent toujours. Au contact de l\'eau, d\'un rocher ou d\'un arbre, le jeu propose la monture qui convient.',
                      'HMs still work. Near water, a rock or a tree, the game offers the right mount.'])
        ]
      },
      {
        id: :berries, name: ['Baies, cuisine', 'Berries, food'], topics: [
          help_topic(['Pots à baies', 'Berry pots'],
                     ['L\'objet « Pots à Baies » (sac) s\'utilise partout : plante une baie, arrose-la, récolte-la quand elle est mûre.',
                      'The "Berry Pots" bag item works anywhere: plant a berry, water it, harvest it when ripe.'],
                     ['Les pots poussent avec le temps du jeu, comme les baies de PSDK. Selon les réglages, il faut un arrosoir ; l\'engrais aide.',
                      'Pots grow with in-game time like normal berries. Depending on settings you need a can; mulch helps.']),
          help_topic(['Poffins', 'Poffins'],
                     ['Cuisine des poffins : choisis 1 à 4 baies du sac, puis tourne avec les flèches pour les cuire.',
                      'Cook poffins: pick 1 to 4 berries from the bag, then turn with the arrows to cook them.'],
                     ['Tourne ni trop lentement (le poffin brûle) ni trop vite (la pâte déborde).',
                      'Do not turn too slowly (it burns) nor too fast (it overflows).'],
                     ['Donne-les à tes Pokémon : épicé = Sang-froid, sec = Beauté, sucré = Charme, amer = Intelligence, acide = Robustesse.',
                      'Feed them to your Pokémon: spicy = Cool, dry = Beauty, sweet = Cute, bitter = Smart, sour = Tough.']),
          help_topic(['Pokéblocs', 'Pokéblocks'],
                     ['Le mixeur : choisis une baie, puis appuie sur A quand la flèche passe sur ton repère (Parfait / Bien / Raté).',
                      'The mixer: pick a berry, then press A when the arrow hits your mark (Perfect / Good / Miss).'],
                     ['Le Pokébloc dépend des saveurs des baies. Deux baies identiques donnent un Pokébloc Noir.',
                      'The Pokéblock depends on the berries\' flavors. Two identical berries make a Black Pokéblock.'],
                     ['La Boîte Pokébloc permet de les donner (le goût de la nature change l\'effet de ±10 %) ou de les jeter.',
                      'The Pokéblock Case lets you feed them (nature taste changes the effect by ±10%) or throw them away.'])
        ]
      },
      {
        id: :contests, name: ['Concours', 'Contests'], topics: [
          help_topic(['Super Concours', 'Super Contests'],
                     ['Un concours se joue en trois épreuves : Habillage, Danse et Jeu d\'acteur, devant un public.',
                      'A contest has three rounds: Dress-up, Dance and Acting, in front of an audience.'],
                     ['Tes points : Condition du Pokémon (nourris-le avec des poffins ou des Pokéblocs) + chaque épreuve.',
                      'Your points: the Pokémon\'s Condition (feed it poffins or Pokéblocks) + each round.'],
                     ['Gagne un ruban pour chaque type et chaque rang. Un Passe Concours peut être exigé.',
                      'Win a ribbon for each type and rank. A Contest Pass may be required.']),
          help_topic(['Pokéathlon', 'Pokéathlon'],
                     ['Choisis une coupe (Vitesse, Force, Technique, Endurance, Saut) puis 3 Pokémon.',
                      'Pick a cup (Speed, Power, Skill, Stamina, Jump) then 3 Pokémon.'],
                     ['Chaque coupe a 3 épreuves. Elles rapportent des points selon le classement ; ils se dépensent à la boutique.',
                      'Each cup has 3 events. They give points by ranking; spend them at the shop.'],
                     ['Les performances (1 à 5 étoiles) dépendent de l\'espèce, de la nature et du jour.',
                      'Performance (1 to 5 stars) depends on species, nature and the day.']),
          help_topic(['Tournois', 'Tournaments'],
                     ['Avant chaque match, choisis les Pokémon qui combattent, dans l\'ordre. Droite : voir l\'équipe adverse.',
                      'Before each match, pick the Pokémon that fight, in order. Right: see the opposing team.'],
                     ['Élimination directe : les autres matchs se jouent tout seuls. Les récompenses dépendent de ta place.',
                      'Single elimination: other matches play out on their own. Rewards depend on your place.'])
        ]
      },
      {
        id: :minigames, name: ['Mini-jeux', 'Mini-games'], topics: [
          help_topic(['Triple Triad', 'Triple Triad'],
                     ['Chaque carte est un Pokémon avec 4 valeurs (haut, droite, bas, gauche) de 1 à 10 (A).',
                      'Each card is a Pokémon with 4 values (top, right, bottom, left) from 1 to 10 (A).'],
                     ['Pose une carte à côté d\'une carte adverse : si la valeur qui la touche est plus grande, tu la captures.',
                      'Place a card next to an opposing card: if the value touching it is higher, you capture it.'],
                     ['À la fin, celui qui a le plus de cartes gagne. La règle Tetra joue sur un plateau 4x4 avec cases bloquées.',
                      'At the end, the player with the most cards wins. Tetra uses a 4x4 board with blocked squares.']),
          help_topic(['Casino JP', 'Casino JP'],
                     ['Mise 1, 2 ou 3 jetons. A lance les rouleaux, puis A les arrête un par un, de gauche à droite.',
                      'Bet 1, 2 or 3 coins. A spins the reels, then A stops them one by one, left to right.'],
                     ['Gain = gain du symbole × mise. Trois « Replay » : la partie suivante est gratuite.',
                      'Win = symbol payout × bet. Three "Replay": the next game is free.']),
          help_topic(['Dodrio', 'Dodrio'],
                     ['Des baies tombent sur 3 colonnes. Gauche, Haut (ou A) et Droite font picorer la tête correspondante.',
                      'Berries fall on 3 columns. Left, Up (or A) and Right peck with the matching head.'],
                     ['Une baie attrapée rapporte 1 à 3 points selon sa taille. Trop de baies ratées et la partie s\'arrête.',
                      'A caught berry gives 1 to 3 points by size. Too many misses and the game ends.']),
          help_topic(['Lance-Ball', 'Ball toss'],
                     ['Des Pokémon se cachent dans les buissons. Vise avec les flèches (ou la souris), lance avec A.',
                      'Pokémon hide in the bushes. Aim with the arrows (or mouse), throw with A.'],
                     ['Trois captures de suite donnent une balle dorée. Capture tout avant la fin du temps : le temps restant rapporte des points.',
                      'Three catches in a row give a golden ball. Catch everything before time runs out: leftover time gives points.']),
          help_topic(['Sac de frappe', 'Punching bag'],
                     ['Choisis un Pokémon : une flèche file sur la jauge, A la fige. Plus elle est au centre, plus le coup vaut d\'étoiles.',
                      'Pick a Pokémon: an arrow runs on the gauge, A freezes it. The closer to the center, the more stars.'],
                     ['Si le score minimum est atteint, le Pokémon gagne des EV et / ou des IV.',
                      'If the minimum score is reached, the Pokémon gains EVs and / or IVs.']),
          help_topic(['Quel Pokémon ?', 'Who\'s that?'],
                     ['Un Pokémon à deviner chaque jour, d\'après sa silhouette. Écris son nom.',
                      'A Pokémon to guess every day, from its silhouette. Type its name.'],
                     ['Tu as plusieurs essais, avec un indice après chaque erreur. Les jours trouvés d\'affilée donnent des bonus.',
                      'You get several tries with a hint after each mistake. Days found in a row give bonuses.'])
        ]
      },
      {
        id: :world, name: ['Monde', 'World'], topics: [
          help_topic(['Carte de région', 'Region map'],
                     ['La carte montre les zones de la région et leur nom. Selon les réglages : zoom, recherche, vol rapide.',
                      'The map shows the region\'s areas and names. Depending on settings: zoom, search, fast fly.'],
                     ['Elle peut aussi indiquer les quêtes et certains dresseurs. Les lieux cachés apparaissent quand tu les découvres.',
                      'It can also show quests and some trainers. Hidden places appear once you discover them.']),
          help_topic(['Journal, succès', 'Quests, goals'],
                     ['Le Journal suit tes quêtes. Les amis du téléphone peuvent t\'en proposer.',
                      'The Quest log tracks your quests. Friends in the phone can offer you some.'],
                     ['Les Succès sont des objectifs à débloquer. Un bandeau « Succès obtenu ! » s\'affiche quand tu en gagnes un.',
                      'Achievements are goals to unlock. An "Achievement unlocked!" banner shows when you earn one.']),
          help_topic(['Magasins', 'Shops'],
                     ['Comptoir : change de catégorie avec gauche / droite, choisis la quantité, confirme. Tu peux aussi vendre.',
                      'Counter: change category with left / right, choose a quantity, confirm. You can also sell.'],
                     ['Étalage : les objets sont sur 3 rayons. Remplis un panier, puis paie à la caisse.',
                      'Shelf: items sit on 3 shelves. Fill a basket, then pay at the register.'],
                     ['Une remise ou un bonus (10 Poké Balls achetées = 1 Honor Ball offerte) peut s\'appliquer.',
                      'A discount or bonus (10 Poké Balls bought = 1 free Premier Ball) may apply.']),
          help_topic(['Télévision', 'Television'],
                     ['La télé diffuse des programmes répartis sur 8 chaînes : actualités, conseils et informations sur le jeu.',
                      'The TV broadcasts programs over 8 channels: news, tips and game information.'],
                     ['Les programmes peuvent changer au fil de l\'aventure. Repasse regarder !',
                      'Programs can change as the adventure goes on. Come back and watch!'])
        ]
      }
    ]

    # Images d'exemple : { titre français du tutoriel => { numéro de page => image } } (graphics/interface/aide/, voir
    # tools/aide/generer_images.py). Une page peut aussi avoir l'image en 3e élément : ['français', 'anglais', 'image'].
    HELP_IMAGES = {
      'Les applis' => { 0 => 'telephone_applis' },
      "Barre d'état" => { 1 => 'telephone_reseau' },
      'PC à distance' => { 1 => 'telephone_reseau' },
      'Personnaliser' => { 0 => 'telephone_perso' },
      'Mécaniques' => { 0 => 'combat_roue' },
      'Poffins' => { 0 => 'poffin_cuisine' },
      'Casino JP' => { 0 => 'casino_jp' }
    }
    HELP_CATEGORIES.each do |category|
      category[:topics].each do |topic|
        (HELP_IMAGES[topic[:name][0]] || {}).each do |index, image|
          topic[:pages][index] = topic[:pages][index] + [image] if topic[:pages][index] && topic[:pages][index].size < 3
        end
      end
    end
  end
end
