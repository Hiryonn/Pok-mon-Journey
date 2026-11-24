/* eslint-disable */
// =============================================================================
// Groupes d'Œuf (plugin « egg_groups », Données > Pokémon > Groupes d'Œuf) — partie « processus principal »
// Chargé depuis .vite/build/index.js. Fournit les canaux IPC « pj-egg-groups:* ».
// Lit / écrit Data/configs/plugins/egg_groups.json ; le plugin installé reçoit les scripts à jour.
// =============================================================================
'use strict';
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');

const CONFIG_FILE = 'Data/configs/plugins/egg_groups.json';
const PLUGIN_NAME = 'egg_groups';
const PLUGIN_SOURCE = 'scripts/egg_groups';
const PLUGINS_INSTALLED = 'scripts/00000 Plugins';
const join = (projectPath, rel) => path.join(projectPath, ...rel.split('/'));
const exists = (p) => { try { return fs.existsSync(p); } catch (e) { return false; } };
const norm = (b) => b.toString('utf8').replace(/^\uFEFF/, '').replace(/\r\n/g, '\n');

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



const DEFAULT_CONFIG = () => ({ klass: 'EggGroupsConfig', groups: [], creatures: {}, recipes: [], incense: [], disabled_incense: [] });

// Pokémon de Studio : n°, nom, groupes d'œuf de Studio de chaque forme
async function creatures(projectPath) {
  const text = texts(projectPath, 100000);
  const out = [];
  for (const d of await readDir(projectPath, 'Data/Studio/pokemon')) {
    if (!d.dbSymbol || d.dbSymbol === '__undef__') continue;
    out.push({
      id: d.id, db: d.dbSymbol, name: (text && text(d.id)) || d.dbSymbol,
      forms: (d.forms || []).map((f) => ({ form: f.form, groups: (f.breedGroups || []).filter((g, i, a) => a.indexOf(g) === i), baby: f.babyDbSymbol || '' })),
    });
  }
  return out.sort((a, b) => a.id - b.id);
}

const handlers = {
  async getContext({ projectPath }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    let config = DEFAULT_CONFIG();
    const file = join(projectPath, CONFIG_FILE);
    if (exists(file)) {
      try { config = Object.assign(config, JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''))); } catch (e) { throw new Error('egg_groups.json illisible : ' + e.message); }
    }
    const itemName = texts(projectPath, 100012);
    const items = (await readDir(projectPath, 'Data/Studio/items')).filter((d) => d.dbSymbol && d.dbSymbol !== '__undef__')
      .map((d) => ({ id: d.id, db: d.dbSymbol, name: (itemName && itemName(d.id)) || d.dbSymbol })).sort((a, b) => a.id - b.id);
    return { config, creatures: await creatures(projectPath), items, plugin: await pluginStatus(projectPath) };
  },
  async save({ projectPath, config }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    await writeAtomic(join(projectPath, CONFIG_FILE), JSON.stringify(config, null, 2) + '\n');
    const rx = join(projectPath, 'Data/configs/plugins_egg_groups.rxdata');
    if (exists(rx)) { try { await fsp.unlink(rx); } catch (e) { /* rien */ } }
    const sync = await syncInstalledPlugin(projectPath);
    return { plugin: { source: sync.source, installed: sync.installed } };
  },
  async buildPlugin({ projectPath }) {
    if (!projectPath || !exists(join(projectPath, `${PLUGIN_SOURCE}/config.yml`))) return { built: false, error: 'plugin introuvable' };
    return buildPluginPackage(projectPath);
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([n, fn]) => {
    const channel = 'pj-egg-groups:' + n;
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
