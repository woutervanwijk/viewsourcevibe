import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/shared_content_manager.dart';
import 'package:view_source_vibe/services/sharing_service.dart';

void main() {
  group('URL to File Conversion Tests', () {
    
    test('Should detect file URLs in URL content', () {
      // Test the actual case from the error
      final fileUrl = 'file:///Users/wouter/Library/Developer/CoreSimulator/Devices/2C19D11B-BEF5-45B1-81FD-0919B6BFB505/data/Containers/Data/Application/DDE7D1D9-790B-429E-A07B-BCAE79AADB4F/tmp/info.wouter.sourceviewer-Inbox/sample.py';
      
      expect(SharingService.isFilePath(fileUrl), true);
    });

    test('Should extract file name from file URL', () {
      final fileUrl = 'file:///Users/wouter/Library/Developer/CoreSimulator/Devices/2C19D11B-BEF5-45B1-81FD-0919B6BFB505/data/Containers/Data/Application/DDE7D1D9-790B-429E-A07B-BCAE79AADB4F/tmp/info.wouter.sourceviewer-Inbox/sample.py';
      
      final fileName = SharedContentManager.extractFileNameFromPath(fileUrl);
      expect(fileName, 'sample.py');
    });

    test('Should extract file name from various file URLs', () {
      final testCases = [
        {
          'input': 'file:///Users/test/file.html',
          'expected': 'file.html'
        },
        {
          'input': 'file///var/mobile/Containers/Data/Application/app/file.txt',
          'expected': 'file.txt'
        },
        {
          'input': 'file://Library/Application Support/app/data.json',
          'expected': 'data.json'
        },
        {
          'input': '/Users/test/file.html',
          'expected': 'file.html'
        },
        {
          'input': '/var/mobile/Containers/Data/Application/app/',
          'expected': 'shared_file' // Fallback for directory paths
        },
      ];
      
      for (final testCase in testCases) {
        final input = testCase['input'] as String;
        final expected = testCase['expected'] as String;
        
        final fileName = SharedContentManager.extractFileNameFromPath(input);
        expect(fileName, expected);
      }
    });

    test('Should handle file URLs with special characters', () {
      final fileUrl = 'file:///Users/test/My Documents/file with spaces.html';
      final fileName = SharedContentManager.extractFileNameFromPath(fileUrl);
      expect(fileName, 'file with spaces.html');
    });

    test('Should handle file URLs with query parameters', () {
      final fileUrl = 'file:///Users/test/file.html?param=value';
      final fileName = SharedContentManager.extractFileNameFromPath(fileUrl);
      expect(fileName, 'file.html?param=value'); // Keep query params in file name
    });

    test('Should handle edge cases in file name extraction', () {
      expect(SharedContentManager.extractFileNameFromPath('file:///'), 'shared_file');
      expect(SharedContentManager.extractFileNameFromPath('file:///file'), 'file');
      expect(SharedContentManager.extractFileNameFromPath('file:///file.html'), 'file.html');
      expect(SharedContentManager.extractFileNameFromPath('file:///path/to/'), 'shared_file');
    });

    test('Should handle complex iOS file paths', () {
      // Test the actual iOS file path from the error
      final iosFilePath = 'file:///Users/wouter/Library/Developer/CoreSimulator/Devices/2C19D11B-BEF5-45B1-81FD-0919B6BFB505/data/Containers/Data/Application/DDE7D1D9-790B-429E-A07B-BCAE79AADB4F/tmp/info.wouter.sourceviewer-Inbox/sample.py';
      
      // Verify it's detected as a file path
      expect(SharingService.isFilePath(iosFilePath), true);
      
      // Verify file name extraction
      final fileName = SharedContentManager.extractFileNameFromPath(iosFilePath);
      expect(fileName, 'sample.py');
    });

    test('Should NOT detect web URLs as file paths', () {
      final webUrls = [
        'https://example.com/file.html',
        'http://localhost:8080/data.json',
        'www.google.com',
      ];
      
      for (final webUrl in webUrls) {
        expect(SharingService.isFilePath(webUrl), false);
      }
    });

  });
}