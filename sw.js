// FlexiTap POS Support PWA - Service Worker
const CACHE_NAME = 'flexitap-support-v2';
const STATIC_ASSETS = [
  './flexi-app.html',
  './manifest.json',
  './image_02e503.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS);
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
      );
    })
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  // Only handle GET requests and local/same-origin or CDN resources
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);

  // For Supabase & Gemini API queries, bypass cache to ensure real-time data
  if (url.hostname.includes('supabase.co') || url.hostname.includes('googleapis.com')) {
    event.respondWith(fetch(event.request));
    return;
  }

  // Stale-while-revalidate for local app shell
  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      const fetchPromise = fetch(event.request).then((networkResponse) => {
        if (networkResponse && networkResponse.status === 200 && networkResponse.type === 'basic') {
          const responseToCache = networkResponse.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseToCache);
          });
        }
        return networkResponse;
      }).catch(() => cachedResponse);

      return cachedResponse || fetchPromise;
    })
  );
});
