# Capacités ajoutées (128)

## Bolt In — `bolt_in` (#10000)
- steel / physical ; puissance 50, précision 100, PP 20, priorité 0, critique 1
- fonction : `s_self_stat` ; cible : any_other_pokemon ; chance de l'effet : 100
- stats : [{'battleStage': 'SPD_STAGE', 'modificator': 1}] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user crashes into its target while running around aimlessly. Hitting a target raises the Speed stat.

## Cuddle — `cuddle` (#10001)
- fairy / physical ; puissance 40, précision 100, PP 15, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 50
- stats : [{'battleStage': 'ATK_STAGE', 'modificator': -1}] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user snuggles up with the target, damaging its will to fight. This may also lower the target's Attack stat.

## Heartfelt Pulse — `heartfelt_pulse` (#10002)
- normal / special ; puissance 0, précision 100, PP 20, priorité 0, critique 1
- fonction : `s_return` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user gathers its love into a burst of energy that grows more powerful the more the user likes its Trainer.

## Oil Fire — `oil_fire` (#10003)
- fire / special ; puissance 75, précision 100, PP 20, priorité 0, critique 1
- fonction : `s_extra_oil_fire` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user scorches the target with an oily flame that gets stronger if it's raining.

## Electrocute — `electrocute` (#10004)
- electric / special ; puissance 80, précision 100, PP 15, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 100
- stats : [{'battleStage': 'ATK_STAGE', 'modificator': -1}] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user electrocutes the opponent by releasing colorful sparks. This also lowers the target's Attack stat.

## Shadowfall — `shadowfall` (#10005)
- dark / status ; puissance 0, précision 0, PP 5, priorité 0, critique 2
- fonction : `s_extra_shadowfall` ; cible : adjacent_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user brings about a dark overcast, powering up Dark-type moves. It also makes critical hits land more easily.

## The        HUB Collection — `the_hub_collection` (#10006)
- water / physical ; puissance 90, précision 100, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user attacks and drags the target deep underwater, then releases it during the next turn. The target cannot attack while underwater.

## The        Oceane Collection — `the_oceane_collection` (#10007)
- poison / special ; puissance 100, précision 100, PP 5, priorité 0, critique 1
- fonction : `s_extra_fatal_tide` ; cible : adjacent_all_foe ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : A colossal, fetid wave collapses onto opposing Pokémon, dealing heavy damage and preventing the opposing team from using any moves, Abilities, or held items that recover HP.

## Abyssal Dive — `abyssal_dive` (#10008)
- water / physical ; puissance 90, précision 100, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user attacks and drags the target deep underwater, then releases it during the next turn. The target cannot attack while underwater.

## Air Bubble — `air_bubble` (#10009)
- flying / special ; puissance 40, précision 100, PP 30, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 10
- stats : [{'battleStage': 'SPD_STAGE', 'modificator': -1}] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : A lightweight bubble is hurled at the target. This may also lower the target's Speed stat.

## Allergy Pollen — `allergy_pollen` (#10010)
- grass / status ; puissance 0, précision 75, PP 15, priorité 0, critique 1
- fonction : `s_status` ; cible : any_other_pokemon ; chance de l'effet : 100
- stats : [] ; statuts : [{'status': 'BURN', 'luckRate': 100}] ; drapeaux : isMirrorMove, isBlocable
- description : The user scatters a big cloud of urticating pollen around the target to inflict a burn.

## Amber Wave — `amber_wave` (#10011)
- rock / special ; puissance 80, précision 100, PP 10, priorité 0, critique 1
- fonction : `s_bind` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user attacks with a sticky, flowing wave of liquid amber that hardens around the target. The target becomes unable to flee.

## Anticoagulant — `anticoagulant` (#10012)
- poison / status ; puissance 0, précision 100, PP 10, priorité 0, critique 1
- fonction : `s_stat` ; cible : any_other_pokemon ; chance de l'effet : 100
- stats : [{'battleStage': 'DFS_STAGE', 'modificator': -3}] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The target is sprayed with blood-thinning toxins. This drastically lowers the target's Sp. Def stat.

## Aqua Slap — `aqua_slap` (#10013)
- water / physical ; puissance 40, précision 100, PP 25, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 10
- stats : [] ; statuts : [{'status': 'FLINCH', 'luckRate': 10}] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user jumps at its target and attacks with a splash of water. This may also make the target flinch.

## Bananarang — `bananarang` (#10014)
- grass / physical ; puissance 50, précision 90, PP 10, priorité 0, critique 1
- fonction : `s_2hits` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user throws a banana at the target, which loops around to hit the target twice—coming and going.

## Beach Tide — `beach_tide` (#10015)
- water / special ; puissance 75, précision 100, PP 20, priorité 0, critique 1
- fonction : `s_extra_beach_tide` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user drenches the target with a wave of warm water that gets stronger if it's sunny.

