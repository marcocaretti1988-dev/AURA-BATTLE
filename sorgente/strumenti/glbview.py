"""Render frontale texturizzato (posa di riposo) di un GLB, solo numpy: per controllare la mesh."""
import json, struct, sys, io
import numpy as np
from PIL import Image
def load(path):
    b = open(path, 'rb').read(); L = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + L]); BIN = b[20 + L + 8:]
    CT = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}; NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}
    def get(i):
        a = j['accessors'][i]; bv = j['bufferViews'][a['bufferView']]
        return np.frombuffer(BIN, dtype=CT[a['componentType']], count=a['count'] * NC[a['type']], offset=bv.get('byteOffset', 0) + a.get('byteOffset', 0)).reshape(a['count'], -1)
    p = j['meshes'][0]['primitives'][0]
    P = get(p['attributes']['POSITION']); UV = get(p['attributes']['TEXCOORD_0']); F = get(p['indices']).reshape(-1, 3)
    mat = j['materials'][0]; ti = mat['pbrMetallicRoughness']['baseColorTexture']['index']; im = j['images'][j['textures'][ti]['source']]
    bv = j['bufferViews'][im['bufferView']]; tex = np.array(Image.open(io.BytesIO(BIN[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']])).convert('RGB').resize((512, 512)))
    return P, UV, F, tex
def render(path, size=420, yaw=0.0):
    P, UV, F, tex = load(path)
    c, s = np.cos(yaw), np.sin(yaw); X = P[:, 0] * c + P[:, 2] * s; Z = -P[:, 0] * s + P[:, 2] * c
    sc = size / 1.85; px = X * sc + size / 2; py = size - 10 - P[:, 1] * sc
    img = np.zeros((size, size, 3), np.uint8) + 40; zb = np.full((size, size), -1e9)
    for t in F:
        xs, ys, zs = px[t], py[t], Z[t]
        x0, x1 = int(max(0, xs.min())), int(min(size - 1, xs.max() + 1)); y0, y1 = int(max(0, ys.min())), int(min(size - 1, ys.max() + 1))
        if x1 < x0 or y1 < y0: continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + .5, np.arange(y0, y1 + 1) + .5)
        d = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
        if abs(d) < 1e-9: continue
        w0 = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / d
        w1 = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / d; w2 = 1 - w0 - w1
        m = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
        if not m.any(): continue
        z = w0 * zs[0] + w1 * zs[1] + w2 * zs[2]
        yy, xx = gy[m].astype(int), gx[m].astype(int); zz = z[m]
        better = zz > zb[yy, xx]
        if not better.any(): continue
        yy, xx, zz = yy[better], xx[better], zz[better]
        uv = UV[t]; u = (w0[m][better] * uv[0, 0] + w1[m][better] * uv[1, 0] + w2[m][better] * uv[2, 0]); v = (w0[m][better] * uv[0, 1] + w1[m][better] * uv[1, 1] + w2[m][better] * uv[2, 1])
        img[yy, xx] = tex[np.clip((v * 511).astype(int), 0, 511), np.clip((u * 511).astype(int), 0, 511)]; zb[yy, xx] = zz
    return Image.fromarray(img)
if __name__ == '__main__':
    ims = [render(p, yaw=float(y)) for p in sys.argv[2:] for y in (0, 1.2)]
    out = Image.new('RGB', (420 * len(ims), 420))
    for i, im in enumerate(ims): out.paste(im, (420 * i, 0))
    out.save(sys.argv[1])
