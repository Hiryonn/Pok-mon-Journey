#!/usr/bin/env node
'use strict';
// =============================================================================
// Serveur en ligne de Pokémon Journey (relais) — aucune dépendance, Node 18+.
//   node server.js [--port 7777] [--data ./data]
// Protocole : une ligne JSON par message (TCP). Le serveur ne fait pas confiance au client :
//   - comptes : identifiant public (code ami) + jeton secret (stocké haché)
//   - salons à 2 joueurs (échange, défi) : le serveur relaie seulement les messages entre les deux joueurs
//   - limites : taille des lignes, débit, nombre de connexions par adresse, durée de vie des salons
// Étapes suivantes (déjà prévues dans le protocole) : amis, profils, classements, monde partagé, évènements.
// =============================================================================
const net = require('net');
const tls = require('tls');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const args = process.argv.slice(2);
const opt = (name, def) => { const i = args.indexOf('--' + name); return i >= 0 && args[i + 1] ? args[i + 1] : def; };
const PORT = parseInt(opt('port', process.env.PJ_PORT || '7777'), 10);
const DATA_DIR = path.resolve(opt('data', process.env.PJ_DATA || path.join(__dirname, 'data')));
const MAX_LINE = 64 * 1024;          // octets par message
const RATE = { burst: 40, perSecond: 20 }; // messages
const MAX_CONN_PER_IP = 8;
const ROOM_TTL_MS = 15 * 60 * 1000;
const IDLE_TIMEOUT_MS = 90 * 1000;
const PROTOCOL = 1;
const ROOM_KINDS = new Set(['trade', 'duel']);
const log = (...a) => console.log(new Date().toISOString(), ...a);

// --- comptes ---------------------------------------------------------------------------------------
fs.mkdirSync(DATA_DIR, { recursive: true });
const ACCOUNTS_FILE = path.join(DATA_DIR, 'accounts.json');
let accounts = {};
try { accounts = JSON.parse(fs.readFileSync(ACCOUNTS_FILE, 'utf8')); } catch (e) { accounts = {}; }
let dirty = false;
const saveAccounts = () => {
  if (!dirty) return;
  dirty = false;
  const tmp = ACCOUNTS_FILE + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(accounts, null, 1));
  fs.renameSync(tmp, ACCOUNTS_FILE);
};
setInterval(saveAccounts, 5000).unref();
const sha = (s) => crypto.createHash('sha256').update(String(s)).digest('hex');
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sans 0/O/1/I
const randomCode = (n) => Array.from(crypto.randomBytes(n), (b) => ALPHABET[b % ALPHABET.length]).join('');
const cleanName = (n) => String(n || '').replace(/[\u0000-\u001f\u007f<>]/g, '').trim().slice(0, 16) || 'Dresseur';

function createAccount(name) {
  let id;
  do { id = randomCode(8); } while (accounts[id]);
  const token = crypto.randomBytes(24).toString('hex');
  accounts[id] = { name: cleanName(name), tokenHash: sha(token), created: Date.now(), lastSeen: Date.now() };
  dirty = true;
  return { id, token };
}
function checkAccount(id, token) {
  const a = accounts[id];
  return !!a && typeof token === 'string' && crypto.timingSafeEqual(Buffer.from(a.tokenHash), Buffer.from(sha(token)));
}

// --- connexions et salons --------------------------------------------------------------------------
const clients = new Map();   // id → client
const rooms = new Map();     // code → { code, kind, host, guest, created }
const perIp = new Map();

function send(c, msg) {
  if (!c || c.socket.destroyed) return;
  try { c.socket.write(JSON.stringify(msg) + '\n'); } catch (e) { /* connexion fermée */ }
}
const err = (c, code, text) => send(c, { t: 'error', code, text });
const publicInfo = (c) => ({ id: c.id, name: c.name });

function closeRoom(room, why, except) {
  rooms.delete(room.code);
  for (const who of [room.host, room.guest]) {
    if (who && who !== except) send(who, { t: 'room_closed', code: room.code, why });
    if (who && who.room === room) who.room = null;
  }
}
function leaveRoom(c, why = 'left') {
  const room = c.room;
  if (!room) return;
  const other = room.host === c ? room.guest : room.host;
  c.room = null;
  rooms.delete(room.code);
  if (other) { other.room = null; send(other, { t: 'peer_left', code: room.code, why }); }
}

