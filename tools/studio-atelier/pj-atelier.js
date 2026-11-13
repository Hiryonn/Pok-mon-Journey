/* eslint-disable */
// =============================================================================
// Atelier — éditeur de pixel art de Pokémon Studio Extra (section « Atelier » de la barre de gauche)
//   Graphismes du projet (dossier graphics) uniquement : ouverture, création, enregistrement en PNG
//   Outils : crayon, gomme, pot de peinture, pipette, ligne, rectangle, ellipse, sélection, déplacement, main
//   Calques (visibilité, opacité, ordre, fusion), palette, annuler / rétablir, zoom, grilles, symétrie,
//   retourner / pivoter / redimensionner, copier / coller (presse-papiers de Windows compris)
// Style de l'éditeur Smartphone (classes pjs-*).
// =============================================================================
(() => {
  'use strict';
  if (window.__pjAtelierLoaded) return;
  window.__pjAtelierLoaded = true;

  const api = window.pjAtelier;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API de l'atelier n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
    get(key, def) { try { const v = localStorage.getItem('pjAtelier.' + key); return v === null ? def : JSON.parse(v); } catch (e) { return def; } },
    set(key, v) { try { localStorage.setItem('pjAtelier.' + key, JSON.stringify(v)); } catch (e) { /* rien */ } },
  };
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  // ---------------------------------------------------------------------------
  // Couleurs
  // ---------------------------------------------------------------------------
  // palette de départ (DB32)
  const DEFAULT_PALETTE = ['#000000', '#222034', '#45283c', '#663931', '#8f563b', '#df7126', '#d9a066', '#eec39a', '#fbf236', '#99e550', '#6abe30',
    '#37946e', '#4b692f', '#524b24', '#323c39', '#3f3f74', '#306082', '#5b6ee1', '#639bff', '#5fcde4', '#cbdbfc', '#ffffff', '#9badb7', '#847e87',
    '#696a6a', '#595652', '#76428a', '#ac3232', '#d95763', '#d77bba', '#8f974a', '#8a6f30'];
  const hex2 = (n) => n.toString(16).padStart(2, '0');
  const toHex = (c) => '#' + hex2(c[0]) + hex2(c[1]) + hex2(c[2]);
  const fromHex = (s, a = 255) => { const m = /^#?([0-9a-f]{6})$/i.exec(s || ''); if (!m) return [0, 0, 0, a]; const n = parseInt(m[1], 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255, a]; };
  const css = (c) => `rgba(${c[0]},${c[1]},${c[2]},${(c[3] / 255).toFixed(3)})`;
  const sameColor = (d, i, c) => d[i] === c[0] && d[i + 1] === c[1] && d[i + 2] === c[2] && d[i + 3] === c[3];

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const TOOLS = [
    ['pencil', 'Crayon', 'B', 'M3 21l3.75-1L19 7.75 16.25 5 4 17.25zM20.7 6.04a1 1 0 000-1.41l-1.33-1.33a1 1 0 00-1.41 0l-1.04 1.04 2.75 2.75z'],
    ['eraser', 'Gomme', 'E', 'M16.24 3.56l4.95 4.94c.78.79.78 2.05 0 2.84L12 20.53a4 4 0 01-5.66 0L2.81 17c-.78-.79-.78-2.05 0-2.84l10.6-10.6c.79-.78 2.05-.78 2.83 0M4.22 15.58l3.54 3.53c.78.79 2.04.79 2.83 0l3.53-3.53-4.95-4.95z'],
    ['bucket', 'Pot de peinture (Maj : toutes les zones de cette couleur)', 'G', 'M19 11.5s-2 2.17-2 3.5a2 2 0 004 0c0-1.33-2-3.5-2-3.5M5.21 10L10 5.21 14.79 10M16.56 8.94L7.62 0 6.21 1.41l2.38 2.38-5.15 5.15c-.59.56-.59 1.53 0 2.12l5.5 5.5c.29.29.68.44 1.06.44s.77-.15 1.06-.44l5.5-5.5c.59-.59.59-1.56 0-2.12z'],
    ['picker', 'Pipette', 'I', 'M19.35 11.72l-2.13 2.13-1.41-1.42-7.71 7.71L3.5 22 2 20.5l1.86-4.6 7.71-7.71-1.42-1.41 2.13-2.13 1.42 1.41L17.06 2.7a1 1 0 011.41 0l2.83 2.83a1 1 0 010 1.41l-3.36 3.36zM5.59 18.4l1.06.46 7.04-7.04-1.51-1.51-7.04 7.04z'],
    ['line', 'Ligne (Maj : angles droits)', 'L', 'M4.22 18.36L18.36 4.22l1.42 1.42L5.64 19.78z'],
    ['rect', 'Rectangle (Maj : carré)', 'U', 'M3 3h18v18H3zm2 2v14h14V5z'],
    ['ellipse', 'Ellipse (Maj : cercle)', 'O', 'M12 4c4.42 0 8 3.58 8 8s-3.58 8-8 8-8-3.58-8-8 3.58-8 8-8m0-2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2z'],
    ['select', 'Sélection (glisser dedans pour déplacer)', 'M', 'M3 3h2v2H3zm4 0h2v2H7zm4 0h2v2h-2zm4 0h2v2h-2zm4 0h2v2h-2zm0 4h2v2h-2zM3 7h2v2H3zm0 4h2v2H3zm0 4h2v2H3zm0 4h2v2H3zm4 0h2v2H7zm4 0h2v2h-2zm4 0h2v2h-2zm4 0h2v2h-2zm0-4h2v2h-2zm0-4h2v2h-2z'],
    ['move', 'Déplacer le calque', 'V', 'M10 9h4V6h3l-5-5-5 5h3zm-1 1H6V7l-5 5 5 5v-3h3zm14 2l-5-5v3h-3v4h3v3zm-9 3h-4v3H7l5 5 5-5h-3z'],
    ['hand', 'Main (ou Espace / clic molette)', 'H', 'M13 6v5h1V2.5a1.5 1.5 0 013 0V11h1V5.5a1.5 1.5 0 013 0V16c0 3.31-2.69 6-6 6h-1.5c-1.95 0-3.68-.94-4.78-2.38L3.3 13.7a1.5 1.5 0 012.32-1.9L8 14V4.5a1.5 1.5 0 013 0V11h1V3a1.5 1.5 0 013 0'],
  ];
  const S = {
    projectPath: null, ctx: null, search: '', openDirs: new Set(store.get('openDirs', [])),
    doc: null, tool: 'pencil', primary: [0, 0, 0, 255], secondary: [255, 255, 255, 0], brush: 1, filled: false,
    mirror: false, grid: store.get('grid', true), tile: store.get('tile', { on: false, w: 16, h: 16 }), palette: store.get('palette', DEFAULT_PALETTE),
    zoom: 8, ox: 0, oy: 0, cursor: null, status: '', error: '', clipboard: null,
  };
  let root = null;
  let view = null; // canvas d'affichage
  let vctx = null;

  // Document : calques (canvas) + sélection + historique
  function makeCanvas(w, h) { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; }
  function newDoc(w, h, file) {
    const doc = { w, h, file: file || null, dirty: false, layers: [], active: 0, selection: null, floating: null, undo: [], redo: [] };
    doc.layers.push(newLayer(doc, 'Calque 1'));
    return doc;
  }
  function newLayer(doc, name) {
    const c = makeCanvas(doc.w, doc.h);
    return { name, canvas: c, ctx: c.getContext('2d', { willReadFrequently: true }), visible: true, opacity: 255 };
  }
  const layer = () => S.doc.layers[S.doc.active];

  // Historique : copie complète (les images du jeu restent petites)
  function snapshot() {
    const d = S.doc;
    return { w: d.w, h: d.h, active: d.active, layers: d.layers.map((l) => ({ name: l.name, visible: l.visible, opacity: l.opacity, data: l.ctx.getImageData(0, 0, d.w, d.h) })) };
  }
  function restore(snap) {
    const d = S.doc;
    d.w = snap.w; d.h = snap.h;
    d.layers = snap.layers.map((s) => { const l = newLayer(d, s.name); l.visible = s.visible; l.opacity = s.opacity; l.ctx.putImageData(s.data, 0, 0); return l; });
    d.active = clamp(snap.active, 0, d.layers.length - 1);
    d.selection = null; d.floating = null;
  }
  function pushUndo() {
    const d = S.doc;
    d.undo.push(snapshot());
    if (d.undo.length > 80) d.undo.shift();
    d.redo = [];
    d.dirty = true;
  }
  function undo() { const d = S.doc; if (!d) return; commitFloating(); if (!d.undo.length) return; d.redo.push(snapshot()); restore(d.undo.pop()); d.dirty = true; refreshAll(); }
  function redo() { const d = S.doc; if (!d || !d.redo.length) return; d.undo.push(snapshot()); restore(d.redo.pop()); d.dirty = true; refreshAll(); }

  // ---------------------------------------------------------------------------
  // Dessin
  // ---------------------------------------------------------------------------
  function inSelection(x, y) {
    const s = S.doc.selection;
    return !s || S.doc.floating || (x >= s.x && y >= s.y && x < s.x + s.w && y < s.y + s.h);
  }
  function plot(ctx, x, y, color, erase) {
    const d = S.doc;
    const size = S.brush;
    const off = Math.floor((size - 1) / 2);
    const pts = [[x, y]];
    if (S.mirror) pts.push([d.w - 1 - x, y]);
    for (const [px, py] of pts) {
      for (let j = 0; j < size; j++) {
        for (let i = 0; i < size; i++) {
          const ax = px - off + i;
          const ay = py - off + j;
          if (ax < 0 || ay < 0 || ax >= d.w || ay >= d.h || !inSelection(ax, ay)) continue;
          ctx.clearRect(ax, ay, 1, 1);
          if (!erase && color[3] > 0) { ctx.fillStyle = css(color); ctx.fillRect(ax, ay, 1, 1); }
        }
      }
    }
  }
  function linePoints(x0, y0, x1, y1) {
    const pts = [];
    const dx = Math.abs(x1 - x0); const dy = -Math.abs(y1 - y0);
    const sx = x0 < x1 ? 1 : -1; const sy = y0 < y1 ? 1 : -1;
    let err = dx + dy;
    for (;;) {
      pts.push([x0, y0]);
      if (x0 === x1 && y0 === y1) break;
      const e2 = 2 * err;
      if (e2 >= dy) { err += dy; x0 += sx; }
      if (e2 <= dx) { err += dx; y0 += sy; }
    }
    return pts;
  }
  function rectPoints(x0, y0, x1, y1, filled) {
    const pts = [];
    const ax = Math.min(x0, x1); const bx = Math.max(x0, x1); const ay = Math.min(y0, y1); const by = Math.max(y0, y1);
    for (let y = ay; y <= by; y++) {
      for (let x = ax; x <= bx; x++) if (filled || x === ax || x === bx || y === ay || y === by) pts.push([x, y]);
    }
    return pts;
  }
  function ellipsePoints(x0, y0, x1, y1, filled) {
    const ax = Math.min(x0, x1); const bx = Math.max(x0, x1); const ay = Math.min(y0, y1); const by = Math.max(y0, y1);
    const cx = (ax + bx) / 2; const cy = (ay + by) / 2; const rx = (bx - ax) / 2 + 0.5; const ry = (by - ay) / 2 + 0.5;
    const inside = (x, y) => ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1;
    const pts = [];
    for (let y = ay; y <= by; y++) {
      for (let x = ax; x <= bx; x++) {
        if (!inside(x, y)) continue;
        if (filled || !inside(x - 1, y) || !inside(x + 1, y) || !inside(x, y - 1) || !inside(x, y + 1)) pts.push([x, y]);
      }
    }
    return pts;
  }
  function constrain(x0, y0, x1, y1, tool) {
    if (tool === 'line') {
      const dx = x1 - x0; const dy = y1 - y0;
      const ang = Math.round(Math.atan2(dy, dx) / (Math.PI / 4)) * (Math.PI / 4);
      const len = Math.max(Math.abs(dx), Math.abs(dy));
      return [x0 + Math.round(Math.cos(ang) * len), y0 + Math.round(Math.sin(ang) * len)];
    }
    const s = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0));
    return [x0 + Math.sign(x1 - x0 || 1) * s, y0 + Math.sign(y1 - y0 || 1) * s];
  }
  function shapePoints(tool, a, b, shift) {
    let [x1, y1] = b;
    if (shift) [x1, y1] = constrain(a[0], a[1], x1, y1, tool);
    if (tool === 'line') return linePoints(a[0], a[1], x1, y1);
    if (tool === 'rect') return rectPoints(a[0], a[1], x1, y1, S.filled);
    return ellipsePoints(a[0], a[1], x1, y1, S.filled);
  }
  function floodFill(x, y, color, global) {
    const d = S.doc;
    const l = layer();
    const img = l.ctx.getImageData(0, 0, d.w, d.h);
    const data = img.data;
    const i0 = (y * d.w + x) * 4;
    const target = [data[i0], data[i0 + 1], data[i0 + 2], data[i0 + 3]];
    const fill = color;
    if (target.every((v, i) => v === fill[i])) return false;
    const set = (i) => { data[i] = fill[0]; data[i + 1] = fill[1]; data[i + 2] = fill[2]; data[i + 3] = fill[3]; };
    const ok = (px, py) => inSelection(px, py);
    if (global) {
      for (let py = 0; py < d.h; py++) for (let px = 0; px < d.w; px++) { const i = (py * d.w + px) * 4; if (sameColor(data, i, target) && ok(px, py)) set(i); }
    } else {
      const stack = [[x, y]];
      const seen = new Uint8Array(d.w * d.h);
      while (stack.length) {
        const [px, py] = stack.pop();
        if (px < 0 || py < 0 || px >= d.w || py >= d.h) continue;
        const k = py * d.w + px;
        if (seen[k]) continue;
        seen[k] = 1;
        const i = k * 4;
        if (!sameColor(data, i, target) || !ok(px, py)) continue;
        set(i);
        stack.push([px + 1, py], [px - 1, py], [px, py + 1], [px, py - 1]);
      }
    }
    l.ctx.putImageData(img, 0, 0);
    return true;
  }
  // couleur visible (tous les calques) ou du calque actif
  function pickColor(x, y) {
    const flat = flatten();
    const p = flat.getContext('2d').getImageData(x, y, 1, 1).data;
    return [p[0], p[1], p[2], p[3]];
  }
  function flatten() {
    const d = S.doc;
    const out = makeCanvas(d.w, d.h);
    const c = out.getContext('2d');
    d.layers.forEach((l) => {
      if (!l.visible) return;
      c.globalAlpha = l.opacity / 255;
      c.drawImage(l.canvas, 0, 0);
      if (d.floating && l === layer()) c.drawImage(d.floating.canvas, d.floating.x, d.floating.y);
    });
    c.globalAlpha = 1;
    return out;
  }

  // Sélection flottante (déplacée)
  function liftSelection() {
    const d = S.doc;
    const s = d.selection;
    if (!s || d.floating) return;
    pushUndo();
    const c = makeCanvas(s.w, s.h);
    c.getContext('2d').drawImage(layer().canvas, s.x, s.y, s.w, s.h, 0, 0, s.w, s.h);
    layer().ctx.clearRect(s.x, s.y, s.w, s.h);
    d.floating = { canvas: c, x: s.x, y: s.y };
  }
  function commitFloating() {
    const d = S.doc;
    if (!d || !d.floating) return;
    layer().ctx.drawImage(d.floating.canvas, d.floating.x, d.floating.y);
    d.selection = { x: d.floating.x, y: d.floating.y, w: d.floating.canvas.width, h: d.floating.canvas.height };
    d.floating = null;
    d.dirty = true;
  }
  function selectionCanvas() {
    const d = S.doc;
    if (d.floating) { const c = makeCanvas(d.floating.canvas.width, d.floating.canvas.height); c.getContext('2d').drawImage(d.floating.canvas, 0, 0); return c; }
    const s = d.selection || { x: 0, y: 0, w: d.w, h: d.h };
    const c = makeCanvas(s.w, s.h);
    c.getContext('2d').drawImage(layer().canvas, s.x, s.y, s.w, s.h, 0, 0, s.w, s.h);
    return c;
  }
  async function copy(cut) {
    if (!S.doc) return;
    const c = selectionCanvas();
    S.clipboard = c;
    try {
      const blob = await new Promise((r) => c.toBlob(r, 'image/png'));
      if (navigator.clipboard && window.ClipboardItem) await navigator.clipboard.write([new ClipboardItem({ 'image/png': blob })]);
    } catch (e) { /* presse-papiers interne seulement */ }
    if (cut) {
      pushUndo();
      if (S.doc.floating) S.doc.floating = null;
      else { const s = S.doc.selection || { x: 0, y: 0, w: S.doc.w, h: S.doc.h }; layer().ctx.clearRect(s.x, s.y, s.w, s.h); }
      S.doc.selection = null;
      refreshAll();
    }
    flash(cut ? 'Coupé.' : 'Copié.');
  }
  async function paste() {
    if (!S.doc) return;
    let src = null;
    try {
      if (navigator.clipboard && navigator.clipboard.read) {
        const items = await navigator.clipboard.read();
        for (const it of items) {
          const type = it.types.find((t) => t.startsWith('image/'));
          if (type) { const bmp = await createImageBitmap(await it.getType(type)); src = makeCanvas(bmp.width, bmp.height); src.getContext('2d').drawImage(bmp, 0, 0); break; }
        }
      }
    } catch (e) { /* presse-papiers interne */ }
    src = src || S.clipboard;
    if (!src) return;
    commitFloating();
    pushUndo();
    const v = visibleCenter();
    const x = clamp(Math.round(v[0] - src.width / 2), 0, Math.max(0, S.doc.w - src.width));
    const y = clamp(Math.round(v[1] - src.height / 2), 0, Math.max(0, S.doc.h - src.height));
    const c = makeCanvas(src.width, src.height);
    c.getContext('2d').drawImage(src, 0, 0);
    S.doc.floating = { canvas: c, x, y };
    S.doc.selection = { x, y, w: c.width, h: c.height };
    setTool('select');
    refreshAll();
  }
  function clearSelection() {
    const d = S.doc;
    if (!d) return;
    if (d.floating) { d.floating = null; d.selection = null; refreshAll(); return; }
    pushUndo();
    const s = d.selection || { x: 0, y: 0, w: d.w, h: d.h };
    layer().ctx.clearRect(s.x, s.y, s.w, s.h);
    refreshAll();
  }

  // ---------------------------------------------------------------------------
  // Opérations sur l'image
  // ---------------------------------------------------------------------------
  function transformAll(w, h, draw) {
    commitFloating();
    pushUndo();
    const d = S.doc;
    d.layers.forEach((l) => {
      const c = makeCanvas(w, h);
      const ctx = c.getContext('2d', { willReadFrequently: true });
      ctx.imageSmoothingEnabled = false;
      draw(ctx, l.canvas);
      l.canvas = c; l.ctx = ctx;
    });
    d.w = w; d.h = h; d.selection = null;
    refreshAll();
  }
  const flipH = () => transformAll(S.doc.w, S.doc.h, (c, src) => { c.translate(S.doc.w, 0); c.scale(-1, 1); c.drawImage(src, 0, 0); });
  const flipV = () => transformAll(S.doc.w, S.doc.h, (c, src) => { c.translate(0, S.doc.h); c.scale(1, -1); c.drawImage(src, 0, 0); });
  const rotate = (dir) => { const { w, h } = S.doc; transformAll(h, w, (c, src) => { c.translate(h / 2, w / 2); c.rotate(dir * Math.PI / 2); c.drawImage(src, -w / 2, -h / 2); }); };
  function resizeCanvas(w, h, anchorX, anchorY, scale) {
    const d = S.doc;
    const ox = Math.round((w - d.w) * anchorX); const oy = Math.round((h - d.h) * anchorY);
    transformAll(w, h, (c, src) => { if (scale) c.drawImage(src, 0, 0, d.w, d.h, 0, 0, w, h); else c.drawImage(src, ox, oy); });
    fit();
  }
  function cropToSelection() {
    const s = S.doc.selection;
    if (!s) return;
    transformAll(s.w, s.h, (c, src) => c.drawImage(src, -s.x, -s.y));
    fit();
  }

  // Calques
  function addLayer() { commitFloating(); pushUndo(); const d = S.doc; d.layers.splice(d.active + 1, 0, newLayer(d, 'Calque ' + (d.layers.length + 1))); d.active += 1; refreshAll(); }
  function duplicateLayer() { commitFloating(); pushUndo(); const d = S.doc; const src = layer(); const l = newLayer(d, src.name + ' (copie)'); l.ctx.drawImage(src.canvas, 0, 0); l.opacity = src.opacity; d.layers.splice(d.active + 1, 0, l); d.active += 1; refreshAll(); }
  function deleteLayer() { const d = S.doc; if (d.layers.length < 2) return; commitFloating(); pushUndo(); d.layers.splice(d.active, 1); d.active = clamp(d.active - 1, 0, d.layers.length - 1); refreshAll(); }
  function moveLayer(dir) { const d = S.doc; const j = d.active + dir; if (j < 0 || j >= d.layers.length) return; commitFloating(); pushUndo(); [d.layers[d.active], d.layers[j]] = [d.layers[j], d.layers[d.active]]; d.active = j; refreshAll(); }
  function mergeDown() {
    const d = S.doc;
    if (d.active === 0) return;
    commitFloating(); pushUndo();
    const top = layer(); const below = d.layers[d.active - 1];
    if (top.visible) { below.ctx.globalAlpha = top.opacity / 255; below.ctx.drawImage(top.canvas, 0, 0); below.ctx.globalAlpha = 1; }
    d.layers.splice(d.active, 1); d.active -= 1; refreshAll();
  }

  // ---------------------------------------------------------------------------
  // Fichiers (dossier graphics du projet)
  // ---------------------------------------------------------------------------
  async function loadContext() {
    S.projectPath = currentProject();
    try { S.ctx = await call('getContext', { projectPath: S.projectPath }); S.error = ''; } catch (e) { S.ctx = null; S.error = e.message; }
  }
  function loadImage(url) {
    return new Promise((resolve, reject) => { const img = new Image(); img.onload = () => resolve(img); img.onerror = () => reject(new Error("Image illisible.")); img.src = url; });
  }
  async function openFile(file) {
    if (S.doc && S.doc.file === file) return;
    if (!(await confirmDiscard())) return;
    try {
      const img = await loadImage(await call('read', { projectPath: S.projectPath, file }));
      const doc = newDoc(img.naturalWidth, img.naturalHeight, file);
      doc.layers[0].name = 'Image';
      doc.layers[0].ctx.drawImage(img, 0, 0);
      S.doc = doc;
      fit();
      extractIfEmpty();
      refreshAll();
      flash('Ouvert : graphics/' + file);
    } catch (e) { flash(e.message, true); }
  }
  async function save(as) {
    const d = S.doc;
    if (!d) return;
    commitFloating();
    let file = d.file;
    if (as || !file || !/\.png$/i.test(file)) {
      file = await askSavePath(file);
      if (!file) return;
      if (await call('exists', { projectPath: S.projectPath, file }) && file !== d.file && !(await confirmBox('Remplacer graphics/' + file + ' ?', 'Remplacer'))) return;
    }
    if (d.layers.length > 1 && !store.get('warnedLayers', false)) {
      store.set('warnedLayers', true);
      flash('Les calques sont fusionnés dans le PNG (ils restent séparés tant que l’image est ouverte).');
    }
    try {
      await call('write', { projectPath: S.projectPath, file, dataUrl: flatten().toDataURL('image/png') });
      d.file = file;
      d.dirty = false;
      await loadContext();
      refreshAll();
      flash('Enregistré : graphics/' + file);
    } catch (e) { flash(e.message, true); }
  }

  // ---------------------------------------------------------------------------
  // Fenêtres (nouveau, enregistrer sous, taille, confirmation)
  // ---------------------------------------------------------------------------
  function modal(title, body, buttons) {
    return new Promise((resolve) => {
      const close = (v) => { ov.remove(); resolve(v); };
      const ov = h('div', { class: 'pja-overlay', onmousedown: (e) => { if (e.target === ov) close(null); } },
        h('div', { class: 'pja-modal' }, h('h3', null, title), body,
          h('div', { class: 'pja-modal-actions' }, buttons.map(([v, label, primary]) => h('button', { class: 'pjs-btn' + (primary ? ' primary' : ''), onclick: () => close(typeof v === 'function' ? v() : v) }, label)))));
      ov.addEventListener('keydown', (e) => { e.stopPropagation(); if (e.key === 'Escape') close(null); if (e.key === 'Enter') { const p = buttons.find((b) => b[2]); if (p) close(typeof p[0] === 'function' ? p[0]() : p[0]); } });
      root.appendChild(ov);
      const first = ov.querySelector('input'); if (first) { first.focus(); first.select && first.select(); }
    });
  }
  const confirmBox = (text, ok) => modal(text, null, [[false, 'Annuler'], [true, ok || 'Continuer', true]]);
  async function confirmDiscard() {
    if (!S.doc || !S.doc.dirty) return true;
    const r = await modal('Modifications non enregistrées', h('p', { class: 'pjs-hint' }, (S.doc.file ? 'graphics/' + S.doc.file : 'Nouvelle image') + ' a été modifiée.'),
      [[null, 'Annuler'], ['discard', 'Ne pas enregistrer'], ['save', 'Enregistrer', true]]);
    if (r === 'save') { await save(false); return !S.doc.dirty; }
    return r === 'discard';
  }
  function folders(nodes, out = ['']) { for (const n of nodes || []) if (n.dir) { out.push(n.path); folders(n.children, out); } return out; }
  async function askSavePath(current) {
    const parts = (current || '').split('/');
    const name = h('input', { class: 'pjs-input', value: (parts.pop() || 'nouvelle_image').replace(/\.[^.]+$/, '') });
    const dir = h('select', { class: 'pjs-input' }, folders(S.ctx && S.ctx.tree).map((f) => h('option', { value: f, selected: f === parts.join('/') }, 'graphics/' + f)));
    const sub = h('input', { class: 'pjs-input', placeholder: 'sous-dossier (facultatif)' });
    const r = await modal('Enregistrer sous', h('div', { class: 'pja-form' }, h('label', null, 'Dossier', dir), h('label', null, 'Nouveau sous-dossier', sub), h('label', null, 'Nom (.png)', name)),
      [[null, 'Annuler'], [() => ({ dir: dir.value, sub: sub.value.trim(), name: name.value.trim() }), 'Enregistrer', true]]);
    if (!r || !r.name) return null;
    const clean = (s) => s.replace(/[<>:"|?*\\]/g, '').replace(/^\/+|\/+$/g, '').replace(/\.\.+/g, '');
    return [r.dir, clean(r.sub), clean(r.name).replace(/\.png$/i, '') + '.png'].filter(Boolean).join('/');
  }
  async function newImage() {
    if (!(await confirmDiscard())) return;
    const last = store.get('newSize', { w: 64, h: 64 });
    const w = h('input', { class: 'pjs-input', type: 'number', min: 1, max: 4096, value: last.w });
    const hh = h('input', { class: 'pjs-input', type: 'number', min: 1, max: 4096, value: last.h });
    const presets = [[16, 16], [32, 32], [64, 64], [96, 96], [128, 128], [128, 192], [256, 256], [320, 240]];
    const r = await modal('Nouvelle image', h('div', { class: 'pja-form' },
      h('div', { class: 'pja-pair' }, h('label', null, 'Largeur', w), h('label', null, 'Hauteur', hh)),
      h('div', { class: 'pja-chips' }, presets.map(([a, b]) => h('button', { class: 'pjs-btn small', onclick: () => { w.value = a; hh.value = b; } }, `${a}×${b}`))),
      h('p', { class: 'pjs-hint' }, 'Le PSDK utilise 96×96 pour les Pokémon, 32×32 par case pour les personnages (charset 4×4).')),
    [[null, 'Annuler'], [() => ({ w: +w.value, h: +hh.value }), 'Créer', true]]);
    if (!r || !(r.w > 0 && r.h > 0)) return;
    store.set('newSize', r);
    S.doc = newDoc(clamp(Math.round(r.w), 1, 4096), clamp(Math.round(r.h), 1, 4096), null);
    S.doc.dirty = true;
    fit();
    refreshAll();
  }
  async function askResize() {
    const d = S.doc;
    const w = h('input', { class: 'pjs-input', type: 'number', min: 1, max: 4096, value: d.w });
    const hh = h('input', { class: 'pjs-input', type: 'number', min: 1, max: 4096, value: d.h });
    const mode = h('select', { class: 'pjs-input' }, h('option', { value: 'canvas' }, 'Agrandir / réduire la toile'), h('option', { value: 'scale' }, 'Mettre l’image à l’échelle'));
    const anchor = h('select', { class: 'pjs-input' }, [['0,0', 'En haut à gauche'], ['0.5,0', 'En haut'], ['0.5,0.5', 'Au centre'], ['0.5,1', 'En bas'], ['0,1', 'En bas à gauche']]
      .map(([v, l]) => h('option', { value: v, selected: v === '0.5,1' }, l)));
    const r = await modal('Taille de l’image', h('div', { class: 'pja-form' }, h('div', { class: 'pja-pair' }, h('label', null, 'Largeur', w), h('label', null, 'Hauteur', hh)),
      h('label', null, 'Mode', mode), h('label', null, 'Position de l’image', anchor),
      h('div', { class: 'pja-chips' }, [0.5, 2, 3, 4].map((k) => h('button', { class: 'pjs-btn small', onclick: () => { w.value = Math.max(1, Math.round(d.w * k)); hh.value = Math.max(1, Math.round(d.h * k)); mode.value = 'scale'; } }, '×' + k)))),
    [[null, 'Annuler'], [() => ({ w: +w.value, h: +hh.value, scale: mode.value === 'scale', anchor: anchor.value.split(',').map(Number) }), 'Appliquer', true]]);
    if (!r || !(r.w > 0 && r.h > 0)) return;
    resizeCanvas(clamp(Math.round(r.w), 1, 4096), clamp(Math.round(r.h), 1, 4096), r.anchor[0], r.anchor[1], r.scale);
  }

  // ---------------------------------------------------------------------------
  // Vue : zoom, déplacement, rendu
  // ---------------------------------------------------------------------------
  function fit() {
    if (!view || !S.doc) return;
    const r = view.parentElement.getBoundingClientRect();
    const z = Math.max(1, Math.floor(Math.min((r.width - 40) / S.doc.w, (r.height - 40) / S.doc.h)));
    S.zoom = clamp(z, 1, 64);
    S.ox = Math.round((r.width - S.doc.w * S.zoom) / 2);
    S.oy = Math.round((r.height - S.doc.h * S.zoom) / 2);
  }
  function zoomAt(z, mx, my) {
    z = clamp(z, 1, 64);
    if (mx === undefined) { const r = view.getBoundingClientRect(); mx = r.width / 2; my = r.height / 2; }
    S.ox = Math.round(mx - (mx - S.ox) * (z / S.zoom));
    S.oy = Math.round(my - (my - S.oy) * (z / S.zoom));
    S.zoom = z;
    draw();
    renderStatus();
  }
  const ZOOMS = [1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64];
  const zoomStep = (dir, mx, my) => { const i = ZOOMS.findIndex((z) => z >= S.zoom); const next = ZOOMS[clamp((ZOOMS[i] === S.zoom ? i : i - (dir > 0 ? 1 : 0)) + dir, 0, ZOOMS.length - 1)]; zoomAt(next, mx, my); };
  function visibleCenter() {
    const r = view.getBoundingClientRect();
    return [clamp(Math.floor((r.width / 2 - S.ox) / S.zoom), 0, S.doc.w - 1), clamp(Math.floor((r.height / 2 - S.oy) / S.zoom), 0, S.doc.h - 1)];
  }

  let checker = null;
  function checkerPattern() {
    if (checker) return checker;
    const c = makeCanvas(16, 16); const x = c.getContext('2d');
    x.fillStyle = '#3a3943'; x.fillRect(0, 0, 16, 16); x.fillStyle = '#2e2d36'; x.fillRect(0, 0, 8, 8); x.fillRect(8, 8, 8, 8);
    checker = vctx.createPattern(c, 'repeat');
    return checker;
  }
  let preview = null; // forme en cours (points) ou trait
  function draw() {
    if (!view || !vctx) return;
    const r = view.parentElement.getBoundingClientRect();
    const k = window.devicePixelRatio || 1;
    const W = Math.max(1, Math.round(r.width * k)); const H = Math.max(1, Math.round(r.height * k));
    if (view.width !== W || view.height !== H) { view.width = W; view.height = H; view.style.width = r.width + 'px'; view.style.height = r.height + 'px'; checker = null; }
    const c = vctx;
    c.setTransform(k, 0, 0, k, 0, 0);
    c.clearRect(0, 0, r.width, r.height);
    const d = S.doc;
    if (!d) return;
    const z = S.zoom; const X = S.ox; const Y = S.oy; const w = d.w * z; const hh = d.h * z;
    c.save();
    c.fillStyle = checkerPattern();
    c.translate(X, Y);
    c.fillRect(0, 0, w, hh);
    c.restore();
    c.imageSmoothingEnabled = false;
    d.layers.forEach((l, i) => {
      if (!l.visible) return;
      c.globalAlpha = l.opacity / 255;
      c.drawImage(l.canvas, X, Y, w, hh);
      if (i === d.active && d.floating) c.drawImage(d.floating.canvas, X + d.floating.x * z, Y + d.floating.y * z, d.floating.canvas.width * z, d.floating.canvas.height * z);
      if (i === d.active && preview && preview.pts) {
        c.fillStyle = preview.erase ? 'rgba(255,255,255,0.35)' : css(preview.color);
        for (const [px, py] of preview.pts) if (px >= 0 && py >= 0 && px < d.w && py < d.h) c.fillRect(X + px * z, Y + py * z, z, z);
      }
    });
    c.globalAlpha = 1;
    // grilles
    if (S.grid && z >= 4) {
      // grille des pixels : trait sombre + trait clair pour rester visible sur toutes les couleurs
      const lines = () => {
        c.beginPath();
        for (let x = 1; x < d.w; x++) { c.moveTo(X + x * z + 0.5, Y); c.lineTo(X + x * z + 0.5, Y + hh); }
        for (let y = 1; y < d.h; y++) { c.moveTo(X, Y + y * z + 0.5); c.lineTo(X + w, Y + y * z + 0.5); }
      };
      c.lineWidth = 1;
      c.strokeStyle = 'rgba(0,0,0,0.28)'; lines(); c.stroke();
      c.save(); c.translate(1, 1); c.strokeStyle = 'rgba(255,255,255,0.10)'; lines(); c.stroke(); c.restore();
    }
    if (S.tile.on && S.tile.w > 0 && S.tile.h > 0) {
      c.strokeStyle = 'rgba(184,29,36,0.75)'; c.lineWidth = 1; c.beginPath();
      for (let x = S.tile.w; x < d.w; x += S.tile.w) { c.moveTo(X + x * z + 0.5, Y); c.lineTo(X + x * z + 0.5, Y + hh); }
      for (let y = S.tile.h; y < d.h; y += S.tile.h) { c.moveTo(X, Y + y * z + 0.5); c.lineTo(X + w, Y + y * z + 0.5); }
      c.stroke();
    }
    if (S.mirror) { c.strokeStyle = 'rgba(95,205,228,0.8)'; c.beginPath(); c.moveTo(X + w / 2 + 0.5, Y); c.lineTo(X + w / 2 + 0.5, Y + hh); c.stroke(); }
    c.strokeStyle = 'rgba(0,0,0,0.6)'; c.strokeRect(X - 0.5, Y - 0.5, w + 1, hh + 1);
    // sélection
    const s = d.floating ? { x: d.floating.x, y: d.floating.y, w: d.floating.canvas.width, h: d.floating.canvas.height } : (preview && preview.sel) || d.selection;
    if (s && s.w > 0 && s.h > 0) {
      const t = (performance.now() / 60) | 0;
      c.lineWidth = 1;
      c.setLineDash([4, 4]); c.lineDashOffset = -t;
      c.strokeStyle = '#fff'; c.strokeRect(X + s.x * z + 0.5, Y + s.y * z + 0.5, s.w * z - 1, s.h * z - 1);
      c.lineDashOffset = -t + 4; c.strokeStyle = '#000'; c.strokeRect(X + s.x * z + 0.5, Y + s.y * z + 0.5, s.w * z - 1, s.h * z - 1);
      c.setLineDash([]);
    }
    // curseur (taille du pinceau)
    if (S.cursor && ['pencil', 'eraser', 'line', 'rect', 'ellipse'].includes(S.tool)) {
      const off = Math.floor((S.brush - 1) / 2);
      c.strokeStyle = 'rgba(255,255,255,0.8)';
      c.strokeRect(X + (S.cursor[0] - off) * z + 0.5, Y + (S.cursor[1] - off) * z + 0.5, S.brush * z - 1, S.brush * z - 1);
    }
  }
  // fourmis de la sélection
  setInterval(() => { if (root && S.doc && (S.doc.selection || S.doc.floating)) draw(); }, 120);

  // ---------------------------------------------------------------------------
  // Souris
  // ---------------------------------------------------------------------------
  let drag = null;
  let spaceDown = false;
  const pixelAt = (e) => { const r = view.getBoundingClientRect(); return [Math.floor((e.clientX - r.left - S.ox) / S.zoom), Math.floor((e.clientY - r.top - S.oy) / S.zoom)]; };
  const inDoc = (p) => p[0] >= 0 && p[1] >= 0 && p[0] < S.doc.w && p[1] < S.doc.h;
  function strokeTo(p, erase, color) {
    const ctx = layer().ctx;
    for (const [x, y] of linePoints(drag.last[0], drag.last[1], p[0], p[1])) plot(ctx, x, y, color, erase);
    drag.last = p;
  }
  function onDown(e) {
    if (!S.doc) return;
    e.preventDefault();
    view.focus();
    const p = pixelAt(e);
    const tool = (e.button === 1 || spaceDown) ? 'hand' : S.tool;
    const right = e.button === 2;
    const color = right ? S.secondary : S.primary;
    drag = { tool, start: p, last: p, sx: e.clientX, sy: e.clientY, ox: S.ox, oy: S.oy, right, color };
    if (tool === 'hand') return;
    if (tool === 'pencil' || tool === 'eraser') {
      commitFloating(); pushUndo();
      const erase = tool === 'eraser';
      if (e.shiftKey && S.lastPoint) { drag.last = S.lastPoint; strokeTo(p, erase, color); } else plot(layer().ctx, p[0], p[1], color, erase);
      S.lastPoint = p;
    } else if (tool === 'bucket') {
      drag = null;
      if (!inDoc(p)) return;
      commitFloating();
      const snap = snapshot();
      if (floodFill(p[0], p[1], color, e.shiftKey)) { S.doc.undo.push(snap); S.doc.redo = []; S.doc.dirty = true; }
    } else if (tool === 'picker') {
      if (inDoc(p)) setColor(right ? 'secondary' : 'primary', pickColor(p[0], p[1]));
    } else if (tool === 'line' || tool === 'rect' || tool === 'ellipse') {
      commitFloating();
      preview = { pts: shapePoints(tool, p, p, e.shiftKey), color, erase: false };
    } else if (tool === 'select') {
      const d = S.doc;
      const s = d.floating ? { x: d.floating.x, y: d.floating.y, w: d.floating.canvas.width, h: d.floating.canvas.height } : d.selection;
      if (s && p[0] >= s.x && p[1] >= s.y && p[0] < s.x + s.w && p[1] < s.y + s.h) {
        if (!d.floating) { if (e.altKey) { pushUndo(); const c = selectionCanvas(); d.floating = { canvas: c, x: s.x, y: s.y }; } else liftSelection(); }
        drag.moveSel = { x: d.floating.x, y: d.floating.y };
      } else {
        commitFloating();
        d.selection = null;
        preview = { sel: { x: p[0], y: p[1], w: 1, h: 1 } };
      }
    } else if (tool === 'move') {
      commitFloating(); pushUndo();
      drag.copy = makeCanvas(S.doc.w, S.doc.h);
      drag.copy.getContext('2d').drawImage(layer().canvas, 0, 0);
    }
    refreshCanvas();
  }
  function onMove(e) {
    if (!S.doc || !view) return;
    const p = pixelAt(e);
    S.cursor = inDoc(p) ? p : null;
    if (!drag) { draw(); renderStatus(); return; }
    const t = drag.tool;
    if (t === 'hand') { S.ox = drag.ox + e.clientX - drag.sx; S.oy = drag.oy + e.clientY - drag.sy; }
    else if (t === 'pencil' || t === 'eraser') { strokeTo(p, t === 'eraser', drag.color); S.lastPoint = p; }
    else if (t === 'picker') { if (inDoc(p)) setColor(drag.right ? 'secondary' : 'primary', pickColor(p[0], p[1])); }
    else if (t === 'line' || t === 'rect' || t === 'ellipse') { preview = { pts: shapePoints(t, drag.start, p, e.shiftKey), color: drag.color }; }
    else if (t === 'select') {
      if (drag.moveSel) { S.doc.floating.x = drag.moveSel.x + p[0] - drag.start[0]; S.doc.floating.y = drag.moveSel.y + p[1] - drag.start[1]; }
      else {
        const x0 = clamp(Math.min(drag.start[0], p[0]), 0, S.doc.w - 1); const y0 = clamp(Math.min(drag.start[1], p[1]), 0, S.doc.h - 1);
        const x1 = clamp(Math.max(drag.start[0], p[0]), 0, S.doc.w - 1); const y1 = clamp(Math.max(drag.start[1], p[1]), 0, S.doc.h - 1);
        preview = { sel: { x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1 } };
      }
    } else if (t === 'move') {
      const l = layer();
      l.ctx.clearRect(0, 0, S.doc.w, S.doc.h);
      l.ctx.drawImage(drag.copy, p[0] - drag.start[0], p[1] - drag.start[1]);
    }
    draw();
    renderStatus();
  }
  function onUp() {
    if (!drag || !S.doc) { drag = null; return; }
    const t = drag.tool;
    if ((t === 'line' || t === 'rect' || t === 'ellipse') && preview && preview.pts) {
      pushUndo();
      const brush = S.brush; S.brush = 1;
      for (const [x, y] of preview.pts) plot(layer().ctx, x, y, drag.color, false);
      S.brush = brush;
    } else if (t === 'select' && preview && preview.sel) {
      const s = preview.sel;
      S.doc.selection = s.w > 1 || s.h > 1 ? s : null;
    }
    preview = null;
    drag = null;
    refreshAll();
  }
  function onWheel(e) {
    if (!S.doc) return;
    e.preventDefault();
    const r = view.getBoundingClientRect();
    if (e.ctrlKey || !e.shiftKey) zoomStep(e.deltaY < 0 ? 1 : -1, e.clientX - r.left, e.clientY - r.top);
    else { S.ox -= e.deltaY; draw(); }
  }

  // ---------------------------------------------------------------------------
  // Clavier
  // ---------------------------------------------------------------------------
  function onKey(e) {
    if (!root || !root.isConnected || !S.doc && !(e.ctrlKey && e.key.toLowerCase() === 'n')) return;
    const tag = (e.target && e.target.tagName) || '';
    if (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA' || root.querySelector('.pja-overlay')) return;
    const k = e.key.toLowerCase();
    const ctrl = e.ctrlKey || e.metaKey;
    let done = true;
    if (ctrl && k === 'z' && !e.shiftKey) undo();
    else if (ctrl && (k === 'y' || (k === 'z' && e.shiftKey))) redo();
    else if (ctrl && k === 's') save(e.shiftKey);
    else if (ctrl && k === 'n') newImage();
    else if (ctrl && k === 'c') copy(false);
    else if (ctrl && k === 'x') copy(true);
    else if (ctrl && k === 'v') paste();
    else if (ctrl && k === 'a') { commitFloating(); S.doc.selection = { x: 0, y: 0, w: S.doc.w, h: S.doc.h }; refreshCanvas(); }
    else if (ctrl && (k === "'" || k === 'g' || e.code === 'Quote' || e.code === 'Backquote')) toggleGrid();
    else if (ctrl && k === 'd') { commitFloating(); S.doc.selection = null; refreshCanvas(); }
    else if (k === 'delete' || k === 'backspace') clearSelection();
    else if (k === 'escape') { commitFloating(); S.doc.selection = null; refreshAll(); }
    else if (k === 'enter') { commitFloating(); refreshAll(); }
    else if (k === ' ') spaceDown = true;
    else if (k === 'x' && !ctrl) { const p = S.primary; S.primary = S.secondary; S.secondary = p; renderSide(); }
    else if (k === '+' || k === '=') zoomStep(1);
    else if (k === '-') zoomStep(-1);
    else if (k === '0') { fit(); draw(); renderStatus(); }
    else if (k === '[') setBrush(S.brush - 1);
    else if (k === ']') setBrush(S.brush + 1);
    else if (S.doc.floating && k.startsWith('arrow')) {
      const n = e.shiftKey ? 8 : 1;
      if (k === 'arrowleft') S.doc.floating.x -= n; if (k === 'arrowright') S.doc.floating.x += n; if (k === 'arrowup') S.doc.floating.y -= n; if (k === 'arrowdown') S.doc.floating.y += n;
      draw();
    } else {
      const tool = TOOLS.find((t) => t[2].toLowerCase() === k && !ctrl);
      if (tool) setTool(tool[0]); else done = false;
    }
    if (done) { e.preventDefault(); e.stopPropagation(); }
  }
  window.addEventListener('keydown', onKey, true);
  window.addEventListener('keyup', (e) => { if (e.key === ' ') spaceDown = false; }, true);
  window.addEventListener('mouseup', onUp);
  window.addEventListener('mousemove', (e) => { if (drag) onMove(e); });

  // ---------------------------------------------------------------------------
  // Réglages
  // ---------------------------------------------------------------------------
  function toggleGrid(v) {
    S.grid = v === undefined ? !S.grid : !!v;
    store.set('grid', S.grid);
    renderTools(); renderSide(); draw();
  }
  function setTool(t) { S.tool = t; renderTools(); renderSide(); draw(); }
  function setBrush(n) { S.brush = clamp(n, 1, 16); renderSide(); draw(); }
  function setColor(which, c) { S[which] = c.slice(); renderSide(); }
  function extractColors() {
    if (!S.doc) return;
    const data = flatten().getContext('2d').getImageData(0, 0, S.doc.w, S.doc.h).data;
    const count = new Map();
    for (let i = 0; i < data.length; i += 4) { if (data[i + 3] === 0) continue; const key = toHex([data[i], data[i + 1], data[i + 2]]); count.set(key, (count.get(key) || 0) + 1); }
    const colors = [...count.entries()].sort((a, b) => b[1] - a[1]).slice(0, 96).map((e) => e[0]);
    if (!colors.length) { flash('Image vide : rien à reprendre.'); return; }
    S.palette = colors; store.set('palette', S.palette); renderSide();
    flash(colors.length + ' couleurs reprises de l’image.');
  }
  function extractIfEmpty() { /* la palette reste celle de l'utilisateur */ }
  let flashTimer = null;
  function flash(text, error) {
    S.status = text; S.error = error ? text : '';
    const el = root && root.querySelector('.pja-msg');
    if (el) { el.textContent = text; el.classList.toggle('error', !!error); }
    clearTimeout(flashTimer);
    flashTimer = setTimeout(() => { S.status = ''; S.error = ''; const m = root && root.querySelector('.pja-msg'); if (m) m.textContent = ''; }, error ? 8000 : 3500);
  }

  // ---------------------------------------------------------------------------
  // Rendu de la page
  // ---------------------------------------------------------------------------
  const icon = (d) => { const s = document.createElementNS('http://www.w3.org/2000/svg', 'svg'); s.setAttribute('viewBox', '0 0 24 24'); const p = document.createElementNS('http://www.w3.org/2000/svg', 'path'); p.setAttribute('d', d); p.setAttribute('fill', 'currentColor'); s.appendChild(p); return s; };
  const extOf = (n) => (n.match(/\.[^.]+$/) || [''])[0].slice(1).toUpperCase();
  function matches(node, q) { return !q || (node.dir ? node.children.some((c) => matches(c, q)) : node.path.toLowerCase().includes(q)); }
  function treeRows(nodes, depth, q) {
    const out = [];
    for (const n of nodes) {
      if (!matches(n, q)) continue;
      if (n.dir) {
        const opened = !!q || S.openDirs.has(n.path);
        out.push(h('div', { class: 'pja-row dir', style: { paddingLeft: 6 + depth * 12 + 'px' }, onclick: () => { if (S.openDirs.has(n.path)) S.openDirs.delete(n.path); else S.openDirs.add(n.path); store.set('openDirs', [...S.openDirs]); renderFiles(); } },
          h('span', { class: 'pja-caret' + (opened ? ' open' : '') }, '▸'), h('span', { class: 'pja-name' }, n.name)));
        if (opened) out.push(...treeRows(n.children, depth + 1, q));
      } else {
        out.push(h('div', { class: 'pja-row file' + (S.doc && S.doc.file === n.path ? ' sel' : ''), style: { paddingLeft: 18 + depth * 12 + 'px' }, title: 'graphics/' + n.path, onclick: () => openFile(n.path) },
          h('span', { class: 'pja-ext' }, extOf(n.name)), h('span', { class: 'pja-name' }, n.name)));
      }
    }
    return out;
  }
  function renderFiles() {
    const list = root && root.querySelector('.pja-tree');
    if (!list) return;
    const top = list.scrollTop;
    list.innerHTML = '';
    const q = S.search.trim().toLowerCase();
    const rows = treeRows((S.ctx && S.ctx.tree) || [], 0, q);
    if (!rows.length) list.appendChild(h('div', { class: 'pjs-hint pja-empty' }, !S.ctx || !S.ctx.rootExists ? 'Ouvre un projet dans Studio.' : q ? 'Aucune image trouvée.' : 'Aucune image dans graphics.'));
    rows.forEach((r) => list.appendChild(r));
    list.scrollTop = top;
  }
  function renderTools() {
    const bar = root && root.querySelector('.pja-tools');
    if (!bar) return;
    bar.innerHTML = '';
    TOOLS.forEach(([id, label, key, path]) => bar.appendChild(h('button', { class: 'pja-tool' + (S.tool === id ? ' on' : ''), title: `${label} (${key})`, onclick: () => setTool(id) }, icon(path))));
    bar.appendChild(h('div', { class: 'pja-tools-sep' }));
    bar.appendChild(h('button', { class: 'pja-tool toggle' + (S.grid ? ' active' : ''), title: (S.grid ? 'Cacher' : 'Afficher') + ' la grille des pixels (Ctrl+G)', onclick: () => toggleGrid() },
      icon('M3 3h18v18H3zm2 2v4h4V5zm6 0v4h2V5zm4 0v4h4V5zM5 11v2h4v-2zm6 0v2h2v-2zm4 0v2h4v-2zM5 15v4h4v-4zm6 0v4h2v-4zm4 0v4h4v-4z')));
  }
  function swatch(which) {
    const c = S[which];
    return h('label', { class: 'pja-swatch ' + which, title: which === 'primary' ? 'Couleur principale (clic gauche)' : 'Couleur secondaire (clic droit)' },
      h('span', { style: { background: css(c) } }),
      h('input', { type: 'color', value: toHex(c), oninput: (e) => { S[which] = fromHex(e.target.value, S[which][3] || 255); renderSide(); } }));
  }
  function renderSide() {
    const side = root && root.querySelector('.pja-side');
    if (!side) return;
    side.innerHTML = '';
    const d = S.doc;
    // couleurs
    const alpha = h('input', { type: 'range', min: 0, max: 255, value: S.primary[3], oninput: (e) => { S.primary[3] = +e.target.value; alphaVal.textContent = Math.round(S.primary[3] / 2.55) + ' %'; swatches.querySelector('.primary span').style.background = css(S.primary); } });
    const alphaVal = h('span', { class: 'pjs-hint' }, Math.round(S.primary[3] / 2.55) + ' %');
    const swatches = h('div', { class: 'pja-swatches' }, swatch('secondary'), swatch('primary'),
      h('button', { class: 'pja-swap', title: 'Échanger (X)', onclick: () => { const p = S.primary; S.primary = S.secondary; S.secondary = p; renderSide(); } }, '⇄'));
    const hex = h('input', { class: 'pjs-input pja-hex', value: toHex(S.primary), onchange: (e) => { S.primary = fromHex(e.target.value, S.primary[3]); renderSide(); } });
    side.appendChild(h('div', { class: 'pja-panel' }, h('div', { class: 'pja-title' }, 'Couleurs'),
      h('div', { class: 'pja-colorrow' }, swatches, h('div', { class: 'pja-colorinfo' }, hex, h('div', { class: 'pja-alpha' }, h('span', { class: 'pjs-hint' }, 'Opacité'), alpha, alphaVal))),
      h('div', { class: 'pja-palette' }, S.palette.map((p, i) => h('button', { class: 'pja-pal', style: { background: p }, title: p + ' — clic droit : couleur secondaire, Maj+clic : retirer',
        onclick: (e) => { if (e.shiftKey) { S.palette.splice(i, 1); store.set('palette', S.palette); renderSide(); return; } S.primary = fromHex(p); renderSide(); },
        oncontextmenu: (e) => { e.preventDefault(); S.secondary = fromHex(p); renderSide(); } })),
      h('button', { class: 'pja-pal add', title: 'Ajouter la couleur principale', onclick: () => { const c = toHex(S.primary); if (!S.palette.includes(c)) { S.palette.push(c); store.set('palette', S.palette); renderSide(); } } }, '+')),
      h('div', { class: 'pja-btnrow' },
        h('button', { class: 'pjs-btn small', onclick: extractColors, disabled: !d }, 'Couleurs de l’image'),
        h('button', { class: 'pjs-btn small', onclick: () => { S.palette = DEFAULT_PALETTE.slice(); store.set('palette', S.palette); renderSide(); } }, 'Palette de base'))));
    // outil
    const toolOpts = h('div', { class: 'pja-panel' }, h('div', { class: 'pja-title' }, 'Outil'));
    if (['pencil', 'eraser'].includes(S.tool)) {
      toolOpts.appendChild(h('div', { class: 'pja-opt' }, h('span', null, 'Taille'), h('input', { type: 'range', min: 1, max: 16, value: S.brush, oninput: (e) => setBrush(+e.target.value) }), h('span', { class: 'pjs-hint' }, S.brush + ' px')));
      toolOpts.appendChild(h('label', { class: 'pja-check' }, h('input', { type: 'checkbox', checked: S.mirror, onchange: (e) => { S.mirror = e.target.checked; draw(); } }), 'Symétrie horizontale'));
    }
    if (['rect', 'ellipse'].includes(S.tool)) toolOpts.appendChild(h('label', { class: 'pja-check' }, h('input', { type: 'checkbox', checked: S.filled, onchange: (e) => { S.filled = e.target.checked; } }), 'Forme pleine'));
    const hints = { pencil: 'Clic gauche : couleur principale, clic droit : secondaire. Maj+clic : trait droit depuis le dernier point.',
      eraser: 'Efface en transparence.', bucket: 'Maj+clic : remplace la couleur dans toute l’image.', picker: 'Clic droit : prend la couleur secondaire.',
      line: 'Maj : angles de 45°.', rect: 'Maj : carré.', ellipse: 'Maj : cercle.', select: 'Glisser dedans : déplacer (Alt : copier). Flèches : 1 px (Maj : 8). Entrée : poser. Suppr : effacer. Ctrl+C / X / V.',
      move: 'Déplace tout le calque actif.', hand: 'Molette : zoom. Espace ou clic molette : déplacer la vue.' };
    toolOpts.appendChild(h('div', { class: 'pjs-hint pja-toolhint' }, hints[S.tool]));
    side.appendChild(toolOpts);
    // calques
    if (d) {
      const layers = h('div', { class: 'pja-layers' });
      d.layers.slice().reverse().forEach((l) => {
        const i = d.layers.indexOf(l);
        const thumb = makeCanvas(32, 32);
        const tc = thumb.getContext('2d'); tc.imageSmoothingEnabled = false;
        const k = Math.min(32 / d.w, 32 / d.h); tc.drawImage(l.canvas, (32 - d.w * k) / 2, (32 - d.h * k) / 2, d.w * k, d.h * k);
        layers.appendChild(h('div', { class: 'pja-layer' + (i === d.active ? ' on' : ''), onclick: () => { commitFloating(); d.active = i; renderSide(); draw(); } },
          h('button', { class: 'pja-eye' + (l.visible ? '' : ' off'), title: 'Afficher / cacher', onclick: (e) => { e.stopPropagation(); l.visible = !l.visible; d.dirty = true; renderSide(); draw(); } }, l.visible ? '●' : '○'),
          thumb,
          h('input', { class: 'pja-lname', value: l.name, onchange: (e) => { l.name = e.target.value || l.name; }, onclick: (e) => e.stopPropagation() }),
          h('input', { class: 'pja-lop', type: 'range', min: 0, max: 255, value: l.opacity, title: 'Opacité', onclick: (e) => e.stopPropagation(), oninput: (e) => { l.opacity = +e.target.value; d.dirty = true; draw(); } })));
      });
      side.appendChild(h('div', { class: 'pja-panel grow' }, h('div', { class: 'pja-title' }, 'Calques'), layers,
        h('div', { class: 'pja-btnrow' },
          h('button', { class: 'pjs-btn small', title: 'Nouveau calque', onclick: addLayer }, '+'),
          h('button', { class: 'pjs-btn small', title: 'Dupliquer', onclick: duplicateLayer }, '⧉'),
          h('button', { class: 'pjs-btn small', title: 'Monter', onclick: () => moveLayer(1) }, '▲'),
          h('button', { class: 'pjs-btn small', title: 'Descendre', onclick: () => moveLayer(-1) }, '▼'),
          h('button', { class: 'pjs-btn small', title: 'Fusionner avec le calque du dessous', onclick: mergeDown }, 'Fusionner'),
          h('button', { class: 'pjs-btn small', title: 'Supprimer', onclick: deleteLayer }, '✕'))));
      // image
      side.appendChild(h('div', { class: 'pja-panel' }, h('div', { class: 'pja-title' }, 'Image'),
        h('div', { class: 'pja-btnrow' },
          h('button', { class: 'pjs-btn small', onclick: askResize }, 'Taille…'),
          h('button', { class: 'pjs-btn small', onclick: cropToSelection, disabled: !d.selection }, 'Rogner'),
          h('button', { class: 'pjs-btn small', title: 'Retourner horizontalement', onclick: flipH }, '⇋'),
          h('button', { class: 'pjs-btn small', title: 'Retourner verticalement', onclick: flipV }, '⥮'),
          h('button', { class: 'pjs-btn small', title: 'Pivoter à gauche', onclick: () => rotate(-1) }, '⟲'),
          h('button', { class: 'pjs-btn small', title: 'Pivoter à droite', onclick: () => rotate(1) }, '⟳')),
        h('label', { class: 'pja-check', title: 'Ctrl+G' }, h('input', { type: 'checkbox', checked: S.grid, onchange: (e) => toggleGrid(e.target.checked) }), 'Grille des pixels (visible à partir du zoom 400 %)'),
        h('div', { class: 'pja-opt' },
          h('label', { class: 'pja-check' }, h('input', { type: 'checkbox', checked: S.tile.on, onchange: (e) => { S.tile.on = e.target.checked; store.set('tile', S.tile); draw(); } }), 'Cases'),
          h('input', { class: 'pjs-input pja-num', type: 'number', min: 1, value: S.tile.w, onchange: (e) => { S.tile.w = Math.max(1, +e.target.value); store.set('tile', S.tile); draw(); } }), '×',
          h('input', { class: 'pjs-input pja-num', type: 'number', min: 1, value: S.tile.h, onchange: (e) => { S.tile.h = Math.max(1, +e.target.value); store.set('tile', S.tile); draw(); } }),
          h('button', { class: 'pjs-btn small', title: 'Charset du PSDK : 4 colonnes × 4 lignes', onclick: () => { S.tile = { on: true, w: Math.max(1, Math.floor(d.w / 4)), h: Math.max(1, Math.floor(d.h / 4)) }; store.set('tile', S.tile); renderSide(); draw(); } }, '4×4'))));
    }
  }
  function renderStatus() {
    const el = root && root.querySelector('.pja-info');
    if (!el) return;
    const d = S.doc;
    el.textContent = d ? `${d.w} × ${d.h} px   ·   zoom ${S.zoom * 100} %` + (S.cursor ? `   ·   ${S.cursor[0]}, ${S.cursor[1]}` : '') + (d.selection ? `   ·   sélection ${d.selection.w} × ${d.selection.h}` : '') : '';
    const t = root.querySelector('.pja-doc');
    if (t) t.textContent = d ? (d.file ? 'graphics/' + d.file : 'Nouvelle image') + (d.dirty ? ' •' : '') : 'Aucune image ouverte';
  }
  function refreshCanvas() { draw(); renderStatus(); }
  function refreshAll() { refreshWelcome(); draw(); renderSide(); renderStatus(); renderFiles(); }
  function render() {
    if (!root) return;
    root.innerHTML = '';
    view = h('canvas', { class: 'pja-view', tabindex: 0, onmousedown: onDown, onmousemove: (e) => { if (!drag) onMove(e); }, onwheel: onWheel, oncontextmenu: (e) => e.preventDefault(),
      onmouseleave: () => { S.cursor = null; draw(); renderStatus(); } });
    vctx = view.getContext('2d');
    checker = null;
    const empty = h('div', { class: 'pja-welcome' }, h('div', { class: 'pja-welcome-title' }, 'Atelier'),
      h('div', { class: 'pjs-hint' }, 'Ouvre une image du dossier graphics à gauche ou crée-en une nouvelle.'),
      h('button', { class: 'pjs-btn primary', onclick: newImage }, 'Nouvelle image'));
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' }, h('span', { class: 'pjs-top-title' }, 'Atelier'), h('span', { class: 'pjs-top-sub pja-doc' })),
      h('div', { class: 'pjs-topbar-right' }, h('span', { class: 'pjs-status pja-msg' }),
        h('button', { class: 'pjs-btn small', title: 'Annuler (Ctrl+Z)', onclick: undo }, '↶'),
        h('button', { class: 'pjs-btn small', title: 'Rétablir (Ctrl+Y)', onclick: redo }, '↷'),
        h('button', { class: 'pjs-btn small', title: 'Ctrl+N', onclick: newImage }, 'Nouvelle'),
        h('button', { class: 'pjs-btn small', title: 'Ctrl+Maj+S', onclick: () => save(true) }, 'Enregistrer sous'),
        h('button', { class: 'pjs-btn primary small', title: 'Ctrl+S', onclick: () => save(false) }, 'Enregistrer'))));
    root.appendChild(h('div', { class: 'pja-body' },
      h('div', { class: 'pja-files' },
        h('input', { class: 'pjs-input', placeholder: 'Rechercher une image…', value: S.search, oninput: (e) => { S.search = e.target.value; renderFiles(); } }),
        h('div', { class: 'pja-tree' }),
        h('button', { class: 'pjs-btn small', onclick: async () => { await loadContext(); renderFiles(); } }, 'Actualiser')),
      h('div', { class: 'pja-tools' }),
      h('div', { class: 'pja-center' }, h('div', { class: 'pja-viewport' }, view, S.doc ? null : empty), h('div', { class: 'pja-info' })),
      h('div', { class: 'pja-side' })));
    renderTools();
    renderFiles();
    renderSide();
    requestAnimationFrame(() => { if (S.doc && !S.viewed) { fit(); S.viewed = true; } draw(); renderStatus(); });
    if (S.error) flash(S.error, true);
  }
  // l'accueil disparaît dès qu'une image est ouverte
  const _refreshAll = refreshAll;
  function refreshWelcome() { const w = root && root.querySelector('.pja-welcome'); if (w && S.doc) w.remove(); }
  const observerResize = new ResizeObserver(() => draw());

  // ---------------------------------------------------------------------------
  // Page « Atelier » (/atelier)
  // ---------------------------------------------------------------------------
  const PAGE_ID = 'atelier';
  if (!(window.pjPluginPages = window.pjPluginPages || []).some((p) => p.id === PAGE_ID)) window.pjPluginPages.push({ id: PAGE_ID, label: 'Atelier', place: 'atelier' });
  window.dispatchEvent(new Event('pj-plugin-pages'));

  async function mount(hostEl) {
    root = h('div', { id: 'pja-root' });
    ['keydown', 'keypress', 'keyup'].forEach((type) => root.addEventListener(type, (e) => e.stopPropagation()));
    hostEl.appendChild(root);
    if (currentProject() !== S.projectPath || !S.ctx) {
      if (S.doc && S.doc.dirty && S.projectPath && currentProject() !== S.projectPath) S.doc = null;
      await loadContext();
    }
    render();
    const vp = root.querySelector('.pja-viewport');
    if (vp) observerResize.observe(vp);
  }
  function checkPage() {
    const hostEl = document.getElementById('pj-page-' + PAGE_ID);
    if (root && hostEl && hostEl.contains(root)) { refreshWelcome(); return; }
    if (root) { root = null; view = null; vctx = null; observerResize.disconnect(); }
    if (hostEl) mount(hostEl);
  }
  let scheduled = false;
  const observer = new MutationObserver(() => { if (!scheduled) { scheduled = true; requestAnimationFrame(() => { scheduled = false; checkPage(); }); } });
  const begin = () => { observer.observe(document.body, { childList: true, subtree: true }); checkPage(); };
  if (document.body) begin(); else document.addEventListener('DOMContentLoaded', begin);

  window.pjAtelier_ = { state: S, render, refresh: _refreshAll };
})();
