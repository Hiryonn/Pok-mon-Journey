/* eslint-disable */
// =============================================================================
// Statuts — page « Données > Statuts » de Pokémon Studio (plugin « statuts »)
//   Statuts de base (Poison, Paralysie…) : rappel de leurs effets
//   Statuts du projet (Saignement…) : nom, icône, stats divisées, dégâts par tour, types immunisés, capture,
//   attaques qui l'infligent, messages de combat
// Enregistre Data/configs/plugins/statuts.json et redessine les icônes (graphics/interface/statuts<fr|en|es>.png).
// Style de l'éditeur Smartphone (classes pjs-*).
// =============================================================================
(() => {
  'use strict';
  if (window.__pjStatutsLoaded) return;
  window.__pjStatutsLoaded = true;

  const LANGS = ['fr', 'en', 'es'];
  const STATS = [['atk', 'Attaque'], ['dfe', 'Défense'], ['ats', 'Atq. Spé.'], ['dfs', 'Déf. Spé.'], ['spd', 'Vitesse']];
  const MESSAGES = [['inflict', 'Infligé'], ['already', 'Déjà atteint'], ['damage', 'Dégâts du tour'], ['cure', 'Guéri'], ['immune', 'Sans effet']];
  const DEFAULT_STATUS = () => ({
    id: 'bleeding', number: 10, name: { fr: 'Saignement', en: 'Bleeding' }, short: { fr: 'SAI', en: 'BLD', es: 'SAN' },
    color: '#b3123a', stats: { atk: 1, dfe: 1.5, ats: 1, dfs: 1, spd: 1 }, damage: 16, immune_types: [], catch_rate: 1.5, moves: [],
    messages: {
      inflict: { fr: '[nom] saigne !', en: '[nom] is bleeding!' },
      already: { fr: '[nom] saigne déjà !', en: '[nom] is already bleeding!' },
      damage: { fr: '[nom] perd des PV à cause du saignement !', en: '[nom] is hurt by its bleeding!' },
      cure: { fr: '[nom] ne saigne plus !', en: '[nom] stopped bleeding!' },
      immune: { fr: 'Ça n’affecte pas [nom]…', en: 'It doesn’t affect [nom]…' },
    },
  });
  // statuts de PSDK (numéro = ligne de l'icône)
  const BASE = [
    { number: 1, name: 'Poison', text: 'Perd 1/8 de ses PV max à la fin de chaque tour.' },
    { number: 8, name: 'Poison grave', text: 'Perd 1/16 de ses PV max, puis 2/16, 3/16… à chaque tour (remis à 1/16 quand il quitte le combat).' },
    { number: 2, name: 'Paralysie', text: 'Vitesse divisée par 2 ; 25 % de chances de ne pas pouvoir agir.' },
    { number: 3, name: 'Brûlure', text: 'Attaque physique divisée par 2 ; perd 1/16 de ses PV max à chaque tour.' },
    { number: 4, name: 'Sommeil', text: 'Ne peut pas agir pendant 1 à 3 tours.' },
    { number: 5, name: 'Gel', text: 'Ne peut pas agir ; 20 % de chances de dégeler à chaque tour (et aux attaques Feu).' },
    { number: 6, name: 'Confusion', text: 'Temporaire (2 à 5 tours) : 33 % de chances de se blesser au lieu d’attaquer. Pas d’icône.' },
    { number: 9, name: 'K.O.', text: 'Plus de PV.' },
  ];

  // Police 5 x 6 des icônes (même style que les icônes de PSDK)
  const FONT = {
    A: ['.###.', '##..#', '##..#', '#####', '##..#', '##..#'], B: ['####.', '##..#', '####.', '##..#', '##..#', '####.'],
    C: ['.###.', '##..#', '##...', '##...', '##..#', '.###.'], D: ['####.', '##..#', '##..#', '##..#', '##..#', '####.'],
    E: ['#####', '##...', '####.', '##...', '##...', '#####'], F: ['#####', '##...', '####.', '##...', '##...', '##...'],
    G: ['.####', '##...', '##.##', '##..#', '##..#', '.####'], H: ['##..#', '##..#', '#####', '##..#', '##..#', '##..#'],
    I: ['####', '.##.', '.##.', '.##.', '.##.', '####'], J: ['..###', '...##', '...##', '...##', '#..##', '.###.'],
    K: ['##..#', '##.#.', '###..', '###..', '##.#.', '##..#'], L: ['##...', '##...', '##...', '##...', '##...', '#####'],
    M: ['##.##', '#####', '#####', '#####', '##.##', '##.##'], N: ['##..#', '##..#', '###.#', '#####', '##.##', '##..#'],
    O: ['.###.', '##..#', '##..#', '##..#', '##..#', '.###.'], P: ['####.', '##..#', '##..#', '####.', '##...', '##...'],
    Q: ['.###.', '##..#', '##..#', '##..#', '##.#.', '.##.#'], R: ['####.', '##..#', '##..#', '####.', '##.##', '##..#'],
    S: ['.####', '##...', '.###.', '...##', '...##', '####.'], T: ['#####', '.##..', '.##..', '.##..', '.##..', '.##..'],
    U: ['##..#', '##..#', '##..#', '##..#', '##..#', '#####'], V: ['##..#', '##..#', '##..#', '##..#', '.#.#.', '..#..'],
    W: ['##..#', '##..#', '##.##', '#####', '#####', '##.##'], X: ['##..#', '.#.#.', '..#..', '..#..', '.#.#.', '##..#'],
    Y: ['##..#', '##..#', '.###.', '..##.', '..##.', '..##.'], Z: ['#####', '...#.', '..#..', '.#...', '#....', '#####'],
    0: ['.###.', '##..#', '##.##', '###.#', '##..#', '.###.'], 1: ['.##', '###', '.##', '.##', '.##', '.##'],
    2: ['####.', '...##', '..##.', '.##..', '##...', '#####'], 3: ['####.', '...##', '.###.', '...##', '...##', '####.'],
    4: ['##.#.', '##.#.', '#####', '...#.', '...#.', '...#.'], 5: ['#####', '##...', '####.', '...##', '...##', '####.'],
    6: ['.###.', '##...', '####.', '##..#', '##..#', '.###.'], 7: ['#####', '...##', '..##.', '.##..', '.##..', '.##..'],
    8: ['.###.', '##..#', '.###.', '##..#', '##..#', '.###.'], 9: ['.###.', '##..#', '##..#', '.####', '...##', '.###.'],
    '.': ['..', '..', '..', '..', '..', '##'], '-': ['...', '...', '###', '...', '...', '...'], ' ': ['..', '..', '..', '..', '..', '..'],
  };
  const cleanShort = (s) => String(s || '').toUpperCase().normalize('NFD').replace(/[̀-ͯ]/g, '').split('').filter((c) => FONT[c]).join('').slice(0, 4);

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------
  // fait défiler seulement la liste qui contient l'élément (scrollIntoView ferait aussi défiler la fenêtre de Studio)
  function scrollInto(el) {
    let box = el.parentElement;
    while (box && box !== document.body && !/^pj\w*-root$/.test(box.id)) {
      const st = getComputedStyle(box);
      if (/(auto|scroll)/.test(st.overflowY) && box.scrollHeight > box.clientHeight) break;
      box = box.parentElement;
    }
    if (!box || box === document.body || /^pj\w*-root$/.test(box.id)) return;
    const b = box.getBoundingClientRect(); const r = el.getBoundingClientRect();
    if (r.top < b.top) box.scrollTop -= b.top - r.top;
    else if (r.bottom > b.bottom) box.scrollTop += r.bottom - b.bottom;
  }
  const api = window.pjStatuts;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API Statuts n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  let toastTimer = null;
  function toast(msg, err) {
    document.querySelectorAll('.pjs-toast').forEach((t) => t.remove());
    const t = h('div', { class: 'pjs-toast' + (err ? ' err' : '') }, msg);
    document.body.appendChild(t);
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.remove(), err ? 6000 : 2500);
  }
  const projectList = () => { try { return JSON.parse(localStorage.getItem('projectList') || '[]'); } catch (e) { return []; } };
  const loadImage = (src) => new Promise((ok) => { if (!src) { ok(null); return; } const im = new Image(); im.onload = () => ok(im); im.onerror = () => ok(null); im.src = src; });
  const hexRgb = (hex) => { const m = /^#?([0-9a-f]{6})$/i.exec(hex || ''); const v = m ? parseInt(m[1], 16) : 0xb3123a; return [(v >> 16) & 255, (v >> 8) & 255, v & 255]; };

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const S = { open: false, projectPath: null, ctx: null, config: null, saved: null, error: null, sel: null, building: false, images: {} };
  let root = null;
  const snapshot = () => JSON.stringify(S.config);
  const dirty = () => S.config && S.saved !== snapshot();
  const statuses = () => S.config.statuses;
  const current = () => statuses().find((s) => 'custom:' + s.id === S.sel);

  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.ctx = null; S.config = null; S.error = null;
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath });
      const cfg = Object.assign({ klass: 'StatutsConfig', statuses: [DEFAULT_STATUS()] }, S.ctx.config || {});
      cfg.statuses = (cfg.statuses || []).map((s) => normalize(s));
      S.config = cfg;
      S.saved = S.ctx.config ? snapshot() : null;
      S.images = {};
      for (const lang of LANGS) S.images[lang] = await loadImage(S.ctx.icons[lang]);
      if (!S.sel || (S.sel.startsWith('custom:') && !current())) S.sel = statuses()[0] ? 'custom:' + statuses()[0].id : 'base:1';
    } catch (e) { S.error = e.message; }
    render();
  }
  function normalize(s) {
    const d = DEFAULT_STATUS();
    const out = Object.assign({}, d, s);
    out.name = Object.assign({}, s.name || {});
    out.short = Object.assign({}, s.short || {});
    out.stats = Object.assign({ atk: 1, dfe: 1, ats: 1, dfs: 1, spd: 1 }, s.stats || {});
    out.messages = {};
    MESSAGES.forEach(([k]) => { out.messages[k] = Object.assign({}, (s.messages || {})[k] || {}); });
    out.immune_types = (s.immune_types || []).slice();
    out.moves = (s.moves || []).map((m) => ({ move: m.move, chance: m.chance | 0 }));
    return out;
  }

  // ---------------------------------------------------------------------------
  // Icônes
  // ---------------------------------------------------------------------------
  // Dessine l'icône d'un statut (25 x 10) à partir de la pastille de la Brûlure (ligne 3) de l'image de la langue
  function drawIcon(ctx, base, y0, label, color) {
    const [cr, cg, cb] = hexRgb(color);
    const tmp = document.createElement('canvas'); tmp.width = 25; tmp.height = 10;
    const tc = tmp.getContext('2d');
    tc.drawImage(base, 0, 30, 25, 10, 0, 0, 25, 10);
    const img = tc.getImageData(0, 0, 25, 10);
    const d = img.data;
    for (let y = 0; y < 10; y++) {
      for (let x = 0; x < 25; x++) {
        const i = (y * 25 + x) * 4;
        if (!d[i + 3]) continue;
        let white = d[i] > 200 && d[i + 1] > 200 && d[i + 2] > 200;
        // lettres de la Brûlure effacées (fond de la pastille)
        if (white && x >= 3 && x <= 21 && y >= 2 && y <= 7) white = false, d[i + 1] = 0, d[i + 2] = 0;
        if (white) continue;
        const t = 1 - d[i + 1] / 255;
        d[i] = Math.round(255 * (1 - t) + cr * t); d[i + 1] = Math.round(255 * (1 - t) + cg * t); d[i + 2] = Math.round(255 * (1 - t) + cb * t);
      }
    }
    const glyphs = cleanShort(label).split('').map((c) => FONT[c]);
    const width = glyphs.reduce((a, g) => a + g[0].length, 0) + Math.max(0, glyphs.length - 1);
    let x0 = Math.floor((25 - width) / 2);
    glyphs.forEach((g) => {
      g.forEach((row, gy) => row.split('').forEach((p, gx) => {
        if (p !== '#') return;
        const x = x0 + gx; const y = 2 + gy;
        if (x < 0 || x >= 25) return;
        const i = (y * 25 + x) * 4; d[i] = d[i + 1] = d[i + 2] = d[i + 3] = 255;
      }));
      x0 += g[0].length + 1;
    });
    tc.putImageData(img, 0, 0);
    ctx.clearRect(0, y0, 25, 10);
    ctx.drawImage(tmp, 0, y0);
  }
  // Image complète d'une langue avec les icônes des statuts du projet
  function buildSheet(lang) {
    const base = S.images[lang];
    if (!base) return null;
    const rows = Math.max(Math.floor(base.height / 10), ...statuses().map((s) => (s.number | 0) + 1));
    const cv = document.createElement('canvas'); cv.width = 25; cv.height = rows * 10;
    const ctx = cv.getContext('2d');
    ctx.drawImage(base, 0, 0);
    statuses().forEach((s) => drawIcon(ctx, base, (s.number | 0) * 10, s.short[lang] || s.short.en || s.short.fr || '', s.color));
    return cv;
  }
  // Aperçu (agrandi) d'une icône : statut du projet (dessiné) ou de base (ligne de l'image)
  function iconCanvas(numberOrStatus, lang, scale) {
    const cv = h('canvas', { class: 'pjst-icon', width: 25, height: 10 });
    cv.style.width = 25 * (scale || 2) + 'px'; cv.style.height = 10 * (scale || 2) + 'px';
    const base = S.images[lang || 'fr'] || S.images.fr;
    if (!base) return cv;
    const ctx = cv.getContext('2d');
    if (typeof numberOrStatus === 'object') drawIcon(ctx, base, 0, numberOrStatus.short[lang || 'fr'] || '', numberOrStatus.color);
    else if (numberOrStatus * 10 < base.height) ctx.drawImage(base, 0, numberOrStatus * 10, 25, 10, 0, 0, 25, 10);
    return cv;
  }

  // ---------------------------------------------------------------------------
  // Enregistrement
  // ---------------------------------------------------------------------------
  function validate() {
    const ids = new Set(); const nums = new Set();
    for (const s of statuses()) {
      if (!/^[a-z][a-z0-9_]*$/.test(s.id)) return `Identifiant invalide : « ${s.id} » (lettres minuscules, chiffres, _)`;
      if (ids.has(s.id)) return `Identifiant en double : ${s.id}`;
      if (['poison', 'paralysis', 'burn', 'sleep', 'freeze', 'confusion', 'toxic', 'death', 'ko', 'flinch', 'cure'].includes(s.id)) return `« ${s.id} » est déjà un statut de PSDK.`;
      if ((s.number | 0) < 10) return `Numéro de ${s.id} : 10 ou plus.`;
      if (nums.has(s.number)) return `Numéro en double : ${s.number}`;
      ids.add(s.id); nums.add(s.number);
    }
    return null;
  }
  async function save() {
    if (!S.config) return;
    const err = validate();
    if (err) { toast(err, true); return; }
    try {
      const icons = {};
      LANGS.forEach((lang) => { const cv = buildSheet(lang); if (cv) icons[lang] = cv.toDataURL('image/png'); });
      const r = await call('save', { projectPath: S.projectPath, config: S.config, icons });
      S.saved = snapshot();
      for (const lang of LANGS) if (icons[lang]) S.images[lang] = await loadImage(icons[lang]);
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
    try {
      const r = await call('buildPlugin', { projectPath: S.projectPath });
      if (!r.built) toast('Plugin non reconstruit : ' + (r.error || '?'), true);
    } catch (e) { toast('Plugin non reconstruit : ' + e.message, true); }
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
      h('div', { class: 'pjs-topbar-left' }, h('span', { class: 'pjs-top-title' }, 'Statuts'),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + statusCls }, statusTxt),
        h('button', { class: 'pjs-btn secondary', onclick: () => { if (!dirty() || confirm('Statuts : abandonner les modifications non enregistrées ?')) loadProject(S.projectPath); }, title: 'Relire les fichiers du projet' }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.config, title: 'Ctrl+S' }, 'Enregistrer'))));
    const page = h('div', { class: 'pjs-page' });
    root.appendChild(page);
    if (S.error) { page.appendChild(h('div', { class: 'pjs-empty err' }, S.error)); return; }
    if (!S.config) { page.appendChild(h('div', { class: 'pjs-empty' }, 'Chargement…')); return; }
    const content = h('div', { class: 'pjs-content pjst-content' });
    page.appendChild(content);
    const p = S.ctx.plugin;
    if (p && !p.source) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le dossier scripts/statuts est introuvable.'));
    else if (p && !p.installed) content.appendChild(h('div', { class: 'pjs-warn' }, "Le plugin « statuts » n'est pas encore installé : lance construire_plugins.bat une fois (ensuite, Enregistrer le met à jour tout seul)."));
    const row = h('div', { class: 'pjs-row pjst-row' });
    content.appendChild(row);
    row.appendChild(renderList());
    const editor = h('div', { class: 'pjs-block pjst-editor' });
    row.appendChild(editor);
    if (S.sel && S.sel.startsWith('base:')) renderBase(editor, +S.sel.slice(5));
    else if (current()) renderCustom(editor, current());
    else editor.appendChild(h('div', { class: 'pjs-empty' }, 'Choisis un statut.'));
    page.scrollTop = scroll;
  }

  function renderList() {
    const list = h('div', { class: 'pjst-list' });
    const item = (key, icon, name, sub) => h('div', { class: 'pjs-item pjst-item' + (S.sel === key ? ' active' : ''), onclick: () => { S.sel = key; render(); } },
      icon, h('span', { class: 'pjst-name' }, name), sub ? h('span', { class: 'pjst-sub' }, sub) : null);
    list.appendChild(h('div', { class: 'pjst-group' }, 'Statuts du projet'));
    statuses().forEach((s) => list.appendChild(item('custom:' + s.id, iconCanvas(s, 'fr', 2), s.name.fr || s.id, '#' + s.number)));
    list.appendChild(h('button', { class: 'pjs-btn secondary small pjst-add', onclick: addStatus }, '+ Nouveau statut'));
    list.appendChild(h('div', { class: 'pjst-group' }, 'Statuts de base (PSDK)'));
    BASE.forEach((b) => list.appendChild(item('base:' + b.number, iconCanvas(b.number, 'fr', 2), b.name)));
    requestAnimationFrame(() => { const a = list.querySelector('.active'); if (a) scrollInto(a); });
    return h('div', { class: 'pjs-block pjst-list-block' }, h('div', { class: 'pjs-block-head' }, h('h2', null, 'Statuts')), list);
  }

  function addStatus() {
    const n = Math.max(9, ...statuses().map((s) => s.number | 0)) + 1;
    let id = 'nouveau'; let k = 2;
    while (statuses().some((s) => s.id === id)) id = 'nouveau_' + k++;
    const s = normalize({ id, number: n, name: { fr: 'Nouveau statut', en: 'New status' }, short: { fr: 'NEW', en: 'NEW', es: 'NEW' }, color: '#3a7bd5',
      stats: {}, damage: 0, immune_types: [], catch_rate: 1.5, moves: [], messages: {
        inflict: { fr: '[nom] est atteint !', en: '[nom] is affected!' }, already: { fr: '[nom] est déjà atteint !', en: '[nom] is already affected!' },
        damage: { fr: '[nom] souffre !', en: '[nom] is hurt!' }, cure: { fr: '[nom] est guéri !', en: '[nom] was cured!' }, immune: { fr: 'Ça n’affecte pas [nom]…', en: 'It doesn’t affect [nom]…' } } });
    statuses().push(s);
    S.sel = 'custom:' + id;
    render();
  }

  const field = (label, input, hint) => h('div', { class: 'pjst-field' }, h('div', { class: 'pjst-label' }, label), input, hint ? h('div', { class: 'pjs-hint' }, hint) : null);
  const text = (value, onchange, extra) => h('input', Object.assign({ class: 'pjs-input', value: value || '', oninput: (e) => { onchange(e.target.value); updateStatus(); } }, extra || {}));

  function renderBase(editor, number) {
    const b = BASE.find((x) => x.number === number);
    editor.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, b.name), h('span', { class: 'pjs-hint' }, 'Statut de PSDK — numéro ' + number)));
    editor.appendChild(field('Icônes', h('div', { class: 'pjst-icons' }, LANGS.map((l) => h('span', { class: 'pjst-iconlang' }, iconCanvas(number, l, 4), l.toUpperCase())))));
    editor.appendChild(field('Effet', h('div', { class: 'pjst-text' }, b.text)));
    editor.appendChild(h('div', { class: 'pjs-hint' }, 'Les statuts de base sont gérés par PSDK : leurs effets ne se changent pas ici. Les statuts du projet (au-dessus) se règlent entièrement.'));
  }

  function renderCustom(editor, s) {
    const rerender = () => render();
    editor.appendChild(h('div', { class: 'pjs-block-head' }, h('div', { class: 'pjst-head' }, iconCanvas(s, 'fr', 3), h('h2', null, s.name.fr || s.id)),
      h('button', { class: 'pjs-btn danger small', onclick: () => {
        if (!confirm(`Supprimer le statut « ${s.name.fr || s.id} » ? Les Pokémon qui l'ont dans une sauvegarde le perdront.`)) return;
        S.config.statuses = statuses().filter((x) => x !== s); S.sel = statuses()[0] ? 'custom:' + statuses()[0].id : 'base:1'; render();
      } }, 'Supprimer')));

    // Identité
    const sec1 = h('div', { class: 'pjs-section first pjst-grid3' });
    sec1.appendChild(field('Nom (français)', text(s.name.fr, (v) => { s.name.fr = v; })));
    sec1.appendChild(field('Nom (anglais)', text(s.name.en, (v) => { s.name.en = v; })));
    sec1.appendChild(field('Identifiant', h('input', { class: 'pjs-input', value: s.id, onchange: (e) => {
      const v = e.target.value.trim().toLowerCase().replace(/[^a-z0-9_]/g, '_');
      S.sel = 'custom:' + v; s.id = v; render();
    } }), 'Pour les scripts : infliger_statut(:' + s.id + ')'));
    editor.appendChild(sec1);

    // Icône
    const sec2 = h('div', { class: 'pjs-section' });
    sec2.appendChild(h('div', { class: 'pjst-label' }, 'Icône'));
    const icons = h('div', { class: 'pjst-icons' });
    const drawIcons = () => { icons.textContent = ''; LANGS.forEach((l) => icons.appendChild(h('span', { class: 'pjst-iconlang' }, iconCanvas(s, l, 4), l.toUpperCase()))); };
    drawIcons();
    const shortInput = (l) => h('label', { class: 'pjst-short' }, h('span', { class: 'pjs-label' }, 'Abrév. ' + l.toUpperCase()),
      h('input', { class: 'pjs-input', value: s.short[l] || '', maxlength: 4, oninput: (e) => { s.short[l] = cleanShort(e.target.value); drawIcons(); updateStatus(); }, onchange: rerender }));
    sec2.appendChild(h('div', { class: 'pjst-iconrow' }, icons,
      h('div', { class: 'pjst-iconform' }, LANGS.map(shortInput),
        h('label', { class: 'pjst-short' }, h('span', { class: 'pjs-label' }, 'Couleur'),
          h('input', { type: 'color', class: 'pjst-color', value: s.color, oninput: (e) => { s.color = e.target.value; drawIcons(); updateStatus(); }, onchange: rerender })))));
    sec2.appendChild(h('div', { class: 'pjs-hint' }, `Ligne ${s.number} de graphics/interface/statuts<fr|en|es>.png, redessinée à l'enregistrement (A à Z, 0 à 9, 4 lettres au plus). La couleur teinte aussi le Pokémon en combat.`));
    editor.appendChild(sec2);

    // Effets
    const sec3 = h('div', { class: 'pjs-section' });
    sec3.appendChild(h('div', { class: 'pjst-label' }, 'Statistiques divisées par'));
    sec3.appendChild(h('div', { class: 'pjst-stats' }, STATS.map(([k, label]) => h('label', { class: 'pjst-stat' + (+s.stats[k] !== 1 ? ' on' : '') }, h('span', { class: 'pjs-label' }, label),
      h('input', { class: 'pjs-input num', type: 'number', min: 0.1, max: 10, step: 0.1, value: s.stats[k], onchange: (e) => { s.stats[k] = Math.max(0.1, Math.min(10, +e.target.value || 1)); rerender(); } }),
      h('span', { class: 'pjs-hint inline' }, +s.stats[k] === 1 ? 'normale' : `× ${(1 / s.stats[k]).toFixed(2).replace('.', ',')}`)))));
    sec3.appendChild(h('div', { class: 'pjs-hint' }, '1 : pas de changement. 1,5 : la stat est divisée par 1,5 tant que le Pokémon a ce statut (comme la Brûlure divise l’Attaque par 2).'));
    const dmg = s.damage | 0;
    sec3.appendChild(field('Dégâts à la fin de chaque tour', h('div', { class: 'pjst-inline' }, h('span', null, '1 /'),
      h('input', { class: 'pjs-input num', type: 'number', min: 0, max: 100, value: dmg, onchange: (e) => { s.damage = Math.max(0, Math.min(100, Math.round(+e.target.value || 0))); rerender(); } }),
      h('span', { class: 'pjs-hint inline' }, dmg > 0 ? `des PV max (${(100 / dmg).toFixed(2).replace('.', ',')} %)` : 'aucun dégât')),
      '0 : pas de dégâts. Garde Magik protège des dégâts.'));
    sec3.appendChild(field('Bonus de capture', h('input', { class: 'pjs-input num', type: 'number', min: 1, max: 5, step: 0.5, value: s.catch_rate,
      onchange: (e) => { s.catch_rate = Math.max(1, Math.min(5, +e.target.value || 1)); rerender(); } }), '× 1,5 pour Poison, Paralysie, Brûlure ; × 2,5 pour Sommeil et Gel.'));
    editor.appendChild(sec3);

    // Types immunisés
    const sec4 = h('div', { class: 'pjs-section' });
    sec4.appendChild(h('div', { class: 'pjst-label' }, 'Types immunisés'));
    sec4.appendChild(h('div', { class: 'pjst-types' }, S.ctx.types.map((t) => {
      const on = s.immune_types.includes(t.db);
      return h('button', { class: 'pjst-type' + (on ? ' on' : ''), style: on && t.color ? { borderColor: t.color, background: t.color + '33' } : null,
        onclick: () => { s.immune_types = on ? s.immune_types.filter((x) => x !== t.db) : s.immune_types.concat(t.db); rerender(); } }, t.name);
    })));
    sec4.appendChild(h('div', { class: 'pjs-hint' }, 'Un Pokémon de ces types ne peut pas avoir ce statut (comme les types Feu pour la Brûlure).'));
    editor.appendChild(sec4);

    // Attaques
    const sec5 = h('div', { class: 'pjs-section' });
    sec5.appendChild(h('div', { class: 'pjst-label' }, 'Attaques qui l’infligent'));
    const moveOf = (db) => S.ctx.moves.find((m) => m.db === db);
    const listId = 'pjst-moves-list';
    if (!document.getElementById(listId)) {
      const dl = h('datalist', { id: listId }, S.ctx.moves.map((m) => h('option', { value: `${m.name} (${m.db})` })));
      root.appendChild(dl);
    }
    const table = h('div', { class: 'pjst-moves' });
    s.moves.forEach((m, i) => {
      const mv = moveOf(m.move);
      table.appendChild(h('div', { class: 'pjst-move' },
        h('input', { class: 'pjs-input', list: listId, value: mv ? `${mv.name} (${mv.db})` : m.move, placeholder: 'Attaque', onchange: (e) => {
          const v = e.target.value; const mm = /\(([a-z0-9_]+)\)\s*$/.exec(v);
          const found = mm ? moveOf(mm[1]) : S.ctx.moves.find((x) => x.name.toLowerCase() === v.trim().toLowerCase() || x.db === v.trim());
          if (found) m.move = found.db; else toast('Attaque introuvable : ' + v, true);
          rerender();
        } }),
        h('span', { class: 'pjs-hint inline' }, mv ? `${mv.category === 'status' ? 'statut' : mv.category === 'physical' ? 'physique' : 'spéciale'}${mv.power ? ' · ' + mv.power : ''}` : ''),
        h('input', { class: 'pjs-input num', type: 'number', min: 1, max: 100, value: m.chance, onchange: (e) => { m.chance = Math.max(1, Math.min(100, Math.round(+e.target.value || 1))); rerender(); } }),
        h('span', { class: 'pjs-hint inline' }, '%'),
        h('button', { class: 'pjst-x', title: 'Retirer', onclick: () => { s.moves.splice(i, 1); rerender(); } }, '×')));
    });
    sec5.appendChild(table);
    sec5.appendChild(h('button', { class: 'pjs-btn secondary small pjst-addmove', onclick: () => { s.moves.push({ move: '', chance: 20 }); rerender(); } }, '+ Ajouter une attaque'));
    sec5.appendChild(h('div', { class: 'pjs-hint' }, 'Chance d’infliger le statut à chaque cible touchée, en plus des effets de l’attaque dans Studio. Une attaque de statut à 100 % affiche un message si elle échoue.'));
    editor.appendChild(sec5);

    // Messages
    const sec6 = h('div', { class: 'pjs-section last' });
    sec6.appendChild(h('div', { class: 'pjst-label' }, 'Messages de combat'));
    const msgs = h('div', { class: 'pjst-msgs' }, h('span', null), h('span', { class: 'pjs-label' }, 'Français'), h('span', { class: 'pjs-label' }, 'Anglais'));
    MESSAGES.forEach(([k, label]) => {
      msgs.appendChild(h('span', { class: 'pjs-label' }, label));
      msgs.appendChild(text(s.messages[k].fr, (v) => { s.messages[k].fr = v; }));
      msgs.appendChild(text(s.messages[k].en, (v) => { s.messages[k].en = v; }));
    });
    sec6.appendChild(msgs);
    sec6.appendChild(h('div', { class: 'pjs-hint' }, '[nom] : nom du Pokémon (« Rattata sauvage », « Rattata ennemi » pour l’adversaire).'));
    editor.appendChild(sec6);
  }

  // ---------------------------------------------------------------------------
  // Page « Statuts » : Données > Statuts (/database/statuses)
  // ---------------------------------------------------------------------------
  const PAGE_ID = 'statuts';
  function mount(hostEl) {
    root = h('div', { id: 'pjst-root' });
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

  window.pjStatutsEditor = { state: S, render, save };
})();
