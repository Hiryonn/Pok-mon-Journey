import * as esbuild from 'esbuild';
const w = async (entry) => (await esbuild.build({ entryPoints: [entry], bundle: true, minify: true, format: 'iife', write: false, logLevel: 'error' })).outputFiles[0].text;
const editor = await w('monaco-editor/esm/vs/editor/editor.worker.js');
const json = await w('monaco-editor/esm/vs/language/json/json.worker.js');
await esbuild.build({
  entryPoints: ['src/main.js'], bundle: true, minify: true, format: 'iife', outfile: '../monaco.js', logLevel: 'error',
  loader: { '.ttf': 'dataurl' },
  plugins: [{ name: 'w', setup(b) {
    b.onLoad({ filter: /[\\/]vs[\\/]nls\.js$/ }, async (a) => {
      let src = (await import('fs')).readFileSync(a.path, 'utf8');
      const fr = (await import('fs')).readFileSync('src/fr.json', 'utf8');
      src = 'const __pjFR = ' + fr + ';\n' + src;
      src = src.replace('export function localize(data /* | number when built */, message /* | null when built */, ...args) {', 'export function localize(data, message, ...args) {\n    if (typeof message === "string" && __pjFR[message]) message = __pjFR[message];');
      src = src.replace('    const value = _format(message, args);\n    return {', '    if (typeof message === "string" && __pjFR[message]) message = __pjFR[message];\n    const value = _format(message, args);\n    return {');
      if (!src.includes('__pjFR[message]) message')) throw new Error('nls patch');
      return { contents: src, loader: 'js' };
    });
    b.onResolve({ filter: /^worker:/ }, (a) => ({ path: a.path, namespace: 'w' }));
    b.onLoad({ filter: /.*/, namespace: 'w' }, (a) => ({ contents: 'export default ' + JSON.stringify(a.path === 'worker:json' ? json : editor), loader: 'js' }));
  } }],
});
