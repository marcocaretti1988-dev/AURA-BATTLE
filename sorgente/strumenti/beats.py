"""Beat tracking (programmazione dinamica, stile Ellis 2007) -> mappa dei battiti per ogni canzone."""
import numpy as np, sys, json
sr = 22050; hop = 128; n = 1024; fps = sr / hop

def onset_env(path):
    x = np.fromfile(path, dtype=np.float32)
    fr = np.lib.stride_tricks.sliding_window_view(x, n)[::hop] * np.hanning(n)
    S = np.abs(np.fft.rfft(fr, axis=1))
    freqs = np.fft.rfftfreq(n, 1 / sr)
    S = np.log1p(S * 20)
    d = np.maximum(0, np.diff(S, axis=0))
    w = np.where(freqs < 200, 2.0, 1.0)  # più peso a cassa/basso
    f = (d * w).sum(1)
    f = f - np.convolve(f, np.ones(64) / 64, 'same'); f = np.maximum(f, 0)
    f = np.convolve(f, np.hanning(5) / np.hanning(5).sum(), 'same')
    return f / (f.std() + 1e-9), len(x) / sr

def tempo(f, lo=80, hi=170):
    ac = np.correlate(f, f, 'full')[len(f) - 1:]
    best = None
    for bpm in np.arange(lo, hi, .02):
        lag = 60 / bpm * fps; s = 0
        for k in (1, 2, 4):
            l = lag * k; i = int(l); r = l - i
            s += (ac[i] * (1 - r) + ac[i + 1] * r) / k ** .3
        # preferenza morbida intorno a 120
        s *= np.exp(-.5 * (np.log2(bpm / 120) / 1.0) ** 2)
        if best is None or s > best[0]: best = (s, bpm)
    return best[1]

def track(f, bpm, tight=100.):
    p = 60 / bpm * fps
    N = len(f); score = f.copy(); back = -np.ones(N, int)
    lo, hi = int(p / 2), int(p * 2)
    offs = np.arange(-hi, -lo + 1)
    pen = -tight * np.log(-offs / p) ** 2
    for t in range(hi, N):
        cand = score[t + offs] + pen
        k = np.argmax(cand); score[t] = f[t] + cand[k]; back[t] = t + offs[k]
    t = int(np.argmax(score[-int(p * 2):])) + N - int(p * 2)
    beats = [t]
    while back[t] >= 0: t = back[t]; beats.append(t)
    return (np.array(beats[::-1]) + n / 2 / hop) / fps

out = {}
for arg in sys.argv[1:]:
    name, path = arg.split('=')
    f, dur = onset_env(path)
    bpm = tempo(f)
    b = track(f, bpm)
    iv = np.diff(b)
    # downbeat: la fase (mod 4) con più energia sulle basse
    x = np.fromfile(path, dtype=np.float32)
    lowE = []
    for t in b:
        i = int(t * sr); seg = x[max(0, i - 400):i + 800]
        sp = np.abs(np.fft.rfft(seg * np.hanning(len(seg)))); fq = np.fft.rfftfreq(len(seg), 1 / sr)
        lowE.append(sp[(fq > 35) & (fq < 130)].sum())
    lowE = np.array(lowE); ph = [lowE[k::4][8:].mean() for k in range(4)]
    db = int(np.argmax(ph))
    print(name, 'bpm %.2f  beats %d  intervallo medio %.4f  dev %.4f  min %.3f max %.3f  downbeat %d %s' % (bpm, len(b), iv.mean(), iv.std(), iv.min(), iv.max(), db, np.round(ph / max(ph), 2)))
    # tempo locale per finestre di 16 battiti
    loc = [60 / np.median(iv[i:i + 16]) for i in range(0, len(iv) - 16, 16)]
    print('   bpm locali', [round(v, 1) for v in loc])
    out[name] = {'beats': [round(float(t), 4) for t in b[db:]], 'bpm': round(float(60 / np.median(iv)), 2), 'dur': round(dur, 3)}
json.dump(out, open('music/beatmaps.json', 'w'))
