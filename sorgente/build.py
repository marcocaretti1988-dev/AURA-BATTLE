import base64, json, sys
def b64(p, mime='image/png'): return f'data:{mime};base64,' + base64.b64encode(open(p,'rb').read()).decode()
BM = json.load(open('music/beatmaps.json'))
SONGS = {'menu': {'file': 'music/battle_milano.mp3'}}
import os
for v in ['milano','spagna','napoli','sanlorenzo','bologna','palermo']:
    if os.path.exists(f'music/song_{v}.mp3'): SONGS[v] = {'file': f'music/song_{v}.mp3'}
def build(out, embed_songs):
    A = {'logo': b64('out/logo.png')}
    import os as _os
    EX = json.load(open('chars_extra.json')) if _os.path.exists('chars_extra.json') else {}
    CH = ['jester', 'horse', 'monster'] + [k for k in EX if k not in ('jester', 'horse', 'monster')]
    MODELS = CH + ['crowdA', 'crowdB', 'crowdC']
    import os, base64 as B64
    os.makedirs('models', exist_ok=True)
    for n in MODELS: open(f'models/{n}.txt', 'w').write(B64.b64encode(open(f'm3d/{n}.glb', 'rb').read()).decode())
    A['models'] = {n: (b64(f'm3d/{n}.glb', 'model/gltf-binary') if embed_songs else f'models/{n}.txt') for n in MODELS}
    A['portraits'] = {n: b64(f'm3d/{n}_card.jpg', 'image/jpeg') for n in CH}
    CAL = {'milano': [852/1672, 590/941], 'spagna': [840/1672, 703/941], 'napoli': [842/1672, 630/941], 'sanlorenzo': [858/1672, 655/941], 'bologna': [.502, .670], 'palermo': [.502, .670]}
    SRC = {'milano': 'milano', 'spagna': 'spagna', 'napoli': 'napoli', 'sanlorenzo': 'colosseo', 'bologna': 'bologna', 'palermo': 'palermo'}
    A['venues'] = {v: {'img': b64(f'venues/{SRC[v]}_v3.jpg','image/jpeg'), 'thumb': b64(f'venues/{SRC[v]}_v3_t.jpg','image/jpeg'), 'hd': True, 'cal': CAL[v]} for v in SRC}
    A['songs'] = {k: (b64(v['file'].replace('.mp3','_96.mp3'), 'audio/mpeg') if embed_songs else v['file'].replace('.mp3','_96.mp3')) for k, v in SONGS.items()}  # versioni leggere (mono 96k) anche online
    meta = {k: {'beats': BM[k]['beats']} for k in SONGS}
    s = open('template.html').read().replace('/*ASSETS*/null', json.dumps(A)).replace('/*SONGS*/{}', json.dumps(meta)).replace('/*EXTRA_CHARS*/{}', json.dumps(EX, ensure_ascii=False))
    open(out,'w').write(s); print(out, round(len(s)/1e6,2), 'MB')
build('Aura_Battle.html', True)
build('Aura_Battle_web.html', False)
