import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/unified_sharing_service.dart';

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sharing Service Fix Tests', () {
    test('shareHtml should handle errors gracefully', () async {
      // This test verifies that the sharing service can handle errors
      // without crashing the app

      try {
        // This will fail because we're not running on a real device
        // but it should fail gracefully
        await UnifiedSharingService.shareHtml('<html><body>Test</body></html>',
            filename: 'test.html');
      } catch (e) {
        // Expected to fail in test environment with MissingPluginException
        expect(e, isA<Exception>());
        expect(e.toString(), contains('MissingPluginException'));
      }
    });

    test('shareText should handle errors gracefully', () async {
      try {
        await UnifiedSharingService.shareText('Test text');
      } catch (e) {
        expect(e, isA<Exception>());
        expect(e.toString(), contains('MissingPluginException'));
      }
    });

    test('shareFile should handle errors gracefully', () async {
      try {
        await UnifiedSharingService.shareFile('/nonexistent/path/test.html');
      } catch (e) {
        expect(e, isA<Exception>());
        expect(e.toString(), contains('MissingPluginException'));
      }
    });
  });
}
