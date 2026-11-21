# Studio Extra : moteur des correctifs de Pokémon Studio, insensible aux noms raccourcis du code de Studio
#
# Le code de Studio (index-xxxx.js) est « minifié » : ses variables ont des noms courts (j, Aa, R$, Pdo…) qui changent
# à chaque mise à jour. Les correctifs sont écrits avec les noms d'une version de référence ; ici chaque nom est
# remplacé par un joker, le passage est retrouvé dans la version installée, et les vrais noms sont repris dans
# le texte ajouté.
#   - rep(a, b) : remplace le passage a (unique) par b
#   - les noms d'une seule lettre sont des variables locales (liées au passage) ; les autres sont des noms du
#     module, gardés d'un correctif à l'autre ; les noms pj… (les nôtres) ne changent pas
#   - symboles.json : passages de la version de référence qui retrouvent les noms utilisés seulement dans b
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
IDENT = re.compile(r'[A-Za-z_$][\w$]*')
KEYWORDS = set('''break case catch class const continue debugger default delete do else export extends false finally for
function if import in instanceof let new null of return super switch this throw true try typeof undefined var void while
with yield async await window document sessionStorage localStorage String Number Boolean Object Array JSON Math Event
console require Promise Date Error Map Set RegExp Symbol Infinity NaN parseInt parseFloat isNaN setTimeout clearTimeout
setInterval clearInterval requestAnimationFrame process module exports globalThis'''.split())
# noms d'une lettre qui sont des noms du module (pas des variables locales)
SINGLE_GLOBALS = set('jpM')


class PatchError(Exception):
    pass


def tokens(text):
    """Découpe un passage : [(type, texte)] ; type = 'id' (nom remplaçable), 'lit' (le reste)."""
    out = []
    i = 0
    n = len(text)
    lit = []

    def flush():
        if lit:
            out.append(('lit', ''.join(lit)))
            lit.clear()

    while i < n:
        c = text[i]
        if c in '\'"':
            j = i + 1
            while j < n and text[j] != c:
                j += 2 if text[j] == '\\' else 1
            lit.append(text[i:j + 1])
            i = j + 1
            continue
        if c == '`':
            # gabarit : le texte reste tel quel, les expressions ${…} sont découpées aussi
            lit.append(c)
            j = i + 1
            while j < n and text[j] != '`':
                if text[j] == '\\':
                    lit.append(text[j:j + 2])
                    j += 2
                elif text.startswith('${', j):
                    depth = 1
                    k = j + 2
                    while k < n and depth:
                        depth += {'{': 1, '}': -1}.get(text[k], 0)
                        k += 1
                    lit.append('${')
                    flush()
                    out.extend(tokens(text[j + 2:k - 1]))
                    lit.append('}')
                    j = k
                else:
                    lit.append(text[j])
                    j += 1
            lit.append('`')
            i = j + 1
            continue
        if c == '/' and i + 1 < n and text[i + 1] == '^':
            # expression régulière /^…/
            j = i + 2
            while j < n and text[j] != '/':
                j += 2 if text[j] == '\\' else 1
            lit.append(text[i:j + 1])
            i = j + 1
            continue
        m = IDENT.match(text, i) if (c.isalpha() or c in '_$') else None
        if m and not (i > 0 and (text[i - 1].isdigit() or text[i - 1] in '_$' or text[i - 1].isalnum())):
            word = m.group(0)
            end = m.end()
            prev = text[i - 1] if i > 0 else ''
            nxt = text[end] if end < n else ''
            is_prop = prev == '.' and not (i > 1 and text[i - 2] == '.')
            is_key = nxt == ':' and prev in '{,' and not word.startswith('$')
            if is_prop or is_key or word in KEYWORDS or word.startswith('pj'):
                lit.append(word)
            else:
                flush()
                out.append(('id', word))
            i = end
            continue
        lit.append(c)
        i += 1
    flush()
    return out


def is_global(name):
    return len(name) > 1 or name in SINGLE_GLOBALS


