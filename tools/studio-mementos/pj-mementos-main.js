/* eslint-disable */
// =============================================================================
// Souvenirs (plugin « mementos », Données > Pokémon > Rubans et insignes) — partie « processus principal »
// Chargé depuis .vite/build/index.js. Fournit les canaux IPC « pj-mementos:* ».
// Lit / écrit Data/configs/plugins/mementos.json ; lit la liste des souvenirs dans scripts/mementos/scripts/00101 Donnees.rb
// (et les textes de PSDK dans Data/Text/Dialogs/100075..100077) ; le plugin installé reçoit les scripts à jour.
// =============================================================================
'use strict';
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');

const CONFIG_FILE = 'Data/configs/plugins/mementos.json';
const PLUGIN_NAME = 'mementos';
const PLUGIN_SOURCE = 'scripts/mementos';
const DATA_FILE = 'scripts/mementos/scripts/00101 Donnees.rb';
const PLUGINS_INSTALLED = 'scripts/00000 Plugins';
const join = (projectPath, rel) => path.join(projectPath, ...rel.split('/'));
const exists = (p) => { try { return fs.existsSync(p); } catch (e) { return false; } };
const norm = (b) => b.toString('utf8').replace(/^﻿/, '').replace(/\r\n/g, '\n');

// Rubans de PSDK, dans l'ordre de PFM::RIBBONS_DATA (leur n° est la ligne des textes 100075..100077)
const PSDK_RIBBONS = ('kalos_champion champion sinnoh_champion best_friends training skillful_battler expert_battler effort alert shock downcast careless ' +
  'relax snooze smile gorgeous royal gorgeous_royal artist footprint record legend country national earth world classic premier event birthday special ' +
  'souvenir wishing battle_champion regional_champion national_champion world_champion contest_memory battle_memory hoenn_champion contest_star ' +
  'coolness_master beauty_master cuteness_master cleverness_master toughness_master alola_champion battle_royal_master battle_tree_great ' +
  'battle_tree_master galar_champion paldea_champion cool_normal_hoenn cool_super_hoenn cool_hyper_hoenn cool_master_hoenn beauty_normal_hoenn ' +
  'beauty_super_hoenn beauty_hyper_hoenn beauty_master_hoenn cute_normal_hoenn cute_super_hoenn cute_hyper_hoenn cute_master_hoenn smart_normal_hoenn ' +
  'smart_super_hoenn smart_hyper_hoenn smart_master_hoenn tough_normal_hoenn tough_super_hoenn tough_hyper_hoenn tough_master_hoenn cool_normal_sinnoh ' +
  'cool_great_sinnoh cool_ultra_sinnoh cool_master_sinnoh beauty_normal_sinnoh beauty_great_sinnoh beauty_ultra_sinnoh beauty_master_sinnoh ' +
  'cute_normal_sinnoh cute_great_sinnoh cute_ultra_sinnoh cute_master_sinnoh smart_normal_sinnoh smart_great_sinnoh smart_ultra_sinnoh ' +
  'smart_master_sinnoh tough_normal_sinnoh tough_great_sinnoh tough_ultra_sinnoh tough_master_sinnoh twinkling_star contest_memory_gold winning ' +
  'victory ability great_ability double_ability multi_ability pair_ability world_ability tower_master battle_memory_gold master_rank hisui ' +
  'once_in_a_lifetime').split(' ');

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

