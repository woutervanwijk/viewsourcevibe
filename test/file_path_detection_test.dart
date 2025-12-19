import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/sharing_service.dart';

void main() {
  group('File Path Detection Tests', () {
    
    test('Should detect macOS file paths', () {
      expect(SharingService.isFilePath('/Users/test/file.html'), true);
      expect(SharingService.isFilePath('/Library/Application Support/app/data.txt'), true);
      expect(SharingService.isFilePath('/Applications/App.app/Contents/Resources/config.json'), true);
      expect(SharingService.isFilePath('/var/mobile/Containers/Data/Application/temp/cache.html'), true);
    });

    test('Should detect iOS file paths', () {
      expect(SharingService.isFilePath('/var/mobile/Containers/Data/Application/1234-5678-90AB-CDEF/temp/file.html'), true);
      expect(SharingService.isFilePath('/private/var/mobile/Containers/Data/Application/app/Documents/doc.txt'), true);
      expect(SharingService.isFilePath('/var/mobile/Containers/Bundle/Application/app.app/file.js'), true);
    });

    test('Should detect file:// URLs', () {
      expect(SharingService.isFilePath('file:///Users/test/file.html'), true);
      expect(SharingService.isFilePath('file///Users/test/file.html'), true);
      expect(SharingService.isFilePath('file:///var/mobile/Containers/Data/Application/temp/file.css'), true);
    });

    test('Should detect relative file paths with extensions', () {
      expect(SharingService.isFilePath('./file.html'), true);
      expect(SharingService.isFilePath('../data/file.txt'), true);
      expect(SharingService.isFilePath('documents/report.pdf'), true);
    });

    test('Should NOT detect web URLs as file paths', () {
      expect(SharingService.isFilePath('https://example.com/file.html'), false);
      expect(SharingService.isFilePath('http://localhost:8080/data.json'), false);
      expect(SharingService.isFilePath('www.google.com'), false);
      expect(SharingService.isFilePath('example.com/path/to/file'), false);
    });

    test('Should NOT detect plain text as file paths', () {
      expect(SharingService.isFilePath('Hello World'), false);
      expect(SharingService.isFilePath('This is some text content'), false);
      expect(SharingService.isFilePath('Sample text without paths'), false);
    });

    test('Should handle file paths with spaces', () {
      expect(SharingService.isFilePath('/Users/test/My Documents/file with spaces.html'), true);
      expect(SharingService.isFilePath('/var/mobile/Containers/Data/Application/app/Documents/my file.txt'), true);
    });

    test('Should handle file paths with special characters', () {
      expect(SharingService.isFilePath('/Users/test/file-name_123.html'), true);
      expect(SharingService.isFilePath('/var/mobile/Containers/Data/Application/app/file(1).txt'), true);
      expect(SharingService.isFilePath('/Library/Application Support/app/data [backup].json'), true);
    });

    test('Should handle quoted file paths', () {
      expect(SharingService.isFilePath('"/Users/test/file.html"'), true);
      expect(SharingService.isFilePath("'/var/mobile/Containers/Data/Application/app/file.txt'"), true);
    });

    test('Should handle file paths with query parameters', () {
      // These should still be detected as file paths, not URLs
      expect(SharingService.isFilePath('/Users/test/file.html?param=value'), true);
      expect(SharingService.isFilePath('/var/mobile/Containers/Data/Application/app/file.txt#section'), true);
    });

    test('Should handle edge cases', () {
      expect(SharingService.isFilePath(''), false);
      expect(SharingService.isFilePath('   '), false);
      expect(SharingService.isFilePath('/'), true); // Root path
      expect(SharingService.isFilePath('file.html'), true); // Simple filename
      expect(SharingService.isFilePath('C:\\Windows\\file.txt'), false); // Windows path (not supported)
    });

    test('URL detection should NOT detect file paths', () {
      // These should return false for isUrl
      expect(SharingService.isUrl('/Users/test/file.html'), false);
      expect(SharingService.isUrl('/var/mobile/Containers/Data/Application/app/file.txt'), false);
      expect(SharingService.isUrl('file:///Users/test/file.html'), false);
    });

    test('File path detection should NOT detect URLs', () {
      // These should return false for isFilePath (or true for isUrl)
      expect(SharingService.isFilePath('https://example.com/file.html'), false);
      expect(SharingService.isFilePath('http://localhost:8080/data.json'), false);
    });

  });
}