## Berserk Fury — `berserk_fury` (#10016)
- dragon / status ; puissance 0, précision 0, PP 5, priorité 0, critique 1
- fonction : `s_stat` ; cible : user ; chance de l'effet : 100
- stats : [{'battleStage': 'ATK_STAGE', 'modificator': 3}] ; statuts : [{'status': 'CONFUSED', 'luckRate': 100}] ; drapeaux : isMirrorMove, isBlocable
- description : The user enters a state of furious berserk. This drastically raises the Attack stat, but leaves the user confused.

## Blaze Arrow — `blaze_arrow` (#10017)
- fire / physical ; puissance 70, précision 100, PP 20, priorité 0, critique 2
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 20
- stats : [] ; statuts : [{'status': 'BURN', 'luckRate': 20}] ; drapeaux : isMirrorMove, isBlocable
- description : The user launches a fierce blast of fire at the target, which may also cause a burn. Critical hits land more easily.

## Bombshell — `bombshell` (#10018)
- water / physical ; puissance 25, précision 90, PP 15, priorité 0, critique 1
- fonction : `s_multi_hit` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user bombards the target with water shells two to five times in a row.

## Bramble Up — `bramble_up` (#10019)
- grass / status ; puissance 0, précision 0, PP 10, priorité 0, critique 1
- fonction : `s_self_stat` ; cible : user ; chance de l'effet : 100
- stats : [{'battleStage': 'ATK_STAGE', 'modificator': 1}, {'battleStage': 'SPD_STAGE', 'modificator': 1}] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user grows sturdy brambles around its limbs, which fortifies them. This raises the user's Attack and Speed stats.

## Breakdown — `breakdown` (#10020)
- psychic / physical ; puissance 120, précision 100, PP 5, priorité 0, critique 1
- fonction : `s_self_stat` ; cible : any_other_pokemon ; chance de l'effet : 100
- stats : [{'battleStage': 'DFE_STAGE', 'modificator': -1}, {'battleStage': 'DFS_STAGE', 'modificator': -1}] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user attacks the target with all its passion. This also lowers the user's Defense and Sp. Def stats.

## Burning Sneeze — `burning_sneeze` (#10021)
- fire / special ; puissance 50, précision 80, PP 20, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 30
- stats : [] ; statuts : [{'status': 'BURN', 'luckRate': 30}, {'status': 'POISONED', 'luckRate': 15}] ; drapeaux : isMirrorMove, isBlocable
- description : The user attacks by shooting flaming snot at the target. This may also leave the target poisoned or with a burn.

## Caffeine Sip — `caffeine_sip` (#10022)
- dark / status ; puissance 0, précision 0, PP 5, priorité 0, critique 1
- fonction : `s_heal` ; cible : user ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user restores its own HP by up to half of its max HP. It prevents sleep by turning the user's Ability to Vital Spirit.

## Caustic Breath — `caustic_breath` (#10023)
- dragon / special ; puissance 60, précision 100, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : adjacent_all_foe ; chance de l'effet : 100
- stats : [{'battleStage': 'DFE_STAGE', 'modificator': -1}, {'battleStage': 'DFS_STAGE', 'modificator': -1}] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The users exhales caustic breath at opposing Pokémon. This also lowers the Defense and Sp. Def stats of those hit.

## Cheer Up — `cheer_up` (#10024)
- light / status ; puissance 0, précision 0, PP 20, priorité 0, critique 1
- fonction : `s_stat` ; cible : all_ally ; chance de l'effet : 100
- stats : [{'battleStage': 'ATS_STAGE', 'modificator': 1}] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user cheers up itself and its allies. This raises their Sp. Atk stats.

## Cherub Arrow — `cherub_arrow` (#10025)
- fairy / physical ; puissance 60, précision 100, PP 20, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user shoots a glimmering arrow at the target. This also infatuates a Pokémon of the opposing gender.

## Clone Attack — `clone_attack` (#10026)
- dark / physical ; puissance 20, précision 100, PP 20, priorité 0, critique 1
- fonction : `s_multi_hit` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user attacks the target with shadow clones that strike two to five times in a row.

## Cloud Crash — `cloud_crash` (#10027)
- flying / physical ; puissance 100, précision 100, PP 5, priorité 0, critique 1
- fonction : `s_stomp` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user flies down from above and bashes the target using its entire body.

## Coal Throw — `coal_throw` (#10028)
- fire / physical ; puissance 15, précision 90, PP 20, priorité 1, critique 1
- fonction : `s_multi_hit` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user attacks by pelting the target with hot coals two to five times in a row at amazing speeds. This move always goes first.

## Cold Snap — `cold_snap` (#10029)
- ice / status ; puissance 0, précision 50, PP 5, priorité 0, critique 1
- fonction : `s_status` ; cible : any_other_pokemon ; chance de l'effet : 100
- stats : [] ; statuts : [{'status': 'FROZEN', 'luckRate': 100}] ; drapeaux : isMirrorMove, isBlocable
- description : The user drops air temperature around the target to inflict freeze.

