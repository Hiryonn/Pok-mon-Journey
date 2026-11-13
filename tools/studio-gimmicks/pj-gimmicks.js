/* eslint-disable */
// =============================================================================
// Gimmicks — Données > Gimmicks de Pokémon Studio (plugin « gimmicks »), une page par mécanique :
//   Méga-gemmes : objets clés, Pokémon qui méga-évoluent (forme + méga-gemme), dresseurs (objet clé, gemmes tenues)
//   Capacités Z : objets clés, cristaux de type et exclusifs, dresseurs (objet clé, cristaux tenus)
//   Téracristal : Orbe Téracristal, type Téra par défaut des Pokémon, dresseurs (objet clé, type Téra de l'équipe)
//   Dynamax     : durée, niveau, facteur Gigamax (général / par Pokémon), dresseurs (objet clé, Gigamax, niveau)
//   Chaque page a aussi les réglages communs (mécaniques actives, cinématique, dresseurs adverses).
// Enregistre Data/configs/plugins/gimmicks.json. Style de l'éditeur Smartphone (classes pjs-*), installé avant lui.
// =============================================================================
(() => {
  'use strict';
  if (window.__pjGimmicksLoaded) return;
  window.__pjGimmicksLoaded = true;

  const DEFAULTS = {
    klass: 'GimmicksConfig',
    enabled: { mega: true, zmove: true, dynamax: true, tera: true },
    cinematic: true,
    ai: true,
    ai_chance: 0.4,
    dynamax_turns: 3,
    dynamax_level: 10,
    tera_orb_recharge: true,
    gmax_rate: 0,
    species: {},
    trainers: {},
  };
  const GIMMICKS = [
    ['mega', 'Méga-Évolution', "Objet clé : Méga-Anneau (ou tout objet « Permet la méga-évolution »). Le Pokémon tient sa méga-gemme."],
    ['zmove', 'Capacités Z', 'Objet clé : Bracelet Z. Le Pokémon tient un cristal Z (de type ou exclusif).'],
    ['dynamax', 'Dynamax / Gigamax', 'Objet clé : Poignet Dynamax. 3 tours, PV augmentés, attaques Max ; Gigamax avec le facteur Gigamax.'],
    ['tera', 'Téracristal', "Objet clé : Orbe Téracristal. Le Pokémon prend son type Téra jusqu'à la fin du combat."],
  ];
  const TERA_TYPES = [['normal', 'Normal'], ['fighting', 'Combat'], ['flying', 'Vol'], ['poison', 'Poison'], ['ground', 'Sol'], ['rock', 'Roche'],
    ['bug', 'Insecte'], ['ghost', 'Spectre'], ['steel', 'Acier'], ['fire', 'Feu'], ['water', 'Eau'], ['grass', 'Plante'], ['electric', 'Électrik'],
    ['psychic', 'Psy'], ['ice', 'Glace'], ['dragon', 'Dragon'], ['dark', 'Ténèbres'], ['fairy', 'Fée'], ['stellar', 'Stellaire']];
  const typeName = (t) => (TERA_TYPES.find((x) => x[0] === t) || ['', t])[1];
  // Capacités Z exclusives (les mêmes que dans le plugin) : cristal => [Pokémon, attaque, capacité Z]
  const Z_EXCLUSIVE = {
    aloraichium_z: [['raichu'], 'thunderbolt', 'stoked_sparksurfer'], decidium_z: [['decidueye'], 'spirit_shackle', 'sinister_arrow_raid'],
    eevium_z: [['eevee'], 'last_resort', 'extreme_evoboost'], incinium_z: [['incineroar'], 'darkest_lariat', 'malicious_moonsault'],
    kommonium_z: [['kommo_o'], 'clanging_scales', 'clangorous_soulblaze'], lunalium_z: [['lunala', 'necrozma'], 'moongeist_beam', 'menacing_moonraze_maelstrom'],
    lycanium_z: [['lycanroc'], 'stone_edge', 'splintered_stormshards'], marshadium_z: [['marshadow'], 'spectral_thief', 'soul_stealing_7_star_strike'],
    mewnium_z: [['mew'], 'psychic', 'genesis_supernova'], mimikium_z: [['mimikyu'], 'play_rough', 'let_s_snuggle_forever'],
    pikanium_z: [['pikachu'], 'volt_tackle', 'catastropika'], pikashunium_z: [['pikachu'], 'thunderbolt', 's10_000_000_volt_thunderbolt'],
    primarium_z: [['primarina'], 'sparkling_aria', 'oceanic_operetta'], snorlium_z: [['snorlax'], 'giga_impact', 'pulverizing_pancake'],
    solganium_z: [['solgaleo', 'necrozma'], 'sunsteel_strike', 'searing_sunraze_smash'],
    tapunium_z: [['tapu_koko', 'tapu_lele', 'tapu_bulu', 'tapu_fini'], 'nature_s_madness', 'guardian_of_alola'],
    ultranecrozium_z: [['necrozma'], 'photon_geyser', 'light_that_burns_the_sky'],
  };
  const BLOCKED_DYNAMAX = ['zacian', 'zamazenta', 'eternatus'];

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------
  const api = window.pjGimmicks;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API Gimmicks n'est pas disponible : relance l'installateur puis redémarre Studio.");
    const r = await api[name](payload);
    if (!r || !r.ok) throw new Error((r && r.error) || 'Erreur inconnue');
    return r.value;
  };
  function h(tag, attrs, ...kids) {
    const el = document.createElement(tag);
    if (attrs) {
      for (const [k, v] of Object.entries(attrs)) {
        if (v === undefined || v === null || v === false) continue;
        if (k === 'class') el.className = v;
        else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
        else if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2).toLowerCase(), v);
        else if (k === 'value') el.value = v;
        else if (k === 'checked') el.checked = !!v;
        else if (k === 'selected') el.selected = !!v;
        else el.setAttribute(k, v === true ? '' : v);
      }
    }
    const add = (c) => {
      if (c === null || c === undefined || c === false) return;
      if (Array.isArray(c)) c.forEach(add);
      else el.appendChild(c instanceof Node ? c : document.createTextNode(String(c)));
    };
    kids.forEach(add);
    return el;
  }
  const clone = (o) => JSON.parse(JSON.stringify(o));
  let toastTimer = null;
  function toast(msg, err) {
    document.querySelectorAll('.pjs-toast').forEach((t) => t.remove());
    const t = h('div', { class: 'pjs-toast' + (err ? ' err' : '') }, msg);
    document.body.appendChild(t);
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.remove(), err ? 6000 : 2500);
  }
  const projectList = () => { try { return JSON.parse(localStorage.getItem('projectList') || '[]'); } catch (e) { return []; } };
  function projectUrl(rel) {
    const u = new URL(rel.split('/').map(encodeURIComponent).join('/'), window.__pjEventsProjectBase || 'project://--/');
    u.searchParams.append('projectPath', S.projectPath);
    return u.toString();
  }
  const select = (options, value, onchange, extra) => h('select', Object.assign({ class: 'pjs-input', onchange: (e) => onchange(e.target.value) }, extra || {}),
    options.map(([v, l]) => h('option', { value: v, selected: v === value }, l)));
  const check = (value, onchange, label, title) => h('label', { class: 'pjs-inline', title },
    h('input', { type: 'checkbox', checked: value, onchange: (e) => onchange(e.target.checked) }), label);

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const S = { open: false, projectPath: null, ctx: null, config: null, saved: null, error: null, page: 'mega', tabs: {}, sels: {}, filters: {}, query: '', tquery: '', tsel: null, building: false };
  let root = null;
  const snapshot = () => JSON.stringify(S.config);
  const dirty = () => S.config && S.saved !== snapshot();
  const creatureOf = (db) => S.ctx && S.ctx.creatures.find((c) => c.dbSymbol === db);
  const trainerOf = (db) => S.ctx && S.ctx.trainers.find((t) => t.dbSymbol === db);
  const speciesCfg = (db) => S.config.species[db] || {};
  function setSpecies(db, key, value) {
    const entry = Object.assign({}, S.config.species[db] || {});
    if (value === '' || value === false || value === null || value === undefined) delete entry[key]; else entry[key] = value;
    if (Object.keys(entry).length) S.config.species[db] = entry; else delete S.config.species[db];
    render();
  }
  function trainerCfg(db) {
    return S.config.trainers[db] || { keys: [], team: [] };
  }
  function setTrainer(db, fn) {
    const entry = clone(trainerCfg(db));
    entry.keys = entry.keys || [];
    entry.team = entry.team || [];
    fn(entry);
    entry.team = entry.team.map((slot) => {
      const s = Object.assign({}, slot || {});
      Object.keys(s).forEach((k) => { if (s[k] === '' || s[k] === false || s[k] === null) delete s[k]; });
      return s;
    });
    while (entry.team.length && !Object.keys(entry.team[entry.team.length - 1]).length) entry.team.pop();
    if (entry.keys.length || entry.team.length) S.config.trainers[db] = entry; else delete S.config.trainers[db];
    render();
  }

  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.ctx = null; S.config = null; S.error = null;
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath });
      const cfg = Object.assign(clone(DEFAULTS), S.ctx.config || {});
      cfg.enabled = Object.assign({}, DEFAULTS.enabled, cfg.enabled || {});
      cfg.species = cfg.species || {};
      cfg.trainers = cfg.trainers || {};
      S.config = cfg;
      S.saved = S.ctx.config ? snapshot() : null;
      if (!S.tsel || !trainerOf(S.tsel)) S.tsel = (S.ctx.trainers[0] || {}).dbSymbol || null;
    } catch (e) { S.error = e.message; }
    render();
  }

  async function save() {
    if (!S.config) return;
    try {
      const r = await call('save', { projectPath: S.projectPath, config: S.config });
      S.saved = snapshot();
      const p = r.plugin || {};
      if (p.source) S.ctx.plugin = { source: true, installed: p.installed, outdated: p.installed ? [] : ['?'], stale: [] };
      toast('Enregistré' + (p.source && !p.installed ? ' — plugin pas encore installé : lance construire_plugins.bat une fois' : ''));
      render();
      if (p.source && p.installed) rebuildPlugin();
    } catch (e) { toast('Erreur de sauvegarde : ' + e.message, true); }
  }

  async function rebuildPlugin() {
    if (S.building) return;
    S.building = true;
    updateStatus();
    try {
      const r = await call('buildPlugin', { projectPath: S.projectPath });
      if (!r.built) toast('Plugin non reconstruit : ' + (r.error || '?'), true);
    } catch (e) { toast('Plugin non reconstruit : ' + e.message, true); }
    S.building = false;
    updateStatus();
  }

  function statusText() {
    if (!S.config) return ['', ''];
    if (S.building) return ['Mise à jour du plugin…', ' busy'];
    if (dirty()) return ['Modifications non enregistrées', ' dirty'];
    return [S.saved ? 'Enregistré' : 'Réglages par défaut (pas encore enregistrés)', ''];
  }
  function updateStatus() {
    const el = root && root.querySelector('.pjs-status');
    if (!el) return;
    const [txt, cls] = statusText();
    el.textContent = txt;
    el.className = 'pjs-status' + cls;
  }

  // ---------------------------------------------------------------------------
  // Pages : Données > Gimmicks > Méga-gemmes / Capacités Z / Téracristal / Dynamax
  // ---------------------------------------------------------------------------
  const PAGES = { 'gimmicks-mega': 'mega', 'gimmicks-zmove': 'zmove', 'gimmicks-tera': 'tera', 'gimmicks-dynamax': 'dynamax' };
  const PAGE_INFO = {
    mega: { title: 'Méga-gemmes', tabs: [['settings', 'Réglages'], ['pokemon', 'Pokémon'], ['trainers', 'Dresseurs']] },
    zmove: { title: 'Capacités Z', tabs: [['settings', 'Réglages'], ['crystals', 'Cristaux Z'], ['trainers', 'Dresseurs']] },
    tera: { title: 'Téracristal', tabs: [['settings', 'Réglages'], ['pokemon', 'Pokémon'], ['trainers', 'Dresseurs']] },
    dynamax: { title: 'Dynamax', tabs: [['settings', 'Réglages'], ['pokemon', 'Pokémon'], ['trainers', 'Dresseurs']] },
  };
  const Z_TYPES = [['normalium_z', 'normal', 'breakneck_blitz'], ['fightinium_z', 'fighting', 'all_out_pummeling'], ['flyinium_z', 'flying', 'supersonic_skystrike'],
    ['poisonium_z', 'poison', 'acid_downpour'], ['groundium_z', 'ground', 'tectonic_rage'], ['rockium_z', 'rock', 'continental_crush'], ['buginium_z', 'bug', 'savage_spin_out'],
    ['ghostium_z', 'ghost', 'never_ending_nightmare'], ['steelium_z', 'steel', 'corkscrew_crash'], ['firium_z', 'fire', 'inferno_overdrive'], ['waterium_z', 'water', 'hydro_vortex'],
    ['grassium_z', 'grass', 'bloom_doom'], ['electrium_z', 'electric', 'gigavolt_havoc'], ['psychium_z', 'psychic', 'shattered_psyche'], ['icium_z', 'ice', 'subzero_slammer'],
    ['dragonium_z', 'dragon', 'devastating_drake'], ['darkinium_z', 'dark', 'black_hole_eclipse'], ['fairium_z', 'fairy', 'twinkle_tackle']];
  const KEY_ITEMS = { mega: 'mega_ring', zmove: 'z_ring', dynamax: 'dynamax_band', tera: 'tera_orb' };
  const gimmickLabel = (k) => (GIMMICKS.find((g) => g[0] === k) || [k, k])[1];
  const itemOf = (db) => (S.ctx && S.ctx.items && S.ctx.items[db]) || null;
  // textes d'objets décalés dans certains projets (cristaux Z nommés « DT92 »…) : nom de la version « <cristal>2 » à la place
  const FALLBACK_NAMES = { z_ring: 'Bracelet Z' };
  function itemName(db) {
    const n = (itemOf(db) || {}).name || db;
    if (!/^[CD]T\d+$/.test(n) || /^(tm|tr|hm)\d/.test(db)) return n;
    return FALLBACK_NAMES[db] || (itemOf(db + '2') || {}).name || db;
  }
  const moveName = (db) => ((S.ctx && S.ctx.moves && S.ctx.moves[db]) || {}).name || db;
  const isZCrystal = (db) => !!db && (Z_TYPES.some((z) => z[0] === db) || !!Z_EXCLUSIVE[db]);
  const megasOf = (c) => (c ? c.forms.flatMap((f) => f.mega) : []);
  const tabOf = () => S.tabs[S.page] || 'settings';
  function itemIcon(db) {
    const it = itemOf(db);
    return h('span', { class: 'pjg-itemicon', style: it && it.icon ? { backgroundImage: `url("${projectUrl(`graphics/icons/${it.icon}.png`)}")` } : null });
  }
  const itemChip = (db) => h('span', { class: 'pjg-chip pjg-chip-item', title: db }, itemIcon(db), itemName(db));

  function render() {
    if (!root) return;
    const scroll = root.querySelector('.pjs-page') ? root.querySelector('.pjs-page').scrollTop : 0;
    root.textContent = '';
    const info = PAGE_INFO[S.page] || PAGE_INFO.mega;
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    const [statusTxt, statusCls] = statusText();
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' },
        h('span', { class: 'pjs-top-title' }, info.title),
        h('div', { class: 'pjs-tabs' },
          info.tabs.map(([tab, label]) => h('button', {
            class: 'pjs-tab' + (tabOf() === tab ? ' active' : ''), onclick: () => { S.tabs[S.page] = tab; render(); },
          }, label))),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + statusCls }, statusTxt),
        h('button', { class: 'pjs-btn secondary', onclick: () => { if (!dirty() || confirm('Gimmicks : abandonner les modifications non enregistrées ?')) loadProject(S.projectPath); }, title: 'Relire les fichiers du projet' }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.config, title: 'Ctrl+S (les réglages des 4 pages sont enregistrés ensemble)' }, 'Enregistrer'))));
    const page = h('div', { class: 'pjs-page' });
    root.appendChild(page);
    if (S.error) { page.appendChild(h('div', { class: 'pjs-empty err' }, S.error)); return; }
    if (!S.config) { page.appendChild(h('div', { class: 'pjs-empty' }, 'Chargement…')); return; }
    const content = h('div', { class: 'pjs-content pjg-content' });
    page.appendChild(content);
    const p = S.ctx.plugin;
    if (p && !p.source) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le dossier scripts/gimmicks est introuvable.'));
    else if (p && !p.installed) content.appendChild(h('div', { class: 'pjs-warn' }, "Le plugin « gimmicks » n'est pas encore installé : lance construire_plugins.bat une fois (ensuite, Enregistrer le met à jour tout seul)."));
    const tab = tabOf();
    if (tab === 'pokemon') renderPokemon(content);
    else if (tab === 'trainers') renderTrainers(content);
    else if (tab === 'crystals') renderCrystals(content);
    else renderSettings(content);
    page.scrollTop = scroll;
  }

  const block = (title, ...kids) => h('div', { class: 'pjs-block' }, h('div', { class: 'pjs-block-head' }, h('h2', null, title)), kids);
  const field = (label, input, hint) => h('div', { class: 'pjg-field' }, h('div', { class: 'pjg-label' }, label), input, hint ? h('div', { class: 'pjs-hint' }, hint) : null);
  const num = (value, min, max, onchange, extra) => h('input', Object.assign({ class: 'pjs-input pjg-num', type: 'number', min, max, value, onchange: (e) => onchange(e.target.value) }, extra || {}));

  // --- Réglages -----------------------------------------------------------------
  function renderSettings(content) {
    const c = S.config;
    const k = S.page;
    const g = GIMMICKS.find((x) => x[0] === k);
    content.appendChild(block(g[1],
      h('div', { class: 'pjg-card pjg-card-wide' + (c.enabled[k] ? ' on' : '') },
        check(c.enabled[k], (v) => { c.enabled[k] = v; render(); }, 'Utilisable en combat dès le début de la partie'),
        h('div', { class: 'pjs-hint' }, g[2])),
      h('div', { class: 'pjs-hint' }, "Décoché : la commande d'évènement « Activer / désactiver une mécanique » l'active en cours de partie.")));
    if (k === 'mega') {
      const keys = Object.entries(S.ctx.items || {}).filter(([, it]) => it.megaKey).map(([db]) => db);
      content.appendChild(block('Objets clés',
        keys.length ? h('div', { class: 'pjg-chips' }, keys.map(itemChip)) : h('span', { class: 'pjs-hint' }, 'Aucun objet « Permet la méga-évolution ».'),
        h('div', { class: 'pjs-hint' }, 'Un seul de ces objets dans le sac suffit (Studio : Objets > case « Permet la méga-évolution »). Le Pokémon tient sa méga-gemme (onglet Pokémon).')));
    } else if (k === 'zmove') {
      content.appendChild(block('Objets clés', h('div', { class: 'pjg-chips' }, ['z_ring', 'z_power_ring'].filter(itemOf).map(itemChip)),
        h('div', { class: 'pjs-hint' }, 'Le Pokémon tient un cristal Z (onglet Cristaux Z) et le garde après usage. Une capacité Z utilise un PP de l’attaque de départ.')));
    } else if (k === 'tera') {
      content.appendChild(block('Orbe Téracristal',
        itemOf('tera_orb') ? h('div', { class: 'pjg-chips' }, itemChip('tera_orb')) : null,
        field('Recharge', check(c.tera_orb_recharge, (v) => { c.tera_orb_recharge = v; render(); }, 'Se vide après usage, se recharge quand l’équipe est soignée (centre Pokémon)'))));
    } else if (k === 'dynamax') {
      content.appendChild(block('Dynamax / Gigamax',
        itemOf('dynamax_band') ? h('div', { class: 'pjg-chips pjg-mb' }, itemChip('dynamax_band')) : null,
        field('Durée', num(c.dynamax_turns, 1, 10, (v) => { c.dynamax_turns = Math.max(1, Math.min(10, +v || 3)); render(); }), 'Tours (3 dans les jeux).'),
        field('Niveau Dynamax de base', num(c.dynamax_level, 0, 10, (v) => { c.dynamax_level = Math.max(0, Math.min(10, +v || 0)); render(); }),
          'PV x (1,5 + 0,05 x niveau). Pour les Pokémon qui n’ont pas reçu de niveau (commande « Niveau Dynamax »).'),
        field('Facteur Gigamax', h('div', { class: 'pjg-checks' }, h('span', null, '1 chance sur'),
          num(c.gmax_rate || 0, 0, 100000, (v) => { c.gmax_rate = Math.max(0, Math.round(+v || 0)); render(); }),
          h('span', { class: 'pjs-hint' }, c.gmax_rate > 0 ? `(${(100 / c.gmax_rate).toFixed(c.gmax_rate > 100 ? 2 : 1)} %)` : '(jamais)')),
          'Chance qu’un nouveau Pokémon (sauvage, œuf, donné…) qui a une forme Gigamax naisse avec le facteur Gigamax. 0 : jamais. Taux propre à une espèce : onglet Pokémon.')));
    }
    content.appendChild(block('Commun aux quatre mécaniques',
      field('Cinématique', check(c.cinematic, (v) => { c.cinematic = v; render(); }, 'Zoom sur le Pokémon et son dresseur pendant la transformation (A ou B la passe)')),
      field('Dresseurs adverses', check(c.ai, (v) => { c.ai = v; render(); }, 'Ils utilisent les mécaniques (il leur faut l’objet clé : onglet Dresseurs)')),
      field('Chance par tour', num(Math.round(c.ai_chance * 100), 0, 100, (v) => { c.ai_chance = Math.max(0, Math.min(100, +v || 0)) / 100; render(); }),
        'En % : chance qu’un dresseur utilise une mécanique possible à un tour. Toujours avec son dernier Pokémon.'),
      h('div', { class: 'pjs-hint' }, 'Règles : chaque mécanique une fois par combat et par dresseur ; un Pokémon qui en utilise une ne peut plus utiliser les autres jusqu’à la fin du combat. '
        + 'En combat, Y fait défiler les mécaniques possibles (onglet « ACTION » au-dessus des attaques).')));
  }

  // --- Pokémon --------------------------------------------------------------------
  function iconStyle(c, form) {
    const f = (form !== undefined && c.forms.find((x) => x.form === form)) || c.forms[0];
    return f && f.icon ? { backgroundImage: `url("${projectUrl(`graphics/pokedex/pokeicon/${f.icon}.png`)}")` } : null;
  }
  function speciesTags(c) {
    const cfg = speciesCfg(c.dbSymbol);
    const tags = [];
    if (S.page === 'mega') { const n = megasOf(c).length; if (n) tags.push(n > 1 ? `${n} Méga` : 'Méga'); }
    if (S.page === 'tera' && cfg.tera) tags.push(typeName(cfg.tera));
    if (S.page === 'dynamax') {
      if (cfg.gmax) tags.push('G-Max');
      else if (cfg.gmax_rate !== undefined) tags.push(cfg.gmax_rate > 0 ? `G-Max 1/${cfg.gmax_rate}` : 'sans G-Max');
      else if (c.gmax) tags.push('forme G-Max');
      if (cfg.no_dynamax || BLOCKED_DYNAMAX.includes(c.dbSymbol)) tags.push('sans Dynamax');
    }
    return tags;
  }
  function speciesFilter(c) {
    const f = S.filters[S.page];
    if (S.page === 'mega') return f === 'all' || megasOf(c).length > 0;
    if (S.page === 'dynamax' && f === 'gmax') return c.gmax;
    if (S.page === 'tera' && f === 'set') return !!speciesCfg(c.dbSymbol).tera;
    return true;
  }
  const FILTERS = {
    mega: [['', 'Avec Méga-Évolution'], ['all', 'Tous les Pokémon']],
    tera: [['', 'Tous les Pokémon'], ['set', 'Type Téra choisi']],
    dynamax: [['', 'Tous les Pokémon'], ['gmax', 'Avec forme Gigamax']],
  };
  function renderPokemon(content) {
    const row = h('div', { class: 'pjs-row pjg-row' });
    content.appendChild(row);
    const list = h('div', { class: 'pjg-list' });
    const search = h('input', { class: 'pjs-input', placeholder: 'n°, nom ou symbole', value: S.query });
    search.addEventListener('input', () => { S.query = search.value; fill(); });
    const count = h('span', { class: 'pjs-count' });
    row.appendChild(h('div', { class: 'pjs-block pjg-list-block' }, h('div', { class: 'pjs-block-head' }, h('h2', null, 'Pokémon'), count),
      select(FILTERS[S.page], S.filters[S.page] || '', (v) => { S.filters[S.page] = v; render(); }, { class: 'pjs-input pjg-filter' }), search, list));
    const shown = S.ctx.creatures.filter((c) => c.id > 0 && speciesFilter(c));
    let sel = S.sels[S.page];
    if (!shown.some((c) => c.dbSymbol === sel)) sel = S.sels[S.page] = (shown[0] || {}).dbSymbol || null;
    count.textContent = String(shown.length);
    function fill() {
      list.textContent = '';
      const q = S.query.trim().toLowerCase();
      shown.filter((c) => !q || String(c.id) === q.replace(/^0+/, '') || c.name.toLowerCase().includes(q) || c.dbSymbol.includes(q)).slice(0, 400).forEach((c) => {
        list.appendChild(h('div', { class: 'pjs-item pjg-item' + (sel === c.dbSymbol ? ' active' : ''), onclick: () => { S.sels[S.page] = c.dbSymbol; render(); } },
          h('span', { class: 'pjg-mini', style: iconStyle(c) }), h('span', { class: 'pjg-num' }, String(c.id).padStart(3, '0')), h('span', { class: 'pjg-name' }, c.name),
          speciesTags(c).map((t) => h('span', { class: 'pjg-tag' }, t))));
      });
      if (!list.firstChild) list.appendChild(h('div', { class: 'pjs-hint pjg-pad' }, 'Aucun Pokémon.'));
    }
    fill();
    const c = creatureOf(sel);
    const editor = h('div', { class: 'pjs-block pjg-editor' });
    row.appendChild(editor);
    if (!c) { editor.appendChild(h('div', { class: 'pjs-empty' }, S.page === 'mega' ? 'Aucun Pokémon n’a de Méga-Évolution (Studio : Pokémon > Évolutions, condition « méga-gemme »).' : 'Choisis un Pokémon.')); return; }
    const cfg = speciesCfg(c.dbSymbol);
    const base = c.forms.find((f) => f.form === 0) || c.forms[0] || { types: [] };
    editor.appendChild(h('div', { class: 'pjs-block-head pjg-head' }, h('span', { class: 'pjg-mini big', style: iconStyle(c) }), h('h2', null, c.name), h('span', { class: 'pjs-hint' }, c.dbSymbol)));
    if (S.page === 'mega') {
      const megas = megasOf(c);
      editor.appendChild(field('Méga-Évolutions', megas.length
        ? h('div', { class: 'pjg-megas' }, megas.map((m) => {
          const f = c.forms.find((x) => x.form === m.form);
          return h('div', { class: 'pjg-mega' }, h('span', { class: 'pjg-mini big', style: iconStyle(c, m.form) }),
            h('div', { class: 'pjg-mega-txt' }, h('b', null, (f && f.name) || `Forme ${m.form}`), h('span', { class: 'pjs-hint' }, `forme ${m.form}${f && f.types.length ? ' · ' + f.types.map(typeName).join(' / ') : ''}`)),
            h('span', { class: 'pjg-arrow' }, '←'), itemChip(m.item));
        }))
        : h('span', { class: 'pjs-hint' }, 'Aucune.'),
        'Méga-gemme tenue + objet clé dans le sac. Pour en ajouter : Studio, Pokémon > Évolutions, condition « méga-gemme » vers la forme méga.'));
      const holders = S.ctx.trainers.filter((t) => t.party.some((p) => p.specie === c.dbSymbol));
      if (holders.length) {
        editor.appendChild(field('Dans les équipes des dresseurs', h('div', { class: 'pjg-chips' }, holders.map((t) => {
          const p = t.party.find((x) => x.specie === c.dbSymbol);
          const ok = megas.some((m) => m.item === p.item);
          return h('span', { class: 'pjg-chip' + (ok ? ' ok' : ''), title: p.item ? 'Tient : ' + itemName(p.item) : 'Ne tient rien' }, `${t.klass ? t.klass + ' ' : ''}${t.name}${ok ? ' ✓' : ''}`);
        })), '✓ : le Pokémon tient sa méga-gemme.'));
      }
    } else if (S.page === 'tera') {
      editor.appendChild(field('Type Téra par défaut',
        select([['', `Au hasard parmi ses types (${base.types.map(typeName).join(' / ')})`], ...TERA_TYPES], cfg.tera || '', (v) => setSpecies(c.dbSymbol, 'tera', v)),
        'Donné à chaque nouveau Pokémon de cette espèce. La commande « Changer le type Téra » le change pour un Pokémon de l’équipe ; l’onglet Dresseurs pour l’équipe d’un dresseur.'));
    } else if (S.page === 'dynamax') {
      const blocked = BLOCKED_DYNAMAX.includes(c.dbSymbol);
      editor.appendChild(field('Dynamax',
        h('div', { class: 'pjg-checks' },
          blocked ? h('span', { class: 'pjs-hint' }, 'Ne peut jamais se Dynamaxer (comme dans les jeux).') : check(!!cfg.no_dynamax, (v) => setSpecies(c.dbSymbol, 'no_dynamax', v), 'Ne peut pas se Dynamaxer'))));
      editor.appendChild(field('Gigamax', c.gmax
        ? h('div', { class: 'pjg-checks' }, h('span', { class: 'pjg-mini big', style: iconStyle(c, 40) }),
          check(!!cfg.gmax, (v) => setSpecies(c.dbSymbol, 'gmax', v), 'Toujours avec le facteur Gigamax', 'Sinon : commande « Facteur Gigamax » ou onglet Dresseurs'))
        : h('span', { class: 'pjs-hint' }, 'Pas de forme Gigamax (forme 40).')));
      if (c.gmax && !cfg.gmax) {
        editor.appendChild(field('Taux du facteur Gigamax', h('div', { class: 'pjg-checks' }, h('span', null, '1 chance sur'),
          num(cfg.gmax_rate ?? '', 0, 100000, (v) => setSpecies(c.dbSymbol, 'gmax_rate', v === '' ? '' : Math.max(0, Math.round(+v))), { placeholder: String(S.config.gmax_rate || 0) })),
          `Vide : taux général (${S.config.gmax_rate > 0 ? '1 sur ' + S.config.gmax_rate : 'jamais'}, onglet Réglages). 0 : jamais pour cette espèce.`));
      }
    }
  }

  // --- Cristaux Z -------------------------------------------------------------------
  function renderCrystals(content) {
    const table = h('div', { class: 'pjg-ztable' });
    table.appendChild(h('div', { class: 'pjg-zrow head' }, h('span', null, 'Cristal'), h('span', null, 'Type'), h('span', null, 'Capacité Z')));
    Z_TYPES.forEach(([item, type, z]) => table.appendChild(h('div', { class: 'pjg-zrow' + (itemOf(item) ? '' : ' missing') },
      itemChip(item), h('span', null, typeName(type)), h('span', { title: z }, moveName(z)))));
    content.appendChild(block('Cristaux de type', table,
      h('div', { class: 'pjs-hint' }, 'Une attaque offensive du type devient la capacité Z du type (puissance selon la puissance de base, même catégorie) ; une attaque de statut reçoit un bonus Z puis s’utilise.')));
    const ex = h('div', { class: 'pjg-ztable ex' });
    ex.appendChild(h('div', { class: 'pjg-zrow head' }, h('span', null, 'Cristal'), h('span', null, 'Pokémon'), h('span', null, 'Attaque'), h('span', null, 'Capacité Z')));
    Object.entries(Z_EXCLUSIVE).forEach(([item, [species, move, z]]) => ex.appendChild(h('div', { class: 'pjg-zrow' + (itemOf(item) ? '' : ' missing') },
      itemChip(item),
      h('span', { class: 'pjg-zpokes' }, species.map((sp) => { const c = creatureOf(sp); return h('span', { class: 'pjg-zpoke', title: sp }, c ? h('span', { class: 'pjg-mini', style: iconStyle(c) }) : null, c ? c.name : sp); })),
      h('span', { title: move }, moveName(move)), h('span', { title: z }, moveName(z)))));
    content.appendChild(block('Cristaux exclusifs', ex,
      h('div', { class: 'pjs-hint' }, 'L’attaque précise du Pokémon précis devient sa capacité Z exclusive. Necrozma Crinière du Couchant / Ailes de l’Aurore avec l’Ultranecrozium Z : Ultra-Explosion au début du tour.')));
  }

  // --- Dresseurs ----------------------------------------------------------------------
  function renderTrainers(content) {
    const k = S.page;
    const row = h('div', { class: 'pjs-row pjg-row' });
    content.appendChild(row);
    const list = h('div', { class: 'pjg-list' });
    const search = h('input', { class: 'pjs-input', placeholder: 'n°, nom ou symbole', value: S.tquery });
    search.addEventListener('input', () => { S.tquery = search.value; fill(); });
    const hasKey = (t) => (trainerCfg(t.dbSymbol).keys || []).includes(k) || inBag(t);
    const inBag = (t) => (k === 'mega' ? t.bag.some((b) => (itemOf(b) || {}).megaKey || /mega_ring|mega_bracelet|key_stone/.test(b)) : t.bag.includes(KEY_ITEMS[k]) || (k === 'zmove' && t.bag.includes('z_power_ring')));
    row.appendChild(h('div', { class: 'pjs-block pjg-list-block' }, h('div', { class: 'pjs-block-head' }, h('h2', null, 'Dresseurs'),
      h('span', { class: 'pjs-count', title: `Dresseurs qui peuvent utiliser : ${gimmickLabel(k)}` }, String(S.ctx.trainers.filter(hasKey).length))), search, list));
    function fill() {
      list.textContent = '';
      const q = S.tquery.trim().toLowerCase();
      S.ctx.trainers.filter((t) => !q || String(t.id) === q || t.name.toLowerCase().includes(q) || t.klass.toLowerCase().includes(q) || t.dbSymbol.includes(q)).forEach((t) => {
        list.appendChild(h('div', { class: 'pjs-item pjg-item' + (S.tsel === t.dbSymbol ? ' active' : ''), onclick: () => { S.tsel = t.dbSymbol; render(); } },
          h('span', { class: 'pjg-num' }, String(t.id).padStart(3, '0')), h('span', { class: 'pjg-name' }, `${t.klass ? t.klass + ' ' : ''}${t.name}`),
          hasKey(t) ? h('span', { class: 'pjg-tag' }, '✓') : null));
      });
    }
    fill();
    const t = trainerOf(S.tsel);
    const editor = h('div', { class: 'pjs-block pjg-editor' });
    row.appendChild(editor);
    if (!t) { editor.appendChild(h('div', { class: 'pjs-empty' }, 'Choisis un dresseur.')); return; }
    const cfg = trainerCfg(t.dbSymbol);
    editor.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, `${t.klass ? t.klass + ' ' : ''}${t.name}`), h('span', { class: 'pjs-hint' }, t.dbSymbol)));
    const bag = inBag(t);
    editor.appendChild(field('Objet clé', check((cfg.keys || []).includes(k) || bag, (v) => setTrainer(t.dbSymbol, (e) => { e.keys = e.keys.filter((x) => x !== k); if (v) e.keys.push(k); }),
      `Peut utiliser : ${gimmickLabel(k)}` + (bag ? ' (objet déjà dans son sac)' : ''), `Donne ${KEY_ITEMS[k]} au dresseur pendant le combat`),
      k === 'mega' || k === 'zmove' ? 'Le dresseur reçoit l’objet clé pendant le combat. Ses Pokémon doivent aussi tenir leur ' + (k === 'mega' ? 'méga-gemme' : 'cristal Z') + ' (Studio : Dresseurs > équipe > objet tenu).'
        : 'Le dresseur reçoit l’objet clé pendant le combat.'));
    const cols = { mega: ['Objet tenu', 'Méga-Évolution'], zmove: ['Objet tenu', 'Cristal Z'], tera: ['Type Téra'], dynamax: ['Gigamax', 'Niveau Dynamax'] }[k];
    const table = h('div', { class: 'pjg-team c' + (cols.length + 1) });
    table.appendChild(h('div', { class: 'pjg-team-row head' }, h('span', null, 'Pokémon'), cols.map((x) => h('span', null, x))));
    t.party.forEach((p, i) => {
      const slot = (cfg.team || [])[i] || {};
      const c = creatureOf(p.specie);
      const setSlot = (key, value) => setTrainer(t.dbSymbol, (e) => { while (e.team.length <= i) e.team.push({}); e.team[i] = Object.assign({}, e.team[i], { [key]: value }); });
      const base = c && (c.forms.find((f) => f.form === p.form) || c.forms[0]);
      const cells = [];
      if (k === 'mega' || k === 'zmove') {
        cells.push(p.item ? itemChip(p.item) : h('span', { class: 'pjs-hint' }, 'rien'));
        if (k === 'mega') {
          const megas = megasOf(c);
          const m = megas.find((x) => x.item === p.item);
          const f = m && c.forms.find((x) => x.form === m.form);
          cells.push(m ? h('span', { class: 'pjg-ok' }, '✓ ' + ((f && f.name) || 'forme ' + m.form)) : h('span', { class: 'pjs-hint' }, megas.length ? 'Tient pas sa méga-gemme (' + megas.map((x) => itemName(x.item)).join(', ') + ')' : '—'));
        } else cells.push(isZCrystal(p.item) ? h('span', { class: 'pjg-ok' }, '✓') : h('span', { class: 'pjs-hint' }, '—'));
      } else if (k === 'tera') {
        cells.push(select([['', `Par défaut${base ? ' (' + base.types.map(typeName).join(' / ') + ')' : ''}`], ...TERA_TYPES], slot.tera || '', (v) => setSlot('tera', v)));
      } else {
        cells.push(c && c.gmax ? h('input', { type: 'checkbox', checked: !!slot.gmax, onchange: (e) => setSlot('gmax', e.target.checked) }) : h('span', { class: 'pjs-hint' }, '—'));
        cells.push(num(slot.dynamax_level ?? '', 0, 10, (v) => setSlot('dynamax_level', v === '' ? '' : Math.max(0, Math.min(10, +v))), { placeholder: String(S.config.dynamax_level) }));
      }
      table.appendChild(h('div', { class: 'pjg-team-row' },
        h('span', { class: 'pjg-team-poke' }, c ? h('span', { class: 'pjg-mini', style: iconStyle(c, p.form) }) : null, `${c ? c.name : p.specie} N.${p.level}`), cells));
    });
    editor.appendChild(field('Équipe', t.party.length ? table : h('span', { class: 'pjs-hint' }, 'Équipe vide.')));
  }


  function mount(hostEl, pageKey) {
    root = h('div', { id: 'pjg-root' });
    ['keydown', 'keypress', 'keyup'].forEach((type) => root.addEventListener(type, (e) => e.stopPropagation()));
    hostEl.appendChild(root);
    S.open = true;
    S.page = pageKey;
    const latest = projectList()[0] && projectList()[0].projectPath;
    if (!S.config || (latest && latest !== S.projectPath && !dirty())) loadProject(latest || null); else render();
  }
  function checkPage() {
    let found = null;
    for (const id of Object.keys(PAGES)) { const el = document.getElementById('pj-page-' + id); if (el) { found = [el, PAGES[id]]; break; } }
    if (root && found && found[0].contains(root) && found[1] === S.page) return;
    if (root && root.parentNode) root.remove();
    if (root) { root = null; S.open = false; }
    if (found) mount(found[0], found[1]);
  }
  let scheduled = false;
  const observer = new MutationObserver(() => { if (!scheduled) { scheduled = true; requestAnimationFrame(() => { scheduled = false; checkPage(); }); } });
  const start = () => { observer.observe(document.body, { childList: true, subtree: true }); checkPage(); };
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);

  window.addEventListener('keydown', (e) => {
    if (!S.open) return;
    if (e.ctrlKey && e.key.toLowerCase() === 's') { e.preventDefault(); e.stopPropagation(); save(); }
  }, true);
  setInterval(() => { if (S.open) updateStatus(); }, 1000);

  window.pjGimmicksEditor = { state: S, render };
})();
