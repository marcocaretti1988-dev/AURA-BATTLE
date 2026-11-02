"""Ottimizza un GLB di Meshy per il web:
- texture PNG 4096 -> JPEG 1024 (colore, normal map, metallic/roughness)
- rimuove le tracce di traslazione costanti delle ossa (resta solo quella dei fianchi)
- rimuove le animazioni indicate
- ricostruisce buffer e indici senza dati inutilizzati
uso: python3 glbopt.py in.glb out.glb [--tex 1024] [--drop Running,Walking]"""
import json, struct, sys, io
import numpy as np
from PIL import Image

args = sys.argv[1:]
src, dst = args[0], args[1]
tex = int(args[args.index('--tex') + 1]) if '--tex' in args else 1024
keep = set(args[args.index('--keep') + 1].split(',')) if '--keep' in args else None
drop = set(args[args.index('--drop') + 1].split(',')) if '--drop' in args else set()

b = open(src, 'rb').read()
L = struct.unpack('<I', b[12:16])[0]
j = json.loads(b[20:20 + L])
binstart = 20 + L + 8
BIN = b[binstart:]
CT = {5126: ('f', 4), 5123: ('H', 2), 5125: ('I', 4), 5121: ('B', 1), 5122: ('h', 2), 5120: ('b', 1)}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}

def acc_data(i):
    a = j['accessors'][i]; bv = j['bufferViews'][a['bufferView']]
    fmt, sz = CT[a['componentType']]; n = NC[a['type']]
    off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    arr = np.frombuffer(BIN, dtype=np.dtype(fmt).newbyteorder('<'), count=a['count'] * n, offset=off)
    return arr.reshape(a['count'], n)

# --- animazioni
anims = []
for an in j.get('animations', []):
    if an.get('name') in drop or (keep is not None and an.get('name') not in keep): continue
    ch2, sm2 = [], []
    for c in an['channels']:
        node = j['nodes'][c['target']['node']]['name']
        s = an['samplers'][c['sampler']]
        if c['target']['path'] == 'translation' and 'Hips' not in node:
            d = acc_data(s['output'])
            if np.ptp(d, axis=0).max() < 1e-4:
                continue
        sm2.append(s); ch2.append({'sampler': len(sm2) - 1, 'target': c['target']})
    an = dict(an); an['channels'] = ch2; an['samplers'] = sm2
    anims.append(an)
j['animations'] = anims

# --- immagini
newimg = {}
for ii, im in enumerate(j['images']):
    bv = j['bufferViews'][im['bufferView']]
    raw = BIN[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]
    pil = Image.open(io.BytesIO(raw)).convert('RGB')
    if pil.width > tex: pil = pil.resize((tex, tex), Image.LANCZOS)
    out = io.BytesIO(); q = 82 if 'normal' not in (im.get('name') or '') else 90
    pil.save(out, 'JPEG', quality=q, optimize=True)
    newimg[ii] = out.getvalue()

# --- accessori usati
used_acc = set()
for m in j['meshes']:
    for p in m['primitives']:
        used_acc.update(p['attributes'].values())
        if 'indices' in p: used_acc.add(p['indices'])
        for t in p.get('targets', []): used_acc.update(t.values())
for s in j.get('skins', []):
    if 'inverseBindMatrices' in s: used_acc.add(s['inverseBindMatrices'])
for an in anims:
    for s in an['samplers']: used_acc.update([s['input'], s['output']])
acc_map = {}; new_acc = []
for i in sorted(used_acc):
    acc_map[i] = len(new_acc); new_acc.append(dict(j['accessors'][i]))

# --- ricostruzione buffer
out = bytearray(); new_bv = []; bv_map = {}
def add_view(data, extra):
    global out
    while len(out) % 4: out += b'\0'
    v = dict(extra); v['buffer'] = 0; v['byteOffset'] = len(out); v['byteLength'] = len(data)
    out += data; new_bv.append(v); return len(new_bv) - 1
for a in new_acc:
    old = a['bufferView']
    if old not in bv_map:
        bv = j['bufferViews'][old]
        data = BIN[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]
        extra = {k: v for k, v in bv.items() if k in ('byteStride', 'target')}
        bv_map[old] = add_view(data, extra)
    a['bufferView'] = bv_map[old]
for ii, im in enumerate(j['images']):
    im['bufferView'] = add_view(newimg[ii], {}); im['mimeType'] = 'image/jpeg'
while len(out) % 4: out += b'\0'
j['accessors'] = new_acc; j['bufferViews'] = new_bv; j['buffers'] = [{'byteLength': len(out)}]
for m in j['meshes']:
    for p in m['primitives']:
        p['attributes'] = {k: acc_map[v] for k, v in p['attributes'].items()}
        if 'indices' in p: p['indices'] = acc_map[p['indices']]
        if 'targets' in p: p['targets'] = [{k: acc_map[v] for k, v in t.items()} for t in p['targets']]
for s in j.get('skins', []):
    if 'inverseBindMatrices' in s: s['inverseBindMatrices'] = acc_map[s['inverseBindMatrices']]
for an in anims:
    for s in an['samplers']: s['input'] = acc_map[s['input']]; s['output'] = acc_map[s['output']]
js = json.dumps(j, separators=(',', ':')).encode()
while len(js) % 4: js += b' '
glb = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(out))
glb += struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(out), 0x004E4942) + bytes(out)
open(dst, 'wb').write(glb)
print(dst, round(len(glb) / 1e6, 2), 'MB', 'anims', [a['name'] for a in anims], 'img', [len(v) // 1024 for v in newimg.values()], 'KB')
