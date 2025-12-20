import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/sharing_service.dart';

void main() {
  group('iOS Share Extension File Content Tests', () {
    test('SharingService should detect file paths that need content handling', () async {
      // Test cases that should be detected as problematic file paths
      final problematicPaths = [
        'file:///Users/wouter/Library/Developer/CoreSimulator/Devices/2C19D11B-BEF5-45B1-81FD-0919B6BFB505/data/Containers/Shared/AppGroup/29525140-96EE-4D50-BDC2-55B065FD5E43/File%20Provider%20Storage/sample.py',
        '/var/mobile/Containers/Data/Application/temp/File%20Provider%20Storage/document.txt',
        '/Users/test/Library/Developer/CoreSimulator/Devices/some-device/data/Containers/Shared/AppGroup/some-group/File Provider Storage/file.html',
      ];

      for (final path in problematicPaths) {
        // These should be detected as file paths
        expect(SharingService.isFilePath(path), true, reason: 'Path should be detected as file path: $path');
        
        // These should NOT be detected as URLs
        expect(SharingService.isUrl(path), false, reason: 'Path should not be detected as URL: $path');
      }
    });

    test('SharingService should handle file paths with URL-encoded spaces', () async {
      final pathWithEncodedSpaces = 'file:///Users/test/File%20Provider%20Storage/sample.py';
      
      // Should be detected as file path
      expect(SharingService.isFilePath(pathWithEncodedSpaces), true);
      
      // Should not be detected as URL
      expect(SharingService.isUrl(pathWithEncodedSpaces), false);
    });

    test('SharingService should handle sandboxed file paths correctly', () async {
      final sandboxedPaths = [
        '/Users/wouter/Library/Developer/CoreSimulator/Devices/2C19D11B-BEF5-45B1-81FD-0919B6BFB505/data/Containers/Shared/AppGroup/29525140-96EE-4D50-BDC2-55B065FD5E43/File Provider Storage/sample.py',
        '/var/mobile/Containers/Data/Application/temp/File Provider Storage/document.txt',
        '/private/var/mobile/Containers/Shared/AppGroup/group.com.example/files/file.html',
      ];

      for (final path in sandboxedPaths) {
        // These should be detected as file paths
        expect(SharingService.isFilePath(path), true, reason: 'Sandboxed path should be detected as file path: $path');
        
        // These should contain indicators of sandboxed locations
        expect(path.contains('Containers') || path.contains('AppGroup') || path.contains('Library/Developer'),
               true, reason: 'Path should contain sandbox indicators: $path');
      }
    });

    test('SharingService should distinguish between actual file content and file paths', () async {
      // This is actual file content (Python code)
      final actualContent = 'def hello():\n    print("Hello, World!")';
      
      // This is a file path
      final filePath = 'file:///Users/test/File%20Provider%20Storage/sample.py';
      
      // Actual content should not be detected as file path
      expect(SharingService.isFilePath(actualContent), false);
      
      // File path should be detected as file path
      expect(SharingService.isFilePath(filePath), true);
      
      // Actual content should not be detected as URL
      expect(SharingService.isUrl(actualContent), false);
      
      // File path should not be detected as URL
      expect(SharingService.isUrl(filePath), false);
    });

    test('SharingService should handle file:// URL variations', () async {
      final fileUrlVariations = [
        'file:///path/to/file.txt',
        'file://path/to/file.txt', 
        'file///path/to/file.txt',
      ];

      for (final url in fileUrlVariations) {
        // All should be detected as file paths
        expect(SharingService.isFilePath(url), true, reason: 'File URL variation should be detected as file path: $url');
        
        // None should be detected as regular URLs
        expect(SharingService.isUrl(url), false, reason: 'File URL variation should not be detected as regular URL: $url');
      }
    });
  });
}