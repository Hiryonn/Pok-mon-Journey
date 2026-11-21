# Souvenirs : données des rubans et des insignes
#
# INFO   catégorie et rangs précédents de chaque souvenir (les rangs précédents sont « regroupés » dans le résumé :
#        avec les rangs regroupés, seul le plus haut rang obtenu est montré)
# TEXTS  nom, description et titre [français, anglais] des souvenirs qui n'ont pas de texte dans PSDK
#        (les nouveaux sont ajoutés à PFM::RIBBONS_DATA dans cet ordre, à la suite de ceux de PSDK).
#        Un titre peut placer le nom : « {name} de {owner} » ({owner} : dresseur d'origine, {player} : joueur)
# Catégories des rubans : contest, league, frontier, memorial, gift ; des insignes : time, weather, encounter,
# rarity, personality, size, party, boss
module Mementos
  CONTEST_RANKS = %i[cool_normal_hoenn cool_super_hoenn cool_hyper_hoenn cool_master_hoenn beauty_normal_hoenn
                     beauty_super_hoenn beauty_hyper_hoenn beauty_master_hoenn cute_normal_hoenn cute_super_hoenn
                     cute_hyper_hoenn cute_master_hoenn smart_normal_hoenn smart_super_hoenn smart_hyper_hoenn
                     smart_master_hoenn tough_normal_hoenn tough_super_hoenn tough_hyper_hoenn tough_master_hoenn
                     cool_normal_sinnoh cool_great_sinnoh cool_ultra_sinnoh cool_master_sinnoh beauty_normal_sinnoh
                     beauty_great_sinnoh beauty_ultra_sinnoh beauty_master_sinnoh cute_normal_sinnoh cute_great_sinnoh
                     cute_ultra_sinnoh cute_master_sinnoh smart_normal_sinnoh smart_great_sinnoh smart_ultra_sinnoh
                     smart_master_sinnoh tough_normal_sinnoh tough_great_sinnoh tough_ultra_sinnoh tough_master_sinnoh].freeze

  INFO = {
    cool_normal_hoenn: [:contest],
    cool_super_hoenn: [:contest, %i[cool_normal_hoenn]],
    cool_hyper_hoenn: [:contest, %i[cool_normal_hoenn cool_super_hoenn]],
    cool_master_hoenn: [:contest, %i[cool_normal_hoenn cool_super_hoenn cool_hyper_hoenn]],
    beauty_normal_hoenn: [:contest],
    beauty_super_hoenn: [:contest, %i[beauty_normal_hoenn]],
    beauty_hyper_hoenn: [:contest, %i[beauty_normal_hoenn beauty_super_hoenn]],
    beauty_master_hoenn: [:contest, %i[beauty_normal_hoenn beauty_super_hoenn beauty_hyper_hoenn]],
    cute_normal_hoenn: [:contest],
    cute_super_hoenn: [:contest, %i[cute_normal_hoenn]],
    cute_hyper_hoenn: [:contest, %i[cute_normal_hoenn cute_super_hoenn]],
    cute_master_hoenn: [:contest, %i[cute_normal_hoenn cute_super_hoenn cute_hyper_hoenn]],
    smart_normal_hoenn: [:contest],
    smart_super_hoenn: [:contest, %i[smart_normal_hoenn]],
    smart_hyper_hoenn: [:contest, %i[smart_normal_hoenn smart_super_hoenn]],
    smart_master_hoenn: [:contest, %i[smart_normal_hoenn smart_super_hoenn smart_hyper_hoenn]],
    tough_normal_hoenn: [:contest],
    tough_super_hoenn: [:contest, %i[tough_normal_hoenn]],
    tough_hyper_hoenn: [:contest, %i[tough_normal_hoenn tough_super_hoenn]],
    tough_master_hoenn: [:contest, %i[tough_normal_hoenn tough_super_hoenn tough_hyper_hoenn]],
    cool_normal_sinnoh: [:contest],
    cool_great_sinnoh: [:contest, %i[cool_normal_sinnoh]],
    cool_ultra_sinnoh: [:contest, %i[cool_normal_sinnoh cool_great_sinnoh]],
    cool_master_sinnoh: [:contest, %i[cool_normal_sinnoh cool_great_sinnoh cool_ultra_sinnoh]],
    beauty_normal_sinnoh: [:contest],
    beauty_great_sinnoh: [:contest, %i[beauty_normal_sinnoh]],
    beauty_ultra_sinnoh: [:contest, %i[beauty_normal_sinnoh beauty_great_sinnoh]],
    beauty_master_sinnoh: [:contest, %i[beauty_normal_sinnoh beauty_great_sinnoh beauty_ultra_sinnoh]],
    cute_normal_sinnoh: [:contest],
    cute_great_sinnoh: [:contest, %i[cute_normal_sinnoh]],
    cute_ultra_sinnoh: [:contest, %i[cute_normal_sinnoh cute_great_sinnoh]],
    cute_master_sinnoh: [:contest, %i[cute_normal_sinnoh cute_great_sinnoh cute_ultra_sinnoh]],
    smart_normal_sinnoh: [:contest],
    smart_great_sinnoh: [:contest, %i[smart_normal_sinnoh]],
    smart_ultra_sinnoh: [:contest, %i[smart_normal_sinnoh smart_great_sinnoh]],
    smart_master_sinnoh: [:contest, %i[smart_normal_sinnoh smart_great_sinnoh smart_ultra_sinnoh]],
    tough_normal_sinnoh: [:contest],
    tough_great_sinnoh: [:contest, %i[tough_normal_sinnoh]],
    tough_ultra_sinnoh: [:contest, %i[tough_normal_sinnoh tough_great_sinnoh]],
    tough_master_sinnoh: [:contest, %i[tough_normal_sinnoh tough_great_sinnoh tough_ultra_sinnoh]],
    contest_memory: [:contest, CONTEST_RANKS],
    contest_memory_gold: [:contest, CONTEST_RANKS],
    coolness_master: [:contest],
    beauty_master: [:contest],
    cuteness_master: [:contest],
    cleverness_master: [:contest],
    toughness_master: [:contest],
    contest_star: [:contest, %i[coolness_master beauty_master cuteness_master cleverness_master toughness_master]],
    twinkling_star: [:contest],
    champion: [:league],
    hoenn_champion: [:league],
    sinnoh_champion: [:league],
    kalos_champion: [:league],
    alola_champion: [:league],
    galar_champion: [:league],
    paldea_champion: [:league],
    winning: [:frontier],
    victory: [:frontier, %i[winning]],
    ability: [:frontier],
    great_ability: [:frontier, %i[ability]],
    double_ability: [:frontier],
    multi_ability: [:frontier, %i[double_ability]],
    pair_ability: [:frontier],
    world_ability: [:frontier],
    battle_memory: [:frontier, %i[winning victory ability great_ability double_ability multi_ability pair_ability world_ability]],
    battle_memory_gold: [:frontier, %i[winning victory ability great_ability double_ability multi_ability pair_ability world_ability]],
    skillful_battler: [:frontier],
    expert_battler: [:frontier, %i[skillful_battler]],
    battle_tree_great: [:frontier],
    battle_tree_master: [:frontier, %i[battle_tree_great]],
    tower_master: [:frontier],
    artist: [:memorial],
    effort: [:memorial],
    alert: [:memorial],
    shock: [:memorial],
    downcast: [:memorial],
    careless: [:memorial],
    relax: [:memorial],
    snooze: [:memorial],
    smile: [:memorial],
    gorgeous: [:memorial],
    royal: [:memorial],
    gorgeous_royal: [:memorial, %i[gorgeous royal]],
    footprint: [:memorial],
    record: [:memorial],
    legend: [:memorial],
    best_friends: [:memorial],
    training: [:memorial],
    battle_royal_master: [:frontier],
    master_rank: [:memorial],
    hisui: [:memorial],
    once_in_a_lifetime: [:memorial],
    event: [:gift],
    birthday: [:gift],
    special: [:gift],
    souvenir: [:gift],
    national: [:gift],
    country: [:gift],
    battle_champion: [:gift],
    regional_champion: [:gift, %i[battle_champion]],
    earth: [:gift],
    world: [:gift],
    national_champion: [:gift],
    world_champion: [:gift, %i[national_champion]],
    classic: [:gift],
    premier: [:gift],
    red: [:gift],
    green: [:gift],
    blue: [:gift],
    marine: [:gift],
    land: [:gift],
    sky: [:gift],
    wishing: [:gift],
    lunchtime_mark: [:time],
    sleepy_time_mark: [:time],
    dusk_mark: [:time],
    dawn_mark: [:time],
    cloudy_mark: [:weather],
    rainy_mark: [:weather],
    stormy_mark: [:weather],
    snowy_mark: [:weather],
    blizzard_mark: [:weather],
    dry_mark: [:weather],
    sandstorm_mark: [:weather],
    misty_mark: [:weather],
    destiny_mark: [:encounter],
    fishing_mark: [:encounter],
    curry_mark: [:encounter],
    rare_mark: [:rarity],
    uncommon_mark: [:rarity],
    rowdy_mark: [:personality],
    absent_minded_mark: [:personality],
    jittery_mark: [:personality],
    excited_mark: [:personality],
    charismatic_mark: [:personality],
    calmness_mark: [:personality],
    intense_mark: [:personality],
    zoned_out_mark: [:personality],
    joyful_mark: [:personality],
    angry_mark: [:personality],
    smiley_mark: [:personality],
    teary_mark: [:personality],
    upbeat_mark: [:personality],
    peeved_mark: [:personality],
    intellectual_mark: [:personality],
    ferocious_mark: [:personality],
    crafty_mark: [:personality],
    scowling_mark: [:personality],
    kindly_mark: [:personality],
    flustered_mark: [:personality],
    pumped_up_mark: [:personality],
    zero_energy_mark: [:personality],
    prideful_mark: [:personality],
    unsure_mark: [:personality],
    humble_mark: [:personality],
    thorny_mark: [:personality],
    vigor_mark: [:personality],
    slump_mark: [:personality],
    jumbo_mark: [:size],
    mini_mark: [:size],
    itemfinder_mark: [:party],
    partner_mark: [:party],
    gourmand_mark: [:party],
    alpha_mark: [:boss],
    mightiest_mark: [:boss],
    titan_mark: [:boss],
    partner: [:memorial]
  }.freeze

  TEXTS = {
    master_rank: { name: ['Ruban Rang Master', 'Master Rank Ribbon'],
                   description: ['Ruban reçu pour avoir vaincu un Dresseur au rang Master Ball des combats classés.', 'A Ribbon awarded for winning against a Trainer in the Master Ball Tier of Ranked Battles.'] },
    hisui: { name: ['Ruban Hisui', 'Hisui Ribbon'],
             description: ['Ruban reçu par un Pokémon photographié à Hisui, dans un passé lointain.', 'A ribbon awarded to a Pokémon that posed for a photograph in Hisui in the distant past.'] },
    once_in_a_lifetime: { name: ['Ruban Unique', 'Once-in-a-Lifetime Ribbon'],
                          description: ['Ruban très rare, trouvé sur les Pokémon reçus lors d’un échange miracle.', 'A rare ribbon found extremely infrequently on Pokémon obtained in a Surprise Trade.'] },
    red: { name: ['Ruban Rouge', 'Red Ribbon'],
           description: ['Ruban commémoratif obtenu dans une Zone Mystère.', 'A commemorative Ribbon obtained in a Mystery Zone.'] },
    green: { name: ['Ruban Vert', 'Green Ribbon'],
             description: ['Ruban commémoratif obtenu dans une Zone Mystère.', 'A commemorative Ribbon obtained in a Mystery Zone.'] },
    blue: { name: ['Ruban Bleu', 'Blue Ribbon'],
            description: ['Ruban commémoratif obtenu dans une Zone Mystère.', 'A commemorative Ribbon obtained in a Mystery Zone.'] },
    marine: { name: ['Ruban Marin', 'Marine Ribbon'],
              description: ['Ruban commémoratif obtenu dans une Zone Mystère.', 'A commemorative Ribbon obtained in a Mystery Zone.'] },
    land: { name: ['Ruban Terrestre', 'Land Ribbon'],
            description: ['Ruban commémoratif obtenu dans une Zone Mystère.', 'A commemorative Ribbon obtained in a Mystery Zone.'] },
    sky: { name: ['Ruban Céleste', 'Sky Ribbon'],
           description: ['Ruban commémoratif obtenu dans une Zone Mystère.', 'A commemorative Ribbon obtained in a Mystery Zone.'] },
    lunchtime_mark: { name: ['Insigne Appétit', 'Lunchtime Mark'],
                      description: ['Un insigne pour un Pokémon qui a un petit creux.', 'A mark for a peckish Pokémon.'], title: ['l\'Affamé', 'the Peckish'] },
    sleepy_time_mark: { name: ['Insigne Minuit', 'Sleepy-Time Mark'],
                        description: ['Un insigne pour un Pokémon qui tombe de sommeil.', 'A mark for a sleepy Pokémon.'], title: ['l\'Endormi', 'the Sleepy'] },
    dusk_mark: { name: ['Insigne Crépuscule', 'Dusk Mark'],
                 description: ['Un insigne pour un Pokémon somnolent.', 'A mark for a dozy Pokémon.'], title: ['le Fourbu', 'the Dozy'] },
    dawn_mark: { name: ['Insigne Aube', 'Dawn Mark'],
                 description: ['Un insigne pour un Pokémon lève-tôt.', 'A mark for an early-riser Pokémon.'], title: ['le Matinal', 'the Early Riser'] },
    cloudy_mark: { name: ['Insigne Nuages', 'Cloudy Mark'],
                   description: ['Un insigne pour un Pokémon qui contemple les nuages.', 'A mark for a cloud-watching Pokémon.'], title: ['le Rêveur', 'the Cloud Watcher'] },
    rainy_mark: { name: ['Insigne Pluie', 'Rainy Mark'],
                  description: ['Un insigne pour un Pokémon trempé jusqu’aux os.', 'A mark for a sodden Pokémon.'], title: ['le Trempé', 'the Sodden'] },
    stormy_mark: { name: ['Insigne Tonnerre', 'Stormy Mark'],
                   description: ['Un insigne pour un Pokémon frappé par la foudre.', 'A mark for a thunderstruck Pokémon.'], title: ['le Survolté', 'the Thunderstruck'] },
    snowy_mark: { name: ['Insigne Neige', 'Snowy Mark'],
                  description: ['Un insigne pour un Pokémon qui gambade dans la neige.', 'A mark for a snow-frolicking Pokémon.'], title: ['l\'Enneigé', 'the Snow Frolicker'] },
    blizzard_mark: { name: ['Insigne Blizzard', 'Blizzard Mark'],
                     description: ['Un insigne pour un Pokémon qui grelotte.', 'A mark for a shivering Pokémon.'], title: ['le Grelottant', 'the Shivering'] },
    dry_mark: { name: ['Insigne Sécheresse', 'Dry Mark'],
                description: ['Un insigne pour un Pokémon assoiffé.', 'A mark for a parched Pokémon.'], title: ['l\'Assoiffé', 'the Parched'] },
    sandstorm_mark: { name: ['Insigne Tempête de Sable', 'Sandstorm Mark'],
                      description: ['Un insigne pour un Pokémon balayé par le sable.', 'A mark for a sandswept Pokémon.'], title: ['l\'Ensablé', 'the Sandswept'] },
    misty_mark: { name: ['Insigne Brume', 'Misty Mark'],
                  description: ['Un insigne pour un Pokémon qui erre dans la brume.', 'A mark for a mist-drifter Pokémon.'], title: ['l\'Égaré', 'the Mist Drifter'] },
    destiny_mark: { name: ['Insigne Destin', 'Destiny Mark'],
                    description: ['Un insigne pour un Pokémon élu.', 'A mark of a chosen Pokémon.'], title: ['le Destiné', 'the Chosen One'] },
    fishing_mark: { name: ['Insigne Pêche', 'Fishing Mark'],
                    description: ['Un insigne pour un Pokémon pêché, la prise du jour.', 'A mark for a catch-of-the-day Pokémon.'], title: ['le Frétillant', 'the Catch of the Day'] },
    curry_mark: { name: ['Insigne Curry', 'Curry Mark'],
                  description: ['Un insigne pour un Pokémon fin connaisseur de bonne cuisine.', 'A mark for a curry-connoisseur Pokémon.'], title: ['le Gastronome', 'the Curry Connoisseur'] },
    rare_mark: { name: ['Insigne Rareté', 'Rare Mark'],
                 description: ['Un insigne pour un Pokémon solitaire.', 'A mark for a reclusive Pokémon.'], title: ['le Rarissime', 'the Recluse'] },
    uncommon_mark: { name: ['Insigne Sociabilité', 'Uncommon Mark'],
                     description: ['Un insigne pour un Pokémon sociable.', 'A mark for a sociable Pokémon.'], title: ['le Sociable', 'the Sociable'] },
    rowdy_mark: { name: ['Insigne Espièglerie', 'Rowdy Mark'],
                  description: ['Un insigne pour un Pokémon turbulent.', 'A mark for a rowdy Pokémon.'], title: ['l\'Espiègle', 'the Rowdy'] },
    absent_minded_mark: { name: ['Insigne Inattention', 'Absent-Minded Mark'],
                          description: ['Un insigne pour un Pokémon dans la lune.', 'A mark for a spacey Pokémon.'], title: ['le Distrait', 'the Spacey'] },
    jittery_mark: { name: ['Insigne Nervosité', 'Jittery Mark'],
                    description: ['Un insigne pour un Pokémon anxieux.', 'A mark for an anxious Pokémon.'], title: ['le Tendu', 'the Anxious'] },
    excited_mark: { name: ['Insigne Enthousiasme', 'Excited Mark'],
                    description: ['Un insigne pour un Pokémon surexcité.', 'A mark for a giddy Pokémon.'], title: ['l\'Enthousiaste', 'the Giddy'] },
    charismatic_mark: { name: ['Insigne Charisme', 'Charismatic Mark'],
                        description: ['Un insigne pour un Pokémon rayonnant.', 'A mark for a radiant Pokémon.'], title: ['le Charismatique', 'the Radiant'] },
    calmness_mark: { name: ['Insigne Sang-Froid', 'Calmness Mark'],
                     description: ['Un insigne pour un Pokémon serein.', 'A mark for a serene Pokémon.'], title: ['l\'Imperturbable', 'the Serene'] },
    intense_mark: { name: ['Insigne Sang Chaud', 'Intense Mark'],
                    description: ['Un insigne pour un Pokémon fougueux.', 'A mark for a feisty Pokémon.'], title: ['l\'Agressif', 'the Feisty'] },
    zoned_out_mark: { name: ['Insigne Insouciance', 'Zoned-Out Mark'],
                      description: ['Un insigne pour un Pokémon rêveur.', 'A mark for a daydreaming Pokémon.'], title: ['l\'Insouciant', 'the Daydreamer'] },
    joyful_mark: { name: ['Insigne Bonheur', 'Joyful Mark'],
                   description: ['Un insigne pour un Pokémon joyeux.', 'A mark for a joyful Pokémon.'], title: ['le Guilleret', 'the Joyful'] },
    angry_mark: { name: ['Insigne Colère', 'Angry Mark'],
                  description: ['Un insigne pour un Pokémon furieux.', 'A mark for a furious Pokémon.'], title: ['le Contrarié', 'the Furious'] },
    smiley_mark: { name: ['Insigne Rire', 'Smiley Mark'],
                   description: ['Un insigne pour un Pokémon radieux.', 'A mark for a beaming Pokémon.'], title: ['le Rieur', 'the Beaming'] },
    teary_mark: { name: ['Insigne Pleurs', 'Teary Mark'],
                  description: ['Un insigne pour un Pokémon au bord des larmes.', 'A mark for a teary-eyed Pokémon.'], title: ['le Pleurnicheur', 'the Teary-Eyed'] },
    upbeat_mark: { name: ['Insigne Bonne Humeur', 'Upbeat Mark'],
                   description: ['Un insigne pour un Pokémon plein d’entrain.', 'A mark for a chipper Pokémon.'], title: ['le Bien Luné', 'the Chipper'] },
    peeved_mark: { name: ['Insigne Saute d’Humeur', 'Peeved Mark'],
                   description: ['Un insigne pour un Pokémon grincheux.', 'A mark for a grumpy Pokémon.'], title: ['le Mal Luné', 'the Grumpy'] },
    intellectual_mark: { name: ['Insigne Réflexion', 'Intellectual Mark'],
                         description: ['Un insigne pour un Pokémon érudit.', 'A mark for a scholarly Pokémon.'], title: ['le Réfléchi', 'the Scholar'] },
    ferocious_mark: { name: ['Insigne Menace', 'Ferocious Mark'],
                      description: ['Un insigne pour un Pokémon déchaîné.', 'A mark for a rampaging Pokémon.'], title: ['le Menaçant', 'the Rampaging'] },
    crafty_mark: { name: ['Insigne Ruse', 'Crafty Mark'],
                   description: ['Un insigne pour un Pokémon opportuniste.', 'A mark for an opportunistic Pokémon.'], title: ['l\'Opportuniste', 'the Opportunist'] },
    scowling_mark: { name: ['Insigne Discrétion', 'Scowling Mark'],
                     description: ['Un insigne pour un Pokémon sévère.', 'A mark for a stern Pokémon.'], title: ['le Taciturne', 'the Stern'] },
    kindly_mark: { name: ['Insigne Gentillesse', 'Kindly Mark'],
                   description: ['Un insigne pour un Pokémon au grand cœur.', 'A mark for a kindhearted Pokémon.'], title: ['le Bienveillant', 'the Kindhearted'] },
    flustered_mark: { name: ['Insigne Panique', 'Flustered Mark'],
                      description: ['Un insigne pour un Pokémon qui perd vite ses moyens.', 'A mark for an easily flustered Pokémon.'], title: ['le Paniqué', 'the Easily Flustered'] },
    pumped_up_mark: { name: ['Insigne Entrain', 'Pumped-Up Mark'],
                      description: ['Un insigne pour un Pokémon motivé.', 'A mark for a driven Pokémon.'], title: ['le Motivé', 'the Driven'] },
    zero_energy_mark: { name: ['Insigne Nonchalance', 'Zero Energy Mark'],
                        description: ['Un insigne pour un Pokémon apathique.', 'A mark for an apathetic Pokémon.'], title: ['le Nonchalant', 'the Apathetic'] },
    prideful_mark: { name: ['Insigne Fierté', 'Prideful Mark'],
                     description: ['Un insigne pour un Pokémon arrogant.', 'A mark for an arrogant Pokémon.'], title: ['le Fier', 'the Arrogant'] },
    unsure_mark: { name: ['Insigne Hésitation', 'Unsure Mark'],
                   description: ['Un insigne pour un Pokémon hésitant.', 'A mark for an unsure Pokémon.'], title: ['l\'Hésitant', 'the Reluctant'] },
    humble_mark: { name: ['Insigne Humilité', 'Humble Mark'],
                   description: ['Un insigne pour un Pokémon humble.', 'A mark for a humble Pokémon.'], title: ['le Modeste', 'the Humble'] },
    thorny_mark: { name: ['Insigne Frime', 'Thorny Mark'],
                   description: ['Un insigne pour un Pokémon prétentieux.', 'A mark for a pompous Pokémon.'], title: ['le Frimeur', 'the Pompous'] },
    vigor_mark: { name: ['Insigne Énergie', 'Vigor Mark'],
                  description: ['Un insigne pour un Pokémon plein de vie.', 'A mark for a lively Pokémon.'], title: ['l\'Énergique', 'the Lively'] },
    slump_mark: { name: ['Insigne Abattement', 'Slump Mark'],
                  description: ['Un insigne pour un Pokémon épuisé.', 'A mark for a worn-out Pokémon.'], title: ['l\'Abattu', 'the Worn-Out'] },
    jumbo_mark: { name: ['Insigne Colosse', 'Jumbo Mark'],
                  description: ['Un insigne pour un Pokémon aussi grand qu’il peut l’être.', 'A mark for a Pokémon that\'s the largest it can be.'], title: ['le Colosse', 'the Great'] },
    mini_mark: { name: ['Insigne Mini', 'Mini Mark'],
                 description: ['Un insigne pour un Pokémon aussi petit qu’il peut l’être.', 'A mark for a Pokémon that\'s the smallest it can be.'], title: ['le Minuscule', 'the Teeny'] },
    itemfinder_mark: { name: ['Insigne Trouvaille', 'Itemfinder Mark'],
                       description: ['Un insigne pour un Pokémon qui aime ramasser des objets.', 'A mark for a Pokémon that likes to pick things up.'], title: ['le Chasseur de Trésors', 'the Treasure Hunter'] },
    partner_mark: { name: ['Insigne Partenaire', 'Partner Mark'],
                    description: ['Un insigne pour un Pokémon amical.', 'A mark for a friendly Pokémon.'], title: ['le Fidèle Partenaire', 'the Reliable Partner'] },
    gourmand_mark: { name: ['Insigne Gourmet', 'Gourmand Mark'],
                     description: ['Un insigne pour un Pokémon gourmet.', 'A mark for a Pokémon gourmet.'], title: ['le Fin Gourmet', 'the Gourmet'] },
    alpha_mark: { name: ['Insigne Baron', 'Alpha Mark'],
                  description: ['Un insigne pour un Pokémon qui fut un Baron.', 'A mark for a Pokémon that was an alpha.'], title: ['l\'Ancien Baron', 'the Former Alpha'] },
    mightiest_mark: { name: ['Insigne Suprême', 'Mightiest Mark'],
                      description: ['Un insigne pour un Pokémon particulièrement puissant.', 'A mark for an especially mighty Pokémon.'], title: ['l\'Invincible', 'the Unrivaled'] },
    titan_mark: { name: ['Insigne Dominant', 'Titan Mark'],
                  description: ['Un insigne pour un Pokémon qui fut un Dominant.', 'A mark for a Pokémon that was a Titan.'], title: ['l\'Ancien Dominant', 'the Former Titan'] },
    partner: { name: ['Ruban Partenaire', 'Partner Ribbon'],
               description: ['Ruban spécial reçu par un Pokémon qui a fait équipe avec un grand Dresseur.', 'A special Ribbon awarded to a Pokémon that was once partnered with another great Trainer.'], title: ['{name} de {owner}', '{owner}\'s {name}'] }
  }.freeze
