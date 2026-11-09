import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/collectors/transfer_size_lookup.dart';

void main() {
  late HttpServer server;
  late String base;
  final seenHeaders = <String, String?>{};
  final methods = <String, List<String>>{};

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((req) async {
      seenHeaders['accept-encoding'] =
          req.headers.value(HttpHeaders.acceptEncodingHeader);
      methods.putIfAbsent(req.uri.path, () => []).add(req.method);
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
        case '/head-405':
          if (req.method == 'HEAD') {
            res.statusCode = 405;
          } else {
            res.add(List.filled(3000, 1));
          }
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

  Future<int?> look(String path, {int? limit}) => limit == null
      ? lookupTransferSize('$base$path', userAgent: 'test')
      : lookupTransferSize('$base$path', userAgent: 'test', limit: limit);

  test('counts the compressed bytes on the wire plus headers', () async {
    final gz = gzip.encode(List.filled(100 * 1024, 65)).length;
    final size = (await look('/gz'))!;
    expect(size, greaterThan(gz));
    expect(size, lessThan(gz + 500), reason: 'headers are a few hundred B');
    expect(size, lessThan(100 * 1024), reason: 'never the decoded size');
    expect(seenHeaders['accept-encoding'], contains('br'));
  });

  test('a HEAD sizes the resource first; the body is not re-downloaded',
      () async {
    final gz = gzip.encode(List.filled(100 * 1024, 65)).length;
    final size = (await look('/gz'))!;
    expect(methods['/gz']!.first, 'HEAD');
    // Content-length was on the HEAD response: no GET was needed.
    expect(methods['/gz'], isNot(contains('GET')));
    expect(size, greaterThan(gz));
  });

  test('when HEAD is refused, a GET measures the body', () async {
    final size = (await look('/head-405'))!;
    expect(methods['/head-405'], ['HEAD', 'GET']);
    expect(size, greaterThanOrEqualTo(3000));
  });

  test('without content-length the received bytes still count', () async {
    final size = (await look('/chunked'))!;
    expect(size, greaterThanOrEqualTo(5000));
    expect(size, lessThan(5500));
  });

  test('past the limit it reports a lower bound, not a size', () async {
    expect(look('/big', limit: 1024), throwsA(isA<SizeLimitExceeded>()));
  });

  test('the default limit allows big GIFs (50 MB)', () {
    expect(const SizeLimitExceeded(50 * 1024 * 1024).toString(),
        'larger than 50 MB');
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
