/* eslint-disable */
// =============================================================================
// Carte de région (plugin « carte_region », Level design > Carte de région) — partie « processus principal »
// Chargé depuis .vite/build/index.js. Fournit les canaux IPC « pj-carte-region:* ».
// Lit les cartes du monde / zones / quêtes de Studio, lit et écrit Data/configs/plugins/carte_region.json.
// =============================================================================
'use strict';
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');

const CONFIG_FILE = 'Data/configs/plugins/carte_region.json';
const PLUGIN_NAME = 'carte_region';
const PLUGIN_SOURCE = 'scripts/carte_region';
const GFX = 'graphics/interface/carte_region';
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



async function listPngs(projectPath, rel) {
  const dir = join(projectPath, rel);
  if (!exists(dir)) return [];
  return (await fsp.readdir(dir)).filter((n) => n.toLowerCase().endsWith('.png')).map((n) => n.replace(/\.png$/i, '')).sort((a, b) => a.localeCompare(b, 'fr'));
}

// ---------------------------------------------------------------------------
// Cartes du monde (Data/Studio/worldmaps) et noms des régions (textes 100009)
// ---------------------------------------------------------------------------
const REGION_TEXTS = 'Data/Text/Dialogs/100009.csv';

function regionNames(projectPath) {
  const file = join(projectPath, REGION_TEXTS);
  if (!exists(file)) return [];
  const rows = parseCsv(fs.readFileSync(file, 'utf8').replace(/^﻿/, ''));
  const head = rows[0] || [];
  const fr = head.indexOf('fr'); const en = head.indexOf('en');
  return rows.slice(1).map((r) => ({ fr: fr >= 0 ? r[fr] || '' : '', en: en >= 0 ? r[en] || '' : '' }));
}

