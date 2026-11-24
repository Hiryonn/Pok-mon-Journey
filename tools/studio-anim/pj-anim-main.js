/* eslint-disable */
// =============================================================================
// Animations des attaques (Données > Attaques > Animations) — partie « processus principal » (Electron main)
// Chargé depuis .vite/build/index.js. Fournit les canaux IPC « pj-anim:* ».
// Une animation par attaque : Data/studio_animations/moves/<attaque>.json (lu en jeu par
// scripts/90001 StudioAnimations.rb). Sans fichier, le jeu garde l'animation de PSDK (Animations.rxdata).
// =============================================================================
'use strict';
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');

const ANIM_DIR = 'Data/studio_animations/moves';
const RUNTIME_NAME = '90001 StudioAnimations.rb';
const RUNTIME_SOURCE = path.join(__dirname, 'pj-anim-runtime.rb');
const join = (projectPath, rel) => path.join(projectPath, ...rel.split('/'));
const exists = (p) => { try { return fs.existsSync(p); } catch (e) { return false; } };
const safe = (s) => String(s || '').replace(/[^a-z0-9_]/gi, '_');
const MIME = { '.png': 'image/png', '.gif': 'image/gif', '.ogg': 'audio/ogg', '.wav': 'audio/wav', '.mp3': 'audio/mpeg', '.mid': 'audio/midi' };

// -----------------------------------------------------------------------------
class MarshalReader {
  constructor(buffer) {
    this.b = buffer;
    this.i = 2; // version 4.8
    this.symbols = [];
    this.objects = [];
  }
  byte() { return this.b[this.i++]; }
  int() {
    let c = this.b.readInt8(this.i++);
    if (c === 0) return 0;
    if (c >= 5) return c - 5;
    if (c <= -5) return c + 5;
    if (c > 0) {
      let x = 0;
      for (let k = 0; k < c; k++) x |= this.b[this.i++] << (8 * k);
      return x;
    }
    c = -c;
    let x = -1;
    for (let k = 0; k < c; k++) {
      x &= ~(0xff << (8 * k));
      x |= this.b[this.i++] << (8 * k);
    }
    return x;
  }
  bytes() { const n = this.int(); const s = this.b.subarray(this.i, this.i + n); this.i += n; return s; }
  symbol() {
    const t = String.fromCharCode(this.byte());
    if (t === ':') { const s = this.bytes().toString('utf8'); this.symbols.push(s); return s; }
    if (t === ';') return this.symbols[this.int()];
    if (t === 'I') { const s = this.symbol(); this.ivars({}); return s; }
    throw new Error('Symbole attendu, reçu ' + t);
  }
  ivars(target) {
    const n = this.int();
    for (let k = 0; k < n; k++) { const key = this.symbol(); target[key] = this.read(); }
    return target;
  }
  reg(o) { this.objects.push(o); return o; }
  read() {
    const t = String.fromCharCode(this.byte());
    switch (t) {
      case '0': return null;
      case 'T': return true;
      case 'F': return false;
      case 'i': return this.int();
      case ':': { this.i--; return { __symbol: this.symbol() }; }
      case ';': { this.i--; return { __symbol: this.symbol() }; }
      case '@': return this.objects[this.int()];
      case 'I': {
        const v = this.read();
        const iv = this.ivars({});
        if (v && typeof v === 'object') Object.assign(v, iv);
        return v;
      }
      case '"': { const s = this.bytes().toString('utf8'); this.reg(s); return s; }
      case 'f': {
        const s = this.bytes().toString('latin1');
        const v = s === 'nan' ? NaN : s === 'inf' ? Infinity : s === '-inf' ? -Infinity : parseFloat(s);
        this.reg(v); return v;
      }
      case 'l': {
        const sign = String.fromCharCode(this.byte());
        const n = this.int() * 2; let v = 0;
        for (let k = 0; k < n; k++) v += this.b[this.i++] * Math.pow(256, k);
        v = sign === '-' ? -v : v; this.reg(v); return v;
      }
      case '[': {
        const a = this.reg([]); const n = this.int();
        for (let k = 0; k < n; k++) a.push(this.read());
        return a;
      }
      case '{': case '}': {
        const h = this.reg({ __hash: [] }); const n = this.int();
        for (let k = 0; k < n; k++) { const key = this.read(); h.__hash.push([key, this.read()]); }
        if (t === '}') h.__default = this.read();
        return h;
      }
      case 'o': {
        const o = this.reg({ __class: this.symbol() });
        return this.ivars(o);
      }
      case 'u': {
        const cls = this.symbol(); const data = Buffer.from(this.bytes());
        return this.reg({ __class: cls, __userdef: data });
      }
      case 'U': {
        const o = this.reg({ __class: this.symbol() }); o.__data = this.read(); return o;
      }
      case 'S': {
        const o = this.reg({ __class: this.symbol(), __struct: true }); const n = this.int();
        for (let k = 0; k < n; k++) { const key = this.symbol(); o[key] = this.read(); }
        return o;
      }
      case 'e': { this.symbol(); return this.read(); }
      case 'C': { this.symbol(); return this.read(); }
      case 'c': case 'm': case 'M': { const s = this.bytes().toString('utf8'); this.reg({ __module: s }); return { __module: s }; }
      case '/': { const s = this.bytes().toString('utf8'); this.byte(); this.reg(s); return s; }
      case 'd': { const o = this.reg({ __class: this.symbol() }); o.__data = this.read(); return o; }
      default: throw new Error('Type Marshal non géré : ' + t + ' @' + (this.i - 1));
    }
  }
}
const marshalLoad = (buffer) => new MarshalReader(buffer).read();
const hashEntries = (h) => (h && h.__hash ? h.__hash : []);

