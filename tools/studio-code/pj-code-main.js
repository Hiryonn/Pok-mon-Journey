/* eslint-disable */
// =============================================================================
// Code (éditeur de code de Pokémon Studio Extra) — partie « processus principal » (Electron main)
// Chargé depuis .vite/build/index.js. Fournit les canaux IPC « pj-code:* ».
// Lit et écrit uniquement les fichiers du dossier du projet ouvert.
// =============================================================================
'use strict';
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');

const IMAGES = { '.png': 'image/png', '.gif': 'image/gif', '.bmp': 'image/bmp', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.ico': 'image/x-icon', '.svg': 'image/svg+xml' };
// dossiers ignorés par l'index (Ctrl+P) et la recherche dans les fichiers
const SKIP_DIRS = new Set(['.git', 'node_modules', '.vs', '.idea', '__pycache__', '.backup', '.pj-backup']);
// jamais lus par la recherche (binaires connus)
const BINARY_EXT = new Set(['.rxdata', '.dat', '.ogg', '.mp3', '.wav', '.mid', '.midi', '.flac', '.ttf', '.otf', '.exe', '.dll', '.so', '.zip', '.7z', '.rar', '.gz',
  '.psd', '.ase', '.aseprite', '.mp4', '.webm', '.avi', '.pdf', '.bin', '.pyc', '.o', '.obj', '.lib', '.class', '.jar', '.ico', '.cur', '.ani', '.rvdata2', '.dmp', '.mega']);
const MAX_TEXT = 8 * 1024 * 1024;
const MAX_SEARCH_FILE = 2 * 1024 * 1024;
const exists = (p) => { try { return fs.existsSync(p); } catch (e) { return false; } };
const toRel = (root, full) => path.relative(root, full).split(path.sep).join('/');
const sortEntries = (a, b) => (a.dir === b.dir ? a.name.localeCompare(b.name, 'fr', { numeric: true, sensitivity: 'base' }) : a.dir ? -1 : 1);

function rootOf(projectPath) {
  if (!projectPath) throw new Error('Aucun projet ouvert.');
  return path.resolve(projectPath);
}
// chemin relatif au projet -> chemin complet (refuse tout ce qui sort du projet) ; '' = racine si allowRoot
function resolve(projectPath, rel, allowRoot) {
  const root = rootOf(projectPath);
  const full = path.resolve(root, String(rel || '').replace(/\\/g, '/'));
  const r = path.relative(root, full);
  if ((!r && !allowRoot) || r.startsWith('..') || path.isAbsolute(r)) throw new Error('Seuls les fichiers du projet sont accessibles.');
  return full;
}
// texte ou binaire : pas d'octet nul dans les 8 premiers Ko
function looksBinary(buf) {
  const n = Math.min(buf.length, 8192);
  for (let i = 0; i < n; i++) if (buf[i] === 0) return true;
  return false;
}
function decode(buf) {
  if (buf.length >= 3 && buf[0] === 0xef && buf[1] === 0xbb && buf[2] === 0xbf) return { text: buf.slice(3).toString('utf8'), encoding: 'utf8bom' };
  if (buf.length >= 2 && buf[0] === 0xff && buf[1] === 0xfe) return { text: buf.slice(2).toString('utf16le'), encoding: 'utf16le' };
  return { text: buf.toString('utf8'), encoding: 'utf8' };
}
function encode(text, encoding) {
  if (encoding === 'utf8bom') return Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), Buffer.from(text, 'utf8')]);
  if (encoding === 'utf16le') return Buffer.concat([Buffer.from([0xff, 0xfe]), Buffer.from(text, 'utf16le')]);
  return Buffer.from(text, 'utf8');
}
async function walk(dir, root, out, limit) {
  let list;
  try { list = await fsp.readdir(dir, { withFileTypes: true }); } catch (e) { return; }
  for (const d of list) {
    if (out.length >= limit) return;
    const full = path.join(dir, d.name);
    if (d.isDirectory()) { if (!SKIP_DIRS.has(d.name)) await walk(full, root, out, limit); } else if (d.isFile()) out.push(toRel(root, full));
  }
}
const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const globToRe = (g) => new RegExp('(^|/)' + escapeRe(g.trim()).replace(/\\\*\\\*/g, '.*').replace(/\\\*/g, '[^/]*').replace(/\\\?/g, '[^/]') + '($|/)', 'i');

