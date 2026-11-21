/* eslint-disable */
// =============================================================================
// Tenues (wardrobe) — partie « processus principal » (Electron main)
// Chargé depuis .vite/build/index.js. Fournit les canaux IPC « pj-wardrobe:* ».
// Les tenues sont gardées dans Data/configs/plugins/wardrobe.json (lu par le plugin wardrobe en jeu).
// Peut aussi créer l'objet Studio d'une tenue (Data/Studio/items, icône, textes).
// =============================================================================
'use strict';
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');

const OUTFITS_FILE = 'Data/configs/plugins/wardrobe.json';
const PIECES_FILE = 'Data/configs/plugins/generateur_pieces.json';
const ITEMS_DIR = 'Data/Studio/items';
const NAMES_CSV = 'Data/Text/Dialogs/100012.csv';
const DESCRIPTIONS_CSV = 'Data/Text/Dialogs/100013.csv';
const ICONS_DIR = 'graphics/icons';
const IMAGE_DIRS = ['graphics/characters', 'graphics/pictures', 'graphics/icons'];
const ITEM_SOCKET = 5; // objets rares
const CATS = ['hair', 'top', 'bottom', 'hat', 'bag'];

const join = (projectPath, rel) => path.join(projectPath, ...rel.split('/'));
const exists = (p) => { try { return fs.existsSync(p); } catch (e) { return false; } };
const checkProject = (projectPath) => {
  if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
};
const readJson = async (file) => JSON.parse((await fsp.readFile(file, 'utf8')).replace(/^﻿/, ''));
const isSymbol = (s) => /^[a-z0-9_]{1,60}$/.test(String(s || ''));
const listPngs = async (dir) => (exists(dir) ? (await fsp.readdir(dir)).filter((n) => /\.png$/i.test(n)).map((n) => n.replace(/\.png$/i, '')).sort() : []);