// Textes du projet (Data/Text/Dialogs/<id>.csv) : (ligne) => [fr, en]
function texts(projectPath, id) {
  const file = join(projectPath, `Data/Text/Dialogs/${id}.csv`);
  if (!exists(file)) return () => ['', ''];
  const rows = parseCsv(fs.readFileSync(file, 'utf8').replace(/^﻿/, ''));
  const fr = Math.max(0, rows[0].indexOf('fr'));
  const en = Math.max(0, rows[0].indexOf('en'));
  return (i) => (rows[i + 1] ? [rows[i + 1][fr] || '', rows[i + 1][en] || ''] : ['', '']);
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
// Souvenirs : 00101 Donnees.rb (INFO : catégorie, rangs ; TEXTS : textes des nouveaux) + textes de PSDK
// ---------------------------------------------------------------------------
const STR = `'((?:[^'\\\\]|\\\\.)*)'`;
const unq = (s) => (s || '').replace(/\\(.)/g, '$1');
function readMementos(projectPath) {
  const file = join(projectPath, DATA_FILE);
  if (!exists(file)) return [];
  const src = norm(fs.readFileSync(file));
  const ranksConst = (src.match(/CONTEST_RANKS = %i\[([^\]]*)\]/) || [, ''])[1].split(/\s+/).filter(Boolean);
  const info = new Map();
  const infoBlock = (src.match(/INFO = \{([\s\S]*?)\n  \}\.freeze/) || [, ''])[1];
  for (const m of infoBlock.matchAll(/^\s+(\w+): \[:(\w+)(?:, (?:%i\[([^\]]*)\]|(CONTEST_RANKS)))?\]/gm)) {
    info.set(m[1], { category: m[2], ranks: m[4] ? ranksConst : (m[3] || '').split(/\s+/).filter(Boolean) });
  }
  const own = new Map();
  const textBlock = (src.match(/TEXTS = \{([\s\S]*?)\n  \}\.freeze/) || [, ''])[1];
  const re = new RegExp(`(\\w+): \\{ name: \\[${STR}, ${STR}\\],\\s*description: \\[${STR}, ${STR}\\](?:, title: \\[${STR}, ${STR}\\])? \\}`, 'g');
  for (const m of textBlock.matchAll(re)) {
    own.set(m[1], { name: [unq(m[2]), unq(m[3])], description: [unq(m[4]), unq(m[5])], title: m[6] !== undefined ? [unq(m[6]), unq(m[7])] : null });
  }
  const names = texts(projectPath, 100075);
  const descs = texts(projectPath, 100076);
  const titles = texts(projectPath, 100077);
  const order = PSDK_RIBBONS.concat([...own.keys()].filter((s) => !PSDK_RIBBONS.includes(s)));
  const gfx = join(projectPath, 'graphics/interface/ribbons');
  return order.map((sym) => {
    const i = PSDK_RIBBONS.indexOf(sym);
    const t = own.get(sym);
    const psdk = i >= 0;
    const title = t && t.title ? t.title : (psdk ? titles(i) : ['', '']);
    const inf = info.get(sym) || { category: 'gift', ranks: [] };
    return {
      symbol: sym, psdk, category: inf.category, ranks: inf.ranks,
      name: t ? t.name : names(i), description: t ? t.description : descs(i), title,
      icon: exists(path.join(gfx, `${sym}_ribbon.png`)),
    };
  });
}

// Dresseurs de Studio et leur équipe
async function readTrainers(projectPath) {
  const trainerName = texts(projectPath, 100062);
  const monName = texts(projectPath, 100000);
  const species = new Map((await readDir(projectPath, 'Data/Studio/pokemon')).map((d) => [d.dbSymbol, d.id]));
  return (await readDir(projectPath, 'Data/Studio/trainers')).filter((d) => d.dbSymbol)
    .map((d) => ({
      id: d.id, db: d.dbSymbol, name: trainerName(d.id)[0] || trainerName(d.id)[1] || d.dbSymbol,
      party: (d.party || []).map((p) => {
        const id = species.get(p.specie);
        const nick = (p.expandPokemonSetup || []).find((e) => e.type === 'givenName');
        return { specie: p.specie, id: id === undefined ? null : id, form: p.form || 0,
          name: (nick && nick.value) || (id !== undefined ? monName(id)[0] || monName(id)[1] : '') || p.specie,
          level: p.levelSetup && p.levelSetup.level };
      }),
    }))
    .sort((a, b) => a.id - b.id);
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
      try { config = JSON.parse(fs.readFileSync(file, 'utf8').replace(/^﻿/, '')); } catch (e) { throw new Error('mementos.json illisible : ' + e.message); }
    }
    return {
      config,
      mementos: readMementos(projectPath),
      trainers: await readTrainers(projectPath),
      charm: exists(join(projectPath, 'Data/Studio/items/mark_charm.json')),
      plugin: await pluginStatus(projectPath),
    };
  },
  async save({ projectPath, config }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    await writeAtomic(join(projectPath, CONFIG_FILE), JSON.stringify(config, null, 1) + '\n');
    const rx = join(projectPath, 'Data/configs/plugins_mementos.rxdata');
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
    if (!exists(full)) return null;
    return 'data:image/png;base64,' + (await fsp.readFile(full)).toString('base64');
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([n, fn]) => {
    const channel = 'pj-mementos:' + n;
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
