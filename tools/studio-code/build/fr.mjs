import fs from 'fs';
const dir = 'node_modules/monaco-editor/min/vs/';
const g = {}; new Function('define', fs.readFileSync(dir + 'nls.messages.fr.js', 'utf8'))((deps, f) => f());
const FR = globalThis._VSCODE_NLS_MESSAGES;
const map = {}; let n = 0, bad = 0;
const files = ['editor/editor.main.js', ...fs.readdirSync(dir + 'language').flatMap((d) => fs.readdirSync(dir + 'language/' + d).map((f) => 'language/' + d + '/' + f))];
for (const f of files) {
  const src = fs.readFileSync(dir + f, 'utf8');
  for (const m of src.matchAll(/localize2?\((\d+),\s*("(?:[^"\\]|\\.)*")/g)) {
    let en; try { en = JSON.parse(m[2]); } catch (e) { bad++; continue; }
    const fr = FR[+m[1]];
    if (typeof fr === 'string' && fr !== en && !(en in map)) { map[en] = fr; n++; }
  }
}
fs.writeFileSync('src/fr.json', JSON.stringify(map));
console.log(n, bad, FR.length, map['Find'], map['Replace'], map['Go to Definition']);
