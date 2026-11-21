# Pokémon Studio : icônes chromatiques dans graphics/pokedex/pokeiconshiny et icônes d'œuf dans graphics/pokedex/pokeiconegg
# (Studio les met toutes dans pokeicon). Studio affiche et range les nouvelles icônes dans ces dossiers ;
# le jeu les y trouve grâce à scripts/10000 Dossiers des icones.rb.
# Pour déplacer les icônes déjà dans pokeicon : ranger_icones.bat
# À relancer après une mise à jour de Studio (Studio doit être fermé).
# Usage : python patch_studio_icons.py   (cherche Studio dans %LOCALAPPDATA%\Programs\pokemon-studio)
#         python patch_studio_icons.py <fichier index-xxxx.js>
import glob, os, shutil, sys

if len(sys.argv) > 1:
    path = sys.argv[1]
else:
    base = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Programs/pokemon-studio/resources/app/.vite/renderer/main_window/assets')
    path = next(iter(sorted(glob.glob(os.path.join(base, 'index-*.js')))), None)
if not path or not os.path.exists(path):
    sys.exit('Fichier de Studio introuvable')
s = open(path, encoding='utf-8').read()
if 'pokedex/pokeiconshiny/' in s:
    sys.exit('Déjà fait : ' + path)
if not os.path.exists(path + '.bak-icones'):
    shutil.copy(path, path + '.bak-icones')
old = 'case`icon`:case`iconF`:case`iconShiny`:case`iconShinyF`:case`iconEgg`:return`graphics/pokedex/pokeicon/${n[t]??``}`;'
new = ('case`icon`:case`iconF`:return`graphics/pokedex/pokeicon/${n[t]??``}`;'
       'case`iconShiny`:case`iconShinyF`:return`graphics/pokedex/pokeiconshiny/${n[t]??``}`;'
       'case`iconEgg`:return`graphics/pokedex/pokeiconegg/${n[t]??``}`;')
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'studio-extra'))
from studio_patch import Patcher, PatchError  # noqa: E402
PATCHER = Patcher(s)
try:
    PATCHER.rep(old, new)
except PatchError as e:
    sys.exit('Version de Studio non reconnue (%s)' % e)
s = PATCHER.s
open(path, 'w', encoding='utf-8').write(s)
print('Icônes chromatiques / œufs : dossiers pokeiconshiny / pokeiconegg dans Studio (' + path + '). Redémarre Pokémon Studio.')