class Patcher:
    def __init__(self, text, symbols=True):
        self.s = text
        self.sym = {}
        if symbols:
            self.load_symbols()

    # --- recherche ---------------------------------------------------------------------------------
    def _pattern(self, a, target=None):
        parts = []
        groups = {}
        order = []
        toks = tokens(a)
        for k, (kind, text) in enumerate(toks):
            if kind == 'lit':
                parts.append(re.escape(text))
                continue
            if text in self.sym and text != target:
                parts.append(re.escape(self.sym[text]))
                continue
            if text in groups:
                parts.append('(?P=%s)' % groups[text])
                continue
            g = 'g%d' % len(groups)
            groups[text] = g
            order.append(text)
            parts.append('(?P<%s>[A-Za-z_$][\\w$]*)' % g)
        pattern = ''.join(parts)
        if toks and toks[0][0] == 'id':
            pattern = r'(?<![\w$])' + pattern
        if toks and toks[-1][0] == 'id':
            pattern += r'(?![\w$])'
        return re.compile(pattern), groups

    def find(self, a, target=None):
        """Trouve le passage a (une seule fois) : (match, {ancien nom: nom installé})."""
        if target is None and self.s.count(a) == 1:
            # passage identique à la version de référence : les noms n'ont pas changé
            start = self.s.index(a)

            class Exact:
                def start(self):
                    return start

                def end(self):
                    return start + len(a)

            binding = {text: text for kind, text in tokens(a) if kind == 'id'}
            binding.update({k: v for k, v in self.sym.items() if k not in binding})
            return Exact(), binding
        rx, groups = self._pattern(a, target)
        matches = []
        for m in rx.finditer(self.s):
            matches.append(m)
            if len(matches) > 1:
                break
        if len(matches) != 1:
            raise PatchError('%s : %s' % ('passage introuvable' if not matches else 'passage en double', a[:90]))
        m = matches[0]
        binding = {old: m.group(g) for old, g in groups.items()}
        binding.update({k: v for k, v in self.sym.items() if k != target})
        return m, binding

    def remember(self, binding):
        for old, new in binding.items():
            if is_global(old) and old not in self.sym:
                self.sym[old] = new

    # --- remplacement ------------------------------------------------------------------------------
    def translate(self, b, binding, a=''):
        """Texte b avec les noms de la version installée."""
        out = []
        missing = set()
        local_new = {v for k, v in binding.items() if not is_global(k)}
        for kind, text in tokens(b):
            if kind == 'lit':
                out.append(text)
            elif text in binding:
                out.append(binding[text])
            elif is_global(text):
                missing.add(text)
                out.append(text)
            else:
                # variable locale du texte ajouté : ne doit pas prendre le nom d'une variable liée au passage
                if text in local_new and text not in binding:
                    raise PatchError('nom local %s en conflit dans : %s' % (text, b[:90]))
                out.append(text)
        if missing and not os.environ.get('PJ_PATCH_LOOSE'):
            raise PatchError('noms inconnus %s (ajouter des repères dans symboles.json) : %s' % (sorted(missing), b[:90]))
        return ''.join(out)

    def rep(self, a, b):
        log = os.environ.get('PJ_PATCH_LOG')
        if log:
            with open(log, 'a', encoding='utf-8') as f:
                f.write(json.dumps([a, b], ensure_ascii=False) + '\n')
        m, binding = self.find(a)
        new = self.translate(b, binding, a)
        self.s = self.s[:m.start()] + new + self.s[m.end():]
        self.remember(binding)

    def has(self, a):
        try:
            self.find(a)
            return True
        except PatchError:
            return False

    # --- repères des noms ---------------------------------------------------------------------------
    def bind(self, snippet, name):
        m, binding = self.find(snippet, target=name)
        new = binding[name]
        if name in self.sym and self.sym[name] != new:
            raise PatchError('%s : deux valeurs (%s, %s)' % (name, self.sym[name], new))
        self.sym[name] = new
        self.remember(binding)

    def load_symbols(self):
        path = os.path.join(HERE, 'symboles.json')
        if not os.path.exists(path):
            return
        with open(path, encoding='utf-8') as f:
            entries = json.load(f)
        for name, snippet in entries:
            if name in self.sym:
                continue
            try:
                self.bind(snippet, name)
            except PatchError:
                pass  # retrouvé plus tard par un correctif, sinon signalé par translate
