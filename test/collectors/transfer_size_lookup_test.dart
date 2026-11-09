import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/collectors/transfer_size_lookup.dart';

void main() {
  late HttpServer server;
  late String base;
  final seenHeaders = <String, String?>{};

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((req) async {
      seenHeaders['accept-encoding'] =
          req.headers.value(HttpHeaders.acceptEncodingHeader);
      final res = req.response;
      switch (req.uri.path) {
        case '/gz':
          // 100 KB of text, gzipped on the wire.
          final body = gzip.encode(List.filled(100 * 1024, 65));
          res.headers.set('content-encoding', 'gzip');
          res.contentLength = body.length;
          res.add(body);
        case '/chunked':
          res.add(List.filled(3000, 1));
          res.add(List.filled(2000, 1));
        case '/big':
          res.add(List.filled(4096, 1));
        case '/404':
          res.statusCode = 404;
          res.write('nope');
        case '/empty':
          break;
      }
      await res.close();
    });
  });
  tearDown(() => server.close(force: true));

  Future<int?> look(String path, {int limit = 10 * 1024 * 1024}) =>
      lookupTransferSize('$base$path', userAgent: 'test', limit: limit);

  test('counts the compressed bytes on the wire plus headers', () async {
    final gz = gzip.encode(List.filled(100 * 1024, 65)).length;
    final size = (await look('/gz'))!;
    expect(size, greaterThan(gz));
    expect(size, lessThan(gz + 500), reason: 'headers are a few hundred B');
    expect(size, lessThan(100 * 1024), reason: 'never the decoded size');
    expect(seenHeaders['accept-encoding'], contains('br'));
  });

  test('without content-length the received bytes still count', () async {
    final size = (await look('/chunked'))!;
    expect(size, greaterThanOrEqualTo(5000));
    expect(size, lessThan(5500));
  });

  test('past the limit it reports a lower bound, not a size', () async {
    expect(look('/big', limit: 1024), throwsA(isA<SizeLimitExceeded>()));
  });

  test('error status and empty body give no size (never 0)', () async {
    expect(await look('/404'), isNull);
    expect(await look('/empty'), isNull);
  });

  test('an unreachable host throws (a failed lookup, not a size)', () async {
    await server.close(force: true);
    expect(look('/gz'), throwsA(anything));
  });
}
