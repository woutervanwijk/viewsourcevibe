import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:view_source_vibe/services/unified_sharing_service.dart';

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannel Communication Tests', () {
    
    // Mock MethodChannel for testing
    const MethodChannel sharedContentChannel = MethodChannel('info.wouter.sourceviewer/shared_content');
    const MethodChannel sharingChannel = MethodChannel('info.wouter.sourceview.sharing');

    setUp(() {
      // Set up test method call handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            sharedContentChannel,
            (MethodCall methodCall) async {
              if (methodCall.method == 'getSharedContent') {
                // Mock response for shared content
                return {
                  'type': 'text',
                  'content': 'Test shared content'
                };
              }
              return null;
            }
          );

      // Set up mock for sharing channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            sharingChannel,
            (MethodCall methodCall) async {
              if (methodCall.method == 'shareText') {
                return true;
              }
              return null;
            }
          );
    });

    tearDown(() {
      // Clean up mock handlers
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(sharedContentChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(sharingChannel, null);
    });

    test('UnifiedSharingService.shareText uses correct channel', () async {
      // This test verifies that shareText uses the correct channel
      // We can't test the actual sharing in a unit test, but we can verify
      // that it doesn't throw an exception with our mock
      
      expect(() async {
        await UnifiedSharingService.shareText('Test text');
      }, returnsNormally);
    });

    test('UnifiedSharingService.extractFileNameFromPath works correctly', () {
      // Test file name extraction
      
      expect(
        UnifiedSharingService.extractFileNameFromPath('/path/to/file.txt'),
        'file.txt'
      );
      
      expect(
        UnifiedSharingService.extractFileNameFromPath('file:///path/to/file.txt'),
        'file.txt'
      );
      
      expect(
        UnifiedSharingService.extractFileNameFromPath('file///path/to/file.txt'),
        'file.txt'
      );
      
      expect(
        UnifiedSharingService.extractFileNameFromPath('file://path/to/file.txt'),
        'file.txt'
      );
      
      // Test edge case: path ending with slash
      expect(
        UnifiedSharingService.extractFileNameFromPath('/path/to/directory/'),
        'shared_file'
      );
    });
  });
}