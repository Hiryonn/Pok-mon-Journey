# Outil (développement) : refait symboles.json à partir d'une version de référence de Studio
#   python trouver_symboles.py <index-xxxx.js de référence, sans correctif> <index-yyyy.js d'une autre version> <log.jsonl>
# log.jsonl : passages des correctifs, notés en lançant les correctifs sur la référence avec PJ_PATCH_LOG=log.jsonl
# Pour chaque nom du module utilisé par les correctifs, cherche autour de ses apparitions un passage unique dans les deux
# versions (noms remplacés par des jokers) qui le retrouve.
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio_patch import Patcher, PatchError, tokens, is_global  # noqa: E402

ref = open(sys.argv[1], encoding='utf-8').read()
other = open(sys.argv[2], encoding='utf-8').read()
names = []
near = {}
for line in open(sys.argv[3], encoding='utf-8'):
    a, b = json.loads(line)
    pos = ref.find(a)
    for kind, text in tokens(a) + tokens(b):
        if kind == 'id' and is_global(text):
            if text not in names:
                names.append(text)
            if pos >= 0:
                near.setdefault(text, []).append(pos)
print(len(names), 'noms :', ' '.join(names))

SAFE_START = ',;{(['
SAFE_END = ',;})]'


def balanced(t):
    return t.count('`') % 2 == 0 and "'" not in t and '"' not in t and '/' not in t.replace('/>', '')


def candidates(name):
    rx = re.compile(r'(?<![\w$.])' + re.escape(name) + r'(?![\w$])')
    spots = near.get(name, [])
    occ = list(rx.finditer(ref))
    if spots:
        # d'abord les apparitions proches des passages des correctifs (même partie du code de Studio)
        occ.sort(key=lambda m: min(abs(m.start() - p) for p in spots))
    for m in occ[:400]:
        for size in (40, 70, 110, 160, 240):
            st = max(0, m.start() - size)
            en = min(len(ref), m.end() + size)
            # coupe sur des séparateurs sûrs
            while st < m.start() and ref[st] not in SAFE_START:
                st += 1
            while en > m.end() and ref[en - 1] not in SAFE_END:
                en -= 1
            snippet = ref[st + 1:en]
            if len(snippet) < 15 or name not in snippet or not balanced(snippet):
                continue
            yield snippet


APP = ('(0,j.', '(0,p.')


def ordered(name):
    # d'abord les passages du code de Studio lui-même (composants React : « (0,j.jsx) »…), pas des bibliothèques
    first, rest = [], []
    for snippet in candidates(name):
        (first if any(a in snippet for a in APP) else rest).append(snippet)
        if len(first) > 60:
            break
    return first + rest


found = []
missing = []
for name in names:
    ok = None
    for snippet in ordered(name):
        if not any(k == 'id' and t == name for k, t in tokens(snippet)):
            continue
        try:
            p1 = Patcher(ref, symbols=False)
            p1.bind(snippet, name)
            if p1.sym[name] != name:
                continue
            p2 = Patcher(other, symbols=False)
            p2.bind(snippet, name)
        except PatchError:
            continue
        except re.error:
            continue
        ok = (snippet, p2.sym[name])
        break
    if ok:
        found.append([name, ok[0]])
        print('%-6s -> %-6s  %s' % (name, ok[1], ok[0][:70]))
    else:
        missing.append(name)
# repères écrits à la main (noms que la recherche automatique ne retrouve pas)
MANUAL = [
    ['HOa', 'R$=e=>{let{path:t,label:n,activeForced:r}=e;return(0,j.jsx)(HOa,{to:t,"data-active-forced":r,children:(0,j.jsx)(VOa,{children:n})})}'],
    ['VOa', 'R$=e=>{let{path:t,label:n,activeForced:r}=e;return(0,j.jsx)(HOa,{to:t,"data-active-forced":r,children:(0,j.jsx)(VOa,{children:n})})}'],
    ['Y0a', 'X0a=()=>(0,j.jsxs)(Y0a,{children:[(0,j.jsx)(UOa,{}),(0,j.jsxs)(Ma,{children:[(0,j.jsx)(Aa,{path:`moves/pokemon`,element:(0,j.jsx)(nRa,{})})'],
    ['Pco', '(0,j.jsx)(Aa,{path:`overview`,element:(0,j.jsx)(Pco,{})})'],
]
for name, snippet in MANUAL:
    if name in missing:
        try:
            p2 = Patcher(other, symbols=False)
            p2.bind(snippet, name)
            found.append([name, snippet])
            missing.remove(name)
            print('%-6s -> %-6s  (à la main)' % (name, p2.sym[name]))
        except PatchError as e:
            print('à la main, introuvable :', name, e)
print('introuvables :', missing)
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'symboles.json')
with open(out, 'w', encoding='utf-8') as f:
    json.dump(found, f, ensure_ascii=False, indent=0)
