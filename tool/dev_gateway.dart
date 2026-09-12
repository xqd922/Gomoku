import 'dart:async';
import 'dart:io';

/// Same-origin development gateway. Run after flutter build web.
/// Keeps HttpOnly cookies on both RPC and Streaming Methods requests.
Future<void> main(List<String> args) async {
  final port = args.isEmpty ? 4280 : int.parse(args.first);
  final root = Directory.fromUri(
    Platform.script.resolve('../apps/gomoku_app/build/web/'),
  );
  final upstream = HttpClient()..autoUncompress = false;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Gomoku: http://localhost:$port');
  stdout.writeln(
    'Serving Flutter with same-origin API, cookies, and database workers.',
  );
  await for (final request in server) {
    unawaited(_handle(request, root, upstream));
  }
}

const _hopHeaders = {
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
  'host',
};

Future<void> _handle(
  HttpRequest request,
  Directory root,
  HttpClient client,
) async {
  try {
    final path = request.uri.path;
    if (path.startsWith('/api/') ||
        path == '/v1/websocket' ||
        path.startsWith('/auth/') ||
        path == '/health') {
      final rpc = path.startsWith('/api/') || path == '/v1/websocket';
      final target = Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: rpc ? 8080 : 8082,
        path: path.startsWith('/api/') ? path.substring(4) : path,
        query: request.uri.hasQuery ? request.uri.query : null,
      );
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final headers = <String, dynamic>{};
        for (final name in [
          'cookie',
          'origin',
          'authorization',
          'user-agent',
        ]) {
          final values = request.headers[name];
          if (values != null) {
            headers[name] = values.join(name == 'cookie' ? '; ' : ', ');
          }
        }
        final remote = await WebSocket.connect(
          target.replace(scheme: 'ws').toString(),
          headers: headers,
        );
        final local = await WebSocketTransformer.upgrade(request);
        void close() {
          unawaited(local.close());
          unawaited(remote.close());
        }

        local.listen(remote.add, onDone: close, onError: (Object _) => close());
        remote.listen(local.add, onDone: close, onError: (Object _) => close());
        return;
      }
      final outgoing = await client.openUrl(request.method, target);
      request.headers.forEach((name, values) {
        if (!_hopHeaders.contains(name)) outgoing.headers.set(name, values);
      });
      await outgoing.addStream(request);
      final response = await outgoing.close();
      request.response.statusCode = response.statusCode;
      response.headers.forEach((name, values) {
        if (!_hopHeaders.contains(name)) {
          request.response.headers.set(name, values);
        }
      });
      await request.response.addStream(response);
      await request.response.close();
      return;
    }
    if (request.method != 'GET' && request.method != 'HEAD') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      return;
    }
    final segments = request.uri.pathSegments;
    if (segments.any((s) => s == '..' || s.contains(r'\') || s.contains(':'))) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }
    var file = File.fromUri(root.uri.resolve(segments.join('/')));
    if (path == '/' || (!await file.exists() && !segments.last.contains('.'))) {
      file = File.fromUri(root.uri.resolve('index.html'));
    }
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Build the web app with flutter build web first.');
      await request.response.close();
      return;
    }
    final extension = file.path.split('.').last.toLowerCase();
    final mime = switch (extension) {
      'html' => 'text/html; charset=utf-8',
      'js' || 'mjs' => 'text/javascript; charset=utf-8',
      'json' || 'map' => 'application/json',
      'wasm' => 'application/wasm',
      'png' => 'image/png',
      'svg' => 'image/svg+xml',
      'ico' => 'image/x-icon',
      'ttf' => 'font/ttf',
      'otf' => 'font/otf',
      'woff2' => 'font/woff2',
      'wav' => 'audio/wav',
      _ => 'application/octet-stream',
    };
    request.response.headers
      ..set('content-type', mime)
      ..set('cross-origin-opener-policy', 'same-origin')
      ..set('cross-origin-embedder-policy', 'require-corp')
      ..set('cross-origin-resource-policy', 'same-origin')
      ..set('x-content-type-options', 'nosniff')
      ..set('referrer-policy', 'same-origin')
      ..set('cache-control', 'no-cache');
    request.response.contentLength = await file.length();
    if (request.method != 'HEAD') {
      await request.response.addStream(file.openRead());
    }
    await request.response.close();
  } catch (_) {
    try {
      request.response.statusCode = HttpStatus.badGateway;
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"error":"service_unavailable"}');
      await request.response.close();
    } catch (_) {
      /* The requesting browser may have disconnected. */
    }
  }
}