const handlers = {
  hello(c, m) {
    if (c.id) return err(c, 'already', 'Déjà connecté');
    if (m.v !== PROTOCOL) return err(c, 'version', `Protocole ${PROTOCOL} requis`);
    let id = m.id; let token = m.token; let fresh = false;
    if (id && !checkAccount(id, token)) return err(c, 'auth', 'Compte inconnu ou jeton invalide');
    if (!id) { ({ id, token } = createAccount(m.name)); fresh = true; }
    if (clients.has(id)) { const old = clients.get(id); err(old, 'replaced', 'Connecté ailleurs'); old.socket.destroy(); }
    if (bannedIds().has(id)) { err(c, 'banned', 'Compte suspendu'); return c.socket.destroy(); }
    c.id = id; c.name = moderated(cleanName(m.name || accounts[id].name));
    accounts[id].name = c.name; accounts[id].lastSeen = Date.now(); dirty = true;
    clients.set(id, c);
    send(c, { t: 'welcome', v: PROTOCOL, id, name: c.name, token: fresh ? token : undefined, online: clients.size });
    log('connexion', id, c.name);
  },
  ping(c) { send(c, { t: 'pong' }); },
  room_create(c, m) {
    if (c.room) return err(c, 'busy', 'Déjà dans un salon');
    if (!ROOM_KINDS.has(m.kind)) return err(c, 'kind', 'Type de salon inconnu');
    let code;
    do { code = randomCode(5); } while (rooms.has(code));
    const room = { code, kind: m.kind, host: c, guest: null, created: Date.now() };
    rooms.set(code, room); c.room = room;
    send(c, { t: 'room', code, kind: room.kind });
  },
  room_join(c, m) {
    if (c.room) return err(c, 'busy', 'Déjà dans un salon');
    const room = rooms.get(String(m.code || '').toUpperCase());
    if (!room || room.guest) return err(c, 'no_room', 'Salon introuvable ou complet');
    if (room.host === c) return err(c, 'self', 'C’est ton propre salon');
    if ((acct(room.host.id).blocked || []).includes(c.id)) return err(c, 'no_room', 'Salon introuvable ou complet');
    room.guest = c; c.room = room;
    send(room.host, { t: 'room_ready', code: room.code, kind: room.kind, peer: publicInfo(c), role: 'host' });
    send(c, { t: 'room_ready', code: room.code, kind: room.kind, peer: publicInfo(room.host), role: 'guest' });
  },
  room_leave(c) { leaveRoom(c); },
  relay(c, m) {
    const room = c.room;
    if (!room || !room.guest) return err(c, 'no_peer', 'Pas de partenaire');
    const other = room.host === c ? room.guest : room.host;
    if (m.data === null || typeof m.data !== 'object') return err(c, 'bad_data', 'Message invalide');
    send(other, { t: 'relay', from: c.id, data: m.data });
  },
};


// --- étape 3 : profils, amis, classements -----------------------------------------------------------
const NUM_FIELDS = { dex_seen: 2000, dex_caught: 2000, badges: 64, play_time: 36000000, trades: 100000, duels_won: 100000, duels_lost: 100000, pvp_won: 100000, pvp_lost: 100000 };
const BOARDS = { dex_caught: 'Pokédex (capturés)', pvp_won: 'Combats en ligne gagnés', duels_won: 'Défis d’équipe gagnés', trades: 'Échanges', badges: 'Badges' };
const MAX_FRIENDS = 100, MAX_REQUESTS = 50;
const num = (v, max) => { const n = Math.floor(Number(v)); return Number.isFinite(n) ? Math.max(0, Math.min(max, n)) : 0; };
function cleanProfile(p) {
  p = p && typeof p === 'object' ? p : {};
  const out = { title: moderated(String(p.title || '').replace(/[\u0000-\u001f\u007f<>]/g, '').slice(0, 24)) };
  out.team = (Array.isArray(p.team) ? p.team : []).filter((x) => typeof x === 'string' && /^[a-z0-9_]{1,40}$/.test(x)).slice(0, 6);
  for (const [k, max] of Object.entries(NUM_FIELDS)) out[k] = num(p[k], max);
  out.dex_caught = Math.min(out.dex_caught, out.dex_seen || out.dex_caught);
  return out;
}
const acct = (id) => { const a = accounts[id]; if (a) { a.friends = a.friends || []; a.requests = a.requests || []; } return a; };
const areFriends = (a, b) => !!acct(a) && acct(a).friends.includes(b);
const card = (id) => ({ id, name: accounts[id].name, online: clients.has(id), profile: accounts[id].profile || null, has_base: !!accounts[id].base });
const need = (c, m) => { const code = String(m.code || '').toUpperCase(); if (!/^[A-Z0-9]{8}$/.test(code) || !accounts[code]) { err(c, 'no_user', 'Code ami inconnu'); return null; } return code; };

