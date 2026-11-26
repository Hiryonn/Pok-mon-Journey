/* eslint-disable */
// =============================================================================
// Studio Events — partie « processus principal » (Electron main)
// Chargé depuis .vite/build/index.js par l'installateur.
// Fournit les canaux IPC « pj-events:* » utilisés par l'éditeur d'évents.
// =============================================================================
'use strict';
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');

// Hors de Data/Studio : PSDK convertit chaque dossier de Data/Studio au démarrage (Studio2PSDK)
// et plante sur les classes inconnues (Studio::MapEvents) ou les dossiers vides.
const MAP_EVENTS_DIR = 'Data/studio_events/map_events';
const COMMON_EVENTS_FILE = 'Data/studio_events/common_events.json';
const LEGACY_MAP_EVENTS_DIR = 'Data/Studio/map_events';
const LEGACY_COMMON_EVENTS_FILE = 'Data/Studio/common_events.json';

// -----------------------------------------------------------------------------
// Lecteur Marshal Ruby (format 4.8) minimal, indépendant de Studio
// -----------------------------------------------------------------------------
class MarshalReader {
  constructor(buffer) {
    this.b = buffer;
    this.i = 2; // version 4.8
    this.symbols = [];
    this.objects = [];
  }
  byte() { return this.b[this.i++]; }
  int() {
    let c = this.b.readInt8(this.i++);
    if (c === 0) return 0;
    if (c >= 5) return c - 5;
    if (c <= -5) return c + 5;
    if (c > 0) {
      let x = 0;
      for (let k = 0; k < c; k++) x |= this.b[this.i++] << (8 * k);
      return x;
    }
    c = -c;
    let x = -1;
    for (let k = 0; k < c; k++) {
      x &= ~(0xff << (8 * k));
      x |= this.b[this.i++] << (8 * k);
    }
    return x;
  }
  bytes() { const n = this.int(); const s = this.b.subarray(this.i, this.i + n); this.i += n; return s; }
  symbol() {
    const t = String.fromCharCode(this.byte());
    if (t === ':') { const s = this.bytes().toString('utf8'); this.symbols.push(s); return s; }
    if (t === ';') return this.symbols[this.int()];
    if (t === 'I') { const s = this.symbol(); this.ivars({}); return s; }
    throw new Error('Symbole attendu, reçu ' + t);
  }
  ivars(target) {
    const n = this.int();
    for (let k = 0; k < n; k++) { const key = this.symbol(); target[key] = this.read(); }
    return target;
  }
  reg(o) { this.objects.push(o); return o; }
  read() {
    const t = String.fromCharCode(this.byte());
    switch (t) {
      case '0': return null;
      case 'T': return true;
      case 'F': return false;
      case 'i': return this.int();
      case ':': { this.i--; return { __symbol: this.symbol() }; }
      case ';': { this.i--; return { __symbol: this.symbol() }; }
      case '@': return this.objects[this.int()];
      case 'I': {
        const v = this.read();
        const iv = this.ivars({});
        if (v && typeof v === 'object') Object.assign(v, iv);
        return v;
      }
      case '"': { const s = this.bytes().toString('utf8'); this.reg(s); return s; }
      case 'f': {
        const s = this.bytes().toString('latin1');
        const v = s === 'nan' ? NaN : s === 'inf' ? Infinity : s === '-inf' ? -Infinity : parseFloat(s);
        this.reg(v); return v;
      }
      case 'l': {
        const sign = String.fromCharCode(this.byte());
        const n = this.int() * 2; let v = 0;
        for (let k = 0; k < n; k++) v += this.b[this.i++] * Math.pow(256, k);
        v = sign === '-' ? -v : v; this.reg(v); return v;
      }
      case '[': {
        const a = this.reg([]); const n = this.int();
        for (let k = 0; k < n; k++) a.push(this.read());
        return a;
      }
      case '{': case '}': {
        const h = this.reg({ __hash: [] }); const n = this.int();
        for (let k = 0; k < n; k++) { const key = this.read(); h.__hash.push([key, this.read()]); }
        if (t === '}') h.__default = this.read();
        return h;
      }
      case 'o': {
        const o = this.reg({ __class: this.symbol() });
        return this.ivars(o);
      }
      case 'u': {
        const cls = this.symbol(); const data = Buffer.from(this.bytes());
        return this.reg({ __class: cls, __userdef: data });
      }
      case 'U': {
        const o = this.reg({ __class: this.symbol() }); o.__data = this.read(); return o;
      }
      case 'S': {
        const o = this.reg({ __class: this.symbol(), __struct: true }); const n = this.int();
        for (let k = 0; k < n; k++) { const key = this.symbol(); o[key] = this.read(); }
        return o;
      }
      case 'e': { this.symbol(); return this.read(); }
      case 'C': { this.symbol(); return this.read(); }
      case 'c': case 'm': case 'M': { const s = this.bytes().toString('utf8'); this.reg({ __module: s }); return { __module: s }; }
      case '/': { const s = this.bytes().toString('utf8'); this.byte(); this.reg(s); return s; }
      case 'd': { const o = this.reg({ __class: this.symbol() }); o.__data = this.read(); return o; }
      default: throw new Error('Type Marshal non géré : ' + t + ' @' + (this.i - 1));
    }
  }
}
const marshalLoad = (buffer) => new MarshalReader(buffer).read();
const hashEntries = (h) => (h && h.__hash ? h.__hash : []);