## Coral Break — `coral_break` (#10030)
- water / special ; puissance 80, précision 95, PP 15, priorité 0, critique 1
- fonction : `s_psyshock` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user creates crashing waves to attack the target. This attack does physical damage.

## Corrosion Wave — `corrosion_wave` (#10031)
- poison / special ; puissance 70, précision 100, PP 20, priorité 0, critique 1
- fonction : `s_extra_corrosion_wave` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user emits horrible waves that corrode away any metal. This move is super effective on Steel types.

## Corrosive Bite — `corrosive_bite` (#10032)
- poison / physical ; puissance 80, précision 100, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 20
- stats : [] ; statuts : [{'status': 'TOXIC', 'luckRate': 20}] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user bites down on the target, injecting corrosive toxins. This may also leave the target badly poisoned.

## Crop Circle — `crop_circle` (#10033)
- psychic / status ; puissance 0, précision 0, PP 10, priorité 0, critique 1
- fonction : `s_extra_crop_circle` ; cible : all_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user makes an intricate pattern on the field that emanates cosmic energy, increasing the Sp. Atk, Sp. Def, and Speed stats of Grass-type Pokémon.

## Cryopreserve — `cryopreserve` (#10034)
- ice / status ; puissance 0, précision 80, PP 10, priorité 0, critique 1
- fonction : `s_extra_cryopreserve` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user freezes its target to fully heal its HP.

## Curse of Ash — `curse_of_ash` (#10035)
- fire / special ; puissance 120, précision 100, PP 5, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 100
- stats : [] ; statuts : [{'status': 'BURN', 'luckRate': 100}] ; drapeaux : isMirrorMove, isBlocable
- description : The user calls on otherworldly powers to burn the target to ash. This also places a curse on the user.

## Cyclone — `cyclone` (#10036)
- flying / special ; puissance 100, précision 100, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : adjacent_all_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user starts a powerful cyclone, attacking everything around it.

## Depth Charge — `depth_charge` (#10037)
- water / physical ; puissance 95, précision 90, PP 5, priorité 0, critique 1
- fonction : `s_2turns` ; cible : any_other_pokemon ; chance de l'effet : 30
- stats : [] ; statuts : [{'status': 'FLINCH', 'luckRate': 30}] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user dives underwater on the first turn, then launches a surprise attack on the second turn that may also make the target flinch. This move hits even if the target protects itself.

## Downpour — `downpour` (#10038)
- water / special ; puissance 130, précision 90, PP 5, priorité 0, critique 1
- fonction : `s_self_stat` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [{'battleStage': 'ATS_STAGE', 'modificator': -2}] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user bombards the target from above with an immeasurable amount of water. The attack's recoil harshly lowers the user's Sp. Atk stat.

## Drag Under — `drag_under` (#10039)
- water / status ; puissance 0, précision 100, PP 5, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The target is dragged underwater, becoming trapped. In three turns, both the user and target faint. Water types cannot be fainted by this effect.

## Dragon Fang — `dragon_fang` (#10040)
- dragon / physical ; puissance 65, précision 95, PP 15, priorité 0, critique 1
- fonction : `s_self_stat` ; cible : any_other_pokemon ; chance de l'effet : 10
- stats : [{'battleStage': 'ATK_STAGE', 'modificator': 1}] ; statuts : [{'status': 'FLINCH', 'luckRate': 10}] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user bites the target, rousing itself with power. This may also make the target flinch or raise the user's Attack stat.

## Dust Kick — `dust_kick` (#10041)
- ground / physical ; puissance 40, précision 100, PP 25, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 10
- stats : [{'battleStage': 'ACC_STAGE', 'modificator': -1}] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user attacks with a kick of dust. This may also lower the target's accuracy.

## Dust Tornado — `dust_tornado` (#10042)
- ground / special ; puissance 90, précision 90, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user attacks with razing sand that gets into the opponent's eyes. The target is tormented, making it incapable of using the same move twice in a row.

## Ear Split — `ear_split` (#10043)
- normal / special ; puissance 120, précision 100, PP 5, priorité 0, critique 1
- fonction : `s_basic` ; cible : adjacent_all_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user lets out a terrible ear-splitting noise, damaging everything around it. Any Pokémon affected by this move obtains the Ability Soundproof.

## Echolocate — `echolocate` (#10044)
- normal / status ; puissance 0, précision 0, PP 15, priorité 0, critique 1
- fonction : `s_self_stat` ; cible : user ; chance de l'effet : 0
- stats : [{'battleStage': 'ATS_STAGE', 'modificator': 1}, {'battleStage': 'ACC_STAGE', 'modificator': 1}] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user scans for weak points using sonar to boost its Sp. Atk stat and accuracy.

## Electric Cheer — `electric_cheer` (#10045)
- electric / status ; puissance 0, précision 0, PP 10, priorité 0, critique 1
- fonction : `s_stat` ; cible : all_ally ; chance de l'effet : 100
- stats : [{'battleStage': 'ATS_STAGE', 'modificator': 1}, {'battleStage': 'SPD_STAGE', 'modificator': 1}] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user cheers on its ally Pokémon with a shower of sparks, boosting the Sp. Atk and Speed stats.

