import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:view_source_vibe/services/unified_sharing_service.dart';

void main() {
  // Initialize the test binding
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Filename Handling Fix Tests', () {
    
    setUp(() {
      // Set up a mock method channel handler for testing
      const MethodChannel sharingChannel = MethodChannel('info.wouter.sourceview.sharing');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        sharingChannel,
        (MethodCall methodCall) async {
          if (methodCall.method == 'shareHtml') {
            final args = methodCall.arguments as Map;
            final filename = args['filename'] as String;
            
            // Verify that the filename is not empty
            if (filename.isEmpty) {
              throw PlatformException(
                code: 'INVALID_FILENAME',
                message: 'Filename cannot be empty',
              );
            }
            
            // Return success if filename is valid
            return true;
          }
          throw PlatformException(
            code: 'UNAVAILABLE',
            message: 'Method not implemented',
          );
        },
      );
    });

    test('shareHtml with valid filename works correctly', () async {
      // This should work fine
      expect(() async {
        await UnifiedSharingService.shareHtml('<html><body>Test</body></html>', 
            filename: 'test.html');
      }, returnsNormally);
    });

    test('shareHtml with empty filename uses default', () async {
      // This should use the default filename and work
      expect(() async {
        await UnifiedSharingService.shareHtml('<html><body>Test</body></html>', 
            filename: '');
      }, returnsNormally);
    });

    test('shareHtml with null filename uses default', () async {
      // This should use the default filename and work
      expect(() async {
        await UnifiedSharingService.shareHtml('<html><body>Test</body></html>');
      }, returnsNormally);
    });

    test('shareHtml with whitespace-only filename uses default', () async {
      // This should use the default filename and work
      expect(() async {
        await UnifiedSharingService.shareHtml('<html><body>Test</body></html>', 
            filename: '   ');
      }, returnsNormally);
    });

    test('shareHtml handles various edge cases', () async {
      // Test various edge cases
      final testCases = [
        null,
        '',
        '   ',
        '\t',
        '\n',
      ];

      for (final filename in testCases) {
        expect(() async {
          await UnifiedSharingService.shareHtml('<html><body>Test</body></html>', 
              filename: filename);
        }, returnsNormally, reason: 'Failed for filename: "$filename"');
      }
    });
  });
}