Object.assign(handlers, {
  profile_set(c, m) {
    acct(c.id).profile = cleanProfile(m.profile); dirty = true;
    send(c, { t: 'profile_ok' });
  },
  profile_get(c, m) {
    const code = need(c, m); if (!code) return;
    if (code !== c.id && !areFriends(c.id, code)) return err(c, 'private', 'Profil visible par ses amis seulement');
    send(c, { t: 'profile', user: card(code) });
  },
  friends_list(c) {
    const a = acct(c.id);
    send(c, { t: 'friends', friends: a.friends.filter((i) => accounts[i]).map(card), requests: a.requests.filter((i) => accounts[i]).map((i) => ({ id: i, name: accounts[i].name })) });
  },
  friend_add(c, m) {
    const code = need(c, m); if (!code) return;
    if (code === c.id) return err(c, 'self', 'C’est ton propre code');
    const me = acct(c.id), other = acct(code);
    if ((me.blocked || []).includes(code)) return err(c, 'blocked', 'Tu as bloqué cette personne');
    if ((other.blocked || []).includes(c.id)) return send(c, { t: 'friend_ok', a: 'sent', user: { id: code, name: other.name } }); // silencieux
    if (me.friends.includes(code)) return err(c, 'already', 'Déjà ami');
    if (me.requests.includes(code)) { // il m'avait déjà invité : on accepte
      me.requests = me.requests.filter((i) => i !== code); me.friends.push(code); other.friends.push(c.id); dirty = true;
      return send(c, { t: 'friend_ok', a: 'accepted', user: card(code) });
    }
    if (other.requests.includes(c.id)) return err(c, 'pending', 'Demande déjà envoyée');
    if (me.friends.length >= MAX_FRIENDS || other.friends.length >= MAX_FRIENDS) return err(c, 'full', 'Liste d’amis pleine');
    if (other.requests.length >= MAX_REQUESTS) return err(c, 'full', 'Trop de demandes en attente chez cette personne');
    other.requests.push(c.id); dirty = true;
    send(c, { t: 'friend_ok', a: 'sent', user: { id: code, name: other.name } });
    if (clients.has(code)) send(clients.get(code), { t: 'friend_notice', from: publicInfo(c) });
  },
  friend_answer(c, m) {
    const code = need(c, m); if (!code) return;
    const me = acct(c.id);
    if (!me.requests.includes(code)) return err(c, 'no_request', 'Aucune demande de cette personne');
    me.requests = me.requests.filter((i) => i !== code);
    if (m.accept === true) { if (!me.friends.includes(code)) me.friends.push(code); const o = acct(code); if (!o.friends.includes(c.id)) o.friends.push(c.id); }
    dirty = true;
    send(c, { t: 'friend_ok', a: m.accept === true ? 'accepted' : 'declined', user: { id: code, name: accounts[code].name } });
  },
  friend_remove(c, m) {
    const code = need(c, m); if (!code) return;
    acct(c.id).friends = acct(c.id).friends.filter((i) => i !== code);
    acct(code).friends = acct(code).friends.filter((i) => i !== c.id); dirty = true;
    send(c, { t: 'friend_ok', a: 'removed', user: { id: code, name: accounts[code].name } });
  },
  board(c, m) {
    const key = String(m.board || '');
    if (!Object.prototype.hasOwnProperty.call(BOARDS, key)) return err(c, 'board', 'Classement inconnu');
    const all = Object.entries(accounts).filter(([, a]) => a.profile && a.profile[key] > 0).map(([id, a]) => ({ id, name: a.name, value: a.profile[key] }))
      .sort((x, y) => y.value - x.value || x.name.localeCompare(y.name));
    const rows = all.slice(0, 20).map((r, i) => ({ rank: i + 1, id: r.id, name: r.name, value: r.value }));
    const idx = all.findIndex((r) => r.id === c.id);
    send(c, { t: 'board', board: key, title: BOARDS[key], rows, me: idx >= 0 ? { rank: idx + 1, value: all[idx].value } : null, total: all.length });
  },
});


