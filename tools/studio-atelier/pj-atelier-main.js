/* eslint-disable */
// =============================================================================
// Atelier (éditeur d'images de Pokémon Studio Extra) — partie « processus principal » (Electron main)
// Chargé depuis .vite/build/index.js. Fournit les canaux IPC « pj-atelier:* ».
// Lit et écrit uniquement les images du dossier graphics du projet.
// =============================================================================
'use strict';
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');

const READABLE = { '.png': 'image/png', '.gif': 'image/gif', '.bmp': 'image/bmp', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp' };
const exists = (p) => { try { return fs.existsSync(p); } catch (e) { return false; } };
const graphicsDir = (projectPath) => {
  if (!projectPath) throw new Error('Aucun projet ouvert.');
  return path.join(projectPath, 'graphics');
};
// chemin relatif à graphics -> chemin complet (refuse tout ce qui sort de graphics)
function resolve(projectPath, rel) {
  const root = graphicsDir(projectPath);
  const full = path.resolve(root, String(rel || '').replace(/\\/g, '/'));
  const r = path.relative(root, full);
  if (!r || r.startsWith('..') || path.isAbsolute(r)) throw new Error('Seules les images du dossier graphics du projet sont accessibles.');
  return full;
}
async function tree(dir, root) {
  const out = [];
  let list;
  try { list = await fsp.readdir(dir, { withFileTypes: true }); } catch (e) { return out; }
  list.sort((a, b) => (a.isDirectory() === b.isDirectory() ? a.name.localeCompare(b.name, 'fr', { numeric: true }) : a.isDirectory() ? -1 : 1));
  for (const d of list) {
    const full = path.join(dir, d.name);
    const rel = path.relative(root, full).split(path.sep).join('/');
    if (d.isDirectory()) out.push({ name: d.name, path: rel, dir: true, children: await tree(full, root) });
    else if (READABLE[path.extname(d.name).toLowerCase()]) out.push({ name: d.name, path: rel });
  }
  return out;
}

const handlers = {
  async getContext({ projectPath }) {
    if (!projectPath) return { root: '', rootExists: false, tree: [] };
    const root = graphicsDir(projectPath);
    return { root, rootExists: exists(root), tree: exists(root) ? await tree(root, root) : [] };
  },
  async read({ projectPath, file }) {
    const full = resolve(projectPath, file);
    const mime = READABLE[path.extname(full).toLowerCase()];
    if (!mime) throw new Error('Format non pris en charge.');
    return 'data:' + mime + ';base64,' + (await fsp.readFile(full)).toString('base64');
  },
  async exists({ projectPath, file }) {
    return exists(resolve(projectPath, file));
  },
  async write({ projectPath, file, dataUrl }) {
    const full = resolve(projectPath, file);
    if (path.extname(full).toLowerCase() !== '.png') throw new Error("L'atelier enregistre en PNG.");
    const m = /^data:image\/png;base64,(.*)$/.exec(String(dataUrl || ''));
    if (!m) throw new Error('Image invalide.');
    await fsp.mkdir(path.dirname(full), { recursive: true });
    await fsp.writeFile(full, Buffer.from(m[1], 'base64'));
    return true;
  },
  async mkdir({ projectPath, dir }) {
    await fsp.mkdir(resolve(projectPath, dir), { recursive: true });
    return true;
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([name, fn]) => {
    const channel = 'pj-atelier:' + name;
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
