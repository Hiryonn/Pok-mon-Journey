/* eslint-disable */
// =============================================================================
// Advanced Pokédex — éditeur du plugin « advanced_pokedex » pour Pokémon Studio
// Ouvert par « Données > Pokédex > Taille / Poids » (ou Ctrl+Maj+D).
// Aperçu en direct des pages Taille et Poids (mêmes images, mêmes calculs qu'en jeu) :
//   personnages à comparer, mise en page (curseurs ou glisser dans l'aperçu), textes et options.
// Utilise le style de l'éditeur Smartphone (classes pjs-*), installé avant lui.
// =============================================================================
(() => {
  'use strict';
  // fait défiler seulement la liste qui contient l'élément (scrollIntoView ferait aussi défiler la fenêtre de Studio,
  // ce qui décale toute la page sous la barre du haut)
  function scrollInto(el, center) {
    let box = el.parentElement;
    while (box && box !== document.body && !/^pj\w*-root$/.test(box.id)) {
      const st = getComputedStyle(box);
      if (/(auto|scroll)/.test(st.overflowY + st.overflowX) && (box.scrollHeight > box.clientHeight || box.scrollWidth > box.clientWidth)) break;
      box = box.parentElement;
    }
    if (!box || box === document.body || /^pj\w*-root$/.test(box.id)) return;
    const b = box.getBoundingClientRect(); const r = el.getBoundingClientRect();
    if (center) box.scrollTop += (r.top - b.top) - (box.clientHeight - r.height) / 2;
    else if (r.top < b.top) box.scrollTop -= b.top - r.top;
    else if (r.bottom > b.bottom) box.scrollTop += r.bottom - b.bottom;
    if (r.left < b.left) box.scrollLeft -= b.left - r.left;
    else if (r.right > b.right) box.scrollLeft += r.right - b.right;
  }
  if (window.__pjAdexLoaded) return;
  window.__pjAdexLoaded = true;

  // ---------------------------------------------------------------------------
  // Valeurs par défaut (les mêmes que dans le plugin)
  // ---------------------------------------------------------------------------
  const DEFAULTS = {
    klass: 'AdvancedPokedexConfig',
    characters: [{ name: '', player: true, height: 1.55, weight: 46.0, sprite: '', cols: 4, rows: 4, frame: 0 }],
    labels: { height: { fr: 'Taille', en: 'Height' }, weight: { fr: 'Poids', en: 'Weight' } },
    require_caught: true,
    silhouette_color: '#000000',
    silhouette_color_pe: '#344751',
    height_max: 104,
    height_base_y: 164,
    height_pokemon_x: 96,
    height_character_x: 222,
    weight_scale_x: 83,
    weight_scale_y: 92,
    weight_icon_zoom: 1,
    weight_character_zoom: 1,
    pan_offset: 3,
    show_titles: true,
    show_tabs: true,
    theme: 'auto',
  };
  // Habillage du Pokédex PE (interface_pe/scripts/00100 Pokedex/008 Advanced Pokedex.rb)
  const PE = {
    boxes: [[16, 177, 132, 16], [173, 177, 132, 16]],
    nav: [[0, 48, 'back'], [52, 108, 'height'], [160, 108, 'weight'], [272, 48, 'character']],
  };
  // Couleurs 10 (blanc) et 11 (bleu clair) des textes de PSDK : remplissage, ombre
  const COLORS = { 0: ['rgb(16,24,33)', 'rgb(208,208,200)'], 10: ['rgb(255,255,255)', 'rgb(96,96,96)'], 11: ['rgb(148,180,240)', 'rgb(96,96,96)'] };
  const LAYOUT_KEYS = ['height_max', 'height_base_y', 'height_pokemon_x', 'height_character_x', 'weight_scale_x', 'weight_scale_y', 'weight_icon_zoom', 'weight_character_zoom', 'pan_offset'];
  // Constantes du plugin (00100 Configuration.rb)
  const PANS = [[[22, 0], [130, 29]], [[22, 2], [130, 27]], [[20, 6], [132, 23]], [[20, 8], [132, 21]],
    [[20, 10], [132, 19]], [[20, 15], [132, 15]], [[22, 19], [132, 10]], [[22, 21], [132, 8]],
    [[22, 23], [132, 6]], [[22, 27], [132, 2]], [[22, 29], [132, 0]]];
  const SCALE_FRAMES = 11;
  const BOXES = [[24, 179, 114], [182, 179, 114]];
  const TABS = { height: [111, 1], weight: [166, 1] };
  const TITLE = [160, 31];
  const SCALE_STEP_TIME = 3;
  const ZOOM = 2;
  // Couleur 0 des textes de PSDK (graphics/windowskins/_colors.png) : remplissage et ombre
  const TEXT_FILL = 'rgb(16,24,33)';
  const TEXT_SHADOW = 'rgb(208,208,200)';

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------
  const api = window.pjAdex;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API Advanced Pokédex n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  const num = (v, d = 0) => { const n = parseFloat(String(v).replace(',', '.')); return Number.isFinite(n) ? n : d; };
  let toastTimer = null;
  function toast(msg, err) {
    document.querySelectorAll('.pjs-toast').forEach((t) => t.remove());
    const t = h('div', { class: 'pjs-toast' + (err ? ' err' : '') }, msg);
    document.body.appendChild(t);
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.remove(), err ? 6000 : 2500);
  }
  const projectList = () => { try { return JSON.parse(localStorage.getItem('projectList') || '[]'); } catch (e) { return []; } };

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const S = {
    open: false,
    projectPath: null,
    ctx: null,
    config: null,
    saved: null,
    error: null,
    page: 'height',
    sel: null,          // { db, form }
    charIndex: 0,
    gender: 'm',        // sprite du joueur dans l'aperçu
    images: new Map(),  // clé -> Promise<{ img, data }|null>
    anim: { frame: 5, target: 5, timer: 0 },
    hit: [],            // zones déplaçables de l'aperçu
    pluginBuilding: false,
    pluginError: null,
  };
  let root = null;
  let canvas = null;
  let fontFamily = 'sans-serif';
  let smallFamily = 'sans-serif';

  const snapshot = () => JSON.stringify(S.config);
  const dirty = () => S.config && S.saved !== snapshot();
  const cfg = (k) => (S.config[k] === undefined || S.config[k] === null ? DEFAULTS[k] : S.config[k]);

  // ---------------------------------------------------------------------------
  // Images
  // ---------------------------------------------------------------------------
  function decode(url) {
    return new Promise((resolve) => {
      if (!url) { resolve(null); return; }
      const img = new Image();
      img.onload = () => {
        const c = document.createElement('canvas');
        c.width = img.width; c.height = img.height;
        const g = c.getContext('2d');
        g.drawImage(img, 0, 0);
        let data = null;
        try { data = g.getImageData(0, 0, img.width, img.height); } catch (e) { /* rien */ }
        resolve({ img, data });
      };
      img.onerror = () => resolve(null);
      img.src = url;
    });
  }
  // image du plugin (graphics/pokedex/advanced)
  function asset(name) {
    const key = 'asset:' + name;
    if (!S.images.has(key)) S.images.set(key, decode(S.ctx.assets[name]));
    return S.images.get(key);
  }
  // image du projet : chemin dans graphics/ sans extension
  function picture(rel) {
    if (!rel) return Promise.resolve(null);
    const key = 'g:' + rel;
    if (!S.images.has(key)) {
      S.images.set(key, call('readImages', { projectPath: S.projectPath, files: [rel] }).then((m) => decode(m[rel])).catch(() => null));
    }
    return S.images.get(key);
  }
  // zone non transparente (relative à rect)
  const bboxCache = new WeakMap();
  function bbox(pic, rect) {
    const [rx, ry, rw, rh] = rect;
    let byPic = bboxCache.get(pic);
    if (!byPic) { byPic = new Map(); bboxCache.set(pic, byPic); }
    const key = rect.join(',');
    if (byPic.has(key)) return byPic.get(key);
    let x0 = rw; let y0 = rh; let x1 = -1; let y1 = -1;
    const d = pic.data && pic.data.data;
    if (d) {
      for (let y = 0; y < rh; y++) {
        for (let x = 0; x < rw; x++) {
          if (d[((ry + y) * pic.data.width + rx + x) * 4 + 3] === 0) continue;
          if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; y1 = y;
        }
      }
    }
    const box = x1 < 0 ? [0, 0, rw, rh] : [x0, y0, x1 - x0 + 1, y1 - y0 + 1];
    byPic.set(key, box);
    return box;
  }

  // ---------------------------------------------------------------------------
  // Données
  // ---------------------------------------------------------------------------
  const creatureOf = (db) => S.ctx && S.ctx.creatures.find((c) => c.dbSymbol === db);
  const formOf = (c, form) => c && (c.forms.find((f) => (f.form | 0) === (form | 0)) || c.forms[0]);
  const characters = () => (Array.isArray(S.config.characters) && S.config.characters.length ? S.config.characters : DEFAULTS.characters);
  const currentCharacter = () => { const list = characters(); return list[((S.charIndex % list.length) + list.length) % list.length]; };
  const charName = (c) => (c.name || (c.player ? 'Joueur (son nom en jeu)' : 'Personnage'));
  const charSprite = (c) => (c.sprite || (c.player ? `characters/player_${S.gender}_walk` : ''));
  function charRect(pic, c) {
    const cols = Math.max(1, c.cols | 0); const rows = Math.max(1, c.rows | 0);
    const frame = Math.min(Math.max(0, c.frame | 0), cols * rows - 1);
    const w = Math.floor(pic.img.width / cols); const hh = Math.floor(pic.img.height / rows);
    return [(frame % cols) * w, Math.floor(frame / cols) * hh, w, hh];
  }
  function label(key) {
    const l = (cfg('labels') || {})[key] || {};
    return l.fr || l.en || (key === 'height' ? 'Taille' : 'Poids');
  }
  const fmt = (key, v) => (key === 'height' ? `${(+v || 0).toFixed(1)} m` : `${(+v || 0).toFixed(1)} kg`);

  // ---------------------------------------------------------------------------
  // Aperçu (les mêmes calculs que GamePlay::AdvancedPokedex)
  // ---------------------------------------------------------------------------
  let drawToken = 0;
  let drawQueued = false;
  function scheduleDraw() {
    if (drawQueued) return;
    drawQueued = true;
    requestAnimationFrame(() => { drawQueued = false; draw(); });
  }

  function scaleFrameFor(pw, cw) {
    if (pw <= 0 || cw <= 0) return 5;
    return Math.min(Math.max(5 + Math.round(Math.log2(pw / cw) * 1.5), 0), SCALE_FRAMES - 1);
  }

  async function draw() {
    if (!canvas || !S.ctx) return;
    const token = ++drawToken;
    const page = S.page;
    const creature = S.sel && creatureOf(S.sel.db);
    const form = formOf(creature, S.sel && S.sel.form);
    const ch = currentCharacter();
    const pe = usePe();
    const [bg, title, tabH, tabW, scale, poke, chr, ball] = await Promise.all([
      asset((pe ? 'pe_adv_' : 'bg_') + page), asset('title_' + page), asset('tab_height'), asset('tab_weight'), asset('scale'),
      // page Taille : sprite de face ; page Poids : icône
      page === 'height' ? (form && form.front ? picture(`pokedex/pokefront/${form.front}`) : null)
        : (form && form.icon ? picture(`pokedex/pokeicon/${form.icon}`) : null),
      picture(charSprite(ch)),
      asset('pe_ball_on'),
    ]);
    if (token !== drawToken || !canvas) return;
    const g = canvas.getContext('2d');
    g.imageSmoothingEnabled = false;
    g.clearRect(0, 0, 320, 240);
    S.hit = [];
    if (bg) g.drawImage(bg.img, 0, 0); else { g.fillStyle = '#f8f8f8'; g.fillRect(0, 0, 320, 240); }
    if (!pe && title && cfg('show_titles') !== false) g.drawImage(title.img, TITLE[0] - Math.floor(title.img.width / 2), TITLE[1]);
    if (!pe && cfg('show_tabs') !== false) {
      [['height', tabH], ['weight', tabW]].forEach(([p, t]) => {
        if (!t) return;
        const hh = t.img.height / 2;
        g.drawImage(t.img, 0, p === page ? hh : 0, t.img.width, hh, TABS[p][0], TABS[p][1], t.img.width, hh);
      });
    }
    const pw = form ? +form.weight || 0 : 0;
    const ph = form ? +form.height || 0 : 0;
    const cw = num(ch.weight); const chh = num(ch.height);
    const silhouette = cfg(pe ? 'silhouette_color_pe' : 'silhouette_color') || '#000000';
    if (page === 'height') {
      const tallest = Math.max(ph, chh, 0.01);
      const pxPerM = num(cfg('height_max'), 104) / tallest;
      const baseY = num(cfg('height_base_y'), 164);
      if (poke) place(g, poke, null, ph * pxPerM, num(cfg('height_pokemon_x')), baseY, silhouette, null, 'pokemon');
      if (chr) place(g, chr, charRect(chr, ch), chh * pxPerM, num(cfg('height_character_x')), baseY, silhouette, null, 'character');
      // ligne de base (aide visuelle de l'éditeur)
      g.fillStyle = 'rgba(80,120,255,.35)';
      g.fillRect(14, baseY, 292, 1);
    } else if (scale) {
      const sx = num(cfg('weight_scale_x')); const sy = num(cfg('weight_scale_y'));
      const fh = scale.img.height / SCALE_FRAMES;
      const f = S.anim.frame;
      g.drawImage(scale.img, 0, f * fh, scale.img.width, fh, sx, sy, scale.img.width, fh);
      S.hit.push({ kind: 'scale', x: sx, y: sy, w: scale.img.width, h: fh });
      const [[lx, ly], [rx, ry]] = PANS[f];
      const off = num(cfg('pan_offset'), 3);
      const zoomOf = (k) => { const z = num(cfg(k), 1); return z > 0 ? z : 1; };
      if (poke) place(g, poke, [0, 0, Math.min(poke.img.height, poke.img.width), poke.img.height], 0, sx + lx, sy + ly + off, null, null, 'icon', zoomOf('weight_icon_zoom'));
      if (chr) place(g, chr, charRect(chr, ch), 0, sx + rx, sy + ry + off, null, null, 'weightchar', zoomOf('weight_character_zoom'));
    }
    // textes des cadres du bas
    g.font = `13px "${fontFamily}"`;
    g.textBaseline = 'alphabetic';
    const key = page;
    const texts = [
      [creature ? creature.name : '???', label(key), fmt(key, key === 'height' ? ph : pw)],
      [ch.name || (ch.player ? 'Red' : 'Personnage'), label(key), fmt(key, key === 'height' ? chh : cw)],
    ];
    const color = pe ? 10 : 0;
    (pe ? PE.boxes : BOXES.map(([x, y, w]) => [x, y, w, 20])).forEach(([x, y, w, dy], i) => {
      const [name, lab, value] = texts[i];
      text(g, name, x, y, w, 'left', color);
      text(g, lab, x, y + dy, w, 'left', color);
      text(g, value, x, y + dy, w, 'right', color);
    });
    if (pe) {
      // bandeau : Poké Ball, nom du Pokémon, page ; barre du bas : Fiche / Taille / Poids / Perso.
      if (ball) g.drawImage(ball.img, 4, 4);
      g.font = `bold 13px "${fontFamily}"`;
      text(g, creature ? creature.name : '???', 40, 3, 136, 'left', 10);
      g.font = `11px "${smallFamily}"`;
      text(g, label(page), 200, 5, 114, 'right', 10, 10);
      g.font = `13px "${fontFamily}"`;
      const many = characters().length > 1;
      PE.nav.forEach(([x, w, action]) => {
        const str = action === 'back' ? 'Fiche' : action === 'character' ? 'Perso.' : label(action);
        const col = (action === 'height' || action === 'weight') ? (action === page ? 10 : 11) : (action === 'character' && !many ? 11 : 10);
        text(g, str, x, 220, w, 'center', col);
      });
    }
    // animation de la balance
    if (page === 'weight' && S.anim.frame !== S.anim.target) {
      requestAnimationFrame(() => {
        if (!S.open || S.page !== 'weight') return;
        S.anim.timer += 1;
        if (S.anim.timer >= SCALE_STEP_TIME) { S.anim.timer = 0; S.anim.frame += S.anim.target > S.anim.frame ? 1 : -1; }
        draw();
      });
    }
  }

  function text(g, str, x, y, w, align, color = 0, size = 12) {
    const base = y + size;
    const [fill, shadow] = COLORS[color] || COLORS[0];
    g.textAlign = align;
    const tx = align === 'right' ? x + w : align === 'center' ? x + w / 2 : x;
    g.fillStyle = shadow;
    [[1, 0], [0, 1], [1, 1]].forEach(([dx, dy]) => g.fillText(str, tx + dx, base + dy, w));
    g.fillStyle = fill;
    g.fillText(str, tx, base, w);
  }

  // Place une image debout : centrée sur x, pieds sur baseY, partie visible haute de height pixels
  function place(g, pic, rect, height, x, baseY, silhouette, maxWidth, hitKind, fixedZoom) {
    if (!pic || (!fixedZoom && height <= 0)) return;
    rect = rect || [0, 0, pic.img.width, pic.img.height];
    const [bx, by, bw, bh] = bbox(pic, rect);
    let zoom = fixedZoom || Math.max(height, 1) / bh;
    if (maxWidth) zoom = Math.min(zoom, maxWidth / bw);
    const dx = Math.round(x - (bx + bw / 2) * zoom);
    const dy = Math.round(baseY - (by + bh) * zoom);
    const dw = rect[2] * zoom; const dh = rect[3] * zoom;
    if (silhouette) {
      const off = document.createElement('canvas');
      off.width = Math.max(1, Math.ceil(dw)); off.height = Math.max(1, Math.ceil(dh));
      const o = off.getContext('2d');
      o.imageSmoothingEnabled = false;
      o.drawImage(pic.img, rect[0], rect[1], rect[2], rect[3], 0, 0, dw, dh);
      o.globalCompositeOperation = 'source-in';
      o.fillStyle = silhouette;
      o.fillRect(0, 0, off.width, off.height);
      g.drawImage(off, dx, dy);
    } else {
      g.drawImage(pic.img, rect[0], rect[1], rect[2], rect[3], dx, dy, dw, dh);
    }
    if (hitKind) S.hit.push({ kind: hitKind, x: dx + bx * zoom, y: dy + by * zoom, w: bw * zoom, h: bh * zoom });
  }

  function restartScale() {
    const creature = S.sel && creatureOf(S.sel.db);
    const form = formOf(creature, S.sel && S.sel.form);
    S.anim = { frame: 5, target: scaleFrameFor(form ? +form.weight || 0 : 0, num(currentCharacter().weight)), timer: 0 };
    scheduleDraw();
  }

  // Glisser dans l'aperçu : Pokémon / personnage (page Taille), balance (page Poids)
  function setupDrag(c) {
    let drag = null;
    c.addEventListener('mousedown', (e) => {
      const x = e.offsetX / ZOOM; const y = e.offsetY / ZOOM;
      const hit = [...S.hit].filter((r) => ['pokemon', 'character', 'scale'].includes(r.kind)).reverse().find((r) => x >= r.x - 3 && x <= r.x + r.w + 3 && y >= r.y - 3 && y <= r.y + r.h + 3);
      if (!hit) return;
      const keys = hit.kind === 'pokemon' ? ['height_pokemon_x', 'height_base_y'] : hit.kind === 'character' ? ['height_character_x', 'height_base_y'] : ['weight_scale_x', 'weight_scale_y'];
      drag = { keys, x, y, start: keys.map((k) => num(cfg(k))) };
      e.preventDefault();
    });
    window.addEventListener('mousemove', (e) => {
      if (!drag || !canvas) return;
      const r = canvas.getBoundingClientRect();
      const x = (e.clientX - r.left) / ZOOM; const y = (e.clientY - r.top) / ZOOM;
      S.config[drag.keys[0]] = Math.round(drag.start[0] + x - drag.x);
      S.config[drag.keys[1]] = Math.round(drag.start[1] + y - drag.y);
      syncLayoutInputs();
      scheduleDraw();
      updateStatus();
    });
    window.addEventListener('mouseup', () => { drag = null; });
    c.addEventListener('mousemove', (e) => {
      const x = e.offsetX / ZOOM; const y = e.offsetY / ZOOM;
      c.style.cursor = S.hit.filter((r) => ['pokemon', 'character', 'scale'].includes(r.kind)).some((r) => x >= r.x - 3 && x <= r.x + r.w + 3 && y >= r.y - 3 && y <= r.y + r.h + 3) ? 'move' : 'default';
    });
  }

  // ---------------------------------------------------------------------------
  // Chargement / enregistrement
  // ---------------------------------------------------------------------------
  async function loadFonts() {
    const fonts = (S.ctx && S.ctx.fonts) || {};
    for (const [key, family] of [['main', 'PJXPokemonDS'], ['small', 'PJXPowerGreenSmall']]) {
      if (!fonts[key]) continue;
      try {
        const face = new FontFace(family, `url(${fonts[key]})`);
        await face.load();
        document.fonts.add(face);
        if (key === 'main') fontFamily = family; else smallFamily = family;
      } catch (e) { /* police de secours */ }
    }
  }

  // Habillage PE : réglage « auto » = PE si le Pokédex PE (interface_pe) est actif
  function usePe() {
    const theme = cfg('theme');
    if (!S.ctx || !S.ctx.assets.pe_adv_height) return false;
    if (theme === 'pe') return true;
    if (theme === 'essentials') return false;
    return !!S.ctx.peEnabled;
  }

  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.ctx = null; S.config = null; S.error = null; S.images = new Map();
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath });
      const c = Object.assign(clone(DEFAULTS), S.ctx.config || {});
      if (!Array.isArray(c.characters) || !c.characters.length) c.characters = clone(DEFAULTS.characters);
      c.labels = Object.assign(clone(DEFAULTS.labels), c.labels || {});
      S.config = c;
      S.saved = S.ctx.config ? snapshot() : null;
      if (!S.sel || !creatureOf(S.sel.db)) {
        const first = S.ctx.creatures.find((x) => x.id > 0) || S.ctx.creatures[0];
        S.sel = first ? { db: first.dbSymbol, form: first.forms[0] ? first.forms[0].form | 0 : 0 } : null;
      }
      await loadFonts();
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
      toast('Enregistré' + (p.source && !p.installed ? ' — plugin pas encore installé : lance construire_plugin_advanced_pokedex.bat une fois' : ''));
      render();
      if (p.source) rebuildPlugin();
    } catch (e) { toast('Erreur de sauvegarde : ' + e.message, true); }
  }

  let buildQueued = false;
  async function rebuildPlugin() {
    if (S.pluginBuilding) { buildQueued = true; return; }
    S.pluginBuilding = true; S.pluginError = null; updateStatus();
    try {
      const r = await call('buildPlugin', { projectPath: S.projectPath });
      if (!r.built) S.pluginError = r.error || 'échec';
    } catch (e) { S.pluginError = e.message; }
    S.pluginBuilding = false; updateStatus();
    if (S.pluginError) toast("Enregistré, mais advanced_pokedex.psdkplug n'a pas pu être reconstruit : " + S.pluginError, true);
    if (buildQueued) { buildQueued = false; rebuildPlugin(); }
  }

  function statusText() {
    if (!S.config) return ['', ''];
    if (dirty()) return ['Modifications non enregistrées', ' dirty'];
    if (S.pluginBuilding) return ['Mise à jour du plugin…', ''];
    const p = S.ctx && S.ctx.plugin;
    if (p && p.source && !p.installed) return ['Plugin pas installé : construire_plugin_advanced_pokedex.bat', ' dirty'];
    if (p && p.source && (p.outdated.length || p.stale.length)) return ['Plugin installé pas à jour : Enregistrer', ' dirty'];
    if (S.pluginError) return ['Plugin : paquet non reconstruit', ' dirty'];
    return ['Tout est enregistré', ''];
  }
  function updateStatus() {
    const st = root && root.querySelector('.pjs-status');
    if (!st) return;
    const [t, cls] = statusText();
    st.className = 'pjs-status' + cls; st.textContent = t;
  }

  // ---------------------------------------------------------------------------
  // Rendu de la page
  // ---------------------------------------------------------------------------
  let layoutInputs = [];
  function syncLayoutInputs() { layoutInputs.forEach((f) => f()); }

  function render() {
    if (!root) return;
    root.textContent = '';
    canvas = null;
    layoutInputs = [];
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    const [st, stc] = statusText();
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' },
        h('span', { class: 'pjs-top-title' }, 'Advanced Pokédex'),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + stc }, st),
        h('button', { class: 'pjs-btn secondary', onclick: () => { if (!dirty() || confirm('Advanced Pokédex : abandonner les modifications non enregistrées ?')) loadProject(S.projectPath); }, title: 'Relire les fichiers du projet' }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.config, title: 'Ctrl+S' }, 'Enregistrer'))));
    const page = h('div', { class: 'pjs-page' });
    root.appendChild(page);
    if (S.error) { page.appendChild(h('div', { class: 'pjs-empty err' }, S.error)); return; }
    if (!S.config) { page.appendChild(h('div', { class: 'pjs-empty' }, 'Chargement…')); return; }
    const content = h('div', { class: 'pjs-content pjx-content' });
    page.appendChild(content);
    const p = S.ctx.plugin;
    if (p && !p.source) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le dossier scripts/advanced_pokedex est introuvable : extrais le plugin à la racine du projet.'));
    else if (p && !p.installed) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le plugin « advanced_pokedex » n\'est pas encore installé : lance construire_plugin_advanced_pokedex.bat une fois (ensuite, Enregistrer le met à jour tout seul).'));
    if (!S.ctx.assets.bg_height) content.appendChild(h('div', { class: 'pjs-warn' }, 'Images introuvables dans graphics/pokedex/advanced/ : extrais le plugin à la racine du projet.'));
    const row = h('div', { class: 'pjs-row pjx-row' });
    content.appendChild(row);
    row.appendChild(renderPreview());
    const side = h('div', { class: 'pjx-side' });
    row.appendChild(side);
    side.appendChild(renderCharacters());
    side.appendChild(renderLayout());
    side.appendChild(renderTexts());
    if (S.page === 'weight') restartScale(); else scheduleDraw();
  }

  const PAGE_HINTS = {
    height: 'Glisse le Pokémon ou le personnage pour les déplacer (la ligne bleue est le sol, elle n\'apparaît pas en jeu). Le plus grand des deux mesure « Hauteur max » pixels.',
    weight: 'Glisse la balance pour la déplacer. Plus l\'écart de poids est grand, plus la balance penche (11 positions).',
  };
  let refs = { pageButtons: [] };

  // Change de page sans redessiner l'éditeur (les curseurs gardent la main)
  function setPage(page, replay = true) {
    const changed = S.page !== page;
    S.page = page;
    refs.pageButtons.forEach((b) => b.classList.toggle('active', b.dataset.page === page));
    if (refs.replay) refs.replay.style.display = page === 'weight' ? '' : 'none';
    if (refs.hint) refs.hint.textContent = PAGE_HINTS[page];
    if (page === 'weight' && (changed || replay)) restartScale(); else scheduleDraw();
  }

  // Liste déroulante avec recherche (remplace les <datalist> : liste complète, filtrée en tapant, au style de Studio)
  // items : () => [{ label, sub, value, search }] ; onPick(value, item) ; input : champ existant (sinon créé)
  function combo({ value = '', placeholder = '', className = '', items, onPick, input = null, free = false }) {
    const field = input || h('input', { class: 'pjs-input', placeholder, value });
    field.setAttribute('autocomplete', 'off');
    const wrap = h('div', { class: 'pjx-combo ' + className });
    const pop = h('div', { class: 'pjx-pop' });
    wrap.append(field, pop);
    let shown = []; let active = -1; let typed = false; let opened = false;
    const MAX = 300;
    const fill = () => {
      const q = typed ? field.value.trim().toLowerCase() : '';
      const all = items();
      const words = q.split(/\s+/).filter(Boolean);
      shown = (words.length ? all.filter((it) => words.every((w) => (it.search || it.label.toLowerCase()).includes(w))) : all);
      pop.textContent = '';
      shown.slice(0, MAX).forEach((it, i) => {
        const row = h('div', { class: 'pjx-opt' + (i === active ? ' active' : '') }, h('span', null, it.label), it.sub ? h('span', { class: 'pjx-sub' }, it.sub) : null);
        row.addEventListener('mousedown', (e) => { e.preventDefault(); pickItem(it); });
        pop.appendChild(row);
      });
      if (shown.length > MAX) pop.appendChild(h('div', { class: 'pjx-opt more' }, `… ${shown.length - MAX} autres : précise la recherche`));
      if (!shown.length) pop.appendChild(h('div', { class: 'pjx-opt more' }, 'Aucun résultat'));
    };
    const show = () => {
      opened = true; wrap.classList.add('open');
      const current = items().findIndex((it) => it.label === field.value);
      active = typed ? 0 : current;
      fill();
      const el = pop.children[Math.max(active, 0)];
      if (el) scrollInto(el);
    };
    const hide = () => { opened = false; typed = false; wrap.classList.remove('open'); };
    const pickItem = (it) => { field.value = it.label; hide(); field.blur(); onPick(it.value, it); };
    field.addEventListener('focus', () => { typed = false; field.select(); show(); });
    field.addEventListener('click', () => { if (!opened) show(); });
    field.addEventListener('input', () => { typed = true; active = 0; if (!opened) show(); else fill(); });
    field.addEventListener('blur', () => setTimeout(hide, 120));
    field.addEventListener('keydown', (e) => {
      if (!opened && (e.key === 'ArrowDown' || e.key === 'ArrowUp')) { show(); e.preventDefault(); return; }
      if (!opened) return;
      if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        e.preventDefault();
        active = Math.max(0, Math.min(Math.min(shown.length, MAX) - 1, active + (e.key === 'ArrowDown' ? 1 : -1)));
        [...pop.children].forEach((c, i) => c.classList.toggle('active', i === active));
        const el = pop.children[active]; if (el) scrollInto(el);
      } else if (e.key === 'Enter') {
        e.preventDefault();
        if (shown[active]) pickItem(shown[active]);
        else if (free) { hide(); field.blur(); }
      } else if (e.key === 'Escape') { e.preventDefault(); hide(); field.blur(); }
    });
    return wrap;
  }

  // Champ « image » d'un personnage : saisie libre + liste des images de graphics/characters et battlers
  function spriteCombo(input) {
    return combo({
      input,
      free: true,
      className: 'pjx-sprite-combo',
      items: () => (S.ctx.sprites || []).map((path) => ({ label: path, value: path, search: path.toLowerCase() })),
      onPick: () => input.dispatchEvent(new Event('input')),
    });
  }

  function renderPreview() {
    refs = { pageButtons: [] };
    const block = h('div', { class: 'pjs-block pjx-preview' });
    block.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Aperçu'),
      h('div', { class: 'pjs-variants' }, [['height', 'Taille'], ['weight', 'Poids']].map(([pg, l]) => {
        const b = h('button', { class: 'pjs-variant' + (S.page === pg ? ' active' : ''), onclick: () => setPage(pg) }, l);
        b.dataset.page = pg;
        refs.pageButtons.push(b);
        return b;
      }))));
    // Pokémon
    const creature = S.sel && creatureOf(S.sel.db);
    const label3 = (c) => `${String(c.id).padStart(3, '0')} ${c.name}`;
    const choose = (c) => { if (!c) return; S.sel = { db: c.dbSymbol, form: c.forms[0] ? c.forms[0].form | 0 : 0 }; render(); };
    const pick = combo({
      value: creature ? label3(creature) : '',
      placeholder: 'Pokémon (n°, nom ou symbole)',
      className: 'pjx-pick',
      items: () => S.ctx.creatures.map((c) => ({ label: label3(c), sub: c.dbSymbol, value: c, search: `${c.id} ${label3(c)} ${c.dbSymbol}`.toLowerCase() })),
      onPick: (c) => choose(c),
    });
    const step = (d) => {
      const list = S.ctx.creatures;
      const i = Math.max(0, list.findIndex((c) => creature && c.dbSymbol === creature.dbSymbol));
      choose(list[(i + d + list.length) % list.length]);
    };
    const forms = creature && creature.forms.length > 1 ? h('select', { class: 'pjs-select', onchange: (e) => { S.sel.form = parseInt(e.target.value, 10) || 0; render(); } },
      creature.forms.map((f) => h('option', { value: f.form, selected: (f.form | 0) === S.sel.form }, `Forme ${f.form}`))) : null;
    block.appendChild(h('div', { class: 'pjx-controls' },
      h('button', { class: 'pjs-btn small', onclick: () => step(-1), title: 'Pokémon précédent' }, '◀'),
      pick,
      h('button', { class: 'pjs-btn small', onclick: () => step(1), title: 'Pokémon suivant' }, '▶'),
      forms));
    // personnage comparé
    const list = characters();
    block.appendChild(h('div', { class: 'pjx-controls' },
      h('span', { class: 'pjs-label' }, 'Comparé à'),
      h('select', { class: 'pjs-select', onchange: (e) => { S.charIndex = parseInt(e.target.value, 10) || 0; render(); } },
        list.map((c, i) => h('option', { value: i, selected: i === S.charIndex % list.length }, `${charName(c)} (${num(c.height)} m, ${num(c.weight)} kg)`))),
      list.some((c) => c.player && !c.sprite) ? h('div', { class: 'pjs-variants' }, [['m', 'Garçon'], ['f', 'Fille']].map(([gd, l]) => h('button', {
        class: 'pjs-variant' + (S.gender === gd ? ' active' : ''), title: 'Sprite du joueur dans l\'aperçu', onclick: () => { S.gender = gd; render(); },
      }, l))) : null,
      (refs.replay = h('button', { class: 'pjs-btn small', onclick: restartScale, style: { display: S.page === 'weight' ? '' : 'none' } }, 'Rejouer la balance'))));
    canvas = h('canvas', { class: 'pjx-canvas', width: 320, height: 240 });
    setupDrag(canvas);
    block.appendChild(h('div', { class: 'pjx-screen' }, canvas));
    refs.hint = h('div', { class: 'pjs-hint' }, PAGE_HINTS[S.page]);
    block.appendChild(refs.hint);
    block.appendChild(h('div', { class: 'pjs-hint' }, 'En jeu : DROITE dans la fiche d\'un Pokémon du Pokédex, puis gauche / droite (pages), haut / bas (Pokémon), A (personnage suivant), B (retour).'));
    return block;
  }

  // --- Personnages ------------------------------------------------------------
  function renderCharacters() {
    const block = h('div', { class: 'pjs-block' });
    const list = S.config.characters;
    block.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, `Personnages (${list.length})`),
      h('button', { class: 'pjs-btn small', onclick: () => { list.push({ name: 'Nouveau', player: false, height: 1.7, weight: 65, sprite: '', cols: 4, rows: 4, frame: 0 }); S.charIndex = list.length - 1; render(); } }, 'Ajouter')));
    list.forEach((c, i) => {
      const thumb = h('canvas', { class: 'pjx-thumb', width: 40, height: 40 });
      const drawThumb = () => picture(charSprite(c)).then((pic) => {
        const g = thumb.getContext('2d'); g.imageSmoothingEnabled = false; g.clearRect(0, 0, 40, 40);
        if (!pic) return;
        const [rx, ry, rw, rh] = charRect(pic, c);
        const z = Math.min(40 / rw, 40 / rh, 2);
        g.drawImage(pic.img, rx, ry, rw, rh, (40 - rw * z) / 2, (40 - rh * z) / 2, rw * z, rh * z);
      });
      const changed = (rerender) => { updateStatus(); if (rerender) drawThumb(); if (S.page === 'weight') restartScale(); else scheduleDraw(); };
      const field = (key, attrs, parse) => {
        const input = h('input', Object.assign({ class: 'pjs-input' }, attrs, { value: c[key] ?? '' }));
        input.addEventListener('input', () => { c[key] = parse ? parse(input.value) : input.value; if (S.charIndex !== i) { S.charIndex = i; } changed(['sprite', 'cols', 'rows', 'frame'].includes(key)); });
        return input;
      };
      const card = h('div', { class: 'pjx-char' + (i === S.charIndex % list.length ? ' active' : '') },
        h('div', { class: 'pjx-char-head' },
          thumb,
          h('div', { class: 'pjx-char-main' },
            field('name', { placeholder: c.player ? 'Nom du joueur en jeu' : 'Nom' }),
            h('label', { class: 'pjs-inline pjx-player' }, h('input', { type: 'checkbox', checked: !!c.player, onchange: (e) => { c.player = e.target.checked; render(); } }), 'Joueur (son nom et son sprite si vides)')),
          h('div', { class: 'pjx-char-actions' },
            h('button', { class: 'pjs-btn small', title: 'Voir dans l\'aperçu', onclick: () => { S.charIndex = i; render(); } }, '👁'),
            h('button', { class: 'pjs-btn small', disabled: i === 0, onclick: () => { [list[i - 1], list[i]] = [list[i], list[i - 1]]; render(); } }, '▲'),
            h('button', { class: 'pjs-btn small', disabled: i === list.length - 1, onclick: () => { [list[i + 1], list[i]] = [list[i], list[i + 1]]; render(); } }, '▼'),
            h('button', { class: 'pjs-btn small danger', disabled: list.length <= 1, onclick: () => { if (confirm(`Supprimer « ${charName(c)} » ?`)) { list.splice(i, 1); S.charIndex = 0; render(); } } }, '✕'))),
        h('div', { class: 'pjx-grid' },
          h('label', null, h('span', { class: 'pjs-label' }, 'Taille (m)'), field('height', { type: 'number', step: 0.01, min: 0 }, (v) => num(v))),
          h('label', null, h('span', { class: 'pjs-label' }, 'Poids (kg)'), field('weight', { type: 'number', step: 0.1, min: 0 }, (v) => num(v))),
          h('label', { class: 'wide' }, h('span', { class: 'pjs-label' }, 'Image (dans graphics/)'), spriteCombo(field('sprite', { placeholder: c.player ? 'vide : sprite de marche du joueur' : 'characters/…' }))),
          h('label', null, h('span', { class: 'pjs-label' }, 'Colonnes'), field('cols', { type: 'number', min: 1, step: 1 }, (v) => Math.max(1, parseInt(v, 10) || 1))),
          h('label', null, h('span', { class: 'pjs-label' }, 'Lignes'), field('rows', { type: 'number', min: 1, step: 1 }, (v) => Math.max(1, parseInt(v, 10) || 1))),
          h('label', null, h('span', { class: 'pjs-label' }, 'Image n°'), field('frame', { type: 'number', min: 0, step: 1 }, (v) => Math.max(0, parseInt(v, 10) || 0)))));
      drawThumb();
      block.appendChild(card);
    });
    block.appendChild(h('div', { class: 'pjs-hint' }, 'Planche de marche (4 × 4) : image 0 = de face. Une image seule : 1 colonne, 1 ligne. En jeu, A passe au personnage suivant.'));
    return block;
  }

  // --- Mise en page -----------------------------------------------------------
  function renderLayout() {
    const block = h('div', { class: 'pjs-block' });
    block.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Mise en page'),
      h('button', { class: 'pjs-btn small', onclick: () => { LAYOUT_KEYS.forEach((k) => { S.config[k] = DEFAULTS[k]; }); render(); } }, 'Valeurs de base')));
    const groups = [
      ['Taille', [['height_max', 'Hauteur max', 16, 140], ['height_base_y', 'Sol (y)', 40, 172], ['height_pokemon_x', 'Pokémon (x)', 0, 320], ['height_character_x', 'Personnage (x)', 0, 320]]],
      ['Poids', [['weight_scale_x', 'Balance (x)', -40, 220], ['weight_scale_y', 'Balance (y)', 20, 140], ['weight_icon_zoom', 'Zoom de l\'icône', 0.5, 3, 0.5], ['weight_character_zoom', 'Zoom du personnage', 0.5, 3, 0.5], ['pan_offset', 'Enfoncement', -8, 12]]],
    ];
    groups.forEach(([title, fields]) => {
      const sec = h('div', { class: 'pjs-section' }, h('div', { class: 'pjs-label pjx-group' }, title));
      fields.forEach(([key, lab, min, max, stepSize = 1]) => {
        const range = h('input', { type: 'range', class: 'pjx-range', min, max, step: stepSize, value: cfg(key) });
        const box = h('input', { type: 'number', class: 'pjs-input num', step: stepSize, value: cfg(key) });
        const set = (v) => {
          S.config[key] = Math.round(num(v, DEFAULTS[key]) / stepSize) * stepSize; range.value = S.config[key]; box.value = S.config[key]; updateStatus();
          setPage(key.startsWith('height') ? 'height' : 'weight', false);
        };
        range.addEventListener('input', () => set(range.value));
        box.addEventListener('input', () => set(box.value));
        layoutInputs.push(() => { range.value = cfg(key); box.value = cfg(key); });
        sec.appendChild(h('div', { class: 'pjx-slider' }, h('span', { class: 'pjs-label' }, lab), range, box));
      });
      block.appendChild(sec);
    });
    return block;
  }

  // --- Textes et options ------------------------------------------------------
  function renderTexts() {
    const block = h('div', { class: 'pjs-block' });
    block.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Textes et options')));
    const labels = S.config.labels;
    const sec = h('div', { class: 'pjs-section' });
    [['height', 'Libellé « taille »'], ['weight', 'Libellé « poids »']].forEach(([key, lab]) => {
      labels[key] = labels[key] || {};
      sec.appendChild(h('div', { class: 'pjx-labels' }, h('span', { class: 'pjs-label' }, lab),
        ['fr', 'en'].map((lang) => {
          const input = h('input', { class: 'pjs-input', value: labels[key][lang] || '', placeholder: lang });
          input.addEventListener('input', () => { labels[key][lang] = input.value; updateStatus(); scheduleDraw(); });
          return h('label', { class: 'pjs-inline' }, h('span', { class: 'pjx-lang' }, lang), input);
        })));
    });
    block.appendChild(sec);
    const opts = h('div', { class: 'pjs-section last' });
    [['silhouette_color', 'Couleur des silhouettes (habillage Essentials)'], ['silhouette_color_pe', 'Couleur des silhouettes (habillage Pokédex PE)']].forEach(([key, lab]) => {
      const color = h('input', { type: 'color', class: 'pjx-color', value: cfg(key) });
      color.addEventListener('input', () => { S.config[key] = color.value; updateStatus(); scheduleDraw(); });
      opts.appendChild(h('label', { class: 'pjs-inline' }, color, lab));
    });
    const theme = h('select', { class: 'pjs-select', onchange: (e) => { S.config.theme = e.target.value; updateStatus(); scheduleDraw(); } },
      [['auto', `Automatique (${S.ctx.peEnabled ? 'Pokédex PE actif' : 'Pokédex PE inactif'})`], ['pe', 'Pokédex PE (interface_pe)'], ['essentials', 'Essentials (rose / orange)']]
        .map(([v, l]) => h('option', { value: v, selected: (cfg('theme') || 'auto') === v }, l)));
    opts.appendChild(h('label', { class: 'pjs-inline' }, h('span', { class: 'pjs-label' }, 'Habillage'), theme));
    [['show_titles', 'Afficher le titre du cadre (HEIGHT CHECK / WEIGHT CHECK, habillage Essentials)'], ['show_tabs', 'Afficher les onglets du bandeau (habillage Essentials)'], ['require_caught', 'Seulement pour les Pokémon capturés (taille et poids connus)']].forEach(([key, lab]) => {
      opts.appendChild(h('label', { class: 'pjs-inline' }, h('input', { type: 'checkbox', checked: cfg(key) !== false, onchange: (e) => { S.config[key] = e.target.checked; updateStatus(); scheduleDraw(); } }), lab));
    });
    block.appendChild(opts);
    return block;
  }

  // ---------------------------------------------------------------------------
  // Page « Advanced Pokédex » : Données > Pokédex > Taille / Poids (vraie page de Studio : /database/dex-size)
  // (onglet et routes ajoutés à Studio par tools/studio-plugins/patch_studio_pages.py)
  // ---------------------------------------------------------------------------
  const PAGE_ID = 'advanced-pokedex';
  // page « Données > Pokédex > Taille / Poids » (menu et route ajoutés par tools/studio-plugins/patch_studio_pages.py)
  window.dispatchEvent(new Event('pj-plugin-pages'));

  // raccourci clavier (Ctrl+Maj+D) : va sur la page
  function open() {
    if (window.pjNavigate) window.pjNavigate('/database/dex-size');
    else toast("Ouvre un projet pour accéder à l'Advanced Pokédex (Données > Pokédex > Taille / Poids)", true);
  }

  function mount(hostEl) {
    root = h('div', { id: 'pjx-root' });
    // les touches tapées dans la page ne remontent pas jusqu'aux raccourcis de Studio
    ['keydown', 'keypress', 'keyup'].forEach((type) => root.addEventListener(type, (e) => e.stopPropagation()));
    hostEl.appendChild(root);
    S.open = true;
    const latest = projectList()[0] && projectList()[0].projectPath;
    if (!S.config || (latest && latest !== S.projectPath && !dirty())) loadProject(latest || null); else render();
  }

  // page ouverte / quittée (les modifications non enregistrées restent gardées jusqu'au retour sur la page)
  function checkPage() {
    const hostEl = document.getElementById('pj-page-' + PAGE_ID);
    if (root && hostEl && hostEl.contains(root)) return;
    if (root) { root = null; canvas = null; S.open = false; }
    if (hostEl) mount(hostEl);
  }
  let scheduled = false;
  const observer = new MutationObserver(() => { if (!scheduled) { scheduled = true; requestAnimationFrame(() => { scheduled = false; checkPage(); }); } });
  const start = () => { observer.observe(document.body, { childList: true, subtree: true }); checkPage(); };
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);

  window.addEventListener('keydown', (e) => {
    const k = e.key.toLowerCase();
    const typing = e.target && ['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName);
    if (e.ctrlKey && e.shiftKey && k === 'd' && !typing) { e.preventDefault(); open(); return; }
    if (!S.open) return;
    if (e.ctrlKey && k === 's') { e.preventDefault(); e.stopPropagation(); save(); }
  }, true);

  setInterval(() => { if (S.open) updateStatus(); }, 1000);

  window.pjAdexEditor = { open, state: S };
})();
