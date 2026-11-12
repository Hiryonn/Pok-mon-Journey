/* eslint-disable */
// =============================================================================
// Aseprite dans Pokémon Studio Extra — partie « processus principal » (Electron main)
// Chargé depuis .vite/build/index.js. Fournit les canaux IPC « pj-aseprite:* ».
//  - lance Aseprite et colle sa fenêtre dans celle de Studio (page « Aseprite » de la barre de gauche)
//  - liste les graphismes du projet (dossier graphics) et les ouvre dans Aseprite
//  - Aseprite reçoit un script (pj-aseprite-bridge.lua) qui referme tout fichier pris hors de graphics
// =============================================================================
'use strict';
const fs = require('fs');
const fsp = require('fs/promises');
const os = require('os');
const path = require('path');
const http = require('http');
const crypto = require('crypto');
const { spawn } = require('child_process');

const EXTENSIONS = ['.png', '.gif', '.aseprite', '.ase', '.bmp', '.jpg', '.jpeg', '.webp', '.tga'];
const exists = (p) => { try { return fs.existsSync(p); } catch (e) { return false; } };

let electron = null;
try { electron = require('electron'); } catch (e) { /* hors Electron (tests) */ }
const userDir = () => (electron && electron.app ? electron.app.getPath('userData') : os.tmpdir());
const SETTINGS = () => path.join(userDir(), 'pj-aseprite.json');

const S = {
  proc: null, hwnd: 0, parent: 0, win: null, root: '', visible: false, bounds: null, starting: null, error: '',
  helper: null, helperQueue: [], helperBuf: '', server: null, port: 0, sock: null, pending: [],
};

// --- Réglages (chemin d'Aseprite) --------------------------------------------
function readSettings() { try { return JSON.parse(fs.readFileSync(SETTINGS(), 'utf8')); } catch (e) { return {}; } }
function writeSettings(data) { fs.writeFileSync(SETTINGS(), JSON.stringify(data, null, 2)); }
function candidates() {
  const home = os.homedir();
  const pf = process.env.ProgramFiles || 'C:\\Program Files';
  const pf86 = process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)';
  return [
    path.join(home, 'Documents', 'Aseprite', 'Aseprite.exe'),
    path.join(pf86, 'Steam', 'steamapps', 'common', 'Aseprite', 'Aseprite.exe'),
    path.join(pf, 'Steam', 'steamapps', 'common', 'Aseprite', 'Aseprite.exe'),
    path.join(pf, 'Aseprite', 'Aseprite.exe'),
    path.join(pf86, 'Aseprite', 'Aseprite.exe'),
  ];
}
function asepritePath() {
  const s = readSettings();
  if (s.exe && exists(s.exe)) return s.exe;
  return candidates().find(exists) || '';
}

// --- Dossier graphics du projet ----------------------------------------------
const graphicsDir = (projectPath) => path.join(projectPath, 'graphics');
function insideRoot(file, root) {
  const rel = path.relative(root, path.resolve(file));
  return !!rel && !rel.startsWith('..') && !path.isAbsolute(rel);
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
    else if (EXTENSIONS.includes(path.extname(d.name).toLowerCase())) out.push({ name: d.name, path: rel });
  }
  return out;
}

// --- Assistant Windows (PowerShell) ------------------------------------------
function helper() {
  if (S.helper) return S.helper;
  const script = path.join(__dirname, 'pj-aseprite-win.ps1');
  const p = spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', script], { windowsHide: true });
  S.helper = { proc: p, ready: null };
  S.helper.ready = new Promise((resolve) => { S.helperQueue.push(resolve); });
  p.stdout.on('data', (chunk) => {
    S.helperBuf += chunk.toString();
    let i;
    while ((i = S.helperBuf.indexOf('\n')) >= 0) {
      const line = S.helperBuf.slice(0, i).trim();
      S.helperBuf = S.helperBuf.slice(i + 1);
      const next = S.helperQueue.shift();
      if (next) next(line);
    }
  });
  p.stderr.on('data', (d) => console.error('[pj-aseprite] ' + d));
  p.on('exit', () => { S.helper = null; S.helperQueue.splice(0).forEach((r) => r('err assistant arrêté')); });
  return S.helper;
}
async function win(cmd) {
  const h = helper();
  await h.ready;
  return new Promise((resolve) => { S.helperQueue.push(resolve); h.proc.stdin.write(cmd + '\n'); });
}

