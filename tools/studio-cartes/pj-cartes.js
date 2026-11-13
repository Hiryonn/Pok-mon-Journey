/* eslint-disable */
// =============================================================================
// Cartes — éditeur de cartes façon Tiled de Pokémon Studio Extra (section « Cartes » de la barre de gauche)
//   Ouvre les cartes Tiled du projet (Data/Tiled/Maps/*.tmx) et leurs tilesets (.tsx), garde leur format :
//   Studio les convertit comme d'habitude (Monde > « Mettre à jour les cartes modifiées »).
//   Tuiles animées : affichées animées sur la carte et dans le tileset, éditeur d'animation (frames, durées).
//   Outils : tampon, gomme, pot de peinture, rectangle, sélection (copier / couper / coller / effacer), pipette, main.
//   Calques (visibilité, opacité), grille, zoom, annuler / rétablir.
//   Automapping (onglet de droite, Ctrl+M) : règles de Tiled (rules.txt + cartes de règles), cartes infinies comprises.
// Style de l'éditeur Smartphone (classes pjs-*).
// =============================================================================
(() => {
  'use strict';
  if (window.__pjCartesLoaded) return;
  window.__pjCartesLoaded = true;

  const api = window.pjCartes;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API des cartes n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  const projectList = () => { try { return JSON.parse(localStorage.getItem('projectList') || '[]'); } catch (e) { return []; } };
  const currentProject = () => (projectList()[0] && projectList()[0].projectPath) || null;
  const store = {
    get(key, def) { try { const v = localStorage.getItem('pjCartes.' + key); return v === null ? def : JSON.parse(v); } catch (e) { return def; } },
    set(key, v) { try { localStorage.setItem('pjCartes.' + key, JSON.stringify(v)); } catch (e) { /* rien */ } },
  };
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const makeCanvas = (w, hh) => { const c = document.createElement('canvas'); c.width = Math.max(1, w); c.height = Math.max(1, hh); return c; };
  // chemins façon Tiled (relatifs, avec ../)
  function joinPath(base, rel) {
    const parts = (base ? base.split('/') : []).concat(String(rel).replace(/\\/g, '/').split('/'));
    const out = [];
    for (const p of parts) { if (!p || p === '.') continue; if (p === '..') out.pop(); else out.push(p); }
    return out.join('/');
  }
  const dirOf = (p) => p.split('/').slice(0, -1).join('/');

  // Drapeaux de retournement des tuiles (format Tiled)
  const FLIP_H = 0x80000000; const FLIP_V = 0x40000000; const FLIP_D = 0x20000000;
  const GID_MASK = 0x1fffffff;

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const TOOLS = [
    ['stamp', 'Tampon (clic droit : prendre des tuiles sur la carte)', 'B', 'M19 3H5a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2V5a2 2 0 00-2-2m-1 9h-4v4h-4v-4H6V8h4V4h4v4h4z'],
    ['eraser', 'Gomme', 'E', 'M16.24 3.56l4.95 4.94c.78.79.78 2.05 0 2.84L12 20.53a4 4 0 01-5.66 0L2.81 17c-.78-.79-.78-2.05 0-2.84l10.6-10.6c.79-.78 2.05-.78 2.83 0M4.22 15.58l3.54 3.53c.78.79 2.04.79 2.83 0l3.53-3.53-4.95-4.95z'],
    ['fill', 'Pot de peinture', 'F', 'M19 11.5s-2 2.17-2 3.5a2 2 0 004 0c0-1.33-2-3.5-2-3.5M5.21 10L10 5.21 14.79 10M16.56 8.94L7.62 0 6.21 1.41l2.38 2.38-5.15 5.15c-.59.56-.59 1.53 0 2.12l5.5 5.5c.29.29.68.44 1.06.44s.77-.15 1.06-.44l5.5-5.5c.59-.59.59-1.56 0-2.12z'],
    ['rect', 'Remplir un rectangle', 'R', 'M3 3h18v18H3zm2 2v14h14V5z'],
    ['terrain', 'Pinceau de terrain (terrains automatiques)', 'T', 'M7 14c-1.66 0-3 1.34-3 3 0 1.31-1.16 2-2 2 .92 1.22 2.49 2 4 2 2.21 0 4-1.79 4-4 0-1.66-1.34-3-3-3m13.71-9.37l-1.34-1.34a.996.996 0 00-1.41 0L9 12.25 11.75 15l8.96-8.96a.996.996 0 000-1.41'],
    ['object', 'Objets (sélection, rectangle, ellipse, point, tuile)', 'O', 'M12 2l-5.5 9h11zm5.5 11c-2.49 0-4.5 2.01-4.5 4.5S15.01 22 17.5 22s4.5-2.01 4.5-4.5-2.01-4.5-4.5-4.5M3 21.5h8v-8H3z'],
    ['select', 'Sélection (Ctrl+C / X / V, Suppr)', 'S', 'M3 3h2v2H3zm4 0h2v2H7zm4 0h2v2h-2zm4 0h2v2h-2zm4 0h2v2h-2zm0 4h2v2h-2zM3 7h2v2H3zm0 4h2v2H3zm0 4h2v2H3zm0 4h2v2H3zm4 0h2v2H7zm4 0h2v2h-2zm4 0h2v2h-2zm4 0h2v2h-2zm0-4h2v2h-2zm0-4h2v2h-2z'],
    ['picker', 'Pipette (prend la tuile du calque actif)', 'I', 'M19.35 11.72l-2.13 2.13-1.41-1.42-7.71 7.71L3.5 22 2 20.5l1.86-4.6 7.71-7.71-1.42-1.41 2.13-2.13 1.42 1.41L17.06 2.7a1 1 0 011.41 0l2.83 2.83a1 1 0 010 1.41l-3.36 3.36zM5.59 18.4l1.06.46 7.04-7.04-1.51-1.51-7.04 7.04z'],
    ['hand', 'Main (ou Espace / clic molette)', 'H', 'M13 6v5h1V2.5a1.5 1.5 0 013 0V11h1V5.5a1.5 1.5 0 013 0V16c0 3.31-2.69 6-6 6h-1.5c-1.95 0-3.68-.94-4.78-2.38L3.3 13.7a1.5 1.5 0 012.32-1.9L8 14V4.5a1.5 1.5 0 013 0V11h1V3a1.5 1.5 0 013 0'],
  ];
  const ZOOMS = [0.125, 0.25, 0.33, 0.5, 0.75, 1, 1.5, 2, 3, 4];
  const S = {
    projectPath: null, ctx: null, search: '', map: null, tool: 'stamp', stamp: null, clipboard: null,
    zoom: 1, ox: 0, oy: 0, grid: store.get('grid', true), animate: store.get('animate', true), cursor: null, selection: null,
    tsIndex: 0, tsZoom: store.get('tsZoom', 1), tsSel: null, anim: null, loading: '',
    terrain: null, rightTab: 'tiles', objMode: 'select', snap: store.get('snap', true), obj: null,
  };
  let root = null;
  let view = null; let vctx = null;
  let tsBox = null; let tsCanvas = null; let tsSpacer = null;

  // ---------------------------------------------------------------------------
  // Lecture des tilesets et des cartes
  // ---------------------------------------------------------------------------
  const imageCache = new Map(); // chemin (Data/Tiled) + couleur transparente -> canvas
  function loadImage(url) {
    return new Promise((resolve, reject) => { const img = new Image(); img.onload = () => resolve(img); img.onerror = () => reject(new Error('Image illisible')); img.src = url; });
  }
  async function tilesetImage(file, trans) {
    const key = file + '|' + (trans || '');
    if (imageCache.has(key)) return imageCache.get(key);
    const img = await loadImage(await call('readImage', { projectPath: S.projectPath, file }));
    const c = makeCanvas(img.naturalWidth, img.naturalHeight);
    const x = c.getContext('2d', { willReadFrequently: !!trans });
    x.drawImage(img, 0, 0);
    if (trans) {
      // couleur transparente du tileset (attribut trans de Tiled)
      const n = parseInt(trans.replace('#', ''), 16);
      const r = (n >> 16) & 255; const g = (n >> 8) & 255; const b = n & 255;
      const data = x.getImageData(0, 0, c.width, c.height);
      const d = data.data;
      for (let i = 0; i < d.length; i += 4) if (d[i] === r && d[i + 1] === g && d[i + 2] === b) d[i + 3] = 0;
      x.putImageData(data, 0, 0);
    }
    imageCache.set(key, c);
    return c;
  }
  // <tileset> (dans un .tsx ou dans la carte) -> objet tileset
  async function parseTileset(el, base, firstgid, source, doc) {
    const num = (name, def) => (el.hasAttribute(name) ? Number(el.getAttribute(name)) : def);
    const ts = {
      firstgid, source, doc, el, base, name: el.getAttribute('name') || source || 'tileset',
      tw: num('tilewidth', 32), th: num('tileheight', 32), count: num('tilecount', 0), columns: num('columns', 0),
      margin: num('margin', 0), spacing: num('spacing', 0), image: null, tiles: new Map(), offset: { x: 0, y: 0 }, dirty: false, error: '',
    };
    const off = el.querySelector(':scope > tileoffset');
    if (off) ts.offset = { x: Number(off.getAttribute('x') || 0), y: Number(off.getAttribute('y') || 0) };
    const img = el.querySelector(':scope > image');
    try {
      if (img) {
        ts.image = await tilesetImage(joinPath(base, img.getAttribute('source')), img.getAttribute('trans'));
        if (!ts.columns) ts.columns = Math.floor((ts.image.width - ts.margin * 2 + ts.spacing) / (ts.tw + ts.spacing));
        if (!ts.count) ts.count = ts.columns * Math.floor((ts.image.height - ts.margin * 2 + ts.spacing) / (ts.th + ts.spacing));
      }
    } catch (e) { ts.error = e.message; }
    for (const t of el.querySelectorAll(':scope > tile')) {
      const id = Number(t.getAttribute('id'));
      const info = {};
      const anim = t.querySelector(':scope > animation');
      if (anim) info.anim = [...anim.querySelectorAll(':scope > frame')].map((f) => ({ id: Number(f.getAttribute('tileid')), dur: Math.max(1, Number(f.getAttribute('duration')) || 100) }));
      if (info.anim && !info.anim.length) delete info.anim;
      const timg = t.querySelector(':scope > image');
      if (timg) {
        try { info.image = await tilesetImage(joinPath(base, timg.getAttribute('source')), timg.getAttribute('trans')); } catch (e) { /* tuile absente */ }
      }
      if (t.hasAttribute('probability')) info.probability = Number(t.getAttribute('probability'));
      if (info.anim || info.image || info.probability !== undefined) ts.tiles.set(id, info);
    }
    // terrains (wangsets de Tiled)
    ts.wangsets = [...el.querySelectorAll(':scope > wangsets > wangset')].map((ws) => {
      const set = { el: ws, name: ws.getAttribute('name') || 'Terrain', type: ws.getAttribute('type') || 'mixed',
        colors: [...ws.querySelectorAll(':scope > wangcolor')].map((c, i) => ({ index: i + 1, name: c.getAttribute('name') || '', color: c.getAttribute('color') || '#fff',
          tile: Number(c.getAttribute('tile') ?? -1), probability: Number(c.getAttribute('probability') || 1) })),
        tiles: [] };
      for (const wt of ws.querySelectorAll(':scope > wangtile')) {
        const raw = wt.getAttribute('wangid') || '';
        if (raw.startsWith('0x')) continue; // ancien format de Tiled, ignoré
        const wang = raw.split(',').map(Number);
        if (wang.length === 8) set.tiles.push({ id: Number(wt.getAttribute('tileid')), wang });
      }
      set.map = new Map(set.tiles.map((t) => [t.id, t.wang]));
      return set;
    }).filter((ws) => ws.tiles.length);
    if (!img && ts.tiles.size) ts.count = Math.max(ts.count, Math.max(...ts.tiles.keys()) + 1);
    ts.maxW = ts.tw; ts.maxH = ts.th;
    ts.tiles.forEach((info) => { if (info.image) { ts.maxW = Math.max(ts.maxW, info.image.width); ts.maxH = Math.max(ts.maxH, info.image.height); } });
    if (info0Anim(ts)) ts.hasAnim = true;
    return ts;
  }
  const info0Anim = (ts) => [...ts.tiles.values()].some((i) => i.anim);

  // bloc de tuiles (élément <data> ou <chunk>) -> Uint32Array de n cases
  async function decodeBlock(el, encoding, compression, n) {
    const out = new Uint32Array(n);
    if (encoding === 'csv') {
      const parts = el.textContent.split(',');
      for (let i = 0; i < out.length && i < parts.length; i++) out[i] = Number(parts[i].trim()) >>> 0;
    } else if (encoding === 'base64') {
      let bytes = Uint8Array.from(atob(el.textContent.trim()), (c) => c.charCodeAt(0));
      if (compression === 'zlib' || compression === 'gzip') {
        const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream(compression === 'zlib' ? 'deflate' : 'gzip'));
        bytes = new Uint8Array(await new Response(stream).arrayBuffer());
      } else if (compression) throw new Error('Compression ' + compression + ' non prise en charge');
      const dv = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
      for (let i = 0; i < out.length && i * 4 + 3 < bytes.length; i++) out[i] = dv.getUint32(i * 4, true);
    } else {
      const tiles = el.querySelectorAll(':scope > tile');
      tiles.forEach((t, i) => { if (i < out.length) out[i] = Number(t.getAttribute('gid') || 0) >>> 0; });
    }
    return out;
  }
  // inf : { ox, oy } pour les cartes infinies (morceaux <chunk> placés dans un rectangle qui les contient tous)
  async function decodeData(dataEl, w, hh, inf) {
    const encoding = dataEl.getAttribute('encoding') || '';
    const compression = dataEl.getAttribute('compression') || '';
    const chunks = dataEl.querySelectorAll(':scope > chunk');
    if (!chunks.length) return decodeBlock(dataEl, encoding, compression, w * hh);
    if (!inf) throw new Error('Cartes infinies non prises en charge');
    const out = new Uint32Array(w * hh);
    for (const ch of chunks) {
      const cw = Number(ch.getAttribute('width')); const chh = Number(ch.getAttribute('height'));
      const cx = Number(ch.getAttribute('x')) - inf.ox; const cy = Number(ch.getAttribute('y')) - inf.oy;
      const d = await decodeBlock(ch, encoding, compression, cw * chh);
      for (let y = 0; y < chh; y++) {
        const ty = cy + y;
        if (ty < 0 || ty >= hh) continue;
        for (let x = 0; x < cw; x++) { const tx = cx + x; if (tx >= 0 && tx < w) out[ty * w + tx] = d[y * cw + x]; }
      }
    }
    return out;
  }
  async function encodeBlock(arr, w, hh, encoding, compression) {
    if (encoding === 'csv') {
      const rows = [];
      for (let y = 0; y < hh; y++) rows.push(Array.from(arr.subarray(y * w, (y + 1) * w)).join(','));
      return rows.join(',\n');
    }
    let bytes = new Uint8Array(arr.length * 4);
    const dv = new DataView(bytes.buffer);
    arr.forEach((g, i) => dv.setUint32(i * 4, g >>> 0, true));
    if (compression === 'zlib' || compression === 'gzip') {
      const stream = new Blob([bytes]).stream().pipeThrough(new CompressionStream(compression === 'zlib' ? 'deflate' : 'gzip'));
      bytes = new Uint8Array(await new Response(stream).arrayBuffer());
    }
    let bin = '';
    for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
    return btoa(bin);
  }
  async function encodeData(layer) {
    const el = layer.dataEl;
    let encoding = el.getAttribute('encoding') || '';
    const compression = el.getAttribute('compression') || '';
    if (encoding !== 'csv' && encoding !== 'base64') {
      // format XML (ancien) : réécrit en CSV
      while (el.firstChild) el.removeChild(el.firstChild);
      el.setAttribute('encoding', 'csv');
      encoding = 'csv';
    }
    if (layer.inf) {
      // carte infinie : morceaux de cs × cs cases, seuls les morceaux non vides sont écrits (comme Tiled)
      const doc = el.ownerDocument; const cs = layer.inf.cs;
      const before = el.previousSibling && el.previousSibling.nodeType === 3 ? el.previousSibling.nodeValue.replace(/[\r\n]/g, '') : '  ';
      while (el.firstChild) el.removeChild(el.firstChild);
      for (let cy = 0; cy < layer.h; cy += cs) for (let cx = 0; cx < layer.w; cx += cs) {
        const part = new Uint32Array(cs * cs); let any = false;
        for (let y = 0; y < cs; y++) for (let x = 0; x < cs; x++) {
          const tx = cx + x; const ty = cy + y;
          const g = tx < layer.w && ty < layer.h ? layer.data[ty * layer.w + tx] : 0;
          part[y * cs + x] = g; if (g) any = true;
        }
        if (!any) continue;
        const ch = doc.createElement('chunk');
        ch.setAttribute('x', String(cx + layer.inf.ox)); ch.setAttribute('y', String(cy + layer.inf.oy));
        ch.setAttribute('width', String(cs)); ch.setAttribute('height', String(cs));
        ch.textContent = '\n' + (await encodeBlock(part, cs, cs, encoding, compression)) + '\n';
        el.appendChild(doc.createTextNode('\n' + before + ' ')); el.appendChild(ch);
      }
      if (el.firstChild) el.appendChild(doc.createTextNode('\n' + before));
      return;
    }
    const old = el.textContent;
    const tail = (old.match(/\n[ \t]*$/) || ['\n  '])[0];
    const body = await encodeBlock(layer.data, layer.w, layer.h, encoding, compression);
    if (encoding === 'csv') el.textContent = '\n' + body + tail;
    else { const ind = (old.match(/^\s*/) || [''])[0]; el.textContent = ind + body + tail; }
  }

  async function openMap(file) {
    if (S.map && S.map.file === file) return;
    if (!(await confirmDiscard())) return;
    S.loading = 'Ouverture de ' + file.replace(/^Maps\//, '') + '…';
    renderAll();
    try {
      const M = await loadMap(file);
      S.map = M;
      S.selection = null;
      S.tsIndex = clamp(store.get('ts.' + file, 0), 0, Math.max(0, M.tilesets.length - 1));
      S.tsSel = null; S.anim = null; S.obj = null;
      if (S.terrain && !M.tilesets.includes(S.terrain.ts)) S.terrain = null;
      const tileLayers = M.layers.filter((l) => l.kind === 'tile');
      M.active = M.layers.indexOf(tileLayers.find((l) => l.visible && !l.readonly) || tileLayers[0]);
      refreshAnimFlags();
      S.loading = '';
      fit();
      renderAll();
      flash('Ouvert : ' + file.replace(/^Maps\//, ''));
    } catch (e) {
      S.loading = '';
      renderAll();
      flash(e.message, true);
    }
  }

  // lit une carte .tmx (tilesets et calques), sans l'ouvrir dans l'éditeur
  async function loadMap(file) {
    const text = await call('readText', { projectPath: S.projectPath, file });
    const doc = new DOMParser().parseFromString(text, 'application/xml');
    if (doc.querySelector('parsererror')) throw new Error('Fichier .tmx illisible.');
    const mapEl = doc.documentElement;
    if (mapEl.getAttribute('orientation') && mapEl.getAttribute('orientation') !== 'orthogonal') throw new Error('Seules les cartes orthogonales sont prises en charge.');
    const base = dirOf(file);
    const M = {
      file, doc, el: mapEl, base, w: Number(mapEl.getAttribute('width')), h: Number(mapEl.getAttribute('height')),
      tw: Number(mapEl.getAttribute('tilewidth')), th: Number(mapEl.getAttribute('tileheight')),
      tilesets: [], layers: [], dirty: false, inf: mapInfinite(mapEl), crlf: /\r\n/.test(text), undo: [], redo: [], mtime: await call('mtime', { projectPath: S.projectPath, file }), hadDecl: /^<\?xml/.test(text),
    };
    // tilesets
    for (const tsEl of mapEl.querySelectorAll(':scope > tileset')) {
      const firstgid = Number(tsEl.getAttribute('firstgid'));
      const source = tsEl.getAttribute('source');
      if (source) {
        const tsFile = joinPath(base, source);
        try {
          const tsText = await call('readText', { projectPath: S.projectPath, file: tsFile });
          const tsDoc = new DOMParser().parseFromString(tsText, 'application/xml');
          const parsed = await parseTileset(tsDoc.documentElement, dirOf(tsFile), firstgid, tsFile, tsDoc);
          parsed.crlf = /\r\n/.test(tsText);
          M.tilesets.push(parsed);
        } catch (e) {
          M.tilesets.push({ firstgid, source: tsFile, name: source, tw: M.tw, th: M.th, count: 0, columns: 1, margin: 0, spacing: 0, tiles: new Map(), offset: { x: 0, y: 0 }, error: e.message, maxW: M.tw, maxH: M.th });
        }
      } else {
        M.tilesets.push(await parseTileset(tsEl, base, firstgid, null, null));
      }
    }
    M.tilesets.sort((a, b) => a.firstgid - b.firstgid);
    if (M.inf) { M.w = M.inf.w; M.h = M.inf.h; }
    M.maxW = Math.max(M.tw, ...M.tilesets.map((t) => t.maxW || t.tw));
    M.maxH = Math.max(M.th, ...M.tilesets.map((t) => t.maxH || t.th));
    await walkLayers(M);
    return M;
  }

  // carte infinie (règles d'automapping…) : rectangle qui contient tous les morceaux, avec une marge d'un morceau
  function mapInfinite(mapEl) {
    if (mapEl.getAttribute('infinite') !== '1') return null;
    const cse = mapEl.querySelector(':scope > editorsettings > chunksize');
    const cs = (cse && Number(cse.getAttribute('width'))) || 16;
    let x0 = Infinity; let y0 = Infinity; let x1 = -Infinity; let y1 = -Infinity;
    for (const ch of mapEl.querySelectorAll('layer > data > chunk')) {
      const x = Number(ch.getAttribute('x')); const y = Number(ch.getAttribute('y'));
      x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x + Number(ch.getAttribute('width'))); y1 = Math.max(y1, y + Number(ch.getAttribute('height')));
    }
    if (x0 === Infinity) { x0 = 0; y0 = 0; x1 = Number(mapEl.getAttribute('width')) || cs; y1 = Number(mapEl.getAttribute('height')) || cs; }
    x0 = Math.floor(x0 / cs) * cs - cs; y0 = Math.floor(y0 / cs) * cs - cs;
    x1 = Math.ceil(x1 / cs) * cs + cs; y1 = Math.ceil(y1 / cs) * cs + cs;
    return { ox: x0, oy: y0, w: x1 - x0, h: y1 - y0, cs };
  }
  // calques (groupes compris, dans l'ordre de dessin), relus depuis le XML ; les calques déjà lus sont gardés
  let uidSeq = 0;
  async function walkLayers(M) {
    const old = new Map((M.layers || []).map((l) => [l.el, l]));
    const activeL = M.layers ? M.layers[M.active] : null;
    const out = [];
    const walk = async (parent, depth, parentVisible) => {
      for (const el of parent.children) {
        const tag = el.tagName;
        if (!['layer', 'group', 'objectgroup', 'imagelayer'].includes(tag)) continue;
        let L = old.get(el);
        if (!L) {
          L = { el, uid: ++uidSeq, kind: tag === 'layer' ? 'tile' : tag === 'group' ? 'group' : tag === 'objectgroup' ? 'object' : 'image', name: el.getAttribute('name') || '',
            visible: el.getAttribute('visible') !== '0', opacity: el.hasAttribute('opacity') ? Number(el.getAttribute('opacity')) : 1, locked: el.getAttribute('locked') === '1' };
          if (L.kind === 'tile') {
            L.w = Number(el.getAttribute('width')) || M.w; L.h = Number(el.getAttribute('height')) || M.h;
            if (M.inf) { L.w = M.w; L.h = M.h; L.inf = M.inf; }
            L.dataEl = el.querySelector(':scope > data');
            try { L.data = L.dataEl ? await decodeData(L.dataEl, L.w, L.h, L.inf) : new Uint32Array(L.w * L.h); } catch (e) { L.data = new Uint32Array(L.w * L.h); L.readonly = e.message; }
          }
        }
        L.depth = depth; L.parentVisible = parentVisible;
        out.push(L);
        if (tag === 'group') await walk(el, depth + 1, parentVisible && L.visible);
      }
    };
    await walk(M.el, 0, true);
    M.layers = out;
    M.active = activeL && out.includes(activeL) ? out.indexOf(activeL) : Math.max(0, Math.min(M.active || 0, out.length - 1));
  }

  // ---------------------------------------------------------------------------
  // Tuiles
  // ---------------------------------------------------------------------------
  function tilesetOf(id) {
    const list = S.map.tilesets;
    let lo = 0; let hi = list.length - 1; let found = null;
    while (lo <= hi) { const mid = (lo + hi) >> 1; if (list[mid].firstgid <= id) { found = list[mid]; lo = mid + 1; } else hi = mid - 1; }
    return found;
  }
  const isAnimated = (gid) => { const id = gid & GID_MASK; if (!id) return false; const ts = tilesetOf(id); const info = ts && ts.tiles.get(id - ts.firstgid); return !!(info && info.anim); };
  function frameOf(ts, local, t) {
    const info = ts.tiles.get(local);
    if (!info || !info.anim || !S.animate) return local;
    let total = info.total;
    if (!total) { total = info.anim.reduce((s, f) => s + f.dur, 0); info.total = total; }
    let r = t % total;
    for (const f of info.anim) { if (r < f.dur) return f.id; r -= f.dur; }
    return info.anim[0].id;
  }
  // dessine une tuile (gid avec drapeaux) ; (dx, dy) = coin bas-gauche de la case, s = échelle
  function drawGid(c, gid, dx, dy, s, t) {
    const raw = gid >>> 0;
    const id = raw & GID_MASK;
    if (!id) return;
    const ts = tilesetOf(id);
    if (!ts) return;
    const local = frameOf(ts, id - ts.firstgid, t);
    let img = ts.image; let sx = 0; let sy = 0; let sw = ts.tw; let sh = ts.th;
    const info = ts.tiles.get(local);
    if (info && info.image) { img = info.image; sw = img.width; sh = img.height; } else if (img) {
      sx = ts.margin + (local % ts.columns) * (ts.tw + ts.spacing);
      sy = ts.margin + Math.floor(local / ts.columns) * (ts.th + ts.spacing);
    }
    if (!img) return;
    const w = sw * s; const hh = sh * s;
    const x = dx + ts.offset.x * s; const y = dy - hh + ts.offset.y * s;
    const fh = raw & FLIP_H; const fv = raw & FLIP_V; const fd = raw & FLIP_D;
    if (!fh && !fv && !fd) { c.drawImage(img, sx, sy, sw, sh, x, y, w, hh); return; }
    c.save();
    c.translate(x + w / 2, y + hh / 2);
    if (fd) { c.rotate(Math.PI / 2); c.scale(1, -1); }
    c.scale(fh ? -1 : 1, fv ? -1 : 1);
    c.drawImage(img, sx, sy, sw, sh, -w / 2, -hh / 2, w, hh);
    c.restore();
  }

  // ---------------------------------------------------------------------------
  // Rendu de la carte : morceaux en cache pour les calques fixes, tuiles animées redessinées
  // ---------------------------------------------------------------------------
  const CH = 16;
  let bands = [];
  let chunkCount = 0;
  function refreshAnimFlags() {
    const M = S.map;
    M.layers.forEach((l) => { if (l.kind === 'tile') l.hasAnim = l.data.some((g) => isAnimated(g)); });
    rebuildBands();
  }
  const layerShown = (l) => l.visible && l.parentVisible;
  function rebuildBands() {
    bands = [];
    chunkCount = 0;
    let cur = null;
    for (const l of S.map.layers) {
      if (l.kind !== 'tile' || !layerShown(l) || l.opacity <= 0) continue;
      if (l.hasAnim) { bands.push({ dynamic: true, layer: l }); cur = null; continue; }
      if (!cur) { cur = { dynamic: false, layers: [], cache: new Map() }; bands.push(cur); }
      cur.layers.push(l);
    }
  }
  function invalidateCell(layer, x, y) {
    const b = bands.find((band) => !band.dynamic && band.layers.includes(layer));
    if (!b) return;
    const M = S.map;
    const px = Math.ceil((M.maxW - M.tw) / M.tw); const py = Math.ceil((M.maxH - M.th) / M.th);
    for (let cy = Math.floor((y - py) / CH); cy <= Math.floor(y / CH); cy++) for (let cx = Math.floor(x / CH); cx <= Math.floor((x + px) / CH); cx++) b.cache.delete(cx + ',' + cy);
  }
  function buildChunk(band, cx, cy) {
    const M = S.map;
    const c = makeCanvas(CH * M.tw, CH * M.th);
    const x = c.getContext('2d');
    x.imageSmoothingEnabled = false;
    const px = Math.ceil((M.maxW - M.tw) / M.tw); const py = Math.ceil((M.maxH - M.th) / M.th);
    for (const l of band.layers) {
      x.globalAlpha = l.opacity;
      for (let ty = cy * CH; ty < (cy + 1) * CH + py; ty++) {
        if (ty < 0 || ty >= l.h) continue;
        for (let tx = cx * CH - px; tx < (cx + 1) * CH; tx++) {
          if (tx < 0 || tx >= l.w) continue;
          const g = l.data[ty * l.w + tx];
          if (g) drawGid(x, g, (tx - cx * CH) * M.tw, (ty - cy * CH + 1) * M.th, 1, 0);
        }
      }
    }
    chunkCount += 1;
    return c;
  }
  function trimCaches() {
    if (chunkCount < 400) return;
    bands.forEach((b) => { if (!b.dynamic) b.cache.clear(); });
    chunkCount = 0;
  }

  function fit() {
    if (!view || !S.map) return;
    const r = view.parentElement.getBoundingClientRect();
    const M = S.map;
    const z = Math.min((r.width - 40) / (M.w * M.tw), (r.height - 40) / (M.h * M.th));
    S.zoom = ZOOMS.filter((v) => v <= Math.max(z, 0.125)).pop() || 0.125;
    if (S.zoom > 1) S.zoom = 1;
    S.ox = Math.round((r.width - M.w * M.tw * S.zoom) / 2);
    S.oy = Math.round((r.height - M.h * M.th * S.zoom) / 2);
  }
  function zoomAt(z, mx, my) {
    if (!view) return;
    if (mx === undefined) { const r = view.getBoundingClientRect(); mx = r.width / 2; my = r.height / 2; }
    S.ox = Math.round(mx - (mx - S.ox) * (z / S.zoom));
    S.oy = Math.round(my - (my - S.oy) * (z / S.zoom));
    S.zoom = z;
    needDraw = true;
    renderStatus();
  }
  const zoomStep = (dir, mx, my) => {
    let i = ZOOMS.findIndex((z) => z >= S.zoom - 1e-6);
    if (i < 0) i = ZOOMS.length - 1;
    const exact = Math.abs(ZOOMS[i] - S.zoom) < 1e-6;
    const next = ZOOMS[clamp(dir > 0 ? (exact ? i + 1 : i) : i - 1, 0, ZOOMS.length - 1)];
    zoomAt(next, mx, my);
  };

  let needDraw = true;
  let lastStep = -1;
  function draw(t) {
    if (!view || !vctx) return;
    const r = view.parentElement.getBoundingClientRect();
    const k = window.devicePixelRatio || 1;
    const W = Math.max(1, Math.round(r.width * k)); const H = Math.max(1, Math.round(r.height * k));
    if (view.width !== W || view.height !== H) { view.width = W; view.height = H; view.style.width = r.width + 'px'; view.style.height = r.height + 'px'; }
    const c = vctx;
    c.setTransform(k, 0, 0, k, 0, 0);
    c.imageSmoothingEnabled = false;
    c.clearRect(0, 0, r.width, r.height);
    const M = S.map;
    if (!M) return;
    const z = S.zoom; const X = S.ox; const Y = S.oy;
    const tw = M.tw * z; const th = M.th * z;
    c.fillStyle = '#16151b';
    c.fillRect(X, Y, M.w * tw, M.h * th);
    // cases visibles
    const x0 = clamp(Math.floor(-X / tw), 0, M.w); const x1 = clamp(Math.ceil((r.width - X) / tw), 0, M.w);
    const y0 = clamp(Math.floor(-Y / th), 0, M.h); const y1 = clamp(Math.ceil((r.height - Y) / th), 0, M.h);
    const px = Math.ceil((M.maxW - M.tw) / M.tw); const py = Math.ceil((M.maxH - M.th) / M.th);
    for (const b of bands) {
      if (b.dynamic) {
        const l = b.layer;
        c.globalAlpha = l.opacity;
        for (let ty = y0; ty < Math.min(l.h, y1 + py); ty++) {
          for (let tx = Math.max(0, x0 - px); tx < Math.min(l.w, x1); tx++) {
            const g = l.data[ty * l.w + tx];
            if (g) drawGid(c, g, X + tx * tw, Y + (ty + 1) * th, z, t);
          }
        }
        c.globalAlpha = 1;
      } else {
        const cw = CH * tw; const chh = CH * th;
        for (let cy = Math.floor(y0 / CH); cy <= Math.floor((y1 - 1) / CH); cy++) {
          for (let cx = Math.floor(x0 / CH); cx <= Math.floor((x1 - 1) / CH); cx++) {
            const key = cx + ',' + cy;
            let chunk = b.cache.get(key);
            if (!chunk) { chunk = buildChunk(b, cx, cy); b.cache.set(key, chunk); }
            c.drawImage(chunk, X + cx * cw, Y + cy * chh, cw, chh);
          }
        }
      }
    }
    drawObjects(c, X - (M.inf ? M.inf.ox : 0) * tw, Y - (M.inf ? M.inf.oy : 0) * th, z, t);
    // grille
    if (S.grid && tw >= 12) {
      c.strokeStyle = 'rgba(0,0,0,0.35)'; c.lineWidth = 1; c.beginPath();
      for (let x = x0; x <= x1; x++) { c.moveTo(Math.round(X + x * tw) + 0.5, Y + y0 * th); c.lineTo(Math.round(X + x * tw) + 0.5, Y + y1 * th); }
      for (let y = y0; y <= y1; y++) { c.moveTo(X + x0 * tw, Math.round(Y + y * th) + 0.5); c.lineTo(X + x1 * tw, Math.round(Y + y * th) + 0.5); }
      c.stroke();
    }
    c.strokeStyle = 'rgba(255,255,255,0.25)'; c.strokeRect(X - 0.5, Y - 0.5, M.w * tw + 1, M.h * th + 1);
    // aperçu du tampon / de l'outil
    const cur = S.cursor;
    if (cur && !drag || (drag && ['rect', 'select', 'capture'].includes(drag.mode))) {
      if (drag && drag.rect) {
        const rr = drag.rect;
        if (drag.mode === 'rect' && S.stamp) {
          c.globalAlpha = 0.6;
          for (let y = rr.y; y < rr.y + rr.h; y++) for (let x = rr.x; x < rr.x + rr.w; x++) {
            const g = S.stamp.gids[((y - rr.y) % S.stamp.h) * S.stamp.w + ((x - rr.x) % S.stamp.w)];
            if (g) drawGid(c, g, X + x * tw, Y + (y + 1) * th, z, t);
          }
          c.globalAlpha = 1;
        }
        c.strokeStyle = drag.mode === 'capture' ? '#5fcde4' : '#fff';
        c.strokeRect(X + rr.x * tw + 0.5, Y + rr.y * th + 0.5, rr.w * tw - 1, rr.h * th - 1);
      } else if (cur && S.tool === 'terrain' && S.terrain) {
        c.strokeStyle = S.terrain.color.color; c.lineWidth = 2;
        c.strokeRect(X + cur[0] * tw + 1, Y + cur[1] * th + 1, tw - 2, th - 2); c.lineWidth = 1;
      } else if (cur && S.tool === 'object') {
        /* les objets ont leur propre aperçu */
      } else if (cur && S.tool === 'stamp' && S.stamp) {
        const sx = cur[0] - Math.floor((S.stamp.w - 1) / 2); const sy = cur[1] - Math.floor((S.stamp.h - 1) / 2);
        c.globalAlpha = 0.6;
        for (let y = 0; y < S.stamp.h; y++) for (let x = 0; x < S.stamp.w; x++) { const g = S.stamp.gids[y * S.stamp.w + x]; if (g) drawGid(c, g, X + (sx + x) * tw, Y + (sy + y + 1) * th, z, t); }
        c.globalAlpha = 1;
        c.strokeStyle = 'rgba(255,255,255,0.8)'; c.strokeRect(X + sx * tw + 0.5, Y + sy * th + 0.5, S.stamp.w * tw - 1, S.stamp.h * th - 1);
      } else if (cur) {
        c.strokeStyle = S.tool === 'eraser' ? 'rgba(245,61,92,0.9)' : 'rgba(255,255,255,0.8)';
        c.strokeRect(X + cur[0] * tw + 0.5, Y + cur[1] * th + 0.5, tw - 1, th - 1);
      }
    }
    // sélection
    if (S.selection) {
      const s = S.selection;
      c.setLineDash([4, 4]); c.lineDashOffset = -((t / 60) | 0);
      c.strokeStyle = '#fff'; c.strokeRect(X + s.x * tw + 0.5, Y + s.y * th + 0.5, s.w * tw - 1, s.h * th - 1);
      c.lineDashOffset = -((t / 60) | 0) + 4; c.strokeStyle = '#000'; c.strokeRect(X + s.x * tw + 0.5, Y + s.y * th + 0.5, s.w * tw - 1, s.h * th - 1);
      c.setLineDash([]);
    }
    trimCaches();
  }
  // boucle : redessine quand il le faut, et au rythme des animations
  function loop(t) {
    if (root && root.isConnected) {
      const animated = S.animate && bands.some((b) => b.dynamic);
      const step = Math.floor(t / 50);
      if (needDraw || (animated && step !== lastStep) || (S.selection && step % 2 === 0 && step !== lastStep)) { draw(t); needDraw = false; }
      if (step !== lastStep) { drawTileset(t); drawAnimPreview(t); }
      lastStep = step;
    }
    requestAnimationFrame(loop);
  }
  requestAnimationFrame(loop);

  // ---------------------------------------------------------------------------
  // Modifications (avec annuler / rétablir)
  // ---------------------------------------------------------------------------
  let change = null; // modification en cours : Map(cle -> [calque, index, avant, après])
  function begin() { change = new Map(); }
  function setCell(layer, x, y, gid) {
    if (x < 0 || y < 0 || x >= layer.w || y >= layer.h) return;
    const i = y * layer.w + x;
    const old = layer.data[i];
    gid >>>= 0;
    if (old === gid) return;
    const key = layer.uid + ':' + i;
    if (change) { const prev = change.get(key); change.set(key, [layer, i, prev ? prev[2] : old, gid]); }
    layer.data[i] = gid;
    if (!layer.hasAnim && isAnimated(gid)) { layer.hasAnim = true; rebuildBands(); } else invalidateCell(layer, x, y);
    needDraw = true;
  }
  function end() {
    if (!change) return;
    const list = [...change.values()].filter((c) => c[2] !== c[3]);
    change = null;
    if (!list.length) return;
    S.map.undo.push(list);
    if (S.map.undo.length > 200) S.map.undo.shift();
    S.map.redo = [];
    S.map.dirty = true;
    renderStatus();
  }
  function applyList(list, back) {
    const M = S.map;
    for (const [l, i, before, after] of back ? [...list].reverse() : list) {
      if (!M.layers.includes(l)) continue;
      l.data[i] = back ? before : after;
      invalidateCell(l, i % l.w, Math.floor(i / l.w));
    }
    refreshAnimFlags();
    M.dirty = true;
    needDraw = true;
    renderStatus();
  }
  function applyEntry(entry, back) { if (entry.obj) applyObj(entry, back); else applyList(entry, back); }
  function undo() { const M = S.map; if (!M || !M.undo.length) return; const l = M.undo.pop(); applyEntry(l, true); M.redo.push(l); }
  function redo() { const M = S.map; if (!M || !M.redo.length) return; const l = M.redo.pop(); applyEntry(l, false); M.undo.push(l); }
  const activeLayer = () => (S.map ? S.map.layers[S.map.active] : null);
  function editableLayer() {
    const l = activeLayer();
    if (!l || l.kind !== 'tile') { flash('Choisis un calque de tuiles.', true); return null; }
    if (l.readonly) { flash('Calque en lecture seule : ' + l.readonly, true); return null; }
    if (l.locked) { flash('Ce calque est verrouillé dans Tiled.', true); return null; }
    if (!layerShown(l)) { flash('Le calque actif est caché.', true); return null; }
    return l;
  }
  function stampAt(layer, cx, cy) {
    const s = S.stamp;
    if (!s) return;
    const sx = cx - Math.floor((s.w - 1) / 2); const sy = cy - Math.floor((s.h - 1) / 2);
    for (let y = 0; y < s.h; y++) for (let x = 0; x < s.w; x++) { const g = s.gids[y * s.w + x]; if (g) setCell(layer, sx + x, sy + y, g); }
  }
  function fillArea(layer, cx, cy) {
    if (!S.stamp || cx < 0 || cy < 0 || cx >= layer.w || cy >= layer.h) return;
    const target = layer.data[cy * layer.w + cx];
    const seen = new Uint8Array(layer.w * layer.h);
    const stack = [[cx, cy]];
    const cells = [];
    while (stack.length) {
      const [x, y] = stack.pop();
      if (x < 0 || y < 0 || x >= layer.w || y >= layer.h) continue;
      const i = y * layer.w + x;
      if (seen[i] || layer.data[i] !== target) continue;
      if (S.selection && !inRect(S.selection, x, y)) continue;
      seen[i] = 1; cells.push([x, y]);
      stack.push([x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]);
    }
    const s = S.stamp;
    for (const [x, y] of cells) setCell(layer, x, y, s.gids[(((y - cy) % s.h) + s.h) % s.h * s.w + ((((x - cx) % s.w) + s.w) % s.w)]);
  }
  const inRect = (r, x, y) => x >= r.x && y >= r.y && x < r.x + r.w && y < r.y + r.h;
  function capture(layer, rect) {
    const gids = new Uint32Array(rect.w * rect.h);
    for (let y = 0; y < rect.h; y++) for (let x = 0; x < rect.w; x++) {
      const tx = rect.x + x; const ty = rect.y + y;
      gids[y * rect.w + x] = tx >= 0 && ty >= 0 && tx < layer.w && ty < layer.h ? layer.data[ty * layer.w + tx] : 0;
    }
    return { w: rect.w, h: rect.h, gids };
  }
  function copySel(cut) {
    const l = activeLayer();
    if (!S.map || !S.selection || !l || l.kind !== 'tile') return;
    S.clipboard = capture(l, S.selection);
    if (cut) { const e = editableLayer(); if (!e) return; begin(); for (let y = 0; y < S.selection.h; y++) for (let x = 0; x < S.selection.w; x++) setCell(e, S.selection.x + x, S.selection.y + y, 0); end(); }
    flash(cut ? 'Coupé.' : 'Copié.');
  }
  function pasteSel() { if (!S.clipboard) return; S.stamp = S.clipboard; S.tsSel = null; setTool('stamp'); flash('Clique sur la carte pour coller.'); }
  function clearSel() {
    const l = editableLayer();
    if (!l) return;
    const s = S.selection || { x: 0, y: 0, w: l.w, h: l.h };
    begin(); for (let y = 0; y < s.h; y++) for (let x = 0; x < s.w; x++) setCell(l, s.x + x, s.y + y, 0); end();
  }

  // ---------------------------------------------------------------------------
  // Souris sur la carte
  // ---------------------------------------------------------------------------
  let drag = null;
  let spaceDown = false;
  const cellAt = (e) => { const r = view.getBoundingClientRect(); return [Math.floor((e.clientX - r.left - S.ox) / (S.map.tw * S.zoom)), Math.floor((e.clientY - r.top - S.oy) / (S.map.th * S.zoom))]; };
  const inMap = (p) => p[0] >= 0 && p[1] >= 0 && p[0] < S.map.w && p[1] < S.map.h;
  const rectOf = (a, b) => ({ x: Math.min(a[0], b[0]), y: Math.min(a[1], b[1]), w: Math.abs(a[0] - b[0]) + 1, h: Math.abs(a[1] - b[1]) + 1 });
  function onDown(e) {
    if (!S.map) return;
    e.preventDefault();
    view.focus();
    const p = cellAt(e);
    if (e.button === 1 || spaceDown || S.tool === 'hand') { drag = { mode: 'pan', sx: e.clientX, sy: e.clientY, ox: S.ox, oy: S.oy }; return; }
    if (e.button === 2) { drag = { mode: 'capture', start: p, rect: rectOf(p, p) }; needDraw = true; return; }
    const tool = S.tool;
    if (tool === 'select') { drag = { mode: 'select', start: p, rect: rectOf(p, p) }; S.selection = null; needDraw = true; return; }
    if (tool === 'picker') { pick(p); return; }
    if (tool === 'object') { objDown(e); return; }
    const l = editableLayer();
    if (!l) return;
    if (tool === 'stamp') { if (!S.stamp) { flash('Choisis des tuiles dans le tileset (à droite).', true); return; } begin(); stampAt(l, p[0], p[1]); drag = { mode: 'paint', last: p, layer: l }; }
    else if (tool === 'eraser') { begin(); setCell(l, p[0], p[1], 0); drag = { mode: 'erase', last: p, layer: l }; }
    else if (tool === 'fill') { if (!S.stamp) { flash('Choisis des tuiles dans le tileset (à droite).', true); return; } begin(); fillArea(l, p[0], p[1]); end(); }
    else if (tool === 'rect') { if (!S.stamp) { flash('Choisis des tuiles dans le tileset (à droite).', true); return; } drag = { mode: 'rect', start: p, rect: rectOf(p, p), layer: l }; }
    else if (tool === 'terrain') {
      if (!S.terrain) { flash('Choisis un terrain (onglet Terrains, à droite).', true); return; }
      begin(); terrainPaint(l, p[0], p[1]); drag = { mode: 'terrain', last: p, layer: l };
    }
    needDraw = true;
  }
  function cellsBetween(a, b) {
    const pts = []; let [x0, y0] = a; const [x1, y1] = b;
    const dx = Math.abs(x1 - x0); const dy = -Math.abs(y1 - y0); const sx = x0 < x1 ? 1 : -1; const sy = y0 < y1 ? 1 : -1; let err = dx + dy;
    for (;;) { pts.push([x0, y0]); if (x0 === x1 && y0 === y1) break; const e2 = 2 * err; if (e2 >= dy) { err += dy; x0 += sx; } if (e2 <= dx) { err += dx; y0 += sy; } }
    return pts;
  }
  function onMove(e) {
    if (!S.map || !view) return;
    const p = cellAt(e);
    const changed = !S.cursor || S.cursor[0] !== p[0] || S.cursor[1] !== p[1];
    S.cursor = inMap(p) ? p : null;
    if (drag) {
      if (drag.mode === 'pan') { S.ox = drag.ox + e.clientX - drag.sx; S.oy = drag.oy + e.clientY - drag.sy; needDraw = true; return; }
      if (drag.mode.startsWith('obj')) { objMove(e); return; }
      if (!changed && drag.mode !== 'pan') return;
      if (drag.mode === 'paint') { const s = S.stamp; const step = s && (s.w > 1 || s.h > 1); for (const q of step ? [p] : cellsBetween(drag.last, p)) stampAt(drag.layer, q[0], q[1]); drag.last = p; }
      else if (drag.mode === 'erase') { for (const q of cellsBetween(drag.last, p)) setCell(drag.layer, q[0], q[1], 0); drag.last = p; }
      else if (drag.mode === 'terrain') { for (const q of cellsBetween(drag.last, p).slice(1)) terrainPaint(drag.layer, q[0], q[1]); drag.last = p; }
      else if (drag.rect) drag.rect = rectOf(drag.start, p);
    }
    if (changed) { needDraw = true; renderStatus(); }
  }
  function onUp() {
    if (!drag) return;
    const d = drag;
    drag = null;
    if (d.mode === 'paint' || d.mode === 'erase' || d.mode === 'terrain') end();
    else if (d.mode.startsWith('obj')) objUp(d);
    else if (d.mode === 'rect') { begin(); const s = S.stamp; const r = d.rect; for (let y = 0; y < r.h; y++) for (let x = 0; x < r.w; x++) setCell(d.layer, r.x + x, r.y + y, s.gids[(y % s.h) * s.w + (x % s.w)]); end(); }
    else if (d.mode === 'select') S.selection = d.rect.w > 1 || d.rect.h > 1 ? clipRect(d.rect) : null;
    else if (d.mode === 'capture') {
      const l = activeLayer();
      if (l && l.kind === 'tile') {
        S.stamp = capture(l, d.rect); S.tsSel = null;
        if (S.tool !== 'stamp' && S.tool !== 'rect' && S.tool !== 'fill') setTool('stamp');
        focusStampTileset();
      }
    }
    needDraw = true;
    renderStatus();
  }
  const clipRect = (r) => { const x0 = clamp(r.x, 0, S.map.w - 1); const y0 = clamp(r.y, 0, S.map.h - 1); const x1 = clamp(r.x + r.w - 1, 0, S.map.w - 1); const y1 = clamp(r.y + r.h - 1, 0, S.map.h - 1); return { x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1 }; };
  function pick(p) {
    const l = activeLayer();
    if (!l || l.kind !== 'tile' || !inMap(p)) return;
    const g = l.data[p[1] * l.w + p[0]];
    S.stamp = { w: 1, h: 1, gids: Uint32Array.of(g) };
    setTool('stamp');
    focusStampTileset();
  }
  // le tileset de la tuile prise s'affiche et la tuile est entourée
  function focusStampTileset() {
    const s = S.stamp;
    if (!s || !S.map) return;
    const first = Array.from(s.gids).find((g) => g & GID_MASK);
    if (!first) return;
    const id = first & GID_MASK;
    const ts = tilesetOf(id);
    const idx = S.map.tilesets.indexOf(ts);
    if (idx < 0) return;
    if (idx !== S.tsIndex) { S.tsIndex = idx; renderTilesets(); }
    const local = id - ts.firstgid;
    if (s.w === 1 && s.h === 1 && ts.columns) {
      S.tsSel = { x: local % ts.columns, y: Math.floor(local / ts.columns), w: 1, h: 1 };
      scrollTilesetTo(S.tsSel);
    } else S.tsSel = null;
    renderAnimPanel();
  }
  function onWheel(e) {
    if (!S.map) return;
    e.preventDefault();
    const r = view.getBoundingClientRect();
    if (e.ctrlKey || (!e.shiftKey && Math.abs(e.deltaY) >= Math.abs(e.deltaX) && !store.get('wheelScroll', false))) zoomStep(e.deltaY < 0 ? 1 : -1, e.clientX - r.left, e.clientY - r.top);
    else { S.ox -= e.shiftKey ? e.deltaY : e.deltaX; S.oy -= e.shiftKey ? 0 : e.deltaY; needDraw = true; }
  }

  // ---------------------------------------------------------------------------
  // Terrains automatiques (wangsets de Tiled) : le pinceau choisit les bonnes tuiles de bordure
  // ---------------------------------------------------------------------------
  // 0 = fond (aucune couleur) : les cases autour qui ne sont pas des tuiles du terrain comptent comme du fond
  // positions d'une case dans un wangid : haut, haut-droite, droite, bas-droite, bas, bas-gauche, gauche, haut-gauche
  const wangPos = (x, y) => [['h', x, y], ['c', x + 1, y], ['v', x + 1, y], ['c', x + 1, y + 1], ['h', x, y + 1], ['c', x, y + 1], ['v', x, y], ['c', x, y]];
  const wangIdx = (type) => (type === 'corner' ? [1, 3, 5, 7] : type === 'edge' ? [0, 2, 4, 6] : [0, 1, 2, 3, 4, 5, 6, 7]);
  function wangAt(layer, ts, ws, x, y) {
    if (x < 0 || y < 0 || x >= layer.w || y >= layer.h) return null;
    const g = layer.data[y * layer.w + x] & GID_MASK;
    if (!g || g < ts.firstgid || g >= ts.firstgid + ts.count) return null;
    return ws.map.get(g - ts.firstgid) || null;
  }
  function chooseWang(ts, ws, desired, idxs, current) {
    let best = []; let bestScore = Infinity;
    for (const t of ws.tiles) {
      let score = 0;
      for (const i of idxs) if (t.wang[i] !== desired[i]) score += desired[i] ? 2 : 1;
      if (score < bestScore) { bestScore = score; best = [t]; } else if (score === bestScore) best.push(t);
    }
    if (!best.length) return null;
    if (current !== null && best.some((t) => t.id === current)) return current; // la tuile en place convient déjà
    // tirage pondéré par la probabilité des tuiles (comme Tiled)
    const weight = (t) => { const info = ts.tiles.get(t.id); return info && info.probability !== undefined ? info.probability : 1; };
    const total = best.reduce((a, t) => a + weight(t), 0);
    let r = Math.random() * total;
    for (const t of best) { r -= weight(t); if (r <= 0) return t.id; }
    return best[0].id;
  }
  function terrainPaint(layer, cx, cy) {
    const T = S.terrain;
    if (!T || cx < 0 || cy < 0 || cx >= layer.w || cy >= layer.h) return;
    const { ts, ws, color } = T;
    const idxs = wangIdx(ws.type);
    const val = new Map();
    const K = (p) => p.join(',');
    // couleurs déjà en place autour (les cases les plus éloignées d'abord : elles ne changent pas)
    for (const dist of [2, 1, 0]) {
      for (let y = cy - dist; y <= cy + dist; y++) for (let x = cx - dist; x <= cx + dist; x++) {
        if (Math.max(Math.abs(x - cx), Math.abs(y - cy)) !== dist) continue;
        const w = wangAt(layer, ts, ws, x, y);
        if (w) wangPos(x, y).forEach((p, i) => { if (w[i] && !val.has(K(p))) val.set(K(p), w[i]); });
      }
    }
    // la case peinte prend la couleur choisie
    wangPos(cx, cy).forEach((p, i) => { if (idxs.includes(i)) val.set(K(p), color.index); });
    // la case et ses voisines reçoivent la tuile qui colle le mieux
    for (const dist of [0, 1]) {
      for (let y = cy - dist; y <= cy + dist; y++) for (let x = cx - dist; x <= cx + dist; x++) {
        if (Math.max(Math.abs(x - cx), Math.abs(y - cy)) !== dist || x < 0 || y < 0 || x >= layer.w || y >= layer.h) continue;
        const desired = wangPos(x, y).map((p) => val.get(K(p)) || 0);
        if (!idxs.some((i) => desired[i])) continue;
        const cur = layer.data[y * layer.w + x] & GID_MASK;
        const curLocal = cur && cur >= ts.firstgid && cur < ts.firstgid + ts.count && ws.map.has(cur - ts.firstgid) ? cur - ts.firstgid : null;
        // ne touche pas aux tuiles d'un autre tileset (arbres, bâtiments…) ; le fond du même tileset devient une bordure
        if (dist === 1 && curLocal === null && cur && (cur < ts.firstgid || cur >= ts.firstgid + ts.count)) continue;
        const id = chooseWang(ts, ws, desired, idxs, curLocal);
        if (id !== null) setCell(layer, x, y, ts.firstgid + id);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Objets (calques d'objets de Tiled)
  // ---------------------------------------------------------------------------
  const OBJ_MODES = [['select', 'Sélection'], ['rect', 'Rectangle'], ['ellipse', 'Ellipse'], ['point', 'Point'], ['tile', 'Tuile']];
  const objEls = (L) => [...L.el.children].filter((e) => e.tagName === 'object');
  function objInfo(o) {
    const n = (a) => Number(o.getAttribute(a) || 0);
    const kind = o.hasAttribute('gid') ? 'tile' : o.querySelector(':scope > ellipse') ? 'ellipse' : o.querySelector(':scope > point') ? 'point'
      : o.querySelector(':scope > polygon') ? 'polygon' : o.querySelector(':scope > polyline') ? 'polyline' : o.querySelector(':scope > text') ? 'text' : 'rect';
    const x = n('x'); const y = n('y'); let w = n('width'); let hh = n('height');
    const gid = o.hasAttribute('gid') ? Number(o.getAttribute('gid')) >>> 0 : 0;
    if (kind === 'tile' && (!w || !hh)) { const ts = tilesetOf(gid & GID_MASK); w = w || (ts ? ts.tw : S.map.tw); hh = hh || (ts ? ts.th : S.map.th); }
    let pts = null; let box;
    const poly = o.querySelector(':scope > polygon, :scope > polyline');
    if (poly) pts = (poly.getAttribute('points') || '').trim().split(/\s+/).map((q) => q.split(',').map(Number));
    if (kind === 'tile') box = { x, y: y - hh, w, h: hh };
    else if (kind === 'point') box = { x: x - 6 / S.zoom, y: y - 6 / S.zoom, w: 12 / S.zoom, h: 12 / S.zoom };
    else if (pts && pts.length) {
      const xs = pts.map((q) => q[0]); const ys = pts.map((q) => q[1]);
      box = { x: x + Math.min(...xs), y: y + Math.min(...ys), w: Math.max(...xs) - Math.min(...xs), h: Math.max(...ys) - Math.min(...ys) };
    } else box = { x, y, w: Math.max(w, 1), h: Math.max(hh, 1) };
    return { kind, x, y, w, h: hh, gid, pts, box };
  }
  function drawObjects(c, X, Y, z, t) {
    const M = S.map;
    for (const l of M.layers) {
      if (l.kind !== 'object' || !layerShown(l)) continue;
      const col = l.el.getAttribute('color') || '#5fcde4';
      c.globalAlpha = l.opacity;
      for (const o of objEls(l)) {
        if (o.getAttribute('visible') === '0') continue;
        const info = objInfo(o);
        const sx = X + info.x * z; const sy = Y + info.y * z;
        c.strokeStyle = col; c.fillStyle = col + '33'; c.lineWidth = 1.5;
        if (info.kind === 'tile') {
          const ts = tilesetOf(info.gid & GID_MASK);
          const k = ts ? info.w / ts.tw : 1;
          drawGid(c, info.gid, sx, sy, z * k, t);
        } else if (info.kind === 'ellipse') {
          c.beginPath(); c.ellipse(sx + info.w * z / 2, sy + info.h * z / 2, Math.max(1, info.w * z / 2), Math.max(1, info.h * z / 2), 0, 0, Math.PI * 2); c.fill(); c.stroke();
        } else if (info.kind === 'point') {
          c.beginPath(); c.arc(sx, sy - 8, 5, 0, Math.PI * 2); c.fill(); c.stroke(); c.beginPath(); c.moveTo(sx, sy - 3); c.lineTo(sx, sy); c.stroke();
        } else if (info.pts) {
          c.beginPath(); info.pts.forEach(([px, py], i) => (i ? c.lineTo(sx + px * z, sy + py * z) : c.moveTo(sx + px * z, sy + py * z)));
          if (info.kind === 'polygon') { c.closePath(); c.fill(); }
          c.stroke();
        } else { c.fillRect(sx, sy, info.w * z, info.h * z); c.strokeRect(sx + 0.5, sy + 0.5, info.w * z, info.h * z); }
        const name = o.getAttribute('name');
        if (name && z >= 0.5) { c.fillStyle = '#fff'; c.font = '11px Avenir Next'; c.fillText(name, X + info.box.x * z, Y + info.box.y * z - 3); }
        if (o === S.obj) {
          const b = info.box;
          c.setLineDash([4, 3]); c.strokeStyle = '#fff'; c.lineWidth = 1;
          c.strokeRect(X + b.x * z - 2.5, Y + b.y * z - 2.5, b.w * z + 5, b.h * z + 5);
          c.setLineDash([]);
          if (['rect', 'ellipse', 'tile'].includes(info.kind)) { c.fillStyle = '#fff'; c.fillRect(X + (b.x + b.w) * z - 3, Y + (b.y + b.h) * z - 3, 7, 7); }
        }
      }
      c.globalAlpha = 1;
    }
    // objet en cours de création
    if (drag && drag.mode === 'objnew' && drag.rect) {
      const r = drag.rect;
      c.strokeStyle = '#fff'; c.setLineDash([4, 3]);
      if (S.objMode === 'ellipse') { c.beginPath(); c.ellipse(X + (r.x + r.w / 2) * z, Y + (r.y + r.h / 2) * z, Math.max(1, r.w * z / 2), Math.max(1, r.h * z / 2), 0, 0, Math.PI * 2); c.stroke(); }
      else c.strokeRect(X + r.x * z + 0.5, Y + r.y * z + 0.5, r.w * z, r.h * z);
      c.setLineDash([]);
    }
  }
  const pixelAt = (e) => { const r = view.getBoundingClientRect(); const inf = S.map.inf; return [(e.clientX - r.left - S.ox) / S.zoom + (inf ? inf.ox * S.map.tw : 0), (e.clientY - r.top - S.oy) / S.zoom + (inf ? inf.oy * S.map.th : 0)]; };
  const snap = (v, step) => (S.snap ? Math.round(v / step) * step : Math.round(v));
  function objectLayer() {
    const l = activeLayer();
    if (!l || l.kind !== 'object') { flash('Choisis un calque d’objets (ou crée-en un : « + » dans Calques).', true); return null; }
    if (!layerShown(l)) { flash('Le calque actif est caché.', true); return null; }
    return l;
  }
  function objDown(e) {
    const L = objectLayer();
    if (!L) return;
    const [px, py] = pixelAt(e);
    const M = S.map;
    if (S.objMode === 'select') {
      const hit = objEls(L).reverse().find((o) => { const b = objInfo(o).box; const pad = 4 / S.zoom; return px >= b.x - pad && py >= b.y - pad && px <= b.x + b.w + pad && py <= b.y + b.h + pad; });
      selectObj(hit || null);
      if (!hit) return;
      const info = objInfo(hit);
      const b = info.box;
      const onHandle = ['rect', 'ellipse', 'tile'].includes(info.kind) && Math.abs(px - (b.x + b.w)) * S.zoom < 8 && Math.abs(py - (b.y + b.h)) * S.zoom < 8;
      drag = { mode: onHandle ? 'objresize' : 'objmove', layer: L, el: hit, start: [px, py], info, before: L.el.cloneNode(true), moved: false };
      return;
    }
    if (S.objMode === 'point' || S.objMode === 'tile') {
      const g = S.objMode === 'tile' ? (S.stamp ? Array.from(S.stamp.gids).find((x) => x & GID_MASK) : 0) : 0;
      if (S.objMode === 'tile' && !g) { flash('Choisis une tuile dans le tileset.', true); return; }
      const before = L.el.cloneNode(true);
      let o;
      if (S.objMode === 'point') o = addObject(L, { x: snap(px, M.tw / 2), y: snap(py, M.th / 2) }, 'point');
      else {
        const ts = tilesetOf(g & GID_MASK);
        o = addObject(L, { gid: g >>> 0, x: snap(px, M.tw), y: snap(py, M.th) + (ts ? ts.th : M.th), width: ts ? ts.tw : M.tw, height: ts ? ts.th : M.th });
      }
      pushObjUndo(L, before);
      selectObj(o);
      return;
    }
    drag = { mode: 'objnew', layer: L, start: [snap(px, M.tw / 2), snap(py, M.th / 2)], rect: null };
  }
  function objMove(e) {
    const d = drag;
    const [px, py] = pixelAt(e);
    const M = S.map;
    if (d.mode === 'objnew') {
      const x1 = snap(px, M.tw / 2); const y1 = snap(py, M.th / 2);
      d.rect = { x: Math.min(d.start[0], x1), y: Math.min(d.start[1], y1), w: Math.abs(x1 - d.start[0]), h: Math.abs(y1 - d.start[1]) };
    } else if (d.mode === 'objmove') {
      const dx = px - d.start[0]; const dy = py - d.start[1];
      if (!d.moved && Math.abs(dx) * S.zoom < 3 && Math.abs(dy) * S.zoom < 3) return;
      d.moved = true;
      const step = d.info.kind === 'tile' ? M.tw : M.tw / 2;
      setNum(d.el, 'x', snap(d.info.x + dx, step)); setNum(d.el, 'y', snap(d.info.y + dy, step));
    } else if (d.mode === 'objresize') {
      d.moved = true;
      const w = Math.max(1, snap(d.info.w + px - d.start[0], M.tw / 2)); const hh = Math.max(1, snap(d.info.h + py - d.start[1], M.th / 2));
      setNum(d.el, 'width', w); setNum(d.el, 'height', hh);
      if (d.info.kind === 'tile') setNum(d.el, 'y', d.info.y - d.info.h + hh);
    }
    needDraw = true;
    renderObjPanel();
  }
  function objUp(d) {
    const M = S.map;
    if (d.mode === 'objnew') {
      const r = d.rect && d.rect.w >= 2 && d.rect.h >= 2 ? d.rect : { x: d.start[0], y: d.start[1], w: M.tw, h: M.th };
      const before = d.layer.el.cloneNode(true);
      const o = addObject(d.layer, { x: r.x, y: r.y, width: r.w, height: r.h }, S.objMode === 'ellipse' ? 'ellipse' : null);
      pushObjUndo(d.layer, before);
      selectObj(o);
    } else if (d.moved) pushObjUndo(d.layer, d.before);
  }
  const fmt = (v) => String(Math.round(v * 100) / 100);
  function setNum(el, name, v) { el.setAttribute(name, fmt(v)); }
  // nouvel objet (avec les retraits de Tiled)
  function addObject(L, attrs, child) {
    const M = S.map;
    const doc = M.doc;
    const ind = ' '.repeat(L.depth + 2);
    const o = doc.createElement('object');
    const id = Number(M.el.getAttribute('nextobjectid') || 1);
    o.setAttribute('id', String(id));
    M.el.setAttribute('nextobjectid', String(id + 1));
    for (const [k, v] of Object.entries(attrs)) if (v !== undefined && v !== null) o.setAttribute(k, typeof v === 'number' ? fmt(v) : String(v));
    if (child) { o.appendChild(doc.createTextNode('\n' + ind + ' ')); o.appendChild(doc.createElement(child)); o.appendChild(doc.createTextNode('\n' + ind)); }
    const last = L.el.lastChild;
    if (last && last.nodeType === 3 && /^\s*$/.test(last.nodeValue)) { L.el.insertBefore(doc.createTextNode('\n' + ind), last); L.el.insertBefore(o, last); }
    else { L.el.appendChild(doc.createTextNode('\n' + ind)); L.el.appendChild(o); L.el.appendChild(doc.createTextNode('\n' + ' '.repeat(L.depth + 1))); }
    M.dirty = true;
    needDraw = true;
    return o;
  }
  function removeNode(el) { const prev = el.previousSibling; if (prev && prev.nodeType === 3 && /^\s*$/.test(prev.nodeValue)) prev.remove(); el.remove(); }
  function deleteObj() {
    const o = S.obj;
    const L = S.map && S.map.layers.find((l) => l.el === (o && o.parentNode));
    if (!o || !L) return;
    const before = L.el.cloneNode(true);
    removeNode(o);
    pushObjUndo(L, before);
    selectObj(null);
  }
  function pushObjUndo(L, before) {
    const M = S.map;
    M.undo.push({ obj: true, layer: L, before, after: L.el.cloneNode(true) });
    if (M.undo.length > 200) M.undo.shift();
    M.redo = [];
    M.dirty = true;
    needDraw = true;
    renderStatus();
  }
  function applyObj(entry, back) {
    const src = back ? entry.before : entry.after;
    const el = entry.layer.el;
    while (el.firstChild) el.removeChild(el.firstChild);
    [...src.cloneNode(true).childNodes].forEach((n) => el.appendChild(n));
    S.obj = null;
    S.map.dirty = true;
    needDraw = true;
    renderObjPanel();
    renderStatus();
  }
  function selectObj(o) { S.obj = o; needDraw = true; renderObjPanel(); }
  // propriétés de l'objet sélectionné
  function editObj(fn) {
    const o = S.obj;
    const L = S.map && S.map.layers.find((l) => l.el === (o && o.parentNode));
    if (!o || !L) return;
    const before = L.el.cloneNode(true);
    fn(o);
    pushObjUndo(L, before);
    renderObjPanel();
  }
  function objProps(o) {
    const props = o.querySelector(':scope > properties');
    return props ? [...props.querySelectorAll(':scope > property')] : [];
  }
  function setObjProp(o, name, value, oldName) {
    const doc = S.map.doc;
    const ind = (o.previousSibling && o.previousSibling.nodeType === 3 ? o.previousSibling.nodeValue.replace(/^[^\n]*\n/, '') : '  ');
    let props = o.querySelector(':scope > properties');
    if (!props) {
      props = doc.createElement('properties');
      props.appendChild(doc.createTextNode('\n' + ind + ' '));
      const first = o.firstChild;
      if (first && first.nodeType === 3) { o.insertBefore(doc.createTextNode('\n' + ind + ' '), first); o.insertBefore(props, first); }
      else { o.insertBefore(props, first); o.insertBefore(doc.createTextNode('\n' + ind + ' '), props); if (!first) o.appendChild(doc.createTextNode('\n' + ind)); }
    }
    let p = [...props.querySelectorAll(':scope > property')].find((x) => x.getAttribute('name') === (oldName ?? name));
    if (value === null) { if (p) removeNode(p); if (!props.querySelector('property')) removeNode(props); return; }
    if (!p) {
      p = doc.createElement('property');
      const last = props.lastChild;
      props.insertBefore(doc.createTextNode('\n' + ind + '  '), last);
      props.insertBefore(p, last);
    }
    p.setAttribute('name', name);
    if (p.hasAttribute('value') || !p.textContent) p.setAttribute('value', value); else p.textContent = value;
  }

  // ---------------------------------------------------------------------------
  // Création : cartes, taille, calques, tilesets
  // ---------------------------------------------------------------------------
  function nextLayerId() {
    const M = S.map;
    let id = Number(M.el.getAttribute('nextlayerid') || 0);
    if (!id) id = Math.max(0, ...[...M.doc.querySelectorAll('layer,group,objectgroup,imagelayer')].map((e) => Number(e.getAttribute('id') || 0))) + 1;
    M.el.setAttribute('nextlayerid', String(id + 1));
    return id;
  }
  // insère un élément de calque au-dessus du calque actif (même parent), avec les retraits de Tiled
  function insertLayerEl(el) {
    const M = S.map;
    const act = activeLayer();
    const parent = act ? act.el.parentNode : M.el;
    const depth = act ? act.depth : 0;
    const ind = '\n' + ' '.repeat(depth + 1);
    if (act) { const ref = act.el.nextSibling; parent.insertBefore(M.doc.createTextNode(ind), ref); parent.insertBefore(el, ref); }
    else {
      const last = M.el.lastChild;
      if (last && last.nodeType === 3) { M.el.insertBefore(M.doc.createTextNode(ind), last); M.el.insertBefore(el, last); } else { M.el.appendChild(M.doc.createTextNode(ind)); M.el.appendChild(el); }
    }
    return depth;
  }
  async function afterStructure(select) {
    const M = S.map;
    await walkLayers(M);
    if (select) M.active = Math.max(0, M.layers.findIndex((l) => l.el === select));
    refreshAnimFlags();
    M.dirty = true;
    needDraw = true;
    renderLayers(); renderStatus(); renderObjPanel();
  }
  async function askName(title, value) {
    const input = h('input', { class: 'pjs-input', value: value || '' });
    setTimeout(() => { input.focus(); input.select(); }, 0);
    input.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); ok.click(); } });
    let ok;
    const p = modal(title, h('div', { class: 'pjc-form' }, input), [[null, 'Annuler'], [() => input.value.trim(), 'OK', true]]);
    ok = root.querySelector('.pjc-overlay .pjs-btn.primary');
    const r = await p;
    return typeof r === 'function' ? r() : r;
  }
  async function addLayer(kind) {
    const M = S.map;
    if (!M) return;
    const names = { tile: 'Calque de tuiles', object: 'Calque d’objets', group: 'Groupe' };
    const name = await askName('Nouveau : ' + names[kind], names[kind] + ' ' + (M.layers.length + 1));
    if (!name) return;
    const doc = M.doc;
    const el = doc.createElement(kind === 'tile' ? 'layer' : kind === 'object' ? 'objectgroup' : 'group');
    el.setAttribute('id', String(nextLayerId()));
    el.setAttribute('name', name);
    if (kind === 'tile') { el.setAttribute('width', String(M.w)); el.setAttribute('height', String(M.h)); }
    const depth = insertLayerEl(el);
    if (kind === 'tile') {
      const ind = ' '.repeat(depth + 1);
      const data = doc.createElement('data');
      data.setAttribute('encoding', 'csv');
      const rows = []; for (let y = 0; y < M.h; y++) rows.push(new Array(M.w).fill(0).join(','));
      data.textContent = '\n' + rows.join(',\n') + '\n' + ind + ' ';
      el.appendChild(doc.createTextNode('\n' + ind + ' ')); el.appendChild(data); el.appendChild(doc.createTextNode('\n' + ind));
    }
    await afterStructure(el);
    if (kind === 'object') setTool('object');
  }
  async function duplicateLayer() {
    const M = S.map; const L = activeLayer();
    if (!M || !L || L.kind === 'group') return;
    if (L.kind === 'tile' && L.dataEl) await encodeData(L);
    const el = L.el.cloneNode(true);
    el.setAttribute('id', String(nextLayerId()));
    el.setAttribute('name', (L.name || 'Calque') + ' (copie)');
    if (L.kind === 'object') objEls({ el }).forEach((o) => { const id = Number(M.el.getAttribute('nextobjectid') || 1); o.setAttribute('id', String(id)); M.el.setAttribute('nextobjectid', String(id + 1)); });
    insertLayerEl(el);
    await afterStructure(el);
  }
  async function deleteLayer() {
    const M = S.map; const L = activeLayer();
    if (!M || !L) return;
    if (!(await confirmBox(`Supprimer le calque « ${L.name} » ?`, 'Supprimer'))) return;
    removeNode(L.el);
    if (S.obj && !M.doc.contains(S.obj)) S.obj = null;
    await afterStructure(null);
  }
  async function renameLayer(L) {
    const name = await askName('Renommer le calque', L.name);
    if (!name) return;
    L.name = name; L.el.setAttribute('name', name);
    S.map.dirty = true; renderLayers(); renderStatus();
  }
  async function moveLayer(dir) {
    const L = activeLayer();
    if (!L) return;
    const sib = (el, d) => { let n = d > 0 ? el.nextSibling : el.previousSibling; while (n && n.nodeType !== 1) n = d > 0 ? n.nextSibling : n.previousSibling; return n; };
    const other = sib(L.el, dir);
    if (!other) return;
    const parent = L.el.parentNode;
    const ws = L.el.previousSibling && L.el.previousSibling.nodeType === 3 ? L.el.previousSibling : null;
    if (dir > 0) { const ref = other.nextSibling; if (ws) parent.insertBefore(ws, ref); parent.insertBefore(L.el, ref); }
    else { const ows = other.previousSibling && other.previousSibling.nodeType === 3 ? other.previousSibling : other; if (ws) parent.insertBefore(ws, ows); parent.insertBefore(L.el, ows); }
    await afterStructure(L.el);
  }
  async function resizeMap() {
    const M = S.map;
    if (!M) return;
    if (M.inf) { flash('Carte infinie : elle s’agrandit toute seule (une marge vide est ajoutée autour à l’ouverture).'); return; }
    const w = h('input', { class: 'pjs-input', type: 'number', min: 1, max: 1000, value: M.w });
    const hh = h('input', { class: 'pjs-input', type: 'number', min: 1, max: 1000, value: M.h });
    const anchor = h('select', { class: 'pjs-input' }, [['0,0', 'En haut à gauche'], ['0.5,0', 'En haut'], ['1,0', 'En haut à droite'], ['0,0.5', 'À gauche'], ['0.5,0.5', 'Au centre'],
      ['1,0.5', 'À droite'], ['0,1', 'En bas à gauche'], ['0.5,1', 'En bas'], ['1,1', 'En bas à droite']].map(([v, l]) => h('option', { value: v }, l)));
    const r = await modal('Taille de la carte', h('div', { class: 'pjc-form' }, h('div', { class: 'pjc-pair' }, h('label', null, 'Largeur (cases)', w), h('label', null, 'Hauteur (cases)', hh)),
      h('label', null, 'Position du contenu actuel', anchor), h('p', { class: 'pjs-hint' }, 'Les cases retirées sont perdues. Cette opération ne peut pas être annulée.')),
    [[null, 'Annuler'], ['ok', 'Redimensionner', true]]);
    if (r !== 'ok') return;
    const nw = clamp(Math.round(+w.value), 1, 1000); const nh = clamp(Math.round(+hh.value), 1, 1000);
    const [ax, ay] = anchor.value.split(',').map(Number);
    const dx = Math.round((nw - M.w) * ax); const dy = Math.round((nh - M.h) * ay);
    for (const L of M.layers) {
      if (L.kind === 'tile') {
        const data = new Uint32Array(nw * nh);
        for (let y = 0; y < L.h; y++) for (let x = 0; x < L.w; x++) { const tx = x + dx; const ty = y + dy; if (tx >= 0 && ty >= 0 && tx < nw && ty < nh) data[ty * nw + tx] = L.data[y * L.w + x]; }
        L.data = data; L.w = nw; L.h = nh;
        L.el.setAttribute('width', String(nw)); L.el.setAttribute('height', String(nh));
      } else if (L.kind === 'object') {
        objEls(L).forEach((o) => { setNum(o, 'x', Number(o.getAttribute('x') || 0) + dx * M.tw); setNum(o, 'y', Number(o.getAttribute('y') || 0) + dy * M.th); });
      }
    }
    M.w = nw; M.h = nh;
    M.el.setAttribute('width', String(nw)); M.el.setAttribute('height', String(nh));
    M.undo = []; M.redo = [];
    S.selection = null;
    rebuildBands(); M.dirty = true; fit(); needDraw = true; renderStatus();
    flash(`Carte redimensionnée : ${nw} × ${nh} cases.`);
  }
  async function readTsx(file) {
    const text = await call('readText', { projectPath: S.projectPath, file });
    const doc = new DOMParser().parseFromString(text, 'application/xml');
    if (doc.querySelector('parsererror')) throw new Error(file + ' illisible');
    return { text, doc };
  }
  async function addTileset() {
    try { await addTilesetInner(); } catch (e) { flash(e.message, true); }
  }
  async function addTilesetInner() {
    const M = S.map;
    if (!M) return;
    const files = await call('list', { projectPath: S.projectPath, dir: 'Tilesets', ext: '.tsx' });
    const used = new Set(M.tilesets.map((t) => t.source));
    const free = files.filter((f) => !used.has(f));
    if (!free.length) { flash('Tous les tilesets sont déjà dans la carte.'); return; }
    const sel = h('select', { class: 'pjs-input', size: 12 }, free.map((f, i) => h('option', { value: f, selected: i === 0 }, f.replace(/^Tilesets\//, ''))));
    const r = await modal('Ajouter un tileset à la carte', h('div', { class: 'pjc-form' }, sel), [[null, 'Annuler'], ['ok', 'Ajouter', true]]);
    if (r !== 'ok' || !sel.value) return;
    try {
      const ts = await attachTileset(M, sel.value);
      S.tsIndex = M.tilesets.indexOf(ts);
      renderTilesets(); renderStatus();
      flash('Tileset ajouté : ' + ts.name);
    } catch (e) { flash(e.message, true); }
  }
  // ajoute le tileset (.tsx) à la carte, après les autres ; renvoie le tileset lu
  async function attachTileset(M, file) {
    const { text, doc } = await readTsx(file);
    const firstgid = M.tilesets.reduce((a, t) => Math.max(a, t.firstgid + Math.max(1, t.count || 0)), 1);
    const ts = await parseTileset(doc.documentElement, dirOf(file), firstgid, file, doc);
    ts.crlf = /\r\n/.test(text);
    const el = M.doc.createElement('tileset');
    el.setAttribute('firstgid', String(firstgid));
    el.setAttribute('source', relPath(M.base, file));
    const tsEls = M.el.querySelectorAll(':scope > tileset');
    const after = tsEls[tsEls.length - 1];
    if (after) { M.el.insertBefore(M.doc.createTextNode('\n '), after.nextSibling); M.el.insertBefore(el, after.nextSibling.nextSibling); }
    else { M.el.insertBefore(el, M.el.firstChild); M.el.insertBefore(M.doc.createTextNode('\n '), el); }
    M.tilesets.push(ts);
    M.tilesets.sort((x, y) => x.firstgid - y.firstgid);
    M.maxW = Math.max(M.maxW, ts.maxW || ts.tw); M.maxH = Math.max(M.maxH, ts.maxH || ts.th);
    M.dirty = true;
    return ts;
  }
  // chemin relatif façon Tiled (de Maps vers Tilesets : ../Tilesets/x.tsx)
  function relPath(fromDir, to) {
    const a = fromDir ? fromDir.split('/') : []; const b = to.split('/');
    while (a.length && b.length > 1 && a[0] === b[0]) { a.shift(); b.shift(); }
    return '../'.repeat(a.length) + b.join('/');
  }
  async function newMap() {
    try { await newMapInner(); } catch (e) { flash(e.message, true); }
  }
  async function newMapInner() {
    if (!S.ctx || !S.ctx.rootExists) { flash('Pas de dossier Data/Tiled dans le projet.', true); return; }
    if (!(await confirmDiscard())) return;
    const files = await call('list', { projectPath: S.projectPath, dir: 'Tilesets', ext: '.tsx' });
    const maps = (S.ctx.maps || []);
    const name = h('input', { class: 'pjs-input', placeholder: 'ex. K044 Route 26' });
    const w = h('input', { class: 'pjs-input', type: 'number', min: 1, max: 1000, value: 40 });
    const hh = h('input', { class: 'pjs-input', type: 'number', min: 1, max: 1000, value: 30 });
    const tile = h('input', { class: 'pjs-input', type: 'number', min: 8, max: 128, value: 32 });
    const tpl = h('select', { class: 'pjs-input' }, h('option', { value: '' }, 'Carte vide (calques et tilesets choisis ci-dessous)'),
      maps.map((m) => h('option', { value: m.path }, 'Copie de ' + m.name + ' (' + m.tiled + ')')));
    const checks = files.map((f) => h('label', { class: 'pjc-check' }, h('input', { type: 'checkbox', value: f }), f.replace(/^Tilesets\//, '')));
    const r = await modal('Nouvelle carte', h('div', { class: 'pjc-form' },
      h('label', null, 'Nom du fichier', name),
      h('label', null, 'Modèle', tpl),
      h('div', { class: 'pjc-pair' }, h('label', null, 'Largeur (cases)', w), h('label', null, 'Hauteur (cases)', hh), h('label', null, 'Taille d’une case (px)', tile)),
      h('label', null, 'Tilesets (carte vide)', h('div', { class: 'pjc-checks' }, checks)),
      h('p', { class: 'pjs-hint' }, 'Ensuite, dans Studio : Monde > ajoute la carte et associe-lui ce fichier Tiled.')),
    [[null, 'Annuler'], ['ok', 'Créer', true]]);
    if (r !== 'ok') return;
    const clean = name.value.trim().replace(/[<>:"/\\|?*]/g, '').replace(/\.tmx$/i, '');
    if (!clean) { flash('Donne un nom à la carte.', true); return; }
    const file = 'Maps/' + clean + '.tmx';
    if (await call('exists', { projectPath: S.projectPath, file })) { flash('Une carte porte déjà ce nom.', true); return; }
    try {
      let text;
      const W = clamp(Math.round(+w.value), 1, 1000); const H = clamp(Math.round(+hh.value), 1, 1000); const T = clamp(Math.round(+tile.value), 8, 128);
      if (tpl.value) {
        // copie d'une carte existante, à la taille demandée si elle diffère (contenu en haut à gauche)
        text = await call('readText', { projectPath: S.projectPath, file: tpl.value });
      } else {
        let gid = 1;
        const tsLines = [];
        for (const c of checks) {
          const input = c.querySelector('input');
          if (!input.checked) continue;
          const { doc } = await readTsx(input.value);
          const count = Number(doc.documentElement.getAttribute('tilecount') || 0) || 1;
          tsLines.push(` <tileset firstgid="${gid}" source="${relPath('Maps', input.value).replace(/&/g, '&amp;').replace(/"/g, '&quot;')}"/>`);
          gid += count;
        }
        const rows = []; for (let y = 0; y < H; y++) rows.push(new Array(W).fill(0).join(','));
        text = ['<?xml version="1.0" encoding="UTF-8"?>',
          `<map version="1.10" tiledversion="1.12.1" orientation="orthogonal" renderorder="right-down" width="${W}" height="${H}" tilewidth="${T}" tileheight="${T}" infinite="0" nextlayerid="2" nextobjectid="1">`,
          ...tsLines,
          ` <layer id="1" name="Calque 1" width="${W}" height="${H}">`, '  <data encoding="csv">', rows.join(',\r\n'), '</data>', ' </layer>', '</map>', ''].join('\r\n');
      }
      await call('writeText', { projectPath: S.projectPath, file, text, create: true });
      S.ctx = await call('getContext', { projectPath: S.projectPath });
      if (S.map) S.map.dirty = false;
      await openMap(file);
      flash('Carte créée. Dans l’arbre du Monde : « + » Nouvelle carte, puis choisis le fichier ' + clean + '.tmx pour l’ajouter au jeu.');
      renderMaps();
    } catch (e) { flash(e.message, true); }
  }

  // ---------------------------------------------------------------------------
  // Tileset (panneau de droite) : choix des tuiles, tuiles animées
  // ---------------------------------------------------------------------------
  const curTs = () => (S.map ? S.map.tilesets[S.tsIndex] : null);
  function tsLayout() {
    const ts = curTs();
    if (!ts || !tsBox) return null;
    const z = S.tsZoom;
    const cols = ts.columns || Math.max(1, Math.floor((tsBox.clientWidth - 8) / (ts.tw * z)));
    const rows = Math.ceil((ts.count || 1) / cols);
    return { ts, z, cols, rows, cw: (ts.tw + 0) * z, chh: (ts.th + 0) * z };
  }
  function drawTileset(t) {
    if (!tsCanvas || !tsBox) return;
    const L = tsLayout();
    const c = tsCanvas.getContext('2d');
    const k = window.devicePixelRatio || 1;
    const W = tsBox.clientWidth; const H = tsBox.clientHeight;
    if (tsCanvas.width !== Math.round(W * k) || tsCanvas.height !== Math.round(H * k)) { tsCanvas.width = Math.round(W * k); tsCanvas.height = Math.round(H * k); tsCanvas.style.width = W + 'px'; tsCanvas.style.height = H + 'px'; }
    c.setTransform(k, 0, 0, k, 0, 0);
    c.clearRect(0, 0, W, H);
    if (!L) return;
    const { ts, z, cols, rows, cw, chh } = L;
    tsSpacer.style.width = cols * cw + 'px';
    tsSpacer.style.height = rows * chh + 'px';
    const sx = tsBox.scrollLeft; const sy = tsBox.scrollTop;
    tsCanvas.style.left = sx + 'px'; tsCanvas.style.top = sy + 'px';
    c.imageSmoothingEnabled = false;
    if (ts.error) { c.fillStyle = '#f53d5c'; c.font = '12px Avenir Next'; c.fillText(ts.error, 8, 20); return; }
    const r0 = Math.floor(sy / chh); const r1 = Math.min(rows, Math.ceil((sy + H) / chh));
    const c0 = Math.floor(sx / cw); const c1 = Math.min(cols, Math.ceil((sx + W) / cw));
    c.fillStyle = '#2a2932';
    c.fillRect(c0 * cw - sx, r0 * chh - sy, (c1 - c0) * cw, (r1 - r0) * chh);
    for (let row = r0; row < r1; row++) {
      for (let col = c0; col < c1; col++) {
        const local = row * cols + col;
        if (local >= ts.count) continue;
        const sxx = col * cw - sx; const syy = row * chh - sy;
        const frame = frameOf(ts, local, t);
        const info = ts.tiles.get(frame);
        if (info && info.image) c.drawImage(info.image, sxx, syy, cw, chh);
        else if (ts.image) c.drawImage(ts.image, ts.margin + (frame % ts.columns) * (ts.tw + ts.spacing), ts.margin + Math.floor(frame / ts.columns) * (ts.th + ts.spacing), ts.tw, ts.th, sxx, syy, cw, chh);
        const own = ts.tiles.get(local);
        if (own && own.anim) { c.fillStyle = 'rgba(184,29,36,0.95)'; c.beginPath(); c.moveTo(sxx + cw - 9, syy + 1); c.lineTo(sxx + cw - 1, syy + 1); c.lineTo(sxx + cw - 1, syy + 9); c.fill(); }
      }
    }
    if (S.grid && cw >= 8) {
      c.strokeStyle = 'rgba(0,0,0,0.35)'; c.lineWidth = 1; c.beginPath();
      for (let col = c0; col <= c1; col++) { c.moveTo(col * cw - sx + 0.5, r0 * chh - sy); c.lineTo(col * cw - sx + 0.5, r1 * chh - sy); }
      for (let row = r0; row <= r1; row++) { c.moveTo(c0 * cw - sx, row * chh - sy + 0.5); c.lineTo(c1 * cw - sx, row * chh - sy + 0.5); }
      c.stroke();
    }
    const sel = S.anim ? null : S.tsSel;
    if (sel) {
      c.strokeStyle = '#fff'; c.lineWidth = 2;
      c.strokeRect(sel.x * cw - sx + 1, sel.y * chh - sy + 1, sel.w * cw - 2, sel.h * chh - 2);
      c.fillStyle = 'rgba(184,29,36,0.25)'; c.fillRect(sel.x * cw - sx, sel.y * chh - sy, sel.w * cw, sel.h * chh);
      c.lineWidth = 1;
    }
    if (S.anim && S.anim.ts === ts) {
      const col = S.anim.id % cols; const row = Math.floor(S.anim.id / cols);
      c.strokeStyle = '#f5ab3d'; c.lineWidth = 2; c.strokeRect(col * cw - sx + 1, row * chh - sy + 1, cw - 2, chh - 2); c.lineWidth = 1;
    }
  }
  function scrollTilesetTo(sel) {
    const L = tsLayout();
    if (!L || !tsBox) return;
    const top = sel.y * L.chh; const left = sel.x * L.cw;
    if (top < tsBox.scrollTop || top > tsBox.scrollTop + tsBox.clientHeight - L.chh) tsBox.scrollTop = Math.max(0, top - tsBox.clientHeight / 2);
    if (left < tsBox.scrollLeft || left > tsBox.scrollLeft + tsBox.clientWidth - L.cw) tsBox.scrollLeft = Math.max(0, left - tsBox.clientWidth / 2);
  }
  let tsDrag = null;
  function tsCellAt(e) {
    const L = tsLayout();
    const r = tsBox.getBoundingClientRect();
    return [clamp(Math.floor((e.clientX - r.left + tsBox.scrollLeft) / L.cw), 0, L.cols - 1), clamp(Math.floor((e.clientY - r.top + tsBox.scrollTop) / L.chh), 0, L.rows - 1)];
  }
  function tsDown(e) {
    const L = tsLayout();
    if (!L) return;
    e.preventDefault();
    const p = tsCellAt(e);
    const local = p[1] * L.cols + p[0];
    if (S.anim) { // édition d'animation : ajoute la tuile cliquée comme image
      if (local < L.ts.count && S.anim.ts === L.ts) { S.anim.frames.push({ id: local, dur: S.anim.defaultDur }); renderAnimPanel(); }
      return;
    }
    tsDrag = { start: p };
    S.tsSel = rectOf(p, p);
  }
  function tsMove(e) { if (!tsDrag) return; S.tsSel = rectOf(tsDrag.start, tsCellAt(e)); }
  function tsUp() {
    if (!tsDrag) return;
    tsDrag = null;
    const L = tsLayout();
    const s = S.tsSel;
    if (!L || !s) return;
    const gids = new Uint32Array(s.w * s.h);
    for (let y = 0; y < s.h; y++) for (let x = 0; x < s.w; x++) { const local = (s.y + y) * L.cols + s.x + x; gids[y * s.w + x] = local < L.ts.count ? L.ts.firstgid + local : 0; }
    S.stamp = { w: s.w, h: s.h, gids };
    if (!['stamp', 'fill', 'rect'].includes(S.tool)) setTool('stamp');
    renderAnimPanel();
  }

  // ---------------------------------------------------------------------------
  // Éditeur d'animation (comme dans Tiled : une tuile du tileset joue plusieurs images)
  // ---------------------------------------------------------------------------
  let animCanvas = null;
  function startAnimEdit() {
    const ts = curTs();
    const s = S.tsSel;
    if (!ts || !s || s.w !== 1 || s.h !== 1) { flash('Choisis une seule tuile du tileset.', true); return; }
    const L = tsLayout();
    const id = s.y * L.cols + s.x;
    const info = ts.tiles.get(id);
    S.anim = { ts, id, frames: info && info.anim ? info.anim.map((f) => ({ ...f })) : [], defaultDur: store.get('animDur', 100) };
    renderAnimPanel();
  }
  function drawAnimPreview(t) {
    if (!animCanvas || !S.anim) return;
    const c = animCanvas.getContext('2d');
    const { ts, frames } = S.anim;
    c.clearRect(0, 0, animCanvas.width, animCanvas.height);
    c.imageSmoothingEnabled = false;
    if (!frames.length) return;
    const total = frames.reduce((a, f) => a + Math.max(1, f.dur), 0);
    let r = t % total; let id = frames[0].id;
    for (const f of frames) { if (r < f.dur) { id = f.id; break; } r -= f.dur; }
    drawLocal(c, ts, id, 0, 0, animCanvas.width, animCanvas.height);
  }
  function drawLocal(c, ts, local, x, y, w, hh) {
    const info = ts.tiles.get(local);
    if (info && info.image) { c.drawImage(info.image, x, y, w, hh); return; }
    if (!ts.image) return;
    c.drawImage(ts.image, ts.margin + (local % ts.columns) * (ts.tw + ts.spacing), ts.margin + Math.floor(local / ts.columns) * (ts.th + ts.spacing), ts.tw, ts.th, x, y, w, hh);
  }
  async function saveAnim() {
    const a = S.anim;
    if (!a) return;
    const { ts } = a;
    const doc = ts.doc || S.map.doc;
    let tileEl = [...ts.el.querySelectorAll(':scope > tile')].find((t) => Number(t.getAttribute('id')) === a.id);
    const ns = ts.el.namespaceURI;
    const mk = (tag) => (ns ? doc.createElementNS(ns, tag) : doc.createElement(tag));
    // indentation façon Tiled (1 espace par niveau)
    const base = ts.doc ? ' ' : '  ';
    if (!tileEl && a.frames.length) {
      tileEl = mk('tile');
      tileEl.setAttribute('id', String(a.id));
      // à sa place parmi les <tile> (par id croissant), après <image>/<tileoffset>…
      const tiles = [...ts.el.querySelectorAll(':scope > tile')];
      const next = tiles.find((t) => Number(t.getAttribute('id')) > a.id);
      if (next) { ts.el.insertBefore(tileEl, next); ts.el.insertBefore(doc.createTextNode('\n' + base), next); } else {
        const last = ts.el.lastChild;
        if (last && last.nodeType === 3 && /^\s*$/.test(last.nodeValue)) { ts.el.insertBefore(doc.createTextNode('\n' + base), last); ts.el.insertBefore(tileEl, last); } else ts.el.appendChild(tileEl);
      }
    }
    if (tileEl) {
      const old = tileEl.querySelector(':scope > animation');
      if (old) { const prev = old.previousSibling; if (prev && prev.nodeType === 3) prev.remove(); old.remove(); }
      if (a.frames.length) {
        const anim = mk('animation');
        a.frames.forEach((f) => { anim.appendChild(doc.createTextNode('\n' + base + '  ')); const fr = mk('frame'); fr.setAttribute('tileid', String(f.id)); fr.setAttribute('duration', String(Math.max(1, Math.round(f.dur)))); anim.appendChild(fr); });
        anim.appendChild(doc.createTextNode('\n' + base + ' '));
        const last = tileEl.lastChild;
        if (last && last.nodeType === 3) tileEl.insertBefore(doc.createTextNode('\n' + base + ' '), last), tileEl.insertBefore(anim, last);
        else { tileEl.appendChild(doc.createTextNode('\n' + base + ' ')); tileEl.appendChild(anim); tileEl.appendChild(doc.createTextNode('\n' + base)); }
      }
      // <tile> vide : retiré
      if (!tileEl.attributes.length || (tileEl.attributes.length === 1 && ![...tileEl.childNodes].some((n) => n.nodeType === 1))) {
        const prev = tileEl.previousSibling; if (prev && prev.nodeType === 3) prev.remove(); tileEl.remove();
      }
    }
    const info = ts.tiles.get(a.id) || {};
    if (a.frames.length) info.anim = a.frames.map((f) => ({ id: f.id, dur: Math.max(1, Math.round(f.dur)) })); else delete info.anim;
    delete info.total;
    if (info.anim || info.image) ts.tiles.set(a.id, info); else ts.tiles.delete(a.id);
    store.set('animDur', a.defaultDur);
    S.anim = null;
    refreshAnimFlags();
    bands.forEach((b) => { if (!b.dynamic) b.cache.clear(); });
    needDraw = true;
    if (ts.doc) {
      try {
        const text = serialize(ts.doc, ts.crlf);
        await call('writeText', { projectPath: S.projectPath, file: ts.source, text });
        flash('Animation enregistrée dans ' + ts.source.replace(/^Tilesets\//, '') + ' (toutes les cartes qui utilisent ce tileset en profitent).');
      } catch (e) { flash(e.message, true); }
    } else {
      S.map.dirty = true;
      flash('Animation ajoutée (tileset intégré à la carte) : enregistre la carte.');
    }
    renderAnimPanel();
    renderStatus();
  }

  // ---------------------------------------------------------------------------
  // Automapping façon Tiled : rules.txt (dans le dossier de la carte) liste les cartes de règles, appliquées dans l'ordre.
  //   Calques d'une carte de règles : regions / regions_input / regions_output, input[index]_<calque>,
  //   inputnot[index]_<calque>, output[index]_<calque> (un index de sortie tiré au hasard par règle trouvée).
  //   Propriétés reprises de Tiled : MatchOutsideMap, OverflowBorder, WrapBorder, DeleteTiles, MatchInOrder,
  //   NoOverlappingOutput, AutoEmpty, Probability, calque rule_options (ModX/ModY/OffsetX/OffsetY/Probability/Disabled),
  //   tuiles spéciales (propriété MatchType : Empty, Ignore, NonEmpty, Other, Negate).
  // ---------------------------------------------------------------------------
  const AM = { rulesFile: '', entries: [], report: '', busy: false, onlySel: store.get('amSel', false), back: null };
  const tsxMetaCache = new Map();
  const truthy = (v) => v === true || v === 'true' || v === '1';
  const globRe = (g) => new RegExp('^' + g.replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*').replace(/\?/g, '.') + '$', 'i');
  const baseName = (f) => f.split('/').pop();
  function readProps(el) {
    const out = {};
    const props = el && el.querySelector(':scope > properties');
    if (props) for (const p of props.querySelectorAll(':scope > property')) out[p.getAttribute('name')] = p.hasAttribute('value') ? p.getAttribute('value') : p.textContent;
    return out;
  }
  const RULE_LAYER = /^(regions(?:_input|_output)?|input(?:not)?[^_]*_.+|output[^_]*_.+)$/i;
  function isRuleMap(M) {
    if (!M) return false;
    const names = M.layers.filter((l) => l.kind === 'tile').map((l) => l.name);
    return names.some((n) => /^output[^_]*_/i.test(n)) && names.some((n) => /^(regions|input)/i.test(n));
  }
  // MatchType des tuiles d'un tileset (tuiles spéciales de l'automapping)
  function matchTypes(el) {
    const m = new Map();
    for (const t of el.querySelectorAll(':scope > tile')) { const mt = readProps(t).MatchType; if (mt) m.set(Number(t.getAttribute('id')), mt); }
    return m;
  }
  async function tsxMeta(file) {
    if (tsxMetaCache.has(file)) return tsxMetaCache.get(file);
    let meta = { matchType: new Map() };
    try { const { doc } = await readTsx(file); meta = { matchType: matchTypes(doc.documentElement) }; } catch (e) { /* tileset absent */ }
    tsxMetaCache.set(file, meta);
    return meta;
  }

  // rules.txt : chemins de cartes de règles (ou d'autres .txt), filtres [motif], commentaires # et //
  async function rulesFileFor(M) {
    for (const f of [joinPath(M.base, 'rules.txt'), 'rules.txt']) { try { if (await call('exists', { projectPath: S.projectPath, file: f })) return f; } catch (e) { /* hors Data/Tiled */ } }
    return joinPath(M.base, 'rules.txt');
  }
  async function parseRulesTxt(file, mapFile, seen = new Set(), out = []) {
    if (seen.has(file)) return out;
    seen.add(file);
    let text = '';
    try { text = await call('readText', { projectPath: S.projectPath, file }); } catch (e) { return out; }
    let ok = true;
    for (const raw of text.split(/\r?\n/)) {
      const line = raw.trim();
      if (!line || line.startsWith('#') || line.startsWith('//')) continue;
      if (/^\[.*\]$/.test(line)) { const re = globRe(line.slice(1, -1).trim()); ok = re.test(baseName(mapFile)) || re.test(mapFile); continue; }
      const f = joinPath(dirOf(file), line);
      if (/\.txt$/i.test(f)) { if (ok) await parseRulesTxt(f, mapFile, seen, out); } else out.push({ file: f, active: ok });
    }
    return out;
  }

  // carte de règles -> calques décodés (cases en coordonnées locales)
  async function loadRuleMap(file) {
    const text = await call('readText', { projectPath: S.projectPath, file });
    const doc = new DOMParser().parseFromString(text, 'application/xml');
    if (doc.querySelector('parsererror')) throw new Error(baseName(file) + ' illisible');
    const mapEl = doc.documentElement;
    const base = dirOf(file);
    const inf = mapInfinite(mapEl);
    const W = inf ? inf.w : Number(mapEl.getAttribute('width')); const H = inf ? inf.h : Number(mapEl.getAttribute('height'));
    const tw = Number(mapEl.getAttribute('tilewidth')) || 32; const th = Number(mapEl.getAttribute('tileheight')) || 32;
    const tilesets = [];
    for (const el of mapEl.querySelectorAll(':scope > tileset')) {
      const src = el.getAttribute('source');
      const source = src ? joinPath(base, src) : null;
      tilesets.push({ firstgid: Number(el.getAttribute('firstgid')), source, matchType: source ? (await tsxMeta(source)).matchType : matchTypes(el) });
    }
    tilesets.sort((a, b) => a.firstgid - b.firstgid);
    const layers = [];
    for (const el of mapEl.querySelectorAll('layer')) {
      const dataEl = el.querySelector(':scope > data');
      if (!dataEl) continue;
      const lw = inf ? W : Number(el.getAttribute('width')) || W; const lh = inf ? H : Number(el.getAttribute('height')) || H;
      let data = await decodeData(dataEl, lw, lh, inf);
      if (lw !== W || lh !== H) { const d = new Uint32Array(W * H); for (let y = 0; y < Math.min(lh, H); y++) for (let x = 0; x < Math.min(lw, W); x++) d[y * W + x] = data[y * lw + x]; data = d; }
      layers.push({ name: el.getAttribute('name') || '', props: readProps(el), data });
    }
    const options = [];
    for (const og of mapEl.querySelectorAll('objectgroup')) {
      if ((og.getAttribute('name') || '').toLowerCase() !== 'rule_options') continue;
      for (const o of og.querySelectorAll(':scope > object')) {
        const x = Number(o.getAttribute('x') || 0) / tw - (inf ? inf.ox : 0); const y = Number(o.getAttribute('y') || 0) / th - (inf ? inf.oy : 0);
        options.push({ x, y, w: Number(o.getAttribute('width') || 0) / tw, h: Number(o.getAttribute('height') || 0) / th, props: readProps(o) });
      }
    }
    return { file, props: readProps(mapEl), tilesets, W, H, layers, options };
  }
  function ruleTileset(R, id) {
    let found = null;
    for (const t of R.tilesets) { if (t.firstgid <= id) found = t; else break; }
    return found;
  }
  // tuile de la carte de règles -> { special } ou { gid } dans la carte cible (null : tileset absent de la carte)
  function mapRuleGid(R, raw, M) {
    const id = raw & GID_MASK;
    const ts = ruleTileset(R, id);
    if (!ts) return { gid: null };
    const local = id - ts.firstgid;
    const special = ts.matchType.get(local);
    if (special) return { special };
    const target = ts.source ? M.tilesets.find((t) => t.source === ts.source) : null;
    if (!target) return { gid: null, source: ts.source };
    return { gid: ((target.firstgid + local) | (raw & ~GID_MASK)) >>> 0 };
  }
  // zones liées (4 voisins avec des calques regions, 8 sinon : comme Tiled)
  function coherent(cells, W, eight) {
    const left = new Set(cells); const out = [];
    for (const start of cells) {
      if (!left.has(start)) continue;
      left.delete(start);
      const comp = [start]; const stack = [start];
      while (stack.length) {
        const i = stack.pop(); const x = i % W; const y = (i - x) / W;
        for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
          if ((!dx && !dy) || (!eight && dx && dy)) continue;
          const nx = x + dx; const ny = y + dy;
          if (nx < 0 || nx >= W || ny < 0) continue;
          const j = ny * W + nx;
          if (left.has(j)) { left.delete(j); comp.push(j); stack.push(j); }
        }
      }
      out.push(comp);
    }
    return out;
  }
  // les tilesets utilisés par les sorties d'une carte de règles sont ajoutés à la carte (comme Tiled)
  async function ensureOutputTilesets(R, M) {
    const need = new Set();
    for (const L of R.layers) {
      if (!/^output[^_]*_/i.test(L.name)) continue;
      for (const g of L.data) if (g) { const r = mapRuleGid(R, g, M); if (r.gid === null && r.source) need.add(r.source); }
    }
    for (const src of need) { try { await attachTileset(M, src); } catch (e) { /* tileset introuvable : ses tuiles sont ignorées */ } }
    return need.size;
  }
  function compileRules(R, M) {
    const W = R.W;
    const props = R.props;
    const infos = R.layers.map((L) => {
      const n = L.name;
      let m;
      if (/^regions$/i.test(n)) return { L, kind: 'regions' };
      if (/^regions_input$/i.test(n)) return { L, kind: 'regions_in' };
      if (/^regions_output$/i.test(n)) return { L, kind: 'regions_out' };
      if ((m = n.match(/^input(not)?([^_]*)_(.+)$/i)) && !/^not/i.test(m[2])) return { L, kind: 'input', not: !!m[1], index: m[2], target: m[3] };
      if ((m = n.match(/^output([^_]*)_(.+)$/i))) return { L, kind: 'output', index: m[1], target: m[2] };
      return { L, kind: 'other' };
    });
    const cellsOf = (list) => { const set = new Set(); for (const { L } of list) L.data.forEach((g, i) => { if (g) set.add(i); }); return set; };
    const legacy = infos.some((i) => i.kind.startsWith('regions'));
    const inputs = infos.filter((i) => i.kind === 'input'); const outputs = infos.filter((i) => i.kind === 'output');
    const regIn = infos.some((i) => i.kind === 'regions' || i.kind === 'regions_in') ? cellsOf(infos.filter((i) => i.kind === 'regions' || i.kind === 'regions_in')) : cellsOf(inputs);
    const regOut = infos.some((i) => i.kind === 'regions' || i.kind === 'regions_out') ? cellsOf(infos.filter((i) => i.kind === 'regions' || i.kind === 'regions_out')) : cellsOf(outputs);
    const all = [...new Set([...regIn, ...regOut])].sort((a, b) => a - b);
    const comps = coherent(all, W, !legacy);
    const rules = [];
    for (const comp of comps) {
      const inCells = comp.filter((i) => regIn.has(i)); const outCells = comp.filter((i) => regOut.has(i));
      if (!inCells.length) continue;
      const xy = (i) => [i % W, Math.floor(i / W)];
      let minX = Infinity; let minY = Infinity; let maxX = -Infinity; let maxY = -Infinity;
      for (const i of inCells) { const [x, y] = xy(i); minX = Math.min(minX, x); minY = Math.min(minY, y); maxX = Math.max(maxX, x); maxY = Math.max(maxY, y); }
      let top = Infinity; let leftX = Infinity;
      for (const i of comp) { const [x, y] = xy(i); if (y < top || (y === top && x < leftX)) { top = y; leftX = x; } }
      // conditions : index -> calque cible -> case -> condition
      const groups = new Map();
      for (const info of inputs) {
        if (!groups.has(info.index)) groups.set(info.index, new Map());
        const g = groups.get(info.index);
        if (!g.has(info.target)) g.set(info.target, { cells: new Map(), autoEmpty: false });
        const t = g.get(info.target);
        if (truthy(info.L.props.AutoEmpty) || truthy(info.L.props.StrictEmpty)) t.autoEmpty = true;
        for (const i of inCells) {
          const raw = info.L.data[i];
          if (!raw) continue;
          if (!t.cells.has(i)) t.cells.set(i, { yes: [], no: [], nonEmpty: false, noNonEmpty: false, other: false, negate: false, ignore: false });
          const c = t.cells.get(i);
          const r = mapRuleGid(R, raw, M);
          if (r.special === 'Ignore') c.ignore = true;
          else if (!info.not) {
            if (r.special === 'Empty') c.yes.push(0); else if (r.special === 'NonEmpty') c.nonEmpty = true;
            else if (r.special === 'Other') c.other = true; else if (r.special === 'Negate') c.negate = true;
            else c.yes.push(r.gid === null ? -1 : r.gid);
          } else if (r.special === 'Empty') c.no.push(0);
          else if (r.special === 'NonEmpty') c.noNonEmpty = true;
          else if (!r.special && r.gid !== null) c.no.push(r.gid);
        }
      }
      const conds = [];
      for (const [, g] of groups) {
        const list = [];
        for (const [target, t] of g) {
          const used = new Set();
          t.cells.forEach((c) => c.yes.forEach((v) => used.add(v)));
          for (const i of inCells) {
            let c = t.cells.get(i);
            const blank = !c || (!c.yes.length && !c.no.length && !c.nonEmpty && !c.noNonEmpty && !c.other && !c.negate);
            if (blank) {
              if (legacy) c = { yes: [], no: [], other: true };
              else if (t.autoEmpty) c = { yes: [0], no: [] };
              else continue;
            }
            if (c.negate) { c.no = c.no.concat(c.yes); c.yes = []; }
            const cd = { x: i % W, y: Math.floor(i / W), target };
            if (c.yes.length) cd.yes = new Set(c.yes);
            if (c.no.length) cd.no = new Set(c.no);
            if (c.nonEmpty) cd.nonEmpty = true;
            if (c.noNonEmpty) cd.noNonEmpty = true;
            if (c.other) { cd.other = used; cd.otherEmpty = !used.has(0); }
            if (cd.yes || cd.no || cd.nonEmpty || cd.noNonEmpty || cd.other) list.push(cd);
          }
        }
        if (list.length) conds.push(list);
      }
      if (!conds.length) continue;
      // sorties : index -> { probabilité, calques }
      const outs = new Map();
      for (const info of [...outputs].reverse()) {
        const cells = [];
        for (const i of outCells) {
          const raw = info.L.data[i];
          if (!raw) continue;
          const r = mapRuleGid(R, raw, M);
          if (r.special === 'Empty') cells.push([i % W, Math.floor(i / W), 0]);
          else if (!r.special && r.gid !== null) cells.push([i % W, Math.floor(i / W), r.gid]);
        }
        if (!outs.has(info.index)) outs.set(info.index, { prob: info.L.props.Probability !== undefined ? Number(info.L.props.Probability) : 1, items: [] });
        if (cells.length) outs.get(info.index).items.push({ target: info.target, cells });
      }
      for (const [k, v] of outs) if (!v.items.length) outs.delete(k);
      // options : carte, puis rectangles du calque rule_options qui touchent la règle
      const opt = { ModX: 1, ModY: 1, OffsetX: 0, OffsetY: 0, Probability: 1, Disabled: false, NoOverlappingOutput: truthy(props.NoOverlappingOutput), IgnoreLock: false };
      const take = (p) => { for (const k of Object.keys(opt)) if (p[k] !== undefined) opt[k] = typeof opt[k] === 'boolean' ? truthy(p[k]) : Number(p[k]); };
      take(props);
      for (const o of R.options) if (o.x < maxX + 1 && o.x + o.w > minX && o.y < maxY + 1 && o.y + o.h > minY) take(o.props);
      if (opt.Disabled) continue;
      rules.push({ conds, outs, inCells: inCells.map((i) => [i % W, Math.floor(i / W)]), outCells: outCells.map((i) => [i % W, Math.floor(i / W)]), minX, minY, maxX, maxY, top, left: leftX, opt });
    }
    rules.sort((a, b) => a.top - b.top || a.left - b.left);
    return { rules, legacy, props, outputTargets: [...new Set(outputs.map((o) => o.target))], inputTargets: [...new Set(inputs.map((o) => o.target))] };
  }
  const findTileLayer = (M, name) => M.layers.find((l) => l.kind === 'tile' && l.name === name) || null;
  async function createTileLayerAtTop(M, name) {
    const doc = M.doc;
    const el = doc.createElement('layer');
    el.setAttribute('id', String(nextLayerId()));
    el.setAttribute('name', name);
    el.setAttribute('width', String(M.w)); el.setAttribute('height', String(M.h));
    const data = doc.createElement('data');
    data.setAttribute('encoding', 'csv');
    const rows = []; for (let y = 0; y < M.h; y++) rows.push(new Array(M.w).fill(0).join(','));
    data.textContent = '\n' + rows.join(',\n') + '\n  ';
    el.append(doc.createTextNode('\n  '), data, doc.createTextNode('\n '));
    const last = M.el.lastChild;
    if (last && last.nodeType === 3) { M.el.insertBefore(doc.createTextNode('\n '), last); M.el.insertBefore(el, last); } else M.el.append(doc.createTextNode('\n '), el);
    return el;
  }
  // applique une carte de règles compilée ; renvoie le nombre de règles trouvées
  function applyRuleSet(C, M, area) {
    const props = C.props;
    const wrap = truthy(props.WrapBorder); const overflow = !wrap && truthy(props.OverflowBorder);
    const outside = wrap || overflow || (props.MatchOutsideMap !== undefined ? truthy(props.MatchOutsideMap) : !!M.inf);
    const inOrder = C.legacy || truthy(props.MatchInOrder);
    const deleteTiles = truthy(props.DeleteTiles);
    const layers = new Map();
    for (const n of [...C.inputTargets, ...C.outputTargets]) layers.set(n, findTileLayer(M, n));
    // toutes les règles lisent la carte d'origine, sauf MatchInOrder (et l'ancien système des calques regions)
    const snap = new Map();
    if (!inOrder) for (const n of C.inputTargets) { const L = layers.get(n); if (L) snap.set(n, L.data.slice()); }
    const W = M.w; const H = M.h;
    const read = (name, x, y) => {
      const L = layers.get(name);
      if (!L) return 0;
      if (x < 0 || y < 0 || x >= W || y >= H) {
        if (wrap) { x = ((x % W) + W) % W; y = ((y % H) + H) % H; } else if (overflow) { x = clamp(x, 0, W - 1); y = clamp(y, 0, H - 1); } else return 0;
      }
      const d = inOrder ? L.data : snap.get(name);
      return d[y * L.w + x] >>> 0;
    };
    const ok = (cd, c) => {
      if (cd.yes || cd.nonEmpty || cd.other) {
        const pass = (cd.yes && cd.yes.has(c)) || (cd.nonEmpty && c !== 0) || (cd.other && (c === 0 ? cd.otherEmpty : !cd.other.has(c)));
        if (!pass) return false;
      }
      if (cd.no && cd.no.has(c)) return false;
      if (cd.noNonEmpty && c !== 0) return false;
      return true;
    };
    const pending = [];
    let found = 0;
    const write = (rule, dx, dy, written) => {
      // un index de sortie au hasard (selon Probability) + les sorties sans index
      const keyed = [...rule.outs.entries()].filter(([k]) => k !== '');
      const chosen = [];
      if (rule.outs.has('')) chosen.push(rule.outs.get(''));
      if (keyed.length) {
        let total = keyed.reduce((s, [, v]) => s + Math.max(0, v.prob), 0); let r = Math.random() * total;
        let pick = keyed[keyed.length - 1][1];
        for (const [, v] of keyed) { r -= Math.max(0, v.prob); if (r < 0) { pick = v; break; } }
        if (total > 0) chosen.push(pick);
      }
      const plan = [];
      for (const o of chosen) for (const it of o.items) {
        const L = findTileLayer(M, it.target);
        if (!L || L.readonly || (L.locked && !rule.opt.IgnoreLock)) continue;
        for (const [x, y, g] of it.cells) { const tx = x + dx; const ty = y + dy; if (tx >= 0 && ty >= 0 && tx < L.w && ty < L.h) plan.push([L, tx, ty, g]); }
      }
      if (rule.opt.NoOverlappingOutput) {
        if (plan.some(([L, x, y]) => written.has(L.uid + ':' + x + ',' + y))) return false;
        plan.forEach(([L, x, y]) => written.add(L.uid + ':' + x + ',' + y));
      }
      if (deleteTiles) for (const n of C.outputTargets) { const L = findTileLayer(M, n); if (L && !L.readonly) for (const [x, y] of rule.inCells) setCell(L, x + dx, y + dy, 0); }
      for (const [L, x, y, g] of plan) setCell(L, x, y, g);
      return true;
    };
    for (const rule of C.rules) {
      const written = new Set();
      const x0 = outside ? -rule.maxX : -rule.minX; const x1 = outside ? W - 1 - rule.minX : W - 1 - rule.maxX;
      const y0 = outside ? -rule.maxY : -rule.minY; const y1 = outside ? H - 1 - rule.minY : H - 1 - rule.maxY;
      const o = rule.opt;
      for (let dy = y0; dy <= y1; dy++) {
        if (o.ModY > 1 && ((((dy + rule.minY - o.OffsetY) % o.ModY) + o.ModY) % o.ModY)) continue;
        if (area && (dy + rule.maxY < area.y || dy + rule.minY >= area.y + area.h)) continue;
        for (let dx = x0; dx <= x1; dx++) {
          if (o.ModX > 1 && ((((dx + rule.minX - o.OffsetX) % o.ModX) + o.ModX) % o.ModX)) continue;
          if (area && (dx + rule.maxX < area.x || dx + rule.minX >= area.x + area.w)) continue;
          let match = false;
          for (const list of rule.conds) {
            let all = true;
            for (const cd of list) if (!ok(cd, read(cd.target, cd.x + dx, cd.y + dy))) { all = false; break; }
            if (all) { match = true; break; }
          }
          if (!match || (o.Probability < 1 && Math.random() >= o.Probability)) continue;
          if (inOrder) { if (write(rule, dx, dy, written)) found++; } else pending.push([rule, dx, dy, written]);
        }
      }
    }
    for (const [rule, dx, dy, written] of pending) if (write(rule, dx, dy, written)) found++;
    return found;
  }
  async function runAutomap() {
    const M = S.map;
    if (!M || AM.busy) return;
    if (isRuleMap(M)) { flash('Ouvre une carte du jeu pour lui appliquer les règles (tu es dans une carte de règles).', true); return; }
    AM.busy = true; renderAutomap();
    try {
      AM.rulesFile = await rulesFileFor(M);
      const entries = (await parseRulesTxt(AM.rulesFile, M.file)).filter((e) => e.active);
      if (!entries.length) { flash('Aucune règle : crée-en une ou complète ' + AM.rulesFile + '.', true); return; }
      const area = AM.onlySel && S.selection ? S.selection : null;
      const lines = []; let total = 0;
      // calques et tilesets manquants d'abord (changement de structure), puis les tuiles (un seul « annuler »)
      const loaded = [];
      for (const e of entries) {
        try {
          const R = await loadRuleMap(e.file);
          await ensureOutputTilesets(R, M);
          loaded.push([e, R]);
        } catch (err) { lines.push(baseName(e.file) + ' : ' + err.message); }
      }
      let created = 0;
      const compiled = [];
      for (const [e, R] of loaded) {
        const C = compileRules(R, M);
        for (const n of C.outputTargets) if (!findTileLayer(M, n)) { await createTileLayerAtTop(M, n); await walkLayers(M); created++; }
        compiled.push([e, C]);
      }
      if (created) refreshAnimFlags();
      begin();
      for (const [e, C] of compiled) {
        const n = applyRuleSet(C, M, area);
        total += n;
        lines.push(`${baseName(e.file)} : ${C.rules.length} règle(s), ${n} placée(s)`);
      }
      end();
      refreshAnimFlags();
      if (created) { M.dirty = true; renderLayers(); }
      AM.report = lines.join('\n') + (created ? `\n${created} calque(s) créé(s) en haut de la liste.` : '');
      flash(total ? `Automapping : ${total} règle(s) appliquée(s) (Ctrl+Z pour annuler).` : 'Automapping : aucune règle ne correspond à la carte.');
      needDraw = true; renderStatus();
    } catch (e) { flash(e.message, true); } finally { AM.busy = false; renderAutomap(); }
  }
  async function refreshRulesList() {
    const M = S.map;
    if (!M) { AM.entries = []; return; }
    AM.rulesFile = await rulesFileFor(M);
    const back = AM.back && isRuleMap(M) ? AM.back : M.file;
    AM.entries = await parseRulesTxt(AM.rulesFile, back);
    // cartes de règles du dossier pas encore listées dans rules.txt
    try {
      const listed = new Set(AM.entries.map((e) => e.file));
      for (const f of await call('list', { projectPath: S.projectPath, dir: dirOf(AM.rulesFile) || 'Maps', ext: '.tmx' })) if (/^rules/i.test(baseName(f)) && !listed.has(f)) AM.entries.push({ file: f, active: false, unlisted: true });
    } catch (e) { /* rien */ }
  }
  async function openRuleMap(file) {
    const M = S.map;
    if (M && !isRuleMap(M)) AM.back = M.file;
    await openMap(file);
    if (S.map && S.map.file === file) { S.rightTab = 'automap'; renderTilesets(); }
  }
  async function writeRulesTxt(text) {
    await call('writeText', { projectPath: S.projectPath, file: AM.rulesFile, text });
  }
  async function addToRulesTxt(file) {
    let text = '';
    try { text = await call('readText', { projectPath: S.projectPath, file: AM.rulesFile }); } catch (e) { /* nouveau fichier */ }
    const crlf = /\r\n/.test(text) || !text;
    const rel = dirOf(AM.rulesFile) === dirOf(file) ? baseName(file) : relPath(dirOf(AM.rulesFile), file);
    const nl = crlf ? '\r\n' : '\n';
    await writeRulesTxt(text + (text && !/\r?\n$/.test(text) ? nl : '') + rel);
  }
  async function editRulesTxt() {
    try {
      let text = '';
      try { text = await call('readText', { projectPath: S.projectPath, file: AM.rulesFile }); } catch (e) { /* nouveau */ }
      const area = h('textarea', { class: 'pjs-input pjc-rulestxt', spellcheck: 'false' });
      area.value = text;
      const r = await modal('Fichier de règles : ' + AM.rulesFile, h('div', { class: 'pjc-form' }, area,
        h('p', { class: 'pjs-hint' }, 'Une carte de règles par ligne, appliquées dans l’ordre (chemin relatif à ce fichier). [K0*] : les lignes suivantes ne servent qu’aux cartes dont le nom correspond ([*] pour toutes). Commentaires : # ou //.')),
      [[null, 'Annuler'], ['ok', 'Enregistrer', true]]);
      if (r !== 'ok') return;
      await writeRulesTxt(area.value.replace(/\r?\n/g, /\r\n/.test(text) || !text ? '\r\n' : '\n'));
      await refreshRulesList(); renderAutomap(); flash('rules.txt enregistré.');
    } catch (e) { flash(e.message, true); }
  }
  async function newRuleMap() {
    try {
      const M = S.map;
      if (!M) return;
      const src = isRuleMap(M) && AM.back ? null : M;
      const tileNames = (src || M).layers.filter((l) => l.kind === 'tile' && !RULE_LAYER.test(l.name)).map((l) => l.name);
      const name = h('input', { class: 'pjs-input', placeholder: 'ex. chemins' });
      const input = h('select', { class: 'pjs-input' }, tileNames.map((n, i) => h('option', { value: n, selected: i === 0 }, n)));
      const outs = tileNames.map((n) => h('label', { class: 'pjc-check' }, h('input', { type: 'checkbox', value: n }), n));
      const size = h('input', { class: 'pjs-input', type: 'number', min: 8, max: 300, value: 40 });
      const list = h('input', { type: 'checkbox', checked: true });
      const r = await modal('Nouvelle carte de règles', h('div', { class: 'pjc-form' },
        h('label', null, 'Nom (fichier rules_<nom>.tmx)', name),
        h('div', { class: 'pjc-pair' }, h('label', null, 'Calque lu (input_)', input), h('label', null, 'Taille (cases)', size)),
        h('label', null, 'Calques écrits (output_)', h('div', { class: 'pjc-checks' }, outs)),
        h('div', null, h('label', { class: 'pjc-check' }, list, 'Ajouter à rules.txt')),
        h('p', { class: 'pjs-hint' }, 'Dans la carte de règles : dessine le motif à chercher sur input_, ce qu’il faut poser sur output_, et marque la zone de chaque règle avec n’importe quelle tuile sur regions_input (cases lues) et regions_output (cases écrites). Les tilesets de la carte actuelle sont repris.')),
      [[null, 'Annuler'], ['ok', 'Créer', true]]);
      if (r !== 'ok') return;
      const clean = name.value.trim().replace(/[<>:"/\\|?*\s]+/g, '_').replace(/\.tmx$/i, '').replace(/^rules_/i, '');
      if (!clean) { flash('Donne un nom à la règle.', true); return; }
      const file = joinPath(M.base, 'rules_' + clean + '.tmx');
      if (await call('exists', { projectPath: S.projectPath, file })) { flash('Une carte de règles porte déjà ce nom.', true); return; }
      const N = clamp(Math.round(+size.value) || 40, 8, 300);
      const outNames = outs.map((l) => l.querySelector('input')).filter((i) => i.checked).map((i) => i.value);
      if (!outNames.length && input.value) outNames.push(input.value);
      const esc = (v) => String(v).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
      const rows = []; for (let y = 0; y < N; y++) rows.push(new Array(N).fill(0).join(','));
      const layerNames = ['regions_input', 'regions_output', ...(input.value ? ['input_' + input.value] : []), ...outNames.map((n) => 'output_' + n)];
      let id = 1;
      const text = ['<?xml version="1.0" encoding="UTF-8"?>',
        `<map version="1.10" tiledversion="1.12.1" orientation="orthogonal" renderorder="right-down" width="${N}" height="${N}" tilewidth="${M.tw}" tileheight="${M.th}" infinite="0" nextlayerid="${layerNames.length + 1}" nextobjectid="1">`,
        ...M.tilesets.filter((t) => t.source).map((t) => ` <tileset firstgid="${t.firstgid}" source="${esc(relPath(dirOf(file), t.source))}"/>`),
        ...layerNames.flatMap((n) => [` <layer id="${id++}" name="${esc(n)}" width="${N}" height="${N}"${n.startsWith('regions') ? ' opacity="0.5"' : ''}>`, '  <data encoding="csv">', rows.join(',\r\n'), '</data>', ' </layer>']),
        '</map>', ''].join('\r\n');
      await call('writeText', { projectPath: S.projectPath, file, text, create: true });
      AM.rulesFile = await rulesFileFor(M);
      if (list.checked) await addToRulesTxt(file);
      await openRuleMap(file);
      flash('Carte de règles créée : ' + baseName(file));
    } catch (e) { flash(e.message, true); }
  }
  // calques spéciaux d'une carte de règles (regions_input, input_<calque>…)
  async function addRuleLayer() {
    const M = S.map;
    if (!M) return;
    const kind = h('select', { class: 'pjs-input' }, [['regions_input', 'regions_input (zone lue)'], ['regions_output', 'regions_output (zone écrite)'], ['input', 'input_ (motif à trouver)'],
      ['inputnot', 'inputnot_ (tuiles interdites)'], ['output', 'output_ (tuiles posées)']].map(([v, l]) => h('option', { value: v }, l)));
    const idx = h('input', { class: 'pjs-input', placeholder: '(aucun)' });
    const target = h('input', { class: 'pjs-input', list: 'pjc-am-targets', placeholder: 'nom du calque de la carte' });
    let targets = [];
    if (AM.back) { try { const t = await call('readText', { projectPath: S.projectPath, file: AM.back }); targets = [...t.matchAll(/<layer [^>]*name="([^"]*)"/g)].map((m) => m[1]); } catch (e) { /* rien */ } }
    const dl = h('datalist', { id: 'pjc-am-targets' }, targets.map((n) => h('option', { value: n })));
    const r = await modal('Calque de règle', h('div', { class: 'pjc-form' }, h('label', null, 'Type', kind),
      h('div', { class: 'pjc-pair' }, h('label', null, 'Calque visé', target), h('label', null, 'Index (variantes)', idx)), dl,
      h('p', { class: 'pjs-hint' }, 'Même index sur plusieurs input_ : une seule condition. Index différents : l’une OU l’autre. Sur output_, un index est tiré au hasard à chaque règle trouvée.')),
    [[null, 'Annuler'], ['ok', 'Ajouter', true]]);
    if (r !== 'ok') return;
    const k = kind.value;
    const t = target.value.trim(); const i = idx.value.trim().replace(/_/g, '');
    if (!k.startsWith('regions') && !t) { flash('Indique le calque visé.', true); return; }
    const name = k.startsWith('regions') ? k : `${k}${i}_${t}`;
    if (M.layers.some((l) => l.name === name)) { flash('Ce calque existe déjà.', true); return; }
    const el = await createTileLayerAtTop(M, name);
    if (k.startsWith('regions')) el.setAttribute('opacity', '0.5');
    await afterStructure(el);
  }
  function renderAutomap() {
    const box = root && root.querySelector('.pjc-automap');
    if (!box) return;
    box.innerHTML = '';
    const M = S.map;
    if (!M) { box.appendChild(h('div', { class: 'pjs-hint pjc-empty' }, 'Ouvre une carte.')); return; }
    const ruleMap = isRuleMap(M);
    if (ruleMap) {
      box.appendChild(h('div', { class: 'pjc-ambanner' }, h('b', null, 'Carte de règles'),
        h('span', { class: 'pjs-hint' }, 'regions_input : cases lues · regions_output : cases écrites · input_<calque> : motif · inputnot_<calque> : interdit · output_<calque> : résultat. Chaque zone séparée est une règle.'),
        h('div', { class: 'pjc-btnrow left' },
          h('button', { class: 'pjs-btn small', onclick: addRuleLayer }, '+ Calque de règle'),
          AM.back ? h('button', { class: 'pjs-btn small primary', onclick: () => openMap(AM.back) }, '← ' + baseName(AM.back).replace(/\.tmx$/, '')) : null)));
    } else {
      box.appendChild(h('div', { class: 'pjc-btnrow left' },
        h('button', { class: 'pjs-btn primary small', disabled: AM.busy, title: 'Ctrl+M', onclick: runAutomap }, AM.busy ? 'Automapping…' : 'Appliquer l’automapping'),
        h('label', { class: 'pjc-check' }, h('input', { type: 'checkbox', checked: AM.onlySel, onchange: (e) => { AM.onlySel = e.target.checked; store.set('amSel', AM.onlySel); } }), 'Seulement la sélection')));
    }
    box.appendChild(h('div', { class: 'pjc-title' }, 'Règles · ' + (AM.rulesFile || 'rules.txt')));
    const list = h('div', { class: 'pjc-amlist' });
    if (!AM.entries.length) list.appendChild(h('div', { class: 'pjs-hint pjc-empty' }, 'Aucune carte de règles.'));
    AM.entries.forEach((e, n) => list.appendChild(h('div', { class: 'pjc-amrow' + (M.file === e.file ? ' on' : '') + (e.active ? '' : ' off'), title: e.file },
      h('span', { class: 'pjc-amnum' }, e.unlisted ? '–' : String(n + 1)),
      h('span', { class: 'pjc-lname' }, baseName(e.file).replace(/\.tmx$/i, '')),
      e.unlisted ? h('button', { class: 'pjc-mini', title: 'Ajouter à rules.txt', onclick: async () => { try { await addToRulesTxt(e.file); await refreshRulesList(); renderAutomap(); } catch (err) { flash(err.message, true); } } }, '+')
        : !e.active ? h('span', { class: 'pjs-hint', title: 'Filtre [ ] de rules.txt' }, 'filtrée') : null,
      h('button', { class: 'pjs-btn small', onclick: () => openRuleMap(e.file) }, 'Ouvrir'))));
    box.appendChild(list);
    box.appendChild(h('div', { class: 'pjc-btnrow left' },
      h('button', { class: 'pjs-btn small', onclick: newRuleMap }, 'Nouvelle règle…'),
      h('button', { class: 'pjs-btn small', onclick: editRulesTxt }, 'Modifier rules.txt'),
      h('button', { class: 'pjc-mini', title: 'Relire', onclick: async () => { await refreshRulesList(); renderAutomap(); } }, '⟳')));
    if (AM.report && !ruleMap) box.appendChild(h('pre', { class: 'pjc-amreport' }, AM.report));
  }

  // ---------------------------------------------------------------------------
  // Enregistrement (format de Tiled conservé)
  // ---------------------------------------------------------------------------
  // fins de ligne d'origine conservées (Tiled sous Windows : CRLF)
  function serialize(doc, crlf) {
    const text = '<?xml version="1.0" encoding="UTF-8"?>\n' + new XMLSerializer().serializeToString(doc.documentElement) + '\n';
    return crlf ? text.replace(/\r?\n/g, '\r\n') : text;
  }
  async function save() {
    const M = S.map;
    if (!M) return;
    try {
      const now = await call('mtime', { projectPath: S.projectPath, file: M.file });
      if (now && M.mtime && Math.abs(now - M.mtime) > 1 && !(await confirmBox('La carte a été modifiée ailleurs (Tiled ?) depuis son ouverture. L’écraser ?', 'Écraser'))) return;
      for (const l of M.layers) {
        if (l.kind === 'tile' && !l.readonly && l.dataEl) await encodeData(l);
        if (l.kind !== 'tile' && l.kind !== 'group' && l.kind !== 'object' && l.kind !== 'image') continue;
        if (l.visible) l.el.removeAttribute('visible'); else l.el.setAttribute('visible', '0');
        if (l.opacity >= 1) l.el.removeAttribute('opacity'); else l.el.setAttribute('opacity', String(Math.round(l.opacity * 100) / 100));
      }
      M.mtime = await call('writeText', { projectPath: S.projectPath, file: M.file, text: serialize(M.doc, M.crlf) });
      M.dirty = false;
      renderStatus();
      flash('Enregistré. Pour le jeu : Monde > « Mettre à jour les cartes modifiées » dans Studio.');
    } catch (e) { flash(e.message, true); }
  }

  // ---------------------------------------------------------------------------
  // Fenêtres
  // ---------------------------------------------------------------------------
  function modal(title, body, buttons) {
    return new Promise((resolve) => {
      const close = (v) => { ov.remove(); resolve(v); };
      const ov = h('div', { class: 'pjc-overlay', onmousedown: (e) => { if (e.target === ov) close(null); } },
        h('div', { class: 'pjc-modal' }, h('h3', null, title), body,
          h('div', { class: 'pjc-modal-actions' }, buttons.map(([v, label, primary]) => h('button', { class: 'pjs-btn' + (primary ? ' primary' : ''), onclick: () => close(v) }, label)))));
      ov.addEventListener('keydown', (e) => { e.stopPropagation(); if (e.key === 'Escape') close(null); });
      root.appendChild(ov);
    });
  }
  const confirmBox = (text, ok) => modal(text, null, [[false, 'Annuler'], [true, ok || 'Continuer', true]]);
  async function confirmDiscard() {
    if (!S.map || !S.map.dirty) return true;
    const r = await modal('Modifications non enregistrées', h('p', { class: 'pjs-hint' }, S.map.file.replace(/^Maps\//, '') + ' a été modifiée.'),
      [[null, 'Annuler'], ['discard', 'Ne pas enregistrer'], ['save', 'Enregistrer', true]]);
    if (r === 'save') { await save(); return !S.map.dirty; }
    return r === 'discard';
  }

  // ---------------------------------------------------------------------------
  // Clavier
  // ---------------------------------------------------------------------------
  function onKey(e) {
    if (!root || !root.isConnected) return;
    const tag = (e.target && e.target.tagName) || '';
    if (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA' || root.querySelector('.pjc-overlay')) return;
    const k = e.key.toLowerCase();
    const ctrl = e.ctrlKey || e.metaKey;
    let done = true;
    if (ctrl && k === 's') save();
    else if (!S.map) done = false;
    else if (ctrl && k === 'z' && !e.shiftKey) undo();
    else if (ctrl && (k === 'y' || (k === 'z' && e.shiftKey))) redo();
    else if (ctrl && k === 'c') copySel(false);
    else if (ctrl && k === 'x') copySel(true);
    else if (ctrl && k === 'v') pasteSel();
    else if (ctrl && k === 'a') { S.selection = { x: 0, y: 0, w: S.map.w, h: S.map.h }; needDraw = true; }
    else if (ctrl && k === 'g') toggleGrid();
    else if (ctrl && k === 'm') runAutomap();
    else if ((k === 'delete' || k === 'backspace') && S.tool === 'object') deleteObj();
    else if (k === 'delete' || k === 'backspace') clearSel();
    else if (k === 'escape') { S.selection = null; if (S.obj) selectObj(null); if (S.anim) { S.anim = null; renderAnimPanel(); } needDraw = true; }
    else if (k === ' ') spaceDown = true;
    else if (k === '+' || k === '=') zoomStep(1);
    else if (k === '-') zoomStep(-1);
    else if (k === '0') { fit(); needDraw = true; renderStatus(); }
    else if (k === 'pageup' || k === 'pagedown') { selectLayerStep(k === 'pageup' ? 1 : -1); }
    else if ((k === 'x' || k === 'y' || k === 'z') && S.stamp && !ctrl) flipStamp(k);
    else {
      const tool = TOOLS.find((t) => t[2].toLowerCase() === k && !ctrl);
      if (tool) setTool(tool[0]); else done = false;
    }
    if (done) { e.preventDefault(); e.stopPropagation(); }
  }
  // X / Y : retourner le tampon, Z : le tourner (comme Tiled)
  function flipStamp(k) {
    const s = S.stamp;
    const out = new Uint32Array(s.gids.length);
    let w = s.w; let hh = s.h;
    for (let y = 0; y < s.h; y++) for (let x = 0; x < s.w; x++) {
      let g = s.gids[y * s.w + x] >>> 0;
      if (g & GID_MASK) {
        if (k === 'x') g = (g ^ FLIP_H) >>> 0;
        else if (k === 'y') g = (g ^ FLIP_V) >>> 0;
        else {
          // rotation d'un quart de tour à droite (table de Tiled)
          const mask = ((g & FLIP_H) ? 4 : 0) | ((g & FLIP_V) ? 2 : 0) | ((g & FLIP_D) ? 1 : 0);
          const m = [5, 4, 1, 0, 7, 6, 3, 2][mask];
          g = ((g & GID_MASK) | (m & 4 ? FLIP_H : 0) | (m & 2 ? FLIP_V : 0) | (m & 1 ? FLIP_D : 0)) >>> 0;
        }
      }
      let nx = x; let ny = y;
      if (k === 'x') nx = s.w - 1 - x; else if (k === 'y') ny = s.h - 1 - y; else { nx = s.h - 1 - y; ny = x; }
      if (k === 'z') { w = s.h; hh = s.w; out[ny * w + nx] = g; } else out[ny * s.w + nx] = g;
    }
    S.stamp = { w, h: hh, gids: out };
    needDraw = true;
  }
  function selectLayerStep(dir) {
    const M = S.map;
    const tiles = M.layers.map((l, i) => [l, i]).filter(([l]) => l.kind === 'tile');
    const pos = tiles.findIndex(([, i]) => i === M.active);
    const next = tiles[clamp(pos + dir, 0, tiles.length - 1)];
    if (next) { M.active = next[1]; renderLayers(); renderStatus(); }
  }
  window.addEventListener('keydown', onKey, true);
  window.addEventListener('keyup', (e) => { if (e.key === ' ') spaceDown = false; }, true);
  window.addEventListener('mouseup', () => { onUp(); tsUp(); });
  window.addEventListener('mousemove', (e) => { if (drag) onMove(e); if (tsDrag) tsMove(e); });

  // ---------------------------------------------------------------------------
  // Rendu de la page
  // ---------------------------------------------------------------------------
  function setTool(t) {
    const was = S.tool;
    S.tool = t;
    if (t !== 'object' && S.obj) S.obj = null;
    renderTools(); needDraw = true;
    if ((was === 'object') !== (t === 'object')) renderAnimPanel();
    // les objets se posent sur un calque d'objets : on y passe si le calque actif n'en est pas un
    const M = S.map;
    if (M && t === 'object' && activeLayer() && activeLayer().kind !== 'object') {
      const i = M.layers.map((l, j) => [l, j]).reverse().find(([l]) => l.kind === 'object');
      if (i) { M.active = i[1]; renderLayers(); renderStatus(); }
    }
    if (M && t !== 'object' && activeLayer() && activeLayer().kind === 'object') {
      const i = M.layers.map((l, j) => [l, j]).reverse().find(([l]) => l.kind === 'tile' && layerShown(l));
      if (i) { M.active = i[1]; renderLayers(); renderStatus(); }
    }
  }
  function toggleGrid() { S.grid = !S.grid; store.set('grid', S.grid); renderTools(); needDraw = true; }
  let flashTimer = null;
  function flash(text, error) {
    const el = root && root.querySelector('.pjc-msg');
    if (el) { el.textContent = text; el.classList.toggle('error', !!error); }
    clearTimeout(flashTimer);
    flashTimer = setTimeout(() => { const m = root && root.querySelector('.pjc-msg'); if (m) m.textContent = ''; }, error ? 8000 : 5000);
  }
  const icon = (d) => { const s = document.createElementNS('http://www.w3.org/2000/svg', 'svg'); s.setAttribute('viewBox', '0 0 24 24'); const p = document.createElementNS('http://www.w3.org/2000/svg', 'path'); p.setAttribute('d', d); p.setAttribute('fill', 'currentColor'); s.appendChild(p); return s; };
  function renderMaps() {
    const list = root && root.querySelector('.pjc-maps');
    if (!list) return;
    list.innerHTML = '';
    const q = S.search.trim().toLowerCase();
    const maps = ((S.ctx && S.ctx.maps) || []).filter((m) => !q || m.name.toLowerCase().includes(q));
    if (!maps.length) list.appendChild(h('div', { class: 'pjs-hint pjc-empty' }, !S.ctx || !S.ctx.rootExists ? 'Pas de dossier Data/Tiled dans le projet.' : 'Aucune carte trouvée.'));
    maps.forEach((m) => list.appendChild(h('div', { class: 'pjc-row' + (S.map && S.map.file === m.path ? ' sel' : ''), title: m.path, onclick: () => openMap(m.path) }, m.name)));
  }
  function renderLayers() {
    const box = root && root.querySelector('.pjc-layers');
    if (!box) return;
    box.innerHTML = '';
    const M = S.map;
    if (!M) return;
    const kindIcon = { tile: '▦', group: '▤', object: '◇', image: '▣' };
    M.layers.map((l, i) => [l, i]).reverse().forEach(([l, i]) => {
      const row = h('div', { class: 'pjc-layer' + (i === M.active ? ' on' : '') + (l.kind === 'group' ? ' group' : '') + (layerShown(l) ? '' : ' hidden'),
        style: { paddingLeft: 4 + l.depth * 12 + 'px' }, title: l.readonly ? 'Lecture seule : ' + l.readonly : '',
        onclick: () => { M.active = i; if (l.kind === 'object' && S.tool !== 'object') setTool('object'); else if (l.kind === 'tile' && S.tool === 'object') setTool('stamp'); renderLayers(); renderStatus(); },
        ondblclick: () => renameLayer(l) },
      h('button', { class: 'pjc-eye' + (l.visible ? '' : ' off'), title: 'Afficher / cacher', onclick: (e) => {
        e.stopPropagation(); l.visible = !l.visible; M.dirty = true;
        // les calques d'un groupe suivent sa visibilité
        if (l.kind === 'group') { const upd = (start, depth, pv) => { for (let j = start + 1; j < M.layers.length && M.layers[j].depth > depth; j++) if (M.layers[j].depth === depth + 1) { M.layers[j].parentVisible = pv; if (M.layers[j].kind === 'group') upd(j, depth + 1, pv && M.layers[j].visible); } }; upd(i, l.depth, l.parentVisible && l.visible); }
        rebuildBands(); needDraw = true; renderLayers(); renderStatus();
      } }, l.visible ? '●' : '○'),
      h('span', { class: 'pjc-kind' }, kindIcon[l.kind]),
      h('span', { class: 'pjc-lname' }, l.name || '(sans nom)'),
      l.kind === 'tile' && i === M.active ? h('input', { type: 'range', class: 'pjc-op', min: 0, max: 100, value: Math.round(l.opacity * 100), title: 'Opacité', onclick: (e) => e.stopPropagation(),
        oninput: (e) => { l.opacity = +e.target.value / 100; M.dirty = true; rebuildBands(); needDraw = true; } }) : null,
      l.readonly ? h('span', { class: 'pjc-ro' }, '🔒') : null);
      box.appendChild(row);
    });
  }
  function renderLayerBar() {
    const bar = root && root.querySelector('.pjc-layerbar');
    if (!bar) return;
    bar.innerHTML = '';
    const has = !!S.map;
    const menu = h('select', { class: 'pjs-input pjc-addlayer', title: 'Ajouter un calque', disabled: !has, onchange: (e) => { const v = e.target.value; e.target.value = ''; if (v) addLayer(v); } },
      h('option', { value: '' }, '+ Calque'), h('option', { value: 'tile' }, 'Calque de tuiles'), h('option', { value: 'object' }, 'Calque d’objets'), h('option', { value: 'group' }, 'Groupe'));
    bar.append(menu,
      h('button', { class: 'pjc-mini', title: 'Monter', disabled: !has, onclick: () => moveLayer(1) }, '▲'),
      h('button', { class: 'pjc-mini', title: 'Descendre', disabled: !has, onclick: () => moveLayer(-1) }, '▼'),
      h('button', { class: 'pjc-mini', title: 'Dupliquer', disabled: !has, onclick: duplicateLayer }, '⧉'),
      h('button', { class: 'pjc-mini', title: 'Renommer (ou double-clic)', disabled: !has, onclick: () => activeLayer() && renameLayer(activeLayer()) }, '✎'),
      h('button', { class: 'pjc-mini', title: 'Supprimer', disabled: !has, onclick: deleteLayer }, '✕'));
  }
  function renderTerrains() {
    const box = root && root.querySelector('.pjc-terrains');
    if (!box) return;
    box.innerHTML = '';
    const ts = curTs();
    const sets = (ts && ts.wangsets) || [];
    if (!sets.length) {
      const others = S.map ? S.map.tilesets.filter((t) => t.wangsets && t.wangsets.length) : [];
      box.appendChild(h('div', { class: 'pjs-hint pjc-empty' }, 'Ce tileset n’a pas de terrain automatique.'));
      if (others.length) box.appendChild(h('div', { class: 'pjc-btnrow left' }, others.map((t) => h('button', { class: 'pjs-btn small', onclick: () => { S.tsIndex = S.map.tilesets.indexOf(t); renderTilesets(); } }, t.name))));
      return;
    }
    sets.forEach((ws) => {
      box.appendChild(h('div', { class: 'pjc-title' }, ws.name + ' · ' + ({ corner: 'coins', edge: 'bords', mixed: 'coins et bords' }[ws.type] || ws.type)));
      ws.colors.forEach((col) => {
        const thumb = makeCanvas(32, 32);
        const tc = thumb.getContext('2d'); tc.imageSmoothingEnabled = false;
        if (col.tile >= 0) drawLocal(tc, ts, col.tile, 0, 0, 32, 32);
        const on = S.terrain && S.terrain.ws === ws && S.terrain.color === col;
        box.appendChild(h('div', { class: 'pjc-terrain' + (on ? ' on' : ''), onclick: () => { S.terrain = { ts, ws, color: col }; setTool('terrain'); renderTerrains(); } },
          h('span', { class: 'pjc-swatch', style: { background: col.color } }), thumb, h('span', { class: 'pjc-lname' }, col.name || 'Terrain ' + col.index)));
      });
    });
  }
  function renderObjPanel() {
    const box = root && root.querySelector('.pjc-anim');
    if (!box || S.tool !== 'object') return;
    box.innerHTML = '';
    animCanvas = null;
    box.appendChild(h('div', { class: 'pjc-title' }, 'Objets'));
    box.appendChild(h('div', { class: 'pjc-modes' }, OBJ_MODES.map(([id, label]) => h('button', { class: 'pjs-btn small' + (S.objMode === id ? ' primary' : ''), onclick: () => { S.objMode = id; renderObjPanel(); } }, label))));
    box.appendChild(h('label', { class: 'pjc-check' }, h('input', { type: 'checkbox', checked: S.snap, onchange: (e) => { S.snap = e.target.checked; store.set('snap', S.snap); } }), 'Aligner sur la grille'));
    const o = S.obj;
    if (!o || !S.map.doc.contains(o)) {
      box.appendChild(h('div', { class: 'pjs-hint' }, S.objMode === 'select' ? 'Clique un objet pour le choisir, glisse-le pour le déplacer, tire le coin pour le redimensionner.'
        : S.objMode === 'tile' ? 'Clique sur la carte pour poser la tuile choisie dans le tileset.' : S.objMode === 'point' ? 'Clique sur la carte pour poser un point.' : 'Glisse sur la carte pour dessiner l’objet.'));
      return;
    }
    const info = objInfo(o);
    const field = (label, attr, num) => h('label', null, label, h('input', { class: 'pjs-input', type: num ? 'number' : 'text', value: o.getAttribute(attr) || '',
      onchange: (e) => editObj((el) => { const v = e.target.value.trim(); if (v === '') el.removeAttribute(attr); else el.setAttribute(attr, num ? fmt(+v) : v); }) }));
    box.appendChild(h('div', { class: 'pjc-form' },
      h('div', { class: 'pjc-pair' }, field('Nom', 'name'), field('Classe', 'type')),
      h('div', { class: 'pjc-pair' }, field('X', 'x', true), field('Y', 'y', true),
        ['rect', 'ellipse', 'tile'].includes(info.kind) ? field('Largeur', 'width', true) : null, ['rect', 'ellipse', 'tile'].includes(info.kind) ? field('Hauteur', 'height', true) : null)));
    const props = h('div', { class: 'pjc-props' });
    objProps(o).forEach((p) => {
      const name = p.getAttribute('name');
      props.appendChild(h('div', { class: 'pjc-prop' },
        h('input', { class: 'pjs-input', value: name, onchange: (e) => editObj((el) => setObjProp(el, e.target.value.trim() || name, p.getAttribute('value') ?? p.textContent, name)) }),
        h('input', { class: 'pjs-input', value: p.getAttribute('value') ?? p.textContent, onchange: (e) => editObj((el) => setObjProp(el, name, e.target.value)) }),
        h('button', { class: 'pjc-mini', title: 'Retirer', onclick: () => editObj((el) => setObjProp(el, name, null)) }, '✕')));
    });
    box.appendChild(h('div', { class: 'pjc-title' }, `Propriétés (objet ${o.getAttribute('id')})`));
    box.appendChild(props);
    box.appendChild(h('div', { class: 'pjc-btnrow' },
      h('button', { class: 'pjs-btn small', onclick: async () => { const n = await askName('Nouvelle propriété', ''); if (n) editObj((el) => setObjProp(el, n, '')); } }, '+ Propriété'),
      h('button', { class: 'pjs-btn small', onclick: deleteObj }, 'Supprimer l’objet')));
  }
  function renderTools() {
    const bar = root && root.querySelector('.pjc-tools');
    if (!bar) return;
    bar.innerHTML = '';
    TOOLS.forEach(([id, label, key, path]) => bar.appendChild(h('button', { class: 'pjc-tool' + (S.tool === id ? ' on' : ''), title: `${label} (${key})`, onclick: () => setTool(id) }, icon(path))));
    bar.appendChild(h('div', { class: 'pjc-sep' }));
    bar.appendChild(h('button', { class: 'pjc-tool toggle' + (S.grid ? ' active' : ''), title: 'Grille (Ctrl+G)', onclick: toggleGrid }, icon('M3 3h18v18H3zm2 2v4h4V5zm6 0v4h2V5zm4 0v4h4V5zM5 11v2h4v-2zm6 0v2h2v-2zm4 0v2h4v-2zM5 15v4h4v-4zm6 0v4h2v-4zm4 0v4h4v-4z')));
    bar.appendChild(h('button', { class: 'pjc-tool toggle' + (S.animate ? ' active' : ''), title: 'Jouer les tuiles animées', onclick: () => { S.animate = !S.animate; store.set('animate', S.animate); bands.forEach((b) => { if (!b.dynamic) b.cache.clear(); }); renderTools(); needDraw = true; } }, icon('M8 5v14l11-7z')));
  }
  function renderTilesets() {
    const sel = root && root.querySelector('.pjc-tsselect');
    if (!sel) return;
    sel.innerHTML = '';
    const M = S.map;
    (M ? M.tilesets : []).forEach((ts, i) => sel.appendChild(h('option', { value: i, selected: i === S.tsIndex }, ts.name + (ts.tiles && [...ts.tiles.values()].some((x) => x.anim) ? '  ▶' : ''))));
    sel.disabled = !M;
    if (tsBox) { tsBox.scrollTop = 0; tsBox.scrollLeft = 0; }
    const tabs = root.querySelector('.pjc-tabs');
    if (tabs) [...tabs.children].forEach((b) => b.classList.toggle('on', b.dataset.tab === S.rightTab));
    if (tsBox) tsBox.style.display = S.rightTab === 'tiles' ? '' : 'none';
    const tl = root.querySelector('.pjc-terrains');
    if (tl) tl.style.display = S.rightTab === 'terrains' ? '' : 'none';
    const am = root.querySelector('.pjc-automap');
    if (am) am.style.display = S.rightTab === 'automap' ? '' : 'none';
    const head = root.querySelector('.pjc-tshead');
    if (head) head.style.display = S.rightTab === 'automap' ? 'none' : '';
    renderTerrains();
    renderAutomap();
    if (S.rightTab === 'automap' && M && !AM.loading) { AM.loading = true; refreshRulesList().catch(() => {}).then(() => { AM.loading = false; renderAutomap(); }); }
    renderAnimPanel();
  }
  function renderAnimPanel() {
    const box = root && root.querySelector('.pjc-anim');
    if (!box) return;
    if (S.tool === 'object') { renderObjPanel(); return; }
    box.innerHTML = '';
    animCanvas = null;
    const ts = curTs();
    if (!S.anim) {
      const s = S.tsSel;
      const single = ts && s && s.w === 1 && s.h === 1;
      let label = 'Sélectionne une tuile pour voir ou créer son animation.';
      if (single) { const L = tsLayout(); const id = s.y * L.cols + s.x; const info = ts.tiles.get(id); label = `Tuile ${id}` + (info && info.anim ? ` : animée (${info.anim.length} images)` : ' : fixe'); }
      box.appendChild(h('div', { class: 'pjc-animbar' }, h('span', { class: 'pjs-hint' }, label),
        h('button', { class: 'pjs-btn small', disabled: !single, onclick: startAnimEdit }, 'Animation…')));
      return;
    }
    const a = S.anim;
    animCanvas = makeCanvas(64, 64);
    animCanvas.className = 'pjc-animprev';
    const frames = h('div', { class: 'pjc-frames' });
    a.frames.forEach((f, i) => {
      const thumb = makeCanvas(32, 32);
      const tc = thumb.getContext('2d'); tc.imageSmoothingEnabled = false; drawLocal(tc, a.ts, f.id, 0, 0, 32, 32);
      frames.appendChild(h('div', { class: 'pjc-frame' }, thumb, h('span', { class: 'pjs-hint' }, '#' + f.id),
        h('input', { class: 'pjs-input pjc-dur', type: 'number', min: 1, value: f.dur, title: 'Durée (ms)', onchange: (e) => { f.dur = Math.max(1, +e.target.value || 100); } }),
        h('span', { class: 'pjs-hint' }, 'ms'),
        h('button', { class: 'pjc-mini', title: 'Monter', onclick: () => { if (i > 0) { [a.frames[i - 1], a.frames[i]] = [a.frames[i], a.frames[i - 1]]; renderAnimPanel(); } } }, '▲'),
        h('button', { class: 'pjc-mini', title: 'Retirer', onclick: () => { a.frames.splice(i, 1); renderAnimPanel(); } }, '✕')));
    });
    box.appendChild(h('div', { class: 'pjc-animhead' }, animCanvas, h('div', { class: 'pjc-animinfo' },
      h('b', null, `Animation de la tuile ${a.id}`),
      h('span', { class: 'pjs-hint' }, 'Clique des tuiles dans le tileset pour ajouter des images.'),
      h('label', { class: 'pjc-inline' }, 'Durée par défaut', h('input', { class: 'pjs-input pjc-dur', type: 'number', min: 1, value: a.defaultDur, onchange: (e) => { a.defaultDur = Math.max(1, +e.target.value || 100); } }), 'ms'))));
    box.appendChild(frames.childNodes.length ? frames : h('div', { class: 'pjs-hint pjc-empty' }, 'Aucune image : la tuile n’est pas animée.'));
    box.appendChild(h('div', { class: 'pjc-btnrow' },
      h('button', { class: 'pjs-btn small', onclick: () => { a.frames.forEach((f) => { f.dur = a.defaultDur; }); renderAnimPanel(); } }, 'Même durée partout'),
      h('button', { class: 'pjs-btn small', onclick: () => { a.frames = []; renderAnimPanel(); } }, 'Tout retirer'),
      h('button', { class: 'pjs-btn small', onclick: () => { S.anim = null; renderAnimPanel(); } }, 'Annuler'),
      h('button', { class: 'pjs-btn primary small', onclick: saveAnim }, 'Enregistrer')));
  }
  function renderStatus() {
    const info = root && root.querySelector('.pjc-info');
    const M = S.map;
    if (info) {
      const l = activeLayer();
      let cellTxt = '';
      if (M && S.cursor && l && l.kind === 'tile') {
        const g = l.data[S.cursor[1] * l.w + S.cursor[0]] & GID_MASK;
        const ts = g ? tilesetOf(g) : null;
        cellTxt = `   ·   case ${S.cursor[0] + (M.inf ? M.inf.ox : 0)}, ${S.cursor[1] + (M.inf ? M.inf.oy : 0)}` + (g ? `   ·   ${ts ? ts.name : '?'} #${g - (ts ? ts.firstgid : 0)}${isAnimated(g) ? ' (animée)' : ''}` : '');
      }
      info.textContent = M ? `${M.w} × ${M.h} cases de ${M.tw} px   ·   zoom ${Math.round(S.zoom * 100)} %   ·   calque : ${l ? l.name : '—'}${cellTxt}` + (S.selection ? `   ·   sélection ${S.selection.w} × ${S.selection.h}` : '') : (S.loading || '');
    }
    const t = root && root.querySelector('.pjc-doc');
    if (t) {
      const wm = S.worldMap;
      const known = M && S.ctx && (S.ctx.maps || []).find((m) => m.path === M.file);
      t.textContent = M ? (known ? known.name + ' — ' : '') + M.file.replace(/^Maps\//, '') + (M.dirty ? ' •' : '') : S.loading || (wm ? '' : 'Aucune carte choisie');
    }
  }
  function renderAll() {
    renderMaps(); renderLayers(); renderLayerBar(); renderTools(); renderTilesets(); renderStatus(); needDraw = true;
    const w = root && root.querySelector('.pjc-welcome');
    if (w) { w.style.display = S.map ? 'none' : ''; w.querySelector('.pjc-welcome-text').textContent = S.loading || 'Choisis une carte dans l’arbre du Monde, à gauche.'; }
  }
  function render() {
    if (!root) return;
    root.innerHTML = '';
    view = h('canvas', { class: 'pjc-view', tabindex: 0, onmousedown: onDown, onmousemove: (e) => { if (!drag) onMove(e); }, onwheel: onWheel, oncontextmenu: (e) => e.preventDefault(),
      onmouseleave: () => { S.cursor = null; needDraw = true; } });
    vctx = view.getContext('2d');
    tsCanvas = h('canvas', { class: 'pjc-tscanvas' });
    tsSpacer = h('div', { class: 'pjc-tsspacer' });
    tsBox = h('div', { class: 'pjc-tsbox', onmousedown: tsDown, onscroll: () => drawTileset(performance.now()) }, tsSpacer, tsCanvas);
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' }, h('span', { class: 'pjs-top-sub pjc-doc' })),
      h('div', { class: 'pjs-topbar-right' }, h('span', { class: 'pjs-status pjc-msg' }),
        h('button', { class: 'pjs-btn small', title: 'Annuler (Ctrl+Z)', onclick: undo }, '↶'),
        h('button', { class: 'pjs-btn small', title: 'Rétablir (Ctrl+Y)', onclick: redo }, '↷'),
        h('button', { class: 'pjs-btn small', title: 'Adapter à la fenêtre (0)', onclick: () => { fit(); needDraw = true; renderStatus(); } }, 'Ajuster'),
        h('button', { class: 'pjs-btn small', title: 'Changer la taille de la carte', onclick: resizeMap }, 'Taille…'),
        h('button', { class: 'pjs-btn small', title: 'Créer une carte', onclick: newMap }, 'Nouvelle carte'),
        h('button', { class: 'pjs-btn primary small', title: 'Ctrl+S', onclick: save }, 'Enregistrer'))));
    root.appendChild(h('div', { class: 'pjc-body' },
      h('div', { class: 'pjc-left' },
        h('div', { class: 'pjc-panel pjc-layerspanel' }, h('div', { class: 'pjc-title' }, 'Calques'), h('div', { class: 'pjc-layerbar' }), h('div', { class: 'pjc-layers' }))),
      h('div', { class: 'pjc-tools' }),
      h('div', { class: 'pjc-center' }, h('div', { class: 'pjc-viewport' }, view,
        h('div', { class: 'pjc-welcome' }, h('div', { class: 'pjc-welcome-title' }, 'Cartes'), h('div', { class: 'pjs-hint pjc-welcome-text' }))),
      h('div', { class: 'pjc-info' })),
      h('div', { class: 'pjc-right' },
        h('div', { class: 'pjc-panel pjc-tspanel' },
          h('div', { class: 'pjc-tabs' },
            h('button', { class: 'pjc-tab', 'data-tab': 'tiles', onclick: () => { S.rightTab = 'tiles'; renderTilesets(); } }, 'Tuiles'),
            h('button', { class: 'pjc-tab', 'data-tab': 'terrains', onclick: () => { S.rightTab = 'terrains'; renderTilesets(); } }, 'Terrains'),
            h('button', { class: 'pjc-tab', 'data-tab': 'automap', title: 'Automapping (Ctrl+M : appliquer)', onclick: () => { S.rightTab = 'automap'; renderTilesets(); } }, 'Automapping')),
          h('div', { class: 'pjc-tshead' },
            h('select', { class: 'pjs-input pjc-tsselect', onchange: (e) => { S.tsIndex = +e.target.value; S.tsSel = null; S.anim = null; if (S.map) store.set('ts.' + S.map.file, S.tsIndex); renderTilesets(); } }),
            h('button', { class: 'pjc-mini big', title: 'Ajouter un tileset à la carte', onclick: addTileset }, '+'),
            h('select', { class: 'pjs-input pjc-tszoom', title: 'Zoom du tileset', onchange: (e) => { S.tsZoom = +e.target.value; store.set('tsZoom', S.tsZoom); } },
              [0.5, 1, 1.5, 2].map((z) => h('option', { value: z, selected: z === S.tsZoom }, Math.round(z * 100) + ' %')))),
          tsBox, h('div', { class: 'pjc-terrains' }), h('div', { class: 'pjc-automap' })),
        h('div', { class: 'pjc-panel pjc-anim' }))));
    renderAll();
    requestAnimationFrame(() => { if (S.map && !S.viewed) { fit(); S.viewed = true; } needDraw = true; });
  }
  const resizeObs = new ResizeObserver(() => { needDraw = true; });

  // ---------------------------------------------------------------------------
  // Page « Monde > carte > Éditeur » (/world/editor) : la carte choisie dans l'arbre de Studio s'ouvre ici
  // ---------------------------------------------------------------------------
  const PAGE_ID = 'cartes';
  if (!(window.pjPluginPages = window.pjPluginPages || []).some((p) => p.id === PAGE_ID)) window.pjPluginPages.push({ id: PAGE_ID, label: 'Cartes', place: 'world' });
  window.dispatchEvent(new Event('pj-plugin-pages'));

  async function loadContext() {
    S.projectPath = currentProject();
    try { S.ctx = await call('getContext', { projectPath: S.projectPath }); } catch (e) { S.ctx = null; flash(e.message, true); }
  }
  // carte de Studio choisie (arbre du Monde) -> son fichier Tiled
  async function followWorldMap() {
    const wm = window.pjWorldMap;
    S.worldMap = wm || null;
    if (!root) return;
    if (!wm) { renderAll(); return; }
    if (!wm.tiledFilename) {
      if (S.map && !(await confirmDiscard())) return;
      S.map = null; S.loading = 'Cette carte n’a pas encore de fichier Tiled (onglet Données de Studio).'; renderAll(); return;
    }
    const file = 'Maps/' + wm.tiledFilename + '.tmx';
    if (S.map && S.map.file === file) return;
    await openMap(file);
  }
  window.addEventListener('pj-world-map', () => { followWorldMap(); });
  async function mount(hostEl) {
    root = h('div', { id: 'pjc-root' });
    ['keydown', 'keypress', 'keyup'].forEach((type) => root.addEventListener(type, (e) => e.stopPropagation()));
    hostEl.appendChild(root);
    if (currentProject() !== S.projectPath || !S.ctx) {
      if (S.projectPath && currentProject() !== S.projectPath) { S.map = null; imageCache.clear(); }
      await loadContext();
    }
    render();
    const vp = root.querySelector('.pjc-viewport');
    if (vp) resizeObs.observe(vp);
    followWorldMap();
  }
  function checkPage() {
    const hostEl = document.getElementById('pj-page-' + PAGE_ID);
    if (root && hostEl && hostEl.contains(root)) return;
    if (root) { root = null; view = null; vctx = null; tsBox = null; tsCanvas = null; resizeObs.disconnect(); }
    if (hostEl) mount(hostEl);
  }
  let scheduled = false;
  const observer = new MutationObserver(() => { if (!scheduled) { scheduled = true; requestAnimationFrame(() => { scheduled = false; checkPage(); }); } });
  const start = () => { observer.observe(document.body, { childList: true, subtree: true }); checkPage(); };
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);

  // Aperçu d'une carte (Data/Tiled/Overviews/<carte>.png) quand Tiled n'est pas installé : même rendu que tmxrasterizer
  // (calques visibles, sans passages / systemtags / terrain_tag)
  const OVERVIEW_HIDDEN = ['passages', 'systemtags', 'systemtags_bridge1', 'systemtags_bridge2', 'terrain_tag'];
  async function renderOverview(tiledFilename) {
    if (!S.projectPath || S.projectPath !== currentProject()) { S.projectPath = currentProject(); S.ctx = null; }
    const name = String(tiledFilename || '').replace(/\\/g, '/').split('/').pop().replace(/\.tmx$/i, '');
    if (!name) throw new Error('Carte Tiled inconnue');
    const M = await loadMap('Maps/' + name + '.tmx');
    const canvas = document.createElement('canvas');
    canvas.width = M.w * M.tw; canvas.height = M.h * M.th;
    const c = canvas.getContext('2d');
    c.imageSmoothingEnabled = false;
    const keep = S.map;
    S.map = M; // drawGid lit les tilesets de S.map (dessin synchrone, rien ne s'intercale)
    try {
      for (const l of M.layers) {
        if (l.kind !== 'tile' || !l.visible || !l.parentVisible || l.opacity <= 0 || OVERVIEW_HIDDEN.includes(l.name)) continue;
        c.globalAlpha = l.opacity;
        for (let y = 0; y < l.h; y++) for (let x = 0; x < l.w; x++) { const g = l.data[y * l.w + x]; if (g) drawGid(c, g, x * M.tw, (y + 1) * M.th, 1, 0); }
      }
    } finally { S.map = keep; }
    await call('writeOverview', { projectPath: S.projectPath, name, dataUrl: canvas.toDataURL('image/png') });
    return {};
  }
  window.pjCartesOverview = renderOverview;
  window.pjCartesEditor = { state: S, render, save };
})();