## Ensnare — `ensnare` (#10046)
- water / physical ; puissance 60, précision 90, PP 10, priorité 0, critique 1
- fonction : `s_bind` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The target becomes trapped by the user's ensnaring tendrils for four to five turns.

## Epilogue — `epilogue` (#10047)
- normal / status ; puissance 0, précision 0, PP 5, priorité 0, critique 1
- fonction : `s_basic` ; cible : all_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user forcefully ends and prevents the activation of field effects, such as weather conditions and terrains, for three turns.

## Faceplant — `faceplant` (#10048)
- grass / physical ; puissance 40, précision 100, PP 15, priorité 0, critique 1
- fonction : `s_extra_faceplant` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user grows roots or vines to slam the target into the ground with great force. The target takes additional damage from any traps set around its feet.

## Fatal Tide — `fatal_tide` (#10049)
- poison / special ; puissance 100, précision 100, PP 5, priorité 0, critique 1
- fonction : `s_extra_fatal_tide` ; cible : adjacent_all_foe ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : A colossal, fetid wave collapses onto opposing Pokémon, dealing heavy damage and preventing the opposing team from using any moves, Abilities, or held items that recover HP.

## Vital Tide — `vital_tide` (#10050)
- water / status ; puissance 0, précision 0, PP 5, priorité 0, critique 1
- fonction : `s_u_turn` ; cible : user ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user switches places with a party Pokémon in waiting. One turn after this move is used, a healing tide rushes in, healing the active Pokémon on the user's side.

## Feather Slash — `feather_slash` (#10051)
- flying / physical ; puissance 80, précision 95, PP 15, priorité 0, critique 2
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user slashes and cuts the target with its feathers. Critical hits land more easily.

## Festive Shot — `festive_shot` (#10052)
- dragon / special ; puissance 95, précision 90, PP 5, priorité 0, critique 1
- fonction : `s_basic` ; cible : adjacent_all_pokemon ; chance de l'effet : 30
- stats : [] ; statuts : [{'status': 'CONFUSED', 'luckRate': 30}] ; drapeaux : isMirrorMove, isBlocable
- description : The user fires colorful bursts of energy, hitting everything around it. This may also confuse those hit.

## Firewall — `firewall` (#10053)
- fire / status ; puissance 0, précision 0, PP 10, priorité 0, critique 1
- fonction : `s_status` ; cible : user ; chance de l'effet : 100
- stats : [] ; statuts : [{'status': 'BURN', 'luckRate': 100}] ; drapeaux : isMirrorMove, isBlocable
- description : In addition to protecting the user from attacks, this move also burns any attacker that makes direct contact.

## Flame Pounce — `flame_pounce` (#10054)
- fire / physical ; puissance 40, précision 100, PP 20, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : A physical attack in which the user leaps foward and smacks the target with its warmed-up body.

## Flurry Peck — `flurry_peck` (#10055)
- flying / physical ; puissance 20, précision 100, PP 20, priorité 0, critique 1
- fonction : `s_multi_hit` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user pecks the target repeatedly two to five times in a row.

## Fruit Munch — `fruit_munch` (#10056)
- grass / status ; puissance 0, précision 0, PP 10, priorité 0, critique 1
- fonction : `s_heal` ; cible : user ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user eats its held Berry, then restores its own HP by up to half of its max HP.

## Glow Signal — `glow_signal` (#10057)
- psychic / special ; puissance 30, précision 100, PP 20, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 100
- stats : [] ; statuts : [{'status': 'CONFUSED', 'luckRate': 100}] ; drapeaux : isMirrorMove, isBlocable
- description : The user attacks by emitting a mysterious flash from its body. This also leaves the target confused.

## Hair Sweep — `hair_sweep` (#10058)
- psychic / physical ; puissance 80, précision 100, PP 15, priorité 0, critique 1
- fonction : `s_bind` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user elongates its hair, then strikes the target with it. The target is entangled and becomes unable to flee.

## Hammer Throw — `hammer_throw` (#10059)
- fighting / physical ; puissance 110, précision 100, PP 10, priorité 0, critique 1
- fonction : `s_2turns` ; cible : any_other_pokemon ; chance de l'effet : 100
- stats : [{'battleStage': 'SPD_STAGE', 'modificator': 1}] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : In this two-turn attack, the user spins a hammer and raises its speed before releasing it on the second turn.

## Harrowing Wail — `harrowing_wail` (#10060)
- ghost / special ; puissance 80, précision 100, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : adjacent_all_pokemon ; chance de l'effet : 30
- stats : [] ; statuts : [{'status': 'FLINCH', 'luckRate': 30}] ; drapeaux : isMirrorMove, isBlocable
- description : The user lets out a ghastly wail, damaging every Pokémon around it. This may also cause those hit to flinch.