const csvCell = (v) => (/[",\n\r]/.test(v) ? '"' + String(v).replace(/"/g, '""') + '"' : String(v));

// Écrit (ou ajoute) le nom d'une région dans les textes ; renvoie l'index de la ligne
async function writeRegionName(projectPath, index, names) {
  const file = join(projectPath, REGION_TEXTS);
  const raw = exists(file) ? fs.readFileSync(file, 'utf8').replace(/^﻿/, '') : 'en,fr\n';
  const rows = parseCsv(raw);
  while (rows.length > 1 && !rows[rows.length - 1].some((c) => c !== '')) rows.pop(); // lignes vides de la fin seulement
  const head = rows[0];
  const width = head.length;
  if (index == null || index < 0 || index + 1 >= rows.length) {
    rows.push(new Array(width).fill(''));
    index = rows.length - 2;
  }
  const row = rows[index + 1];
  while (row.length < width) row.push('');
  const fr = names.fr || names.en || ''; const en = names.en || names.fr || '';
  head.forEach((lang, c) => { row[c] = lang === 'fr' ? fr : lang === 'en' ? en : (row[c] || en); });
  await writeAtomic(file, rows.map((r) => r.map(csvCell).join(',')).join('\n') + '\n');
  return index;
}

// Enregistre les cartes du monde modifiées ; les anciens fichiers en double (même id) passent en .bak
async function saveWorldmaps(projectPath, list, deleted) {
  const dir = join(projectPath, 'Data/Studio/worldmaps');
  await fsp.mkdir(dir, { recursive: true });
  const files = (await fsp.readdir(dir)).filter((n) => n.endsWith('.json'));
  const byId = {};
  for (const f of files) {
    try { const d = JSON.parse((await fsp.readFile(path.join(dir, f), 'utf8')).replace(/^﻿/, '')); (byId[d.id] = byId[d.id] || []).push({ f, d }); } catch (e) { /* ignoré */ }
  }
  const retire = async (f) => { const full = path.join(dir, f); if (exists(full)) await fsp.rename(full, full + '.bak'); };
  for (const id of deleted) for (const { f } of byId[id] || []) await retire(f);
  const written = [];
  for (const wm of list) {
    const existing = (byId[wm.id] || []).find((e) => e.f === wm.file) || (byId[wm.id] || [])[0];
    const db = wm.db || `worldmap_${wm.id}`;
    const data = existing ? existing.d : { klass: 'WorldMap', id: wm.id, dbSymbol: db };
    const textIndex = await writeRegionName(projectPath, data.regionName ? data.regionName.csvTextIndex : wm.textIndex, wm.names || {});
    data.image = wm.image || '';
    data.grid = wm.grid;
    data.regionName = { csvFileId: 9, csvTextIndex: textIndex };
    const file = existing ? existing.f : `${db}.json`;
    await writeAtomic(path.join(dir, file), JSON.stringify(data, null, 2) + '\n');
    for (const e of byId[wm.id] || []) if (e.f !== file) await retire(e.f);
    written.push({ id: wm.id, file, textIndex });
  }
  return written;
}

const handlers = {
  async getContext({ projectPath }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    let config = null;
    const file = join(projectPath, CONFIG_FILE);
    if (exists(file)) {
      try { config = JSON.parse(fs.readFileSync(file, 'utf8').replace(/^﻿/, '')); } catch (e) { throw new Error('carte_region.json illisible : ' + e.message); }
    }
    const zoneName = texts(projectPath, 100010);
    const regionName = texts(projectPath, 100009);
    const questName = texts(projectPath, 100045);
    // Cartes du monde : un fichier par carte (on garde le plus récent si deux fichiers ont le même id)
    const wmDir = join(projectPath, 'Data/Studio/worldmaps');
    const wms = {};
    if (exists(wmDir)) {
      for (const f of (await fsp.readdir(wmDir)).filter((n) => n.endsWith('.json'))) {
        try {
          const full = path.join(wmDir, f);
          const d = JSON.parse((await fsp.readFile(full, 'utf8')).replace(/^﻿/, ''));
          const mtime = (await fsp.stat(full)).mtimeMs;
          const named = f === `${d.dbSymbol}.json`; // fichier au nom du dbSymbol = format actuel de Studio
          const cur = wms[d.id];
          if (!cur || (named && !cur.named) || (named === cur.named && mtime > cur.mtime)) wms[d.id] = { d, mtime, named, file: f };
        } catch (e) { /* ignoré */ }
      }
    }
    const names = regionNames(projectPath);
    const worldmaps = Object.values(wms).map(({ d, file: f }) => {
      const idx = d.regionName ? d.regionName.csvTextIndex : null;
      const n = idx != null && names[idx] ? names[idx] : { fr: '', en: '' };
      return { id: d.id, db: d.dbSymbol, image: d.image || '', grid: d.grid || [], file: f, textIndex: idx,
        name: n.fr || n.en || d.dbSymbol, names: { fr: n.fr || '', en: n.en || '' } };
    }).sort((a, b) => a.id - b.id);
    const zones = (await readDir(projectPath, 'Data/Studio/zones')).filter((d) => d.dbSymbol && d.dbSymbol !== '__undef__')
      .map((d) => ({ id: d.id, db: d.dbSymbol, name: (zoneName && zoneName(d.id)) || d.dbSymbol, maps: d.maps || [],
        warp: !!(d.warp && d.warp.x != null && d.warp.y != null), weather: d.forcedWeather || 0, groups: (d.wildGroups || []).length,
        position: d.position && d.position.x != null ? d.position : null }))
      .sort((a, b) => a.id - b.id);
    const quests = (await readDir(projectPath, 'Data/Studio/quests')).filter((d) => d.dbSymbol && d.dbSymbol !== '__undef__')
      .map((d) => ({ id: d.id, db: d.dbSymbol, name: (questName && questName(d.id)) || d.dbSymbol })).sort((a, b) => a.id - b.id);
    return {
      config, worldmaps, zones, quests,
      characters: await listPngs(projectPath, 'graphics/characters'),
      decorations: await listPngs(projectPath, `${GFX}/decorations`),
      // les variantes d'heure (<lieu>_matin, _soir, _nuit) sont prises par le jeu : on ne montre que l'image de base
      images: (await listPngs(projectPath, `${GFX}/lieux`)).filter((n) => !/_(matin|soir|nuit)(\.png)?$/i.test(n)),
      mapImages: await listPngs(projectPath, 'graphics/interface/worldmap/worldmaps'),
      themes: (exists(join(projectPath, `${GFX}/themes`)) ? (await fsp.readdir(join(projectPath, `${GFX}/themes`))) : []).sort(),
      assets: exists(join(projectPath, `${GFX}/icons/fly.png`)),
      plugin: await pluginStatus(projectPath),
    };
  },
  async save({ projectPath, config, worldmaps, deleted }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    let written = [];
    if (Array.isArray(worldmaps) || Array.isArray(deleted)) written = await saveWorldmaps(projectPath, worldmaps || [], deleted || []);
    await writeAtomic(join(projectPath, CONFIG_FILE), JSON.stringify(config, null, 2) + '\n');
    const rx = join(projectPath, 'Data/configs/plugins_carte_region.rxdata');
    if (exists(rx)) { try { await fsp.unlink(rx); } catch (e) { /* rien */ } }
    const sync = await syncInstalledPlugin(projectPath);
    return { plugin: { source: sync.source, installed: sync.installed }, worldmaps: written };
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
  // Copie une image PNG choisie sur le disque dans decorations/ ou lieux/ ; renvoie son nom
  async importImage({ projectPath, folder }) {
    if (!['decorations', 'lieux', 'worldmaps'].includes(folder)) throw new Error('Dossier refusé');
    const { dialog, BrowserWindow } = require('electron');
    const win = BrowserWindow.getFocusedWindow();
    const r = await dialog.showOpenDialog(win, { title: 'Choisir une image', filters: [{ name: 'Images PNG', extensions: ['png'] }], properties: ['openFile'] });
    if (r.canceled || !r.filePaths.length) return null;
    const src = r.filePaths[0];
    const name = path.basename(src).replace(/\.png$/i, '').replace(/[^\w\-. ]+/g, '_');
    const dest = join(projectPath, folder === 'worldmaps' ? `graphics/interface/worldmap/worldmaps/${name}.png` : `${GFX}/${folder}/${name}.png`);
    await fsp.mkdir(path.dirname(dest), { recursive: true });
    await fsp.copyFile(src, dest);
    return name;
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([n, fn]) => {
    const channel = 'pj-carte-region:' + n;
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
