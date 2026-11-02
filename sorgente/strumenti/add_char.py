"""Aggiunge un nuovo personaggio Meshy ad Aura Battle in un colpo solo.
uso: python3 add_char.py MODELLO.glb FOTO.jpg id "NOME" "#colore" "NOME MOSSA SPECIALE" ["descrizione"] ["stile"]
- riduce i triangoli (se servono) e le texture, toglie Running
- crea la foto della scheda (300x324) per selezione e schermata VS
- registra il personaggio in chars_extra.json (letto da build.py): entra subito in gioco,
  i balli vengono assegnati in automatico dai nomi delle animazioni (autoAnimSet)"""
import json, struct, subprocess, sys, os, shutil
from PIL import Image, ImageOps

a = sys.argv[1:]
src, photo, cid, name, color, special = a[:6]
desc = a[6] if len(a) > 6 else 'Nuovo sfidante della piazza.'
style = a[7] if len(a) > 7 else 'Balli e pose a sorpresa.'
os.chdir(os.path.dirname(os.path.abspath(__file__)))
shutil.copy(src, f'm3d/{cid}_src.glb')

def info(f):
    b = open(f, 'rb').read(); L = struct.unpack('<I', b[12:16])[0]; j = json.loads(b[20:20 + L])
    tris = sum(j['accessors'][p['indices']]['count'] // 3 for m in j['meshes'] for p in m['primitives'])
    return tris, [x['name'] for x in j.get('animations', [])]
tris, anims = info(f'm3d/{cid}_src.glb')
print('triangoli', tris, 'animazioni', anims)
mid = f'm3d/{cid}_src.glb'
if tris > 22000:
    subprocess.run(['python3', 'decimate.py', mid, f'm3d/{cid}_dec.glb', '20000'], check=True); mid = f'm3d/{cid}_dec.glb'
drop = [n for n in anims if n.lower() in ('running', 'run')]
cmd = ['python3', 'glbopt.py', mid, f'm3d/{cid}.glb', '--tex', '1024'] + (['--drop', ','.join(drop)] if drop else [])
subprocess.run(cmd, check=True)
print('finale', info(f'm3d/{cid}.glb'), os.path.getsize(f'm3d/{cid}.glb') // 1024, 'KB')

im = ImageOps.exif_transpose(Image.open(photo)).convert('RGB'); im.save(f'm3d/{cid}.jpg', quality=90)
ImageOps.fit(im, (300, 324), centering=(.5, .35)).save(f'm3d/{cid}_card.jpg', quality=86)

h = color.lstrip('#'); rgb = [int(h[i:i + 2], 16) for i in (0, 2, 4)]
glow = [min(255, int(c * .6 + 255 * .4)) for c in rgb]
reg = json.load(open('chars_extra.json')) if os.path.exists('chars_extra.json') else {}
reg[cid] = {'id': cid, 'name': name.upper(), 'color': color, 'glow': glow, 'desc': desc, 'style': style, 'special': special.upper(),
            'prefs': {'dance': 2.8, 'gesture': 2.2, 'walk': 1.1, 'mewing': 1.6, 'aura': 2.2, 'celebrate': .9}}
json.dump(reg, open('chars_extra.json', 'w'), indent=1, ensure_ascii=False)
print('registrato', cid, '-> ora: python3 build.py')