## Honey Pour — `honey_pour` (#10061)
- bug / status ; puissance 0, précision 100, PP 15, priorité 0, critique 1
- fonction : `s_stat` ; cible : any_other_pokemon ; chance de l'effet : 100
- stats : [{'battleStage': 'SPD_STAGE', 'modificator': -1}] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user pours sticky honey over the target, lowering the target's Speed stat. The target becomes weaker to Bug-type moves.

## Ice Blade — `ice_blade` (#10062)
- ice / physical ; puissance 90, précision 100, PP 5, priorité 0, critique 2
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 30
- stats : [] ; statuts : [{'status': 'FROZEN', 'luckRate': 30}] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user swings cold-infused claws or a horn like a blade that may leave the target frozen. Critical hits land more easily.

## Jumpscare — `jumpscare` (#10063)
- ghost / physical ; puissance 55, précision 100, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user attacks the target while shouting in a startling fashion. If the target that has just switched into battle, the attack's power will be doubled.

## Jumpstart — `jumpstart` (#10064)
- electric / physical ; puissance 110, précision 100, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 100
- stats : [{'battleStage': 'SPD_STAGE', 'modificator': 1}] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user delivers a terrible electric shock into the target. This also raises the Speed stat of the target, however.

## Landslide — `landslide` (#10065)
- ground / physical ; puissance 60, précision 100, PP 10, priorité 0, critique 1
- fonction : `s_revenge` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The power of this attack move is doubled if the user has been hurt by the target in the same turn.

## Liquefaction — `liquefaction` (#10066)
- rock / physical ; puissance 70, précision 100, PP 15, priorité 0, critique 1
- fonction : `s_extra_liquefaction` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user applies tectonic stress to the ground around the target. This move is super effective on Ground types.

## Liquid Metal — `liquid_metal` (#10067)
- steel / special ; puissance 70, précision 100, PP 15, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 30
- stats : [] ; statuts : [{'status': 'POISONED', 'luckRate': 30}] ; drapeaux : isMirrorMove, isBlocable
- description : The user spouts contaminating, metallic liquid on the target. This may also poison the target.

## Love Lariat — `love_lariat` (#10068)
- fairy / physical ; puissance 75, précision 100, PP 15, priorité 0, critique 1
- fonction : `s_extra_love_lariat` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The target is squeezed tightly. This attack does massive damage to a target that is infatuated.

## Magic Backlash — `magic_backlash` (#10069)
- ghost / special ; puissance 120, précision 90, PP 15, priorité 0, critique 1
- fonction : `s_extra_magic_backlash` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user casts a forbidden spell on the target with tremendous power. This also damages the user quite a lot.

## Malice Strike — `malice_strike` (#10070)
- ghost / physical ; puissance 80, précision 95, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 30
- stats : [] ; statuts : [{'status': 'FLINCH', 'luckRate': 30}] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The target is struck with all the frustrations of the user. This may also make the target flinch.

## Meteor Shower — `meteor_shower` (#10071)
- rock / special ; puissance 90, précision 100, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : adjacent_all_pokemon ; chance de l'effet : 30
- stats : [] ; statuts : [{'status': 'ASLEEP', 'luckRate': 30}] ; drapeaux : isMirrorMove, isBlocable
- description : The user attacks everything around it with pretty lights that rain like comets. This may also induce sleep.

## Mud Slide — `mud_slide` (#10072)
- ground / special ; puissance 95, précision 90, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : adjacent_all_foe ; chance de l'effet : 30
- stats : [{'battleStage': 'SPD_STAGE', 'modificator': -1}] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user fires a torrent of thick mud at the opposing Pokémon. This may also lower their Speed stat.

## Mystic Song — `mystic_song` (#10073)
- dragon / special ; puissance 90, précision 100, PP 10, priorité 0, critique 1
- fonction : `s_self_stat` ; cible : any_other_pokemon ; chance de l'effet : 30
- stats : [{'battleStage': 'DFS_STAGE', 'modificator': 1}] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user sings a powerful, ancient song with damaging energy. This may also raise the user's Sp. Def stat.

## Nature's Call — `natures_call` (#10074)
- grass / status ; puissance 0, précision 0, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : all_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : All Pokémon on the field are forced to answer Nature's call, and have to switch out. In the wild, this ends a battle.

## Neurotoxin — `neurotoxin` (#10075)
- poison / special ; puissance 60, précision 95, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user attacks the target with a toxin that affects the mind. The target is prevented from using a Psychic-type move during this turn.

## Overrule — `overrule` (#10076)
- dragon / status ; puissance 0, précision 100, PP 5, priorité 0, critique 1
- fonction : `s_status` ; cible : any_other_pokemon ; chance de l'effet : 100
- stats : [] ; statuts : [{'status': 'FLINCH', 'luckRate': 100}] ; drapeaux : isMirrorMove, isBlocable
- description : The user stares down at the opponent terrifyingly, making it flinch. This move can't be used twice in a row.