function parseCsv(text) {
  const rows = []; let row = []; let cell = ''; let q = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (q) { if (c === '"') { if (text[i + 1] === '"') { cell += '"'; i++; } else q = false; } else cell += c; }
    else if (c === '"') q = true;
    else if (c === ',') { row.push(cell); cell = ''; }
    else if (c === '\n' || c === '\r') { if (c === '\r' && text[i + 1] === '\n') i++; row.push(cell); rows.push(row); row = []; cell = ''; }
    else cell += c;
  }
  if (cell || row.length) { row.push(cell); rows.push(row); }
  return rows;
}
function texts(projectPath, id) {
  const f = join(projectPath, `Data/Text/Dialogs/${id}.csv`);
  if (!exists(f)) return () => null;
  const rows = parseCsv(fs.readFileSync(f, 'utf8').replace(/^﻿/, ''));
  let col = rows[0].indexOf('fr'); if (col < 0) col = Math.max(0, rows[0].indexOf('en'));
  return (i) => (rows[i + 1] && rows[i + 1][col]) || null;
}
async function readJsonDir(dir) {
  if (!exists(dir)) return [];
  const out = [];
  for (const f of (await fsp.readdir(dir)).filter((n) => n.endsWith('.json'))) {
    try { out.push(JSON.parse((await fsp.readFile(path.join(dir, f), 'utf8')).replace(/^﻿/, ''))); } catch (e) { /* ignoré */ }
  }
  return out;
}
async function listFiles(dir, exts, rel = '') {
  let out = [];
  let list;
  try { list = await fsp.readdir(path.join(dir, rel), { withFileTypes: true }); } catch (e) { return out; }
  for (const d of list) {
    const r = rel ? rel + '/' + d.name : d.name;
    if (d.isDirectory()) { if (!d.name.startsWith('.')) out = out.concat(await listFiles(dir, exts, r)); }
    else if (exts.includes(path.extname(d.name).toLowerCase())) out.push(r);
  }
  return out;
}
const sortFr = (a, b) => a.localeCompare(b, 'fr', { numeric: true, sensitivity: 'base' });

