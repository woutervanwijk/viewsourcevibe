import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/sharing_service.dart';

void main() {
  group('URL Detection Edge Cases Tests', () {
    
    test('Should detect URLs that might be confused with file paths', () async {
      // Test URLs that contain path-like segments that might trigger false negatives
      final testCases = [
        'https://example.com/Users/profile',
        'https://example.com/Library/docs', 
        'https://example.com/Applications/web',
        'https://example.com/Containers/data',
        'https://example.com/file.html',
        'https://example.com/path/to/file.html',
        'https://example.com/var/mobile/content',
        'https://example.com/private/content',
        'https://example.com/Documents/report.pdf',
        'https://example.com/Downloads/software.dmg',
        'https://example.com/Desktop/wallpaper.jpg',
      ];

      for (final url in testCases) {
        expect(SharingService.isUrl(url), true, reason: 'Should detect $url as URL');
      }
    });

    test('Should not detect actual file paths as URLs', () async {
      // Test actual file paths that should NOT be detected as URLs
      final filePaths = [
        '/Users/test/file.html',
        '/Library/Application Support/app/data.txt',
        '/Applications/App.app/Contents/Resources/config.json',
        '/var/mobile/Containers/Data/Application/temp/cache.html',
        '/private/var/mobile/Containers/Data/Application/app/Documents/doc.txt',
        '/var/mobile/Containers/Bundle/Application/app.app/file.js',
        'file:///Users/test/file.html',
        'file:///var/mobile/Containers/Data/Application/temp/file.css',
      ];

      for (final filePath in filePaths) {
        expect(SharingService.isUrl(filePath), false, reason: 'Should NOT detect $filePath as URL');
      }
    });

    test('Should handle URLs with special characters', () async {
      // Test URLs with special characters that might cause issues
      final urlsWithSpecialChars = [
        'https://example.com/path-with-dashes',
        'https://example.com/path_with_underscores',
        'https://example.com/path/with/dots.html',
        'https://example.com/path%20with%20spaces',
        'https://example.com/path?query=value&other=test',
        'https://example.com/path#fragment',
        'https://example.com/path?query=value#fragment',
        'https://user:password@example.com/secure',
        'https://example.com:8080/port',
      ];

      for (final url in urlsWithSpecialChars) {
        expect(SharingService.isUrl(url), true, reason: 'Should detect $url as URL');
      }
    });

    test('Should handle edge cases with mixed patterns', () async {
      // Test edge cases that might confuse the detection logic
      final edgeCases = [
        // These should be URLs
        'https://example.com/Users/profile.html',
        'https://example.com/Library/docs.pdf',
        'https://example.com/Applications/web/index.html',
        'https://example.com/Containers/data/file.js',
        
        // These should NOT be URLs (file paths)
        '/Users/test/Applications/web/index.html',
        '/Library/Application Support/Containers/data/file.js',
        'file:///Users/test/Library/docs.pdf',
      ];

      // Test URLs (should be true)
      expect(SharingService.isUrl('https://example.com/Users/profile.html'), true);
      expect(SharingService.isUrl('https://example.com/Library/docs.pdf'), true);
      expect(SharingService.isUrl('https://example.com/Applications/web/index.html'), true);
      expect(SharingService.isUrl('https://example.com/Containers/data/file.js'), true);

      // Test file paths (should be false)
      expect(SharingService.isUrl('/Users/test/Applications/web/index.html'), false);
      expect(SharingService.isUrl('/Library/Application Support/Containers/data/file.js'), false);
      expect(SharingService.isUrl('file:///Users/test/Library/docs.pdf'), false);
    });

  });
}