// --- étape 4 : évènements / distributions et boîte d'échange mondiale -----------------------------------
const EVENTS_FILE = path.join(DATA_DIR, 'events.json');   // édité à la main (voir events.exemple.json), relu automatiquement
let eventsCache = { mtime: 0, list: [] };
function loadEvents() {
  try {
    const st = fs.statSync(EVENTS_FILE);
    if (st.mtimeMs !== eventsCache.mtime) {
      const raw = JSON.parse(fs.readFileSync(EVENTS_FILE, 'utf8'));
      eventsCache = { mtime: st.mtimeMs, list: (Array.isArray(raw) ? raw : raw.events || []).filter((e) => e && /^[a-z0-9_-]{1,40}$/.test(e.id) && e.reward) };
    }
  } catch (e) { eventsCache = { mtime: 0, list: [] }; }
  return eventsCache.list;
}
const activeEvent = (e, now = Date.now()) => (!e.start || Date.parse(e.start) <= now) && (!e.end || Date.parse(e.end) >= now);
const codeFails = new Map(); // compte → { n, since } (essais de code ratés)

const BOX_FILE = path.join(DATA_DIR, 'box.json');
let box = { deposits: {}, seq: 1 };
try { box = JSON.parse(fs.readFileSync(BOX_FILE, 'utf8')); } catch (e) { /* nouvelle boîte */ }
let boxDirty = false;
setInterval(() => { if (boxDirty) { boxDirty = false; fs.writeFileSync(BOX_FILE + '.tmp', JSON.stringify(box)); fs.renameSync(BOX_FILE + '.tmp', BOX_FILE); } }, 5000).unref();
const BOX_MAX = 300, BOX_TTL = 30 * 24 * 3600 * 1000, INBOX_MAX = 20;
const symOk = (v) => typeof v === 'string' && /^[a-z0-9_]{1,40}$/.test(v);
const intIn = (v, a, b) => Number.isInteger(v) && v >= a && v <= b;
// Pokémon envoyé par un client : on reconstruit un objet propre (liste blanche) ou on refuse (null)
function cleanMon(m) {
  if (!m || typeof m !== 'object' || m.egg) return null;
  if (!symOk(m.id) || !intIn(m.level, 1, 100) || !intIn(m.form, 0, 99)) return null;
  const six = (a, max) => Array.isArray(a) && a.length === 6 && a.every((n) => intIn(n, 0, max));
  if (!six(m.ivs, 31) || !six(m.evs, 252) || m.evs.reduce((x, y) => x + y, 0) > 510) return null;
  if (!Array.isArray(m.moves) || m.moves.length < 1 || m.moves.length > 4 || !m.moves.every((x) => x && symOk(x.id) && intIn(x.pp, 0, 99))) return null;
  const opt = (v) => (v === undefined || v === null || v === '' ? undefined : (symOk(v) ? v : false));
  const item = opt(m.item), ability = opt(m.ability), ball = opt(m.ball);
  if (item === false || ability === false || ball === false) return null;
  let nature = m.nature;
  if (nature !== undefined && nature !== null && !(typeof nature === 'string' ? symOk(nature) : intIn(nature, 0, 99))) return null;
  const txt = (v, n) => String(v === undefined || v === null ? '' : v).replace(/[\u0000-\u001f\u007f<>]/g, '').slice(0, n);
  return { id: m.id, form: m.form, level: m.level, shiny: m.shiny === true, gender: intIn(m.gender, 0, 2) ? m.gender : 0, nature, ability, item, name: moderated(txt(m.name, 12)), ot: moderated(txt(m.ot, 16)),
    tid: intIn(m.tid, 0, 4294967295) ? m.tid : 0, loyalty: intIn(m.loyalty, 0, 255) ? m.loyalty : 70, ball, exp: intIn(m.exp, 0, 99999999) ? m.exp : 0,
    ivs: m.ivs, evs: m.evs, moves: m.moves.map((x) => ({ id: x.id, pp: x.pp })) };
}
const monLabel = (m) => ({ id: m.id, level: m.level, shiny: m.shiny, form: m.form, name: m.name });
const inboxOf = (id) => { const a = acct(id); a.inbox = a.inbox || []; return a.inbox; };
const uid = () => crypto.randomBytes(6).toString('hex');

