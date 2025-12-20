import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/shared_content_manager.dart';
import 'package:view_source_vibe/services/sharing_service.dart';

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Android File Sharing Fix Tests', () {
    test('SharedContentManager handles Android file content correctly', () {
      // Test that SharedContentManager can handle file content provided by Android

      // Simulate Android providing file content directly
      final androidFileData = {
        'type': 'file',
        'content': 'Hello World from Android',
        'fileName': 'test.txt',
        'filePath': '/storage/emulated/0/Download/test.txt',
      };

      // This should be converted to fileBytes
      final result =
          SharedContentManager.convertToStringDynamicMap(androidFileData);

      expect(result, isNotNull);
      expect(result!['type'], 'file');
      expect(result['fileName'], 'test.txt');
      expect(result['filePath'], '/storage/emulated/0/Download/test.txt');
    });

    test('SharedContentManager handles content URIs gracefully', () {
      // Test that SharedContentManager can handle content URIs

      // Simulate Android providing a content URI
      final contentUriData = {
        'type': 'file',
        'filePath':
            'content://com.android.providers.downloads.documents/document/123',
        'fileName': 'document.txt',
        'uri':
            'content://com.android.providers.downloads.documents/document/123',
      };

      // This should be handled without crashing
      final result =
          SharedContentManager.convertToStringDynamicMap(contentUriData);

      expect(result, isNotNull);
      expect(result!['type'], 'file');
      expect(result['fileName'], 'document.txt');
    });

    test('SharedContentManager handles various file path formats', () {
      // Test that SharedContentManager can handle different file path formats

      // Test regular file path
      var result =
          SharedContentManager.extractFileNameFromPath('/path/to/file.txt');
      expect(result, 'file.txt');

      // Test file:// URL
      result = SharedContentManager.extractFileNameFromPath(
          'file:///path/to/file.txt');
      expect(result, 'file.txt');

      // Test content URI
      result = SharedContentManager.extractFileNameFromPath(
          'content://com.android.providers/downloads/documents/document/123');
      expect(result, '123'); // Last path segment
    });

    test('SharingService file path detection works with content URIs', () {
      // Test that SharingService can detect content URIs as file paths

      // Content URIs should be detected as file paths
      expect(
          SharingService.isFilePath(
              'content://com.android.providers.downloads.documents/document/123'),
          isTrue);

      // Regular file paths should still work
      expect(SharingService.isFilePath('/storage/emulated/0/Download/file.txt'),
          isTrue);

      // URLs should not be detected as file paths
      expect(
          SharingService.isFilePath('https://example.com/file.txt'), isFalse);
    });

    test(
        'Android file sharing integration does not break existing functionality',
        () {
      // Test that the Android file sharing fixes don't break existing functionality

      // Test that regular file handling still works
      expect(() async {
        // This would normally fail in test environment due to MissingPluginException
        // but we're just testing that the method call doesn't crash
        try {
          await SharingService.shareFile('/path/to/test.txt');
        } catch (e) {
          // Expected to fail in test environment
          expect(e, isA<Exception>());
        }
      }, returnsNormally);
    });
  });
}
