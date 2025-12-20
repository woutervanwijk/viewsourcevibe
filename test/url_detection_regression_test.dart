import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/sharing_service.dart';
import 'package:view_source_vibe/services/unified_sharing_service.dart';

void main() {
  group('URL Detection Regression Tests', () {
    
    test('Should correctly detect URLs that were previously misclassified as file paths', () async {
      // These are the types of URLs that were failing before the fix
      final problematicUrls = [
        'https://example.com/Users/profile',
        'https://example.com/Library/docs',
        'https://example.com/Applications/web',
        'https://example.com/Containers/data',
        'https://example.com/Users/profile.html',
        'https://example.com/Library/docs.pdf',
        'https://example.com/Applications/web/index.html',
        'https://example.com/Containers/data/file.js',
        'https://example.com/var/mobile/content',
        'https://example.com/private/content',
        'https://example.com/Documents/report.pdf',
        'https://example.com/Downloads/software.dmg',
        'https://example.com/Desktop/wallpaper.jpg',
      ];

      for (final url in problematicUrls) {
        // Test both sharing services
        expect(SharingService.isUrl(url), true, reason: 'SharingService should detect $url as URL');
        expect(UnifiedSharingService.isUrl(url), true, reason: 'UnifiedSharingService should detect $url as URL');
      }
    });

    test('Should still correctly reject actual file paths', () async {
      // These should still be detected as file paths, not URLs
      final actualFilePaths = [
        '/Users/test/file.html',
        '/Library/Application Support/app/data.txt',
        '/Applications/App.app/Contents/Resources/config.json',
        '/var/mobile/Containers/Data/Application/temp/cache.html',
        'file:///Users/test/file.html',
        'file:///var/mobile/Containers/Data/Application/temp/file.css',
      ];

      for (final filePath in actualFilePaths) {
        // Test both sharing services
        expect(SharingService.isUrl(filePath), false, reason: 'SharingService should NOT detect $filePath as URL');
        expect(UnifiedSharingService.isUrl(filePath), false, reason: 'UnifiedSharingService should NOT detect $filePath as URL');
      }
    });

    test('Should handle edge cases correctly', () async {
      // Test edge cases that might be ambiguous
      final edgeCases = [
        // These should be URLs
        {'text': 'https://example.com/Users/profile.html', 'shouldBeUrl': true},
        {'text': 'https://example.com/Library/docs.pdf', 'shouldBeUrl': true},
        {'text': 'https://example.com/Applications/web/index.html', 'shouldBeUrl': true},
        {'text': 'https://example.com/Containers/data/file.js', 'shouldBeUrl': true},
        
        // These should NOT be URLs (file paths)
        {'text': '/Users/test/Applications/web/index.html', 'shouldBeUrl': false},
        {'text': '/Library/Application Support/Containers/data/file.js', 'shouldBeUrl': false},
        {'text': 'file:///Users/test/Library/docs.pdf', 'shouldBeUrl': false},
        
        // These should be URLs (no path-like segments)
        {'text': 'https://example.com', 'shouldBeUrl': true},
        {'text': 'http://example.com/path/to/page', 'shouldBeUrl': true},
        {'text': 'https://sub.example.com/page?param=value', 'shouldBeUrl': true},
        
        // These should NOT be URLs (not HTTP/HTTPS)
        {'text': 'example.com', 'shouldBeUrl': false},
        {'text': 'www.example.com', 'shouldBeUrl': false},
        {'text': 'ftp://example.com', 'shouldBeUrl': false},
        {'text': 'Hello World', 'shouldBeUrl': false},
      ];

      for (final testCase in edgeCases) {
        final text = testCase['text'] as String;
        final shouldBeUrl = testCase['shouldBeUrl'] as bool;
        
        expect(SharingService.isUrl(text), shouldBeUrl, reason: 'SharingService: $text should ${shouldBeUrl ? '' : 'NOT '}be URL');
        expect(UnifiedSharingService.isUrl(text), shouldBeUrl, reason: 'UnifiedSharingService: $text should ${shouldBeUrl ? '' : 'NOT '}be URL');
      }
    });

  });
}