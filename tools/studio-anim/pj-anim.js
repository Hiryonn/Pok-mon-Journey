/* eslint-disable */
// =============================================================================
// Animations des attaques — page « Données > Attaques > Animations » de Pokémon Studio
//   À gauche les attaques, au centre l'aperçu du combat (320 x 240) et la ligne de temps, à droite les réglages.
//   Une animation = des calques (une image de graphics/animations découpée en cases, avec des clés dans le temps)
//   + des évènements (son, flash, tremblement, élan, cacher / montrer un Pokémon).
// Enregistre Data/studio_animations/moves/<attaque>.json, joué en jeu par scripts/90001 StudioAnimations.rb.
// Style de l'éditeur Smartphone (classes pjs-*).
// =============================================================================
(() => {
  'use strict';
  if (window.__pjAnimLoaded) return;
  window.__pjAnimLoaded = true;

  const PAGE_ID = 'move-animations';
  const W = 320; const H = 240; const SCALE = 2;
  const STEP = 0.05; // grille de la ligne de temps (s)
  const USER_POS = [78, 184]; const TARGET_POS = [242, 138];
  const ANCHORS = [['target', 'Cible'], ['user', 'Lanceur'], ['path', 'Trajet lanceur → cible'], ['screen', 'Écran']];
  const BLENDS = [['0', 'Normal'], ['1', 'Addition (lumière)'], ['2', 'Soustraction']];
  const EVENT_TYPES = [['se', 'Son'], ['flash', 'Flash'], ['shake', 'Tremblement'], ['move', 'Élan'], ['hide', 'Cacher'], ['show', 'Montrer']];
  const EVENT_LABEL = Object.fromEntries(EVENT_TYPES);
  const ON = [['target', 'Cible'], ['user', 'Lanceur'], ['screen', 'Écran']];
  const CAT = { physical: 'Physique', special: 'Spéciale', status: 'Statut' };

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------
  const api = window.pjAnim;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API Animations n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  // minuscules sans accents (recherche)
  const plain = (t) => String(t || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const round3 = (v) => Math.round(v * 1000) / 1000;
  const snap = (t) => round3(Math.round(t / STEP) * STEP);
  let toastTimer = null;
  function toast(msg, err) {
    document.querySelectorAll('.pjs-toast').forEach((t) => t.remove());
    const t = h('div', { class: 'pjs-toast' + (err ? ' err' : '') }, msg);
    document.body.appendChild(t);
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.remove(), err ? 6000 : 2500);
  }
  const projectList = () => { try { return JSON.parse(localStorage.getItem('projectList') || '[]'); } catch (e) { return []; } };
  const prefs = (() => { try { return JSON.parse(localStorage.getItem('pjAnimPrefs') || '{}'); } catch (e) { return {}; } })();
  const savePrefs = () => { try { localStorage.setItem('pjAnimPrefs', JSON.stringify(prefs)); } catch (e) { /* rien */ } };
  // fait défiler seulement la liste qui contient l'élément (scrollIntoView ferait défiler la fenêtre de Studio)
  function scrollInto(el) {
    const box = el.parentElement;
    if (!box) return;
    const b = box.getBoundingClientRect(); const r = el.getBoundingClientRect();
    if (r.top < b.top) box.scrollTop -= b.top - r.top;
    else if (r.bottom > b.bottom) box.scrollTop += r.bottom - b.bottom;
  }

  // Images et sons du projet (data URL), gardés en mémoire
  const files = new Map();
  function fileUrl(rel) {
    if (!files.has(rel)) files.set(rel, call('readFile', { projectPath: S.projectPath, file: rel }).catch(() => null));
    return files.get(rel);
  }
  const images = new Map();
  function image(rel) {
    if (images.has(rel)) return images.get(rel);
    const entry = { img: null, ready: false };
    images.set(rel, entry);
    fileUrl(rel).then((url) => {
      if (!url) { entry.ready = true; return; }
      const im = new Image();
      im.onload = () => { entry.img = im; entry.ready = true; draw(); refreshCells(); };
      im.onerror = () => { entry.ready = true; };
      im.src = url;
    });
    return entry;
  }
  function playSe(ev) {
    if (!ev.name) return;
    fileUrl('audio/se/' + ev.name).then((url) => {
      if (!url) return;
      try {
        const a = new Audio(url);
        a.volume = clamp((ev.volume ?? 100) / 100, 0, 1);
        a.playbackRate = clamp((ev.pitch ?? 100) / 100, 0.5, 2);
        a.play().catch(() => {});
      } catch (e) { /* rien */ }
    });
  }

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const S = {
    open: false, projectPath: null, ctx: null, error: null, query: '', filter: prefs.filter || '',
    sel: null, doc: null, saved: null, undo: [], redo: [], loading: false,
    t: 0, playing: false, loop: !!prefs.loop, layer: -1, key: -1, event: -1, pxs: prefs.pxs || 200,
    preview: Object.assign({ bg: 'back_building', user: '0006', target: '0025', reverse: false }, prefs.preview || {}),
  };
  let root = null; let refs = {};
  const snapshot = () => (S.doc ? JSON.stringify(S.doc) : null);
  const dirty = () => S.doc && S.saved !== snapshot();
  const moveOf = (db) => S.ctx && S.ctx.moves.find((m) => m.db === db);
  const layer = () => (S.doc && S.layer >= 0 ? S.doc.layers[S.layer] : null);
  const key = () => { const l = layer(); return l && S.key >= 0 ? l.keys[S.key] : null; };
  const event = () => (S.doc && S.event >= 0 ? S.doc.events[S.event] : null);
  function pushUndo() { if (!S.doc) return; S.undo.push(snapshot()); if (S.undo.length > 100) S.undo.shift(); S.redo = []; }
  function undo() { if (!S.undo.length) return; S.redo.push(snapshot()); S.doc = JSON.parse(S.undo.pop()); fixSelection(); render(); }
  function redo() { if (!S.redo.length) return; S.undo.push(snapshot()); S.doc = JSON.parse(S.redo.pop()); fixSelection(); render(); }
  function fixSelection() {
    if (!S.doc) { S.layer = S.key = S.event = -1; return; }
    if (S.layer >= S.doc.layers.length) S.layer = S.doc.layers.length - 1;
    const l = layer();
    if (!l || S.key >= l.keys.length) S.key = -1;
    if (S.event >= S.doc.events.length) S.event = -1;
  }
  const newDoc = (move) => ({ klass: 'MoveAnimation', move, duration: 1, layers: [], events: [] });

  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.ctx = null; S.error = null; S.doc = null;
    files.clear(); images.clear();
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath });
      if (!S.ctx.battlebacks.includes(S.preview.bg)) S.preview.bg = S.ctx.battlebacks.find((b) => !b.includes('/')) || S.ctx.battlebacks[0] || '';
      const first = S.sel && moveOf(S.sel) ? S.sel : (S.ctx.moves.find((m) => m.has) || S.ctx.moves[0] || {}).db;
      if (first) await selectMove(first, true); else render();
    } catch (e) { S.error = e.message; render(); }
  }

  async function selectMove(db, force) {
    if (!force && dirty() && !confirm('Animations : abandonner les modifications non enregistrées de cette attaque ?')) return;
    stop();
    S.sel = db; S.doc = null; S.saved = null; S.undo = []; S.redo = []; S.t = 0; S.layer = S.key = S.event = -1;
    S.loading = true;
    render();
    try {
      const data = await call('read', { projectPath: S.projectPath, move: db });
      if (S.sel !== db) return;
      if (data) { S.doc = Object.assign(newDoc(db), data); S.saved = snapshot(); if (S.doc.layers.length) S.layer = 0; }
    } catch (e) { toast('Lecture impossible : ' + e.message, true); }
    S.loading = false;
    render();
  }

  async function save() {
    if (!S.doc || !S.sel) return;
    try {
      S.doc.move = S.sel;
      S.doc.duration = round3(Math.max(0.05, S.doc.duration));
      const r = await call('save', { projectPath: S.projectPath, move: S.sel, data: S.doc });
      S.saved = snapshot();
      const m = moveOf(S.sel); if (m) m.has = true;
      if (r.runtime) S.ctx.runtime = r.runtime;
      toast('Animation enregistrée' + (r.runtime && !r.runtime.installed ? ' — script de jeu manquant' : ''));
      render();
    } catch (e) { toast('Erreur de sauvegarde : ' + e.message, true); }
  }

  async function removeAnim() {
    if (!S.sel) return;
    const m = moveOf(S.sel);
    if (!confirm(`Supprimer l'animation Studio de « ${m ? m.name : S.sel} » ? Le jeu reprendra l'animation de PSDK.`)) return;
    try {
      await call('remove', { projectPath: S.projectPath, move: S.sel });
      if (m) m.has = false;
      S.doc = null; S.saved = null; S.layer = S.key = S.event = -1;
      render();
    } catch (e) { toast('Suppression impossible : ' + e.message, true); }
  }

  async function importRmxp() {
    const m = moveOf(S.sel);
    if (!m) return;
    if (S.doc && S.doc.layers.length + S.doc.events.length && !confirm("Remplacer l'animation actuelle par celle de RPG Maker ?")) return;
    try {
      const r = await call('importRmxp', { projectPath: S.projectPath, moveId: m.id });
      if (S.doc) pushUndo();
      S.doc = Object.assign(newDoc(S.sel), { duration: r.duration, layers: r.layers, events: r.events });
      S.t = 0; S.layer = S.doc.layers.length ? 0 : -1; S.key = S.event = -1;
      toast(`Importé : ${r.layers.length} calque(s), ${r.events.length} évènement(s)`);
      render();
    } catch (e) { toast(e.message, true); }
  }

  // ---------------------------------------------------------------------------
  // Calcul d'un instant (même logique que le jeu)
  // ---------------------------------------------------------------------------
  const lerp = (a, b, r) => a + (b - a) * r;
  function layerState(l, t) {
    const keys = l.keys;
    let i = -1;
    for (let k = 0; k < keys.length; k++) if (keys[k].t <= t + 1e-6) i = k;
    if (i < 0 || keys[i].visible === false) return null;
    const a = keys[i]; const b = keys[i + 1];
    const r = b && a.tween !== false && b.visible !== false && b.t > a.t ? (t - a.t) / (b.t - a.t) : 0;
    const v = (name, d) => { const av = a[name] ?? d; const bv = b ? (b[name] ?? av) : av; return lerp(av, bv, r); };
    return { cell: a.cell || 0, x: v('x', 0), y: v('y', 0), p: v('p', 0), zoom: v('zoom', 100), angle: v('angle', 0), opacity: v('opacity', 255), mirror: !!a.mirror };
  }
  function positions() {
    const rev = S.preview.reverse;
    return { user: rev ? TARGET_POS : USER_POS, target: rev ? USER_POS : TARGET_POS, rev };
  }
  const centerOf = (feet) => [feet[0], feet[1] - 48];
  function anchorPos(anchor, p, pos, offs) {
    const u = centerOf(add(pos.user, offs.user)); const g = centerOf(add(pos.target, offs.target));
    if (anchor === 'user') return u;
    if (anchor === 'screen') return [160, 120];
    if (anchor === 'path') return [lerp(u[0], g[0], p), lerp(u[1], g[1], p)];
    return g;
  }
  const add = (a, b) => [a[0] + (b ? b[0] : 0), a[1] + (b ? b[1] : 0)];
  // effets des évènements à l'instant t : décalages, flashs, Pokémon cachés
  function eventEffects(t) {
    const out = { offs: { user: [0, 0], target: [0, 0] }, hidden: { user: false, target: false }, flash: { user: null, target: null, screen: null } };
    const rev = S.preview.reverse ? -1 : 1;
    (S.doc ? S.doc.events : []).filter((e) => e.t <= t + 1e-6).sort((a, b) => a.t - b.t).forEach((e) => {
      const on = e.on || 'target';
      const r = (t - e.t) / Math.max(e.duration || 0.2, 0.01);
      if (e.type === 'hide' || e.type === 'show') { if (on !== 'screen') out.hidden[on] = e.type === 'hide'; return; }
      if (r >= 1) return;
      if (e.type === 'flash') out.flash[on] = { color: e.color || '#ffffff', alpha: ((e.alpha ?? 255) / 255) * (1 - r) };
      else if (e.type === 'shake' && on !== 'screen') out.offs[on][0] += Math.sin(r * Math.PI * 8) * (e.power ?? 4) * (1 - r);
      else if (e.type === 'move' && on !== 'screen') {
        const k = e.back === false ? r : Math.sin(r * Math.PI);
        out.offs[on][0] += (e.x || 0) * rev * k; out.offs[on][1] += (e.y || 0) * rev * k;
      }
    });
    return out;
  }

  // ---------------------------------------------------------------------------
  // Aperçu
  // ---------------------------------------------------------------------------
  function drawPokemon(c, rel, feet, hidden, flash) {
    if (hidden) return;
    const e = image(rel);
    if (!e.img) return;
    const s = e.img.height; // première image (planches animées)
    const w = Math.min(e.img.width, s);
    c.drawImage(e.img, 0, 0, w, s, Math.round(feet[0] - w / 2), Math.round(feet[1] - s), w, s);
    if (flash && flash.alpha > 0) {
      const tmp = document.createElement('canvas'); tmp.width = w; tmp.height = s;
      const tc = tmp.getContext('2d');
      tc.drawImage(e.img, 0, 0, w, s, 0, 0, w, s);
      tc.globalCompositeOperation = 'source-atop'; tc.globalAlpha = flash.alpha; tc.fillStyle = flash.color; tc.fillRect(0, 0, w, s);
      c.drawImage(tmp, Math.round(feet[0] - w / 2), Math.round(feet[1] - s));
    }
  }
  function draw() {
    const cv = refs.stage;
    if (!cv) return;
    const c = cv.getContext('2d');
    c.imageSmoothingEnabled = false;
    c.fillStyle = '#20202a'; c.fillRect(0, 0, W, H);
    const bg = S.preview.bg ? image('graphics/battlebacks/' + S.preview.bg) : null;
    if (bg && bg.img) c.drawImage(bg.img, 0, 0, W, H);
    if (!S.doc) { drawPokemons(c, null); return; }
    const t = S.t;
    const fx = eventEffects(t);
    const pos = positions();
    const states = S.doc.layers.map((l) => (l.hidden ? null : layerState(l, t)));
    // calques derrière la cible, Pokémon, calques devant
    const drawLayers = (front) => S.doc.layers.forEach((l, i) => { if (!!(l.front !== false) === front && states[i]) drawLayer(c, l, states[i], pos, fx, i === S.layer); });
    drawLayers(false);
    drawPokemons(c, fx);
    drawLayers(true);
    if (fx.flash.screen && fx.flash.screen.alpha > 0) { c.globalAlpha = fx.flash.screen.alpha; c.fillStyle = fx.flash.screen.color; c.fillRect(0, 0, W, H); c.globalAlpha = 1; }
    // repères : centres du lanceur et de la cible
    if (!S.playing) {
      const mark = (p, color) => { c.strokeStyle = color; c.lineWidth = 1; c.beginPath(); c.moveTo(p[0] - 4, p[1]); c.lineTo(p[0] + 4, p[1]); c.moveTo(p[0], p[1] - 4); c.lineTo(p[0], p[1] + 4); c.stroke(); };
      mark(centerOf(pos.user), 'rgba(80,200,255,.8)');
      mark(centerOf(pos.target), 'rgba(255,90,110,.8)');
    }
  }
  function drawPokemons(c, fx) {
    const pos = positions();
    const userRel = `graphics/pokedex/${pos.rev ? 'pokefront' : 'pokeback'}/${S.preview.user}`;
    const targetRel = `graphics/pokedex/${pos.rev ? 'pokeback' : 'pokefront'}/${S.preview.target}`;
    const f = fx || { offs: {}, hidden: {}, flash: {} };
    // le plus loin d'abord
    const list = [[targetRel, add(pos.target, f.offs.target), f.hidden.target, f.flash.target], [userRel, add(pos.user, f.offs.user), f.hidden.user, f.flash.user]];
    if (pos.rev) list.reverse();
    list.forEach(([rel, feet, hidden, flash]) => drawPokemon(c, rel, feet, hidden, flash));
  }
  function drawLayer(c, l, st, pos, fx, selected) {
    const e = l.image ? image('graphics/animations/' + l.image) : null;
    const [ax, ay] = anchorPos(l.anchor || 'target', st.p, pos, fx.offs);
    const rev = pos.rev ? -1 : 1;
    const x = ax + st.x * rev; const y = ay + st.y * rev;
    const cw = l.cell || 192; const ch = l.cellH || cw;
    c.save();
    c.translate(x, y);
    c.rotate((-st.angle * rev * Math.PI) / 180);
    const z = st.zoom / 100;
    c.scale((st.mirror !== pos.rev ? -1 : 1) * z, z);
    c.globalAlpha = clamp(st.opacity / 255, 0, 1);
    c.globalCompositeOperation = l.blend == 1 ? 'lighter' : l.blend == 2 ? 'difference' : 'source-over';
    if (e && e.img) {
      const cols = Math.max(1, Math.floor(e.img.width / cw));
      c.drawImage(e.img, (st.cell % cols) * cw, Math.floor(st.cell / cols) * ch, cw, ch, -cw / 2, -ch / 2, cw, ch);
    }
    c.globalCompositeOperation = 'source-over';
    if (selected && !S.playing) { c.globalAlpha = 1; c.strokeStyle = '#ffd34d'; c.lineWidth = 1 / Math.max(z, 0.05); c.strokeRect(-cw / 2, -ch / 2, cw, ch); }
    c.restore();
  }

  // ---------------------------------------------------------------------------
  // Lecture
  // ---------------------------------------------------------------------------
  let raf = 0; let playStart = 0; let playFrom = 0; let lastT = 0;
  function play() {
    if (!S.doc) return;
    if (S.t >= S.doc.duration - 1e-6) S.t = 0;
    S.playing = true; playFrom = S.t; lastT = S.t - 1e-6; playStart = performance.now();
    refreshPlayButton();
    const tick = () => {
      if (!S.playing) return;
      let t = playFrom + (performance.now() - playStart) / 1000;
      if (t >= S.doc.duration) {
        if (S.loop) { fireSounds(lastT, S.doc.duration); playFrom = 0; playStart = performance.now(); lastT = -1e-6; t = 0; } else { S.t = S.doc.duration; fireSounds(lastT, S.t); stop(); draw(); updatePlayhead(); return; }
      }
      fireSounds(lastT, t); lastT = t;
      S.t = t; draw(); updatePlayhead();
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
  }
  function fireSounds(from, to) { S.doc.events.forEach((e) => { if (e.type === 'se' && e.t > from && e.t <= to) playSe(e); }); }
  function stop() { S.playing = false; cancelAnimationFrame(raf); refreshPlayButton(); }
  function refreshPlayButton() { if (refs.play) refs.play.textContent = S.playing ? '■ Stop' : '▶ Lire'; }

  // ---------------------------------------------------------------------------
  // Modifications
  // ---------------------------------------------------------------------------
  function ensureDoc() { if (!S.doc) { S.doc = newDoc(S.sel); } return S.doc; }
  function addLayer() {
    ensureDoc(); pushUndo();
    const image = prefs.lastImage && S.ctx.images.includes(prefs.lastImage) ? prefs.lastImage : (S.ctx.images[0] || '');
    S.doc.layers.push({ name: 'Calque ' + (S.doc.layers.length + 1), image, cell: 192, anchor: 'target', blend: 0, front: true,
      keys: [{ t: snap(S.t), cell: 0, x: 0, y: 0, zoom: 50, angle: 0, opacity: 255, visible: true, tween: true }] });
    S.layer = S.doc.layers.length - 1; S.key = 0; S.event = -1;
    render();
  }
  function keyAt(l, t) { return l.keys.findIndex((k) => Math.abs(k.t - t) < 1e-4); }
  function addKey(l, t) {
    t = snap(t);
    let i = keyAt(l, t);
    if (i >= 0) return i;
    const st = layerState(l, t) || (l.keys.length ? Object.assign({}, l.keys[l.keys.length - 1]) : { cell: 0, x: 0, y: 0, zoom: 50, angle: 0, opacity: 255 });
    const k = { t, cell: st.cell || 0, x: Math.round(st.x || 0), y: Math.round(st.y || 0), zoom: Math.round(st.zoom ?? 100), angle: Math.round(st.angle || 0),
      opacity: Math.round(st.opacity ?? 255), mirror: !!st.mirror, visible: true, tween: true };
    if (l.anchor === 'path') k.p = round3(st.p || 0);
    l.keys.push(k); l.keys.sort((a, b) => a.t - b.t);
    return l.keys.indexOf(k);
  }
  function addEvent(type) {
    ensureDoc(); pushUndo();
    const e = { t: snap(S.t), type };
    if (type === 'se') Object.assign(e, { name: S.ctx.sounds[0] || '', volume: 100, pitch: 100 });
    if (type === 'flash') Object.assign(e, { on: 'target', color: '#ffffff', alpha: 200, duration: 0.2 });
    if (type === 'shake') Object.assign(e, { on: 'target', power: 4, duration: 0.3 });
    if (type === 'move') Object.assign(e, { on: 'user', x: 24, y: -8, duration: 0.2, back: true });
    if (type === 'hide' || type === 'show') Object.assign(e, { on: 'target' });
    S.doc.events.push(e);
    S.event = S.doc.events.length - 1; S.layer = -1; S.key = -1;
    render();
  }
  function deleteSelection() {
    if (!S.doc) return;
    if (S.event >= 0) { pushUndo(); S.doc.events.splice(S.event, 1); S.event = -1; render(); return; }
    const l = layer();
    if (l && S.key >= 0) { pushUndo(); l.keys.splice(S.key, 1); S.key = -1; render(); return; }
    if (l && confirm(`Supprimer le calque « ${l.name} » ?`)) { pushUndo(); S.doc.layers.splice(S.layer, 1); S.layer = -1; render(); }
  }
  // un champ modifié : annulable, puis on redessine sans refaire la page (le champ garde le focus)
  function edit(fn, full) { pushUndo(); fn(); if (full) render(); else { draw(); renderTimeline(); updateStatus(); } }

  // ---------------------------------------------------------------------------
  // Rendu de la page
  // ---------------------------------------------------------------------------
  function statusText() {
    if (!S.doc) return [S.sel ? 'Pas d’animation Studio (le jeu garde celle de PSDK)' : '', ''];
    if (dirty()) return ['Modifications non enregistrées', ' dirty'];
    return [S.saved ? 'Enregistré' : 'Nouvelle animation (pas encore enregistrée)', S.saved ? '' : ' dirty'];
  }
  function updateStatus() {
    const el = root && root.querySelector('.pjs-status');
    if (!el) return;
    const [txt, cls] = statusText();
    el.textContent = txt; el.className = 'pjs-status' + cls;
  }

  function render() {
    if (!root) return;
    const listScroll = refs.list ? refs.list.scrollTop : null;
    const sideScroll = refs.side ? refs.side.scrollTop : 0;
    const tlScroll = refs.tlBody ? refs.tlBody.scrollLeft : 0;
    root.textContent = '';
    refs = {};
    const [statusTxt, statusCls] = statusText();
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' }, h('span', { class: 'pjs-top-title' }, 'Animations des attaques'),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + statusCls }, statusTxt),
        h('button', { class: 'pjs-btn secondary', onclick: () => { if (!dirty() || confirm('Animations : abandonner les modifications non enregistrées ?')) loadProject(S.projectPath); } }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.doc, title: 'Ctrl+S' }, 'Enregistrer'))));
    if (S.error) { root.appendChild(h('div', { class: 'pjs-empty err' }, S.error)); return; }
    if (!S.ctx) { root.appendChild(h('div', { class: 'pjs-empty' }, 'Chargement…')); return; }
    const body = h('div', { class: 'pja2-body' });
    root.appendChild(body);
    body.appendChild(renderList());
    const center = h('div', { class: 'pja2-center' });
    body.appendChild(center);
    renderCenter(center);
    const side = h('div', { class: 'pja2-side' });
    refs.side = side;
    body.appendChild(side);
    renderSide(side);
    side.scrollTop = sideScroll;
    if (refs.tlBody) refs.tlBody.scrollLeft = tlScroll;
    if (listScroll !== null && refs.list) refs.list.scrollTop = listScroll;
    else requestAnimationFrame(() => { const a = refs.list && refs.list.querySelector('.active'); if (a) scrollInto(a); });
    draw();
  }

  function renderList() {
    const list = h('div', { class: 'pja2-list' });
    refs.list = list;
    const search = h('input', { class: 'pjs-input', placeholder: 'Nom, n° ou symbole', value: S.query });
    const fill = () => {
      list.textContent = '';
      const q = plain(S.query.trim());
      const items = S.ctx.moves.filter((m) => (S.filter !== 'studio' || m.has) && (!q || plain(m.name).includes(q) || m.db.includes(q.replace(/[\s-]+/g, '_')) || String(m.id) === q.replace(/^0+/, '')));
      items.slice(0, 500).forEach((m) => {
        const t = S.ctx.types[m.type];
        list.appendChild(h('div', { class: 'pjs-item pja2-item' + (S.sel === m.db ? ' active' : ''), onclick: () => selectMove(m.db) },
          h('span', { class: 'pja2-id' }, String(m.id).padStart(3, '0')),
          h('span', { class: 'pja2-name' }, m.name),
          t ? h('span', { class: 'pja2-type', style: { background: t.color || '#555' }, title: t.name }) : null,
          h('span', { class: 'pja2-badge' + (m.has ? ' on' : ''), title: m.has ? 'Animation Studio' : m.rmxp ? 'Animation RPG Maker (PSDK)' : 'Aucune animation' }, m.has ? 'Studio' : m.rmxp ? 'RM' : '')));
      });
      if (items.length > 500) list.appendChild(h('div', { class: 'pjs-hint' }, `${items.length - 500} autres : affine la recherche.`));
    };
    const onSearch = () => { if (S.query === search.value) return; S.query = search.value; fill(); };
    ['input', 'keyup', 'change', 'search'].forEach((type) => search.addEventListener(type, onSearch));
    search.addEventListener('keydown', (e) => e.stopPropagation());
    const filter = h('select', { class: 'pjs-input', onchange: (e) => { S.filter = e.target.value; prefs.filter = S.filter; savePrefs(); fill(); } },
      [['', 'Toutes les attaques'], ['studio', 'Avec animation Studio']].map(([v, l]) => h('option', { value: v, selected: S.filter === v }, l)));
    fill();
    const count = S.ctx.moves.filter((m) => m.has).length;
    return h('div', { class: 'pjs-block pja2-list-block' },
      h('div', { class: 'pjs-block-head' }, h('h2', null, 'Attaques'), h('span', { class: 'pjs-count', title: 'Attaques avec une animation Studio' }, String(count))),
      filter, search, list);
  }

  function renderCenter(center) {
    const m = moveOf(S.sel);
    // barre de l'aperçu
    const pv = S.preview;
    const setPv = (k, v) => { pv[k] = v; prefs.preview = pv; savePrefs(); draw(); };
    const num = (k) => h('input', { class: 'pjs-input pja2-dex', value: pv[k], title: 'N° de l’image (graphics/pokedex)', onchange: (e) => { setPv(k, e.target.value.trim().padStart(4, '0')); e.target.value = pv[k]; } });
    center.appendChild(h('div', { class: 'pja2-toolbar' },
      h('span', { class: 'pja2-title' }, m ? `${m.name}` : '—', m ? h('span', { class: 'pjs-hint inline' }, ` ${m.db} · ${CAT[m.category] || m.category}${m.power ? ' · ' + m.power : ''}`) : null),
      h('span', { class: 'pja2-spacer' }),
      h('label', { class: 'pja2-mini' }, 'Fond', h('select', { class: 'pjs-input', onchange: (e) => setPv('bg', e.target.value) },
        S.ctx.battlebacks.map((b) => h('option', { value: b, selected: b === pv.bg }, b)))),
      h('label', { class: 'pja2-mini' }, 'Lanceur', num('user')),
      h('label', { class: 'pja2-mini' }, 'Cible', num('target')),
      h('label', { class: 'pjs-inline pja2-mini', title: 'Voir l’attaque lancée par l’adversaire (tout est retourné)' },
        h('input', { type: 'checkbox', checked: pv.reverse, onchange: (e) => setPv('reverse', e.target.checked) }), 'Adversaire')));
    const stageWrap = h('div', { class: 'pja2-stagewrap' });
    const stage = h('canvas', { class: 'pja2-stage', width: W, height: H });
    stage.style.width = W * SCALE + 'px'; stage.style.height = H * SCALE + 'px';
    refs.stage = stage;
    stage.addEventListener('mousedown', onStageDown);
    stageWrap.appendChild(stage);
    if (S.loading) stageWrap.appendChild(h('div', { class: 'pja2-over' }, 'Chargement…'));
    else if (!S.doc && m) {
      stageWrap.appendChild(h('div', { class: 'pja2-over' },
        h('div', null, 'Pas d’animation Studio pour cette attaque : le jeu joue celle de PSDK' + (m.rmxp ? ' (RPG Maker).' : ' (ou aucune).')),
        h('div', { class: 'pja2-over-btns' },
          h('button', { class: 'pjs-btn primary', onclick: () => { S.doc = newDoc(S.sel); render(); } }, 'Créer une animation'),
          m.rmxp ? h('button', { class: 'pjs-btn secondary', onclick: importRmxp }, 'Partir de celle de RPG Maker') : null)));
    }
    center.appendChild(stageWrap);
    center.appendChild(h('div', { class: 'pja2-timeline-wrap' }, renderTimelineShell()));
    renderTimeline();
  }

  // --- Ligne de temps ------------------------------------------------------------------
  function renderTimelineShell() {
    const wrap = h('div', { class: 'pja2-timeline' });
    refs.timeline = wrap;
    const playBtn = h('button', { class: 'pjs-btn small primary', onclick: () => (S.playing ? stop() : play()), disabled: !S.doc, title: 'Espace' }, '▶ Lire');
    refs.play = playBtn;
    const evSel = h('select', { class: 'pjs-input pja2-evsel', disabled: !S.doc && !S.sel, onchange: (e) => { if (e.target.value) addEvent(e.target.value); e.target.value = ''; } },
      h('option', { value: '' }, '+ Évènement…'), EVENT_TYPES.map(([v, l]) => h('option', { value: v }, l)));
    wrap.appendChild(h('div', { class: 'pja2-tl-bar' },
      playBtn,
      h('label', { class: 'pjs-inline' }, h('input', { type: 'checkbox', checked: S.loop, onchange: (e) => { S.loop = e.target.checked; prefs.loop = S.loop; savePrefs(); } }), 'Boucle'),
      h('span', { class: 'pja2-time' }),
      h('span', { class: 'pja2-spacer' }),
      h('button', { class: 'pjs-btn small secondary', onclick: addLayer, disabled: !S.sel }, '+ Calque'),
      h('button', { class: 'pjs-btn small secondary', disabled: !layer(), onclick: () => { const l = layer(); pushUndo(); S.key = addKey(l, S.t); render(); }, title: 'Clé du calque choisi à l’instant affiché (double-clic sur sa piste)' }, '+ Clé'),
      evSel,
      h('button', { class: 'pjs-btn small secondary', onclick: deleteSelection, disabled: !(S.event >= 0 || layer()), title: 'Suppr' }, 'Supprimer'),
      h('label', { class: 'pja2-mini' }, 'Durée', h('input', { class: 'pjs-input pja2-num', type: 'number', min: 0.05, max: 30, step: 0.05, value: S.doc ? S.doc.duration : 1, disabled: !S.doc,
        onchange: (e) => edit(() => { S.doc.duration = round3(clamp(+e.target.value || 1, 0.05, 30)); }, true) }), 's'),
      h('label', { class: 'pja2-mini', title: 'Zoom de la ligne de temps' }, '🔍', h('input', { type: 'range', min: 60, max: 600, value: S.pxs, oninput: (e) => { S.pxs = +e.target.value; prefs.pxs = S.pxs; savePrefs(); renderTimeline(); } }))));
    const body = h('div', { class: 'pja2-tl-body' });
    refs.tlBody = body;
    wrap.appendChild(body);
    return wrap;
  }

  function renderTimeline() {
    const body = refs.tlBody;
    if (!body) return;
    const scroll = body.scrollLeft;
    body.textContent = '';
    const dur = S.doc ? S.doc.duration : 1;
    const width = Math.max(200, dur * S.pxs + 40);
    const xOf = (t) => t * S.pxs;
    const tOf = (x) => clamp(snap(x / S.pxs), 0, dur);
    const labels = h('div', { class: 'pja2-tl-labels' });
    const lanes = h('div', { class: 'pja2-tl-lanes', style: { width: width + 'px' } });
    body.appendChild(labels); body.appendChild(lanes);
    // règle
    labels.appendChild(h('div', { class: 'pja2-tl-label ruler' }, 'Temps'));
    const ruler = h('div', { class: 'pja2-lane ruler' });
    for (let t = 0; t <= dur + 1e-6; t = round3(t + STEP)) {
      const major = Math.abs(t * 10 - Math.round(t * 10)) < 1e-6;
      ruler.appendChild(h('div', { class: 'pja2-tick' + (major ? ' major' : ''), style: { left: xOf(t) + 'px' } }, major ? (Math.round(t * 10) / 10).toFixed(1) : null));
    }
    lanes.appendChild(ruler);
    const scrub = (e) => {
      const r = lanes.getBoundingClientRect();
      const move = (ev) => { stop(); S.t = tOf(ev.clientX - r.left); draw(); updatePlayhead(); };
      move(e);
      const up = () => { window.removeEventListener('mousemove', move); window.removeEventListener('mouseup', up); };
      window.addEventListener('mousemove', move); window.addEventListener('mouseup', up);
    };
    ruler.addEventListener('mousedown', scrub);
    if (S.doc) {
      // calques
      S.doc.layers.forEach((l, li) => {
        labels.appendChild(h('div', { class: 'pja2-tl-label' + (li === S.layer && S.event < 0 ? ' active' : ''), onclick: () => { S.layer = li; S.key = -1; S.event = -1; render(); } },
          h('button', { class: 'pja2-eye' + (l.hidden ? ' off' : ''), title: 'Voir / cacher dans l’aperçu (pas en jeu)', onclick: (e) => { e.stopPropagation(); l.hidden = !l.hidden; renderTimeline(); draw(); } }, l.hidden ? '◌' : '●'),
          h('span', { class: 'pja2-tl-name' }, l.name || 'Calque'),
          h('span', { class: 'pja2-tl-anchor' }, (ANCHORS.find((a) => a[0] === l.anchor) || ['', ''])[1].split(' ')[0])));
        const lane = h('div', { class: 'pja2-lane' + (li === S.layer && S.event < 0 ? ' active' : '') });
        // barres de visibilité
        l.keys.forEach((k, ki) => {
          const next = l.keys[ki + 1];
          if (k.visible !== false) lane.appendChild(h('div', { class: 'pja2-span' + (k.tween !== false && next ? ' tween' : ''), style: { left: xOf(k.t) + 'px', width: Math.max(2, xOf((next ? next.t : dur) - k.t)) + 'px' } }));
        });
        l.keys.forEach((k, ki) => {
          const el = h('div', { class: 'pja2-key' + (k.visible === false ? ' hide' : '') + (li === S.layer && ki === S.key ? ' active' : ''), style: { left: xOf(k.t) + 'px' }, title: `${k.t.toFixed(2)} s${k.visible === false ? ' (caché)' : ''}` });
          el.addEventListener('mousedown', (e) => dragItem(e, lanes, () => { S.layer = li; S.key = ki; S.event = -1; }, (t) => { k.t = t; }, () => { l.keys.sort((a, b) => a.t - b.t); S.key = l.keys.indexOf(k); }, k.t));
          lane.appendChild(el);
        });
        lane.addEventListener('mousedown', (e) => { if (e.target !== lane && !e.target.classList.contains('pja2-span')) return; S.layer = li; S.event = -1; S.key = -1; scrub(e); renderSideOnly(); markLanes(); });
        lane.addEventListener('dblclick', (e) => { if (e.target.classList.contains('pja2-key')) return; const r = lanes.getBoundingClientRect(); pushUndo(); S.layer = li; S.t = tOf(e.clientX - r.left); S.key = addKey(l, S.t); S.event = -1; render(); });
        lanes.appendChild(lane);
      });
      // évènements
      labels.appendChild(h('div', { class: 'pja2-tl-label events' }, 'Évènements'));
      const evLane = h('div', { class: 'pja2-lane events' });
      S.doc.events.forEach((ev, ei) => {
        const el = h('div', { class: `pja2-ev ${ev.type}` + (ei === S.event ? ' active' : ''), style: { left: xOf(ev.t) + 'px' }, title: `${EVENT_LABEL[ev.type]} ${ev.t.toFixed(2)} s${ev.name ? ' — ' + ev.name : ''}` },
          ({ se: '♪', flash: '✦', shake: '≈', move: '➚', hide: '◌', show: '●' })[ev.type] || '?');
        if (ev.duration && ev.type !== 'se') evLane.appendChild(h('div', { class: 'pja2-evspan ' + ev.type, style: { left: xOf(ev.t) + 'px', width: Math.max(2, xOf(ev.duration)) + 'px' } }));
        el.addEventListener('mousedown', (e) => dragItem(e, lanes, () => { S.event = ei; S.layer = -1; S.key = -1; }, (t) => { ev.t = t; }, null, ev.t));
        evLane.appendChild(el);
      });
      evLane.addEventListener('mousedown', (e) => { if (e.target === evLane) scrub(e); });
      lanes.appendChild(evLane);
      if (!S.doc.layers.length && !S.doc.events.length) lanes.appendChild(h('div', { class: 'pjs-hint pja2-tl-empty' }, '« + Calque » ajoute une image animée, « + Évènement » un son, un flash, un tremblement…'));
    }
    const head = h('div', { class: 'pja2-playhead' });
    refs.playhead = head; refs.xOf = xOf;
    lanes.appendChild(h('div', { class: 'pja2-end', style: { left: xOf(dur) + 'px' } }));
    lanes.appendChild(head);
    body.scrollLeft = scroll;
    updatePlayhead();
    refreshPlayButton();
  }
  function markLanes() { renderTimeline(); }
  function updatePlayhead() {
    if (refs.playhead && refs.xOf) refs.playhead.style.left = refs.xOf(S.t) + 'px';
    const tl = root && root.querySelector('.pja2-time');
    if (tl) tl.textContent = `${S.t.toFixed(2)} / ${(S.doc ? S.doc.duration : 0).toFixed(2)} s`;
  }
  // glisser une clé ou un évènement le long du temps (un clic simple le choisit)
  function dragItem(e, lanes, select, setT, after, t0) {
    e.stopPropagation();
    if (e.button !== 0) return;
    stop();
    select();
    S.t = t0;
    const r = lanes.getBoundingClientRect();
    const startX = e.clientX; let moved = false;
    const move = (ev) => {
      if (!moved && Math.abs(ev.clientX - startX) < 3) return;
      if (!moved) { pushUndo(); moved = true; }
      const t = clamp(snap((ev.clientX - r.left) / S.pxs), 0, S.doc.duration);
      setT(t); S.t = t; draw(); renderTimeline();
    };
    const up = () => {
      window.removeEventListener('mousemove', move); window.removeEventListener('mouseup', up);
      if (after) after();
      render();
    };
    window.addEventListener('mousemove', move); window.addEventListener('mouseup', up);
    draw(); renderTimeline(); renderSideOnly();
  }

  // --- Aperçu : déplacer le calque choisi à la souris --------------------------------------
  function onStageDown(e) {
    if (e.button !== 0 || !S.doc) return;
    const l = layer();
    if (!l || l.anchor === 'path' && false) return;
    stop();
    const rect = refs.stage.getBoundingClientRect();
    const sx = rect.width / W;
    const start = [e.clientX, e.clientY];
    pushUndo();
    const ki = addKey(l, S.t);
    S.key = ki; S.event = -1;
    const k = l.keys[ki];
    const base = [k.x || 0, k.y || 0];
    const rev = S.preview.reverse ? -1 : 1;
    const move = (ev) => {
      k.x = Math.round(base[0] + ((ev.clientX - start[0]) / sx) * rev);
      k.y = Math.round(base[1] + ((ev.clientY - start[1]) / sx) * rev);
      draw();
      if (refs.kx) refs.kx.value = k.x;
      if (refs.ky) refs.ky.value = k.y;
    };
    const up = () => { window.removeEventListener('mousemove', move); window.removeEventListener('mouseup', up); render(); };
    window.addEventListener('mousemove', move); window.addEventListener('mouseup', up);
    renderTimeline();
  }

  // --- Panneau de droite ------------------------------------------------------------------------
  function renderSideOnly() { if (!refs.side) return; const s = refs.side.scrollTop; refs.side.textContent = ''; renderSide(refs.side); refs.side.scrollTop = s; }
  const field = (label, input, hint) => h('label', { class: 'pja2-field' }, h('span', { class: 'pjs-label' }, label), input, hint ? h('span', { class: 'pjs-hint inline' }, hint) : null);
  const numIn = (value, onchange, opts) => {
    const el = h('input', Object.assign({ class: 'pjs-input pja2-num', type: 'number', value: value ?? '' }, opts || {}));
    el.addEventListener('change', () => onchange(el.value === '' ? null : +el.value));
    return el;
  };
  const sel = (options, value, onchange) => h('select', { class: 'pjs-input', onchange: (e) => onchange(e.target.value) },
    options.map(([v, l]) => h('option', { value: v, selected: String(v) === String(value) }, l)));

  function renderSide(side) {
    if (!S.sel) return;
    const m = moveOf(S.sel);
    if (S.doc) {
      side.appendChild(h('div', { class: 'pjs-block pja2-box' },
        h('div', { class: 'pjs-block-head' }, h('h2', null, 'Animation')),
        h('div', { class: 'pja2-row' },
          m && m.rmxp ? h('button', { class: 'pjs-btn small secondary', onclick: importRmxp, title: 'Remplace par l’animation de RPG Maker, convertie' }, 'Importer RPG Maker') : null,
          S.saved ? h('button', { class: 'pjs-btn small danger', onclick: removeAnim }, 'Supprimer') : null),
        h('div', { class: 'pjs-hint' }, `${S.doc.layers.length} calque(s), ${S.doc.events.length} évènement(s). Ctrl+Z annule, Espace lit, Suppr efface la sélection.`)));
    }
    const ev = event();
    if (ev) { side.appendChild(renderEvent(ev)); return; }
    const l = layer();
    if (l) side.appendChild(renderLayer(l));
    if (!S.doc) side.appendChild(h('div', { class: 'pjs-hint pja2-pad' }, 'Crée l’animation (au centre) pour la régler.'));
    else if (!l) side.appendChild(h('div', { class: 'pjs-hint pja2-pad' }, 'Choisis un calque ou un évènement dans la ligne de temps.'));
  }

  function renderLayer(l) {
    const box = h('div', { class: 'pjs-block pja2-box' });
    box.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Calque'),
      h('div', { class: 'pja2-row' },
        h('button', { class: 'pjs-btn small secondary', title: 'Monter', disabled: S.layer <= 0, onclick: () => edit(() => { const i = S.layer; [S.doc.layers[i - 1], S.doc.layers[i]] = [S.doc.layers[i], S.doc.layers[i - 1]]; S.layer = i - 1; }, true) }, '↑'),
        h('button', { class: 'pjs-btn small secondary', title: 'Descendre', disabled: S.layer >= S.doc.layers.length - 1, onclick: () => edit(() => { const i = S.layer; [S.doc.layers[i + 1], S.doc.layers[i]] = [S.doc.layers[i], S.doc.layers[i + 1]]; S.layer = i + 1; }, true) }, '↓'),
        h('button', { class: 'pjs-btn small secondary', title: 'Dupliquer', onclick: () => edit(() => { const c = clone(l); c.name += ' (copie)'; S.doc.layers.splice(S.layer + 1, 0, c); S.layer += 1; S.key = -1; }, true) }, '⧉'))));
    const name = h('input', { class: 'pjs-input', value: l.name || '' });
    name.addEventListener('change', () => edit(() => { l.name = name.value; }, true));
    box.appendChild(field('Nom', name));
    const imgSel = h('input', { class: 'pjs-input', list: 'pja2-images', value: l.image || '' });
    imgSel.addEventListener('change', () => {
      const v = imgSel.value.trim();
      if (v && !S.ctx.images.includes(v)) { toast('Image introuvable dans graphics/animations : ' + v, true); imgSel.value = l.image; return; }
      prefs.lastImage = v; savePrefs();
      edit(() => { l.image = v; }, true);
    });
    if (!document.getElementById('pja2-images')) document.body.appendChild(h('datalist', { id: 'pja2-images' }, S.ctx.images.map((i) => h('option', { value: i }))));
    box.appendChild(field('Image', imgSel, 'graphics/animations'));
    box.appendChild(h('div', { class: 'pja2-grid2' },
      field('Case (px)', numIn(l.cell || 192, (v) => edit(() => { l.cell = clamp(v || 192, 8, 1024); }, true), { min: 8, max: 1024 })),
      field('Fusion', sel(BLENDS, l.blend || 0, (v) => edit(() => { l.blend = +v; }, true)))));
    box.appendChild(field('Position par rapport à', sel(ANCHORS, l.anchor || 'target', (v) => edit(() => { l.anchor = v; if (v === 'path') l.keys.forEach((k, i) => { if (k.p === undefined) k.p = l.keys.length > 1 ? round3(i / (l.keys.length - 1)) : 0; }); }, true)),
      l.anchor === 'path' ? 'Avance de 0 (lanceur) à 1 (cible) avec « Trajet » des clés' : null));
    box.appendChild(h('label', { class: 'pjs-inline' }, h('input', { type: 'checkbox', checked: l.front !== false, onchange: (e) => edit(() => { l.front = e.target.checked; }, true) }), 'Devant les Pokémon (sinon derrière)'));
    const k = key();
    if (k) box.appendChild(renderKey(l, k));
    else box.appendChild(h('div', { class: 'pjs-hint' }, 'Clique une clé (losange) dans la ligne de temps, ou double-clique la piste pour en ajouter une. Dans l’aperçu, glisse l’image pour la placer à l’instant affiché.'));
    return box;
  }

  function renderKey(l, k) {
    const box = h('div', { class: 'pja2-sub' });
    box.appendChild(h('div', { class: 'pja2-subhead' }, `Clé à ${k.t.toFixed(2)} s`,
      h('button', { class: 'pjs-btn small danger', onclick: () => { pushUndo(); l.keys.splice(S.key, 1); S.key = -1; render(); } }, 'Supprimer la clé')));
    box.appendChild(h('div', { class: 'pja2-grid2' },
      field('Instant (s)', numIn(k.t, (v) => edit(() => { k.t = clamp(snap(v || 0), 0, S.doc.duration); l.keys.sort((a, b) => a.t - b.t); S.key = l.keys.indexOf(k); S.t = k.t; }, true), { step: STEP, min: 0 })),
      field('Case', numIn(k.cell || 0, (v) => edit(() => { k.cell = Math.max(0, v | 0); refreshCells(); }), { min: 0 }))));
    box.appendChild(renderCells(l, k));
    const kx = numIn(k.x || 0, (v) => edit(() => { k.x = v | 0; })); refs.kx = kx;
    const ky = numIn(k.y || 0, (v) => edit(() => { k.y = v | 0; })); refs.ky = ky;
    box.appendChild(h('div', { class: 'pja2-grid2' }, field('X', kx), field('Y', ky)));
    if (l.anchor === 'path') box.appendChild(field('Trajet (0 → 1)', numIn(k.p ?? 0, (v) => edit(() => { k.p = round3(clamp(v || 0, -0.5, 1.5)); }), { step: 0.05 })));
    box.appendChild(h('div', { class: 'pja2-grid3' },
      field('Zoom %', numIn(k.zoom ?? 100, (v) => edit(() => { k.zoom = clamp(v ?? 100, 1, 1000); }), { min: 1, step: 5 })),
      field('Angle', numIn(k.angle || 0, (v) => edit(() => { k.angle = v || 0; }), { step: 15 })),
      field('Opacité', numIn(k.opacity ?? 255, (v) => edit(() => { k.opacity = clamp(v ?? 255, 0, 255); }), { min: 0, max: 255, step: 15 }))));
    box.appendChild(h('div', { class: 'pja2-checks' },
      h('label', { class: 'pjs-inline' }, h('input', { type: 'checkbox', checked: k.visible !== false, onchange: (e) => edit(() => { k.visible = e.target.checked; }, true) }), 'Visible'),
      h('label', { class: 'pjs-inline', title: 'Glisse doucement vers la clé suivante (sinon saute d’un coup)' }, h('input', { type: 'checkbox', checked: k.tween !== false, onchange: (e) => edit(() => { k.tween = e.target.checked; }, true) }), 'Transition'),
      h('label', { class: 'pjs-inline' }, h('input', { type: 'checkbox', checked: !!k.mirror, onchange: (e) => edit(() => { k.mirror = e.target.checked; }) }), 'Miroir')));
    return box;
  }

  // planche de l'image : clic sur une case
  function renderCells(l, k) {
    const wrap = h('div', { class: 'pja2-cells' });
    refs.cells = { wrap, l, k };
    requestAnimationFrame(refreshCells);
    return wrap;
  }
  function refreshCells() {
    const r = refs.cells;
    if (!r || !r.wrap.isConnected) return;
    const { wrap, l, k } = r;
    wrap.textContent = '';
    const e = l.image ? image('graphics/animations/' + l.image) : null;
    if (!e || !e.img) { wrap.appendChild(h('span', { class: 'pjs-hint' }, e && e.ready ? 'Image introuvable.' : 'Chargement de l’image…')); return; }
    const cw = l.cell || 192; const ch = l.cellH || cw;
    const cols = Math.max(1, Math.floor(e.img.width / cw)); const rows = Math.max(1, Math.floor(e.img.height / ch));
    const size = 44;
    for (let i = 0; i < cols * rows; i++) {
      const cv = h('canvas', { width: size, height: size, class: 'pja2-cell' + (i === (k.cell || 0) ? ' active' : ''), title: 'Case ' + i });
      const c = cv.getContext('2d');
      c.imageSmoothingEnabled = false;
      c.drawImage(e.img, (i % cols) * cw, Math.floor(i / cols) * ch, cw, ch, 0, 0, size, size);
      cv.addEventListener('click', () => edit(() => { k.cell = i; }, true));
      wrap.appendChild(cv);
    }
  }

  function renderEvent(ev) {
    const box = h('div', { class: 'pjs-block pja2-box' });
    box.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, EVENT_LABEL[ev.type] || ev.type),
      h('button', { class: 'pjs-btn small danger', onclick: deleteSelection }, 'Supprimer')));
    box.appendChild(field('Instant (s)', numIn(ev.t, (v) => edit(() => { ev.t = clamp(snap(v || 0), 0, S.doc.duration); S.t = ev.t; }, true), { step: STEP, min: 0 })));
    if (ev.type === 'se') {
      const s = h('input', { class: 'pjs-input', list: 'pja2-sounds', value: ev.name || '' });
      if (!document.getElementById('pja2-sounds')) document.body.appendChild(h('datalist', { id: 'pja2-sounds' }, S.ctx.sounds.map((i) => h('option', { value: i }))));
      s.addEventListener('change', () => edit(() => { ev.name = s.value.trim(); }, true));
      box.appendChild(field('Son', s, 'audio/se'));
      box.appendChild(h('div', { class: 'pja2-grid2' },
        field('Volume', numIn(ev.volume ?? 100, (v) => edit(() => { ev.volume = clamp(v ?? 100, 0, 100); }), { min: 0, max: 100, step: 5 })),
        field('Hauteur', numIn(ev.pitch ?? 100, (v) => edit(() => { ev.pitch = clamp(v ?? 100, 50, 150); }), { min: 50, max: 150, step: 5 }))));
      box.appendChild(h('button', { class: 'pjs-btn small secondary', onclick: () => playSe(ev) }, '▶ Écouter'));
      return box;
    }
    box.appendChild(field('Sur', sel(ev.type === 'flash' ? ON : ON.slice(0, 2), ev.on || 'target', (v) => edit(() => { ev.on = v; }, true))));
    if (ev.type === 'flash') {
      box.appendChild(h('div', { class: 'pja2-grid3' },
        field('Couleur', h('input', { type: 'color', class: 'pja2-color', value: ev.color || '#ffffff', onchange: (e) => edit(() => { ev.color = e.target.value; }) })),
        field('Force', numIn(ev.alpha ?? 255, (v) => edit(() => { ev.alpha = clamp(v ?? 255, 0, 255); }), { min: 0, max: 255, step: 15 })),
        field('Durée (s)', numIn(ev.duration ?? 0.2, (v) => edit(() => { ev.duration = round3(clamp(v ?? 0.2, 0.05, 10)); }, true), { min: 0.05, step: 0.05 }))));
    } else if (ev.type === 'shake') {
      box.appendChild(h('div', { class: 'pja2-grid2' },
        field('Force (px)', numIn(ev.power ?? 4, (v) => edit(() => { ev.power = clamp(v ?? 4, 1, 40); }), { min: 1, max: 40 })),
        field('Durée (s)', numIn(ev.duration ?? 0.3, (v) => edit(() => { ev.duration = round3(clamp(v ?? 0.3, 0.05, 10)); }, true), { min: 0.05, step: 0.05 }))));
    } else if (ev.type === 'move') {
      box.appendChild(h('div', { class: 'pja2-grid3' },
        field('X', numIn(ev.x ?? 0, (v) => edit(() => { ev.x = v | 0; }))),
        field('Y', numIn(ev.y ?? 0, (v) => edit(() => { ev.y = v | 0; }))),
        field('Durée (s)', numIn(ev.duration ?? 0.2, (v) => edit(() => { ev.duration = round3(clamp(v ?? 0.2, 0.05, 10)); }, true), { min: 0.05, step: 0.05 }))));
      box.appendChild(h('label', { class: 'pjs-inline' }, h('input', { type: 'checkbox', checked: ev.back !== false, onchange: (e) => edit(() => { ev.back = e.target.checked; }) }), 'Revient à sa place (aller-retour)'));
      box.appendChild(h('div', { class: 'pjs-hint' }, 'X vers la cible, Y négatif vers le haut (retourné quand l’adversaire attaque).'));
    } else {
      box.appendChild(h('div', { class: 'pjs-hint' }, ev.type === 'hide' ? 'Le Pokémon disparaît (Tunnel, Vol…). Il réapparaît avec « Montrer » ou à la fin de l’animation.' : 'Le Pokémon réapparaît.'));
    }
    return box;
  }

  // ---------------------------------------------------------------------------
  // Page : Données > Attaques > Animations (/database/move-animations)
  // ---------------------------------------------------------------------------
  function mount(hostEl) {
    root = h('div', { id: 'pja2-root' });
    ['keydown', 'keypress', 'keyup'].forEach((type) => root.addEventListener(type, (e) => e.stopPropagation()));
    hostEl.appendChild(root);
    S.open = true;
    const latest = projectList()[0] && projectList()[0].projectPath;
    if (!S.ctx || (latest && latest !== S.projectPath && !dirty())) loadProject(latest || null); else render();
  }
  function checkPage() {
    const hostEl = document.getElementById('pj-page-' + PAGE_ID);
    if (root && hostEl && hostEl.contains(root)) return;
    if (root && root.parentNode) root.remove();
    if (root) { root = null; refs = {}; S.open = false; stop(); }
    if (hostEl) mount(hostEl);
  }
  let scheduled = false;
  const observer = new MutationObserver(() => { if (!scheduled) { scheduled = true; requestAnimationFrame(() => { scheduled = false; checkPage(); }); } });
  const start = () => { observer.observe(document.body, { childList: true, subtree: true }); checkPage(); };
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);

  window.addEventListener('keydown', (e) => {
    if (!S.open) return;
    const k = e.key.toLowerCase();
    const typing = /^(input|select|textarea)$/i.test((e.target && e.target.tagName) || '');
    if (e.ctrlKey && k === 's') { e.preventDefault(); e.stopPropagation(); save(); return; }
    if (typing) return;
    if (e.ctrlKey && k === 'z') { e.preventDefault(); e.stopPropagation(); undo(); }
    else if (e.ctrlKey && k === 'y') { e.preventDefault(); e.stopPropagation(); redo(); }
    else if (k === ' ') { e.preventDefault(); e.stopPropagation(); if (S.playing) stop(); else play(); }
    else if (k === 'delete') { e.preventDefault(); e.stopPropagation(); deleteSelection(); }
    else if (k === 'arrowleft' || k === 'arrowright') { if (!S.doc) return; e.preventDefault(); stop(); S.t = clamp(snap(S.t + (k === 'arrowleft' ? -STEP : STEP)), 0, S.doc.duration); draw(); updatePlayhead(); }
  }, true);
  setInterval(() => { if (S.open) updateStatus(); }, 1000);

  window.pjAnimEditor = { state: S, render };
})();
