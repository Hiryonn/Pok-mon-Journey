#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Traduction automatique des textes du projet (Data/Text/Dialogs/*.csv) : remplit les cases VIDES d'une langue à partir de la
colonne anglaise (en). Ce qui est déjà traduit n'est jamais touché.

Usage : python3 traduire_csv.py <dossier du projet> [options]
  --langues fr,de,es,it,ko,kana   langues à compléter (défaut : toutes les colonnes sauf en)
  --fichiers 100006,9000          ne traiter que ces CSV (numéros) ; --exclure 100000,100001 pour en sauter
  --moteur google|deepl|libre     google : sans clé (point d'accès public, défaut) ; deepl : --cle ; libre : --serveur URL [--cle]
  --identique                     considère aussi « identique à l'anglais » comme non traduit (à éviter pour les noms)
  --essai                         compte ce qui serait traduit, sans rien écrire ni appeler le moteur
  --max N                         s'arrête après N cases traduites (pour tester)
Les codes de texte de PSDK (\\c[1], \\n, [VAR 1], \\pn, {..}, <..>) sont protégés. Une traduction qui perd un code est refusée
(la case reste vide). Les CSV d'origine sont copiés dans sauvegardes/ avant la première modification. Un cache (cache_traduction.json, à côté du script) évite de retraduire et permet de reprendre.
"""
import argparse
import csv
import io
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
CACHE = HERE / 'cache_traduction.json'
CODES = {'kana': 'ja', 'zh': 'zh-CN'}
PROTECT = re.compile(r'(\\[A-Za-z]+(?:\[[^\]]*\])?|\\\\|\[[A-Z_]+(?: ?\d+)?\]|\{[^{}]*\}|<[^<>]*>|\\n|\\r)')


def protect(text):
    saved = []

    def sub(m):
        saved.append(m.group(0))
        return f'⟦{len(saved) - 1}⟧'
    return PROTECT.sub(sub, text), saved


def restore(text, saved):
    for i, code in enumerate(saved):
        text = re.sub(r'⟦\s*' + str(i) + r'\s*⟧', lambda _m, c=code: c, text)
    return text


def http_json(url, data=None, headers=None, retries=4):
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, data=data, headers=headers or {'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.loads(r.read().decode('utf-8'))
        except Exception as e:  # réseau, quota, limite de débit : on attend puis on réessaie
            if attempt == retries - 1:
                raise
            time.sleep(2 * (attempt + 1))
    return None


def make_engine(args):
    if args.moteur == 'test':
        return lambda text, lang: f'[{lang}] {text}'
    if args.moteur == 'deepl':
        if not args.cle:
            sys.exit('DeepL demande une clé : --cle VOTRE_CLE')
        host = 'api-free.deepl.com' if args.cle.endswith(':fx') else 'api.deepl.com'

        def deepl(text, lang):
            body = urllib.parse.urlencode({'text': text, 'source_lang': 'EN', 'target_lang': lang.upper().replace('ZH-CN', 'ZH')}).encode()
            r = http_json(f'https://{host}/v2/translate', body, {'Authorization': f'DeepL-Auth-Key {args.cle}'})
            return r['translations'][0]['text']
        return deepl
    if args.moteur == 'libre':
        if not args.serveur:
            sys.exit('LibreTranslate demande un serveur : --serveur http://localhost:5000')

        def libre(text, lang):
            body = json.dumps({'q': text, 'source': 'en', 'target': lang, 'format': 'text', 'api_key': args.cle or ''}).encode()
            return http_json(args.serveur.rstrip('/') + '/translate', body, {'Content-Type': 'application/json'})['translatedText']
        return libre

    def google(text, lang):
        url = 'https://translate.googleapis.com/translate_a/single?' + urllib.parse.urlencode(
            {'client': 'gtx', 'sl': 'en', 'tl': lang, 'dt': 't', 'q': text})
        data = http_json(url)
        return ''.join(part[0] for part in data[0] if part and part[0])
    return google


def translate_cell(engine, text, lang, cache):
    key = f'{lang}\u0001{text}'
    if key in cache:
        return cache[key]
    out_lines = []
    for line in text.split('\n'):                      # une ligne à la fois : les retours à la ligne sont gardés tels quels
        if not line.strip():
            out_lines.append(line)
            continue
        guarded, saved = protect(line)
        if not re.search(r'[A-Za-z]', PROTECT.sub('', line)):      # rien à traduire (nombres, codes seuls)
            out_lines.append(line)
            continue
        result = restore(engine(guarded, lang), saved)
        if any(code not in result for code in saved):
            raise ValueError(f'code perdu dans la traduction de « {line[:50]} »')
        out_lines.append(result)
    cache[key] = '\n'.join(out_lines)
    return cache[key]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('project')
    ap.add_argument('--langues')
    ap.add_argument('--fichiers')
    ap.add_argument('--exclure')
    ap.add_argument('--moteur', default='google', choices=['google', 'deepl', 'libre', 'test'])
    ap.add_argument('--cle')
    ap.add_argument('--serveur')
    ap.add_argument('--identique', action='store_true')
    ap.add_argument('--essai', action='store_true')
    ap.add_argument('--max', type=int, default=0)
    args = ap.parse_args()

    folder = Path(args.project) / 'Data/Text/Dialogs'
    only = {x.strip() for x in (args.fichiers or '').split(',') if x.strip()}
    skip = {x.strip() for x in (args.exclure or '').split(',') if x.strip()}
    langs = [x.strip() for x in args.langues.split(',')] if args.langues else None
    cache = json.loads(CACHE.read_text(encoding='utf-8')) if CACHE.exists() else {}
    engine = None if args.essai else make_engine(args)
    total = failed = files_changed = 0
    for path in sorted(folder.glob('*.csv'), key=lambda p: (len(p.stem), p.stem)):
        if (only and path.stem not in only) or path.stem in skip:
            continue
        raw = path.read_bytes()
        bom = raw.startswith(b'\xef\xbb\xbf')
        text = raw.decode('utf-8-sig')
        nl = '\r\n' if '\r\n' in text else '\n'
        rows = list(csv.reader(io.StringIO(text, newline='')))
        if not rows or 'en' not in rows[0]:
            continue
        head = rows[0]
        en = head.index('en')
        cols = [(i, h) for i, h in enumerate(head) if h != 'en' and (langs is None or h in langs)]
        todo = []
        for r, row in enumerate(rows[1:], 1):
            if len(row) <= en or not row[en].strip() or row[en].strip() == '-':
                continue
            for i, h in cols:
                value = row[i] if i < len(row) else ''
                if value.strip() == '' or (args.identique and value == row[en]):
                    todo.append((r, i, h))
        if not todo:
            continue
        print(f'{path.name} : {len(todo)} case(s) à traduire')
        if args.essai:
            total += len(todo)
            continue
        changed = 0
        for n, (r, i, h) in enumerate(todo, 1):
            if args.max and total >= args.max:
                break
            code = CODES.get(h, h)
            try:
                value = translate_cell(engine, rows[r][en], code, cache)
            except Exception as e:
                failed += 1
                print(f'  ! ligne {r + 1}, {h} : {e}')
                continue
            while len(rows[r]) <= i:
                rows[r].append('')
            rows[r][i] = value
            changed += 1
            total += 1
            if args.moteur == 'google':
                time.sleep(0.12)
            if changed % 100 == 0:
                CACHE.write_text(json.dumps(cache, ensure_ascii=False), encoding='utf-8')
                print(f'  … {changed}/{len(todo)}')
        if changed:
            out = io.StringIO(newline='')
            csv.writer(out, lineterminator=nl).writerows(rows)
            save = HERE / 'sauvegardes' / f'{path.stem}.csv'      # version d'avant, gardée une seule fois (hors du dossier de Studio)
            if not save.exists():
                save.parent.mkdir(exist_ok=True)
                save.write_bytes(raw)
            path.write_bytes((b'\xef\xbb\xbf' if bom else b'') + out.getvalue().encode('utf-8'))
            files_changed += 1
        CACHE.write_text(json.dumps(cache, ensure_ascii=False), encoding='utf-8')
        if args.max and total >= args.max:
            break
    verb = 'à traduire' if args.essai else 'traduites'
    print(f'\n{total} case(s) {verb}' + ('' if args.essai else f' dans {files_changed} fichier(s) ; {failed} refusée(s)'))


if __name__ == '__main__':
    main()
