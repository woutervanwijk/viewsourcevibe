import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:view_source_vibe/services/html_service.dart';

void main() {
  group('HtmlService.probeUrl', () {
    test('returns correct details for 200 OK HEAD request', () async {
      final htmlService = HtmlService();

      final mockClient = MockClient((request) async {
        if (request.method == 'HEAD' &&
            request.url.toString() == 'https://example.com') {
          return http.Response('', 200, headers: {
            'content-type': 'text/html',
            'content-length': '1234',
          });
        }
        return http.Response('Not Found', 404);
      });

      await http.runWithClient(() async {
        final result = await htmlService.probeUrl('https://example.com');

        expect(result['statusCode'], 200);
        expect(result['headers']['content-type'], 'text/html');
        expect(result['finalUrl'], 'https://example.com');
      }, () => mockClient);
    });

    test('falls back to GET with Range header if HEAD fails', () async {
      final htmlService = HtmlService();

      final mockClient = MockClient((request) async {
        if (request.method == 'HEAD') {
          throw Exception('Connection closed'); // Simulate failure
        }
        if (request.method == 'GET' &&
            request.url.toString() == 'https://example.com' &&
            request.headers['Range'] == 'bytes=0-0') {
          return http.Response('F', 206, headers: {
            // 206 Partial Content
            'content-type': 'text/html',
            'content-length': '1',
            'content-range': 'bytes 0-0/1234'
          });
        }
        return http.Response('Not Found POO', 404);
      });

      await http.runWithClient(() async {
        final result = await htmlService.probeUrl('https://example.com');

        expect(result['statusCode'], 206);
        expect(result['headers']['content-type'], 'text/html');
      }, () => mockClient);
    });
  });
}