## Paradise Display — `paradise_display` (#10077)
- flying / physical ; puissance 120, précision 100, PP 10, priorité 0, critique 1
- fonction : `s_outrage` ; cible : any_other_pokemon ; chance de l'effet : 100
- stats : [] ; statuts : [{'status': 'CONFUSED', 'luckRate': 100}] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user displays its feathers in a magnificent and violent dance for two to three turns. The user then becomes confused.

## Pester — `pester` (#10078)
- bug / status ; puissance 0, précision 100, PP 20, priorité 0, critique 1
- fonction : `s_stat` ; cible : any_other_pokemon ; chance de l'effet : 100
- stats : [{'battleStage': 'ATK_STAGE', 'modificator': -1}, {'battleStage': 'ATS_STAGE', 'modificator': -1}] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user annoys the target with chittering noises, lowering its Attack and Sp. Atk stats.

## Phantom Hand — `phantom_hand` (#10079)
- ghost / special ; puissance 60, précision 100, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user employs supernatural power to drag out a different Pokémon into battle, then attacks it with a ghostly hand.

## Pinch — `pinch` (#10080)
- bug / physical ; puissance 30, précision 100, PP 15, priorité 0, critique 1
- fonction : `s_bind` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The target is trapped and squeezed continuously by the user's claws or pincers for four to five turns.

## Pixie Dust — `pixie_dust` (#10081)
- fairy / status ; puissance 0, précision 100, PP 15, priorité 0, critique 1
- fonction : `s_status` ; cible : any_other_pokemon ; chance de l'effet : 100
- stats : [] ; statuts : [{'status': 'PARALYZED', 'luckRate': 100}] ; drapeaux : isMirrorMove, isBlocable
- description : The user sprinkles mysterious dust on the target to inflict either confusion, paralysis, or sleep.

## Poison Dart — `poison_dart` (#10082)
- poison / physical ; puissance 40, précision 100, PP 20, priorité 1, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 100
- stats : [] ; statuts : [{'status': 'POISONED', 'luckRate': 100}] ; drapeaux : isMirrorMove, isBlocable
- description : The user shoots poison at the target with incredible speed and precision. This move always goes first.

## Prickle Barbs — `prickle_barbs` (#10083)
- poison / physical ; puissance 25, précision 95, PP 10, priorité 0, critique 1
- fonction : `s_multi_hit` ; cible : any_other_pokemon ; chance de l'effet : 30
- stats : [] ; statuts : [{'status': 'POISONED', 'luckRate': 30}] ; drapeaux : isMirrorMove, isBlocable
- description : The user fires a series of poison-laced barbs at the target two to five times in a row. This may also poison the target.

## Psi Bullet — `psi_bullet` (#10084)
- psychic / special ; puissance 60, précision 95, PP 10, priorité 0, critique 1
- fonction : `s_full_crit` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user fires a bullet of concentrated psychic energy. This attack always results in a critical hit.

## Puff Up — `puff_up` (#10085)
- fairy / physical ; puissance 40, précision 95, PP 20, priorité 0, critique 1
- fonction : `s_fury_cutter` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user attacks by puffing up its body. This attack becomes more powerful if it hits in succession.

## Rainbow Rush — `rainbow_rush` (#10086)
- fairy / physical ; puissance 110, précision 75, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user rushes at the target with great speed, leaving a rainbow trail behind.

## Rebound Strike — `rebound_strike` (#10087)
- steel / physical ; puissance 25, précision 90, PP 10, priorité 0, critique 1
- fonction : `s_multi_hit` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user rapidly hurls steel projectiles at the target two to five times in a row.

## Relic Pillar — `relic_pillar` (#10088)
- rock / special ; puissance 85, précision 90, PP 10, priorité 0, critique 1
- fonction : `s_psyshock` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user conjures a strange stone pillar from the ground, which falls onto the target. This attack does physical damage.

## Reservoir — `reservoir` (#10089)
- water / status ; puissance 0, précision 0, PP 5, priorité 0, critique 1
- fonction : `s_heal` ; cible : user_or_adjacent_ally ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user or an ally drinks from a supply of pure water, restoring up to half its max HP. It restores more HP in rain.

## Resonate — `resonate` (#10090)
- psychic / special ; puissance 70, précision 90, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 100
- stats : [] ; statuts : [{'status': 'POISONED', 'luckRate': 100}] ; drapeaux : isMirrorMove, isBlocable
- description : The user emits a damaging sound wave using its psychic energy. If the user is burned, poisoned or paralyzed, those hit will receive the same status condition.

## Rolling Press — `rolling_press` (#10091)
- fighting / physical ; puissance 80, précision 100, PP 15, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 30
- stats : [] ; statuts : [{'status': 'FLINCH', 'luckRate': 30}] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user curls up in a ball and runs the target over. This may also make the target flinch.

## Savage Slash — `savage_slash` (#10092)
- ground / physical ; puissance 100, précision 90, PP 5, priorité 0, critique 2
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user strikes with sharp claws powered by the forces of nature. Critical hits land more easily.

