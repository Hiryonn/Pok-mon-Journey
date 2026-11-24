/* eslint-disable */
// =============================================================================
// Étui à badges — page « Level design > Dresseurs > Étui à badges » de Pokémon Studio
//   Badges d'arène du jeu : nom, région et numéro (badges de PSDK), image, type, champion, lieu, Pokémon fétiche ;
//   noms des régions ; réglages de l'étui (ce qui est montré avant d'obtenir un badge, jingle) ; aperçu de l'écran du jeu.
// Enregistre Data/configs/plugins/etui_badges.json (plugin « etui_badges », appli « Badges » du téléphone).
// =============================================================================
(() => {
  'use strict';
  if (window.__pjEtuiBadgesLoaded) return;
  window.__pjEtuiBadgesLoaded = true;

  const PAGE_ID = 'etui-badges';
  const GFX = 'graphics/interface/etui_badges';
  const DEFAULT_SETTINGS = { show_unobtained: false, name_always: true, location_always: true, type_always: false, leader_always: false, obtain_me: 'audio/me/rosa_badgeobtained' };
  const DEFAULTS = { klass: 'EtuiBadgesConfig', settings: DEFAULT_SETTINGS, regions: [], badges: [] };
  const SETTINGS = [
    ['show_unobtained', 'Fiche des badges pas encore obtenus', 'A ouvre aussi la fiche d’un badge manquant'],
    ['name_always', 'Nom toujours visible', 'sinon « ??? » tant que le badge manque'],
    ['location_always', 'Lieu toujours visible', 'aide le joueur à trouver l’arène suivante'],
    ['type_always', 'Type toujours visible', 'dans la fiche'],
    ['leader_always', 'Champion toujours visible', 'nom, image et Pokémon fétiche'],
  ];

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------
  const api = window.pjEtuiBadges;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API de l'étui à badges n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  const plain = (t) => String(t || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
  const slug = (t) => plain(t).replace(/^badge\s+/, '').replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '').slice(0, 40) || 'badge';
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
  const txt = (v, lang = 'fr') => (v && typeof v === 'object' ? (v[lang] || v.fr || v.en || '') : String(v || ''));
  const small = (t) => String(t || '').replace(/[’‘]/g, "'");

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const autoIds = new Set();
  const S = { open: false, projectPath: null, ctx: null, config: null, saved: null, error: null, building: false, selected: null, view: 0, obtained: 3, search: '' };
  let root = null;
  const snapshot = () => JSON.stringify(S.config);
  const dirty = () => S.config && S.saved !== snapshot();
  const list = () => S.config.badges;
  const current = () => list().find((b) => b.id === S.selected);
  const creatureOf = (db) => S.ctx.creatures.find((c) => c.db === db);
  const typeOf = (db) => S.ctx.types.find((t) => t.db === db);
  const sorted = () => list().slice().sort((a, b) => a.region - b.region || a.number - b.number);
  const regionBadges = (r) => sorted().filter((b) => b.region === r);
  const regionIds = () => [...new Set(sorted().map((b) => b.region))];
  function regionName(id) {
    const r = S.config.regions.find((x) => x.id === id);
    return (r && txt(r.name)) || `Région ${id}`;
  }

  // Remet un badge dans la forme attendue par le jeu
  function normalize(b) {
    ['name', 'leader', 'location'].forEach((k) => { b[k] = Object.assign({ fr: '', en: '' }, typeof b[k] === 'object' && b[k] ? b[k] : { fr: b[k] || '' }); });
    b.region = Math.min(6, Math.max(1, b.region | 0 || 1));
    b.number = Math.min(8, Math.max(1, b.number | 0 || 1));
    b.type = b.type || '';
    b.ace = b.ace || '';
    b.image = b.image || '';
    b.leader_sprite = b.leader_sprite || '';
    return b;
  }
  function uniqueId(base, except) {
    let id = slug(base); let n = 2;
    const taken = (x) => list().some((b) => b !== except && b.id === x);
    while (taken(id)) id = `${slug(base)}_${n++}`;
    return id;
  }
  // Premier numéro libre d'une région (null si les 8 sont pris)
  function freeNumber(region, except) {
    for (let n = 1; n <= 8; n++) if (!list().some((b) => b !== except && b.region === region && b.number === n)) return n;
    return null;
  }

  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.ctx = null; S.config = null; S.error = null;
    imageCache.clear();
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath });
      S.config = Object.assign(clone(DEFAULTS), S.ctx.config || {});
      S.config.settings = Object.assign(clone(DEFAULT_SETTINGS), S.config.settings || {});
      if (!Array.isArray(S.config.regions)) S.config.regions = [];
      if (!Array.isArray(S.config.badges)) S.config.badges = [];
      S.config.badges = S.config.badges.filter((b) => b && b.id).map(normalize);
      S.saved = S.ctx.config ? snapshot() : null;
      if (!current()) S.selected = sorted()[0] && sorted()[0].id;
    } catch (e) { S.error = e.message; }
    render();
  }
  function problems() {
    const out = [];
    const ids = new Set();
    const slots = new Map();
    for (const b of list()) {
      if (!b.id) out.push('Un badge n’a pas d’identifiant.');
      else if (ids.has(b.id)) out.push(`Identifiant en double : ${b.id}`);
      ids.add(b.id);
      if (!txt(b.name).trim()) out.push(`« ${b.id} » n’a pas de nom.`);
      const key = `${b.region}-${b.number}`;
      if (slots.has(key)) out.push(`« ${txt(b.name) || b.id} » et « ${slots.get(key)} » ont le même numéro (${b.number}) dans ${regionName(b.region)}.`);
      slots.set(key, txt(b.name) || b.id);
    }
    return out;
  }
  async function save() {
    if (!S.config) return;
    const p = problems();
    if (p.length) { toast('À corriger avant d’enregistrer : ' + p[0], true); return; }
    try {
      S.config.badges = sorted();
      S.config.regions = S.config.regions.filter((r) => txt(r.name).trim() || regionIds().includes(r.id)).sort((a, b) => a.id - b.id);
      const r = await call('save', { projectPath: S.projectPath, config: S.config });
      S.saved = snapshot();
      const pl = r.plugin || {};
      if (pl.source) S.ctx.plugin = { source: true, installed: pl.installed };
      toast('Enregistré' + (pl.source && !pl.installed ? ' — plugin pas encore installé : lance construire_plugins.bat une fois' : ''));
      render();
      if (pl.source && pl.installed) rebuildPlugin();
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
    return [S.saved ? 'Enregistré' : 'Pas encore enregistré', ''];
  }
  function updateStatus() {
    const el = root && root.querySelector('.pjs-status');
    if (!el) return;
    const [t, cls] = statusText();
    el.textContent = t; el.className = 'pjs-status' + cls;
  }
  const set = (fn) => { fn(); render(); };
  const soft = (fn) => { fn(); updateStatus(); refreshLive(); };

  // ---------------------------------------------------------------------------
  // Actions sur la liste
  // ---------------------------------------------------------------------------
  function addBadge(base) {
    const cur = current();
    let region = base ? base.region : (cur ? cur.region : 1);
    let number = freeNumber(region);
    while (number === null && region < 6) { region += 1; number = freeNumber(region); }
    if (number === null) { toast('Les 6 régions ont déjà 8 badges.', true); return; }
    const b = normalize(base ? clone(base) : { name: { fr: 'Nouveau badge', en: '' } });
    b.region = region; b.number = number;
    b.id = uniqueId(base ? b.id : txt(b.name), null);
    autoIds.add(b.id);
    if (base) b.name.fr = txt(b.name) + ' (copie)';
    list().push(b);
    S.selected = b.id;
    render();
    const el = root.querySelector('[data-focus="name-fr"]');
    if (el) { el.focus(); el.select(); }
  }
  function removeBadge(b) {
    if (!confirm(`Supprimer le badge « ${txt(b.name)} » ?\nLe badge de PSDK (région ${b.region}, n° ${b.number}) reste dans les sauvegardes, il ne sera plus affiché.`)) return;
    const all = sorted();
    const i = all.indexOf(b);
    list().splice(list().indexOf(b), 1);
    S.selected = (all[i + 1] || all[i - 1] || {}).id;
    render();
  }
  // Échange le numéro avec le badge voisin de la même région
  function moveBadge(b, delta) {
    const rb = regionBadges(b.region);
    const other = rb[rb.indexOf(b) + delta];
    if (!other) return;
    [b.number, other.number] = [other.number, b.number];
    render();
  }

  // ---------------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------------
  function render() {
    if (!root) return;
    const prevList = root.querySelector('.pjeb-list');
    const listScroll = prevList ? prevList.scrollTop : 0;
    const prev = root.querySelector('.pjeb-detail');
    const scroll = prev ? prev.scrollTop : 0;
    const focused = document.activeElement && document.activeElement.dataset ? document.activeElement.dataset.focus : null;
    root.textContent = '';
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    const [statusTxt, statusCls] = statusText();
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' }, h('span', { class: 'pjs-top-title' }, 'Étui à badges'),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + statusCls }, statusTxt),
        h('button', { class: 'pjs-btn secondary', onclick: () => { if (!dirty() || confirm('Abandonner les modifications non enregistrées ?')) loadProject(S.projectPath); } }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.config, title: 'Ctrl+S' }, 'Enregistrer'))));
    if (S.error) { root.appendChild(h('div', { class: 'pjs-page' }, h('div', { class: 'pjs-empty err' }, S.error))); return; }
    if (!S.config) { root.appendChild(h('div', { class: 'pjs-page' }, h('div', { class: 'pjs-empty' }, 'Chargement…'))); return; }
    const body = h('div', { class: 'pjeb-body' });
    root.appendChild(body);
    body.appendChild(renderSidebar());
    const detail = h('div', { class: 'pjeb-detail' });
    body.appendChild(detail);
    const content = h('div', { class: 'pjeb-content' });
    detail.appendChild(content);
    const p = S.ctx.plugin;
    if (p && !p.source) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le dossier scripts/etui_badges est introuvable.'));
    else if (p && !p.installed) content.appendChild(h('div', { class: 'pjs-warn' }, "Le plugin « etui_badges » n'est pas encore installé : lance construire_plugins.bat une fois (ensuite, Enregistrer le met à jour tout seul)."));
    const b = current();
    if (!b) {
      content.appendChild(h('div', { class: 'pjs-empty' }, h('div', null, 'Aucun badge pour l’instant.'),
        h('button', { class: 'pjs-btn primary pjeb-mt', onclick: () => addBadge() }, '+ Créer un badge')));
    } else {
      const row = h('div', { class: 'pjeb-row' });
      content.appendChild(row);
      row.appendChild(renderPreview());
      const right = h('div', { class: 'pjeb-right' });
      row.appendChild(right);
      right.appendChild(renderGeneral(b));
      right.appendChild(renderImage(b));
      right.appendChild(renderLeader(b));
    }
    const row2 = h('div', { class: 'pjeb-row2' });
    content.appendChild(row2);
    row2.appendChild(renderRegions());
    row2.appendChild(renderSettings());
    content.appendChild(renderCommands());
    detail.scrollTop = scroll;
    const l = root.querySelector('.pjeb-list');
    if (l) l.scrollTop = listScroll;
    if (focused) { const el = root.querySelector(`[data-focus="${focused}"]`); if (el) { el.focus(); if (el.setSelectionRange && typeof el.value === 'string' && el.type !== 'number') el.setSelectionRange(el.value.length, el.value.length); } }
  }

  const block = (title, extra, ...kids) => h('div', { class: 'pjs-block' }, h('div', { class: 'pjs-block-head' }, h('h2', null, title), extra || null), kids);
  const field = (label, input, hint) => h('label', { class: 'pjeb-field' }, h('span', { class: 'pjs-label' }, label), input, hint ? h('span', { class: 'pjs-hint inline' }, hint) : null);
  const badgeImage = (b, off) => {
    const base = b.image || b.id;
    if (off && S.ctx.offImages.includes(base + '_off')) return loadImage(`${GFX}/badges/${base}_off`);
    return loadImage(`${GFX}/badges/${base}`);
  };
  const hasOff = (b) => S.ctx.offImages.includes((b.image || b.id) + '_off');
  const bgBox = (promise, cls) => {
    const el = h('span', { class: cls });
    promise.then((im) => { if (im) el.style.backgroundImage = `url("${im.src}")`; });
    return el;
  };
  function leaderImage(b) {
    const s = b.leader_sprite;
    if (!s) return Promise.resolve(null);
    if (S.ctx.leaderImages.includes(s)) return loadImage(`${GFX}/leaders/${s}`);
    return loadImage(`graphics/battlers/${s}`);
  }

  // --- Liste des badges, par région --------------------------------------------------------
  function renderSidebar() {
    const side = h('div', { class: 'pjeb-side' });
    side.appendChild(h('button', { class: 'pjs-btn primary pjeb-add', onclick: () => addBadge() }, '+ Nouveau badge'));
    side.appendChild(h('input', { class: 'pjs-input', placeholder: 'Rechercher…', value: S.search, 'data-focus': 'search', oninput: (e) => { S.search = e.target.value; render(); } }));
    const box = h('div', { class: 'pjeb-list' });
    side.appendChild(box);
    const q = plain(S.search);
    regionIds().forEach((r) => {
      const rb = regionBadges(r);
      const shown = rb.filter((b) => !q || plain(txt(b.name)).includes(q) || b.id.includes(q) || plain(txt(b.leader)).includes(q));
      if (!shown.length) return;
      box.appendChild(h('div', { class: 'pjeb-group' }, h('span', null, regionName(r)), h('span', { class: 'pjeb-groupn' }, `${rb.length} / 8`)));
      shown.forEach((b) => {
        const i = rb.indexOf(b);
        box.appendChild(h('div', { class: 'pjeb-entry' + (b.id === S.selected ? ' active' : ''), 'data-id': b.id, onclick: () => set(() => { S.selected = b.id; }) },
          h('span', { class: 'pjeb-num' }, b.number),
          bgBox(badgeImage(b), 'pjeb-ico'),
          h('span', { class: 'pjeb-ename' }, h('span', { class: 'pjeb-name' }, txt(b.name) || b.id),
            h('span', { class: 'pjeb-sub' }, [txt(b.leader), txt(b.location)].filter(Boolean).join(' · '))),
          !q ? h('span', { class: 'pjeb-move' },
            h('button', { class: 'pjeb-x', title: 'Monter (échange les numéros)', disabled: i === 0, onclick: (e) => { e.stopPropagation(); moveBadge(b, -1); } }, '▲'),
            h('button', { class: 'pjeb-x', title: 'Descendre (échange les numéros)', disabled: i === rb.length - 1, onclick: (e) => { e.stopPropagation(); moveBadge(b, 1); } }, '▼')) : null));
      });
    });
    side.appendChild(h('div', { class: 'pjs-hint pjeb-count' }, `${list().length} badge(s) · ${regionIds().length} région(s)`));
    return side;
  }
  function refreshLive() {
    const b = current();
    if (!b || !root) return;
    const entry = root.querySelector(`.pjeb-entry[data-id="${CSS.escape(b.id)}"] .pjeb-name`);
    if (entry) entry.textContent = txt(b.name) || b.id;
    const cv = root.querySelector('.pjeb-canvas');
    if (cv) drawPreview(cv);
  }

  // --- Aperçu (écran du jeu, 320 x 240) --------------------------------------------------------
  const VIEWS = ['Étui', 'Fiche', 'Badge obtenu'];
  function renderPreview() {
    const box = h('div', { class: 'pjs-block pjeb-preview' });
    box.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Aperçu en jeu'),
      h('div', { class: 'pjeb-tabs' }, VIEWS.map((v, i) => h('button', { class: 'pjs-btn small ' + (S.view === i ? 'primary' : 'secondary'), onclick: () => set(() => { S.view = i; }) }, v)))));
    const cv = h('canvas', { class: 'pjeb-canvas', width: 320, height: 240 });
    box.appendChild(cv);
    drawPreview(cv);
    if (S.view === 0) {
      const b = current();
      const rb = regionBadges(b.region);
      box.appendChild(h('label', { class: 'pjeb-slider' }, h('span', { class: 'pjs-hint inline' }, 'Badges déjà obtenus dans l’aperçu'),
        h('input', { type: 'range', min: 0, max: rb.length, value: Math.min(S.obtained, rb.length), oninput: (e) => { S.obtained = e.target.value | 0; drawPreview(cv); } })));
    }
    box.appendChild(h('div', { class: 'pjs-hint' }, [
      'Étui : flèches pour choisir un badge, L / R pour changer de région, A pour la fiche. Les badges manquants sont grisés.',
      'Fiche : ouverte avec A ; date d’obtention, type, lieu, champion et son Pokémon fétiche.',
      'Badge obtenu : écran montré par la commande obtenir_badge(:id), avec le jingle choisi plus bas.'][S.view]));
    return box;
  }
  const COL = { light: '#e5f3fa', dark: '#282828', white: '#fff' };
  let drawToken = 0;
  async function drawPreview(cv) {
    const token = ++drawToken;
    const img = (n) => loadImage('graphics/interface/' + n);
    const names = ['horizon/team/fond', 'horizon/header', 'horizon/tcard/button_background', 'quest/arrow_frame_l', 'quest/arrow_frame_r',
      'etui_badges/tray', 'etui_badges/slot', 'etui_badges/cursor', 'etui_badges/info', 'etui_badges/shine', 'types_fr',
      'etui_badges/card_name', 'etui_badges/card_badge', 'etui_badges/card_ace', 'etui_badges/card_panel', 'etui_badges/card_table', 'etui_badges/card_stage'];
    const I = {};
    (await Promise.all(names.map(img))).forEach((im, i) => { I[names[i].split('/').pop()] = im; });
    const b = current();
    if (!b) return;
    const rb = regionBadges(b.region);
    const done = (x) => (S.view === 0 ? rb.indexOf(x) < S.obtained : true);
    const images = await Promise.all(rb.map((x) => badgeImage(x, !done(x))));
    const leader = await leaderImage(b);
    const ace = creatureOf(b.ace);
    const aceIcon = ace && ace.icon ? await loadImage(`graphics/pokedex/pokeicon/${ace.icon}`) : null;
    if (token !== drawToken) return;
    const c = cv.getContext('2d');
    c.imageSmoothingEnabled = false;
    const draw = (im, x, y) => { if (im) c.drawImage(im, x, y); };
    const text = (s, x, y, o = {}) => {
      c.font = `${o.small ? 9 : 11}px "Avenir Next", sans-serif`;
      c.fillStyle = o.color || COL.dark; c.textBaseline = 'top'; c.textAlign = o.align || 'left';
      c.fillText(small(s), x, y);
    };
    c.fillStyle = COL.light; c.fillRect(0, 0, 320, 240);
    draw(I.fond, 0, 0); draw(I.header, 0, 0); draw(I.button_background, 0, 214);
    const count = rb.filter(done).length;
    const regions = regionIds();
    if (S.view === 0) {
      text(`Total : ${count}`, 6, 9, { small: true, color: COL.white });
      text(`${count} / ${rb.length}`, 314, 9, { small: true, color: COL.white, align: 'right' });
      text(regionName(b.region).toUpperCase(), 160, 7, { align: 'center', color: COL.white });
    } else if (S.view === 1) {
      text('INFOS DU BADGE', 160, 7, { align: 'center', color: COL.white });
      text(`N° ${b.number}`, 314, 9, { small: true, color: COL.white, align: 'right' });
    }
    const S2 = S.config.settings;
    if (S.view === 0) {
      if (regions.length > 1) { draw(I.arrow_frame_l, 84, 6); draw(I.arrow_frame_r, 228, 6); }
      text(regions.length > 1 ? 'A : Détails   L / R : Région   B : Quitter' : 'A : Détails   B : Quitter', 160, 222, { small: true, color: COL.white, align: 'center' });
      draw(I.tray, 10, 32);
      const cols = rb.length <= 4 ? Math.max(rb.length, 1) : 4;
      const rows = rb.length <= 4 ? 1 : 2;
      const cw = Math.floor(300 / cols); const ch = Math.floor(146 / rows);
      rb.forEach((x, i) => {
        const sx = 10 + (i % cols) * cw + Math.floor((cw - 48) / 2);
        const sy = 32 + Math.floor(i / cols) * ch + Math.floor((ch - 48) / 2);
        draw(I.slot, sx, sy);
        const im = images[i];
        if (im) {
          c.globalAlpha = done(x) ? 1 : 170 / 255;
          c.drawImage(im, sx + 4, sy + 4, 40, 40);
          c.globalAlpha = 1;
        }
        if (x === b && I.cursor) c.drawImage(I.cursor, 0, 0, 52, 52, sx - 2, sy - 2, 52, 52);
      });
      draw(I.info, 6, 182);
      const got = done(b);
      text(got || S2.name_always ? txt(b.name) : '???', 14, 184);
      text(got || S2.location_always ? txt(b.location) : '???', 14, 199, { small: true });
      text(got ? '16/11/2026' : 'Pas encore obtenu', 306, 186, { small: true, align: 'right' });
      if (txt(b.leader) && (got || S2.leader_always)) text(txt(b.leader), 306, 199, { small: true, align: 'right' });
      return;
    }
    if (S.view === 1) {
      text('< > : Badge   B : Retour', 160, 222, { small: true, color: COL.white, align: 'center' });
      draw(I.card_name, 0, 34);
      text(txt(b.name), 61, 38, { align: 'center' });
      draw(I.card_badge, 12, 62);
      const im = images[rb.indexOf(b)];
      if (im) c.drawImage(im, 22, 72, 80, 80);
      if (ace) {
        draw(I.card_ace, 0, 168);
        if (aceIcon) { const w = aceIcon.width > aceIcon.height ? aceIcon.height : aceIcon.width; c.drawImage(aceIcon, 0, 0, w, aceIcon.height, 8, 173, w, aceIcon.height); }
        text('POKÉMON', 83, 172, { small: true, align: 'center' });
        text('FÉTICHE', 83, 182, { small: true, align: 'center' });
        text(ace.name, 83, 197, { align: 'center' });
      }
      draw(I.card_panel, 132, 34);
      draw(I.card_table, 139, 40);
      draw(I.card_stage, 139, 124);
      ['Obtenu le', 'Type', 'Lieu', 'Champion'].forEach((label, i) => {
        const y = 40 + 1 + i * 20 + 5;
        text(label, 177, y, { small: true, color: COL.white, align: 'center' });
      });
      text('16/11/2026', 262, 46, { small: true, align: 'center' });
      const t = typeOf(b.type);
      if (t && I.types_fr) c.drawImage(I.types_fr, 0, t.id * 14, 32, 14, 246, 63, 32, 14);
      else text('-', 262, 66, { small: true, align: 'center' });
      text(txt(b.location) || '-', 262, 86, { small: true, align: 'center' });
      text(txt(b.leader) || '-', 262, 106, { small: true, align: 'center' });
      if (leader) {
        const z = Math.min(1, 80 / Math.max(leader.width, leader.height));
        const w = Math.round(leader.width * z); const hh = Math.round(leader.height * z);
        c.drawImage(leader, 139 + Math.floor((172 - w) / 2), 204 - hh, w, hh);
      }
      return;
    }
    text('BADGE OBTENU !', 160, 7, { align: 'center', color: COL.white });
    text('A : Continuer', 160, 222, { small: true, color: COL.white, align: 'center' });
    for (let i = 0; i < 8; i++) {
      const a = (i * 45 + 20) * Math.PI / 180;
      if (I.shine) draw(I.shine, 160 + Math.round(Math.cos(a) * 64) - 7, 110 + Math.round(Math.sin(a) * 64) - 7);
    }
    const im = images[rb.indexOf(b)];
    if (im) c.drawImage(im, 112, 62, 96, 96);
    text(txt(b.name), 160, 172, { align: 'center' });
    const where = [txt(b.location), txt(b.leader) ? `Champion : ${txt(b.leader)}` : ''].filter(Boolean).join('  -  ');
    text(where, 160, 191, { small: true, align: 'center' });
  }

  // --- Général ------------------------------------------------------------------------------
  function renderGeneral(b) {
    const box = block('Badge', h('div', { class: 'pjeb-actions' },
      h('button', { class: 'pjs-btn small secondary', onclick: () => addBadge(b) }, 'Dupliquer'),
      h('button', { class: 'pjs-btn small danger', onclick: () => removeBadge(b) }, 'Supprimer')));
    box.appendChild(h('div', { class: 'pjeb-grid2' },
      field('Nom (français)', h('input', { class: 'pjs-input', 'data-focus': 'name-fr', value: b.name.fr, oninput: (e) => soft(() => { b.name.fr = e.target.value; followName(b); }) })),
      field('Nom (anglais)', h('input', { class: 'pjs-input', 'data-focus': 'name-en', placeholder: b.name.fr, value: b.name.en, oninput: (e) => soft(() => { b.name.en = e.target.value; }) }))));
    const region = h('select', { class: 'pjs-input', onchange: (e) => set(() => {
      const r = e.target.value | 0;
      const n = list().some((x) => x !== b && x.region === r && x.number === b.number) ? freeNumber(r, b) : b.number;
      if (n === null) { toast(`${regionName(r)} a déjà 8 badges.`, true); return; }
      b.region = r; b.number = n;
    }) }, [1, 2, 3, 4, 5, 6].map((r) => h('option', { value: r }, `${r} · ${regionName(r)}`)));
    region.value = b.region;
    const number = h('select', { class: 'pjs-input', onchange: (e) => set(() => {
      const n = e.target.value | 0;
      const other = list().find((x) => x !== b && x.region === b.region && x.number === n);
      if (other) other.number = b.number;
      b.number = n;
    }) }, [1, 2, 3, 4, 5, 6, 7, 8].map((n) => {
      const other = list().find((x) => x !== b && x.region === b.region && x.number === n);
      return h('option', { value: n }, other ? `${n} (échange avec ${txt(other.name) || other.id})` : String(n));
    }));
    number.value = b.number;
    const type = h('select', { class: 'pjs-input', onchange: (e) => set(() => { b.type = e.target.value; }) },
      h('option', { value: '' }, 'Aucun'), S.ctx.types.map((t) => h('option', { value: t.db }, t.name)));
    type.value = b.type;
    box.appendChild(h('div', { class: 'pjeb-grid4' },
      field('Région', region),
      field('Numéro', number, 'badge de PSDK'),
      field('Type de l’arène', type),
      field('Identifiant', h('input', { class: 'pjs-input pjeb-mono', 'data-focus': 'id', value: b.id,
        onchange: (e) => set(() => { const id = uniqueId(e.target.value || txt(b.name), b); autoIds.delete(b.id); b.id = id; S.selected = id; }) }), 'pour les commandes')));
    box.appendChild(h('div', { class: 'pjeb-grid2' },
      field('Lieu (français)', h('input', { class: 'pjs-input', 'data-focus': 'loc-fr', value: b.location.fr, placeholder: 'Argenta', oninput: (e) => soft(() => { b.location.fr = e.target.value; }) })),
      field('Lieu (anglais)', h('input', { class: 'pjs-input', 'data-focus': 'loc-en', value: b.location.en, placeholder: b.location.fr, oninput: (e) => soft(() => { b.location.en = e.target.value; }) }))));
    box.appendChild(h('div', { class: 'pjs-hint' }, 'Région et numéro sont ceux des badges de PSDK ($trainer.set_badge(numéro, région)) : les commandes de badge de Studio et les conditions « badges » marchent avec l’étui.'));
    return box;
  }
  function followName(b) {
    if (!autoIds.has(b.id) || !txt(b.name).trim()) return;
    const old = b.id;
    const id = uniqueId(txt(b.name), b);
    if (id === old) return;
    autoIds.delete(old); autoIds.add(id);
    b.id = id; S.selected = id;
    const entry = root.querySelector(`.pjeb-entry[data-id="${CSS.escape(old)}"]`);
    if (entry) entry.dataset.id = id;
    const input = root.querySelector('[data-focus="id"]');
    if (input) input.value = id;
  }

  // --- Image du badge ---------------------------------------------------------------------------
  async function importImage(folder, name) {
    try {
      const r = await call('importImage', { projectPath: S.projectPath, folder, name });
      if (!r) return null;
      imageCache.clear();
      S.ctx = Object.assign(S.ctx, await call('getContext', { projectPath: S.projectPath }), { config: S.ctx.config });
      toast('Image importée');
      return r;
    } catch (e) { toast('Import impossible : ' + e.message, true); return null; }
  }
  function renderImage(b) {
    const base = b.image || b.id;
    const box = block('Image', h('div', { class: 'pjeb-actions' },
      h('button', { class: 'pjs-btn small secondary', onclick: async () => { const n = await importImage('badges', ''); if (n) set(() => { b.image = n; }); } }, 'Importer…'),
      h('button', { class: 'pjs-btn small secondary', title: `Enregistrée sous ${base}_off.png`, onclick: async () => { if (await importImage('badges', base + '_off')) render(); } }, 'Importer la version grise…')));
    box.appendChild(h('div', { class: 'pjeb-pick' },
      bgBox(badgeImage(b), 'pjeb-bigico'),
      bgBox(badgeImage(b, true), 'pjeb-bigico' + (hasOff(b) ? '' : ' auto')),
      h('div', { class: 'pjs-hint inline' }, hasOff(b) ? `Obtenu / pas encore obtenu (${base}_off).` : 'Pas de version grise : le jeu assombrit l’image du badge.')));
    const q = h('input', { class: 'pjs-input pjeb-gsearch', placeholder: 'Filtrer les images…', 'data-focus': 'img-search', value: S.imgSearch || '', oninput: (e) => { S.imgSearch = e.target.value; render(); } });
    box.appendChild(q);
    const grid = h('div', { class: 'pjeb-gallery' });
    const qq = plain(S.imgSearch);
    S.ctx.badgeImages.filter((n) => !qq || n.includes(qq)).forEach((n) => {
      grid.appendChild(h('button', { class: 'pjeb-gimg' + (n === base ? ' on' : ''), title: n, onclick: () => set(() => { b.image = n; }) }, bgBox(loadImage(`${GFX}/badges/${n}`), 'pjeb-ico')));
    });
    if (!S.ctx.badgeImages.length) grid.appendChild(h('div', { class: 'pjs-hint' }, 'Aucune image dans graphics/interface/etui_badges/badges.'));
    box.appendChild(grid);
    box.appendChild(h('div', { class: 'pjs-hint' }, 'Images de 40 x 40 (agrandies dans la fiche). Dossier : graphics/interface/etui_badges/badges.'));
    return box;
  }

  // --- Champion ------------------------------------------------------------------------------
  function renderLeader(b) {
    const box = block('Champion', h('button', { class: 'pjs-btn small secondary', onclick: async () => { const n = await importImage('leaders', ''); if (n) set(() => { b.leader_sprite = n; }); } }, 'Importer une image…'));
    box.appendChild(h('div', { class: 'pjeb-grid2' },
      field('Nom (français)', h('input', { class: 'pjs-input', 'data-focus': 'leader-fr', value: b.leader.fr, oninput: (e) => soft(() => { b.leader.fr = e.target.value; }) })),
      field('Nom (anglais)', h('input', { class: 'pjs-input', 'data-focus': 'leader-en', value: b.leader.en, placeholder: b.leader.fr, oninput: (e) => soft(() => { b.leader.en = e.target.value; }) }))));
    const sprite = h('select', { class: 'pjs-input', onchange: (e) => set(() => { b.leader_sprite = e.target.value; }) },
      h('option', { value: '' }, 'Aucune'),
      h('optgroup', { label: 'etui_badges/leaders' }, S.ctx.leaderImages.map((n) => h('option', { value: n }, n))),
      h('optgroup', { label: 'graphics/battlers' }, S.ctx.battlers.filter((n) => !S.ctx.leaderImages.includes(n)).map((n) => h('option', { value: n }, n))));
    sprite.value = b.leader_sprite;
    box.appendChild(h('div', { class: 'pjeb-pick' }, bgBox(leaderImage(b), 'pjeb-leader'),
      h('div', { class: 'pjeb-grow' }, field('Image', sprite),
        field('Pokémon fétiche', picker(S.ctx.creatures, b.ace, (v) => set(() => { b.ace = v; }), true)))));
    return box;
  }
  function picker(options, value, onPick, numbered) {
    const wrapEl = h('div', { class: 'pjeb-picker' });
    const sel = h('select', { class: 'pjs-input', onchange: (e) => onPick(e.target.value) });
    const fill = (q) => {
      sel.textContent = '';
      const qq = plain(q);
      let shown = options.filter((o) => !qq || plain(o.name).includes(qq) || o.db.includes(qq)).slice(0, 400);
      const cur = options.find((o) => o.db === value);
      if (cur && !shown.includes(cur)) shown = [cur].concat(shown);
      sel.appendChild(h('option', { value: '' }, '— aucun —'));
      shown.forEach((o) => sel.appendChild(h('option', { value: o.db }, (numbered ? String(o.id).padStart(4, '0') + ' ' : '') + o.name)));
      sel.value = cur ? value : '';
    };
    const search = h('input', { class: 'pjs-input', placeholder: 'Filtrer…', oninput: (e) => fill(e.target.value) });
    fill('');
    wrapEl.appendChild(search); wrapEl.appendChild(sel);
    return wrapEl;
  }

  // --- Régions -------------------------------------------------------------------------------
  function renderRegions() {
    const box = block('Régions');
    const used = regionIds();
    [1, 2, 3, 4, 5, 6].forEach((id) => {
      let r = S.config.regions.find((x) => x.id === id);
      const count = list().filter((b) => b.region === id).length;
      const edit = (lang, v) => {
        if (!r) { r = { id, name: { fr: '', en: '' } }; S.config.regions.push(r); }
        r.name = Object.assign({ fr: '', en: '' }, r.name, { [lang]: v });
      };
      box.appendChild(h('div', { class: 'pjeb-region' + (used.includes(id) ? '' : ' unused') },
        h('span', { class: 'pjeb-rid' }, id),
        h('input', { class: 'pjs-input', 'data-focus': 'reg-fr-' + id, value: r ? r.name.fr || '' : '', placeholder: `Région ${id}`, oninput: (e) => soft(() => edit('fr', e.target.value)), onchange: () => render() }),
        h('input', { class: 'pjs-input', 'data-focus': 'reg-en-' + id, value: r ? r.name.en || '' : '', placeholder: 'English', oninput: (e) => soft(() => edit('en', e.target.value)) }),
        h('span', { class: 'pjs-hint inline pjeb-catn' }, `${count} / 8 badges`)));
    });
    box.appendChild(h('div', { class: 'pjs-hint' }, 'Titre de l’étui en jeu. Seules les régions qui ont des badges s’affichent ; L / R passent de l’une à l’autre.'));
    return box;
  }

  // --- Réglages ----------------------------------------------------------------------------
  let audio = null;
  function renderSettings() {
    const st = S.config.settings;
    const box = block('Réglages de l’étui');
    SETTINGS.forEach(([key, label, hint]) => box.appendChild(h('label', { class: 'pjs-inline pjeb-check' },
      h('input', { type: 'checkbox', checked: !!st[key], onchange: (e) => set(() => { st[key] = e.target.checked; }) }), label, h('span', { class: 'pjs-hint inline' }, hint))));
    const me = h('select', { class: 'pjs-input', onchange: (e) => set(() => { st.obtain_me = e.target.value; }) }, h('option', { value: '' }, 'Aucune musique'),
      S.ctx.mes.map((m) => h('option', { value: m }, m.replace('audio/me/', ''))));
    me.value = st.obtain_me || '';
    box.appendChild(h('div', { class: 'pjeb-pick pjeb-mt' }, h('div', { class: 'pjeb-grow' }, field('Jingle « Badge obtenu ! » (audio/me)', me)),
      h('button', { class: 'pjs-btn small secondary pjeb-play', disabled: !st.obtain_me, onclick: async () => {
        try { if (audio) audio.pause(); const url = await call('readSound', { projectPath: S.projectPath, file: st.obtain_me }); if (url) { audio = new Audio(url); audio.volume = 0.6; audio.play(); } } catch (e) { toast(e.message, true); }
      } }, '▶ Écouter')));
    return box;
  }

  // --- Commandes ---------------------------------------------------------------------------
  function copy(t) { try { navigator.clipboard.writeText(t); toast('Copié'); } catch (e) { /* rien */ } }
  function renderCommands() {
    const id = S.selected || 'boulder';
    const cur = current();
    const cmds = [
      ['etui_badges', 'ouvre l’étui (aussi : appli « Badges » du téléphone)'],
      [`etui_badges(${cur ? cur.region : 1})`, 'ouvre l’étui sur une région'],
      [`obtenir_badge(:${id})`, 'donne le badge et montre « Badge obtenu ! »'],
      [`obtenir_badge(:${id}, false)`, 'donne le badge sans écran'],
      [`badge?(:${id})`, 'true si le badge est obtenu (condition)'],
      ['nombre_badges', 'nombre de badges obtenus (nombre_badges(1) : dans la région 1)'],
      [`retirer_badge(:${id})`, 'retire le badge (pour tester)'],
    ];
    return block('Commandes d’évènement (Script)', null, h('div', { class: 'pjeb-cmds' }, cmds.map(([cmd, hint]) => h('div', { class: 'pjeb-cmdrow' },
      h('code', { class: 'pjeb-cmd', title: 'Cliquer pour copier', onclick: () => copy(cmd) }, cmd), h('span', { class: 'pjs-hint inline' }, hint)))),
      h('div', { class: 'pjs-hint' }, 'Un badge donné autrement (commande « Badge » de Studio, $trainer.set_badge) apparaît aussi dans l’étui, avec sa date d’obtention.'));
  }

  // ---------------------------------------------------------------------------
  // Page : Level design > Dresseurs > Étui à badges (/database/trainers/badges)
  // ---------------------------------------------------------------------------
  function mount(hostEl) {
    root = h('div', { id: 'pjeb-root' });
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
    if (root) { root = null; S.open = false; if (audio) audio.pause(); }
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

  window.pjEtuiBadgesEditor = { state: S, render };
})();
