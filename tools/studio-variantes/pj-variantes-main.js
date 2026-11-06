/* eslint-disable */
// =============================================================================
// Variantes (plugin « variantes ») — partie « processus principal » (Electron main)
// Chargé depuis .vite/build/index.js. Fournit les canaux IPC « pj-variantes:* ».
// Lit / écrit :
//   Data/configs/plugins/variantes.json                 (taux, dégradés Argenté / Doré, recolorations Radiant)
//   graphics/pokedex/pokefrontradiant|pokebackradiant|pokeiconradiant/<sprite normal>.png
// À chaque enregistrement, le plugin installé (scripts/00000 Plugins/<n> variantes) reçoit les scripts à jour
// et scripts/variantes.psdkplug est reconstruit.
// =============================================================================
'use strict';
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');

const CONFIG_FILE = 'Data/configs/plugins/variantes.json';
const PLUGIN_NAME = 'variantes';
const PLUGIN_SOURCE = 'scripts/variantes';
const PLUGINS_INSTALLED = 'scripts/00000 Plugins';
const DIRS = {
  front: ['graphics/pokedex/pokefront', 'graphics/pokedex/pokefrontshiny', 'graphics/pokedex/pokefrontradiant'],
  back: ['graphics/pokedex/pokeback', 'graphics/pokedex/pokebackshiny', 'graphics/pokedex/pokebackradiant'],
  icon: ['graphics/pokedex/pokeicon', 'graphics/pokedex/pokeiconshiny', 'graphics/pokedex/pokeiconradiant'],
};

const join = (projectPath, rel) => path.join(projectPath, ...rel.split('/'));
const exists = (p) => { try { return fs.existsSync(p); } catch (e) { return false; } };
const norm = (b) => b.toString('utf8').replace(/^﻿/, '').replace(/\r\n/g, '\n');

function parseCsv(text) {
  const rows = []; let row = []; let cur = ''; let q = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (q) {
      if (ch === '"') { if (text[i + 1] === '"') { cur += '"'; i++; } else q = false; } else cur += ch;
    } else if (ch === '"') q = true;
    else if (ch === ',') { row.push(cur); cur = ''; }
    else if (ch === '\n' || ch === '\r') { if (ch === '\r' && text[i + 1] === '\n') i++; row.push(cur); rows.push(row); row = []; cur = ''; }
    else cur += ch;
  }
  if (cur !== '' || row.length) { row.push(cur); rows.push(row); }
  return rows;
}

async function writeAtomic(file, content) {
  await fsp.mkdir(path.dirname(file), { recursive: true });
  if (exists(file) && !exists(file + '.bak')) await fsp.copyFile(file, file + '.bak');
  const tmp = file + '.tmp';
  await fsp.writeFile(tmp, content);
  await fsp.rename(tmp, file);
}