// --- RPG Maker : Animations.rxdata + PSP_MTAU / PSP_MTAT (animation du lanceur / de la cible) ------------------
let rmxpCache = null;
function rmxpData(projectPath) {
  const f = join(projectPath, 'Data/Animations.rxdata');
  if (!exists(f)) return null;
  const mtime = fs.statSync(f).mtimeMs;
  if (rmxpCache && rmxpCache.path === f && rmxpCache.mtime === mtime) return rmxpCache;
  const list = marshalLoad(fs.readFileSync(f));
  const table = (name) => {
    const p = join(projectPath, `Data/${name}`);
    if (!exists(p)) return new Map();
    try { return new Map(hashEntries(marshalLoad(fs.readFileSync(p))).map(([k, v]) => [k, v])); } catch (e) { return new Map(); }
  };
  rmxpCache = { path: f, mtime, list, mtau: table('PSP_MTAU.dat'), mtat: table('PSP_MTAT.dat') };
  return rmxpCache;
}
function readTable(t) {
  if (!t || !t.__userdef) return null;
  const b = t.__userdef;
  const xs = b.readInt32LE(4), ys = b.readInt32LE(8), zs = b.readInt32LE(12);
  const data = [];
  for (let i = 0; i < xs * ys * zs; i++) data.push(b.readInt16LE(20 + i * 2));
  return { xs, ys, zs, get: (x, y) => data[x + y * xs] };
}
const colorOf = (c) => {
  if (!c || !c.__userdef) return { hex: '#ffffff', alpha: 255 };
  const b = c.__userdef; const v = [0, 1, 2, 3].map((k) => Math.max(0, Math.min(255, Math.round(b.readDoubleLE(k * 8)))));
  return { hex: '#' + v.slice(0, 3).map((x) => x.toString(16).padStart(2, '0')).join(''), alpha: v[3] };
};
// Animation RPG Maker -> calques / évènements (20 images par seconde, cases de 192 px, écran 640 x 480 -> 320 x 240)
function convertRmxp(anim, anchor, offset, layers, events) {
  if (!anim) return 0;
  const FPS = 20;
  const image = anim['@animation_name'] || '';
  const pos = anim['@position'] | 0; // 0 haut, 1 milieu, 2 bas, 3 écran
  const anchorName = pos === 3 ? 'screen' : anchor;
  const dy = pos === 0 ? -24 : pos === 2 ? 24 : 0;
  const frames = anim['@frames'] || [];
  const tracks = new Map();
  frames.forEach((fr, fi) => {
    const tab = readTable(fr && fr['@cell_data']);
    if (!tab) return;
    for (let c = 0; c < tab.xs; c++) {
      const pattern = tab.get(c, 0);
      const zoom = tab.get(c, 3); const op = tab.get(c, 6);
      const valid = pattern >= 0 && pattern < 100 && zoom > 0 && zoom <= 1000 && op >= 0 && op <= 255;
      if (!tracks.has(c)) tracks.set(c, []);
      const keys = tracks.get(c);
      const t = Math.round((offset + fi / FPS) * 1000) / 1000;
      if (!valid) { if (keys.length && keys[keys.length - 1].visible !== false) keys.push({ t, visible: false, tween: false }); continue; }
      keys.push({ t, cell: pattern, x: Math.round(tab.get(c, 1) / 2), y: Math.round(tab.get(c, 2) / 2) + dy, zoom: Math.round(tab.get(c, 3) / 2),
        angle: tab.get(c, 4), mirror: tab.get(c, 5) === 1, opacity: tab.get(c, 6), visible: true, tween: false, blend: tab.get(c, 7) });
    }
  });
  const end = Math.round((offset + frames.length / FPS) * 1000) / 1000;
  [...tracks.entries()].forEach(([c, keys]) => {
    if (!keys.some((k) => k.visible)) return;
    if (keys[keys.length - 1].visible !== false) keys.push({ t: end, visible: false, tween: false });
    const blend = (keys.find((k) => k.visible) || {}).blend | 0;
    keys.forEach((k) => delete k.blend);
    layers.push({ name: `${anchorName === 'user' ? 'Lanceur' : anchorName === 'screen' ? 'Écran' : 'Cible'} ${c + 1}`, image, cell: 192, anchor: anchorName,
      blend, front: true, keys });
  });
  (anim['@timings'] || []).forEach((tm) => {
    const t = Math.round((offset + (tm['@frame'] | 0) / FPS) * 1000) / 1000;
    const se = tm['@se'];
    if (se && se['@name']) events.push({ t, type: 'se', name: se['@name'], volume: se['@volume'] ?? 100, pitch: se['@pitch'] ?? 100 });
    const scope = tm['@flash_scope'] | 0;
    if (scope === 1 || scope === 2) {
      const c = colorOf(tm['@flash_color']);
      events.push({ t, type: 'flash', on: scope === 1 ? anchor : 'screen', color: c.hex, alpha: c.alpha, duration: Math.round((tm['@flash_duration'] | 0) / FPS * 1000) / 1000 });
    } else if (scope === 3) {
      events.push({ t, type: 'hide', on: anchor });
      events.push({ t: Math.round((t + (tm['@flash_duration'] | 0) / FPS) * 1000) / 1000, type: 'show', on: anchor });
    }
  });
  return frames.length / FPS;
}

