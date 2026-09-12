import 'dart:convert';
import 'dart:io';

/// Generates a versioned offline cache containing only public build artifacts.
Future<void> main() async {
  final root = Directory('apps/gomoku_app/build/web');
  final main = File('${root.path}/main.dart.js');
  if (!main.existsSync()) {
    throw StateError('Build Flutter web before preparing it.');
  }
  final version = (await main.lastModified()).toUtc().microsecondsSinceEpoch;
  final assets = <String>['/'];
  await for (final entry in root.list(recursive: true)) {
    if (entry is! File) continue;
    final relative = entry.path
        .substring(root.path.length)
        .replaceAll(r'\', '/');
    if (relative.endsWith('.map') ||
        relative.endsWith('offline_worker.js') ||
        relative.endsWith('flutter_service_worker.js')) {
      continue;
    }
    assets.add(relative);
  }
  assets.sort();
  await File('${root.path}/offline_worker.js').writeAsString('''
const CACHE = 'gomoku-assets-$version';
const ASSETS = ${jsonEncode(assets)};
self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(ASSETS)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys
    .filter(key => key.startsWith('gomoku-assets-') && key !== CACHE)
    .map(key => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin ||
      url.pathname.startsWith('/api/') || url.pathname.startsWith('/auth/') ||
      url.pathname === '/health' || url.pathname === '/app-config') return;
  if (request.mode === 'navigate') {
    event.respondWith(fetch(request).catch(() => caches.match('/index.html', {cacheName: CACHE})));
  } else {
    event.respondWith(caches.match(request, {cacheName: CACHE}).then(cached => cached || fetch(request)));
  }
});
''');
  stdout.writeln('Web offline cache prepared: ${assets.length} public assets.');
}
