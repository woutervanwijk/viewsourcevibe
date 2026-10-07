import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';

/// Probing uses dart:io's HttpClient, so test against a local server.
void main() {
  group('HtmlService.probeUrl', () {
    late HttpServer server;
    late String url;
    var failHead = false;
    String? rangeHeader;

    setUp(() async {
      failHead = false;
      rangeHeader = null;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      url = 'http://${server.address.address}:${server.port}/';
      server.listen((request) async {
        if (request.method == 'HEAD') {
          if (failHead) {
            // Drop the connection, as some servers do for HEAD.
            (await request.response.detachSocket(writeHeaders: false))
                .destroy();
            return;
          }
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..contentLength = 1234;
        } else {
          rangeHeader = request.headers.value('range');
          request.response
            ..statusCode = 206
            ..headers.contentType = ContentType.html
            ..headers.set('content-range', 'bytes 0-0/1234')
            ..write('F');
        }
        await request.response.close();
      });
    });

    tearDown(() => server.close(force: true));

    test('returns details for a 200 OK HEAD request', () async {
      final result = await HtmlService().probeUrl(url);

      expect(result['statusCode'], 200);
      expect(result['headers']['content-type'], startsWith('text/html'));
      expect(result['contentLength'], 1234);
    });

    test('falls back to GET with a Range header if HEAD fails', () async {
      failHead = true;
      final result = await HtmlService().probeUrl(url);

      expect(result['statusCode'], 206);
      expect(rangeHeader, 'bytes=0-0');
      expect(result['headers']['content-type'], startsWith('text/html'));
    });
  });
}
