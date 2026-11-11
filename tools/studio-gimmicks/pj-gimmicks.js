/* eslint-disable */
// =============================================================================
// Gimmicks — page « Plugins > Gimmicks » de Pokémon Studio (plugin « gimmicks »)
//   Réglages : mécaniques actives, cinématique, dresseurs adverses, Dynamax, Orbe Téracristal
//   Pokémon  : type Téra par défaut, facteur Gigamax d'office, Dynamax interdit (+ méga-gemmes et capacité Z exclusive)
//   Dresseurs: mécaniques que chaque dresseur peut utiliser, type Téra / Gigamax / niveau Dynamax de son équipe
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
  const S = { open: false, projectPath: null, ctx: null, config: null, saved: null, error: null, tab: 'settings', query: '', tquery: '', sel: null, tsel: null, building: false };
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
      if (!S.sel || !creatureOf(S.sel)) S.sel = (S.ctx.creatures.find((c) => c.id > 0) || {}).dbSymbol || null;
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
  // Rendu
  // ---------------------------------------------------------------------------
  function render() {
    if (!root) return;
    const scroll = root.querySelector('.pjs-page') ? root.querySelector('.pjs-page').scrollTop : 0;
    root.textContent = '';
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    const [statusTxt, statusCls] = statusText();
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' },
        h('span', { class: 'pjs-top-title' }, 'Gimmicks'),
        h('div', { class: 'pjs-tabs' },
          [['settings', 'Réglages'], ['pokemon', 'Pokémon'], ['trainers', 'Dresseurs']].map(([tab, label]) => h('button', {
            class: 'pjs-tab' + (S.tab === tab ? ' active' : ''), onclick: () => { S.tab = tab; render(); },
          }, label))),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + statusCls }, statusTxt),
        h('button', { class: 'pjs-btn secondary', onclick: () => { if (!dirty() || confirm('Gimmicks : abandonner les modifications non enregistrées ?')) loadProject(S.projectPath); }, title: 'Relire les fichiers du projet' }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.config, title: 'Ctrl+S' }, 'Enregistrer'))));
    const page = h('div', { class: 'pjs-page' });
    root.appendChild(page);
    if (S.error) { page.appendChild(h('div', { class: 'pjs-empty err' }, S.error)); return; }
    if (!S.config) { page.appendChild(h('div', { class: 'pjs-empty' }, 'Chargement…')); return; }
    const content = h('div', { class: 'pjs-content pjg-content' });
    page.appendChild(content);
    const p = S.ctx.plugin;
    if (p && !p.source) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le dossier scripts/gimmicks est introuvable.'));
    else if (p && !p.installed) content.appendChild(h('div', { class: 'pjs-warn' }, "Le plugin « gimmicks » n'est pas encore installé : lance construire_plugins.bat une fois (ensuite, Enregistrer le met à jour tout seul)."));
    if (S.tab === 'pokemon') renderPokemon(content);
    else if (S.tab === 'trainers') renderTrainers(content);
    else renderSettings(content);
    page.scrollTop = scroll;
  }

  const block = (title, ...kids) => h('div', { class: 'pjs-block' }, h('div', { class: 'pjs-block-head' }, h('h2', null, title)), kids);
  const field = (label, input, hint) => h('div', { class: 'pjg-field' }, h('div', { class: 'pjg-label' }, label), input, hint ? h('div', { class: 'pjs-hint' }, hint) : null);

  // --- Réglages ---------------------------------------------------------------
  function renderSettings(content) {
    const c = S.config;
    content.appendChild(block('Mécaniques',
      h('div', { class: 'pjg-cards' }, GIMMICKS.map(([k, label, hint]) => h('div', { class: 'pjg-card' + (c.enabled[k] ? ' on' : '') },
        check(c.enabled[k], (v) => { c.enabled[k] = v; render(); }, label),
        h('div', { class: 'pjs-hint' }, hint)))),
      h('div', { class: 'pjs-hint' }, "Mécanique décochée : impossible en combat au début de la partie (la commande d'évènement « Activer / désactiver une mécanique » la change en cours de partie). "
        + 'Règles : chaque mécanique une fois par combat et par dresseur ; un Pokémon qui en utilise une ne peut plus utiliser les autres jusqu’à la fin du combat. '
        + 'En combat, Y fait défiler les mécaniques possibles (onglet « ACTION » au-dessus des attaques).')));
    content.appendChild(block('Combat',
      field('Cinématique', check(c.cinematic, (v) => { c.cinematic = v; render(); }, 'Zoom sur le Pokémon et son dresseur pendant la transformation (A ou B la passe)')),
      field('Dresseurs adverses', check(c.ai, (v) => { c.ai = v; render(); }, 'Ils utilisent les mécaniques (il leur faut l’objet clé : onglet Dresseurs)')),
      field('Chance par tour', h('input', { class: 'pjs-input pjg-num', type: 'number', min: 0, max: 100, value: Math.round(c.ai_chance * 100), onchange: (e) => { c.ai_chance = Math.max(0, Math.min(100, +e.target.value || 0)) / 100; render(); } }),
        'En % : chance qu’un dresseur utilise une mécanique possible à un tour. Toujours avec son dernier Pokémon.')));
    content.appendChild(block('Dynamax',
      field('Durée', h('input', { class: 'pjs-input pjg-num', type: 'number', min: 1, max: 10, value: c.dynamax_turns, onchange: (e) => { c.dynamax_turns = Math.max(1, Math.min(10, +e.target.value || 3)); render(); } }), 'Tours (3 dans les jeux).'),
      field('Niveau Dynamax de base', h('input', { class: 'pjs-input pjg-num', type: 'number', min: 0, max: 10, value: c.dynamax_level, onchange: (e) => { c.dynamax_level = Math.max(0, Math.min(10, +e.target.value || 0)); render(); } }),
        'PV x (1,5 + 0,05 x niveau). Pour les Pokémon qui n’ont pas reçu de niveau (commande « Niveau Dynamax »).')));
    content.appendChild(block('Téracristal',
      field('Orbe Téracristal', check(c.tera_orb_recharge, (v) => { c.tera_orb_recharge = v; render(); }, 'Se vide après usage, se recharge quand l’équipe est soignée (centre Pokémon)'))));
  }

  // --- Pokémon ----------------------------------------------------------------
  function iconStyle(c) {
    const f = c.forms[0];
    return f && f.icon ? { backgroundImage: `url("${projectUrl(`graphics/pokedex/pokeicon/${f.icon}.png`)}")` } : null;
  }
  function renderPokemon(content) {
    const row = h('div', { class: 'pjs-row pjg-row' });
    content.appendChild(row);
    const list = h('div', { class: 'pjg-list' });
    const search = h('input', { class: 'pjs-input', placeholder: 'n°, nom ou symbole', value: S.query });
    search.addEventListener('input', () => { S.query = search.value; fill(); });
    row.appendChild(h('div', { class: 'pjs-block pjg-list-block' }, h('div', { class: 'pjs-block-head' }, h('h2', null, 'Pokémon'),
      h('span', { class: 'pjs-count', title: 'Pokémon réglés' }, String(Object.keys(S.config.species).length))), search, list));
    function fill() {
      list.textContent = '';
      const q = S.query.trim().toLowerCase();
      S.ctx.creatures.filter((c) => !q || String(c.id) === q.replace(/^0+/, '') || c.name.toLowerCase().includes(q) || c.dbSymbol.includes(q)).slice(0, 400).forEach((c) => {
        const cfg = speciesCfg(c.dbSymbol);
        const tags = [];
        if (cfg.tera) tags.push(typeName(cfg.tera));
        if (cfg.gmax) tags.push('G-Max');
        if (cfg.no_dynamax) tags.push('sans Dynamax');
        list.appendChild(h('div', { class: 'pjs-item pjg-item' + (S.sel === c.dbSymbol ? ' active' : ''), onclick: () => { S.sel = c.dbSymbol; render(); } },
          h('span', { class: 'pjg-mini', style: iconStyle(c) }), h('span', { class: 'pjg-num' }, String(c.id).padStart(3, '0')), h('span', { class: 'pjg-name' }, c.name),
          tags.map((t) => h('span', { class: 'pjg-tag' }, t))));
      });
    }
    fill();
    const c = creatureOf(S.sel);
    const editor = h('div', { class: 'pjs-block pjg-editor' });
    row.appendChild(editor);
    if (!c) { editor.appendChild(h('div', { class: 'pjs-empty' }, 'Choisis un Pokémon.')); return; }
    const cfg = speciesCfg(c.dbSymbol);
    const base = c.forms.find((f) => f.form === 0) || c.forms[0] || { types: [] };
    editor.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, `${c.name}`), h('span', { class: 'pjs-hint' }, c.dbSymbol)));
    editor.appendChild(field('Type Téra par défaut',
      select([['', `Au hasard parmi ses types (${base.types.map(typeName).join(' / ')})`], ...TERA_TYPES], cfg.tera || '', (v) => setSpecies(c.dbSymbol, 'tera', v)),
      'Donné à chaque nouveau Pokémon de cette espèce. La commande « Changer le type Téra » le change pour un Pokémon de l’équipe ; l’onglet Dresseurs pour l’équipe d’un dresseur.'));
    const blocked = BLOCKED_DYNAMAX.includes(c.dbSymbol);
    editor.appendChild(field('Dynamax',
      h('div', { class: 'pjg-checks' },
        c.gmax ? check(!!cfg.gmax, (v) => setSpecies(c.dbSymbol, 'gmax', v), 'Toujours avec le facteur Gigamax', 'Sinon : commande « Facteur Gigamax » ou onglet Dresseurs') : h('span', { class: 'pjs-hint' }, 'Pas de forme Gigamax (forme 40).'),
        blocked ? h('span', { class: 'pjs-hint' }, 'Ne peut jamais se Dynamaxer (comme dans les jeux).') : check(!!cfg.no_dynamax, (v) => setSpecies(c.dbSymbol, 'no_dynamax', v), 'Ne peut pas se Dynamaxer'))));
    const megas = c.forms.flatMap((f) => f.mega);
    editor.appendChild(field('Méga-Évolution', megas.length
      ? h('div', { class: 'pjg-chips' }, megas.map((m) => { const f = c.forms.find((x) => x.form === m.form); return h('span', { class: 'pjg-chip' }, `${(f && f.name) || 'forme ' + m.form} ← ${m.item}`); }))
      : h('span', { class: 'pjs-hint' }, 'Aucune (Studio : Pokémon > Évolutions, condition « méga-gemme »).')));
    const zs = Object.entries(Z_EXCLUSIVE).filter(([, [sp]]) => sp.includes(c.dbSymbol));
    editor.appendChild(field('Capacité Z exclusive', zs.length
      ? h('div', { class: 'pjg-chips' }, zs.map(([item, [, move, z]]) => h('span', { class: 'pjg-chip' }, `${item} : ${move} → ${z}`)))
      : h('span', { class: 'pjs-hint' }, `Aucune ; avec un cristal de type, ses attaques de ce type deviennent la capacité Z du type.`)));
  }

  // --- Dresseurs ----------------------------------------------------------------
  function renderTrainers(content) {
    const row = h('div', { class: 'pjs-row pjg-row' });
    content.appendChild(row);
    const list = h('div', { class: 'pjg-list' });
    const search = h('input', { class: 'pjs-input', placeholder: 'n°, nom ou symbole', value: S.tquery });
    search.addEventListener('input', () => { S.tquery = search.value; fill(); });
    row.appendChild(h('div', { class: 'pjs-block pjg-list-block' }, h('div', { class: 'pjs-block-head' }, h('h2', null, 'Dresseurs'),
      h('span', { class: 'pjs-count', title: 'Dresseurs réglés' }, String(Object.keys(S.config.trainers).length))), search, list));
    function fill() {
      list.textContent = '';
      const q = S.tquery.trim().toLowerCase();
      S.ctx.trainers.filter((t) => !q || String(t.id) === q || t.name.toLowerCase().includes(q) || t.klass.toLowerCase().includes(q) || t.dbSymbol.includes(q)).forEach((t) => {
        const cfg = trainerCfg(t.dbSymbol);
        list.appendChild(h('div', { class: 'pjs-item pjg-item' + (S.tsel === t.dbSymbol ? ' active' : ''), onclick: () => { S.tsel = t.dbSymbol; render(); } },
          h('span', { class: 'pjg-num' }, String(t.id).padStart(3, '0')), h('span', { class: 'pjg-name' }, `${t.klass ? t.klass + ' ' : ''}${t.name}`),
          (cfg.keys || []).map((k) => h('span', { class: 'pjg-tag' }, ({ mega: 'Méga', zmove: 'Z', dynamax: 'Dyna', tera: 'Téra' })[k]))));
      });
    }
    fill();
    const t = trainerOf(S.tsel);
    const editor = h('div', { class: 'pjs-block pjg-editor' });
    row.appendChild(editor);
    if (!t) { editor.appendChild(h('div', { class: 'pjs-empty' }, 'Choisis un dresseur.')); return; }
    const cfg = trainerCfg(t.dbSymbol);
    editor.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, `${t.klass ? t.klass + ' ' : ''}${t.name}`), h('span', { class: 'pjs-hint' }, t.dbSymbol)));
    const KEY_ITEMS = { mega: 'mega_ring', zmove: 'z_ring', dynamax: 'dynamax_band', tera: 'tera_orb' };
    editor.appendChild(field('Peut utiliser', h('div', { class: 'pjg-checks' }, GIMMICKS.map(([k, label]) => {
      const inBag = k === 'mega' ? t.bag.some((b) => /mega_ring|mega_bracelet|key_stone|mega/.test(b)) : t.bag.includes(KEY_ITEMS[k]);
      return check((cfg.keys || []).includes(k) || inBag, (v) => setTrainer(t.dbSymbol, (e) => { e.keys = e.keys.filter((x) => x !== k); if (v) e.keys.push(k); }),
        label + (inBag ? ' (objet déjà dans son sac)' : ''), `Donne ${KEY_ITEMS[k]} au dresseur pendant le combat`);
    })), 'Le dresseur reçoit l’objet clé pendant le combat. Ses Pokémon doivent aussi tenir leur méga-gemme / cristal Z (Studio : Dresseurs > équipe > objet tenu).'));
    const table = h('div', { class: 'pjg-team' });
    table.appendChild(h('div', { class: 'pjg-team-row head' }, h('span', null, 'Pokémon'), h('span', null, 'Type Téra'), h('span', null, 'Gigamax'), h('span', null, 'Niveau Dynamax')));
    t.party.forEach((p, i) => {
      const slot = (cfg.team || [])[i] || {};
      const c = creatureOf(p.specie);
      const setSlot = (key, value) => setTrainer(t.dbSymbol, (e) => { while (e.team.length <= i) e.team.push({}); e.team[i] = Object.assign({}, e.team[i], { [key]: value }); });
      const base = c && (c.forms.find((f) => f.form === p.form) || c.forms[0]);
      table.appendChild(h('div', { class: 'pjg-team-row' },
        h('span', { class: 'pjg-team-poke' }, c ? h('span', { class: 'pjg-mini', style: iconStyle(c) }) : null, `${c ? c.name : p.specie} N.${p.level}`),
        select([['', `Par défaut${base ? ' (' + base.types.map(typeName).join(' / ') + ')' : ''}`], ...TERA_TYPES], slot.tera || '', (v) => setSlot('tera', v)),
        c && c.gmax ? h('input', { type: 'checkbox', checked: !!slot.gmax, onchange: (e) => setSlot('gmax', e.target.checked) }) : h('span', { class: 'pjs-hint' }, '—'),
        h('input', { class: 'pjs-input pjg-num', type: 'number', min: 0, max: 10, placeholder: String(S.config.dynamax_level), value: slot.dynamax_level ?? '',
          onchange: (e) => setSlot('dynamax_level', e.target.value === '' ? '' : Math.max(0, Math.min(10, +e.target.value))) })));
    });
    editor.appendChild(field('Équipe', t.party.length ? table : h('span', { class: 'pjs-hint' }, 'Équipe vide.')));
  }

  // ---------------------------------------------------------------------------
  // Page « Gimmicks » : onglet Plugins de Studio (/plugins/gimmicks)
  // ---------------------------------------------------------------------------
  const PAGE_ID = 'gimmicks';
  if (!(window.pjPluginPages = window.pjPluginPages || []).some((p) => p.id === PAGE_ID)) window.pjPluginPages.push({ id: PAGE_ID, label: 'Gimmicks' });
  window.dispatchEvent(new Event('pj-plugin-pages'));

  function mount(hostEl) {
    root = h('div', { id: 'pjg-root' });
    ['keydown', 'keypress', 'keyup'].forEach((type) => root.addEventListener(type, (e) => e.stopPropagation()));
    hostEl.appendChild(root);
    S.open = true;
    const latest = projectList()[0] && projectList()[0].projectPath;
    if (!S.config || (latest && latest !== S.projectPath && !dirty())) loadProject(latest || null); else render();
  }
  function checkPage() {
    const hostEl = document.getElementById('pj-page-' + PAGE_ID);
    if (root && hostEl && hostEl.contains(root)) return;
    if (root) { root = null; S.open = false; }
    if (hostEl) mount(hostEl);
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