// -----------------------------------------------------------------------------
// Conversion RPG Maker -> format JSON Studio Events
// -----------------------------------------------------------------------------
const TRIGGERS = ['action', 'playerTouch', 'eventTouch', 'autorun', 'parallel'];
const MOVE_TYPES = ['fixed', 'random', 'approach', 'custom'];
const COMMON_TRIGGERS = ['none', 'autorun', 'parallel'];
const OPERATORS = ['==', '>=', '<=', '>', '<', '!='];
const VAR_OPERATIONS = ['set', 'add', 'sub', 'mul', 'div', 'mod'];
const CONTINUATIONS = new Set([401, 402, 403, 404, 408, 411, 412, 413, 509, 601, 602, 603, 604, 605, 655]);

function encodeValue(v) {
  if (v === null || typeof v !== 'object') return v;
  if (Array.isArray(v)) return v.map(encodeValue);
  if (v.__symbol) return { __rpg: 'Symbol', name: v.__symbol };
  switch (v.__class) {
    case 'RPG::AudioFile': return { __rpg: 'AudioFile', name: v['@name'] || '', volume: v['@volume'] ?? 100, pitch: v['@pitch'] ?? 100 };
    case 'RPG::MoveRoute': return { __rpg: 'MoveRoute', ...convertMoveRoute(v) };
    case 'RPG::MoveCommand': return { __rpg: 'MoveCommand', code: v['@code'], parameters: (v['@parameters'] || []).map(encodeValue) };
    case 'Tone': case 'Color': {
      const d = v.__userdef; const vals = d && d.length >= 32 ? [0, 1, 2, 3].map((k) => d.readDoubleLE(k * 8)) : [0, 0, 0, 0];
      return v.__class === 'Tone'
        ? { __rpg: 'Tone', red: vals[0], green: vals[1], blue: vals[2], gray: vals[3] }
        : { __rpg: 'Color', red: vals[0], green: vals[1], blue: vals[2], alpha: vals[3] };
    }
    default: return null;
  }
}

function convertMoveRoute(r) {
  const list = (r && r['@list']) || [];
  return {
    repeat: !!(r && r['@repeat']),
    skippable: !!(r && r['@skippable']),
    commands: list.filter((c) => c && c['@code'] !== 0).map((c) => ({ code: c['@code'], parameters: (c['@parameters'] || []).map(encodeValue) })),
  };
}

const audio = (a) => ({ name: (a && a['@name']) || '', volume: (a && a['@volume']) ?? 100, pitch: (a && a['@pitch']) ?? 100 });

function convertList(list) {
  const cmds = list.map((c) => ({ code: c['@code'], indent: c['@indent'], parameters: c['@parameters'] || [] }));
  const [result] = parseBlock(cmds, 0, cmds.length ? cmds[0].indent : 0);
  return result;
}

// Lit une suite de commandes au niveau « indent ». Retourne [commandes, index suivant]
function parseBlock(cmds, i, indent) {
  const out = [];
  while (i < cmds.length) {
    const c = cmds[i];
    if (c.indent < indent) return [out, i];
    if (c.code === 0) { if (c.indent === indent) return [out, i + 1]; i++; continue; }
    if (CONTINUATIONS.has(c.code) && c.indent === indent && [402, 403, 404, 411, 412, 413].includes(c.code)) return [out, i];
    const [cmd, next] = parseCommand(cmds, i, indent);
    if (cmd) out.push(cmd);
    i = next;
  }
  return [out, i];
}

function collectLines(cmds, i, contCode) {
  const lines = [cmds[i].parameters[0] ?? ''];
  let j = i + 1;
  while (j < cmds.length && cmds[j].code === contCode && cmds[j].indent === cmds[i].indent) { lines.push(cmds[j].parameters[0] ?? ''); j++; }
  return [lines.join('\n'), j];
}

function rawFrom(cmds, i, indent) {
  const base = cmds[i];
  const raw = [base];
  let j = i + 1;
  while (j < cmds.length) {
    const c = cmds[j];
    if (c.indent > base.indent || (c.indent === base.indent && CONTINUATIONS.has(c.code) && ![402, 403, 404, 411, 412, 413].includes(c.code))) { raw.push(c); j++; continue; }
    // Bloc de combat RMXP (301 ... 604)
    if (base.code === 301 && c.indent === base.indent && [601, 602, 603, 604].includes(c.code)) { raw.push(c); j++; if (c.code === 604) break; continue; }
    break;
  }
  return [{ klass: 'Raw', commands: raw.map((c) => ({ code: c.code, indent: c.indent - indent, parameters: c.parameters.map(encodeValue) })) }, j];
}

function rawUntil(cmds, i, indent, endCode) {
  let j = i + 1;
  while (j < cmds.length && !(cmds[j].code === endCode && cmds[j].indent === cmds[i].indent)) j++;
  const slice = cmds.slice(i, Math.min(j + 1, cmds.length));
  return [{ klass: 'Raw', commands: slice.map((c) => ({ code: c.code, indent: c.indent - indent, parameters: c.parameters.map(encodeValue) })) }, j + 1];
}