Object.assign(handlers, {
  events_list(c) {
    const a = acct(c.id); const claimed = a.claimed || [];
    send(c, { t: 'events', events: loadEvents().filter((e) => activeEvent(e)).map((e) => ({ id: e.id, title: String(e.title || e.id).slice(0, 40), desc: String(e.desc || '').slice(0, 200), end: e.end || null, needs_code: !!e.code, claimed: claimed.includes(e.id), kind: e.reward.type })) });
  },
  event_claim(c, m) {
    const a = acct(c.id); a.claimed = a.claimed || [];
    const e = loadEvents().find((x) => x.id === m.id);
    if (!e || !activeEvent(e)) return err(c, 'no_event', 'Évènement introuvable ou terminé');
    if (a.claimed.includes(e.id)) return err(c, 'claimed', 'Déjà récupéré');
    const f = codeFails.get(c.id) || { n: 0, since: Date.now() };
    if (Date.now() - f.since > 3600000) { f.n = 0; f.since = Date.now(); }
    if (f.n >= 10) return err(c, 'locked', 'Trop d’essais, réessaie plus tard');
    if (e.code && String(m.code || '').trim().toUpperCase() !== String(e.code).toUpperCase()) { f.n++; codeFails.set(c.id, f); return err(c, 'bad_code', 'Code incorrect'); }
    let reward;
    if (e.reward.type === 'pokemon') { const mon = cleanMon(e.reward.mon); if (!mon) return err(c, 'bad_event', 'Évènement mal configuré'); reward = { type: 'pokemon', mon }; }
    else if (e.reward.type === 'item' && symOk(e.reward.item)) reward = { type: 'item', item: e.reward.item, count: Math.max(1, Math.min(99, Math.floor(Number(e.reward.count) || 1))) };
    else return err(c, 'bad_event', 'Évènement mal configuré');
    a.claimed.push(e.id); dirty = true;
    send(c, { t: 'event_reward', id: e.id, title: e.title || e.id, reward });
  },
  box_list(c, m) {
    const now = Date.now();
    let list = Object.values(box.deposits).filter((d) => d.owner !== c.id && now - d.created < BOX_TTL);
    if (symOk(m.species)) list = list.filter((d) => d.mon.id === m.species);
    list.sort((x, y) => y.created - x.created);
    send(c, { t: 'box', deposits: list.slice(0, 30).map((d) => ({ id: d.id, owner: accounts[d.owner] ? accounts[d.owner].name : '?', mon: monLabel(d.mon), want: d.want })), total: list.length });
  },
  box_mine(c) {
    const mine = Object.values(box.deposits).find((d) => d.owner === c.id);
    send(c, { t: 'box_mine', deposit: mine ? { id: mine.id, mon: monLabel(mine.mon), want: mine.want } : null, inbox: inboxOf(c.id).length });
  },
  box_deposit(c, m) {
    if (Object.values(box.deposits).some((d) => d.owner === c.id)) return err(c, 'has_deposit', 'Tu as déjà un dépôt');
    if (Object.keys(box.deposits).length >= BOX_MAX) return err(c, 'full', 'La boîte est pleine');
    const mon = cleanMon(m.mon); if (!mon) return err(c, 'bad_mon', 'Pokémon refusé');
    const w = m.want && typeof m.want === 'object' ? m.want : {};
    const want = { species: symOk(w.species) ? w.species : null, min_level: intIn(w.min_level, 1, 100) ? w.min_level : 1 };
    const id = 'd' + (box.seq++);
    box.deposits[id] = { id, owner: c.id, mon, want, created: Date.now() }; boxDirty = true;
    send(c, { t: 'box_ok', a: 'deposited', id });
  },
  box_withdraw(c) {
    const d = Object.values(box.deposits).find((x) => x.owner === c.id);
    if (!d) return err(c, 'no_deposit', 'Aucun dépôt');
    delete box.deposits[d.id]; boxDirty = true;
    inboxOf(c.id).push({ uid: uid(), mon: d.mon, from: 'retour' }); dirty = true;
    send(c, { t: 'box_ok', a: 'withdrawn' });
  },
  box_take(c, m) {
    const d = box.deposits[String(m.id)];
    if (!d || d.owner === c.id) return err(c, 'gone', 'Ce dépôt n’existe plus');
    const mon = cleanMon(m.mon); if (!mon) return err(c, 'bad_mon', 'Pokémon refusé');
    if (d.want.species && mon.id !== d.want.species) return err(c, 'not_wanted', 'Ce n’est pas l’espèce demandée');
    if (mon.level < d.want.min_level) return err(c, 'too_low', 'Niveau trop bas');
    if (inboxOf(d.owner).length >= INBOX_MAX) return err(c, 'inbox_full', 'Sa boîte de réception est pleine');
    delete box.deposits[d.id]; boxDirty = true;
    inboxOf(d.owner).push({ uid: uid(), mon, from: c.name }); dirty = true;
    send(c, { t: 'box_ok', a: 'taken', mon: d.mon, from: accounts[d.owner] ? accounts[d.owner].name : '?' });
    if (clients.has(d.owner)) send(clients.get(d.owner), { t: 'friend_notice', from: { id: c.id, name: c.name }, box: true });
  },
  box_collect(c) {
    send(c, { t: 'box_inbox', items: inboxOf(c.id).slice(0, 10) });
  },
  box_ack(c, m) {
    const ids = new Set(Array.isArray(m.uids) ? m.uids.map(String) : []);
    const a = acct(c.id); a.inbox = inboxOf(c.id).filter((x) => !ids.has(x.uid)); dirty = true;
    send(c, { t: 'box_ok', a: 'acked' });
  },
});
setInterval(() => { const now = Date.now(); for (const d of Object.values(box.deposits)) if (now - d.created > BOX_TTL) { delete box.deposits[d.id]; boxDirty = true; if (accounts[d.owner]) { inboxOf(d.owner).push({ uid: uid(), mon: d.mon, from: 'expiré' }); dirty = true; } } }, 3600000).unref();