// --- Lien avec le script d'Aseprite (WebSocket minimal) -----------------------
function frame(text) {
  const data = Buffer.from(text, 'utf8');
  let head;
  if (data.length < 126) head = Buffer.from([0x81, data.length]);
  else if (data.length < 65536) { head = Buffer.alloc(4); head[0] = 0x81; head[1] = 126; head.writeUInt16BE(data.length, 2); }
  else { head = Buffer.alloc(10); head[0] = 0x81; head[1] = 127; head.writeBigUInt64BE(BigInt(data.length), 2); }
  return Buffer.concat([head, data]);
}
function control(op, payload) { return Buffer.concat([Buffer.from([0x80 | op, payload.length]), payload]); }
function startServer() {
  if (S.server) return Promise.resolve(S.port);
  return new Promise((resolve, reject) => {
    const server = http.createServer((req, res) => { res.writeHead(404); res.end(); });
    server.on('upgrade', (req, socket) => {
      const key = req.headers['sec-websocket-key'];
      if (!key) { socket.destroy(); return; }
      const accept = crypto.createHash('sha1').update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64');
      socket.write(`HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ${accept}\r\n\r\n`);
      if (S.sock) try { S.sock.destroy(); } catch (e) { /* rien */ }
      S.sock = socket;
      let buf = Buffer.alloc(0);
      socket.on('data', (chunk) => {
        buf = Buffer.concat([buf, chunk]);
        while (buf.length >= 2) {
          const op = buf[0] & 0x0f;
          const masked = buf[1] & 0x80;
          let len = buf[1] & 0x7f;
          let off = 2;
          if (len === 126) { if (buf.length < 4) return; len = buf.readUInt16BE(2); off = 4; } else if (len === 127) { if (buf.length < 10) return; len = Number(buf.readBigUInt64BE(2)); off = 10; }
          const maskOff = off;
          if (masked) off += 4;
          if (buf.length < off + len) return;
          let payload = buf.slice(off, off + len);
          if (masked) payload = payload.map((b, i) => b ^ buf[maskOff + (i % 4)]);
          buf = buf.slice(off + len);
          if (op === 0x9) socket.write(control(0xA, payload));
          else if (op === 0x8) { try { socket.end(control(0x8, Buffer.alloc(0))); } catch (e) { /* rien */ } }
        }
      });
      socket.on('close', () => { if (S.sock === socket) S.sock = null; });
      socket.on('error', () => {});
      S.pending.splice(0).forEach((m) => socket.write(frame(m)));
    });
    server.on('error', reject);
    server.listen(0, '127.0.0.1', () => { S.server = server; S.port = server.address().port; resolve(S.port); });
  });
}
function send(message) {
  if (S.sock && !S.sock.destroyed) S.sock.write(frame(message));
  else S.pending.push(message);
}

// --- Fenêtre d'Aseprite dans Studio ------------------------------------------
const running = () => S.proc && S.proc.exitCode === null && !S.proc.killed;
async function place() {
  if (!S.hwnd) return;
  if (S.visible && S.bounds) {
    const b = S.bounds;
    await win(`move ${S.hwnd} ${Math.round(b.x)} ${Math.round(b.y)} ${Math.max(50, Math.round(b.w))} ${Math.max(50, Math.round(b.h))}`);
    await win(`show ${S.hwnd} 1`);
  } else {
    await win(`show ${S.hwnd} 0`);
  }
}
async function launch(projectPath) {
  const exe = asepritePath();
  if (!exe) throw new Error('Aseprite introuvable : indique où se trouve Aseprite.exe.');
  const root = graphicsDir(projectPath);
  if (!exists(root)) throw new Error('Dossier graphics introuvable dans le projet.');
  const port = await startServer();
  const bridge = path.join(userDir(), 'pj-aseprite-bridge.lua');
  fs.copyFileSync(path.join(__dirname, 'pj-aseprite-bridge.lua'), bridge);
  S.root = root;
  S.error = '';
  S.hwnd = 0;
  S.pending = [];
  const proc = spawn(exe, ['--script-param', `port=${port}`, '--script-param', `root=${root}`, '--script', bridge], { cwd: root, windowsHide: false });
  S.proc = proc;
  proc.on('exit', () => { if (S.proc === proc) { S.proc = null; S.hwnd = 0; } });
  proc.on('error', (e) => { S.error = String(e.message || e); });
  // attend la fenêtre principale d'Aseprite
  let hwnd = 0;
  for (let i = 0; i < 120 && !hwnd && running(); i++) {
    await new Promise((r) => setTimeout(r, 250));
    const r = await win(`find ${proc.pid}`);
    hwnd = Number((r.match(/^found (\d+)/) || [])[1] || 0);
  }
  if (!hwnd) throw new Error(running() ? "La fenêtre d'Aseprite n'est pas apparue." : "Aseprite s'est fermé au démarrage.");
  await new Promise((r) => setTimeout(r, 300));
  const r = await win(`attach ${hwnd} ${S.parent}`);
  if (!r.startsWith('ok')) throw new Error(r);
  S.hwnd = hwnd;
  await place();
}
function watchParent(browserWindow) {
  if (S.win === browserWindow) return;
  S.win = browserWindow;
  // Studio se ferme : Aseprite reprend sa propre fenêtre et demande s'il faut enregistrer
  browserWindow.on('close', () => {
    if (!S.hwnd || !running()) return;
    try { S.helper.proc.stdin.write(`detach ${S.hwnd}\n`); } catch (e) { /* rien */ }
    send('exit');
  });
}

