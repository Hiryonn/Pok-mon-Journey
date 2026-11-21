# -*- coding: utf-8 -*-
"""Lit dans le PDF d'une fiche Pokéngine ce qui n'est PAS écrit en texte mais dessiné :
  - Catch rate : la barre verte (part remplie x 255 = taux de capture)
  - Gender     : la barre bleue (mâles, par-dessus) / rose (femelles) ; barre vide = asexué
  - Effort points : un petit carré de la couleur de la stat par point d'effort (rose = PV, rouge = Att, bleu = Def, violet = Att Spé,
                    cyan = Déf Spé, vert = Vit), couleurs repérées sur les six cases de stats de la même fiche.
Utilise pypdf (pip install pypdf). Les formes vectorielles du PDF sont relues avec leurs positions ; le texte sert de repère."""

STANDARD_CATCH = (3, 15, 25, 30, 45, 60, 75, 90, 120, 150, 180, 190, 200, 225, 255)
STAT_KEYS = ('evHp', 'evAtk', 'evDfe', 'evAts', 'evDfs', 'evSpd')
STANDARD_FEMALE = (0, 12.5, 25, 50, 75, 87.5, 100)
DEFAULT_PALETTE = [(255, 195, 205), (247, 133, 133), (159, 182, 224), (185, 158, 214), (137, 220, 220), (160, 230, 156)]


def _mul(a, b):
    return (a[0] * b[0] + a[1] * b[2], a[0] * b[1] + a[1] * b[3], a[2] * b[0] + a[3] * b[2], a[2] * b[1] + a[3] * b[3],
            a[4] * b[0] + a[5] * b[2] + b[4], a[4] * b[1] + a[5] * b[3] + b[5])


def _run(reader, content_stream_cls, obj, resources, ctm, out, depth=0):
    stack, color, pts = [], None, []
    for operands, op in content_stream_cls(obj, reader).operations:
        op = op.decode() if isinstance(op, bytes) else op
        if op == 'q':
            stack.append((ctm, color))
        elif op == 'Q':
            if stack:
                ctm, color = stack.pop()
        elif op == 'cm':
            ctm = _mul(tuple(float(x) for x in operands), ctm)
        elif op == 'rg':
            color = tuple(round(float(x) * 255) for x in operands)
        elif op == 'g':
            color = (round(float(operands[0]) * 255),) * 3
        elif op in ('scn', 'sc'):
            color = tuple(round(float(x) * 255) for x in operands) if len(operands) == 3 else None
        elif op in ('m', 'l'):
            pts.append(tuple(float(x) for x in operands))
        elif op == 'c':
            pts += [tuple(float(x) for x in operands[i:i + 2]) for i in (0, 2, 4)]
        elif op in ('v', 'y'):
            pts += [tuple(float(x) for x in operands[i:i + 2]) for i in (0, 2)]
        elif op == 're':
            x, y, w, h = (float(v) for v in operands)
            pts += [(x, y), (x + w, y + h)]
        elif op in ('f', 'F', 'f*', 'B', 'b'):
            if pts and color:
                xs = [x * ctm[0] + y * ctm[2] + ctm[4] for x, y in pts]
                ys = [x * ctm[1] + y * ctm[3] + ctm[5] for x, y in pts]
                out.append((min(xs), min(ys), max(xs), max(ys), color))
            pts = []
        elif op in ('n', 'S', 's'):
            pts = []
        elif op == 'Do' and depth < 6:
            xo = resources.get('/XObject', {}).get(operands[0])
            if xo is not None:
                xo = xo.get_object()
                if xo.get('/Subtype') == '/Form':
                    m = tuple(float(v) for v in xo.get('/Matrix', [1, 0, 0, 1, 0, 0]))
                    _run(reader, content_stream_cls, xo, xo.get('/Resources', resources), _mul(m, ctm), out, depth + 1)


def _is_colored(c):
    return max(c) - min(c) > 25


def _dist(a, b):
    return sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5