// --- modération, sauvegardes -------------------------------------------------------------------------
const BANNED_FILE = path.join(DATA_DIR, 'banned.json');          // ["CODEAMI1", …] — édité à la main, relu automatiquement
const WORDS_FILE = path.join(DATA_DIR, 'banned_words.txt');      // un mot interdit par ligne (pseudos)
const REPORTS_FILE = path.join(DATA_DIR, 'reports.json');
const watched = (file, parse, def) => { let m = 0, v = def; return () => { try { const st = fs.statSync(file); if (st.mtimeMs !== m) { v = parse(fs.readFileSync(file, 'utf8')); m = st.mtimeMs; } } catch (e) { v = def; m = 0; } return v; }; };
const bannedIds = watched(BANNED_FILE, (t) => new Set(JSON.parse(t).map(String)), new Set());
const bannedWords = watched(WORDS_FILE, (t) => t.split(/\r?\n/).map((w) => w.trim().toLowerCase()).filter(Boolean), []);
const squash = (t) => t.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]/g, '');
const moderated = (name) => { const flat = squash(name); return bannedWords().some((w) => flat.includes(squash(w))) ? 'Dresseur' : name; };
const reportCount = new Map();
function backup() {
  try {
    saveAccounts();
    const dir = path.join(DATA_DIR, 'backups'); fs.mkdirSync(dir, { recursive: true });
    const stamp = new Date().toISOString().slice(0, 13).replace(/[-T]/g, '');
    for (const f of [ACCOUNTS_FILE, BOX_FILE]) if (fs.existsSync(f)) fs.copyFileSync(f, path.join(dir, `${path.basename(f, '.json')}-${stamp}.json`));
    const old = fs.readdirSync(dir).sort(); while (old.length > 28) fs.unlinkSync(path.join(dir, old.shift()));
  } catch (e) { log('sauvegarde impossible', e.message); }
}
backup(); setInterval(backup, 6 * 3600 * 1000).unref();

Object.assign(handlers, {
  block(c, m) {
    const code = need(c, m); if (!code) return;
    if (code === c.id) return err(c, 'self', 'C’est ton propre code');
    const me = acct(c.id); me.blocked = me.blocked || [];
    if (!me.blocked.includes(code)) { if (me.blocked.length >= 100) return err(c, 'full', 'Liste de blocage pleine'); me.blocked.push(code); }
    me.friends = me.friends.filter((i) => i !== code); me.requests = me.requests.filter((i) => i !== code);
    acct(code).friends = acct(code).friends.filter((i) => i !== c.id); dirty = true;
    send(c, { t: 'friend_ok', a: 'blocked', user: { id: code, name: accounts[code].name } });
  },
  unblock(c, m) {
    const code = need(c, m); if (!code) return;
    const me = acct(c.id); me.blocked = (me.blocked || []).filter((i) => i !== code); dirty = true;
    send(c, { t: 'friend_ok', a: 'unblocked', user: { id: code, name: accounts[code].name } });
  },
  report(c, m) {
    const code = need(c, m); if (!code) return;
    const day = new Date().toISOString().slice(0, 10) + c.id; const n = (reportCount.get(day) || 0) + 1; reportCount.set(day, n);
    if (n > 5) return err(c, 'rate', 'Trop de signalements aujourd’hui');
    let list = []; try { list = JSON.parse(fs.readFileSync(REPORTS_FILE, 'utf8')); } catch (e) { list = []; }
    list.push({ date: new Date().toISOString(), from: c.id, fromName: c.name, target: code, targetName: accounts[code].name, reason: String(m.reason || '').replace(/[\u0000-\u001f\u007f]/g, '').slice(0, 200) });
    fs.writeFileSync(REPORTS_FILE, JSON.stringify(list.slice(-2000), null, 1));
    send(c, { t: 'friend_ok', a: 'reported', user: { id: code, name: accounts[code].name } });
  },
});