function runtimeStatus(projectPath) {
  const f = join(projectPath, `scripts/${RUNTIME_NAME}`);
  if (!exists(f)) return { installed: false, upToDate: false };
  const norm = (t) => t.replace(/\r\n/g, '\n');
  let src = '';
  try { src = fs.readFileSync(RUNTIME_SOURCE, 'utf8'); } catch (e) { /* rien */ }
  return { installed: true, upToDate: !src || norm(fs.readFileSync(f, 'utf8')) === norm(src) };
}

// Paquet d'animations à déballer (Data/studio_animations/import.json : { attaque: animation }) :
// une animation par fichier, sans écraser celles qui existent déjà
async function unpackImport(projectPath) {
  const f = join(projectPath, 'Data/studio_animations/import.json');
  if (!exists(f)) return 0;
  const pack = JSON.parse((await fsp.readFile(f, 'utf8')).replace(/^\uFEFF/, ''));
  const dir = join(projectPath, ANIM_DIR);
  await fsp.mkdir(dir, { recursive: true });
  let n = 0;
  for (const [move, data] of Object.entries(pack)) {
    const out = path.join(dir, safe(move) + '.json');
    if (exists(out)) continue;
    await fsp.writeFile(out, JSON.stringify(data, null, 1) + '\n', 'utf8');
    n++;
  }
  await fsp.unlink(f);
  const cache = join(projectPath, 'Data/studio_animations.rxdata');
  if (exists(cache)) { try { await fsp.unlink(cache); } catch (e) { /* rien */ } }
  return n;
}

