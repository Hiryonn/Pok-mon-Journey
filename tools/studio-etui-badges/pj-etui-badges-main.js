/* eslint-disable */
// =============================================================================
// Étui à badges (plugin « etui_badges », Level design > Dresseurs > Étui à badges) — partie « processus principal »
// Chargé depuis .vite/build/index.js. Fournit les canaux IPC « pj-etui-badges:* ».
// Lit / écrit Data/configs/plugins/etui_badges.json ; le plugin installé reçoit les scripts à jour.
// =============================================================================
'use strict';
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');

const CONFIG_FILE = 'Data/configs/plugins/etui_badges.json';
const PLUGIN_NAME = 'etui_badges';
const PLUGIN_SOURCE = 'scripts/etui_badges';
const GFX = 'graphics/interface/etui_badges';
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



async function pngNames(projectPath, rel) {
  const dir = join(projectPath, rel);
  if (!exists(dir)) return [];
  return (await fsp.readdir(dir)).filter((n) => /\.png$/i.test(n)).map((n) => n.replace(/\.png$/i, '')).sort();
}

const handlers = {
  async getContext({ projectPath }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    let config = null;
    const file = join(projectPath, CONFIG_FILE);
    if (exists(file)) {
      try { config = JSON.parse(fs.readFileSync(file, 'utf8').replace(/^﻿/, '')); } catch (e) { throw new Error('etui_badges.json illisible : ' + e.message); }
    }
    const creatureName = texts(projectPath, 100000);
    const typeName = texts(projectPath, 100003);
    const creatures = (await readDir(projectPath, 'Data/Studio/pokemon')).filter((d) => d.dbSymbol && d.dbSymbol !== '__undef__' && d.id > 0)
      .map((d) => ({ id: d.id, db: d.dbSymbol, name: (creatureName && creatureName(d.id)) || d.dbSymbol, icon: (d.forms && d.forms[0] && d.forms[0].resources && d.forms[0].resources.icon) || '' }))
      .sort((a, b) => a.id - b.id);
    const types = (await readDir(projectPath, 'Data/Studio/types')).filter((d) => d.dbSymbol && d.dbSymbol !== '__undef__')
      .map((d) => ({ id: d.id, db: d.dbSymbol, name: (typeName && typeName(d.textId)) || d.dbSymbol, color: d.color || '#888' }))
      .sort((a, b) => a.id - b.id);
    const meDir = join(projectPath, 'audio/me');
    const mes = exists(meDir) ? (await fsp.readdir(meDir)).filter((n) => /\.(ogg|mp3|wav|mid|midi)$/i.test(n)).map((n) => 'audio/me/' + n.replace(/\.[^.]+$/, '')).sort() : [];
    const badgeFiles = await pngNames(projectPath, `${GFX}/badges`);
    return {
      config, creatures, types, mes,
      badgeImages: badgeFiles.filter((n) => !/_off$/.test(n)),
      offImages: badgeFiles.filter((n) => /_off$/.test(n)),
      leaderImages: await pngNames(projectPath, `${GFX}/leaders`),
      battlers: await pngNames(projectPath, 'graphics/battlers'),
      assets: exists(join(projectPath, `${GFX}/tray.png`)),
      plugin: await pluginStatus(projectPath),
    };
  },
  async save({ projectPath, config }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    await writeAtomic(join(projectPath, CONFIG_FILE), JSON.stringify(config, null, 2) + '\n');
    const rx = join(projectPath, 'Data/configs/plugins_etui_badges.rxdata');
    if (exists(rx)) { try { await fsp.unlink(rx); } catch (e) { /* rien */ } }
    const sync = await syncInstalledPlugin(projectPath);
    return { plugin: { source: sync.source, installed: sync.installed } };
  },
  async buildPlugin({ projectPath }) {
    if (!projectPath || !exists(join(projectPath, `${PLUGIN_SOURCE}/config.yml`))) return { built: false, error: 'plugin introuvable' };
    return buildPluginPackage(projectPath);
  },
  async readImage({ projectPath, file }) {
    const rel = String(file || '').replace(/\\/g, '/');
    if (!/^graphics\//.test(rel) || rel.split('/').includes('..')) throw new Error('Image refusée');
    const full = join(projectPath, rel.endsWith('.png') ? rel : rel + '.png');
    return exists(full) ? 'data:image/png;base64,' + (await fsp.readFile(full)).toString('base64') : null;
  },
  async readSound({ projectPath, file }) {
    const rel = String(file || '').replace(/\\/g, '/');
    if (!/^audio\//.test(rel) || rel.split('/').includes('..')) throw new Error('Son refusé');
    for (const ext of ['.ogg', '.mp3', '.wav']) {
      const full = join(projectPath, rel + ext);
      if (exists(full)) return `data:audio/${ext === '.mp3' ? 'mpeg' : ext.slice(1)};base64,` + (await fsp.readFile(full)).toString('base64');
    }
    return null;
  },
  // Importe une image PNG : badges (nom, ou nom_off pour la version pas obtenue) ou leaders (champions)
  async importImage({ projectPath, folder, name: wanted }) {
    if (!['badges', 'leaders'].includes(folder)) throw new Error('Dossier refusé');
    const { dialog, BrowserWindow } = require('electron');
    const win = BrowserWindow.getFocusedWindow();
    const r = await dialog.showOpenDialog(win, { title: 'Choisir une image', filters: [{ name: 'Images PNG', extensions: ['png'] }], properties: ['openFile'] });
    if (r.canceled || !r.filePaths.length) return null;
    const src = r.filePaths[0];
    const clean = (t) => String(t || '').toLowerCase().replace(/\.png$/i, '').replace(/[^a-z0-9_\-]+/g, '_').replace(/^_+|_+$/g, '');
    const name = clean(wanted) || clean(path.basename(src)) || 'image';
    const dest = join(projectPath, `${GFX}/${folder}/${name}.png`);
    await fsp.mkdir(path.dirname(dest), { recursive: true });
    await fsp.copyFile(src, dest);
    return name;
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([n, fn]) => {
    const channel = 'pj-etui-badges:' + n;
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
