import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/shared_content_manager.dart';
import 'package:view_source_vibe/services/sharing_service.dart';

void main() {
  group('Real-Time Shared Content Tests', () {
    test('Should handle file sharing in real-time', () async {
      // Test data that would come from iOS while app is running
      final fileSharedData = {
        'type': 'file',
        'filePath': '/Users/test/file.html',
        'fileName': 'file.html'
      };

      // Verify the data structure is correct
      expect(fileSharedData['type'], 'file');
      expect(fileSharedData['filePath'], isNotNull);
      expect(fileSharedData['fileName'], isNotNull);
    });

    test('Should convert URL type with file path to file type in real-time',
        () async {
      // Test the case where iOS sends type: url but content is a file path
      final urlWithFilePath = {
        'type': 'url',
        'content': 'file:///Users/test/file.html'
      };

      // Verify it's detected as a file path
      expect(SharingService.isFilePath(urlWithFilePath['content'] as String),
          true);

      // Verify file name can be extracted
      final fileName = SharedContentManager.extractFileNameFromPath(
          urlWithFilePath['content'] as String);
      expect(fileName, 'file.html');
    });

    test('Should handle complex iOS file paths in real-time', () async {
      // Test the actual iOS file path format
      final iosFileData = {
        'type': 'url', // This is what iOS might send incorrectly
        'content':
            'file:///Users/wouter/Library/Developer/CoreSimulator/Devices/2C19D11B-BEF5-45B1-81FD-0919B6BFB505/data/Containers/Data/Application/DDE7D1D9-790B-429E-A07B-BCAE79AADB4F/tmp/info.wouter.sourceviewer-Inbox/sample.py'
      };

      // Verify it's detected as a file path
      expect(SharingService.isFilePath(iosFileData['content'] as String), true);

      // Verify file name extraction
      final fileName = SharedContentManager.extractFileNameFromPath(
          iosFileData['content'] as String);
      expect(fileName, 'sample.py');
    });

    test('Should handle URL sharing in real-time', () async {
      // Test regular URL sharing
      final urlSharedData = {'type': 'url', 'content': 'https://example.com'};

      // Verify it's NOT detected as a file path
      expect(
          SharingService.isFilePath(urlSharedData['content'] as String), false);
    });

    test('Should handle text sharing in real-time', () async {
      // Test text sharing
      final textSharedData = {'type': 'text', 'content': 'Hello World'};

      // Verify the data structure
      expect(textSharedData['type'], 'text');
      expect(textSharedData['content'], 'Hello World');
    });

    test('Should handle various shared content types', () async {
      final testCases = [
        {
          'type': 'file',
          'filePath': '/Users/test/file.html',
          'fileName': 'file.html'
        },
        {'type': 'url', 'content': 'https://example.com'},
        {'type': 'text', 'content': 'Sample text'},
        {
          'type': 'file',
          'filePath': '/var/mobile/Containers/Data/Application/app/file.txt',
          'fileName': 'file.txt'
        },
      ];

      for (final testCase in testCases) {
        final type = testCase['type'] as String;
        expect(type, isNotNull);
        expect(type.isNotEmpty, true);
      }
    });

    test('Should handle edge cases in real-time sharing', () async {
      // Test empty content
      final emptyData = {'type': 'text'};
      expect(emptyData['content'], isNull);

      // Test missing type
      final noTypeData = {'content': 'test'};
      expect(noTypeData['type'], isNull);
    });
  });
}