## Seed Shot — `seed_shot` (#10093)
- grass / physical ; puissance 40, précision 100, PP 20, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user shoots a seed at the target to inflict damage.

## Self-Repair — `self_repair` (#10094)
- steel / status ; puissance 0, précision 0, PP 5, priorité 0, critique 1
- fonction : `s_heal` ; cible : user ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : Repairing itself, the user restores its own HP by half of its max HP.

## Setting Sun — `setting_sun` (#10095)
- fire / special ; puissance 120, précision 95, PP 5, priorité 0, critique 1
- fonction : `s_extra_setting_sun` ; cible : adjacent_all_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user attacks everything around it by creating a blinding image of the setting sun. This move can only be used under harsh sunlight, but also brings it to an end.

## Shadow Dance — `shadow_dance` (#10096)
- ghost / status ; puissance 0, précision 0, PP 20, priorité 0, critique 1
- fonction : `s_self_stat` ; cible : user ; chance de l'effet : 0
- stats : [{'battleStage': 'DFS_STAGE', 'modificator': 1}, {'battleStage': 'SPD_STAGE', 'modificator': 1}] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user gracefully performs a haunting, elegant dance that boosts its Sp. Def and Speed stats.

## Shed Fangs — `shed_fangs` (#10097)
- normal / status ; puissance 0, précision 0, PP 30, priorité 0, critique 1
- fonction : `s_basic` ; cible : user ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user sheds its fangs and grows new ones, removing any stat-lowering effects.

## Snow Slide — `snow_slide` (#10098)
- ice / physical ; puissance 70, précision 100, PP 15, priorité 0, critique 1
- fonction : `s_extra_snow_slide` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user tackles the target while covered in snow. This move's power doubles during a snowstorm.

## Soak Up — `soak_up` (#10099)
- water / status ; puissance 0, précision 100, PP 20, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user drains excess water from the target, removing its Water-type.

## Solar Charger — `solar_charger` (#10100)
- electric / special ; puissance 60, précision 100, PP 15, priorité 0, critique 1
- fonction : `s_basic` ; cible : adjacent_all_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user gathers energy from sunlight to attack everything around it. In sunny weather, this move also raises the user's Sp. Atk.

## Solar Flare — `solar_flare` (#10101)
- fire / special ; puissance 100, précision 100, PP 10, priorité 0, critique 1
- fonction : `s_2turns` ; cible : any_other_pokemon ; chance de l'effet : 30
- stats : [] ; statuts : [{'status': 'BURN', 'luckRate': 30}] ; drapeaux : isMirrorMove, isBlocable
- description : Absorbing heat on the first turn, the user releases searing light on the next turn. This may also leave the target with a burn.

## Starstream — `starstream` (#10102)
- psychic / special ; puissance 80, précision 100, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 30
- stats : [] ; statuts : [{'status': 'ASLEEP', 'luckRate': 30}] ; drapeaux : isMirrorMove, isBlocable
- description : The user assails the target with strange, starry energy. This may also induce sleep.

## Stun Jab — `stun_jab` (#10103)
- electric / physical ; puissance 70, précision 100, PP 15, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 30
- stats : [] ; statuts : [{'status': 'PARALYZED', 'luckRate': 30}] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The target is stabbed with an electrified arm or horn. This may also leave the target with paralysis.

## Supercell — `supercell` (#10104)
- electric / special ; puissance 70, précision 70, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : adjacent_all_foe ; chance de l'effet : 100
- stats : [{'battleStage': 'ACC_STAGE', 'modificator': -1}] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user traps and disorients opposing Pokémon in a violent thunder storm. This also lowers the accuracy of those hit.

## Sweet Decay — `sweet_decay` (#10105)
- fairy / special ; puissance 90, précision 100, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user attacks with a concentrated blast of sugar that rots the target's teeth, preventing it from using biting moves for two turns.

## Team Up — `team_up` (#10106)
- normal / physical ; puissance 20, précision 100, PP 10, priorité 0, critique 1
- fonction : `s_beat_up` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user gets all party Pokémon to attack the target. The more party Pokémon, the greater the number of attacks.

## Thunder Tail — `thunder_tail` (#10107)
- electric / physical ; puissance 85, précision 95, PP 15, priorité 0, critique 2
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user strikes the target with an electrically charged tail. Critical hits land more easily.

## Toxic Fumes — `toxic_fumes` (#10108)
- poison / special ; puissance 80, précision 100, PP 15, priorité 0, critique 1
- fonction : `s_basic` ; cible : adjacent_all_pokemon ; chance de l'effet : 30
- stats : [] ; statuts : [{'status': 'POISONED', 'luckRate': 30}] ; drapeaux : isMirrorMove, isBlocable
- description : The user creates repulsive gases to damage everything around it, which may poison those hit. This move always poisons those hit when used on Filthy Terrain.