// --- étape 6 : visite de la base secrète, fantômes sur la carte, invitations -------------------------------
const GHOST_SCOPE = opt('ghosts', process.env.PJ_GHOSTS || 'friends'); // 'friends' (défaut) ou 'everyone'
const GHOST_MAX = 12, PRESENCE_MIN_MS = 120;
const kindOk = (k) => k === 'ach' || k === 'contest' || k === 'item';
function cleanBase(b) {
  if (!b || typeof b !== 'object' || !Array.isArray(b.placed)) return null;
  const used = new Set(); const placed = [];
  for (const e of b.placed.slice(0, 80)) {
    if (!e || !kindOk(e.kind) || typeof e.id !== 'string' || !/^[A-Za-z0-9_\-]{1,40}$/.test(e.id) || !intIn(e.x, 0, 9) || !intIn(e.y, 0, 6)) continue;
    const key = e.x + ',' + e.y; if (used.has(key)) continue; used.add(key);
    const o = { kind: e.kind, id: e.id, x: e.x, y: e.y };
    if (e.kind === 'contest' && symOk(e.species)) { o.species = e.species; o.form = intIn(e.form, 0, 99) ? e.form : 0; o.shiny = e.shiny === true; }
    placed.push(o);
  }
  return { theme: symOk(b.theme) ? b.theme : '', placed, greeting: moderated(String(b.greeting || '').replace(/[\u0000-\u001f\u007f<>]/g, '').slice(0, 40)) };
}
const canSee = (a, b) => a !== b && !(acct(a).blocked || []).includes(b) && !(acct(b).blocked || []).includes(a) && (GHOST_SCOPE === 'everyone' || areFriends(a, b));
const ghostOf = (c) => ({ id: c.id, name: c.name, map: c.pos.map, x: c.pos.x, y: c.pos.y, dir: c.pos.dir, skin: c.pos.skin });
function dropGhost(c, prevMap) {
  if (!c.id || prevMap === undefined || prevMap === null) return;
  for (const o of clients.values()) if (o !== c && o.pos && o.pos.map === prevMap && canSee(c.id, o.id)) send(o, { t: 'ghost_gone', id: c.id });
}
const inviteAt = new Map();

Object.assign(handlers, {
  base_set(c, m) {
    const base = cleanBase(m.base); if (!base) return err(c, 'bad_base', 'Base invalide');
    base.updated = Date.now(); const a = acct(c.id); a.base = Object.assign(a.base || { visits: 0, recent: [] }, base); dirty = true;
    send(c, { t: 'base_ok', items: base.placed.length });
  },
  base_visit(c, m) {
    const code = need(c, m); if (!code) return;
    if (code !== c.id && !areFriends(c.id, code)) return err(c, 'private', 'Base visible par ses amis seulement');
    const base = acct(code).base; if (!base) return err(c, 'no_base', 'Cette personne n’a pas encore partagé sa base');
    if (code !== c.id) {
      base.visits = (base.visits || 0) + 1; base.recent = (base.recent || []).filter((n) => n !== c.name); base.recent.unshift(c.name); base.recent = base.recent.slice(0, 5); dirty = true;
    }
    send(c, { t: 'base', user: { id: code, name: accounts[code].name }, base: { theme: base.theme, placed: base.placed, greeting: base.greeting }, visits: base.visits || 0, recent: base.recent || [] });
  },
  presence(c, m) {
    const now = Date.now(); if (c.pos && now - (c.posAt || 0) < PRESENCE_MIN_MS) return;
    c.posAt = now;
    if (!intIn(m.map, 1, 9999) || !intIn(m.x, 0, 999) || !intIn(m.y, 0, 999) || !intIn(m.dir, 0, 10)) return err(c, 'bad_pos', 'Position invalide');
    const skin = typeof m.skin === 'string' && /^[A-Za-z0-9_\- ]{0,40}$/.test(m.skin) ? m.skin : '';
    const prev = c.pos ? c.pos.map : null;
    c.pos = { map: m.map, x: m.x, y: m.y, dir: m.dir, skin };
    if (prev !== null && prev !== m.map) dropGhost(c, prev);
    const mine = ghostOf(c);
    let seen = 0;
    for (const o of clients.values()) {
      if (o === c || !o.pos || o.pos.map !== m.map || !canSee(c.id, o.id)) continue;
      send(o, { t: 'ghost', ghost: mine });
      if (prev !== m.map && seen < GHOST_MAX) { send(c, { t: 'ghost', ghost: ghostOf(o) }); seen++; }
    }
  },
  listen(c, m) { c.listening = m.on !== false; },
  presence_off(c) { const prev = c.pos ? c.pos.map : null; c.pos = null; dropGhost(c, prev); },
  invite(c, m) {
    const to = need(c, { code: m.to }); if (!to) return;
    const o = clients.get(to);
    if (!['trade', 'duel', 'pvp'].includes(m.kind) || !/^[A-Z0-9]{3,8}$/.test(String(m.code || ''))) return err(c, 'bad_invite', 'Invitation invalide');
    if (!o || !o.listening || !canSee(c.id, to)) return err(c, 'offline', 'Ce joueur n’est pas joignable (jeu en ligne actif ?)');
    const last = inviteAt.get(c.id) || 0; if (Date.now() - last < 8000) return err(c, 'rate', 'Patiente quelques secondes entre deux invitations');
    inviteAt.set(c.id, Date.now());
    send(o, { t: 'invite', from: publicInfo(c), kind: m.kind, code: String(m.code) });
    send(c, { t: 'invite_ok', to: { id: to, name: o.name } });
  },
});

