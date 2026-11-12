/* eslint-disable */
// =============================================================================
// Cartes (éditeur de cartes façon Tiled de Pokémon Studio Extra) — partie « processus principal » (Electron main)
// Chargé depuis .vite/build/index.js. Fournit les canaux IPC « pj-cartes:* ».
// Lit et écrit uniquement dans Data/Tiled du projet (cartes .tmx, tilesets .tsx, images des tilesets).
// Les fichiers restent au format de Tiled : Studio les convertit comme d'habitude (« Mettre à jour les cartes »).
// =============================================================================
'use strict';
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');

const MIME = { '.png': 'image/png', '.gif': 'image/gif', '.bmp': 'image/bmp', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp' };
const exists = (p) => { try { return fs.existsSync(p); } catch (e) { return false; } };
const tiledDir = (projectPath) => {
  if (!projectPath) throw new Error('Aucun projet ouvert.');
  return path.join(projectPath, 'Data', 'Tiled');
};
// chemin relatif à Data/Tiled -> chemin complet (refuse tout ce qui sort de Data/Tiled)
function resolve(projectPath, rel) {
  const root = tiledDir(projectPath);
  const full = path.resolve(root, String(rel || '').replace(/\\/g, '/'));
  const r = path.relative(root, full);
  if (!r || r.startsWith('..') || path.isAbsolute(r)) throw new Error('Seuls les fichiers de Data/Tiled du projet sont accessibles.');
  return full;
}
const backedUp = new Set();

const handlers = {
  async getContext({ projectPath }) {
    if (!projectPath) return { root: '', rootExists: false, maps: [] };
    const root = tiledDir(projectPath);
    if (!exists(root)) return { root, rootExists: false, maps: [] };
    const mapsDir = path.join(root, 'Maps');
    let maps = [];
    try {
      maps = (await fsp.readdir(mapsDir)).filter((f) => f.toLowerCase().endsWith('.tmx'))
        .sort((a, b) => a.localeCompare(b, 'fr', { numeric: true })).map((f) => ({ name: f.replace(/\.tmx$/i, ''), path: 'Maps/' + f }));
    } catch (e) { /* pas de cartes */ }
    return { root, rootExists: true, maps };
  },
  async readText({ projectPath, file }) {
    return (await fsp.readFile(resolve(projectPath, file), 'utf8')).replace(/^﻿/, '');
  },
  async readImage({ projectPath, file }) {
    const full = resolve(projectPath, file);
    const mime = MIME[path.extname(full).toLowerCase()];
    if (!mime) throw new Error('Image non prise en charge : ' + file);
    return 'data:' + mime + ';base64,' + (await fsp.readFile(full)).toString('base64');
  },
  async mtime({ projectPath, file }) {
    try { return (await fsp.stat(resolve(projectPath, file))).mtimeMs; } catch (e) { return 0; }
  },
  async writeText({ projectPath, file, text }) {
    const full = resolve(projectPath, file);
    if (!/\.(tmx|tsx)$/i.test(full)) throw new Error('Seules les cartes (.tmx) et les tilesets (.tsx) sont enregistrés.');
    // copie de sécurité au premier enregistrement de la session (Data/Tiled/.backup)
    if (exists(full) && !backedUp.has(full)) {
      const dir = path.join(tiledDir(projectPath), '.backup');
      await fsp.mkdir(dir, { recursive: true });
      await fsp.copyFile(full, path.join(dir, path.basename(full)));
      backedUp.add(full);
    }
    const tmp = full + '.tmp';
    await fsp.writeFile(tmp, text, 'utf8');
    await fsp.rename(tmp, full);
    return (await fsp.stat(full)).mtimeMs;
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([name, fn]) => {
    const channel = 'pj-cartes:' + name;
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
