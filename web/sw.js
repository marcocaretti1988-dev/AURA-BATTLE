/* Aura Battle - salva il gioco sul telefono dopo la prima apertura:
   personaggi, musica e librerie vengono presi dalla memoria (veloce e anche offline),
   la pagina del gioco viene controllata in rete per ricevere gli aggiornamenti. */
const CACHE = 'aura-battle-v1';
self.addEventListener('install', e => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));
self.addEventListener('fetch', e => {
  const req = e.request; if (req.method !== 'GET') return;
  const url = new URL(req.url);
  const isPage = req.mode === 'navigate' || url.pathname.endsWith('/') || url.pathname.endsWith('.html');
  if (isPage) {
    // rete prima (aggiornamenti), memoria se offline
    e.respondWith(fetch(req).then(r => { const c = r.clone(); caches.open(CACHE).then(k => k.put(req, c)); return r; }).catch(() => caches.match(req, { ignoreSearch: true })));
    return;
  }
  // modelli, musica, immagini, Three.js, font: memoria prima
  e.respondWith(caches.match(req).then(hit => hit || fetch(req).then(r => {
    if (r.ok || r.type === 'opaque') { const c = r.clone(); caches.open(CACHE).then(k => k.put(req, c)); }
    return r;
  })));
});
