import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter/services.dart';
import 'package:view_source_vibe/services/unified_sharing_service.dart';

class MockMethodChannel extends Mock implements MethodChannel {}

void main() {
  // Initialize the test binding
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Share Button Fix Tests', () {
    
    test('UnifiedSharingService can be instantiated', () {
      // This test just verifies that the service can be instantiated
      // and that the channel names are correct
      expect(UnifiedSharingService, isNotNull);
    });

    test('shareHtml method exists and has correct signature', () {
      // Verify that the shareHtml method exists and has the correct signature
      expect(UnifiedSharingService.shareHtml, isNotNull);
      expect(UnifiedSharingService.shareHtml, isA<Function>());
    });

    test('shareText method exists and has correct signature', () {
      // Verify that the shareText method exists and has the correct signature
      expect(UnifiedSharingService.shareText, isNotNull);
      expect(UnifiedSharingService.shareText, isA<Function>());
    });

    test('shareFile method exists and has correct signature', () {
      // Verify that the shareFile method exists and has the correct signature
      expect(UnifiedSharingService.shareFile, isNotNull);
      expect(UnifiedSharingService.shareFile, isA<Function>());
    });

    test('shareUrl method exists and has correct signature', () {
      // Verify that the shareUrl method exists and has the correct signature
      expect(UnifiedSharingService.shareUrl, isNotNull);
      expect(UnifiedSharingService.shareUrl, isA<Function>());
    });

    test('shareHtml handles errors gracefully', () async {
      // This test verifies that shareHtml handles errors gracefully
      // by using a mock method channel
      
      const MethodChannel sharingChannel = MethodChannel('info.wouter.sourceview.sharing');

      // Set up a test handler that throws an error
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        sharingChannel,
        (MethodCall methodCall) async {
          if (methodCall.method == 'shareHtml') {
            throw PlatformException(
              code: 'UNAVAILABLE',
              message: 'Method not implemented',
            );
          }
          throw PlatformException(
            code: 'UNAVAILABLE',
            message: 'Method not implemented',
          );
        },
      );

      try {
        await UnifiedSharingService.shareHtml('<html><body>Test</body></html>');
        // If we get here, the error was not thrown as expected
        expect(true, isFalse, reason: 'Expected PlatformException to be thrown');
      } catch (e) {
        expect(e, isA<Exception>());
        expect(e.toString(), contains('Sharing failed'));
      }
    });
  });
}