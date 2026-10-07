import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/sharing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('info.wouter.sourceview.sharing');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final sharedUrls = <String>[];

  void mockPlatform({bool fail = false}) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (fail) {
        throw PlatformException(code: 'UNAVAILABLE', message: 'No share sheet');
      }
      expect(call.method, 'shareUrl');
      sharedUrls.add((call.arguments as Map)['url'] as String);
      return null;
    });
  }

  setUp(sharedUrls.clear);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('URL Sharing Tests', () {
    test('passes URLs unchanged to the platform share sheet', () async {
      mockPlatform();
      const urls = [
        'https://example.com',
        'http://example.com',
        'https://www.example.com/path',
        'http://subdomain.example.com:8080/path?query=value',
        'https://example.com/path/to/resource.html',
      ];
      for (final url in urls) {
        await SharingService.shareUrl(url);
      }
      expect(sharedUrls, urls);
    });

    test('wraps platform errors in a "Sharing failed" exception', () async {
      mockPlatform(fail: true);
      await expectLater(
        SharingService.shareUrl('https://example.com'),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('Sharing failed'))),
      );
    });
  });
}