const handlers = {
  async getContext({ projectPath }) {
    if (!projectPath) return { root: '', name: '', rootExists: false };
    const root = rootOf(projectPath);
    return { root, name: path.basename(root), rootExists: exists(root) };
  },
  // contenu d'un dossier (un niveau)
  async list({ projectPath, dir }) {
    const full = resolve(projectPath, dir, true);
    const root = rootOf(projectPath);
    const list = await fsp.readdir(full, { withFileTypes: true });
    return list.filter((d) => d.isDirectory() || d.isFile()).map((d) => ({ name: d.name, path: toRel(root, path.join(full, d.name)), dir: d.isDirectory() })).sort(sortEntries);
  },
  async read({ projectPath, file }) {
    const full = resolve(projectPath, file);
    const st = await fsp.stat(full);
    if (st.isDirectory()) throw new Error("C'est un dossier.");
    const ext = path.extname(full).toLowerCase();
    if (IMAGES[ext]) return { kind: 'image', size: st.size, mtime: st.mtimeMs, dataUrl: 'data:' + IMAGES[ext] + ';base64,' + (await fsp.readFile(full)).toString('base64') };
    if (st.size > MAX_TEXT) return { kind: 'binary', size: st.size, mtime: st.mtimeMs, reason: 'Fichier trop gros pour l’éditeur (' + Math.round(st.size / 1048576) + ' Mo).' };
    const buf = await fsp.readFile(full);
    if (looksBinary(buf) && !(buf[0] === 0xff && buf[1] === 0xfe)) return { kind: 'binary', size: st.size, mtime: st.mtimeMs, reason: 'Fichier binaire (données du jeu, image…) : il ne s’ouvre pas comme du texte.' };
    const { text, encoding } = decode(buf);
    return { kind: 'text', text, encoding, size: st.size, mtime: st.mtimeMs };
  },
  async stat({ projectPath, file }) {
    const full = resolve(projectPath, file);
    if (!exists(full)) return null;
    const st = await fsp.stat(full);
    return { mtime: st.mtimeMs, size: st.size, dir: st.isDirectory() };
  },
  // enregistre ; expectedMtime : refuse si le fichier a changé sur le disque entre-temps (sauf force)
  async write({ projectPath, file, text, encoding, expectedMtime, force }) {
    const full = resolve(projectPath, file);
    if (!force && expectedMtime && exists(full)) {
      const st = await fsp.stat(full);
      if (Math.abs(st.mtimeMs - expectedMtime) > 1) return { conflict: true, mtime: st.mtimeMs };
    }
    await fsp.mkdir(path.dirname(full), { recursive: true });
    await fsp.writeFile(full, encode(String(text), encoding || 'utf8'));
    return { mtime: (await fsp.stat(full)).mtimeMs };
  },
  async create({ projectPath, file, dir }) {
    const full = resolve(projectPath, file || dir);
    if (exists(full)) throw new Error('Ce nom existe déjà.');
    if (dir) await fsp.mkdir(full, { recursive: true });
    else { await fsp.mkdir(path.dirname(full), { recursive: true }); await fsp.writeFile(full, ''); }
    return true;
  },
  async rename({ projectPath, from, to }) {
    const a = resolve(projectPath, from); const b = resolve(projectPath, to);
    if (exists(b)) throw new Error('Ce nom existe déjà.');
    await fsp.mkdir(path.dirname(b), { recursive: true });
    await fsp.rename(a, b);
    return true;
  },
  // suppression : envoyé à la corbeille de Windows (récupérable)
  async trash({ projectPath, file }) {
    const full = resolve(projectPath, file);
    const { shell } = require('electron');
    await shell.trashItem(full);
    return true;
  },
  async reveal({ projectPath, file }) {
    const { shell } = require('electron');
    shell.showItemInFolder(resolve(projectPath, file, true));
    return true;
  },
  // tous les fichiers du projet (Ctrl+P)
  async index({ projectPath }) {
    const root = rootOf(projectPath);
    const out = [];
    await walk(root, root, out, 400000);
    return out;
  },
  // recherche dans les fichiers (Ctrl+Maj+F)
  async search({ projectPath, query, regex, caseSensitive, word, include, exclude, max }) {
    if (!query) return { results: [], files: 0, truncated: false };
    const root = rootOf(projectPath);
    let src = regex ? query : escapeRe(query);
    if (word) src = '\\b' + src + '\\b';
    const re = new RegExp(src, caseSensitive ? 'g' : 'gi');
    const inc = String(include || '').split(',').map((s) => s.trim()).filter(Boolean).map(globToRe);
    const exc = String(exclude || '').split(',').map((s) => s.trim()).filter(Boolean).map(globToRe);
    const files = [];
    await walk(root, root, files, 400000);
    const limit = max || 3000;
    const todo = files.filter((rel) => {
      if (inc.length && !inc.some((r) => r.test(rel))) return false;
      if (exc.some((r) => r.test(rel))) return false;
      const ext = path.extname(rel).toLowerCase();
      return !IMAGES[ext] && !BINARY_EXT.has(ext);
    });
    const found = new Map(); let count = 0; let truncated = false; let next = 0;
    // fichiers lus en parallèle (beaucoup de petits .json dans Data)
    const worker = async () => {
      while (next < todo.length && !truncated) {
        const rel = todo[next++];
        const full = path.join(root, rel);
        let buf;
        try { const st = await fsp.stat(full); if (st.size > MAX_SEARCH_FILE) continue; buf = await fsp.readFile(full); } catch (e) { continue; }
        if (looksBinary(buf)) continue;
        const lines = decode(buf).text.split(/\r?\n/);
        const hits = [];
        const fre = new RegExp(re.source, re.flags);
        for (let i = 0; i < lines.length && !truncated; i++) {
          fre.lastIndex = 0;
          let m;
          while ((m = fre.exec(lines[i]))) {
            const long = lines[i].length > 400;
            hits.push({ line: i + 1, col: m.index + 1, len: m[0].length, text: long ? lines[i].slice(Math.max(0, m.index - 100), m.index + 300) : lines[i], off: long ? Math.max(0, m.index - 100) : 0 });
            if (!m[0].length) fre.lastIndex++;
            if (++count >= limit) { truncated = true; break; }
          }
        }
        if (hits.length) found.set(rel, hits);
      }
    };
    await Promise.all(Array.from({ length: 48 }, worker));
    const results = [...found.keys()].sort((a, b) => a.localeCompare(b, 'fr', { numeric: true })).map((file) => ({ file, hits: found.get(file) }));
    return { results, count, truncated };
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([name, fn]) => {
    const channel = 'pj-code:' + name;
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
