"""Affiche le code Pokéngine (entre parenthèses dans le titre) d'une fiche PDF/txt. Utilisé par le bouton de Studio Extra."""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import importer_pokengine as imp  # noqa: E402

text = imp.read_sheet(sys.argv[1])
m = re.search(r'#\s*(\d+)\s+(.+?)\s+\(([a-z0-9]{6,12})\)', text)
if not m:
    sys.exit("titre introuvable dans la fiche (attendu : « #1 Nom (code) »)")
print(m.group(3))
