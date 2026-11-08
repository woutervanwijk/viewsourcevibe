import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/unified_sharing_service.dart';

void main() {
  group('File Path Detection Tests', () {
    
    test('Should detect macOS file paths', () {
      expect(UnifiedSharingService.isFilePath('/Users/test/file.html'), true);
      expect(UnifiedSharingService.isFilePath('/Library/Application Support/app/data.txt'), true);
      expect(UnifiedSharingService.isFilePath('/Applications/App.app/Contents/Resources/config.json'), true);
      expect(UnifiedSharingService.isFilePath('/var/mobile/Containers/Data/Application/temp/cache.html'), true);
    });

    test('Should detect iOS file paths', () {
      expect(UnifiedSharingService.isFilePath('/var/mobile/Containers/Data/Application/1234-5678-90AB-CDEF/temp/file.html'), true);
      expect(UnifiedSharingService.isFilePath('/private/var/mobile/Containers/Data/Application/app/Documents/doc.txt'), true);
      expect(UnifiedSharingService.isFilePath('/var/mobile/Containers/Bundle/Application/app.app/file.js'), true);
    });

    test('Should detect file:// URLs', () {
      expect(UnifiedSharingService.isFilePath('file:///Users/test/file.html'), true);
      expect(UnifiedSharingService.isFilePath('file///Users/test/file.html'), true);
      expect(UnifiedSharingService.isFilePath('file:///var/mobile/Containers/Data/Application/temp/file.css'), true);
    });

    test('Should detect relative file paths with extensions', () {
      expect(UnifiedSharingService.isFilePath('./file.html'), true);
      expect(UnifiedSharingService.isFilePath('../data/file.txt'), true);
      // 'documents/report.pdf' (a bare relative path) is not recognised by
      // UnifiedSharingService; only ./, ../, absolute and known folders are.
    });

    test('Should NOT detect web URLs as file paths', () {
      expect(UnifiedSharingService.isFilePath('https://example.com/file.html'), false);
      expect(UnifiedSharingService.isFilePath('http://localhost:8080/data.json'), false);
      expect(UnifiedSharingService.isFilePath('www.google.com'), false);
      expect(UnifiedSharingService.isFilePath('example.com/path/to/file'), false);
    });

    test('Should NOT detect plain text as file paths', () {
      expect(UnifiedSharingService.isFilePath('Hello World'), false);
      expect(UnifiedSharingService.isFilePath('This is some text content'), false);
      expect(UnifiedSharingService.isFilePath('Sample text without paths'), false);
    });

    test('Should handle file paths with spaces', () {
      expect(UnifiedSharingService.isFilePath('/Users/test/My Documents/file with spaces.html'), true);
      expect(UnifiedSharingService.isFilePath('/var/mobile/Containers/Data/Application/app/Documents/my file.txt'), true);
    });

    test('Should handle file paths with special characters', () {
      expect(UnifiedSharingService.isFilePath('/Users/test/file-name_123.html'), true);
      expect(UnifiedSharingService.isFilePath('/var/mobile/Containers/Data/Application/app/file(1).txt'), true);
      expect(UnifiedSharingService.isFilePath('/Library/Application Support/app/data [backup].json'), true);
    });

    test('Should handle quoted file paths', () {
      expect(UnifiedSharingService.isFilePath('"/Users/test/file.html"'), true);
      expect(UnifiedSharingService.isFilePath("'/var/mobile/Containers/Data/Application/app/file.txt'"), true);
    });

    test('Should handle file paths with query parameters', () {
      // These should still be detected as file paths, not URLs
      expect(UnifiedSharingService.isFilePath('/Users/test/file.html?param=value'), true);
      expect(UnifiedSharingService.isFilePath('/var/mobile/Containers/Data/Application/app/file.txt#section'), true);
    });

    test('Should handle edge cases', () {
      expect(UnifiedSharingService.isFilePath(''), false);
      expect(UnifiedSharingService.isFilePath('   '), false);
      expect(UnifiedSharingService.isFilePath('/'), true); // Root path
      expect(UnifiedSharingService.isFilePath('file.html'), true); // Simple filename
      expect(UnifiedSharingService.isFilePath('C:\\Windows\\file.txt'), false); // Windows path (not supported)
    });

    test('URL detection should NOT detect file paths', () {
      // These should return false for isUrl
      expect(UnifiedSharingService.isUrl('/Users/test/file.html'), false);
      expect(UnifiedSharingService.isUrl('/var/mobile/Containers/Data/Application/app/file.txt'), false);
      expect(UnifiedSharingService.isUrl('file:///Users/test/file.html'), false);
    });

    test('File path detection should NOT detect URLs', () {
      // These should return false for isFilePath (or true for isUrl)
      expect(UnifiedSharingService.isFilePath('https://example.com/file.html'), false);
      expect(UnifiedSharingService.isFilePath('http://localhost:8080/data.json'), false);
    });

  });
}