function parseCommand(cmds, i, indent) {
  const c = cmds[i];
  const p = c.parameters;
  switch (c.code) {
    case 101: { const [text, j] = collectLines(cmds, i, 401); return [{ klass: 'ShowMessage', text }, j]; }
    case 108: { const [text, j] = collectLines(cmds, i, 408); return [{ klass: 'Comment', text }, j]; }
    case 355: { const [code, j] = collectLines(cmds, i, 655); return [scriptToCommand(code), j]; }
    case 102: {
      const texts = p[0] || []; const cancelType = p[1] ?? 0;
      const cmd = { klass: 'ShowChoices', cancel: cancelType === 0 ? 'disallow' : cancelType === 5 ? 'branch' : cancelType, choices: texts.map((t) => ({ text: t, commands: [] })), cancelCommands: [] };
      let j = i + 1;
      while (j < cmds.length && cmds[j].indent === c.indent && (cmds[j].code === 402 || cmds[j].code === 403)) {
        const isCancel = cmds[j].code === 403; const idx = cmds[j].parameters[0];
        const [block, next] = parseBlock(cmds, j + 1, c.indent + 1);
        if (isCancel) cmd.cancelCommands = block; else if (cmd.choices[idx]) cmd.choices[idx].commands = block;
        j = next;
      }
      if (j < cmds.length && cmds[j].code === 404) j++;
      return [cmd, j];
    }
    case 111: {
      let condition = null;
      switch (p[0]) {
        case 0: condition = { type: 'switch', id: p[1], value: p[2] === 0 }; break;
        case 1: condition = { type: 'variable', id: p[1], operator: OPERATORS[p[4]] || '==', operand: p[2] === 1 ? { type: 'variable', id: p[3] } : { type: 'constant', value: p[3] } }; break;
        case 2: condition = { type: 'selfSwitch', ch: p[1], value: p[2] === 0 }; break;
        case 6: condition = { type: 'facing', target: p[1], direction: p[2] }; break;
        case 12: condition = { type: 'script', code: p[1] || '' }; break;
        default: return rawUntil(cmds, i, indent, 412);
      }
      const cmd = { klass: 'ConditionalBranch', condition, commands: [], elseCommands: null };
      let [block, j] = parseBlock(cmds, i + 1, c.indent + 1);
      cmd.commands = block;
      if (j < cmds.length && cmds[j].code === 411 && cmds[j].indent === c.indent) {
        [block, j] = parseBlock(cmds, j + 1, c.indent + 1);
        cmd.elseCommands = block;
      }
      if (j < cmds.length && cmds[j].code === 412) j++;
      return [cmd, j];
    }
    case 112: {
      let [block, j] = parseBlock(cmds, i + 1, c.indent + 1);
      if (j < cmds.length && cmds[j].code === 413) j++;
      return [{ klass: 'Loop', commands: block }, j];
    }
    case 113: return [{ klass: 'BreakLoop' }, i + 1];
    case 115: return [{ klass: 'ExitEvent' }, i + 1];
    case 116: return [{ klass: 'EraseEvent' }, i + 1];
    case 117: return [{ klass: 'CallCommonEvent', id: p[0] }, i + 1];
    case 118: return [{ klass: 'Label', name: p[0] }, i + 1];
    case 119: return [{ klass: 'JumpToLabel', name: p[0] }, i + 1];
    case 121: return [{ klass: 'ControlSwitches', from: p[0], to: p[1], value: p[2] === 0 }, i + 1];
    case 122: {
      // Point de retour après une défaite : 47 (carte), 48 (X), 49 (Y) mis à une valeur à la suite
      const setConst = (k, id) => cmds[k] && cmds[k].code === 122 && cmds[k].indent === c.indent && cmds[k].parameters[0] === id && cmds[k].parameters[1] === id && cmds[k].parameters[2] === 0 && cmds[k].parameters[3] === 0;
      if (setConst(i, 47) && setConst(i + 1, 48) && setConst(i + 2, 49)) return [{ klass: 'SetRespawn', mode: 'pos', mapId: p[4], x: cmds[i + 1].parameters[4], y: cmds[i + 2].parameters[4] }, i + 3];
      let operand;
      if (p[3] === 0) operand = { type: 'constant', value: p[4] };
      else if (p[3] === 1) operand = { type: 'variable', id: p[4] };
      else if (p[3] === 2) operand = { type: 'random', min: p[4], max: p[5] };
      else return rawFrom(cmds, i, indent);
      return [{ klass: 'ControlVariables', from: p[0], to: p[1], operation: VAR_OPERATIONS[p[2]] || 'set', operand }, i + 1];
    }
    case 123: return [{ klass: 'ControlSelfSwitch', ch: p[0], value: p[1] === 0 }, i + 1];
    case 106: return [{ klass: 'Wait', frames: p[0] }, i + 1];
    case 201: if (p[0] !== 0) return rawFrom(cmds, i, indent);
      return [{ klass: 'TransferPlayer', mapId: p[1], x: p[2], y: p[3], direction: p[4], fade: p[5] === 0 }, i + 1];
    case 202: if (p[1] !== 0) return rawFrom(cmds, i, indent);
      return [{ klass: 'SetEventLocation', target: p[0], x: p[2], y: p[3], direction: p[4] }, i + 1];
    case 208: return [{ klass: 'ChangeTransparency', transparent: p[0] === 0 }, i + 1];
    case 209: {
      let j = i + 1;
      while (j < cmds.length && cmds[j].code === 509) j++;
      return [{ klass: 'SetMoveRoute', target: p[0], route: convertMoveRoute(p[1]) }, j];
    }
    case 210: return [{ klass: 'WaitForMoveCompletion' }, i + 1];
    case 241: return [{ klass: 'PlayBGM', audio: audio(p[0]) }, i + 1];
    case 242: return [{ klass: 'FadeOutBGM', seconds: p[0] }, i + 1];
    case 245: return [{ klass: 'PlayBGS', audio: audio(p[0]) }, i + 1];
    case 246: return [{ klass: 'FadeOutBGS', seconds: p[0] }, i + 1];
    case 249: return [{ klass: 'PlayME', audio: audio(p[0]) }, i + 1];
    case 250: return [{ klass: 'PlaySE', audio: audio(p[0]) }, i + 1];
    default: return rawFrom(cmds, i, indent);
  }
}