const safeName = (name) => String(name || '').replace(/[\\/:*?"<>|]/g, '').replace(/^\.+/, '');

// Pokémon de Studio avec les noms des sprites de chaque forme
async function creatures(projectPath) {
  const dir = join(projectPath, 'Data/Studio/pokemon');
  if (!exists(dir)) return [];
  const textFile = join(projectPath, 'Data/Text/Dialogs/100000.csv');
  const texts = exists(textFile) ? parseCsv(fs.readFileSync(textFile, 'utf8').replace(/^﻿/, '')) : null;
  const col = texts ? Math.max(0, texts[0].indexOf('fr') >= 0 ? texts[0].indexOf('fr') : texts[0].indexOf('en')) : 0;
  const out = [];
  for (const f of (await fsp.readdir(dir)).filter((n) => n.endsWith('.json'))) {
    try {
      const d = JSON.parse(await fsp.readFile(path.join(dir, f), 'utf8'));
      if (!d.dbSymbol || d.dbSymbol === '__undef__') continue;
      const row = texts && texts[d.id + 1];
      out.push({
        id: d.id, dbSymbol: d.dbSymbol, name: (row && row[col]) || d.dbSymbol,
        forms: (d.forms || []).map((fm) => ({ form: fm.form, resources: fm.resources || {} })),
      });
    } catch (e) { /* ignoré */ }
  }
  return out.sort((a, b) => a.id - b.id);
}

// noms (sans extension) des sprites Radiants déjà faits, par sorte
async function radiantFiles(projectPath) {
  const out = {};
  for (const [kind, dirs] of Object.entries(DIRS)) {
    const dir = join(projectPath, dirs[2]);
    out[kind] = exists(dir) ? (await fsp.readdir(dir)).filter((n) => n.toLowerCase().endsWith('.png')).map((n) => n.slice(0, -4)) : [];
  }
  return out;
}

// ---------------------------------------------------------------------------
// Plugin : scripts installés + paquet .psdkplug
// ---------------------------------------------------------------------------
async function listFilesDeep(dir, ext) {
  if (!exists(dir)) return [];
  const out = [];
  const walk = async (d, prefix) => {
    for (const ent of await fsp.readdir(d, { withFileTypes: true })) {
      if (ent.isDirectory()) await walk(path.join(d, ent.name), prefix + ent.name + '/');
      else if (ent.name.toLowerCase().endsWith(ext)) out.push(prefix + ent.name);
    }
  };
  await walk(dir, '');
  return out.sort();
}

function installedPluginDir(projectPath) {
  const base = join(projectPath, PLUGINS_INSTALLED);
  if (!exists(base)) return null;
  const name = fs.readdirSync(base).find((n) => new RegExp(`^\\d+ ${PLUGIN_NAME}$`).test(n));
  return name ? path.join(base, name) : null;
}

async function pluginStatus(projectPath) {
  const source = join(projectPath, `${PLUGIN_SOURCE}/scripts`);
  if (!exists(source)) return { source: false, installed: null, outdated: [], stale: [] };
  const dir = installedPluginDir(projectPath);
  const files = await listFilesDeep(source, '.rb');
  if (!dir) return { source: true, installed: null, outdated: files, stale: [] };
  const outdated = [];
  for (const rel of files) {
    const dest = path.join(dir, ...rel.split('/'));
    if (!exists(dest) || norm(await fsp.readFile(dest)) !== norm(await fsp.readFile(path.join(source, ...rel.split('/'))))) outdated.push(rel);
  }
  const stale = (await listFilesDeep(dir, '.rb')).filter((rel) => !files.includes(rel));
  return { source: true, installed: path.relative(projectPath, dir).split(path.sep).join('/'), outdated, stale };
}

async function syncInstalledPlugin(projectPath) {
  const st = await pluginStatus(projectPath);
  if (!st.source || !st.installed) return { ...st, copied: [], removed: [] };
  const source = join(projectPath, `${PLUGIN_SOURCE}/scripts`);
  const dir = join(projectPath, st.installed);
  for (const rel of st.outdated) {
    const dest = path.join(dir, ...rel.split('/'));
    await fsp.mkdir(path.dirname(dest), { recursive: true });
    await fsp.copyFile(path.join(source, ...rel.split('/')), dest);
  }
  for (const rel of st.stale) await fsp.unlink(path.join(dir, ...rel.split('/')));
  return { ...st, copied: st.outdated, removed: st.stale, outdated: [], stale: [] };
}

function buildPluginPackage(projectPath) {
  return new Promise((resolve) => {
    if (process.platform !== 'win32' || !exists(join(projectPath, 'psdk.bat'))) { resolve({ built: false, error: 'psdk.bat introuvable' }); return; }
    const { spawn } = require('child_process');
    let output = '';
    let done = false;
    const child = spawn('cmd.exe', ['/d', '/c', 'psdk.bat', '--util=plugin', 'build', PLUGIN_NAME], { cwd: projectPath, windowsHide: true });
    const finish = (r) => { if (!done) { done = true; clearTimeout(timer); resolve(r); } };
    const timer = setTimeout(() => { try { child.kill(); } catch (e) { /* rien */ } finish({ built: false, error: 'trop long (plus de 3 minutes)' }); }, 180000);
    child.stdout.on('data', (d) => { output += d; });
    child.stderr.on('data', (d) => { output += d; });
    child.on('error', (e) => finish({ built: false, error: e.message }));
    child.on('close', (code) => {
      const ok = code === 0 && /Done!/.test(output);
      finish(ok ? { built: true } : { built: false, error: (output.trim().split(/\r?\n/).pop() || `code ${code}`).slice(0, 200) });
    });
  });
}

const handlers = {
  async getContext({ projectPath }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    let config = null;
    const file = join(projectPath, CONFIG_FILE);
    if (exists(file)) {
      try { config = JSON.parse(fs.readFileSync(file, 'utf8').replace(/^﻿/, '')); } catch (e) { throw new Error('variantes.json illisible : ' + e.message); }
    }
    return {
      config,
      creatures: await creatures(projectPath),
      radiant: await radiantFiles(projectPath),
      dirs: DIRS,
      plugin: await pluginStatus(projectPath),
    };
  },

  // Lit des images du projet et les renvoie en data: URL (lisibles pixel par pixel dans un canvas)
  async readImages({ projectPath, files }) {
    const out = {};
    for (const rel of files || []) {
      const full = join(projectPath, rel);
      out[rel] = exists(full) ? 'data:image/png;base64,' + (await fsp.readFile(full)).toString('base64') : null;
    }
    return out;
  },

  // Enregistre les réglages, les sprites Radiants (créés / supprimés) et met le plugin à jour
  async save({ projectPath, config, write, remove }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    // suppressions d'abord : un Radiant supprimé puis refait garde ses nouvelles images
    const removed = [];
    for (const { kind, filename } of remove || []) {
      if (!DIRS[kind] || !safeName(filename)) continue;
      const full = join(projectPath, `${DIRS[kind][2]}/${safeName(filename)}.png`);
      if (exists(full)) { await fsp.unlink(full); removed.push(filename); }
    }
    const written = [];
    for (const { kind, filename, dataUrl } of write || []) {
      if (!DIRS[kind] || !safeName(filename) || !/^data:image\/png;base64,/.test(dataUrl || '')) continue;
      const rel = `${DIRS[kind][2]}/${safeName(filename)}.png`;
      await fsp.mkdir(path.dirname(join(projectPath, rel)), { recursive: true });
      await fsp.writeFile(join(projectPath, rel), Buffer.from(dataUrl.split(',')[1], 'base64'));
      written.push(rel);
    }
    await writeAtomic(join(projectPath, CONFIG_FILE), JSON.stringify(config, null, 2) + '\n');
    const sync = await syncInstalledPlugin(projectPath);
    return { written, removed, plugin: { source: sync.source, installed: sync.installed, copied: sync.copied, removed: sync.removed } };
  },

  async buildPlugin({ projectPath }) {
    if (!projectPath || !exists(join(projectPath, `${PLUGIN_SOURCE}/config.yml`))) return { built: false, error: 'plugin introuvable' };
    return buildPluginPackage(projectPath);
  },

  async pluginStatus({ projectPath }) {
    return pluginStatus(projectPath);
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([name, fn]) => {
    const channel = 'pj-variantes:' + name;
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
