# Refait graphics/interface/types*.png (32 x 14 par type) depuis les types de Studio : couleur (Data/Studio/types) et nom (Data/Text/Dialogs/100003.csv)
# Usage : python tools/types/build_types.py  (depuis n'importe où ; P = racine du projet ci-dessous)
import json, csv, glob, os, unicodedata
from PIL import Image
P=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..')+os.sep
G=json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'glyphs.json')))
glyph={k:v[0] for k,v in G.items()}
# glyphes ajoutés à la main (7 px de haut)
def g(rows): return [[1 if c=='#' else 0 for c in r] for r in rows]
glyph['?']=g(['.##.','#..#','...#','..#.','.#..','....','.#..'])
glyph['Q']=g(['.##.','#..#','#..#','#..#','#.##','#..#','.###'])
glyph['J']=g(['..##','...#','...#','...#','...#','#..#','.##.'])
glyph['X']=g(['#..#','#..#','.##.','.##.','.##.','#..#','#..#'])
glyph['Z']=g(['####','...#','..#.','.##.','.#..','#...','####'])
glyph['K']=glyph.get('K')
types={}
for f in glob.glob(P+'Data/Studio/types/*.json'):
  d=json.load(open(f)); types[d['id']]=d
rows=list(csv.reader(open(P+'Data/Text/Dialogs/100003.csv',encoding='utf-8-sig')))
head=rows[0]
# abréviations quand le nom ne tient pas (6 lettres en général, comme les images d'origine)
ABBR={'fr':{'ÉLECTRIK':'ELECTR','TÉNÈBRES':'TENEBR','INSECTE':'INSECT','SPECTRE':'SPECTR','LUMIÈRE':'LUMIER','NUCLÉAIRE':'NUCLEA','BESTIAL':'BESTIA'},
      'en':{'ELECTRIC':'ELECTR','PSYCHIC':'PSYCHC','FIGHTING':'FIGHT'},
      'es':{'ELÉCTRICO':'ELECTR','PSÍQUICO':'PSIQUI','FANTASMA':'FANTAS','SINIESTRO':'SINIES','VOLADOR':'VOLADR'}}
def plain(s): return ''.join(c for c in unicodedata.normalize('NFD',s) if unicodedata.category(c)!='Mn')
def width(t): return sum(len(glyph[c][0]) for c in t)+len(t)-1
def hexc(h): h=h.lstrip('#'); return tuple(int(h[i:i+2],16) for i in (0,2,4))
def mix(c,t,f): return tuple(round(a+(b-a)*f) for a,b in zip(c,t))
def lum(c): return 0.299*c[0]+0.587*c[1]+0.114*c[2]
def badge(text, color, W=32, H=14):
  im=Image.new('RGBA',(W,H),(0,0,0,0)); px=im.load()
  base=hexc(color)
  top=mix(base,(255,255,255),0.45); bot=mix(base,(0,0,0),0.35)
  for x in range(W):
    for y in range(H):
      if (x in (0,W-1)) and (y in (0,H-1)): continue
      px[x,y]=(top if y==0 else bot if y==H-1 else base)+(255,)
  # texte blanc + ombre (fond clair : ombre plus foncée)
  shadow=mix(base,(0,0,0),0.55 if lum(base)>150 else 0.45)
  ink=(248,248,248)
  if lum(base)>220:   # fond très clair (Lumière) : texte foncé
    ink=mix(base,(0,0,0),0.7); shadow=mix(base,(0,0,0),0.25)
  w=width(text); x0=(W-(w+1))//2; y0=(H-7)//2
  x=x0
  for c in text:
    gl=glyph[c]
    for yy,row in enumerate(gl):
      for xx,v in enumerate(row):
        if v:
          for dx,dy in ((1,0),(0,1),(1,1)):
            X,Y=x+xx+dx,y0+yy+dy
            if 0<X<W-1 and 0<Y<H-1 and px[X,Y][:3]!=ink: px[X,Y]=shadow+(255,)
    for yy,row in enumerate(gl):
      for xx,v in enumerate(row):
        if v: px[x+xx,y0+yy]=ink+(255,)
    x+=len(gl[0])+1
  return im
def name_for(lang, tid, W=32):
  t=types[tid]; col=head.index(lang)
  full=rows[t['textId']+1][col].upper()
  n=plain(full)
  if width(n)>W-3: n=plain(ABBR.get(lang,{}).get(full,full))   # abrégé seulement si le nom ne tient pas
  while width(n)>W-3: n=n[:-1]
  return n
# PSDK découpe l'image en (plus grand id + 1) lignes : ligne = id du type, ligne 0 vide (pas de 2e type)
ROWS=max(types)+1
out={}
for lang,files in (('fr',['types_fr.png']),('en',['types_en.png','types.png']),('es',['types_es.png'])):
  sheet=Image.new('RGBA',(32,14*ROWS),(0,0,0,0))
  names=[]
  for tid in range(1,ROWS):   # ligne = id du type ; la ligne 0 reste vide (pas de 2e type)
    if tid not in types: continue
    n=name_for(lang,tid); names.append(n)
    sheet.paste(badge(n,types[tid]['color']),(0,tid*14))
  for f in files: sheet.save(P+'graphics/interface/'+f)
  print(lang,names)

def sheet_for(lang, W, H):
  sheet=Image.new('RGBA',(W,H*ROWS),(0,0,0,0)); names=[]
  for tid in range(1,ROWS):
    if tid not in types: continue
    n=name_for(lang,tid,W); names.append(n)
    sheet.paste(badge(n,types[tid]['color'],W,H),(0,tid*H))
  return sheet, names

# Pokédex : 48 x 16 par type (noms complets quand ils tiennent)
for lang,files in (('fr',['types_fr.png']),('en',['types_en.png','types.png']),('es',['types_es.png'])):
  sheet,names=sheet_for(lang,48,16)
  for f in files: sheet.save(P+'graphics/pokedex/'+f)
  print('pokedex',lang,names)

# Enhanced Battle UI : petites étiquettes 32 x 11 (panneau d'attaque, infos des combattants)
if os.path.isdir(P+'graphics/interface/enhanced_battle_ui'):
  for lang in ('fr','en','es'):
    sheet,names=sheet_for(lang,32,11)
    sheet.save(P+f'graphics/interface/enhanced_battle_ui/types_{lang}.png')
  print('enhanced_battle_ui : types_fr / types_en / types_es')
