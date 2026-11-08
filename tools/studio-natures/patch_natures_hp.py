# Ajoute les PV aux natures dans Pokémon Studio (base de données > Natures : affichage, éditeur, nouvelle nature)
# À relancer après une mise à jour de Studio (Studio doit être fermé).
# Usage : python patch_natures_hp.py   (cherche Studio dans %LOCALAPPDATA%\Programs\pokemon-studio)
#         python patch_natures_hp.py <fichier index-xxxx.js>
import glob, os, re, shutil, sys

if len(sys.argv) > 1:
    path = sys.argv[1]
else:
    base = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Programs/pokemon-studio/resources/app/.vite/renderer/main_window/assets')
    path = next(iter(sorted(glob.glob(os.path.join(base, 'index-*.js')))), None)
if not path or not os.path.exists(path):
    sys.exit('Fichier de Studio introuvable')
s = open(path, encoding='utf-8').read()
if 'qf=[`hp`,' in s:
    sys.exit('Déjà fait : ' + path)
if not os.path.exists(path + '.bak-natures'):
    shutil.copy(path, path + '.bak-natures')

def rep(a, b):
    global s
    if s.count(a) != 1:
        sys.exit('Version de Studio non reconnue (%s)' % a[:40])
    s = s.replace(a, b)

rep("Kf=R({atk:ol.max(999),dfe:ol.max(999),ats:ol.max(999),dfs:ol.max(999),spd:ol.max(999)})",
    "Kf=R({hp:ol.max(999).default(100),atk:ol.max(999),dfe:ol.max(999),ats:ol.max(999),dfs:ol.max(999),spd:ol.max(999)})")
rep("qf=[`atk`,`dfe`,`ats`,`dfs`,`spd`]", "qf=[`hp`,`atk`,`dfe`,`ats`,`dfs`,`spd`]")
rep("D0a=e=>{let t=e-100;", "D0a=e=>{let t=(e??100)-100;")
rep("W0a=e=>{let t=V(e);return qf.forEach(e=>t.stats[e]-=100),t}", "W0a=e=>{let t=V(e);return qf.forEach(e=>t.stats[e]=(t.stats[e]??100)-100),t}")
rep("U0a=Xf.extend({stats:R({atk:Dc().min(-99).max(899),", "U0a=Xf.extend({stats:R({hp:Dc().min(-99).max(899),atk:Dc().min(-99).max(899),")
rep("stats:{atk:100,dfe:100,ats:100,dfs:100,spd:100},flavors:{liked:`none`,disliked:`none`}",
    "stats:{hp:100,atk:100,dfe:100,ats:100,dfs:100,spd:100},flavors:{liked:`none`,disliked:`none`}")

def strval(v):
    m = re.search(r'[,; ]' + re.escape(v) + r'=`([^`]*)`', s)
    return m.group(1) if m else ''

def obj_sub(m):
    fr = strval(m.group(2)) == 'Vitesse'
    return (m.group(1).replace('changing_stats', 'hp:`%s`,changing_stats' % ('PV' if fr else 'HP'), 1) + m.group(2) +
            ',changing_stat_hp:`%s`,flavors' % ('Points de vie' if fr else 'HP'))

s = re.sub(r'(atk:`[^`]*`,dfe:`[^`]*`,ats:`[^`]*`,dfs:`[^`]*`,spd:`[^`]*`,changing_stats:[\w$]+,changing_stat_atk:[\w$]+,changing_stat_dfe:[\w$]+,changing_stat_ats:[\w$]+,changing_stat_dfs:[\w$]+,changing_stat_spd:)([\w$]+),flavors', obj_sub, s)

def get_sub(m):
    spd = re.search(r'changing_stat_spd:\(\)=>([\w$]+)', m.group(0)).group(1)
    return m.group(0) + 'changing_stat_hp:()=>`%s`,' % ('Points de vie' if strval(spd) == 'Vitesse' else 'HP')

s = re.sub(r'changing_stat_atk:\(\)=>[\w$]+,changing_stat_ats:\(\)=>[\w$]+,changing_stat_dfe:\(\)=>[\w$]+,changing_stat_dfs:\(\)=>[\w$]+,changing_stat_spd:\(\)=>[\w$]+,', get_sub, s)
open(path, 'w', encoding='utf-8').write(s)
print('Natures : PV ajoutés dans Studio (' + path + '). Redémarre Pokémon Studio.')