// Reconnaît les scripts PSDK courants pour les rendre éditables comme des blocs Pokémon
const HEAL_SCRIPT = '$actors.each { |pkm| pkm.cure; pkm.hp = pkm.max_hp; pkm.skills_set.each { |s| s.pp = s.ppmax if s.respond_to?(:ppmax) } }';
const RESPAWN_HERE_SCRIPT = '$game_variables[47] = $game_map.map_id; $game_variables[48] = $game_player.x - Yuki::MapLinker.get_OffsetX; $game_variables[49] = $game_player.y - Yuki::MapLinker.get_OffsetY';
function scriptToCommand(code) {
  const c = code.trim();
  let m;
  if (c === HEAL_SCRIPT) return { klass: 'HealParty' };
  if ((m = c.match(/^ecran_console\((true|false)\)$/))) return { klass: 'ConsoleScreen', action: m[1] === 'true' ? 'show' : 'hide', theme: 'neon' };
  if ((m = c.match(/^ecran_console_theme\("(\w+)"\)$/))) return { klass: 'ConsoleScreen', action: 'theme', theme: m[1] };
  if (c === RESPAWN_HERE_SCRIPT) return { klass: 'SetRespawn', mode: 'here', mapId: 1, x: 0, y: 0 };
  if (/^(?:start_pc|demarrer_pc)$/.test(c)) return { klass: 'OpenPC' };
  if (c === 'delete_this_event_forever') return { klass: 'DeleteEventForever', event: 0 };
  if ((m = c.match(/^(?:delete_event_forever|delete_event)\(\s*(\d+)\s*\)$/))) return { klass: 'DeleteEventForever', event: +m[1] };
  if ((m = c.match(/^(?:add_pokemon|ajouter_pokemon)\(\s*:(\w+)\s*,\s*(\d+)\s*(?:,\s*(true|false))?\s*\)$/))) return { klass: 'GivePokemon', pokemon: m[1], level: +m[2], shiny: m[3] === 'true' };
  if ((m = c.match(/^(?:add_pokemon_variant|ajouter_pokemon_variante)\(\s*:(\w+)\s*,\s*(\d+)\s*,\s*:(\w+)\s*\)$/))) return { klass: 'GivePokemon', pokemon: m[1], level: +m[2], form: null, variant: m[3] };
  if ((m = c.match(/^personnaliser_joueur(?:\(\s*(true|false)?\s*(?:,\s*(?::(choisir)|'([mf])'))?\s*\))?$/))) return { klass: 'PJ_CustomizePlayer', cancellable: m[1] === 'true', gender: m[2] || m[3] || '' };
  if (c === 'choisir_genre_joueur') return { klass: 'PJ_ChooseGender', question: '', boy: '', girl: '', variable: 0 };
  if ((m = c.match(/^choisir_genre_joueur\(\s*("(?:[^"\\]|\\.)*")\s*,\s*("(?:[^"\\]|\\.)*")\s*,\s*("(?:[^"\\]|\\.)*")\s*,\s*(\d+)\s*\)$/))) {
    try { return { klass: 'PJ_ChooseGender', question: JSON.parse(m[1]), boy: JSON.parse(m[2]), girl: JSON.parse(m[3]), variable: +m[4] }; } catch (e) { /* script brut */ }
  }
  if ((m = c.match(/^(?:call_battle_wild|demarrer_combat)\(\s*:(\w+)\s*,\s*(\d+)\s*\)$/))) return { klass: 'WildBattle', pokemon: m[1], level: +m[2] };
  if ((m = c.match(/^start_trainer_battle\(\s*(\d+)\s*(?:,\s*bgm:\s*(['"])(.*?)\2)?\s*(?:,\s*troop_id:\s*(\d+))?\s*\)$/))) return { klass: 'TrainerBattle', trainerId: +m[1], bgm: m[3] || '', troopId: m[4] ? +m[4] : 3 };
  if ((m = c.match(/^add_item\(\s*:(\w+)\s*(?:,\s*false)?\s*(?:,\s*count:\s*(\d+))?\s*\)$/))) return { klass: 'GiveItem', item: m[1], count: m[2] ? +m[2] : 1 };
  if ((m = c.match(/^open_shop\(\s*:(\w+)\s*\)$/))) return { klass: 'OpenShop', shop: m[1] };
  if ((m = c.match(/^planter_baie_depart\(\s*:(\w+)\s*(?:,\s*(\d+))?\s*(?:,\s*(nil|\d+))?\s*(?:,\s*(\d+))?\s*\)$/))) return { klass: 'PlantBerry', item: m[1], stage: m[2] ? +m[2] : 4, event: m[3] && m[3] !== 'nil' ? +m[3] : 0, map: m[4] ? +m[4] : 0 };
  // Ancienne façon (cinématique de départ) : Yuki::Berries.init_berry(carte, évènement, :baie, stade)
  if ((m = c.match(/^(?:Yuki::Berries\.)?init_berry\(\s*(\d+)\s*,\s*(\d+)\s*,\s*:(\w+)\s*(?:,\s*(\d+))?\s*\)$/))) return { klass: 'PlantBerry', item: m[3], stage: m[4] ? +m[4] : 4, event: +m[2], map: +m[1] };
  return { klass: 'Script', code };
}

function convertPage(pg) {
  const c = pg['@condition'] || {};
  const g = pg['@graphic'] || {};
  return {
    conditions: {
      switch1: c['@switch1_valid'] ? c['@switch1_id'] : null,
      switch2: c['@switch2_valid'] ? c['@switch2_id'] : null,
      variable: c['@variable_valid'] ? { id: c['@variable_id'], value: c['@variable_value'] } : null,
      selfSwitch: c['@self_switch_valid'] ? c['@self_switch_ch'] : null,
    },
    graphic: {
      characterName: g['@character_name'] || '', tileId: g['@tile_id'] || 0, hue: g['@character_hue'] || 0,
      direction: g['@direction'] || 2, pattern: g['@pattern'] || 0, opacity: g['@opacity'] ?? 255, blendType: g['@blend_type'] || 0,
    },
    moveType: MOVE_TYPES[pg['@move_type']] || 'fixed',
    moveSpeed: pg['@move_speed'] || 3,
    moveFrequency: pg['@move_frequency'] || 3,
    moveRoute: convertMoveRoute(pg['@move_route']),
    walkAnime: !!pg['@walk_anime'], stepAnime: !!pg['@step_anime'], directionFix: !!pg['@direction_fix'],
    through: !!pg['@through'], alwaysOnTop: !!pg['@always_on_top'],
    trigger: TRIGGERS[pg['@trigger']] || 'action',
    commands: convertList(pg['@list'] || []),
  };
}

function convertEvent(ev) {
  return { klass: 'MapEvent', id: ev['@id'], name: ev['@name'] || '', x: ev['@x'], y: ev['@y'], pages: (ev['@pages'] || []).map(convertPage) };
}

// -----------------------------------------------------------------------------
// Utilitaires fichiers / CSV
// -----------------------------------------------------------------------------
const join = (projectPath, rel) => path.join(projectPath, ...rel.split('/'));
const exists = (p) => { try { return fs.existsSync(p); } catch (e) { return false; } };

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

const csvCache = new Map();
function readTexts(projectPath, fileId) {
  const rel = fileId >= 200000 && fileId < 300000 ? `Data/Text/Studio/${fileId}.csv` : `Data/Text/Dialogs/${fileId}.csv`;
  const full = join(projectPath, rel);
  if (!exists(full)) return null;
  const mtime = fs.statSync(full).mtimeMs;
  const cached = csvCache.get(full);
  if (cached && cached.mtime === mtime) return cached.data;
  const rows = parseCsv(fs.readFileSync(full, 'utf8').replace(/^﻿/, ''));
  const header = rows[0] || [];
  let col = header.indexOf('fr'); if (col < 0) col = header.indexOf('en'); if (col < 0) col = 0;
  const data = (id) => { const r = rows[id + 1]; return r && r[col] ? r[col] : null; };
  csvCache.set(full, { mtime, data });
  return data;
}

// Arborescence des cartes de Studio (Data/Studio/map_info.json) : dossiers et cartes dans l'ordre de l'onglet Carte
// Noms des dossiers : Data/Text/Studio/200004.csv (textId)
function readMapTree(projectPath) {
  const full = join(projectPath, 'Data/Studio/map_info.json');
  if (!exists(full)) return null;
  try {
    const raw = JSON.parse(fs.readFileSync(full, 'utf8'));
    const folderNames = readTexts(projectPath, 200004);
    const nodes = {};
    Object.values(raw).forEach((n) => {
      if (!n || n.id === undefined || !n.data) return;
      const klass = n.data.klass;
      nodes[n.id] = {
        id: n.id, children: Array.isArray(n.children) ? n.children : [], expanded: !!n.isExpanded,
        type: klass === 'MapInfoFolder' ? 'folder' : klass === 'MapInfoRoot' ? 'root' : 'map',
        dbSymbol: n.data.mapDbSymbol || null,
        name: klass === 'MapInfoFolder' ? ((folderNames && folderNames(n.data.textId)) || `Dossier ${n.data.textId}`) : null,
      };
    });
    const root = Object.values(nodes).find((n) => n.type === 'root');
    return root ? { root: root.id, nodes } : null;
  } catch (e) {
    console.error('pj-events : map_info.json illisible', e);
    return null;
  }
}

// Listes des plugins pour l'onglet « Plugins » de l'éditeur (réglages faits dans Studio) : { nom: [{ dbSymbol, name }] }
function pluginLists(projectPath) {
  const read = (file) => {
    try { return JSON.parse(fs.readFileSync(join(projectPath, `Data/configs/plugins/${file}.json`), 'utf8').replace(/^﻿/, '')); } catch (e) { return null; }
  };
  const label = (n, fallback) => (n && typeof n === 'object' ? n.fr || n.en || Object.values(n)[0] : n) || fallback;
  const entries = (list) => (Array.isArray(list) ? list : []).filter((x) => x && x.id !== undefined && x.id !== null)
    .map((x) => ({ dbSymbol: String(x.id), name: label(x.name, String(x.id)) }));
  const out = {};
  const statuts = read('statuts'); out.statuses = entries(statuts && statuts.statuses);
  const mag = read('magasins'); out.shops = entries(mag && mag.shops); out.sellers = entries(mag && mag.sellers);
  const succes = read('succes'); out.achievements = entries(succes && succes.achievements);
  const badges = read('etui_badges'); out.badges = entries(badges && badges.badges); out.badgeRegions = entries(badges && badges.regions);
  const sdf = read('sac_de_frappe'); out.punchSessions = entries(sdf && sdf.sessions);
  const triad = read('triple_triad'); out.triadDecks = entries(triad && triad.decks);
  const perso = read('personnages'); out.heroes = entries(perso && perso.heroes); out.allies = entries(perso && perso.allies);
  const raidMaps = read('raids_cartes'); out.raidMaps = entries(raidMaps && raidMaps.maps);
  const tournois = read('tournois'); out.tournaments = entries(tournois && tournois.tournaments);
  const concours = read('concours');
  out.contestTypes = entries(concours && concours.types); out.contestRanks = entries(concours && concours.ranks);
  out.contestAccessories = entries(concours && concours.accessories); out.contestBackdrops = entries(concours && concours.backdrops);
  const montures = read('montures');
  out.mounts = (Array.isArray(montures && montures.mounts) ? montures.mounts : []).filter((x) => x && x.id)
    .map((x) => ({ dbSymbol: String(x.id), name: label(x.name, '') || String(x.species || x.id) }));
  const athlon = read('pokeathlon');
  const courses = Array.isArray(athlon && athlon.courses) && athlon.courses.length ? athlon.courses
    : [['speed', 'Coupe Vitesse'], ['power', 'Coupe Force'], ['skill', 'Coupe Technique'], ['stamina', 'Coupe Endurance'], ['jump', 'Coupe Saut']].map(([id, fr]) => ({ id, name: { fr } }));
  out.athlonCourses = entries(courses);
  const friends = read('pokesmart_friends');
  out.friends = entries(friends && (friends.friends || friends.contacts));
  const smart = read('pokesmart_config');
  const appNames = { open_dex: 'Pokédex', open_party: 'Équipe', open_bag: 'Sac', open_map: 'Carte', open_pc: 'PC', open_quest: 'Quêtes',
    open_tcard: 'Carte dresseur', open_badges: 'Étui à badges', open_amie: 'Poké Récré', open_friends: 'Amis', open_achievements: 'Succès',
    open_customization: 'Personnalisation', open_pokenav: 'PokéNav', open_camera: 'Appareil photo', open_save: 'Sauvegarde', open_option: 'Options' };
  const apps = Object.keys((smart && smart.app_texts) || {});
  out.apps = [...new Set([...apps, ...Object.keys(appNames)])].map((a) => ({ dbSymbol: a, name: appNames[a] || a }));
  return out;
}

async function readJsonFolder(projectPath, rel) {
  const dir = join(projectPath, rel);
  if (!exists(dir)) return [];
  const files = (await fsp.readdir(dir)).filter((f) => f.endsWith('.json'));
  const out = [];
  for (const f of files) {
    try { out.push(JSON.parse(await fsp.readFile(path.join(dir, f), 'utf8'))); } catch (e) { /* ignoré */ }
  }
  return out;
}

async function listFiles(projectPath, rel, exts) {
  const dir = join(projectPath, rel);
  if (!exists(dir)) return [];
  const out = [];
  const walk = async (d, prefix) => {
    for (const ent of await fsp.readdir(d, { withFileTypes: true })) {
      if (ent.isDirectory()) await walk(path.join(d, ent.name), prefix + ent.name + '/');
      else if (exts.includes(path.extname(ent.name).toLowerCase())) out.push(prefix + ent.name);
    }
  };
  await walk(dir, '');
  return out.sort((a, b) => a.localeCompare(b));
}

async function writeJson(file, data) {
  await fsp.mkdir(path.dirname(file), { recursive: true });
  if (exists(file) && !exists(file + '.bak')) await fsp.copyFile(file, file + '.bak');
  const tmp = file + '.tmp';
  await fsp.writeFile(tmp, JSON.stringify(data, null, 2), 'utf8');
  await fsp.rename(tmp, file);
}

const RUNTIME_NAME = '90000 StudioEvents.rb';
const norm = (t) => t.replace(/\r\n/g, '\n').replace(/^\uFEFF/, '');
const RUNTIME_SOURCE = path.join(__dirname, 'pj-events-runtime.rb');
// Le script PSDK est-il présent (et à jour) dans scripts/ du projet ?
function runtimeStatus(projectPath) {
  const dir = join(projectPath, 'scripts');
  const file = exists(dir) ? fs.readdirSync(dir).find((f) => /StudioEvents\.rb$/i.test(f)) : null;
  if (!file) return { installed: false, upToDate: false, file: null };
  let upToDate = true;
  try { upToDate = !exists(RUNTIME_SOURCE) || norm(fs.readFileSync(path.join(dir, file), 'utf8')) === norm(fs.readFileSync(RUNTIME_SOURCE, 'utf8')); } catch (e) { /* rien */ }
  return { installed: true, upToDate, file };
}

const safeName = (s) => String(s).replace(/[^a-zA-Z0-9_\-]/g, '_');
const pad3 = (n) => String(n).padStart(3, '0');

function readSystemNames(projectPath) {
  const f = join(projectPath, 'Data/System.rxdata');
  if (!exists(f)) return { switches: [], variables: [] };
  try {
    const sys = marshalLoad(fs.readFileSync(f));
    return { switches: sys['@switches'] || [], variables: sys['@variables'] || [] };
  } catch (e) { return { switches: [], variables: [], error: String(e) }; }
}

// -----------------------------------------------------------------------------
// Handlers
// -----------------------------------------------------------------------------
// Déplace les évents de l'ancien emplacement (Data/Studio) vers Data/studio_events
async function migrateLegacyEvents(projectPath) {
  if (!projectPath) return;
  const oldDir = join(projectPath, LEGACY_MAP_EVENTS_DIR);
  const newDir = join(projectPath, MAP_EVENTS_DIR);
  if (exists(oldDir)) {
    await fsp.mkdir(newDir, { recursive: true });
    for (const f of await fsp.readdir(oldDir)) {
      const from = path.join(oldDir, f);
      const to = path.join(newDir, f);
      if (!exists(to)) await fsp.rename(from, to);
    }
    await fsp.rm(oldDir, { recursive: true, force: true });
  }
  for (const ext of ['', '.bak']) {
    const oldFile = join(projectPath, LEGACY_COMMON_EVENTS_FILE + ext);
    const newFile = join(projectPath, COMMON_EVENTS_FILE + ext);
    if (!exists(oldFile)) continue;
    await fsp.mkdir(path.dirname(newFile), { recursive: true });
    if (exists(newFile)) await fsp.unlink(oldFile);
    else await fsp.rename(oldFile, newFile);
  }
}

const handlers = {
  async getContext({ projectPath }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    try { await migrateLegacyEvents(projectPath); } catch (e) { console.error('pj-events : migration impossible', e); }
    const mapNames = readTexts(projectPath, 200002);
    const maps = (await readJsonFolder(projectPath, 'Data/Studio/maps'))
      .filter((m) => m && m.klass === 'Map')
      .map((m) => {
        const base = path.basename(m.tiledFilename || '', '.tmx');
        const overview = base && exists(join(projectPath, `Data/Tiled/Overviews/${base}.png`)) ? `Data/Tiled/Overviews/${base}.png` : null;
        return {
          id: m.id, dbSymbol: m.dbSymbol, name: (mapNames && mapNames(m.id)) || m.dbSymbol,
          width: (m.tileMetadata && m.tileMetadata.width) || 20, height: (m.tileMetadata && m.tileMetadata.height) || 15,
          overview, hasRmxp: exists(join(projectPath, `Data/Map${pad3(m.id)}.rxdata`)),
        };
      })
      .sort((a, b) => a.id - b.id);
    const pokemonNames = readTexts(projectPath, 100000);
    const itemNames = readTexts(projectPath, 100012);
    const formNames = readTexts(projectPath, 100067);
    const radiantDir = join(projectPath, 'graphics/pokedex/pokefrontradiant');
    const radiants = new Set(exists(radiantDir) ? (await fsp.readdir(radiantDir)).map((f) => f.replace(/\.png$/i, '').toLowerCase()) : []);
    const pokemon = (await readJsonFolder(projectPath, 'Data/Studio/pokemon'))
      .map((p) => ({ dbSymbol: p.dbSymbol, id: p.id, name: (pokemonNames && pokemonNames(p.id)) || p.dbSymbol,
        forms: (p.forms || []).map((f) => ({
          form: f.form,
          name: (f.form && f.formTextId && formNames && formNames(f.formTextId.name)) || '',
          radiant: !!(f.resources && f.resources.front && radiants.has(String(f.resources.front).toLowerCase())),
        })) }))
      .sort((a, b) => a.id - b.id);
    const items = (await readJsonFolder(projectPath, 'Data/Studio/items'))
      .map((p) => ({ dbSymbol: p.dbSymbol, id: p.id, name: (itemNames && itemNames(p.id)) || p.dbSymbol }))
      .sort((a, b) => a.id - b.id);
    const trainers = (await readJsonFolder(projectPath, 'Data/Studio/trainers'))
      .map((p) => ({ dbSymbol: p.dbSymbol, id: p.id, name: p.dbSymbol }))
      .sort((a, b) => a.id - b.id);
    const moveNames = readTexts(projectPath, 100006);
    const moves = (await readJsonFolder(projectPath, 'Data/Studio/moves'))
      .map((p) => ({ dbSymbol: p.dbSymbol, id: p.id, name: (moveNames && moveNames(p.id)) || p.dbSymbol }))
      .sort((a, b) => a.id - b.id);
    const lists = pluginLists(projectPath);
    const shops = (await readJsonFolder(projectPath, 'Data/Studio/shops'))
      .map((p) => ({ dbSymbol: p.dbSymbol, id: p.id, name: p.dbSymbol }));
    const names = readSystemNames(projectPath);
    const runtime = runtimeStatus(projectPath);
    const eventDir = join(projectPath, MAP_EVENTS_DIR);
    const eventMaps = exists(eventDir) ? (await fsp.readdir(eventDir)).filter((f) => f.endsWith('.json')).map((f) => f.slice(0, -5)) : [];
    const mapTree = readMapTree(projectPath);
    const scriptsDir = join(projectPath, 'scripts');
    const plugins = exists(scriptsDir) ? (await fsp.readdir(scriptsDir)).filter((d) => exists(path.join(scriptsDir, d, 'config.yml'))) : [];
    return {
      maps, mapTree, pokemon, items, moves, lists, trainers, shops, eventMaps, runtime, projectPath, plugins,
      switches: names.switches, variables: names.variables,
      characters: (await listFiles(projectPath, 'Graphics/Characters', ['.png'])).map((f) => f.replace(/\.png$/i, '')),
      audio: {
        bgm: await listFiles(projectPath, 'Audio/BGM', ['.ogg', '.mp3', '.wav', '.mid', '.midi']),
        bgs: await listFiles(projectPath, 'Audio/BGS', ['.ogg', '.mp3', '.wav']),
        me: await listFiles(projectPath, 'Audio/ME', ['.ogg', '.mp3', '.wav', '.mid', '.midi']),
        se: await listFiles(projectPath, 'Audio/SE', ['.ogg', '.mp3', '.wav']),
      },
      hasRmxpCommonEvents: exists(join(projectPath, 'Data/CommonEvents.rxdata')),
    };
  },

  async readMapEvents({ projectPath, dbSymbol }) {
    const f = join(projectPath, `${MAP_EVENTS_DIR}/${safeName(dbSymbol)}.json`);
    if (!exists(f)) return null;
    return JSON.parse(await fsp.readFile(f, 'utf8'));
  },

  async saveMapEvents({ projectPath, dbSymbol, data }) {
    const f = join(projectPath, `${MAP_EVENTS_DIR}/${safeName(dbSymbol)}.json`);
    if (!data || !data.events || data.events.length === 0) {
      if (exists(f)) await fsp.unlink(f);
      return { deleted: true };
    }
    await writeJson(f, data);
    return { saved: f };
  },

  async readCommonEvents({ projectPath }) {
    const f = join(projectPath, COMMON_EVENTS_FILE);
    if (!exists(f)) return null;
    return JSON.parse(await fsp.readFile(f, 'utf8'));
  },

  async saveCommonEvents({ projectPath, data }) {
    await writeJson(join(projectPath, COMMON_EVENTS_FILE), data);
    return { saved: true };
  },

  // Ajoute ou remplace une entrée dans une liste des réglages d'un plugin (Data/configs/plugins/<plugin>.json)
  // { plugin, list, entry, keys } : la ligne existante qui a les mêmes valeurs pour `keys` est remplacée.
  async upsertPluginEntry({ projectPath, plugin, list, entry, keys }) {
    if (!/^[a-z0-9_]+$/i.test(String(plugin)) || !/^[a-z0-9_]+$/i.test(String(list))) throw new Error('Plugin ou liste invalide');
    const f = join(projectPath, `Data/configs/plugins/${plugin}.json`);
    if (!exists(f)) throw new Error(`Réglages introuvables : Data/configs/plugins/${plugin}.json`);
    const data = JSON.parse(norm(await fsp.readFile(f, 'utf8')));
    if (!Array.isArray(data[list])) data[list] = [];
    const same = (x) => x && (keys || []).length > 0 && keys.every((k) => String(x[k]) === String(entry[k]));
    const i = data[list].findIndex(same);
    if (i >= 0) data[list][i] = entry; else data[list].push(entry);
    await writeJson(f, data);
    return { replaced: i >= 0, count: data[list].length };
  },

  async installRuntime({ projectPath }) {
    const src = fs.readFileSync(RUNTIME_SOURCE, 'utf8');
    const dir = join(projectPath, 'scripts');
    await fsp.mkdir(dir, { recursive: true });
    const st = runtimeStatus(projectPath);
    if (st.file && st.file !== RUNTIME_NAME) await fsp.unlink(path.join(dir, st.file));
    await fsp.writeFile(path.join(dir, RUNTIME_NAME), src, 'utf8');
    return runtimeStatus(projectPath);
  },

  async readRmxpEvents({ projectPath, mapId }) {
    const f = join(projectPath, `Data/Map${pad3(mapId)}.rxdata`);
    if (!exists(f)) return [];
    const map = marshalLoad(await fsp.readFile(f));
    return hashEntries(map['@events'])
      .map(([, ev]) => { try { return convertEvent(ev); } catch (e) { return { klass: 'MapEvent', id: ev['@id'], name: ev['@name'], x: ev['@x'], y: ev['@y'], pages: [], error: String(e) }; } })
      .sort((a, b) => a.id - b.id);
  },

  async readRmxpCommonEvents({ projectPath }) {
    const f = join(projectPath, 'Data/CommonEvents.rxdata');
    if (!exists(f)) return [];
    const list = marshalLoad(await fsp.readFile(f));
    return (list || []).filter(Boolean).map((ce) => ({
      id: ce['@id'], name: ce['@name'] || '', trigger: COMMON_TRIGGERS[ce['@trigger']] || 'none',
      switchId: ce['@switch_id'] || 1, commands: convertList(ce['@list'] || []),
    }));
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([name, fn]) => {
    const channel = 'pj-events:' + name;
    try { ipcMain.removeHandler(channel); } catch (e) { /* rien */ }
    ipcMain.handle(channel, async (_event, payload) => {
      try { return { ok: true, value: await fn(payload || {}) }; } catch (e) { return { ok: false, error: String((e && e.stack) || e) }; }
    });
  });
}

module.exports = { register, handlers, marshalLoad, convertEvent, convertList };

try {
  const electron = require('electron');
  if (electron && electron.ipcMain) register(electron.ipcMain);
} catch (e) { /* hors Electron (tests) */ }