def interpret(fills, labels):
    """fills : [(x0, y0, x1, y1, (r, g, b))] avec y vers le BAS ; labels : {'catch': (x, y_base), 'gender': ..., 'effort': ...}
    Renvoie {'catch_rate', 'female_rate', 'effort'} (seulement ce qui a été trouvé)."""
    result = {}

    def row(label, top=-12, bottom=3):
        x, y = labels[label]
        return [f for f in fills if y + top <= (f[1] + f[3]) / 2 <= y + bottom and f[0] > x + 15]

    if 'catch' in labels:
        items = row('catch')
        colored = [f for f in items if _is_colored(f[4]) and f[3] - f[1] < 14 and f[2] - f[0] > 2]
        if colored:
            bar = min(colored, key=lambda f: f[0])
            tracks = [f for f in items if abs(f[0] - bar[0]) < 0.8 and (f[2] - f[0]) > (bar[2] - bar[0]) - 0.5 and not _is_colored(f[4])]
            width = max((f[2] - f[0] for f in tracks), default=None)
            if width:
                raw = max(1, min(255, round((bar[2] - bar[0]) / width * 255)))
                near = min(STANDARD_CATCH, key=lambda v: abs(v - raw))
                result['catch_rate'] = near if abs(near - raw) <= max(3, raw * 0.04) else raw
    if 'gender' in labels:
        items = row('gender')
        colored = [f for f in items if _is_colored(f[4]) and f[3] - f[1] < 14 and f[2] - f[0] > 1]
        if not colored:
            result['female_rate'] = -1                      # barre vide : asexué
        else:
            # le rose peut passer sous le bleu : la largeur du bleu donne les mâles, le reste est femelle
            widest = max(f[2] - f[0] for f in colored)
            blacks = [f[2] - f[0] for f in items if not _is_colored(f[4]) and widest - 0.5 <= f[2] - f[0] < 130]
            track = widest if len([f for f in colored if f[2] - f[0] >= widest - 0.5]) and any(
                f[4][0] > f[4][2] for f in colored) else min(blacks, default=widest)
            blue = max([f[2] - f[0] for f in colored if f[4][2] > f[4][0]], default=0)
            female = round(100 - blue / track * 100, 2)
            near = min(STANDARD_FEMALE, key=lambda v: abs(v - female))
            result['female_rate'] = near if abs(near - female) <= 1.5 else female
    if 'effort' in labels:
        palette = labels.get('palette') or DEFAULT_PALETTE
        squares = [f for f in row('effort', -14, 6) if _is_colored(f[4]) and f[2] - f[0] < 14 and f[3] - f[1] < 14]
        effort = {}
        for f in squares:
            i = min(range(6), key=lambda k: _dist(f[4], palette[k]))
            if _dist(f[4], palette[i]) < 40:
                effort[STAT_KEYS[i]] = effort.get(STAT_KEYS[i], 0) + 1
        result['effort'] = effort
    return result


def read_bars(path):
    """Lit le PDF ; renvoie un dict (vide si rien n'a pu être lu). Lève ImportError sans pypdf."""
    from pypdf import PdfReader
    from pypdf.generic import ContentStream
    reader = PdfReader(str(path))
    for page in reader.pages:
        labels = {}
        height = float(page.mediabox.height)

        def visit(text, cm, tm, font, size):
            t = text.strip()
            key = {'Catch rate': 'catch', 'Gender': 'gender', 'Effort points': 'effort'}.get(t)
            if key and key not in labels:
                labels[key] = (tm[4] * cm[0] + tm[5] * cm[2] + cm[4], height - (tm[4] * cm[1] + tm[5] * cm[3] + cm[5]))

        page.extract_text(visitor_text=visit)
        if not labels:
            continue
        # tout est ramené à un repère « y vers le bas » (comme dans un navigateur)
        raw = []
        _run(reader, ContentStream, page.get_contents(), page['/Resources'], (1, 0, 0, 1, 0, 0), raw)
        fills = [(x0, height - y1, x1, height - y0, c) for x0, y0, x1, y1, c in raw]
        boxes = [f for f in fills if 30 <= f[2] - f[0] <= 42 and 34 <= f[3] - f[1] <= 46 and _is_colored(f[4])]
        by_y = {}
        for f in boxes:
            by_y.setdefault(round(f[1]), []).append(f)
        for group in by_y.values():
            if len(group) == 6:
                labels['palette'] = [f[4] for f in sorted(group, key=lambda f: f[0])]
        return interpret(fills, labels)
    return {}
