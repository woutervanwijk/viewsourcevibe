import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/unified_sharing_service.dart';

void main() {
  sharedTextUrlTests();
  group('UnifiedSharingService URL Detection Tests', () {
    test('Should detect URLs in shared text content', () async {
      // Test that URLs shared as text content are properly detected
      final testCases = [
        {
          'type': 'text',
          'content': 'https://example.com/Users/profile',
          'shouldBeUrl': true,
          'reason': 'URL with Users path segment'
        },
        {
          'type': 'text',
          'content': 'https://example.com/Library/docs',
          'shouldBeUrl': true,
          'reason': 'URL with Library path segment'
        },
        {
          'type': 'text',
          'content': 'https://example.com/Applications/web',
          'shouldBeUrl': true,
          'reason': 'URL with Applications path segment'
        },
        {
          'type': 'text',
          'content': 'https://example.com/Containers/data',
          'shouldBeUrl': true,
          'reason': 'URL with Containers path segment'
        },
        {
          'type': 'text',
          'content': 'https://example.com',
          'shouldBeUrl': true,
          'reason': 'Simple URL'
        },
        {
          'type': 'text',
          'content': 'Hello World',
          'shouldBeUrl': false,
          'reason': 'Plain text'
        },
        {
          'type': 'text',
          'content': '/Users/test/file.html',
          'shouldBeUrl': false,
          'reason': 'File path'
        },
        {
          'type': 'text',
          'content': 'example.com',
          'shouldBeUrl': false,
          'reason': 'URL without scheme'
        },
      ];

      for (final testCase in testCases) {
        final content = testCase['content'] as String;
        final shouldBeUrl = testCase['shouldBeUrl'] as bool;
        final reason = testCase['reason'] as String;

        // Test the isUrl method directly
        final isUrlResult = UnifiedSharingService.isUrl(content);
        expect(isUrlResult, shouldBeUrl,
            reason: 'isUrl should return $shouldBeUrl for: $reason');

        // Print debug info
        // Debug info removed to avoid print statements in production code
        // print('Testing: $content (type: $type) -> isUrl: $isUrlResult, expected: $shouldBeUrl');
      }
    });

    test('Should handle the specific failing case from logs', () async {
      // This test simulates the exact scenario from the logs:
      // "flutter: UnifiedSharingService: Received new shared content via method channel"
      // "flutter: UnifiedSharingService: Handling shared content of type: text"
      // "flutter: UnifiedSharingService: Handling shared text (45 characters)"
      // "flutter: url shared://text"

      // The issue was that a URL was being shared as text content
      // and not being detected as a URL

      final problematicUrl = 'https://example.com/some/path/with/Users';

      // Test that this URL is detected correctly
      expect(UnifiedSharingService.isUrl(problematicUrl), true,
          reason: 'Should detect URL with Users path segment');

      // Test with shared data that would come from the method channel
      final sharedData = {
        'type': 'text',
        'content': problematicUrl,
      };

      // The isUrl method should correctly identify this as a URL
      final content = sharedData['content'] as String;
      final isUrlResult = UnifiedSharingService.isUrl(content);

      expect(isUrlResult, true,
          reason: 'Shared text content should be detected as URL');

      // Debug info removed to avoid print statements in production code
      // print('Problematic URL test: $problematicUrl -> isUrl: $isUrlResult');
    });
  });
}

// B24: shared text is a URL only when the whole trimmed text is one URL.
void sharedTextUrlTests() {
  group('urlFromSharedText (B24)', () {
    test('whole text is exactly one http(s) URL -> URL', () {
      expect(
          UnifiedSharingService.urlFromSharedText(
              '  https://example.com/a?b=c \n'),
          'https://example.com/a?b=c');
      expect(UnifiedSharingService.urlFromSharedText('http://example.com'),
          'http://example.com');
    });

    test('plain host without scheme is still a URL', () {
      expect(UnifiedSharingService.urlFromSharedText('example.com'),
          'example.com');
      expect(UnifiedSharingService.urlFromSharedText('www.example.org/x'),
          'www.example.org/x');
    });

    test('HTML that merely contains a URL stays text', () {
      expect(
          UnifiedSharingService.urlFromSharedText(
              '<a href="https://example.com">x</a>'),
          isNull);
      expect(
          UnifiedSharingService.urlFromSharedText(
              'see https://example.com now'),
          isNull);
      expect(
          UnifiedSharingService.urlFromSharedText(
              'https://a.com https://b.com'),
          isNull);
    });

    test('minified CSS/JS stays content', () {
      expect(UnifiedSharingService.urlFromSharedText('a{b:c}.d{e:f}'), isNull);
      expect(
          UnifiedSharingService.urlFromSharedText('var a=b.c(d.e);'), isNull);
      expect(
          UnifiedSharingService.urlFromSharedText(
              'some.long.dotted.identifier'),
          isNull);
    });
  });
}