const handlers = {
  async getContext({ projectPath }) {
    const exe = asepritePath();
    const root = projectPath ? graphicsDir(projectPath) : '';
    return {
      exe, found: !!exe, root, rootExists: !!root && exists(root), running: !!(running() && S.hwnd),
      tree: root && exists(root) ? await tree(root, root) : [], platform: process.platform,
    };
  },
  async start({ projectPath, bounds, visible }, event) {
    if (process.platform !== 'win32') throw new Error('Aseprite intégré : Windows uniquement.');
    const bw = electron.BrowserWindow.fromWebContents(event.sender);
    const handle = bw.getNativeWindowHandle();
    S.parent = handle.length >= 8 ? Number(handle.readBigUInt64LE(0)) : handle.readUInt32LE(0);
    watchParent(bw);
    S.bounds = bounds || S.bounds;
    S.visible = visible !== false;
    const root = graphicsDir(projectPath);
    if (running() && S.hwnd) {
      if (root !== S.root) { S.root = root; send('root\t' + root); }
      await place();
      return { running: true };
    }
    if (!S.starting) S.starting = launch(projectPath).finally(() => { S.starting = null; });
    await S.starting;
    return { running: true };
  },
  async layout({ bounds, visible }) {
    if (bounds) S.bounds = bounds;
    if (visible !== undefined) S.visible = !!visible;
    await place();
    return true;
  },
  async focus() {
    if (S.hwnd) await win(`focus ${S.hwnd}`);
    return true;
  },
  async open({ projectPath, file }) {
    const root = graphicsDir(projectPath);
    const full = path.resolve(root, file);
    if (!insideRoot(full, root) || !EXTENSIONS.includes(path.extname(full).toLowerCase())) throw new Error('Seuls les graphismes du projet peuvent être ouverts.');
    send('open\t' + full);
    if (S.hwnd) await win(`focus ${S.hwnd}`);
    return true;
  },
  async restart({ projectPath, bounds }, event) {
    if (running()) { try { S.proc.kill(); } catch (e) { /* rien */ } }
    S.proc = null; S.hwnd = 0;
    await new Promise((r) => setTimeout(r, 400));
    return handlers.start({ projectPath, bounds, visible: true }, event);
  },
  async pickExe() {
    const { dialog, BrowserWindow } = electron;
    const r = await dialog.showOpenDialog(BrowserWindow.getFocusedWindow(), {
      title: 'Aseprite.exe', properties: ['openFile'], filters: [{ name: 'Aseprite', extensions: ['exe'] }], defaultPath: asepritePath() || undefined,
    });
    if (r.canceled || !r.filePaths[0]) return null;
    writeSettings(Object.assign(readSettings(), { exe: r.filePaths[0] }));
    return r.filePaths[0];
  },
  async preview({ projectPath, file }) {
    const root = graphicsDir(projectPath);
    const full = path.resolve(root, file);
    if (!insideRoot(full, root)) return null;
    const ext = path.extname(full).toLowerCase();
    const mime = { '.png': 'image/png', '.gif': 'image/gif', '.bmp': 'image/bmp', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp' }[ext];
    if (!mime) return null;
    const data = await fsp.readFile(full);
    return { url: `data:${mime};base64,` + data.toString('base64'), size: data.length };
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([name, fn]) => {
    const channel = 'pj-aseprite:' + name;
    try { ipcMain.removeHandler(channel); } catch (e) { /* rien */ }
    ipcMain.handle(channel, async (event, payload) => {
      try { return { ok: true, value: await fn(payload || {}, event) }; } catch (e) { return { ok: false, error: String((e && e.message) || e) }; }
    });
  });
  if (electron && electron.app) {
    electron.app.on('will-quit', () => {
      try { if (S.helper) S.helper.proc.kill(); } catch (e) { /* rien */ }
      try { if (S.server) S.server.close(); } catch (e) { /* rien */ }
    });
  }
}

module.exports = { register, handlers };

try {
  if (electron && electron.ipcMain) register(electron.ipcMain);
} catch (e) { /* hors Electron (tests) */ }