// --- CSV : on ajoute des lignes à la fin, sans réécrire les autres ---------------------------
const csvField = (v) => (/[",\n\r]/.test(v) ? '"' + String(v).replace(/"/g, '""') + '"' : String(v));
// nombre d'enregistrements d'un CSV (les champs entre guillemets peuvent contenir des retours à la ligne)
function csvRecordCount(text) {
  let count = 0, inQuotes = false, any = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (c === '"') { inQuotes = !inQuotes; any = true; } else if (c === '\n' && !inQuotes) { count++; any = false; } else if (c !== '\r') any = true;
  }
  return count + (any ? 1 : 0);
}
// Ajoute la ligne de l'objet d'identifiant `id` (ligne n° id + 1 après l'en-tête) : 'added', 'exists' (déjà là) ou 'misaligned'
async function addTextRow(projectPath, rel, id, fr, en) {
  const file = join(projectPath, rel);
  if (!exists(file)) return 'missing';
  let text = await fsp.readFile(file, 'utf8');
  const count = csvRecordCount(text);
  const wanted = id + 1; // en-tête + id lignes (0 à id - 1) avant celle-ci
  if (count > wanted) return 'exists';
  if (count < wanted) return 'misaligned';
  if (!text.endsWith('\n')) text += '\n';
  // colonnes : en, fr, it, de, es, ko, kana (les langues sans traduction reprennent l'anglais)
  const row = [en, fr, en, en, en, en, en].map(csvField).join(',');
  await fsp.writeFile(file, text + row + '\n');
  return 'added';
}

// --- Objets ----------------------------------------------------------------------------------
async function itemInfo(projectPath) {
  const dir = join(projectPath, ITEMS_DIR);
  const symbols = exists(dir) ? (await fsp.readdir(dir)).filter((n) => /\.json$/i.test(n)).map((n) => n.replace(/\.json$/i, '')).sort() : [];
  return symbols;
}
async function maxItemId(projectPath) {
  const dir = join(projectPath, ITEMS_DIR);
  let max = 0;
  for (const n of await itemInfo(projectPath)) {
    try { max = Math.max(max, Number((await readJson(path.join(dir, n + '.json'))).id) || 0); } catch (e) { /* ignoré */ }
  }
  return max;
}

// --- Catalogue des pièces du générateur (pour les tenues à pièces) ---------------------------
async function readCatalog(projectPath) {
  const file = join(projectPath, PIECES_FILE);
  if (!exists(file)) return null;
  try {
    const data = await readJson(file);
    const kind = data.kinds && (data.kinds.walk ? 'walk' : Object.keys(data.kinds)[0]);
    const entries = ((kind && data.kinds[kind]) || []).filter((e) => CATS.includes(e.cat));
    const out = {};
    entries.forEach((e) => {
      const list = (out[e.cat] = out[e.cat] || {});
      const piece = (list[e.key] = list[e.key] || { key: e.key, genders: [], colors: [] });
      if (!piece.genders.includes(e.gender || '')) piece.genders.push(e.gender || '');
      if (!piece.colors.includes(e.color || '')) piece.colors.push(e.color || '');
    });
    const cats = {};
    CATS.forEach((c) => { cats[c] = Object.values(out[c] || {}); });
    return { cats, labels: data.labels || {}, colorLabels: data.color_labels || {}, colorHex: data.color_hex || {} };
  } catch (e) { return null; }
}

function cleanOutfit(o) {
  const item = String(o && o.item || '');
  if (!isSymbol(item)) throw new Error(`Objet invalide : « ${item} » (minuscules, chiffres et _ seulement).`);
  const text = (v) => { const a = Array.isArray(v) ? v : [v]; return [String(a[0] || ''), String(a[1] || a[0] || '')]; };
  const out = { item, name: text(o.name || item), description: text(o.description || '') };
  if (o.gender === 'm' || o.gender === 'f') out.gender = o.gender;
  if (o.sprites && o.sprites.charset) {
    out.sprites = { charset: String(o.sprites.charset) };
    if (o.sprites.front) out.sprites.front = String(o.sprites.front);
  }
  if (o.pieces && typeof o.pieces === 'object') {
    const pieces = {};
    CATS.forEach((c) => {
      if (!(c in o.pieces) || o.pieces[c] === undefined) return;
      const p = o.pieces[c];
      pieces[c] = p && p.key ? { key: String(p.key), color: String(p.color || '') } : null;
    });
    if (Object.keys(pieces).length) out.pieces = pieces;
  }
  return out;
}

const handlers = {
  async getContext({ projectPath }) {
    checkProject(projectPath);
    let outfits = [];
    const file = join(projectPath, OUTFITS_FILE);
    if (exists(file)) { try { outfits = (await readJson(file)).outfits || []; } catch (e) { outfits = []; } }
    return {
      outfits,
      items: await itemInfo(projectPath),
      characters: await listPngs(join(projectPath, 'graphics/characters')),
      pictures: await listPngs(join(projectPath, 'graphics/pictures')),
      catalog: await readCatalog(projectPath),
    };
  },

  // Une image du projet en « data URL » (seulement dans graphics/characters, pictures et icons)
  async readImage({ projectPath, dir, name }) {
    checkProject(projectPath);
    if (!IMAGE_DIRS.includes(dir) || !/^[^\\/:*?"<>|]+$/.test(String(name || ''))) throw new Error('Image refusée.');
    const full = join(projectPath, `${dir}/${name}.png`);
    if (!exists(full)) return null;
    return 'data:image/png;base64,' + (await fsp.readFile(full)).toString('base64');
  },

  async saveOutfits({ projectPath, outfits }) {
    checkProject(projectPath);
    const list = (outfits || []).map(cleanOutfit);
    const seen = new Set();
    list.forEach((o) => { if (seen.has(o.item)) throw new Error(`L'objet « ${o.item} » est utilisé par deux tenues.`); seen.add(o.item); });
    const file = join(projectPath, OUTFITS_FILE);
    await fsp.mkdir(path.dirname(file), { recursive: true });
    await fsp.writeFile(file, JSON.stringify({ outfits: list }, null, 2) + '\n');
    return { written: OUTFITS_FILE, count: list.length };
  },

  // Crée l'objet Studio de la tenue : Data/Studio/items/<symbole>.json, icône (32x32), nom et description (français / anglais)
  async createItem({ projectPath, symbol, name, description, iconDataUrl }) {
    checkProject(projectPath);
    if (!isSymbol(symbol)) throw new Error('Nom d\'objet invalide (minuscules, chiffres et _ seulement).');
    const itemFile = join(projectPath, `${ITEMS_DIR}/${symbol}.json`);
    if (exists(itemFile)) throw new Error(`L'objet « ${symbol} » existe déjà.`);
    const id = (await maxItemId(projectPath)) + 1;
    const item = {
      id, dbSymbol: symbol, icon: symbol, price: 0, socket: ITEM_SOCKET, position: 0, isBattleUsable: false, isMapUsable: false,
      isLimited: false, isHoldable: false, isAllowingMega: false, flingPower: 0, klass: 'Item', isBerry: false,
    };
    await fsp.mkdir(path.dirname(itemFile), { recursive: true });
    await fsp.writeFile(itemFile, JSON.stringify(item, null, 2));
    const warnings = [];
    if (/^data:image\/png;base64,/.test(iconDataUrl || '')) {
      const icon = join(projectPath, `${ICONS_DIR}/${symbol}.png`);
      await fsp.mkdir(path.dirname(icon), { recursive: true });
      await fsp.writeFile(icon, Buffer.from(iconDataUrl.split(',')[1], 'base64'));
    } else warnings.push('Pas d\'icône : choisis un charset pour qu\'elle soit créée (première case).');
    const names = Array.isArray(name) ? name : [name, name];
    const descriptions = Array.isArray(description) ? description : [description, description];
    const a = await addTextRow(projectPath, NAMES_CSV, id, names[0] || symbol, names[1] || names[0] || symbol);
    const b = await addTextRow(projectPath, DESCRIPTIONS_CSV, id, descriptions[0] || '', descriptions[1] || descriptions[0] || '');
    if (a !== 'added' || b !== 'added') warnings.push(`Textes de l'objet non ajoutés (${a} / ${b}) : ajoute la ligne ${id + 2} de 100012.csv et 100013.csv dans Studio.`);
    return { id, symbol, warnings };
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([name, fn]) => {
    const channel = 'pj-wardrobe:' + name;
    try { ipcMain.removeHandler(channel); } catch (e) { /* rien */ }
    ipcMain.handle(channel, async (_event, payload) => {
      try { return { ok: true, value: await fn(payload || {}) }; } catch (e) { return { ok: false, error: String((e && e.message) || e) }; }
    });
  });
}

module.exports = { register, handlers, csvRecordCount, addTextRow, cleanOutfit };

try {
  const electron = require('electron');
  if (electron && electron.ipcMain) register(electron.ipcMain);
} catch (e) { /* hors Electron (tests) */ }