## Tranquilize — `tranquilize` (#10109)
- bug / physical ; puissance 50, précision 100, PP 15, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 100
- stats : [] ; statuts : [{'status': 'ASLEEP', 'luckRate': 100}] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user injects the target with a stinger loaded with sleep-inducing toxins. The target becomes drowsy and will fall asleep on the next turn.

## Vine Swing — `vine_swing` (#10110)
- grass / physical ; puissance 55, précision 100, PP 15, priorité 0, critique 1
- fonction : `s_acrobatics` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user quickly swings itself onto the target. If the user is not holding any item, this attack inflicts massive damage.

## Violent Swarm — `violent_swarm` (#10111)
- bug / physical ; puissance 75, précision 100, PP 15, priorité 0, critique 1
- fonction : `s_basic` ; cible : adjacent_all_foe ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user attacks the target with a swarm of biting insects. This move damages all opposing Pokémon and always results in a critical hit on Swarming Terrain.

## Windblast — `windblast` (#10112)
- flying / special ; puissance 100, précision 85, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 30
- stats : [{'battleStage': 'DFS_STAGE', 'modificator': -1}] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user attacks by letting out a blast of wind from its gaping mouth. This may also lower the target's Sp. Def stat.

## Wriggle — `wriggle` (#10113)
- bug / physical ; puissance 40, précision 100, PP 30, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user attacks the target by writhing about. This frees the user from such moves as Bind, Wrap, and Block.

## Ambuscade — `ambuscade` (#10114)
- ground / status ; puissance 0, précision 0, PP 10, priorité 0, critique 1
- fonction : `s_stat` ; cible : user ; chance de l'effet : 100
- stats : [{'battleStage': 'SPD_STAGE', 'modificator': -2}] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user lies in wait, ready to pounce on incoming prey, while preparing itself to avoid any attacks. It also harshly lowers the Speed stat of any attacker that makes direct contact.

## Duress — `duress` (#10115)
- psychic / special ; puissance 50, précision 95, PP 20, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user puts the opponent's mind under intense strain. This attack becomes more powerful if it hits in succession.

## Engulf — `engulf` (#10116)
- dark / physical ; puissance 100, précision 95, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : Traps the foe underwater using its tentacles, reducing its Defense and Evasion.

## Flame Impact — `flame_impact` (#10117)
- fire / physical ; puissance 65, précision 100, PP 15, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user tackles the target at high temps gained by air friction. This attack always goes first.

## Glacial Spear — `glacial_spear` (#10118)
- ice / physical ; puissance 100, précision 95, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : Pierces through all barriers and defenses of the enemy.

## Infernal Blade — `infernal_blade` (#10119)
- fire / physical ; puissance 90, précision 95, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 30
- stats : [] ; statuts : [{'status': 'BURN', 'luckRate': 30}] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user slashes the target with cursed fire. This may also leave the target with a burn. This move is always super effective on Fairy types.

## Laser Pulse — `laser_pulse` (#10120)
- normal / special ; puissance 90, précision 100, PP 20, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user attacks with an elemental laser. This move's type can be Fire, Electric or Ice randomly.

## Metal Cruncher — `metal_cruncher` (#10121)
- steel / physical ; puissance 120, précision 85, PP 5, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 30
- stats : [{'battleStage': 'DFE_STAGE', 'modificator': -1}] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user crunches up the target with metal fangs. This may also lower the target's Defense stat.

## Metal Whip — `metal_whip` (#10122)
- steel / physical ; puissance 50, précision 90, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The target is attacked and held with a whip of steel for four to five turns.

## Ocean's Wrath — `oceans_wrath` (#10123)
- water / special ; puissance 90, précision 100, PP 20, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The target becomes trapped in a giant whirlpool for four to five turns.

## Sandy Splash — `sandy_splash` (#10124)
- water / special ; puissance 90, précision 100, PP 15, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : The user enthusiastically splashes a wave of sandy water at the opponent. This move is Water and Ground type simultaneously.

## Subduction — `subduction` (#10125)
- ground / physical ; puissance 140, précision 90, PP 5, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 100
- stats : [] ; statuts : [{'status': 'CONFUSED', 'luckRate': 100}] ; drapeaux : isMirrorMove, isBlocable
- description : The user creates a massive earthquake that causes the land underneath the foe to rise up and crash down. This massive effort confuses the user.

## Sudden Strike — `sudden_strike` (#10126)
- dark / physical ; puissance 40, précision 100, PP 30, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isDirect, isMirrorMove, isBlocable
- description : The user attacks the target in a sudden, rapid strike. This move always goes first.

## Vaporize — `vaporize` (#10127)
- fire / special ; puissance 100, précision 95, PP 10, priorité 0, critique 1
- fonction : `s_basic` ; cible : any_other_pokemon ; chance de l'effet : 0
- stats : [] ; statuts : [] ; drapeaux : isMirrorMove, isBlocable
- description : Overpowers the foe with a blast of extreme temperature. Super effective on Water.
