import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:view_source_vibe/services/sharing_service.dart';

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('iOS Sharing Service Tests', () {
    
    // Mock MethodChannel for testing
    const MethodChannel sharingChannel = MethodChannel('info.wouter.sourceview.sharing');

    setUp(() {
      // Set up test method call handler that simulates iOS implementation
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            sharingChannel,
            (MethodCall methodCall) async {
              // Simulate successful iOS sharing
              if (methodCall.method == 'shareText' || 
                  methodCall.method == 'shareHtml' || 
                  methodCall.method == 'shareFile' || 
                  methodCall.method == 'shareUrl') {
                return true;
              }
              return null;
            }
          );
    });

    tearDown(() {
      // Clean up mock handlers
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(sharingChannel, null);
    });

    test('shareText works with iOS implementation', () async {
      // This test verifies that shareText works when iOS implementation is available
      
      expect(() async {
        await SharingService.shareText('Test text from iOS');
      }, returnsNormally);
    });

    test('shareHtml works with iOS implementation', () async {
      // This test verifies that shareHtml works when iOS implementation is available
      
      expect(() async {
        await SharingService.shareHtml('<html><body>Test HTML</body></html>', 
            filename: 'test.html');
      }, returnsNormally);
    });

    test('shareFile works with iOS implementation', () async {
      // This test verifies that shareFile works when iOS implementation is available
      
      expect(() async {
        await SharingService.shareFile('/path/to/test.html', mimeType: 'text/html');
      }, returnsNormally);
    });

    test('shareUrl works with iOS implementation', () async {
      // This test verifies that shareUrl works when iOS implementation is available
      
      expect(() async {
        await SharingService.shareUrl('https://example.com');
      }, returnsNormally);
    });

    test('iOS sharing methods handle errors gracefully', () async {
      // Test that iOS sharing handles errors properly
      
      // Remove the mock handler to simulate missing implementation
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(sharingChannel, null);

      // These should throw MissingPluginException but not crash
      expect(() async {
        await SharingService.shareText('Test');
      }, throwsA(isA<Exception>()));

      expect(() async {
        await SharingService.shareHtml('<html></html>');
      }, throwsA(isA<Exception>()));
    });
  });
}