const onConnection = (socket) => {
  const ip = socket.remoteAddress || '?';
  const n = (perIp.get(ip) || 0) + 1;
  if (n > MAX_CONN_PER_IP) { socket.destroy(); return; }
  perIp.set(ip, n);
  socket.setNoDelay(true);
  const c = { socket, id: null, name: null, room: null, buf: '', tokens: RATE.burst, last: Date.now(), seen: Date.now() };
  socket.setTimeout(IDLE_TIMEOUT_MS, () => socket.destroy());
  socket.on('data', (chunk) => {
    c.seen = Date.now();
    c.buf += chunk.toString('utf8');
    if (c.buf.length > MAX_LINE * 2) { socket.destroy(); return; }
    let i;
    while ((i = c.buf.indexOf('\n')) >= 0) {
      const line = c.buf.slice(0, i); c.buf = c.buf.slice(i + 1);
      if (line.length > MAX_LINE) { err(c, 'too_big', 'Message trop gros'); socket.destroy(); return; }
      if (!line.trim()) continue;
      const now = Date.now();
      c.tokens = Math.min(RATE.burst, c.tokens + ((now - c.last) / 1000) * RATE.perSecond); c.last = now;
      if (c.tokens < 1) { err(c, 'rate', 'Trop de messages'); continue; }
      c.tokens -= 1;
      let m;
      try { m = JSON.parse(line); } catch (e) { err(c, 'json', 'JSON invalide'); continue; }
      if (!m || typeof m !== 'object' || typeof m.t !== 'string') { err(c, 'bad', 'Message invalide'); continue; }
      const fn = handlers[m.t];
      if (!fn || !Object.prototype.hasOwnProperty.call(handlers, m.t)) { err(c, 'unknown', 'Message inconnu : ' + m.t.slice(0, 20)); continue; }
      if (m.t !== 'hello' && m.t !== 'ping' && !c.id) { err(c, 'auth', 'hello attendu'); continue; }
      try { fn(c, m); } catch (e) { log('erreur', m.t, e.message); err(c, 'server', 'Erreur serveur'); }
    }
  });
  socket.on('error', () => {});
  socket.on('close', () => {
    perIp.set(ip, Math.max(0, (perIp.get(ip) || 1) - 1));
    if (c.room) leaveRoom(c, 'disconnected');
    if (c.pos) dropGhost(c, c.pos.map);
    if (c.id && clients.get(c.id) === c) clients.delete(c.id);
  });
};
const TLS_CERT = opt('tls-cert', process.env.PJ_TLS_CERT || ''), TLS_KEY = opt('tls-key', process.env.PJ_TLS_KEY || '');
const server = TLS_CERT && TLS_KEY
  ? tls.createServer({ cert: fs.readFileSync(TLS_CERT), key: fs.readFileSync(TLS_KEY) }, onConnection)
  : net.createServer(onConnection);

setInterval(() => {
  const now = Date.now();
  for (const room of [...rooms.values()]) if (now - room.created > ROOM_TTL_MS) closeRoom(room, 'expired');
}, 30000).unref();

function shutdown() { try { fs.writeFileSync(BOX_FILE, JSON.stringify(box)); } catch (e) { /* ignoré */ } backup(); try { fs.writeFileSync(BOX_FILE, JSON.stringify(box)); } catch (e) { /* ignoré */ } server.close(); process.exit(0); }
process.on('SIGINT', shutdown); process.on('SIGTERM', shutdown);

server.listen(PORT, () => log(`Serveur Pokémon Journey en écoute sur le port ${PORT}${TLS_CERT ? ' (TLS)' : ''} (données : ${DATA_DIR})`));
module.exports = { server };