end

module Mementos
  # Rubans définis par PSDK (leurs textes viennent de Data/Text/Dialogs/100075..100077)
  PSDK_RIBBONS = PFM::RIBBONS_DATA.keys.freeze
  MARK_CATEGORIES = %i[time weather encounter rarity personality size party boss].freeze
  CATEGORY_NAMES = {
    contest: %w[Concours Contest], league: %w[Ligue League], frontier: %w[Combat Battle], memorial: %w[Mémorial Memorial],
    gift: %w[Spécial Special], time: %w[Heure Time], weather: %w[Météo Weather], encounter: %w[Rencontre Encounter],
    rarity: %w[Rareté Rarity], personality: %w[Humeur Personality], size: %w[Taille Size], party: %w[Équipe Party],
    boss: %w[Puissance Might]
  }.freeze
  # Tris du résumé (dans l'ordre du menu)
  FILTERS = %i[all rank ribbon mark contest league frontier memorial gift].freeze
  FILTER_NAMES = {
    all: %w[Tous All], rank: ['Rangs regroupés', 'Highest ranks'], ribbon: %w[Rubans Ribbons], mark: %w[Insignes Marks],
    contest: %w[Concours Contest], league: %w[Ligue League], frontier: %w[Combat Battle], memorial: %w[Mémorial Memorial],
    gift: %w[Spécial Special]
  }.freeze

  # Les nouveaux souvenirs rejoignent les rubans de PSDK
  TEXTS.each_key { |sym| PFM::RIBBONS_DATA[sym] ||= PFM::Ribbon.new(sym) }

  module_function

  # @param ribbon [PFM::Ribbon, Symbol]
  # @return [Symbol]
  def sym(ribbon)
    return ribbon.is_a?(PFM::Ribbon) ? ribbon.symbol : ribbon.to_sym
  end

  # @return [Symbol] catégorie du souvenir
  def category(ribbon)
    return INFO.dig(sym(ribbon), 0) || :gift
  end

  def mark?(ribbon)
    return MARK_CATEGORIES.include?(category(ribbon))
  end

  # @return [Array<Symbol>] rangs précédents
  def prev_ranks(ribbon)
    return INFO.dig(sym(ribbon), 1) || []
  end

  def max_rank(ribbon)
    return prev_ranks(ribbon).size + 1
  end

  # @return [Array<Symbol>] insignes d'une catégorie
  def of_category(category)
    return INFO.select { |_, data| data[0] == category }.keys
  end

  # @return [String] « Ruban » ou « Insigne »
  def kind_name(ribbon)
    return mark?(ribbon) ? t('Insigne', 'Mark') : t('Ruban', 'Ribbon')
  end

  def category_name(ribbon)
    return pick(CATEGORY_NAMES[category(ribbon)])
  end

  def filter_name(filter)
    return pick(FILTER_NAMES[filter] || FILTER_NAMES[:all])
  end

  # Le souvenir entre-t-il dans le tri ?
  def match?(ribbon, filter)
    case filter
    when :ribbon then return !mark?(ribbon)
    when :mark then return mark?(ribbon)
    when :all, :rank, nil then return true
    end
    return category(ribbon) == filter
  end

  # Titre complet d'un Pokémon avec ce souvenir
  # @param ribbon [PFM::Ribbon]
  # @param pokemon [PFM::Pokemon]
  # @param name [String, nil] nom à utiliser (surnom par défaut)
  # @return [String] '' si le souvenir ne donne pas de titre
  def full_title(ribbon, pokemon, name = nil)
    title = ribbon.title.to_s
    return '' if title.empty?

    name ||= pokemon.given_name.to_s
    owner = pokemon.respond_to?(:trainer_name) ? pokemon.trainer_name.to_s : ''
    owner = $trainer&.name.to_s if owner.empty?
    title = title.gsub('{owner}', owner).gsub('{player}', $trainer&.name.to_s)
    return title.include?('{name}') ? title.gsub('{name}', name) : "#{name} #{title}"
  end
