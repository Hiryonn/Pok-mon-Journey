/* eslint-disable */
// =============================================================================
// Générateur d'icônes PSS — partie « processus principal » (Electron main)
// Chargé depuis .vite/build/index.js. Fournit les canaux IPC « pj-pss:* ».
// Lit les pièces dans graphics/icones_pss/pieces (catalogue : Data/configs/plugins/icone_pss_pieces.json,
// écrit par tools/pss-icones/decouper_planches.py) et écrit les icônes dans graphics/icones_pss/icones.
// Indépendant du générateur de personnages. Icônes gardées : Data/configs/pss_icones.json
// =============================================================================
'use strict';
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');

const CATALOG_FILE = 'Data/configs/plugins/icone_pss_pieces.json';
const SAVED_FILE = 'Data/configs/pss_icones.json';
const PIECES_DIR = 'graphics/icones_pss/pieces';
const ICONS_DIR = 'graphics/icones_pss/icones';

const join = (projectPath, rel) => path.join(projectPath, ...rel.split('/'));
const exists = (p) => { try { return fs.existsSync(p); } catch (e) { return false; } };
const safeName = (name) => String(name || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9_]+/g, '_').replace(/^_+|_+$/g, '');
const checkProject = (projectPath) => {
  if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
};
const readJson = async (file) => JSON.parse((await fsp.readFile(file, 'utf8')).replace(/^﻿/, ''));

async function readSaved(projectPath) {
  const file = join(projectPath, SAVED_FILE);
  if (!exists(file)) return [];
  try {
    const data = await readJson(file);
    return Array.isArray(data.icones) ? data.icones.filter((i) => i && i.name && i.spec) : [];
  } catch (e) { return []; }
}
async function writeSaved(projectPath, icones) {
  const file = join(projectPath, SAVED_FILE);
  await fsp.mkdir(path.dirname(file), { recursive: true });
  await fsp.writeFile(file, JSON.stringify({ icones }, null, 2) + '\n');
}

// tous les fichiers « catégorie/nom » cités par le catalogue
function catalogFiles(catalog) {
  const out = new Set();
  const add = (f) => { if (f && typeof f === 'string') out.add(f); };
  (catalog.series || []).forEach((s) => {
    [s.hauts, s.peau, s.sourcils, s.yeux, s.frange, s.chapeaux].forEach((l) => (l || []).forEach(add));
    (s.cheveux || []).forEach((st) => (st.couleurs || []).forEach((c) => { add(c.arriere); add(c.avant); }));
    (s.accessoires || []).forEach((g) => (g.fichiers || []).forEach(add));
  });
  return [...out];
}

const handlers = {
  async getContext({ projectPath }) {
    checkProject(projectPath);
    const catFile = join(projectPath, CATALOG_FILE);
    let catalog = null;
    if (exists(catFile)) { try { catalog = await readJson(catFile); } catch (e) { catalog = null; } }
    const iconsDir = join(projectPath, ICONS_DIR);
    const existing = exists(iconsDir) ? (await fsp.readdir(iconsDir)).filter((n) => /\.png$/i.test(n)).map((n) => n.replace(/\.png$/i, '')) : [];
    return { catalog, saved: await readSaved(projectPath), existing };
  },

  // { 'top/a_c01': 'data:image/png;base64,…', … } pour toutes les pièces du catalogue
  async readPieces({ projectPath }) {
    checkProject(projectPath);
    const catFile = join(projectPath, CATALOG_FILE);
    if (!exists(catFile)) return {};
    const out = {};
    for (const f of catalogFiles(await readJson(catFile))) {
      const full = join(projectPath, `${PIECES_DIR}/${f}.png`);
      // sécurité : le fichier doit rester dans le dossier des pièces
      if (!path.resolve(full).startsWith(path.resolve(join(projectPath, PIECES_DIR)) + path.sep)) continue;
      out[f] = exists(full) ? 'data:image/png;base64,' + (await fsp.readFile(full)).toString('base64') : null;
    }
    return out;
  },

  // Écrit graphics/icones_pss/icones/<nom>.png (40x40) et garde le réglage dans la liste des icônes
  async saveIcon({ projectPath, name, spec, dataUrl, overwrite }) {
    checkProject(projectPath);
    const clean = safeName(name);
    if (!clean) throw new Error('Nom d\'icône invalide.');
    if (!/^data:image\/png;base64,/.test(dataUrl || '')) throw new Error('Image invalide.');
    const rel = `${ICONS_DIR}/${clean}.png`;
    const full = join(projectPath, rel);
    if (exists(full) && !overwrite) return { exists: true, name: clean };
    await fsp.mkdir(path.dirname(full), { recursive: true });
    await fsp.writeFile(full, Buffer.from(dataUrl.split(',')[1], 'base64'));
    const list = (await readSaved(projectPath)).filter((i) => i.name !== clean);
    list.push({ name: clean, spec });
    await writeSaved(projectPath, list);
    return { written: rel, name: clean };
  },

  // Retire une icône de la liste (le fichier .png reste dans le projet)
  async forgetIcon({ projectPath, name }) {
    checkProject(projectPath);
    await writeSaved(projectPath, (await readSaved(projectPath)).filter((i) => i.name !== name));
    return true;
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([name, fn]) => {
    const channel = 'pj-pss:' + name;
    try { ipcMain.removeHandler(channel); } catch (e) { /* rien */ }
    ipcMain.handle(channel, async (_event, payload) => {
      try { return { ok: true, value: await fn(payload || {}) }; } catch (e) { return { ok: false, error: String((e && e.message) || e) }; }
    });
  });
}

module.exports = { register, handlers, catalogFiles, safeName };

try {
  const electron = require('electron');
  if (electron && electron.ipcMain) register(electron.ipcMain);
} catch (e) { /* hors Electron (tests) */ }
