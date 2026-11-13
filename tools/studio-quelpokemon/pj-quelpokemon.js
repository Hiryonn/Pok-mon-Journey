/* eslint-disable */
// =============================================================================
// Quel est ce Pokémon ? — page « Level design > Mini-jeux > Quel est ce Pokémon » de Pokémon Studio
//   Aperçu du Pokémon du jour (et des jours suivants), Pokémon pouvant être tirés, partie, récompenses.
// Enregistre Data/configs/plugins/quel_pokemon.json (plugin « quel_pokemon »).
// Le tirage du jour est le même calcul qu'en jeu (scripts/quel_pokemon/scripts/00100 Configuration.rb).
// =============================================================================
(() => {
  'use strict';
  if (window.__pjQuelPokemonLoaded) return;
  window.__pjQuelPokemonLoaded = true;

  const PAGE_ID = 'quel-pokemon';
  const DEFAULTS = {
    klass: 'QuelPokemonConfig', pool: 'all', min_id: 1, max_id: 1025, list: [], exclude: [], choices: 4, tries: 1, mark_seen: true,
    rewards: [], money: 0, streak_every: 0, streak_rewards: [], variable: 0, seed: 0,
  };
  const POOLS = [['all', 'Tous les Pokémon (numéros choisis)'], ['seen', 'Pokémon vus dans le Pokédex du joueur'], ['list', 'Liste choisie']];

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------
  const api = window.pjQuelPokemon;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API « Quel est ce Pokémon » n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const plain = (t) => String(t || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
  let toastTimer = null;
  function toast(msg, err) {
    document.querySelectorAll('.pjs-toast').forEach((t) => t.remove());
    const t = h('div', { class: 'pjs-toast' + (err ? ' err' : '') }, msg);
    document.body.appendChild(t);
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.remove(), err ? 6000 : 2500);
  }
  const projectList = () => { try { return JSON.parse(localStorage.getItem('projectList') || '[]'); } catch (e) { return []; } };
  const imageCache = new Map();
  function loadImage(rel) {
    if (!imageCache.has(rel)) {
      imageCache.set(rel, call('readImage', { projectPath: S.projectPath, file: rel }).then((url) => new Promise((ok) => {
        if (!url) { ok(null); return; }
        const im = new Image(); im.onload = () => ok(im); im.onerror = () => ok(null); im.src = url;
      })).catch(() => null));
    }
    return imageCache.get(rel);
  }

  // --- Tirage du jour : même calcul que le jeu -----------------------------------------
  const today = () => Math.floor((Date.now() / 1000 - new Date().getTimezoneOffset() * 60) / 86400);
  const dayDate = (day) => new Date(day * 86400000 + new Date().getTimezoneOffset() * 60000);
  function roll(day, seed, salt = 0) {
    let x = (day ^ (seed * 7919) ^ (salt * 104729)) >>> 0;
    x = Math.imul(x ^ (x >>> 16), 0x45d9f3b) >>> 0;
    x = Math.imul(x ^ (x >>> 16), 0x45d9f3b) >>> 0;
    return (x ^ (x >>> 16)) >>> 0;
  }
  const creatureOf = (db) => S.ctx.creatures.find((c) => c.db === db);
  function pool() {
    const c = S.config;
    const ex = new Set(c.exclude || []);
    let list;
    if (c.pool === 'list') list = (c.list || []).filter((db) => creatureOf(db));
    else list = S.ctx.creatures.filter((x) => x.id >= (c.min_id | 0) && x.id <= (c.max_id | 0)).map((x) => x.db);
    list = [...new Set(list.filter((db) => !ex.has(db)))];
    return list.sort((a, b) => creatureOf(a).id - creatureOf(b).id);
  }
  function daily(day) {
    const list = pool();
    if (!list.length) return [null, []];
    const seed = S.config.seed | 0;
    const answer = list[roll(day, seed) % list.length];
    const count = clamp(S.config.choices | 0, 2, 6);
    const others = list.filter((x) => x !== answer);
    let choices = [answer];
    let salt = 1;
    while (choices.length < count && others.length) { choices.push(others.splice(roll(day, seed, salt) % others.length, 1)[0]); salt++; }
    const n = roll(day, seed, 99) % choices.length;
    choices = choices.slice(n).concat(choices.slice(0, n));
    return [answer, choices];
  }

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const S = { open: false, projectPath: null, ctx: null, config: null, saved: null, error: null, building: false, day: null, reveal: false };
  let root = null;
  const snapshot = () => JSON.stringify(S.config);
  const dirty = () => S.config && S.saved !== snapshot();

  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.ctx = null; S.config = null; S.error = null;
    imageCache.clear();
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath });
      S.config = Object.assign(clone(DEFAULTS), S.ctx.config || {});
      S.saved = S.ctx.config ? snapshot() : null;
      S.day = today();
    } catch (e) { S.error = e.message; }
    render();
  }
  async function save() {
    if (!S.config) return;
    try {
      const r = await call('save', { projectPath: S.projectPath, config: S.config });
      S.saved = snapshot();
      const p = r.plugin || {};
      if (p.source) S.ctx.plugin = { source: true, installed: p.installed };
      toast('Enregistré' + (p.source && !p.installed ? ' — plugin pas encore installé : lance construire_plugins.bat une fois' : ''));
      render();
      if (p.source && p.installed) rebuildPlugin();
    } catch (e) { toast('Erreur de sauvegarde : ' + e.message, true); }
  }
  async function rebuildPlugin() {
    if (S.building) return;
    S.building = true; updateStatus();
    try { const r = await call('buildPlugin', { projectPath: S.projectPath }); if (!r.built) toast('Plugin non reconstruit : ' + (r.error || '?'), true); } catch (e) { toast('Plugin non reconstruit : ' + e.message, true); }
    S.building = false; updateStatus();
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
    el.textContent = txt; el.className = 'pjs-status' + cls;
  }
  const set = (fn) => { fn(); render(); };

  // ---------------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------------
  function render() {
    if (!root) return;
    const prev = root.querySelector('.pjs-page');
    const scroll = prev ? prev.scrollTop : 0;
    root.textContent = '';
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    const [statusTxt, statusCls] = statusText();
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' }, h('span', { class: 'pjs-top-title' }, 'Quel est ce Pokémon ?'),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + statusCls }, statusTxt),
        h('button', { class: 'pjs-btn secondary', onclick: () => { if (!dirty() || confirm('Abandonner les modifications non enregistrées ?')) loadProject(S.projectPath); } }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.config, title: 'Ctrl+S' }, 'Enregistrer'))));
    const page = h('div', { class: 'pjs-page' });
    root.appendChild(page);
    if (S.error) { page.appendChild(h('div', { class: 'pjs-empty err' }, S.error)); return; }
    if (!S.config) { page.appendChild(h('div', { class: 'pjs-empty' }, 'Chargement…')); return; }
    const content = h('div', { class: 'pjs-content pjq-content' });
    page.appendChild(content);
    const p = S.ctx.plugin;
    if (p && !p.source) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le dossier scripts/quel_pokemon est introuvable.'));
    else if (p && !p.installed) content.appendChild(h('div', { class: 'pjs-warn' }, "Le plugin « quel_pokemon » n'est pas encore installé : lance construire_plugins.bat une fois (ensuite, Enregistrer le met à jour tout seul)."));
    if (!S.ctx.assets.background || !S.ctx.assets.sounds) content.appendChild(h('div', { class: 'pjs-warn' }, 'Images ou sons manquants : graphics/interface/minigames/whosthatpokemon.png, audio/se/minigames/WhosThatPokemon.ogg, Correct.ogg, Incorrect.ogg.'));
    const row = h('div', { class: 'pjs-row pjq-row' });
    content.appendChild(row);
    row.appendChild(renderPreview());
    const right = h('div', { class: 'pjq-right' });
    row.appendChild(right);
    right.appendChild(renderPool());
    right.appendChild(renderGame());
    right.appendChild(renderRewards());
    page.scrollTop = scroll;
  }

  const block = (title, ...kids) => h('div', { class: 'pjs-block' }, h('div', { class: 'pjs-block-head' }, h('h2', null, title)), kids);
  const field = (label, input, hint) => h('label', { class: 'pjq-field' }, h('span', { class: 'pjs-label' }, label), input, hint ? h('span', { class: 'pjs-hint inline' }, hint) : null);
  const num = (value, min, max, onchange, extra) => h('input', Object.assign({ class: 'pjs-input pjq-num', type: 'number', min, max, value, onchange: (e) => onchange(+e.target.value || 0) }, extra || {}));
  const fmtDate = (day) => dayDate(day).toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' });

  // --- Aperçu -------------------------------------------------------------------------------
  function renderPreview() {
    const box = h('div', { class: 'pjs-block pjq-preview' });
    const [answer, choices] = daily(S.day);
    const t = today();
    box.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Aperçu'),
      h('div', { class: 'pjq-daynav' },
        h('button', { class: 'pjs-btn small secondary', onclick: () => set(() => { S.day -= 1; S.reveal = false; }) }, '◀'),
        h('span', { class: 'pjq-day' + (S.day === t ? ' today' : '') }, S.day === t ? "Aujourd'hui" : fmtDate(S.day)),
        h('button', { class: 'pjs-btn small secondary', onclick: () => set(() => { S.day += 1; S.reveal = false; }) }, '▶'),
        S.day !== t ? h('button', { class: 'pjs-btn small secondary', onclick: () => set(() => { S.day = t; S.reveal = false; }) }, "Aujourd'hui") : null)));
    const cv = h('canvas', { class: 'pjq-canvas', width: 320, height: 240 });
    box.appendChild(cv);
    drawPreview(cv, answer);
    if (!answer) { box.appendChild(h('div', { class: 'pjs-hint' }, 'Aucun Pokémon ne peut être tiré : vérifie les réglages.')); return box; }
    box.appendChild(h('div', { class: 'pjq-choices' }, choices.map((db) => {
      const c = creatureOf(db);
      return h('span', { class: 'pjq-choice' + (S.reveal && db === answer ? ' ok' : '') }, c ? c.name : db);
    })));
    box.appendChild(h('div', { class: 'pjq-row-btns' },
      h('button', { class: 'pjs-btn small primary', onclick: () => set(() => { S.reveal = !S.reveal; if (S.reveal) playSound('Correct'); }) }, S.reveal ? 'Cacher' : 'Révéler'),
      h('button', { class: 'pjs-btn small secondary', onclick: () => playSound('WhosThatPokemon') }, '♪ Jingle')));
    if (S.reveal) { const c = creatureOf(answer); box.appendChild(h('div', { class: 'pjq-answer' }, `C'est ${c ? c.name : answer} (n° ${c ? c.id : '?'})`)); }
    if (S.config.pool === 'seen') box.appendChild(h('div', { class: 'pjs-hint' }, 'Avec « vus dans le Pokédex », le tirage dépend de la partie du joueur : l’aperçu montre le tirage parmi tous les Pokémon des numéros choisis.'));
    // jours suivants
    const next = h('div', { class: 'pjq-next' });
    for (let d = t; d < t + 7; d++) {
      const [a] = daily(d);
      const c = a && creatureOf(a);
      const icon = h('span', { class: 'pjq-icon' });
      if (c && c.icon) loadImage(`graphics/pokedex/pokeicon/${c.icon}`).then((im) => { if (im) { icon.style.backgroundImage = `url("${im.src}")`; } });
      next.appendChild(h('div', { class: 'pjq-nextday' + (d === S.day ? ' active' : ''), onclick: () => set(() => { S.day = d; S.reveal = false; }), title: c ? c.name : '' },
        icon, h('span', null, d === t ? "Auj." : dayDate(d).toLocaleDateString('fr-FR', { weekday: 'short', day: 'numeric' }))));
    }
    box.appendChild(h('div', { class: 'pjs-label pjq-mt' }, 'Les 7 prochains jours (clique pour voir)'));
    box.appendChild(next);
    box.appendChild(h('div', { class: 'pjs-hint' }, "Le Pokémon change chaque jour (date de l'ordinateur du joueur). Une seule partie par jour."));
    return box;
  }
  async function drawPreview(cv, answer) {
    const c = cv.getContext('2d');
    c.imageSmoothingEnabled = false;
    c.fillStyle = '#20202a'; c.fillRect(0, 0, 320, 240);
    const bg = await loadImage('graphics/interface/minigames/whosthatpokemon');
    if (bg) c.drawImage(bg, 0, 0, 320, 240);
    const cr = answer && creatureOf(answer);
    if (!cr || !cr.front) return;
    const im = await loadImage(`graphics/pokedex/pokefront/${cr.front}`);
    if (!im) return;
    const s = im.height; const w = Math.min(im.width, s);
    const tmp = document.createElement('canvas'); tmp.width = w; tmp.height = s;
    const tc = tmp.getContext('2d');
    tc.drawImage(im, 0, 0, w, s, 0, 0, w, s);
    if (!S.reveal) { tc.globalCompositeOperation = 'source-atop'; tc.fillStyle = '#000'; tc.fillRect(0, 0, w, s); }
    const z = 1.5;
    c.drawImage(tmp, Math.round(92 - (w * z) / 2), Math.round(96 - (s * z) / 2), w * z, s * z);
  }
  const sounds = new Map();
  function playSound(name) {
    const rel = `audio/se/minigames/${name}.ogg`;
    if (!sounds.has(rel)) sounds.set(rel, call('readSound', { projectPath: S.projectPath, file: rel }).catch(() => null));
    sounds.get(rel).then((url) => { if (url) { try { new Audio(url).play().catch(() => {}); } catch (e) { /* rien */ } } });
  }

  // --- Pokémon à deviner ----------------------------------------------------------------------
  function pokemonPicker(onPick, placeholder) {
    const id = 'pjq-pokemon-list';
    if (!document.getElementById(id)) document.body.appendChild(h('datalist', { id }, S.ctx.creatures.map((c) => h('option', { value: `${c.name} (${c.db})` }))));
    const input = h('input', { class: 'pjs-input', list: id, placeholder });
    input.addEventListener('change', () => {
      const v = input.value.trim();
      const m = /\(([a-z0-9_]+)\)\s*$/.exec(v);
      const c = m ? creatureOf(m[1]) : S.ctx.creatures.find((x) => plain(x.name) === plain(v) || x.db === v || String(x.id) === v.replace(/^0+/, ''));
      if (!c) { toast('Pokémon introuvable : ' + v, true); return; }
      input.value = '';
      onPick(c.db);
    });
    return input;
  }
  function chips(list, onRemove) {
    return h('div', { class: 'pjq-chips' }, list.length ? list.map((db) => {
      const c = creatureOf(db);
      return h('span', { class: 'pjq-chip' }, c ? `${String(c.id).padStart(3, '0')} ${c.name}` : db, h('button', { class: 'pjq-x', onclick: () => onRemove(db), title: 'Retirer' }, '×'));
    }) : h('span', { class: 'pjs-hint' }, 'Aucun.'));
  }
  function renderPool() {
    const c = S.config;
    const box = block('Pokémon à deviner');
    box.appendChild(field('Tirés parmi', h('select', { class: 'pjs-input', onchange: (e) => set(() => { c.pool = e.target.value; }) },
      POOLS.map(([v, l]) => h('option', { value: v, selected: c.pool === v }, l)))));
    if (c.pool === 'list') {
      box.appendChild(pokemonPicker((db) => set(() => { if (!c.list.includes(db)) c.list.push(db); }), 'Ajouter un Pokémon à la liste…'));
      box.appendChild(chips(c.list, (db) => set(() => { c.list = c.list.filter((x) => x !== db); })));
    } else {
      box.appendChild(h('div', { class: 'pjq-grid2' },
        field('Du n°', num(c.min_id, 1, 2000, (v) => set(() => { c.min_id = clamp(v, 1, 2000); }))),
        field('Au n°', num(c.max_id, 1, 2000, (v) => set(() => { c.max_id = clamp(v, 1, 2000); })))));
      box.appendChild(h('div', { class: 'pjq-presets' }, [['Kanto', 1, 151], ['Johto', 1, 251], ['Hoenn', 1, 386], ['Tous', 1, 1025]].map(([l, a, b]) =>
        h('button', { class: 'pjs-btn small secondary', onclick: () => set(() => { c.min_id = a; c.max_id = b; }) }, `${l} (${a}-${b})`))));
    }
    box.appendChild(h('div', { class: 'pjs-label pjq-mt' }, 'Jamais tirés'));
    box.appendChild(pokemonPicker((db) => set(() => { if (!c.exclude.includes(db)) c.exclude.push(db); }), 'Exclure un Pokémon…'));
    box.appendChild(chips(c.exclude, (db) => set(() => { c.exclude = c.exclude.filter((x) => x !== db); })));
    box.appendChild(h('div', { class: 'pjs-hint' }, `${pool().length} Pokémon possibles.`));
    return box;
  }

  // --- Partie ------------------------------------------------------------------------------
  function renderGame() {
    const c = S.config;
    const box = block('Partie');
    box.appendChild(h('div', { class: 'pjq-grid3' },
      field('Réponses proposées', num(c.choices, 2, 6, (v) => set(() => { c.choices = clamp(v, 2, 6); }))),
      field('Essais', num(c.tries, 1, 3, (v) => set(() => { c.tries = clamp(v, 1, 3); })), 'chaque erreur retire une réponse'),
      field('Variable du résultat', num(c.variable, 0, 5000, (v) => set(() => { c.variable = clamp(v, 0, 5000); })), '1 trouvé, 2 raté, 3 déjà joué (0 : aucune)')));
    box.appendChild(h('label', { class: 'pjs-inline' }, h('input', { type: 'checkbox', checked: c.mark_seen, onchange: (e) => set(() => { c.mark_seen = e.target.checked; }) }), 'Le Pokémon révélé est marqué « vu » dans le Pokédex'));
    box.appendChild(h('div', { class: 'pjq-grid2 pjq-mt' },
      field('Graine du tirage', num(c.seed, 0, 99999, (v) => set(() => { c.seed = clamp(v | 0, 0, 99999); }))),
      h('div', { class: 'pjq-field pjq-end' }, h('button', { class: 'pjs-btn small secondary', onclick: () => set(() => { c.seed = Math.floor(Math.random() * 99999); }) }, 'Autre tirage'))));
    box.appendChild(h('div', { class: 'pjs-hint' }, 'Changer la graine change le Pokémon de chaque jour (les joueurs qui ont déjà joué aujourd’hui ne rejouent pas).'));
    box.appendChild(h('div', { class: 'pjs-label pjq-mt' }, 'Commande d’évènement (Script)'));
    box.appendChild(h('code', { class: 'pjq-cmd', title: 'Cliquer pour copier', onclick: () => { try { navigator.clipboard.writeText('quel_est_ce_pokemon'); toast('Copié'); } catch (e) { /* rien */ } } }, 'quel_est_ce_pokemon'));
    box.appendChild(h('div', { class: 'pjs-hint' }, 'À mettre sur un PNJ ou un objet (ordinateur, borne…). quel_pokemon_joue_aujourdhui? et quel_pokemon_serie servent dans les conditions.'));
    return box;
  }

  // --- Récompenses -----------------------------------------------------------------------------
  function itemRows(list) {
    const id = 'pjq-item-list';
    if (!document.getElementById(id)) document.body.appendChild(h('datalist', { id }, S.ctx.items.map((i) => h('option', { value: `${i.name} (${i.db})` }))));
    const wrap = h('div', { class: 'pjq-items' });
    list.forEach((r, i) => {
      const item = S.ctx.items.find((x) => x.db === r.item);
      const input = h('input', { class: 'pjs-input', list: id, value: item ? `${item.name} (${item.db})` : r.item || '', placeholder: 'Objet' });
      input.addEventListener('change', () => {
        const v = input.value.trim(); const m = /\(([a-z0-9_]+)\)\s*$/.exec(v);
        const found = m ? S.ctx.items.find((x) => x.db === m[1]) : S.ctx.items.find((x) => plain(x.name) === plain(v) || x.db === v);
        if (!found) { toast('Objet introuvable : ' + v, true); input.value = item ? `${item.name} (${item.db})` : ''; return; }
        set(() => { r.item = found.db; });
      });
      wrap.appendChild(h('div', { class: 'pjq-item' }, input,
        num(r.quantity || 1, 1, 999, (v) => set(() => { r.quantity = clamp(v, 1, 999); })),
        h('button', { class: 'pjq-x', onclick: () => set(() => { list.splice(i, 1); }), title: 'Retirer' }, '×')));
    });
    wrap.appendChild(h('button', { class: 'pjs-btn small secondary pjq-start', onclick: () => set(() => { list.push({ item: '', quantity: 1 }); }) }, '+ Objet'));
    return wrap;
  }
  function renderRewards() {
    const c = S.config;
    const box = block('Récompenses');
    box.appendChild(h('div', { class: 'pjs-label' }, 'Bonne réponse'));
    box.appendChild(itemRows(c.rewards));
    box.appendChild(field('Argent', num(c.money, 0, 999999, (v) => set(() => { c.money = clamp(v, 0, 999999); })), '$ (0 : aucun)'));
    box.appendChild(h('div', { class: 'pjs-label pjq-mt' }, 'Bonus de série'));
    box.appendChild(field('Tous les', num(c.streak_every, 0, 365, (v) => set(() => { c.streak_every = clamp(v, 0, 365); })), "jours trouvés d'affilée (0 : pas de bonus)"));
    if (c.streak_every > 0) box.appendChild(itemRows(c.streak_rewards));
    return box;
  }

  // ---------------------------------------------------------------------------
  // Page : Level design > Mini-jeux > Quel est ce Pokémon (/database/minigames/quel-pokemon)
  // ---------------------------------------------------------------------------
  function mount(hostEl) {
    root = h('div', { id: 'pjq-root' });
    ['keydown', 'keypress', 'keyup'].forEach((type) => root.addEventListener(type, (e) => e.stopPropagation()));
    hostEl.appendChild(root);
    S.open = true;
    const latest = projectList()[0] && projectList()[0].projectPath;
    if (!S.config || (latest && latest !== S.projectPath && !dirty())) loadProject(latest || null); else render();
  }
  function checkPage() {
    const hostEl = document.getElementById('pj-page-' + PAGE_ID);
    if (root && hostEl && hostEl.contains(root)) return;
    if (root && root.parentNode) root.remove();
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

  window.pjQuelPokemonEditor = { state: S, render, daily };
})();