const handlers = {
  async getContext({ projectPath }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    let unpacked = 0;
    try { unpacked = await unpackImport(projectPath); } catch (e) { console.error('pj-anim : import.json', e); }
    const name = texts(projectPath, 100006);
    const typeName = texts(projectPath, 100003);
    const types = {};
    for (const t of await readJsonDir(join(projectPath, 'Data/Studio/types'))) if (t.dbSymbol) types[t.dbSymbol] = { name: typeName(t.textId) || t.dbSymbol, color: t.color || '' };
    const animDir = join(projectPath, ANIM_DIR);
    const done = new Set(exists(animDir) ? (await fsp.readdir(animDir)).filter((f) => f.endsWith('.json')).map((f) => f.slice(0, -5)) : []);
    const rm = (() => { try { return rmxpData(projectPath); } catch (e) { return null; } })();
    const moves = (await readJsonDir(join(projectPath, 'Data/Studio/moves'))).filter((m) => m.dbSymbol && m.dbSymbol !== '__undef__')
      .map((m) => ({ db: m.dbSymbol, id: m.id, name: name(m.id) || m.dbSymbol, type: m.type || '', category: m.category || '', power: m.power || 0,
        has: done.has(m.dbSymbol), rmxp: !!(rm && (rm.list[m.id] || rm.mtau.has(m.id) || rm.mtat.has(m.id))) }))
      .sort((a, b) => a.id - b.id);
    const images = (await listFiles(join(projectPath, 'graphics/animations'), ['.png'])).map((f) => f.replace(/\.png$/i, '')).sort(sortFr);
    const battlebacks = (await listFiles(join(projectPath, 'graphics/battlebacks'), ['.png'])).map((f) => f.replace(/\.png$/i, '')).sort(sortFr);
    const sounds = (await listFiles(join(projectPath, 'audio/se'), ['.ogg', '.wav', '.mp3'])).map((f) => f.replace(/\.(ogg|wav|mp3)$/i, '')).sort(sortFr);
    return { moves, types, images, battlebacks, sounds, unpacked, runtime: runtimeStatus(projectPath) };
  },
  async read({ projectPath, move }) {
    const f = join(projectPath, `${ANIM_DIR}/${safe(move)}.json`);
    if (!exists(f)) return null;
    return JSON.parse((await fsp.readFile(f, 'utf8')).replace(/^﻿/, ''));
  },
  async save({ projectPath, move, data }) {
    const f = join(projectPath, `${ANIM_DIR}/${safe(move)}.json`);
    await fsp.mkdir(path.dirname(f), { recursive: true });
    await fsp.writeFile(f, JSON.stringify(data, null, 1) + '\n', 'utf8');
    const cache = join(projectPath, 'Data/studio_animations.rxdata');
    if (exists(cache)) { try { await fsp.unlink(cache); } catch (e) { /* rien */ } }
    return { runtime: await handlers.installRuntime({ projectPath }) };
  },
  async remove({ projectPath, move }) {
    const f = join(projectPath, `${ANIM_DIR}/${safe(move)}.json`);
    if (exists(f)) await fsp.unlink(f);
    const cache = join(projectPath, 'Data/studio_animations.rxdata');
    if (exists(cache)) { try { await fsp.unlink(cache); } catch (e) { /* rien */ } }
    return true;
  },
  // copie le script de jeu (scripts/90001 StudioAnimations.rb) s'il manque ou n'est pas à jour
  async installRuntime({ projectPath }) {
    const st = runtimeStatus(projectPath);
    if (st.installed && st.upToDate) return st;
    if (!exists(RUNTIME_SOURCE)) return st;
    await fsp.writeFile(join(projectPath, `scripts/${RUNTIME_NAME}`), fs.readFileSync(RUNTIME_SOURCE, 'utf8'), 'utf8');
    return runtimeStatus(projectPath);
  },
  // animation RPG Maker d'une attaque, convertie (calques + évènements)
  async importRmxp({ projectPath, moveId }) {
    const rm = rmxpData(projectPath);
    if (!rm) throw new Error('Data/Animations.rxdata introuvable.');
    const layers = []; const events = [];
    const userId = rm.mtau.get(moveId);
    const targetId = rm.mtat.has(moveId) ? rm.mtat.get(moveId) : moveId;
    let t = 0;
    if (userId) t = convertRmxp(rm.list[userId], 'user', 0, layers, events);
    const d = convertRmxp(rm.list[targetId], 'target', t, layers, events);
    if (!layers.length && !events.length) throw new Error("Pas d'animation RPG Maker pour cette attaque.");
    return { duration: Math.max(0.2, Math.round((t + d) * 100) / 100), layers, events, from: { user: userId || null, target: rm.list[targetId] ? targetId : null } };
  },
  // fichiers (images, sons) du projet en data URL
  async readFile({ projectPath, file }) {
    const rel = String(file || '').replace(/\\/g, '/');
    if (!/^(graphics|audio)\//.test(rel) || rel.split('/').includes('..')) throw new Error('Fichier refusé : ' + rel);
    let full = join(projectPath, rel);
    if (!path.extname(full)) {
      const ext = ['.png', '.ogg', '.wav', '.mp3'].find((e) => exists(full + e));
      if (!ext) return null;
      full += ext;
    }
    if (!exists(full)) return null;
    return `data:${MIME[path.extname(full).toLowerCase()] || 'application/octet-stream'};base64,` + (await fsp.readFile(full)).toString('base64');
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([n, fn]) => {
    const channel = 'pj-anim:' + n;
    try { ipcMain.removeHandler(channel); } catch (e) { /* rien */ }
    ipcMain.handle(channel, async (_event, payload) => {
      try { return { ok: true, value: await fn(payload || {}) }; } catch (e) { return { ok: false, error: String((e && e.message) || e) }; }
    });
  });
}

module.exports = { register, handlers };

try {
  const electron = require('electron');
  if (electron && electron.ipcMain) register(electron.ipcMain);
} catch (e) { /* hors Electron (tests) */ }
