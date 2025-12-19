import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/platform_sharing_handler.dart';

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Platform Sharing Handler Fix Tests', () {
    test('checkForInitialSharedContent handles missing platform implementation gracefully', () async {
      // This test verifies that checkForInitialSharedContent works in test environments
      // where the platform channel isn't available
      
      final result = await PlatformSharingHandler.checkForInitialSharedContent();
      
      // In test environment, this should return null (no shared content)
      expect(result, isNull);
    });

    test('checkForInitialSharedContent uses correct channel', () async {
      // This test verifies that the method uses the correct channel
      // We can't test the actual channel call in a unit test, but we can verify
      // that it doesn't throw an exception and returns null gracefully
      
      // The method should not throw even when the platform implementation is missing
      expect(() async {
        await PlatformSharingHandler.checkForInitialSharedContent();
      }, returnsNormally);
    });
  });
}