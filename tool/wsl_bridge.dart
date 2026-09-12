import 'dart:async';
import 'dart:io';

/// For WSL installations where Windows localhost forwarding is unavailable.
/// Docker binds only to the WSL private address; Windows listens only on loopback.
Future<void> main(List<String> args) async {
  if (args.length != 1 || InternetAddress.tryParse(args.single) == null) {
    stderr.writeln('Usage: dart tool/wsl_bridge.dart <WSL-private-IP>');
    exitCode = 64;
    return;
  }
  final host = args.single;
  for (final port in [8090, 8091, 1025, 8025]) {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    server.listen((incoming) async {
      try {
        final outgoing = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 5),
        );
        unawaited(_forward(incoming, outgoing));
        unawaited(_forward(outgoing, incoming));
      } catch (_) {
        incoming.destroy();
      }
    });
    stdout.writeln('Forwarding localhost:$port into WSL.');
  }
}

Future<void> _forward(Socket source, Socket destination) async {
  try {
    await destination.addStream(source);
    await destination.close();
  } catch (_) {
    source.destroy();
    destination.destroy();
  }
}
