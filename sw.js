/* Lintel People service worker.
   BUMP CACHE on every deploy that changes index.html — a stale cached shell
   is the classic single-file-PWA trap (same rule as Lintel OS). */
const CACHE = "lintel-people-v3";
const SHELL = ["./", "./index.html", "./manifest.json", "./icons/icon-192.png", "./icons/icon-512.png"];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (e) => {
  const url = new URL(e.request.url);
  // Only same-origin GETs: Supabase/API/font traffic passes straight through.
  if (e.request.method !== "GET" || url.origin !== location.origin) return;

  if (e.request.mode === "navigate" || url.pathname.endsWith("index.html")) {
    // Network-first for the app shell so deploys show up on next load;
    // cache fallback keeps the portal opening offline.
    e.respondWith(
      fetch(e.request)
        .then((res) => { const copy = res.clone(); caches.open(CACHE).then((c) => c.put("./index.html", copy)); return res; })
        .catch(() => caches.match("./index.html"))
    );
    return;
  }
  e.respondWith(
    caches.match(e.request).then((hit) =>
      hit || fetch(e.request).then((res) => { const copy = res.clone(); caches.open(CACHE).then((c) => c.put(e.request, copy)); return res; })
    )
  );
});
