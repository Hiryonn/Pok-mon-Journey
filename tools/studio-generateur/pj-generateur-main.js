/* eslint-disable */
// =============================================================================
// Générateur de personnages — partie « processus principal » (Electron main)
// Chargé depuis .vite/build/index.js. Fournit les canaux IPC « pj-generateur:* ».
// Lit les pièces (base, cheveux, haut, bas, chapeau, sac) dans les dossiers choisis (hors du projet),
// et écrit les sprites faits dans graphics/characters et graphics/battlers du projet.
// Réglages : Data/configs/generateur_personnages.json (dossiers des pièces, personnages enregistrés)
// =============================================================================
'use strict';
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');
const os = require('os');

const CONFIG_FILE = 'Data/configs/generateur_personnages.json';
const OUT_DIRS = ['graphics/characters', 'graphics/battlers'];

const join = (projectPath, rel) => path.join(projectPath, ...rel.split('/'));
const exists = (p) => { try { return fs.existsSync(p); } catch (e) { return false; } };
const safeName = (name) => String(name || '').replace(/[\\/:*?"<>|]/g, '').replace(/^\.+/, '');

function defaultSources() {
  const base = path.join(os.homedir(), 'Documents', 'Pokémon');
  return [
    { path: path.join(base, 'pokemon png', 'pokemon png'), kind: 'auto' },
    { path: path.join(base, 'Swimming', 'Swimming'), kind: 'swim' },
    { path: path.join(base, 'Watering', 'Watering'), kind: 'water' },
  ];
}

// ---------------------------------------------------------------------------
// Lecture des pièces
// ---------------------------------------------------------------------------
const COLORS2 = ['light blue', 'light green', 'powder blue'];
const COLORS = ['black', 'blue', 'green', 'red', 'white', 'yellow', 'purple', 'pink', 'orange', 'magenta', 'brown', 'grey', 'gray', 'navy',
  'wine', 'beige', 'aqua', 'cyan', 'gold', 'silver', 'blonde', 'blond', 'ginger', 'lavender', 'dark', 'light', 'medium', 'pale'];
const ALIASES = {
  'trench coat': 'trenchcoat', formal: 'formal top', 'formal bottoms': 'formal bottom', 'formal pants': 'formal bottom',
  'classy bottoms': 'classy bottom', 'classy pants': 'classy bottom', capri: 'capris', 'lord shirt': 'lord suit', 'lord suit top': 'lord suit',
  'lords pants': 'lord suit pants', 'school uniform top': 'school uniform', 'school top': 'school uniform',
  'school uniform bottom': 'school uniform bottom', 'school girl': 'school uniform bottom', 'schoolboy pants': 'school uniform bottom',
  'schoolgirl skirt': 'school uniform bottom', cat: 'cat ears', cate: 'cat ears', hairband: 'hair band', mining: 'miner', sunhat: 'sun hat',
  'youngster cap': 'youngster hat', 't shirt': 't-shirt', 'v neck': 'v-neck', 'opened jacket': 'open jacket', 'collared  shirt': 'collared shirt',
  'beach wear': 'beach top', 'scarf top': 'scarf shirt', 'evening bottom': 'classy bottom',
};
const TOP_ALIASES = { jumpsuit: 'jumpsuit top', 'jumpsuit alt': 'jumpsuit alt top', beach: 'beach top', classy: 'classy top' };

const words = (s) => String(s).toLowerCase().replace(/[()_]/g, ' ').split(/\s+/).filter(Boolean);
const COLOR_FIX = { blond: 'blonde', gray: 'grey', violet: 'purple', brownish: 'brown' };
const canonColor = (c) => {
  const s = words(c).filter((t) => !/^#/.test(t)).join(' ');
  return COLOR_FIX[s] || s;
};
const isColor = (t) => COLORS.includes(t) || !!COLOR_FIX[t];
// couleur à la fin d'une liste de mots (« classy bottom f beige » -> beige)
function trailingColor(w) {
  w = w.filter((t) => !/^#/.test(t));
  if (w.length >= 2 && COLORS2.includes(w.slice(-2).join(' '))) return w.slice(-2).join(' ');
  if (w.length && isColor(w[w.length - 1])) return w[w.length - 1];
  return '';
}
// genre écrit dans le nom d'un fichier (« school top f dark », « schoolboy pants »)
function nameGender(w) {
  if (w.some((t) => t === 'schoolboy' || t === 'boy')) return 'm';
  if (w.some((t) => t === 'schoolgirl' || t === 'girl')) return 'f';
  const i = w.findIndex((t) => t === 'f' || t === 'm');
  return i > 0 ? w[i] : '';
}

function splitColor(name) {
  const w = words(name);
  if (w.length >= 3 && COLORS2.includes(w.slice(-2).join(' '))) return [w.slice(0, -2).join(' '), w.slice(-2).join(' ')];
  if (w.length >= 2 && COLORS.includes(w[w.length - 1])) return [w.slice(0, -1).join(' '), w[w.length - 1]];
  return [w.join(' '), ''];
}

// nom d'une pièce -> [clé, genre]
function canonItem(cat, raw) {
  let w = words(raw);
  let gender = '';
  const last = w[w.length - 1];
  if (w.length > 1 && (last === 'f' || last === 'm' || last === 'fm' || last === 'mf')) { if (last.length === 1) gender = last; w = w.slice(0, -1); }
  let key = w.join(' ');
  if (cat === 'top' && TOP_ALIASES[key]) key = TOP_ALIASES[key];
  if (ALIASES[key]) key = ALIASES[key];
  return [key, gender];
}

function catOf(dir) {
  const n = dir.toLowerCase();
  if (/^bases?\b/.test(n)) return 'base';
  if (/^hair/.test(n)) return 'hair';
  if (/^(tops?|clothing)$/.test(n)) return 'top';
  if (/^bottoms?$/.test(n)) return 'bottom';
  if (/^hats?\b/.test(n)) return 'hat';
  if (/^carrying/.test(n)) return 'bag';
  return null;
}

// genre d'un dossier de sprites de dresseur
const folderGender = (name) => (/\bfemale\b/i.test(name) ? 'f' : /\bmale\b/i.test(name) ? 'm' : '');

function kindOf(name) {
  const n = name.toLowerCase();
  if (/overworld\s+walk/.test(n)) return 'walk';
  if (/overworld\s+run/.test(n)) return 'run';
  if (/overworld\s+bike/.test(n)) return 'bike';
  if (/trainer\s+front/.test(n)) return 'front';
  if (/trainer\s+back/.test(n)) return 'back';
  if (/swim/.test(n)) return 'swim';
  if (/water/.test(n)) return 'water';
  return null;
}

// une image -> entrée { cat, key, gender, color, file }
function parseEntry(cat, item, file, gender) {
  const base = path.basename(file).replace(/\.png$/i, '');
  if (cat === 'base') {
    const w = words(base);
    let g = gender;
    if (w[0] === 'm' || w[0] === 'f') g = w.shift();
    if (w[0] === 'base') w.shift();
    return { cat, key: w.join(' ') || 'light', gender: g, color: '', file };
  }
  if (cat === 'hair') {
    let style = ''; let g = gender; let color = '';
    if (item) {
      const iw = words(item);
      const num = iw.find((t) => /^\d+$/.test(t));
      style = num || iw.join(' ');
      if (iw.includes('boy')) g = 'm'; else if (iw.includes('girl')) g = 'f';
      color = words(base).filter((t) => !iw.includes(t)).join(' ');
    } else {
      const m = /^([bg])\s*(\d+)\s+(.+)$/i.exec(base);
      if (m) { g = m[1].toLowerCase() === 'b' ? 'm' : 'f'; style = m[2]; color = m[3]; } else { const [k, c] = splitColor(base); style = k; color = c; }
    }
    return { cat, key: style, gender: g, color: canonColor(color), file };
  }
  let itemName; let color;
  if (item) {
    itemName = item;
    const iw = words(item);
    const bw = words(base);
    color = trailingColor(bw);
    if (!color) {
      let i = 0;
      while (i < bw.length && iw.includes(bw[i])) i++;
      color = bw.slice(i).join(' ');
    }
    const g = nameGender(bw.filter((t) => !iw.includes(t)));
    if (g && !gender) gender = g;
  } else {
    const m = /^(.*?)\s*\(([^)]*)\)\s*$/.exec(base);
    if (m) { itemName = m[1]; color = m[2]; } else [itemName, color] = splitColor(base);
  }
  const [key, g] = canonItem(cat, itemName);
  return { cat, key, gender: g || gender, color: canonColor(color), file, raw: words(itemName).join(' ') };
}

async function walkDir(dir, depth = 0) {
  const out = [];
  if (depth > 3) return out;
  let list;
  try { list = await fsp.readdir(dir, { withFileTypes: true }); } catch (e) { return out; }
  for (const d of list) {
    const full = path.join(dir, d.name);
    if (d.isDirectory()) out.push(...(await walkDir(full, depth + 1)).map((f) => [d.name, ...f]));
    else if (/\.png$/i.test(d.name)) out.push([d.name]);
  }
  return out;
}

// dossier d'un type de sprite (ex. « overworld walk ») -> entrées
async function scanKind(dir, gender) {
  const entries = [];
  for (const parts of await walkDir(dir)) {
    if (parts.length < 2) continue;
    const cat = catOf(parts[0]);
    if (!cat) continue;
    const file = path.join(dir, ...parts);
    const item = parts.length >= 3 ? parts[parts.length - 2] : null;
    entries.push(parseEntry(cat, cat === 'base' ? null : item, file, gender));
  }
  return entries;
}

async function scanSources(sources) {
  const kinds = {}; // kind -> entrées
  const report = [];
  const add = (kind, list) => { kinds[kind] = (kinds[kind] || []).concat(list); };
  for (const src of sources || []) {
    if (!src || !src.path || !exists(src.path)) { report.push({ path: src && src.path, ok: false, error: 'dossier introuvable' }); continue; }
    if (src.kind && src.kind !== 'auto') {
      const list = await scanKind(src.path, '');
      add(src.kind, list);
      report.push({ path: src.path, ok: true, kinds: [src.kind], count: list.length });
      continue;
    }
    const found = [];
    let count = 0;
    for (const d of await fsp.readdir(src.path, { withFileTypes: true })) {
      if (!d.isDirectory()) continue;
      const kind = kindOf(d.name);
      if (!kind) continue;
      const list = await scanKind(path.join(src.path, d.name), folderGender(d.name));
      // dresseur de face (fille) : « classy bottom » y est le bas habillé des autres sprites (« formal bottom »)
      if (kind === 'front' && folderGender(d.name) === 'f') list.forEach((e) => { if (e.cat === 'bottom' && e.raw === 'classy bottom') e.key = 'formal bottom'; });
      add(kind, list); count += list.length;
      if (!found.includes(kind)) found.push(kind);
    }
    if (!found.length) {
      const kind = kindOf(path.basename(src.path));
      if (kind) { const list = await scanKind(src.path, ''); add(kind, list); count += list.length; found.push(kind); }
    }
    report.push({ path: src.path, ok: true, kinds: found, count });
  }
  return { kinds, report };
}

// ---------------------------------------------------------------------------
async function readConfig(projectPath) {
  const file = join(projectPath, CONFIG_FILE);
  let cfg = {};
  if (exists(file)) { try { cfg = JSON.parse((await fsp.readFile(file, 'utf8')).replace(/^﻿/, '')); } catch (e) { cfg = {}; } }
  if (!Array.isArray(cfg.sources) || !cfg.sources.length) cfg.sources = defaultSources();
  if (!Array.isArray(cfg.characters)) cfg.characters = [];
  return cfg;
}

let allowedRoots = [];
const handlers = {
  async getContext({ projectPath }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    const config = await readConfig(projectPath);
    const { kinds, report } = await scanSources(config.sources);
    allowedRoots = config.sources.map((s) => path.resolve(s.path));
    const existing = {};
    for (const dir of OUT_DIRS) {
      const full = join(projectPath, dir);
      existing[dir] = exists(full) ? (await fsp.readdir(full)).filter((n) => /\.png$/i.test(n)).map((n) => n.replace(/\.png$/i, '')) : [];
    }
    return { config, kinds, report, existing };
  },

  async readImages({ files }) {
    const out = {};
    for (const f of files || []) {
      const full = path.resolve(f);
      if (!allowedRoots.some((r) => full.startsWith(r + path.sep) || full === r) || !exists(full)) { out[f] = null; continue; }
      out[f] = 'data:image/png;base64,' + (await fsp.readFile(full)).toString('base64');
    }
    return out;
  },

  async saveConfig({ projectPath, config }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    const file = join(projectPath, CONFIG_FILE);
    await fsp.mkdir(path.dirname(file), { recursive: true });
    await fsp.writeFile(file, JSON.stringify({ sources: config.sources || [], characters: config.characters || [] }, null, 2) + '\n');
    return true;
  },

  // files : [{ dir: 'graphics/characters', name: 'hero_m_walk', dataUrl }]
  async exportSprites({ projectPath, files }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    const written = [];
    for (const f of files || []) {
      if (!OUT_DIRS.includes(f.dir) || !safeName(f.name) || !/^data:image\/png;base64,/.test(f.dataUrl || '')) continue;
      const rel = `${f.dir}/${safeName(f.name)}.png`;
      await fsp.mkdir(path.dirname(join(projectPath, rel)), { recursive: true });
      await fsp.writeFile(join(projectPath, rel), Buffer.from(f.dataUrl.split(',')[1], 'base64'));
      written.push(rel);
    }
    return { written };
  },

  async pickFolder({ defaultPath }) {
    const { dialog, BrowserWindow } = require('electron');
    const win = BrowserWindow.getFocusedWindow();
    const r = await dialog.showOpenDialog(win, { properties: ['openDirectory'], defaultPath: defaultPath || undefined, title: 'Dossier des pièces' });
    return r.canceled ? null : r.filePaths[0];
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([name, fn]) => {
    const channel = 'pj-generateur:' + name;
    try { ipcMain.removeHandler(channel); } catch (e) { /* rien */ }
    ipcMain.handle(channel, async (_event, payload) => {
      try { return { ok: true, value: await fn(payload || {}) }; } catch (e) { return { ok: false, error: String((e && e.message) || e) }; }
    });
  });
}

module.exports = { register, handlers, parseEntry, scanSources, canonItem };

try {
  const electron = require('electron');
  if (electron && electron.ipcMain) register(electron.ipcMain);
} catch (e) { /* hors Electron (tests) */ }
