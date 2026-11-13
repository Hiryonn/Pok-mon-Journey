import * as monaco from 'monaco-editor/esm/vs/editor/edcore.main';
import 'monaco-editor/esm/vs/language/json/monaco.contribution';
import 'monaco-editor/esm/vs/basic-languages/ruby/ruby.contribution';
import 'monaco-editor/esm/vs/basic-languages/javascript/javascript.contribution';
import 'monaco-editor/esm/vs/basic-languages/typescript/typescript.contribution';
import 'monaco-editor/esm/vs/basic-languages/css/css.contribution';
import 'monaco-editor/esm/vs/basic-languages/scss/scss.contribution';
import 'monaco-editor/esm/vs/basic-languages/html/html.contribution';
import 'monaco-editor/esm/vs/basic-languages/xml/xml.contribution';
import 'monaco-editor/esm/vs/basic-languages/yaml/yaml.contribution';
import 'monaco-editor/esm/vs/basic-languages/markdown/markdown.contribution';
import 'monaco-editor/esm/vs/basic-languages/ini/ini.contribution';
import 'monaco-editor/esm/vs/basic-languages/bat/bat.contribution';
import 'monaco-editor/esm/vs/basic-languages/powershell/powershell.contribution';
import 'monaco-editor/esm/vs/basic-languages/python/python.contribution';
import 'monaco-editor/esm/vs/basic-languages/shell/shell.contribution';
import 'monaco-editor/esm/vs/basic-languages/sql/sql.contribution';
import 'monaco-editor/esm/vs/basic-languages/cpp/cpp.contribution';
import editorWorker from 'worker:editor';
import jsonWorker from 'worker:json';
const blobUrl = (src) => URL.createObjectURL(new Blob([src], { type: 'text/javascript' }));
const urls = {};
self.MonacoEnvironment = {
  getWorker(_id, label) {
    const key = label === 'json' ? 'json' : 'editor';
    urls[key] = urls[key] || blobUrl(key === 'json' ? jsonWorker : editorWorker);
    return new Worker(urls[key]);
  },
};
window.pjMonaco = monaco;
window.dispatchEvent(new Event('pj-monaco-ready'));
