/* eslint-disable */
// =============================================================================
// Carte de région — page « Level design > Carte de région » de Pokémon Studio Extra (plugin « carte_region »)
//   Régions : thème, musique, quartiers, décorations, quêtes, revanches, régions reliées (placés sur la carte)
//   Lieux : description, image et visibilité de chaque zone
//   Réglages : options générales (« ??? », zoom, souris, vol rapide, recherche, modes…)
//   Lieux fictifs : où montrer le joueur sur certaines cartes
// Enregistre Data/configs/plugins/carte_region.json. D'après « Arcky's Region Map » (Essentials).
// =============================================================================
(() => {
  'use strict';
  if (window.__pjCarteRegionLoaded) return;
  window.__pjCarteRegionLoaded = true;

  const PAGE_ID = 'carte-region';
  const TILE = 8;
  const GFX = 'graphics/interface/carte_region';
  const DEFAULT_SETTINGS = {
    replace_town_map: true, theme: 'horizon', theme_variable: 0, unvisited_text: { fr: '???', en: '???' }, show_unvisited_names: false,
    mark_unvisited: true, unvisited_color: [0, 0, 0, 110], highlight: true, highlight_color: [255, 255, 255, 90],
    quick_fly: true, fly_from_map: true, fly_other_regions: false, auto_cursor: true, max_choices: 6, zoom: true, mouse: true,
    search: true, search_min: 3, search_unvisited: false, preview: true, preview_animation: true, extended_preview: true,
    max_description_lines: 3, weather_preview: true, progress: true, time_based: true, music: true, show_player: true,
    button_hints: true, cursor_frames: 5, modes: { fly: true, quest: true, berry: true, roaming: true, trainer: true },
  };
  const THEME_NAMES = { horizon: 'Horizon', rouge: 'Rouge', bleu: 'Bleu (Arcky)', vert: 'Vert', sombre: 'Sombre', violet: 'Violet' };
  const QUEST_COLORS = [['', 'Jaune (défaut)'], ['red', 'Rouge'], ['blue', 'Bleu'], ['cyan', 'Cyan'], ['green', 'Vert'], ['magenta', 'Magenta'], ['orange', 'Orange'], ['purple', 'Violet'], ['yellow', 'Jaune vif']];
  const SIDES = [['left', 'Gauche'], ['right', 'Droite'], ['up', 'Haut'], ['down', 'Bas']];
  const WEATHERS = ['', 'Pluie', 'Soleil', 'Tempête de sable', 'Grêle', 'Brouillard', 'Soleil intense', 'Pluie battante', 'Vents forts', 'Neige'];
  const WEATHER_ICON = ['', 'rain', 'sunny', 'sandstorm', 'hail', 'fog', 'hardsun', 'hardrain', 'strong_winds', 'snow'];
  const TOOLS = [['paint', 'Zones'], ['point', 'Point du lieu'], ['select', 'Regarder'], ['district', 'Quartier'], ['decoration', 'Décoration'], ['quest', 'Quête'], ['trainer', 'Revanche']];
  const LIST_KEY = { district: 'districts', decoration: 'decorations', quest: 'quests', trainer: 'trainers' };

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------
  const api = window.pjCarteRegion;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API de la Carte de région n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  const txt = (v, lang = 'fr') => (v && typeof v === 'object' && !Array.isArray(v) ? (v[lang] || v.fr || v.en || '') : String(v || ''));
  const loc = (v) => Object.assign({ fr: '', en: '' }, v && typeof v === 'object' && !Array.isArray(v) ? v : { fr: v ? String(v) : '' });
  const int = (v, d = 0) => (v === '' || v === null || v === undefined || Number.isNaN(+v) ? d : Math.round(+v));
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
  function copy(t) { try { navigator.clipboard.writeText(t); toast('Copié'); } catch (e) { /* rien */ } }
  const hue = (id) => (id * 137.508) % 360;

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const S = {
    projectPath: null, ctx: null, config: null, saved: null, error: null, building: false, open: false,
    tab: 'regions', wm: null, zone: null, tool: 'paint', paintZone: null, painting: false, wmChanged: new Set(), wmDeleted: [], sel: null, hover: null, zoneSearch: '', showGrid: true, showZones: true,
  };
  let root = null;
  const wmState = () => (S.ctx ? [S.ctx.worldmaps.map((w) => [w.id, w.image, w.grid, w.names]), S.wmDeleted] : null);
  const snapshot = () => JSON.stringify([cleaned(), wmState()]);
  const dirty = () => S.config && S.saved !== snapshot();
  const wmOf = (id) => S.ctx.worldmaps.find((w) => w.id === id);
  const zoneOf = (id) => S.ctx.zones.find((z) => z.id === id);
  const currentWm = () => wmOf(S.wm);
  const settings = () => S.config.settings;

  function region(id = S.wm, create = true) {
    const key = String(id);
    if (!S.config.regions[key] && create) S.config.regions[key] = {};
    const r = S.config.regions[key] || {};
    ['districts', 'decorations', 'quests', 'trainers', 'connections'].forEach((k) => { if (!Array.isArray(r[k])) r[k] = []; });
    return r;
  }
  function zoneCfg(id, create = true) {
    const key = String(id);
    if (!S.config.zones[key] && create) S.config.zones[key] = {};
    return S.config.zones[key] || {};
  }
  function normalize(c) {
    c.settings = Object.assign(clone(DEFAULT_SETTINGS), c.settings || {});
    c.settings.modes = Object.assign(clone(DEFAULT_SETTINGS.modes), c.settings.modes || {});
    c.settings.unvisited_text = loc(c.settings.unvisited_text);
    if (!c.regions || typeof c.regions !== 'object' || Array.isArray(c.regions)) c.regions = {};
    if (!c.zones || typeof c.zones !== 'object' || Array.isArray(c.zones)) c.zones = {};
    if (!Array.isArray(c.fake_locations)) c.fake_locations = [];
    return c;
  }
  // Retire ce qui est vide avant d'enregistrer
  function cleaned() {
    const c = clone(S.config);
    Object.keys(c.regions).forEach((k) => {
      const r = c.regions[k];
      Object.keys(r).forEach((key) => { if ((Array.isArray(r[key]) && !r[key].length) || r[key] === '' || r[key] === null) delete r[key]; });
      if (r.music && !r.music.name) delete r.music;
      if (!Object.keys(r).length) delete c.regions[k];
    });
    Object.keys(c.zones).forEach((k) => {
      const z = c.zones[k];
      if (z.description && !z.description.fr && !z.description.en) delete z.description;
      if (!z.image) delete z.image;
      if (!z.switch) delete z.switch;
      if (!Object.keys(z).length) delete c.zones[k];
    });
    return c;
  }

  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.ctx = null; S.config = null; S.error = null;
    imageCache.clear();
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath });
      S.config = normalize(Object.assign({ klass: 'CarteRegionConfig' }, S.ctx.config || {}));
      const order = ['horizon', 'rouge', 'bleu', 'vert', 'sombre', 'violet'];
      S.ctx.themes.sort((a, b) => (order.indexOf(a) + 1 || 99) - (order.indexOf(b) + 1 || 99) || a.localeCompare(b));
      S.saved = S.ctx.config ? snapshot() : null;
      if (!wmOf(S.wm)) S.wm = S.ctx.worldmaps[0] ? S.ctx.worldmaps[0].id : null;
      if (!zoneOf(S.zone)) S.zone = (zonesOnMaps()[0] || S.ctx.zones[0] || {}).id;
      S.sel = null;
      S.wmChanged = new Set(); S.wmDeleted = [];
      if (!zoneOf(S.paintZone)) S.paintZone = (S.ctx.zones.find((z) => z.id > 0) || S.ctx.zones[0] || {}).id;
      S.saved = snapshot();
    } catch (e) { S.error = e.message; }
    render();
  }
  async function save() {
    if (!S.config) return;
    try {
      const worldmaps = S.ctx.worldmaps.filter((w) => S.wmChanged.has(w.id))
        .map((w) => ({ id: w.id, db: w.db, file: w.file, image: w.image, grid: w.grid, names: w.names, textIndex: w.textIndex }));
      const r = await call('save', { projectPath: S.projectPath, config: cleaned(), worldmaps, deleted: S.wmDeleted });
      (r.worldmaps || []).forEach((res) => { const w = wmOf(res.id); if (w) { w.file = res.file; w.textIndex = res.textIndex; } });
      S.wmChanged.clear(); S.wmDeleted = [];
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
  async function importImage(folder, done) {
    try {
      const name = await call('importImage', { projectPath: S.projectPath, folder });
      if (!name) return;
      const list = folder === 'lieux' ? S.ctx.images : folder === 'worldmaps' ? S.ctx.mapImages : S.ctx.decorations;
      if (!list.includes(name)) list.push(name);
      list.sort((a, b) => a.localeCompare(b, 'fr'));
      imageCache.delete(`${GFX}/${folder}/${name}`);
      imageCache.delete(`graphics/interface/worldmap/worldmaps/${name}`);
      done(name);
    } catch (e) { toast('Image non ajoutée : ' + e.message, true); }
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
  const soft = (fn) => { fn(); updateStatus(); redraw(); };

  // Zones peintes sur au moins une carte du monde
  function cellsOf(wm) {
    const out = {};
    (wm ? wm.grid : []).forEach((row, y) => (row || []).forEach((id, x) => { if (id != null && id >= 0) (out[id] = out[id] || []).push([x, y]); }));
    return out;
  }
  function zonesOnMaps() {
    const ids = new Set();
    S.ctx.worldmaps.forEach((w) => Object.keys(cellsOf(w)).forEach((id) => ids.add(+id)));
    return S.ctx.zones.filter((z) => ids.has(z.id));
  }
  function gridSize(wm) { return [Math.max(0, ...wm.grid.map((r) => (r || []).length)), wm.grid.length]; }

  // ---------------------------------------------------------------------------
  // Rendu général
  // ---------------------------------------------------------------------------
  function render() {
    if (!root) return;
    const scrolls = [...root.querySelectorAll('[data-scroll]')].map((e) => [e.dataset.scroll, e.scrollTop]);
    const focused = document.activeElement && document.activeElement.dataset ? document.activeElement.dataset.focus : null;
    root.textContent = '';
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    const [statusTxt, statusCls] = statusText();
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' }, h('span', { class: 'pjs-top-title' }, 'Carte de région'),
        h('div', { class: 'pjcr-tabs pjcr-maintabs' }, [['regions', 'Régions'], ['zones', 'Lieux'], ['settings', 'Réglages'], ['fake', 'Lieux fictifs']].map(([k, l]) =>
          h('button', { class: 'pjs-btn small ' + (S.tab === k ? 'primary' : 'secondary'), onclick: () => set(() => { S.tab = k; S.sel = null; }) }, l))),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + statusCls }, statusTxt),
        h('button', { class: 'pjs-btn secondary', onclick: () => { if (!dirty() || confirm('Abandonner les modifications non enregistrées ?')) loadProject(S.projectPath); } }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.config, title: 'Ctrl+S' }, 'Enregistrer'))));
    if (S.error) { root.appendChild(h('div', { class: 'pjs-page' }, h('div', { class: 'pjs-empty err' }, S.error))); return; }
    if (!S.config) { root.appendChild(h('div', { class: 'pjs-page' }, h('div', { class: 'pjs-empty' }, 'Chargement…'))); return; }
    const body = h('div', { class: 'pjcr-body' + (S.tab === 'settings' || S.tab === 'fake' ? ' single' : '') });
    root.appendChild(body);
    if (S.tab === 'regions') renderRegions(body);
    else if (S.tab === 'zones') renderZones(body);
    else if (S.tab === 'settings') renderSettings(body);
    else renderFake(body);
    scrolls.forEach(([k, v]) => { const e = root.querySelector(`[data-scroll="${k}"]`); if (e) e.scrollTop = v; });
    if (focused) { const el = root.querySelector(`[data-focus="${focused}"]`); if (el) { el.focus(); if (el.setSelectionRange && typeof el.value === 'string' && el.type !== 'number') el.setSelectionRange(el.value.length, el.value.length); } }
  }

  const block = (title, extra, ...kids) => h('div', { class: 'pjs-block' }, h('div', { class: 'pjs-block-head' }, h('h2', null, title), extra || null), kids);
  const field = (label, input, hint) => h('label', { class: 'pjcr-field' }, h('span', { class: 'pjs-label' }, label), input, hint ? h('span', { class: 'pjs-hint inline' }, hint) : null);
  const select = (options, value, onchange, attrs = {}) => { const s = h('select', Object.assign({ class: 'pjs-input', onchange: (e) => onchange(e.target.value) }, attrs), options.map(([v, l]) => h('option', { value: v }, l))); s.value = value == null ? '' : String(value); return s; };
  const numInput = (value, onInput, attrs = {}) => h('input', Object.assign({ class: 'pjs-input', type: 'number', value: value === null || value === undefined ? '' : value, oninput: (e) => soft(() => onInput(e.target.value === '' ? null : +e.target.value)) }, attrs));
  const textInput = (value, onInput, attrs = {}) => h('input', Object.assign({ class: 'pjs-input', value: value || '', oninput: (e) => soft(() => onInput(e.target.value)) }, attrs));
  const check = (label, value, onchange, hint) => h('label', { class: 'pjs-inline pjcr-check', title: hint || null }, h('input', { type: 'checkbox', checked: !!value, onchange: (e) => set(() => onchange(e.target.checked)) }), label);
  function iconSpan(rel, cls = 'pjcr-ico', frame) {
    const el = h('span', { class: cls });
    if (rel) loadImage(rel).then((im) => {
      if (!im) return;
      if (frame) { const c = document.createElement('canvas'); const fw = im.width / 4; const fh = im.height / 4; c.width = fw; c.height = fh; c.getContext('2d').drawImage(im, 0, 0, fw, fh, 0, 0, fw, fh); el.style.backgroundImage = `url("${c.toDataURL()}")`; } else el.style.backgroundImage = `url("${im.src}")`;
    });
    return el;
  }
  // Liste déroulante avec filtre (personnages : plusieurs milliers d'images)
  function picker(options, value, onPick, placeholder = '— choisir —') {
    const wrapEl = h('div', { class: 'pjcr-picker' });
    const sel = h('select', { class: 'pjs-input', onchange: (e) => onPick(e.target.value) });
    const fill = (q) => {
      sel.textContent = '';
      const qq = plain(q);
      let shown = options.filter((o) => !qq || plain(o[1]).includes(qq) || plain(o[0]).includes(qq)).slice(0, 300);
      const cur = options.find((o) => String(o[0]) === String(value));
      if (cur && !shown.includes(cur)) shown = [cur].concat(shown);
      sel.appendChild(h('option', { value: '' }, placeholder));
      shown.forEach((o) => sel.appendChild(h('option', { value: o[0] }, o[1])));
      sel.value = cur ? String(value) : '';
    };
    wrapEl.appendChild(h('input', { class: 'pjs-input pjcr-psearch', placeholder: 'Filtrer…', oninput: (e) => fill(e.target.value) }));
    wrapEl.appendChild(sel);
    fill('');
    return wrapEl;
  }
  function warnings(content) {
    const p = S.ctx.plugin;
    if (p && !p.source) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le dossier scripts/carte_region est introuvable.'));
    else if (p && !p.installed) content.appendChild(h('div', { class: 'pjs-warn' }, "Le plugin « carte_region » n'est pas encore installé : lance construire_plugins.bat une fois (ensuite, Enregistrer le met à jour tout seul)."));
    if (!S.ctx.assets) content.appendChild(h('div', { class: 'pjs-warn' }, 'Les images du plugin (graphics/interface/carte_region) sont absentes.'));
  }

  // ---------------------------------------------------------------------------
  // Carte (canvas) : image, grille, zones, éléments placés
  // ---------------------------------------------------------------------------
  let canvasEl = null;
  let drag = null;
  function scaleFor(wm, img) {
    const [gw, gh] = gridSize(wm);
    const w = Math.max(img ? img.width : 0, gw * TILE, 1);
    const hgt = Math.max(img ? img.height : 0, gh * TILE, 1);
    return Math.max(1, Math.min(4, Math.floor(Math.min(760 / w, 560 / hgt))) || 1);
  }
  function renderCanvas(container, wm, opts) {
    const wrap = h('div', { class: 'pjcr-canvaswrap' });
    canvasEl = h('canvas', { class: 'pjcr-canvas' });
    canvasEl.__opts = opts;
    wrap.appendChild(canvasEl);
    const info = h('div', { class: 'pjcr-cellinfo' }, ' ');
    wrap.appendChild(info);
    container.appendChild(wrap);
    requestAnimationFrame(() => redraw());
    const cellAt = (ev) => {
      const r = canvasEl.getBoundingClientRect();
      const sc = canvasEl.__scale || 1;
      return [Math.floor((ev.clientX - r.left) * (canvasEl.width / r.width) / sc / TILE), Math.floor((ev.clientY - r.top) * (canvasEl.height / r.height) / sc / TILE)];
    };
    canvasEl.addEventListener('mousemove', (ev) => {
      const [x, y] = cellAt(ev);
      S.hover = [x, y];
      const id = (wm.grid[y] || [])[x];
      const z = id != null && id >= 0 ? zoneOf(id) : null;
      info.textContent = `Case ${x}, ${y}` + (z ? ` — ${z.name} (zone ${z.id})` : ' — aucune zone') + (opts.hint ? '   ·   ' + opts.hint() : '');
      if (drag) { drag.x2 = x; drag.y2 = y; }
      if (S.painting && opts.onPaint) opts.onPaint(x, y);
      redraw();
    });
    canvasEl.addEventListener('contextmenu', (ev) => {
      ev.preventDefault();
      const [x, y] = cellAt(ev);
      if (opts.onPick) opts.onPick(x, y);
    });
    canvasEl.addEventListener('mouseleave', () => { S.hover = null; info.textContent = ' '; redraw(); });
    canvasEl.addEventListener('mousedown', (ev) => {
      if (ev.button !== 0) return;
      const [x, y] = cellAt(ev);
      if (opts.onDown) opts.onDown(x, y, ev);
    });
    redraw();
  }
  function onUp(ev) {
    if (S.painting) { S.painting = false; if (canvasEl && canvasEl.__opts.onPaintEnd) canvasEl.__opts.onPaintEnd(); }
    if (!drag || !canvasEl) return;
    const d = drag; drag = null;
    if (canvasEl.__opts.onDragEnd) canvasEl.__opts.onDragEnd(d);
  }
  let drawToken = 0;
  async function redraw() {
    if (!canvasEl || !document.body.contains(canvasEl)) return;
    const token = ++drawToken;
    const opts = canvasEl.__opts;
    const wm = opts.wm;
    const img = wm.image ? await loadImage(`graphics/interface/${wm.image}`) : null;
    const extra = opts.images ? await opts.images() : {};
    if (token !== drawToken) return;
    const [gw, gh] = gridSize(wm);
    const sc = scaleFor(wm, img);
    const W = Math.max(img ? img.width : 0, gw * TILE);
    const H = Math.max(img ? img.height : 0, gh * TILE);
    canvasEl.width = W * sc; canvasEl.height = H * sc;
    canvasEl.__scale = sc;
    const c = canvasEl.getContext('2d');
    c.imageSmoothingEnabled = false;
    c.fillStyle = '#20232c'; c.fillRect(0, 0, canvasEl.width, canvasEl.height);
    if (img) c.drawImage(img, 0, 0, img.width * sc, img.height * sc);
    const cells = cellsOf(wm);
    // zones peintes
    if (S.showZones) {
      Object.entries(cells).forEach(([id, list]) => {
        const sel = opts.zone != null && +id === opts.zone;
        c.fillStyle = sel ? 'rgba(255,255,255,.55)' : `hsla(${hue(+id)},80%,55%,.22)`;
        list.forEach(([x, y]) => c.fillRect(x * TILE * sc, y * TILE * sc, TILE * sc, TILE * sc));
      });
    }
    if (S.showGrid && sc >= 2) {
      c.strokeStyle = 'rgba(0,0,0,.18)'; c.lineWidth = 1;
      for (let x = 0; x <= gw; x++) { c.beginPath(); c.moveTo(x * TILE * sc + 0.5, 0); c.lineTo(x * TILE * sc + 0.5, gh * TILE * sc); c.stroke(); }
      for (let y = 0; y <= gh; y++) { c.beginPath(); c.moveTo(0, y * TILE * sc + 0.5); c.lineTo(gw * TILE * sc, y * TILE * sc + 0.5); c.stroke(); }
    }
    if (opts.draw) opts.draw(c, sc, extra);
    if (drag) {
      const x1 = Math.min(drag.x, drag.x2); const y1 = Math.min(drag.y, drag.y2);
      const x2 = Math.max(drag.x, drag.x2); const y2 = Math.max(drag.y, drag.y2);
      c.strokeStyle = '#ffd34d'; c.lineWidth = 2;
      c.strokeRect(x1 * TILE * sc + 1, y1 * TILE * sc + 1, (x2 - x1 + 1) * TILE * sc - 2, (y2 - y1 + 1) * TILE * sc - 2);
    }
    if (S.hover) {
      c.strokeStyle = '#fff'; c.lineWidth = 1;
      c.strokeRect(S.hover[0] * TILE * sc + 0.5, S.hover[1] * TILE * sc + 0.5, TILE * sc - 1, TILE * sc - 1);
    }
  }
  const centerOf = (x, y, sc) => [(x * TILE + TILE / 2) * sc, (y * TILE + TILE / 2) * sc];
  function drawIcon(c, im, x, y, sc, selected, frame) {
    const [cx, cy] = centerOf(x, y, sc);
    if (im) {
      const fw = frame ? im.width / 4 : im.width; const fh = frame ? im.height / 4 : im.height;
      const k = frame && fh > 24 ? 0.5 : 1;
      const zw = fw * k * Math.max(1, sc / 2); const zh = fh * k * Math.max(1, sc / 2);
      c.drawImage(im, 0, 0, fw, fh, cx - zw / 2, cy - zh / 2, zw, zh);
    } else { c.fillStyle = '#ffd34d'; c.beginPath(); c.arc(cx, cy, 5, 0, Math.PI * 2); c.fill(); }
    if (selected) { c.strokeStyle = '#ffd34d'; c.lineWidth = 2; c.strokeRect(cx - 12, cy - 12, 24, 24); }
  }

  // ---------------------------------------------------------------------------
  // Onglet Régions
  // ---------------------------------------------------------------------------
  function renderRegions(body) {
    const side = h('div', { class: 'pjcr-side' });
    side.appendChild(h('button', { class: 'pjs-btn primary', onclick: addWorldmap }, '+ Carte du monde'));
    const list = h('div', { class: 'pjcr-list', 'data-scroll': 'wmlist' });
    S.ctx.worldmaps.forEach((w) => {
      const r = S.config.regions[String(w.id)] || {};
      const n = ['districts', 'decorations', 'quests', 'trainers'].reduce((a, k) => a + ((r[k] || []).length), 0);
      const [gw, gh] = gridSize(w);
      list.appendChild(h('div', { class: 'pjcr-entry' + (w.id === S.wm ? ' active' : ''), onclick: () => set(() => { S.wm = w.id; S.sel = null; }) },
        iconSpan(w.image ? `graphics/interface/${w.image}` : null, 'pjcr-thumb'),
        h('span', { class: 'pjcr-ename' }, h('span', { class: 'pjcr-name' }, w.name || w.db),
          h('span', { class: 'pjcr-sub' }, `n° ${w.id} · ${gw} × ${gh} cases · ${Object.keys(cellsOf(w)).length} lieux${n ? ` · ${n} élément${n > 1 ? 's' : ''}` : ''}`))));
    });
    if (!S.ctx.worldmaps.length) list.appendChild(h('div', { class: 'pjs-hint' }, 'Aucune carte du monde dans le projet.'));
    side.appendChild(list);
    body.appendChild(side);
    const detail = h('div', { class: 'pjcr-detail', 'data-scroll': 'regdetail' });
    body.appendChild(detail);
    const content = h('div', { class: 'pjcr-content' });
    detail.appendChild(content);
    warnings(content);
    const wm = currentWm();
    if (!wm) { content.appendChild(h('div', { class: 'pjs-empty' }, 'Crée une carte du monde (bouton + Carte du monde) pour commencer.')); return; }
    const r = region();
    const row = h('div', { class: 'pjcr-row' });
    content.appendChild(row);
    const left = h('div', { class: 'pjs-block pjcr-mapblock' });
    row.appendChild(left);
    left.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, wm.name || wm.db),
      h('div', { class: 'pjcr-actions' },
        h('label', { class: 'pjs-inline pjcr-check' }, h('input', { type: 'checkbox', checked: S.showZones, onchange: (e) => { S.showZones = e.target.checked; redraw(); } }), 'Zones'),
        h('label', { class: 'pjs-inline pjcr-check' }, h('input', { type: 'checkbox', checked: S.showGrid, onchange: (e) => { S.showGrid = e.target.checked; redraw(); } }), 'Grille'))));
    left.appendChild(h('div', { class: 'pjcr-tabs pjcr-tools' }, TOOLS.map(([k, l]) =>
      h('button', { class: 'pjs-btn small ' + (S.tool === k ? 'primary' : 'secondary'), onclick: () => set(() => { S.tool = k; S.sel = null; }) }, l))));
    if (S.tool === 'paint') left.appendChild(renderPaintBar(wm));
    left.appendChild(h('div', { class: 'pjs-hint' }, {
      paint: 'Peins les cases avec la zone choisie (clic maintenu). Clic droit : reprendre la zone d\'une case. La gomme vide les cases.',
      point: 'Clique sur une case d\'un lieu : c\'est là que le joueur, l\'icône de vol et les icônes du lieu apparaissent.',
      select: 'Survole la carte pour voir les zones. Clique sur un élément placé pour le choisir.',
      district: 'Fais glisser sur la carte pour tracer un quartier (son nom s\'affiche en bas de l\'écran).',
      decoration: 'Clique sur la carte pour poser la décoration choisie (coin haut-gauche de l\'image).',
      quest: 'Clique sur la carte pour placer une quête (icône visible pendant que la quête est en cours).',
      trainer: 'Clique sur la carte pour placer un dresseur (icône visible quand son interrupteur est activé).',
    }[S.tool]));
    renderCanvas(left, wm, regionCanvasOpts(wm, r));
    const right = h('div', { class: 'pjcr-right' });
    row.appendChild(right);
    right.appendChild(renderRegionGeneral(wm, r));
    right.appendChild(renderConnections(wm, r));
    content.appendChild(renderRegionList(wm, r));
    content.appendChild(renderCommands());
  }

  function regionCanvasOpts(wm, r) {
    return {
      wm,
      hint: () => (S.tool === 'select' ? '' : 'Outil : ' + TOOLS.find((t) => t[0] === S.tool)[1]),
      onPaint: (x, y) => paintCell(wm, x, y),
      onPick: (x, y) => { const id = (wm.grid[y] || [])[x]; set(() => { S.tool = 'paint'; S.paintZone = id != null && id >= 0 ? id : -1; }); },
      onPaintEnd: () => render(),
      images: async () => {
        const out = {};
        await Promise.all([
          ...r.decorations.map(async (d) => { out['deco:' + d.image] = await loadImage(`${GFX}/decorations/${d.image}`); }),
          ...QUEST_COLORS.map(async ([k]) => { out['quest:' + k] = await loadImage(`${GFX}/icons/${k ? 'quest_' + k : 'quest'}`); }),
          ...r.trainers.map(async (t) => { out['char:' + t.character] = t.character ? await loadImage(`graphics/characters/${t.character}`) : null; }),
          (async () => { out.trainer = await loadImage(`${GFX}/icons/trainer`); })(),
        ]);
        return out;
      },
      draw: (c, sc, im) => {
        // point de chaque lieu (réglé ici, sinon celui de Studio, sinon le centre)
        Object.entries(cellsOf(wm)).forEach(([id, list]) => {
          const p = pointOf(wm, +id, list);
          if (!p) return;
          const [cx, cy] = centerOf(p[0], p[1], sc);
          const own = (S.config.zones[id] || {}).position;
          c.fillStyle = own ? '#ffd34d' : 'rgba(255,255,255,.9)'; c.strokeStyle = 'rgba(0,0,0,.75)'; c.lineWidth = 1;
          c.beginPath(); c.arc(cx, cy, Math.max(2, sc * 1.5), 0, Math.PI * 2); c.fill(); c.stroke();
        });
        if (S.tool === 'paint' && S.paintZone != null && S.paintZone >= 0) {
          c.strokeStyle = '#ffd34d'; c.lineWidth = 2;
          (cellsOf(wm)[S.paintZone] || []).forEach(([x, y]) => c.strokeRect(x * TILE * sc + 1, y * TILE * sc + 1, TILE * sc - 2, TILE * sc - 2));
        }
        r.decorations.forEach((d, i) => {
          const g = im['deco:' + d.image];
          const x = int(d.x) * TILE * sc; const y = int(d.y) * TILE * sc;
          if (g) { c.globalAlpha = d.switch ? 0.7 : 1; c.drawImage(g, x, y, g.width * sc, g.height * sc); c.globalAlpha = 1; }
          if (S.sel && S.sel.kind === 'decoration' && S.sel.index === i) { c.strokeStyle = '#ffd34d'; c.lineWidth = 2; c.strokeRect(x, y, (g ? g.width : TILE) * sc, (g ? g.height : TILE) * sc); }
        });
        r.districts.forEach((d, i) => {
          const selected = S.sel && S.sel.kind === 'district' && S.sel.index === i;
          c.strokeStyle = selected ? '#ffd34d' : 'rgba(255,255,255,.85)'; c.lineWidth = selected ? 2 : 1;
          c.setLineDash([4, 3]);
          c.strokeRect(int(d.x) * TILE * sc + 1, int(d.y) * TILE * sc + 1, Math.max(1, int(d.w, 1)) * TILE * sc - 2, Math.max(1, int(d.h, 1)) * TILE * sc - 2);
          c.setLineDash([]);
          c.font = `${Math.max(10, 5 * sc)}px sans-serif`; c.fillStyle = '#fff'; c.strokeStyle = 'rgba(0,0,0,.7)'; c.lineWidth = 3;
          const label = txt(d.name) || 'Quartier';
          c.strokeText(label, int(d.x) * TILE * sc + 4, int(d.y) * TILE * sc + 12); c.fillText(label, int(d.x) * TILE * sc + 4, int(d.y) * TILE * sc + 12);
        });
        r.quests.forEach((q, i) => drawIcon(c, im['quest:' + (q.color || '')], int(q.x), int(q.y), sc, S.sel && S.sel.kind === 'quest' && S.sel.index === i));
        r.trainers.forEach((t, i) => drawIcon(c, im['char:' + t.character] || im.trainer, int(t.x), int(t.y), sc, S.sel && S.sel.kind === 'trainer' && S.sel.index === i, !!im['char:' + t.character]));
      },
      onDown: (x, y) => {
        if (S.tool === 'paint') { S.painting = true; paintCell(wm, x, y); redraw(); return; }
        if (S.tool === 'point') {
          const id = (wm.grid[y] || [])[x];
          if (id == null || id < 0) { toast('Cette case n\'appartient à aucun lieu.', true); return; }
          set(() => { zoneCfg(id).position = { x, y }; });
          return;
        }
        if (S.tool === 'district') { drag = { x, y, x2: x, y2: y }; redraw(); return; }
        if (S.tool === 'select') {
          const hit = (kind, list, test) => { const i = list.findIndex(test); if (i >= 0) { S.sel = { kind, index: i }; return true; } return false; };
          const found = hit('quest', r.quests, (q) => int(q.x) === x && int(q.y) === y) || hit('trainer', r.trainers, (t) => int(t.x) === x && int(t.y) === y) ||
            hit('district', r.districts, (d) => x >= int(d.x) && y >= int(d.y) && x < int(d.x) + int(d.w, 1) && y < int(d.y) + int(d.h, 1)) ||
            hit('decoration', r.decorations, (d) => int(d.x) === x && int(d.y) === y);
          if (!found) S.sel = null;
          render();
          return;
        }
        // Outil de pose : déplace l'élément choisi (même type) ou en crée un nouveau
        const key = LIST_KEY[S.tool];
        if (S.sel && S.sel.kind === S.tool && r[key][S.sel.index]) {
          Object.assign(r[key][S.sel.index], { x, y });
        } else {
          const item = S.tool === 'decoration' ? { image: S.ctx.decorations[0] || '', x, y, switch: 0, above: false }
            : S.tool === 'quest' ? { quest: (S.ctx.quests[0] || {}).db || '', x, y, color: '' }
              : { name: { fr: 'Dresseur', en: '' }, character: '', x, y, switch: 0, text: { fr: '', en: '' } };
          r[key].push(item);
          S.sel = { kind: S.tool, index: r[key].length - 1 };
        }
        render();
      },
      onDragEnd: (d) => {
        const x = Math.min(d.x, d.x2); const y = Math.min(d.y, d.y2);
        const w = Math.abs(d.x2 - d.x) + 1; const hh = Math.abs(d.y2 - d.y) + 1;
        if (S.sel && S.sel.kind === 'district' && r.districts[S.sel.index]) Object.assign(r.districts[S.sel.index], { x, y, w, h: hh });
        else { r.districts.push({ name: { fr: 'Nouveau quartier', en: '' }, x, y, w, h: hh }); S.sel = { kind: 'district', index: r.districts.length - 1 }; }
        render();
      },
    };
  }

  // Point d'un lieu : celui réglé ici, sinon celui de Studio, sinon la case la plus proche du centre
  function pointOf(wm, id, list) {
    const own = (S.config.zones[String(id)] || {}).position;
    if (own && list.some(([x, y]) => x === own.x && y === own.y)) return [own.x, own.y];
    const z = zoneOf(id);
    if (z && z.position && list.some(([x, y]) => x === z.position.x && y === z.position.y)) return [z.position.x, z.position.y];
    if (!list.length) return null;
    const mx = list.reduce((a, p) => a + p[0], 0) / list.length; const my = list.reduce((a, p) => a + p[1], 0) / list.length;
    return list.reduce((b, p) => ((p[0] - mx) ** 2 + (p[1] - my) ** 2 < (b[0] - mx) ** 2 + (b[1] - my) ** 2 ? p : b), list[0]);
  }
  function paintCell(wm, x, y) {
    const [gw, gh] = gridSize(wm);
    if (x < 0 || y < 0 || x >= gw || y >= gh) return;
    const v = S.paintZone == null ? -1 : S.paintZone;
    if (!wm.grid[y]) wm.grid[y] = new Array(gw).fill(-1);
    if (wm.grid[y][x] === v) return;
    wm.grid[y][x] = v;
    S.wmChanged.add(wm.id);
    updateStatus();
  }
  // Grille à la taille de l'image (cases de 8 px), en gardant ce qui est déjà peint
  function fitGrid(wm, img) {
    const cols = Math.max(1, Math.ceil(img.width / TILE)); const rows = Math.max(1, Math.ceil(img.height / TILE));
    const grid = [];
    for (let y = 0; y < rows; y++) { grid.push([]); for (let x = 0; x < cols; x++) grid[y].push(wm.grid[y] && wm.grid[y][x] != null ? wm.grid[y][x] : -1); }
    wm.grid = grid;
  }
  async function setImage(wm, name) {
    wm.image = name ? `worldmap/worldmaps/${name}` : '';
    S.wmChanged.add(wm.id);
    const img = name ? await loadImage(`graphics/interface/${wm.image}`) : null;
    if (img) fitGrid(wm, img);
    render();
  }
  function addWorldmap() {
    const id = S.ctx.worldmaps.reduce((m, w) => Math.max(m, w.id), -1) + 1;
    const wm = { id, db: `worldmap_${id}`, image: '', grid: [], file: null, textIndex: null, name: `Région ${id}`, names: { fr: `Région ${id}`, en: `Region ${id}` } };
    for (let y = 0; y < 21; y++) wm.grid.push(new Array(32).fill(-1));
    S.ctx.worldmaps.push(wm);
    S.wmChanged.add(id);
    S.wmDeleted = S.wmDeleted.filter((d) => d !== id);
    S.wm = id; S.tool = 'paint';
    render();
  }
  function deleteWorldmap(wm) {
    if (!confirm(`Supprimer la carte du monde « ${wm.names.fr || wm.name} » ? (son fichier est gardé en .bak)`)) return;
    S.ctx.worldmaps = S.ctx.worldmaps.filter((w) => w !== wm);
    S.wmChanged.delete(wm.id);
    if (wm.file) S.wmDeleted.push(wm.id);
    delete S.config.regions[String(wm.id)];
    S.wm = S.ctx.worldmaps[0] ? S.ctx.worldmaps[0].id : null;
    render();
  }
  function renderPaintBar(wm) {
    const cells = cellsOf(wm);
    const zones = S.ctx.zones.map((z) => [z.id, `${z.name || z.db} (zone ${z.id})${cells[z.id] ? ` · ${cells[z.id].length} case${cells[z.id].length > 1 ? 's' : ''}` : ''}`]);
    const cur = S.paintZone != null && S.paintZone >= 0 ? zoneOf(S.paintZone) : null;
    return h('div', { class: 'pjcr-paintbar' },
      h('span', { class: 'pjcr-dot big', style: { background: cur ? `hsl(${hue(cur.id)},70%,55%)` : 'transparent' } }),
      picker(zones, cur ? cur.id : '', (v) => set(() => { S.paintZone = v === '' ? null : int(v); }), '— zone à peindre —'),
      h('button', { class: 'pjs-btn small ' + (S.paintZone === -1 ? 'primary' : 'secondary'), onclick: () => set(() => { S.paintZone = -1; }) }, 'Gomme'),
      cur ? h('button', { class: 'pjs-btn small secondary', title: 'Effacer toutes les cases de cette zone sur cette carte', onclick: () => { if (confirm(`Effacer ${cur.name} de cette carte ?`)) set(() => { wm.grid.forEach((row) => row.forEach((v, x) => { if (v === cur.id) row[x] = -1; })); S.wmChanged.add(wm.id); }); } }, 'Effacer cette zone') : null);
  }

  function renderRegionGeneral(wm, r) {
    const box = block('Région', h('button', { class: 'pjs-btn small danger', onclick: () => deleteWorldmap(wm) }, 'Supprimer'));
    wm.names = wm.names || { fr: wm.name || '', en: '' };
    const [gw, gh] = gridSize(wm);
    box.appendChild(h('div', { class: 'pjcr-grid2' },
      field('Nom (français)', textInput(wm.names.fr, (v) => { wm.names.fr = v; wm.name = v || wm.db; S.wmChanged.add(wm.id); const n = root.querySelector('.pjcr-entry.active .pjcr-name'); if (n) n.textContent = wm.name; }, { 'data-focus': 'wmfr' })),
      field('Nom (anglais)', textInput(wm.names.en, (v) => { wm.names.en = v; S.wmChanged.add(wm.id); }, { 'data-focus': 'wmen', placeholder: wm.names.fr }))));
    box.appendChild(h('div', { class: 'pjcr-grid2' },
      field('Image de la carte', h('div', { class: 'pjcr-inline-row' },
        select([['', '— aucune —']].concat(S.ctx.mapImages.map((n) => [n, n])), (wm.image || '').replace(/^worldmap\/worldmaps\//, ''), (v) => setImage(wm, v)),
        h('button', { class: 'pjs-btn small secondary', onclick: () => importImage('worldmaps', (n) => setImage(wm, n)) }, 'Importer…')), 'graphics/interface/worldmap/worldmaps'),
      h('div', { class: 'pjcr-field' }, h('span', { class: 'pjs-label' }, 'Grille'), h('span', { class: 'pjs-hint inline' }, `${gw} × ${gh} cases de 8 px · n° ${wm.id}${S.wmChanged.has(wm.id) ? ' · modifiée' : ''}`))));
    const themes = [['', `Thème général (${THEME_NAMES[settings().theme] || settings().theme})`]].concat(S.ctx.themes.map((t) => [t, THEME_NAMES[t] || t]));
    box.appendChild(h('div', { class: 'pjcr-grid2' },
      field('Thème de l\'écran', select(themes, r.theme || '', (v) => set(() => { r.theme = v; })), 'pour cette région seulement'),
      h('div', { class: 'pjcr-field pjcr-end' }, check('Montrer le joueur', r.show_player !== false, (v) => { r.show_player = v; }))));
    r.music = Object.assign({ name: '', volume: 100, pitch: 100 }, r.music || {});
    box.appendChild(h('div', { class: 'pjcr-grid3' },
      field('Musique (audio/bgm)', textInput(r.music.name, (v) => { r.music.name = v; }, { 'data-focus': 'music', placeholder: 'garder la musique' })),
      field('Volume', numInput(r.music.volume, (v) => { r.music.volume = int(v, 100); }, { min: 0, max: 100, 'data-focus': 'vol' })),
      field('Hauteur', numInput(r.music.pitch, (v) => { r.music.pitch = int(v, 100); }, { min: 50, max: 150, 'data-focus': 'pitch' }))));
    box.appendChild(h('div', { class: 'pjs-hint' }, `Version selon l'heure : ajoute une image « _matin », « _jour », « _soir » ou « _nuit » au même nom (option « Carte selon l'heure »).`));
    return box;
  }

  function renderConnections(wm, r) {
    const box = block('Régions reliées', h('button', { class: 'pjs-btn small secondary', disabled: S.ctx.worldmaps.length < 2, onclick: () => set(() => { r.connections.push({ side: 'right', worldmap: (S.ctx.worldmaps.find((w) => w.id !== wm.id) || {}).id, offset: 0 }); }) }, '+ Liaison'));
    if (!r.connections.length) box.appendChild(h('div', { class: 'pjs-hint' }, 'Le curseur qui sort par un bord peut continuer sur une autre carte du monde (ex. deux moitiés d\'une même région).'));
    r.connections.forEach((cn, i) => {
      box.appendChild(h('div', { class: 'pjcr-inline-row' },
        h('span', { class: 'pjs-hint inline' }, 'Bord'),
        select(SIDES, cn.side, (v) => set(() => { cn.side = v; })),
        h('span', { class: 'pjs-hint inline' }, 'mène à'),
        select(S.ctx.worldmaps.filter((w) => w.id !== wm.id).map((w) => [w.id, w.name || w.db]), cn.worldmap, (v) => set(() => { cn.worldmap = int(v); })),
        h('span', { class: 'pjs-hint inline' }, 'décalage'),
        numInput(cn.offset, (v) => { cn.offset = int(v); }, { class: 'pjs-input pjcr-small', 'data-focus': `off-${i}` }),
        h('button', { class: 'pjcr-x', title: 'Retirer', onclick: () => set(() => { r.connections.splice(i, 1); }) }, '✕')));
    });
    return box;
  }

  function renderRegionList(wm, r) {
    if (LIST_KEY[S.tool]) S.listKind = S.tool;
    const kind = S.tool === 'select' && S.sel ? S.sel.kind : (S.listKind || 'district');
    const tabs = h('div', { class: 'pjcr-tabs' }, [['district', `Quartiers (${r.districts.length})`], ['decoration', `Décorations (${r.decorations.length})`], ['quest', `Quêtes (${r.quests.length})`], ['trainer', `Revanches (${r.trainers.length})`]].map(([k, l]) =>
      h('button', { class: 'pjs-btn small ' + (kind === k ? 'primary' : 'secondary'), onclick: () => set(() => { S.tool = k; S.sel = null; }) }, l)));
    const box = block('Éléments de la région', tabs);
    const list = r[LIST_KEY[kind]];
    if (!list.length) box.appendChild(h('div', { class: 'pjs-hint' }, {
      district: 'Aucun quartier. Choisis l\'outil Quartier et fais glisser sur la carte.',
      decoration: 'Aucune décoration. Ajoute des images dans graphics/interface/carte_region/decorations (bouton Importer) puis clique sur la carte avec l\'outil Décoration. Une décoration avec interrupteur sert aussi de zone cachée qui apparaît plus tard.',
      quest: 'Aucune quête placée. Outil Quête puis clic sur la carte.',
      trainer: 'Aucun dresseur. Outil Revanche puis clic sur la carte. Son icône apparaît quand l\'interrupteur est activé (revanche prête).',
    }[kind]));
    list.forEach((item, i) => box.appendChild(renderItem(kind, item, i, list)));
    if (kind === 'decoration') box.appendChild(h('div', { class: 'pjcr-actions pjcr-mt' }, h('button', { class: 'pjs-btn small secondary', onclick: () => importImage('decorations', () => toast('Image ajoutée')) }, 'Importer une image…')));
    return box;
  }

  function renderItem(kind, item, i, list) {
    const selected = S.sel && S.sel.kind === kind && S.sel.index === i;
    const pos = (withSize) => [
      h('label', null, 'x', numInput(item.x, (v) => { item.x = int(v); }, { class: 'pjs-input pjcr-small', 'data-focus': `${kind}-x-${i}` })),
      h('label', null, 'y', numInput(item.y, (v) => { item.y = int(v); }, { class: 'pjs-input pjcr-small', 'data-focus': `${kind}-y-${i}` })),
      withSize ? h('label', null, 'l', numInput(item.w, (v) => { item.w = Math.max(1, int(v, 1)); }, { class: 'pjs-input pjcr-small', 'data-focus': `${kind}-w-${i}` })) : null,
      withSize ? h('label', null, 'h', numInput(item.h, (v) => { item.h = Math.max(1, int(v, 1)); }, { class: 'pjs-input pjcr-small', 'data-focus': `${kind}-h-${i}` })) : null,
    ];
    const tools = h('span', { class: 'pjcr-itemtools' },
      h('button', { class: 'pjs-btn small ' + (selected ? 'primary' : 'secondary'), title: 'Choisir (puis clic sur la carte pour déplacer)', onclick: () => set(() => { S.sel = selected ? null : { kind, index: i }; if (!selected) S.tool = kind; }) }, selected ? 'Choisi' : 'Placer'),
      h('button', { class: 'pjcr-x', title: 'Retirer', onclick: () => set(() => { list.splice(i, 1); S.sel = null; }) }, '✕'));
    let fields;
    if (kind === 'district') {
      item.name = loc(item.name);
      fields = [textInput(item.name.fr, (v) => { item.name.fr = v; }, { placeholder: 'Nom (français)', 'data-focus': `dn-${i}` }), textInput(item.name.en, (v) => { item.name.en = v; }, { placeholder: 'Name (English)', 'data-focus': `de-${i}` }), h('span', { class: 'pjcr-pos' }, pos(true))];
    } else if (kind === 'decoration') {
      fields = [iconSpan(item.image ? `${GFX}/decorations/${item.image}` : null, 'pjcr-ico'),
        select([['', '— image —']].concat(S.ctx.decorations.map((d) => [d, d])), item.image, (v) => set(() => { item.image = v; })),
        h('span', { class: 'pjcr-pos' }, pos(false)),
        h('label', null, 'Interr.', numInput(item.switch || '', (v) => { item.switch = int(v); }, { class: 'pjs-input pjcr-small', placeholder: '—', 'data-focus': `dsw-${i}` })),
        check('Au-dessus', item.above, (v) => { item.above = v; }, 'au-dessus des lieux non visités (sinon dessous)')];
    } else if (kind === 'quest') {
      fields = [iconSpan(`${GFX}/icons/${item.color ? 'quest_' + item.color : 'quest'}`, 'pjcr-ico'),
        select([['', '— quête —']].concat(S.ctx.quests.map((q) => [q.db, `${q.name} (${q.db})`])), item.quest, (v) => set(() => { item.quest = v; })),
        select(QUEST_COLORS, item.color || '', (v) => set(() => { item.color = v; })),
        h('span', { class: 'pjcr-pos' }, pos(false))];
    } else {
      item.name = loc(item.name); item.text = loc(item.text);
      fields = [iconSpan(item.character ? `graphics/characters/${item.character}` : `${GFX}/icons/trainer`, 'pjcr-ico', !!item.character),
        textInput(item.name.fr, (v) => { item.name.fr = v; }, { placeholder: 'Nom du dresseur', 'data-focus': `tn-${i}` }),
        picker(S.ctx.characters.map((n) => [n, n]), item.character, (v) => set(() => { item.character = v; }), '— icône par défaut —'),
        h('span', { class: 'pjcr-pos' }, pos(false)),
        h('label', null, 'Interr.', numInput(item.switch || '', (v) => { item.switch = int(v); }, { class: 'pjs-input pjcr-small', placeholder: '—', 'data-focus': `tsw-${i}` })),
        h('div', { class: 'pjcr-fullrow pjcr-grid2' },
          textInput(item.text.fr, (v) => { item.text.fr = v; }, { placeholder: 'Phrase (français) : Ce dresseur veut une revanche !', 'data-focus': `ttf-${i}` }),
          textInput(item.text.en, (v) => { item.text.en = v; }, { placeholder: 'Text (English)', 'data-focus': `tte-${i}` }))];
    }
    return h('div', { class: 'pjcr-item' + (selected ? ' sel' : '') + ' ' + kind }, fields, tools);
  }

  function renderCommands() {
    const cmds = [
      ['carte_region', 'ouvre la carte de la région du joueur (l\'objet Carte et Vol ouvrent aussi cette carte)'],
      ['carte_region(1)', 'ouvre la carte du monde n° 1'],
      ['carte_region_vol', 'carte en mode Vol'],
      ['carte_murale', 'carte murale : on regarde seulement'],
      ['carte_region_progression', 'pourcentage de lieux visités (0 à 100)'],
    ];
    return block('Commandes d\'évènement (Script)', null, h('div', { class: 'pjcr-cmds' }, cmds.map(([c, hint]) => h('div', { class: 'pjcr-cmdrow' },
      h('code', { class: 'pjcr-cmd', title: 'Cliquer pour copier', onclick: () => copy(c) }, c), h('span', { class: 'pjs-hint inline' }, hint)))));
  }

  // ---------------------------------------------------------------------------
  // Onglet Lieux (zones)
  // ---------------------------------------------------------------------------
  function renderZones(body) {
    const side = h('div', { class: 'pjcr-side' });
    side.appendChild(h('input', { class: 'pjs-input', placeholder: 'Rechercher un lieu…', value: S.zoneSearch, 'data-focus': 'zsearch', oninput: (e) => { S.zoneSearch = e.target.value; render(); } }));
    const list = h('div', { class: 'pjcr-list', 'data-scroll': 'zonelist' });
    const onMaps = new Set(zonesOnMaps().map((z) => z.id));
    const q = plain(S.zoneSearch);
    const zones = S.ctx.zones.filter((z) => !q || plain(z.name).includes(q) || String(z.id) === q);
    const group = (title, arr) => {
      if (!arr.length) return;
      list.appendChild(h('div', { class: 'pjcr-group' }, title));
      arr.forEach((z) => {
        const cfg = S.config.zones[String(z.id)] || {};
        const has = (cfg.description && (cfg.description.fr || cfg.description.en)) || cfg.image;
        list.appendChild(h('div', { class: 'pjcr-entry' + (z.id === S.zone ? ' active' : ''), onclick: () => set(() => { S.zone = z.id; }) },
          h('span', { class: 'pjcr-dot', style: { background: `hsl(${hue(z.id)},70%,55%)` } }),
          h('span', { class: 'pjcr-ename' }, h('span', { class: 'pjcr-name' }, z.name || z.db),
            h('span', { class: 'pjcr-sub' }, `zone ${z.id}${z.warp ? ' · vol' : ''}${z.groups ? ` · ${z.groups} groupe${z.groups > 1 ? 's' : ''}` : ''}${cfg.switch ? ' · cachée' : ''}`)),
          has ? h('span', { class: 'pjcr-badge' }, '✎') : null));
      });
    };
    group('Sur une carte du monde', zones.filter((z) => onMaps.has(z.id)));
    group('Pas encore sur une carte', zones.filter((z) => !onMaps.has(z.id)));
    side.appendChild(list);
    body.appendChild(side);
    const detail = h('div', { class: 'pjcr-detail', 'data-scroll': 'zonedetail' });
    body.appendChild(detail);
    const content = h('div', { class: 'pjcr-content' });
    detail.appendChild(content);
    warnings(content);
    const z = zoneOf(S.zone);
    if (!z) { content.appendChild(h('div', { class: 'pjs-empty' }, 'Choisis un lieu.')); return; }
    const cfg = zoneCfg(z.id);
    cfg.description = loc(cfg.description);
    const wms = S.ctx.worldmaps.filter((w) => cellsOf(w)[z.id]);
    const row = h('div', { class: 'pjcr-row' });
    content.appendChild(row);
    const left = h('div', { class: 'pjcr-right' });
    row.appendChild(left);
    const box = block(z.name || z.db);
    box.appendChild(h('div', { class: 'pjs-hint' }, `Zone ${z.id} (${z.db}) · cartes ${z.maps.join(', ') || '—'} · ${wms.length ? 'sur ' + wms.map((w) => w.name).join(', ') : 'pas encore peinte sur une carte du monde (onglet Régions, outil Zones)'}${z.warp ? ' · point de vol réglé' : ' · pas de point de vol'}${z.weather ? ' · météo : ' + WEATHERS[z.weather] : ''}`));
    box.appendChild(field('Description (français)', h('textarea', { class: 'pjs-input pjcr-area', rows: 3, 'data-focus': 'zdfr', value: cfg.description.fr, oninput: (e) => soft(() => { cfg.description.fr = e.target.value; }) })));
    box.appendChild(field('Description (anglais)', h('textarea', { class: 'pjs-input pjcr-area', rows: 3, 'data-focus': 'zden', placeholder: cfg.description.fr, value: cfg.description.en, oninput: (e) => soft(() => { cfg.description.en = e.target.value; }) })));
    box.appendChild(h('div', { class: 'pjcr-grid2' },
      field('Image de l\'aperçu', h('div', { class: 'pjcr-inline-row' },
        select([['', '— aucune —']].concat(S.ctx.images.map((n) => [n, n])), cfg.image || '', (v) => set(() => { cfg.image = v; })),
        h('button', { class: 'pjs-btn small secondary', onclick: () => importImage('lieux', (n) => set(() => { cfg.image = n; })) }, 'Importer…')), 'graphics/interface/carte_region/lieux (environ 64 × 48)'),
      field('Cachée tant que l\'interrupteur est éteint', numInput(cfg.switch || '', (v) => { cfg.switch = int(v); }, { min: 0, placeholder: 'toujours visible', 'data-focus': 'zsw' }), 'n° d\'interrupteur (lieu secret)')));
    left.appendChild(box);
    const prev = h('div', { class: 'pjs-block pjcr-previewblock' }, h('div', { class: 'pjs-block-head' }, h('h2', null, 'Aperçu en jeu')));
    const cv = h('canvas', { class: 'pjcr-preview', width: 320, height: 240 });
    prev.appendChild(cv);
    prev.appendChild(h('div', { class: 'pjs-hint' }, 'A sur le lieu ouvre cet aperçu ; A encore ouvre la fiche détaillée (Pokémon sauvages par type, progression).'));
    row.appendChild(prev);
    drawZonePreview(cv, z, cfg, wms[0]);
    if (wms[0]) {
      const mapBox = block('Sur la carte : ' + wms[0].name);
      renderCanvas(mapBox, wms[0], { wm: wms[0], zone: z.id, onDown: (x, y) => { const id = (wms[0].grid[y] || [])[x]; if (id != null && id >= 0) set(() => { S.zone = id; }); } });
      content.appendChild(mapBox);
    }
  }

  async function drawZonePreview(cv, z, cfg, wm) {
    const theme = (wm && (S.config.regions[String(wm.id)] || {}).theme) || settings().theme || 'horizon';
    const [bg, box, barT, barB, cursor, image, weather, band, back] = await Promise.all([
      wm && wm.image ? loadImage(`graphics/interface/${wm.image}`) : null,
      loadImage(`${GFX}/themes/${theme}/box`), loadImage(`${GFX}/themes/${theme}/bar_top`), loadImage(`${GFX}/themes/${theme}/bar_bottom`),
      loadImage(`${GFX}/themes/${theme}/cursor`), cfg.image ? loadImage(`${GFX}/lieux/${cfg.image}`) : null,
      z.weather ? loadImage(`${GFX}/icons/weather_${WEATHER_ICON[z.weather]}`) : null,
      loadImage(`${GFX}/themes/${theme}/title`), loadImage(`${GFX}/themes/${theme}/background`),
    ]);
    const c = cv.getContext('2d');
    c.imageSmoothingEnabled = false;
    c.fillStyle = '#e5f3fa'; c.fillRect(0, 0, 320, 240);
    if (back) c.drawImage(back, 0, 0);
    // carte centrée sur le lieu
    let cx = 160; let cy = 120;
    if (wm) {
      const cells = cellsOf(wm)[z.id] || [];
      const mx = cells.length ? cells.reduce((a, p) => a + p[0], 0) / cells.length : 0;
      const my = cells.length ? cells.reduce((a, p) => a + p[1], 0) / cells.length : 0;
      const ox = Math.round(160 - (mx * TILE + 4)); const oy = Math.round(117 - (my * TILE + 4));
      if (bg) c.drawImage(bg, ox, oy);
      c.fillStyle = 'rgba(255,255,255,.35)';
      cells.forEach(([x, y]) => c.fillRect(ox + x * TILE, oy + y * TILE, TILE, TILE));
      cx = ox + mx * TILE + 4; cy = oy + my * TILE + 4;
    }
    if (cursor) c.drawImage(cursor, 0, 0, 22, 22, Math.round(cx - 11), Math.round(cy - 11), 22, 22);
    const nine = (im, x, y, w, hh, b = 8) => {
      if (!im) return;
      const sw = im.width; const sh = im.height;
      c.drawImage(im, 0, 0, b, b, x, y, b, b); c.drawImage(im, sw - b, 0, b, b, x + w - b, y, b, b);
      c.drawImage(im, 0, sh - b, b, b, x, y + hh - b, b, b); c.drawImage(im, sw - b, sh - b, b, b, x + w - b, y + hh - b, b, b);
      c.drawImage(im, b, 0, sw - 2 * b, b, x + b, y, w - 2 * b, b); c.drawImage(im, b, sh - b, sw - 2 * b, b, x + b, y + hh - b, w - 2 * b, b);
      c.drawImage(im, 0, b, b, sh - 2 * b, x, y + b, b, hh - 2 * b); c.drawImage(im, sw - b, b, b, sh - 2 * b, x + w - b, y + b, b, hh - 2 * b);
      c.drawImage(im, b, b, sw - 2 * b, sh - 2 * b, x + b, y + b, w - 2 * b, hh - 2 * b);
    };
    nine(barT, 0, 0, 320, 20); nine(barB, 0, 214, 320, 26);
    const centered = theme === 'horizon';
    const text = (s, x, y, o = {}) => { c.font = `${o.small ? 9 : 11}px "Avenir Next", sans-serif`; c.textAlign = o.align || 'left'; c.textBaseline = 'top'; c.fillStyle = 'rgba(0,0,0,.5)'; c.fillText(s, x + 1, y + 1); c.fillStyle = '#fff'; c.fillText(s, x, y); };
    if (centered) text(wm ? wm.name : '', 160, 4, { align: 'center' }); else text(wm ? wm.name : '', 8, 4);
    text(z.name, 8, 220);
    // boîte d'aperçu
    c.font = '9px "Avenir Next", sans-serif';
    const imgW = image ? image.width + 8 : 0;
    const maxW = 308 - 20 - imgW;
    const lines = [];
    (txt(cfg.description) || '').split('\n').forEach((para) => {
      let line = '';
      para.split(' ').forEach((w) => { const t = line ? line + ' ' + w : w; if (c.measureText(t).width > maxW && line) { lines.push(line); line = w; } else line = t; });
      if (line) lines.push(line);
    });
    const shown = lines.slice(0, Math.max(1, int(settings().max_description_lines, 3)));
    shown.push('A : fiche détaillée');
    const content = Math.max(shown.length * 13, image ? image.height : 0);
    const bh = 30 + content + 8; const by = 214 - bh - 2;
    nine(box, 6, by, 308, bh);
    if (band) nine(band, 9, by + 3, 302, 18, 4);
    text(z.name, 16, by + 3);
    if (weather) { c.drawImage(weather, 6 + 308 - 26, by + 4); text(WEATHERS[z.weather], 6 + 308 - 30, by + 6, { small: true, align: 'right' }); }
    if (image) c.drawImage(image, 16, by + 26);
    shown.forEach((l, i) => text(l, 16 + imgW, by + 24 + i * 13, { small: true }));
  }

  // ---------------------------------------------------------------------------
  // Onglet Réglages
  // ---------------------------------------------------------------------------
  function colorField(label, arr, onChange) {
    const a = Array.isArray(arr) ? arr : [0, 0, 0, 100];
    const hex = '#' + a.slice(0, 3).map((v) => int(v).toString(16).padStart(2, '0')).join('');
    return field(label, h('div', { class: 'pjcr-inline-row' },
      h('input', { type: 'color', class: 'pjcr-color', value: hex, oninput: (e) => soft(() => { const v = e.target.value; onChange([parseInt(v.slice(1, 3), 16), parseInt(v.slice(3, 5), 16), parseInt(v.slice(5, 7), 16), int(a[3], 100)]); }) }),
      h('span', { class: 'pjs-hint inline' }, 'opacité'),
      numInput(a[3], (v) => { onChange([a[0], a[1], a[2], Math.max(0, Math.min(255, int(v)))]); }, { class: 'pjs-input pjcr-small', min: 0, max: 255 })));
  }
  function renderSettings(body) {
    const st = settings();
    const detail = h('div', { class: 'pjcr-detail', 'data-scroll': 'settings' });
    body.appendChild(detail);
    const content = h('div', { class: 'pjcr-content narrow' });
    detail.appendChild(content);
    warnings(content);
    const general = block('Général');
    general.appendChild(h('div', { class: 'pjcr-checks' },
      check('Remplacer la carte de PSDK', st.replace_town_map, (v) => { st.replace_town_map = v; }, 'objet Carte, Vol depuis l\'équipe et open_town_map ouvrent cette carte'),
      check('Souris', st.mouse, (v) => { st.mouse = v; }), check('Zoom (L / R, molette)', st.zoom, (v) => { st.zoom = v; }),
      check('Montrer le joueur', st.show_player, (v) => { st.show_player = v; }), check('Carte selon l\'heure', st.time_based, (v) => { st.time_based = v; }),
      check('Musique des régions', st.music, (v) => { st.music = v; }), check('Boîte des touches', st.button_hints, (v) => { st.button_hints = v; })));
    const themes = S.ctx.themes.map((t) => [t, THEME_NAMES[t] || t]);
    general.appendChild(h('div', { class: 'pjcr-grid3' },
      field('Thème', select(themes, st.theme, (v) => set(() => { st.theme = v; }))),
      field('Variable du thème', numInput(st.theme_variable || '', (v) => { st.theme_variable = int(v); }, { min: 0, placeholder: 'aucune', 'data-focus': 'thv' }), 'thème choisi par le joueur : 1 = horizon, 2 = rouge, 3 = bleu, 4 = vert, 5 = sombre, 6 = violet'),
      field('Vitesse du curseur', numInput(st.cursor_frames, (v) => { st.cursor_frames = Math.max(1, int(v, 5)); }, { min: 1, max: 20, 'data-focus': 'cf' }), 'images par case (1 = instantané)')));
    general.appendChild(h('div', { class: 'pjcr-themes' }, S.ctx.themes.map((t) => h('div', { class: 'pjcr-theme' + (st.theme === t ? ' on' : ''), onclick: () => set(() => { st.theme = t; }) },
      iconSpan(`${GFX}/themes/${t}/box`, 'pjcr-swatch'), h('span', null, THEME_NAMES[t] || t)))));
    content.appendChild(general);

    const places = block('Lieux');
    places.appendChild(h('div', { class: 'pjcr-checks' },
      check('Assombrir les lieux pas encore visités', st.mark_unvisited, (v) => { st.mark_unvisited = v; }),
      check('Montrer le vrai nom des lieux pas visités', st.show_unvisited_names, (v) => { st.show_unvisited_names = v; }),
      check('Éclairer le lieu sous le curseur', st.highlight, (v) => { st.highlight = v; })));
    st.unvisited_text = loc(st.unvisited_text);
    places.appendChild(h('div', { class: 'pjcr-grid4' },
      field('Nom d\'un lieu pas visité', textInput(st.unvisited_text.fr, (v) => { st.unvisited_text.fr = v; }, { 'data-focus': 'uvfr' })),
      field('(anglais)', textInput(st.unvisited_text.en, (v) => { st.unvisited_text.en = v; }, { 'data-focus': 'uven' })),
      colorField('Couleur des lieux pas visités', st.unvisited_color, (v) => { st.unvisited_color = v; }),
      colorField('Couleur du lieu éclairé', st.highlight_color, (v) => { st.highlight_color = v; })));
    content.appendChild(places);

    const preview = block('Aperçu des lieux (A)');
    preview.appendChild(h('div', { class: 'pjcr-checks' },
      check('Aperçu', st.preview, (v) => { st.preview = v; }), check('Animation', st.preview_animation, (v) => { st.preview_animation = v; }),
      check('Fiche détaillée', st.extended_preview, (v) => { st.extended_preview = v; }), check('Météo de la zone', st.weather_preview, (v) => { st.weather_preview = v; }),
      check('Progression (SELECT, %)', st.progress, (v) => { st.progress = v; })));
    preview.appendChild(h('div', { class: 'pjcr-grid3' },
      field('Lignes de description', numInput(st.max_description_lines, (v) => { st.max_description_lines = Math.max(1, Math.min(8, int(v, 3))); }, { min: 1, max: 8, 'data-focus': 'mdl' })),
      field('Choix visibles à la fois', numInput(st.max_choices, (v) => { st.max_choices = Math.max(2, Math.min(12, int(v, 6))); }, { min: 2, max: 12, 'data-focus': 'mc' }), 'listes de vol, de recherche…')));
    content.appendChild(preview);

    const search = block('Recherche et vol');
    search.appendChild(h('div', { class: 'pjcr-checks' },
      check('Recherche de lieu (Y)', st.search, (v) => { st.search = v; }), check('Lieux pas visités dans la recherche', st.search_unvisited, (v) => { st.search_unvisited = v; }),
      check('Voler depuis la carte', st.fly_from_map, (v) => { st.fly_from_map = v; }, 'si un Pokémon de l\'équipe connaît Vol et que l\'endroit le permet'),
      check('Vol rapide (Y en mode Vol)', st.quick_fly, (v) => { st.quick_fly = v; }), check('Curseur automatique (vol rapide)', st.auto_cursor, (v) => { st.auto_cursor = v; }),
      check('Voler vers une autre région', st.fly_other_regions, (v) => { st.fly_other_regions = v; })));
    search.appendChild(h('div', { class: 'pjcr-grid3' }, field('Lieux minimum pour la recherche', numInput(st.search_min, (v) => { st.search_min = Math.max(0, int(v, 3)); }, { min: 0, 'data-focus': 'smin' }))));
    content.appendChild(search);

    const modes = block('Modes de la carte (X)');
    modes.appendChild(h('div', { class: 'pjcr-checks' },
      [['fly', 'Vol'], ['quest', 'Quêtes'], ['berry', 'Baies plantées'], ['roaming', 'Pokémon errants'], ['trainer', 'Revanches']].map(([k, l]) => check(l, st.modes[k], (v) => { st.modes[k] = v; }))));
    modes.appendChild(h('div', { class: 'pjs-hint' }, 'Un mode n\'apparaît que s\'il a quelque chose à montrer (quête en cours placée sur la carte, baie plantée, Pokémon errant, revanche prête…).'));
    content.appendChild(modes);
    content.appendChild(renderCommands());
  }

  // ---------------------------------------------------------------------------
  // Onglet Lieux fictifs
  // ---------------------------------------------------------------------------
  function renderFake(body) {
    const detail = h('div', { class: 'pjcr-detail', 'data-scroll': 'fake' });
    body.appendChild(detail);
    const content = h('div', { class: 'pjcr-content narrow' });
    detail.appendChild(content);
    warnings(content);
    const list = S.config.fake_locations;
    const box = block('Lieux fictifs', h('button', { class: 'pjs-btn small secondary', onclick: () => set(() => { list.push({ map_id: 1, variable: 0, value: 0, worldmap: (S.ctx.worldmaps[0] || {}).id || 0, x: 0, y: 0 }); }) }, '+ Lieu fictif'));
    box.appendChild(h('div', { class: 'pjs-hint' }, 'Sur la carte n° X (et si la variable vaut la valeur, quand une variable est donnée), le joueur est montré à cette case — par exemple dans un bateau, un train ou un lieu qui change de place.'));
    if (list.length) box.appendChild(h('div', { class: 'pjcr-fhead' }, ['Carte n°', 'Variable', 'Valeur', 'Carte du monde', 'x', 'y', ''].map((t) => h('span', null, t))));
    list.forEach((f, i) => box.appendChild(h('div', { class: 'pjcr-frow' },
      numInput(f.map_id, (v) => { f.map_id = int(v); }, { min: 1, 'data-focus': `fm-${i}` }),
      numInput(f.variable || '', (v) => { f.variable = int(v); }, { min: 0, placeholder: '—', 'data-focus': `fv-${i}` }),
      numInput(f.value, (v) => { f.value = int(v); }, { 'data-focus': `fval-${i}` }),
      select(S.ctx.worldmaps.map((w) => [w.id, w.name || w.db]), f.worldmap, (v) => set(() => { f.worldmap = int(v); })),
      numInput(f.x, (v) => { f.x = int(v); }, { min: 0, 'data-focus': `fx-${i}` }),
      numInput(f.y, (v) => { f.y = int(v); }, { min: 0, 'data-focus': `fy-${i}` }),
      h('button', { class: 'pjcr-x', title: 'Retirer', onclick: () => set(() => { list.splice(i, 1); }) }, '✕'))));
    content.appendChild(box);
  }

  // ---------------------------------------------------------------------------
  // Page : Level design > Carte de région (/database/region-map)
  // ---------------------------------------------------------------------------
  function mount(hostEl) {
    root = h('div', { id: 'pjcr-root' });
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
  window.addEventListener('mouseup', onUp);
  window.addEventListener('keydown', (e) => {
    if (!S.open) return;
    if (e.ctrlKey && e.key.toLowerCase() === 's') { e.preventDefault(); e.stopPropagation(); save(); }
  }, true);
  setInterval(() => { if (S.open) updateStatus(); }, 1000);

  window.pjCarteRegionEditor = { state: S, render };
})();