end

module PFM
  # Les souvenirs connaissent leur catégorie, leur rang et leurs textes (français et anglais)
  class Ribbon
    module MementoData
      # Texte changé dans Studio, sinon celui du plugin (TEXTS), sinon celui de PSDK
      def name
        custom = Mementos.custom_text(@symbol, :name)
        return custom if custom

        texts = Mementos::TEXTS[@symbol]
        return texts ? Mementos.pick(texts[:name]) : super
      end

      def description
        custom = Mementos.custom_text(@symbol, :description)
        return custom if custom

        texts = Mementos::TEXTS[@symbol]
        return texts ? Mementos.pick(texts[:description]) : super
      end

      def title
        custom = Mementos.custom_text(@symbol, :title)
        return custom if custom

        texts = Mementos::TEXTS[@symbol]
        return Mementos.pick(texts[:title]) if texts&.key?(:title)
        return super if Mementos::PSDK_RIBBONS.include?(@symbol)

        return ''
      end
    end
    prepend MementoData

    def mark?
      return Mementos.mark?(@symbol)
    end

    def category
      return Mementos.category(@symbol)
    end

    def prev_ranks
      return Mementos.prev_ranks(@symbol)
    end

    def max_rank
      return Mementos.max_rank(@symbol)
    end
  end
end
