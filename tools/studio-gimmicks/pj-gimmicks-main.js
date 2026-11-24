/* eslint-disable */
// =============================================================================
// Gimmicks (plugin « gimmicks », Données > Gimmicks) — partie « processus principal » (Electron main)
// Chargé depuis .vite/build/index.js. Fournit les canaux IPC « pj-gimmicks:* ».
// Lit / écrit Data/configs/plugins/gimmicks.json (réglages, Pokémon, dresseurs).
// À chaque enregistrement, le plugin installé (scripts/00000 Plugins/<n> gimmicks) reçoit les scripts à jour
// et scripts/gimmicks.psdkplug est reconstruit.
// =============================================================================
'use strict';
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');

const CONFIG_FILE = 'Data/configs/plugins/gimmicks.json';
const PLUGIN_NAME = 'gimmicks';
const PLUGIN_SOURCE = 'scripts/gimmicks';
const PLUGINS_INSTALLED = 'scripts/00000 Plugins';

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


// Textes du projet (Data/Text/Dialogs/<id>.csv), colonne française
function texts(projectPath, id) {
  const file = join(projectPath, `Data/Text/Dialogs/${id}.csv`);
  if (!exists(file)) return null;
  const rows = parseCsv(fs.readFileSync(file, 'utf8').replace(/^﻿/, ''));
  const col = Math.max(0, rows[0].indexOf('fr') >= 0 ? rows[0].indexOf('fr') : rows[0].indexOf('en'));
  return (i) => (rows[i + 1] && rows[i + 1][col]) || '';
}

async function readDir(projectPath, rel) {
  const dir = join(projectPath, rel);
  if (!exists(dir)) return [];
  const out = [];
  for (const f of (await fsp.readdir(dir)).filter((n) => n.endsWith('.json'))) {
    try { out.push(JSON.parse((await fsp.readFile(path.join(dir, f), 'utf8')).replace(/^﻿/, ''))); } catch (e) { /* ignoré */ }
  }
  return out;
}

// Pokémon : formes (types, Gigamax, méga-gemmes), noms
async function creatures(projectPath) {
  const name = texts(projectPath, 100000);
  const formName = texts(projectPath, 100067);
  const out = [];
  for (const d of await readDir(projectPath, 'Data/Studio/pokemon')) {
    if (!d.dbSymbol || d.dbSymbol === '__undef__') continue;
    const forms = (d.forms || []).map((f) => ({
      form: f.form | 0,
      name: formName && f.formTextId ? formName(f.formTextId.name) : '',
      types: [f.type1, f.type2].filter((t) => t && t !== '__undef__'),
      icon: (f.resources || {}).icon || '',
      mega: (f.evolutions || []).filter((e) => (e.conditions || []).some((c) => c.type === 'gemme')).map((e) => ({
        form: e.form | 0, item: ((e.conditions || []).find((c) => c.type === 'gemme') || {}).value })),
    }));
    out.push({ id: d.id, dbSymbol: d.dbSymbol, name: (name && name(d.id)) || d.dbSymbol, forms, gmax: forms.some((f) => f.form === 40) });
  }
  return out.sort((a, b) => a.id - b.id);
}

// Dresseurs : nom, équipe
async function trainers(projectPath) {
  const name = texts(projectPath, 100062);
  const klass = texts(projectPath, 100029);
  const out = [];
  for (const d of await readDir(projectPath, 'Data/Studio/trainers')) {
    if (!d.dbSymbol) continue;
    out.push({
      id: d.id, dbSymbol: d.dbSymbol, name: (name && name(d.id)) || d.dbSymbol, klass: (klass && klass(d.id)) || '',
      bag: (d.bagEntries || []).map((b) => b.dbSymbol),
      party: (d.party || []).map((p) => ({ specie: p.specie, form: p.form | 0, level: (p.levelSetup || {}).level || 0,
        item: ((p.expandPokemonSetup || []).find((e) => e.type === 'itemHeld') || {}).value || '' })),
    });
  }
  return out.sort((a, b) => a.id - b.id);
}

// Objets (nom, icône) et attaques (nom), pour les pages Méga-gemmes / Capacités Z
async function items(projectPath) {
  const name = texts(projectPath, 100012);
  const out = {};
  for (const d of await readDir(projectPath, 'Data/Studio/items')) {
    if (!d.dbSymbol) continue;
    out[d.dbSymbol] = { id: d.id, name: (name && name(d.id)) || d.dbSymbol, icon: d.icon || '', megaKey: !!d.isAllowingMega };
  }
  return out;
}
async function moves(projectPath) {
  const name = texts(projectPath, 100006);
  const out = {};
  for (const d of await readDir(projectPath, 'Data/Studio/moves')) {
    if (d.dbSymbol) out[d.dbSymbol] = { name: (name && name(d.id)) || d.dbSymbol, type: d.type || '' };
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
      try { config = JSON.parse(fs.readFileSync(file, 'utf8').replace(/^﻿/, '')); } catch (e) { throw new Error('gimmicks.json illisible : ' + e.message); }
    }
    const types = (await readDir(projectPath, 'Data/Studio/types')).map((t) => t.dbSymbol).filter(Boolean);
    return { config, creatures: await creatures(projectPath), trainers: await trainers(projectPath), items: await items(projectPath), moves: await moves(projectPath), types, plugin: await pluginStatus(projectPath) };
  },

  async save({ projectPath, config }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    await writeAtomic(join(projectPath, CONFIG_FILE), JSON.stringify(config, null, 2) + '\n');
    // fichier compilé par PSDK : refait au prochain lancement
    const rx = join(projectPath, 'Data/configs/plugins_gimmicks.rxdata');
    if (exists(rx)) { try { await fsp.unlink(rx); } catch (e) { /* rien */ } }
    const sync = await syncInstalledPlugin(projectPath);
    return { plugin: { source: sync.source, installed: sync.installed, copied: sync.copied, removed: sync.removed } };
  },

  async buildPlugin({ projectPath }) {
    if (!projectPath || !exists(join(projectPath, `${PLUGIN_SOURCE}/config.yml`))) return { built: false, error: 'plugin introuvable' };
    return buildPluginPackage(projectPath);
  },

  async pluginStatus({ projectPath }) {
    return pluginStatus(projectPath);
  },

  async readImages({ projectPath, files }) {
    const out = {};
    for (const rel of files || []) {
      const full = join(projectPath, rel);
      out[rel] = exists(full) ? 'data:image/png;base64,' + (await fsp.readFile(full)).toString('base64') : null;
    }
    return out;
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([name, fn]) => {
    const channel = 'pj-gimmicks:' + name;
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
