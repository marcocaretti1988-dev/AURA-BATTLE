"""Semplifica la mesh di un GLB Meshy (skinned) con clustering dei vertici.
Raggruppa vertici vicini sia nello spazio che nelle UV (così le cuciture delle texture restano intatte);
per ogni gruppo tiene il vertice più vicino al centro, con le sue UV, normali e pesi delle ossa originali.
uso: python3 decimate.py in.glb out.glb TRIANGOLI_TARGET"""
import json, struct, sys
import numpy as np

src, dst, target = sys.argv[1], sys.argv[2], int(sys.argv[3])
b = open(src, 'rb').read()
L = struct.unpack('<I', b[12:16])[0]
j = json.loads(b[20:20 + L]); BIN = bytearray(b[20 + L + 8:])
CT = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}
def get(i):
    a = j['accessors'][i]; bv = j['bufferViews'][a['bufferView']]
    dt = CT[a['componentType']]; n = NC[a['type']]
    off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    return np.frombuffer(bytes(BIN), dtype=dt, count=a['count'] * n, offset=off).reshape(a['count'], n).copy()

prim = j['meshes'][0]['primitives'][0]
attrs = {k: get(v) for k, v in prim['attributes'].items()}
F = get(prim['indices']).reshape(-1, 3)
P = attrs['POSITION']; UV = attrs['TEXCOORD_0']
print('originale', len(P), 'vertici', len(F), 'triangoli')

def cluster(cell):
    q = np.floor(P / cell).astype(np.int64)
    _, inv = np.unique(q, axis=0, return_inverse=True); inv = inv.ravel()
    nf = inv[F]
    ok = (nf[:, 0] != nf[:, 1]) & (nf[:, 1] != nf[:, 2]) & (nf[:, 0] != nf[:, 2])
    s_ = np.sort(nf[ok], 1); _, keep = np.unique(s_, axis=0, return_index=True)
    idx = np.where(ok)[0][np.sort(keep)]
    return inv, idx

lo, hi = 1e-4, .2
for it in range(30):
    mid = (lo * hi) ** .5
    inv, idx = cluster(mid)
    if len(idx) > target: lo = mid
    else: hi = mid
inv, idx = cluster(hi)
nc = inv.max() + 1
cnt = np.bincount(inv, minlength=nc).astype(np.float64)
cen = np.stack([np.bincount(inv, P[:, k], nc) / cnt for k in range(3)], 1)
d = ((P - cen[inv]) ** 2).sum(1)
order = np.lexsort((d, inv)); first = np.ones(len(order), bool); first[1:] = inv[order][1:] != inv[order][:-1]
rep = np.empty(nc, np.int64); rep[inv[order][first]] = order[first]
Ncl = np.stack([np.bincount(inv, attrs['NORMAL'][:, k], nc) for k in range(3)], 1)
Ncl /= np.linalg.norm(Ncl, axis=1, keepdims=True) + 1e-9
# angoli dei triangoli rimasti: posizione/pesi del gruppo, UV del vertice originale
corners = F[idx].reshape(-1)                 # vertici originali
ccl = inv[corners]                           # gruppo
uvq = np.round(UV[corners] * 4096).astype(np.int64)
key = np.stack([ccl, uvq[:, 0], uvq[:, 1]], 1)
_, first_i, cinv = np.unique(key, axis=0, return_index=True, return_inverse=True)
cinv = cinv.ravel()
src_v = corners[first_i]; src_c = ccl[first_i]
newA = {}
for k, v in attrs.items():
    if k == 'TEXCOORD_0': newA[k] = UV[src_v]
    elif k == 'POSITION': newA[k] = P[rep[src_c]]
    elif k == 'NORMAL': newA[k] = Ncl[src_c].astype(np.float32)
    else: newA[k] = v[rep[src_c]]   # JOINTS/WEIGHTS uguali per tutto il gruppo: niente crepe in animazione
newF = cinv.astype(np.uint32).reshape(-1, 3)
print('semplificata', len(src_v), 'vertici', len(newF), 'triangoli (cella %.4f)' % hi)

# scrive i nuovi dati in coda al buffer e aggiorna gli accessori
def put(acc_i, arr):
    global BIN
    while len(BIN) % 4: BIN += b'\0'
    off = len(BIN); data = np.ascontiguousarray(arr).tobytes(); BIN += data
    j['bufferViews'].append({'buffer': 0, 'byteOffset': off, 'byteLength': len(data)})
    a = j['accessors'][acc_i]; a['bufferView'] = len(j['bufferViews']) - 1; a['byteOffset'] = 0; a['count'] = int(len(arr))
    if arr.dtype == np.uint32: a['componentType'] = 5125
    if 'min' in a and arr.ndim == 2 and a['componentType'] == 5126: a['min'] = arr.min(0).tolist(); a['max'] = arr.max(0).tolist()
    elif 'min' in a: a.pop('min'); a.pop('max', None)
for k, v in prim['attributes'].items(): put(v, newA[k])
put(prim['indices'], newF.reshape(-1))
while len(BIN) % 4: BIN += b'\0'
j['buffers'] = [{'byteLength': len(BIN)}]
js = json.dumps(j, separators=(',', ':')).encode()
while len(js) % 4: js += b' '
out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(BIN)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(BIN), 0x004E4942) + bytes(BIN)
open(dst, 'wb').write(out)
