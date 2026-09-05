import 'dart:io';

Future<void> main(List<String> args) async {
  final port = int.tryParse(args.isNotEmpty ? args[0] : '8085') ?? 8085;
  final root = 'build/web';
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Serving $root at http://127.0.0.1:$port/');
  await for (final req in server) {
    var path = req.uri.path;
    if (path == '/') path = '/index.html';
    final file = File('$root$path');
    if (await file.exists()) {
      req.response.headers.contentType = ContentType.parse(_mime(path));
      await req.response.addStream(file.openRead());
    } else {
      req.response.statusCode = HttpStatus.notFound;
      req.response.write('Not found');
    }
    await req.response.close();
  }
}

String _mime(String path) {
  if (path.endsWith('.html')) return 'text/html; charset=utf-8';
  if (path.endsWith('.js')) return 'application/javascript; charset=utf-8';
  if (path.endsWith('.json')) return 'application/json; charset=utf-8';
  if (path.endsWith('.css')) return 'text/css; charset=utf-8';
  if (path.endsWith('.png')) return 'image/png';
  if (path.endsWith('.ico')) return 'image/x-icon';
  if (path.endsWith('.ttf')) return 'font/ttf';
  if (path.endsWith('.otf')) return 'font/otf';
  if (path.endsWith('.frag')) return 'text/plain';
  if (path.endsWith('.wasm')) return 'application/wasm';
  return 'application/octet-stream';
}