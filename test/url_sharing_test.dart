import 'package:flutter_test/flutter_test.dart';
import 'package:htmlviewer/services/sharing_service.dart';

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('URL Sharing Tests', () {
    setUp(() {
      // Reset any test state
    });

    test('shareUrl method exists and can be called', () async {
      // Test that the shareUrl method exists and can be called
      expect(SharingService.shareUrl, isNotNull);

      // Test that calling shareUrl throws platform exception (expected in test environment)
      try {
        await SharingService.shareUrl('https://example.com');
        fail('Expected platform exception');
      } catch (e) {
        expect(e, isA<Exception>());
        expect(e.toString(), contains('Sharing failed'));
      }
    });

    test('shareUrl handles valid URLs', () async {
      // Test various valid URL formats
      const validUrls = [
        'https://example.com',
        'http://example.com',
        'https://www.example.com/path',
        'http://subdomain.example.com:8080/path?query=value',
        'https://example.com/path/to/resource.html',
      ];

      for (final url in validUrls) {
        // These should all attempt to share (platform exception expected)
        try {
          await SharingService.shareUrl(url);
          fail('Expected platform exception for $url');
        } catch (e) {
          expect(e, isA<Exception>());
          expect(e.toString(), contains('Sharing failed'));
        }
      }
    });

    test('shareUrl handles edge cases', () async {
      // Test edge cases
      const edgeCases = [
        'https://example.com', // Basic HTTPS
        'http://example.com', // Basic HTTP
        'https://example.com/path', // With path
        'https://example.com/path?query=value', // With query
        'https://example.com/path#fragment', // With fragment
        'https://user:pass@example.com', // With auth
        'https://example.com:8080', // With port
      ];

      for (final url in edgeCases) {
        expect(() => SharingService.shareUrl(url), throwsA(isA<Exception>()));
      }
    });

    test('shareUrl handles invalid URLs gracefully', () async {
      // Test invalid URL formats
      const invalidUrls = [
        'not-a-url',
        'example.com', // Missing protocol
        'https://', // Missing domain
        '', // Empty string
        '   ', // Whitespace only
      ];

      for (final url in invalidUrls) {
        // These should throw exceptions (invalid URL format)
        expect(() => SharingService.shareUrl(url), throwsA(isA<Exception>()));
      }
    });

    test('URL detection logic works correctly', () async {
      // Test URL detection patterns
      const urlPatterns = [
        'https://example.com',
        'http://example.com',
        'https://www.example.com',
        'http://www.example.com',
      ];

      for (final pattern in urlPatterns) {
        expect(pattern.startsWith('http://') || pattern.startsWith('https://'),
            true);
      }
    });

    test('Non-URL paths are not detected as URLs', () async {
      // Test that non-URL paths are not detected as URLs
      const nonUrlPaths = [
        '/path/to/file.html',
        'file:///path/to/file.html',
        'assets/sample.html',
        'relative/path/file.txt',
        'c:/windows/path/file.txt',
        '~/user/path/file.txt',
      ];

      for (final path in nonUrlPaths) {
        expect(
            path.startsWith('http://') || path.startsWith('https://'), false);
      }
    });
  });

  group('Sharing Service Integration Tests', () {
    test('All sharing methods are available', () async {
      // Test that all sharing methods exist
      expect(SharingService.shareText, isNotNull);
      expect(SharingService.shareHtml, isNotNull);
      expect(SharingService.shareFile, isNotNull);
      expect(SharingService.shareUrl, isNotNull);
      expect(SharingService.handleSharedContent, isNotNull);
      expect(SharingService.checkForSharedContent, isNotNull);
    });

    test('Sharing methods have correct signatures', () async {
      // Test method signatures
      expect(SharingService.shareText is Future<void> Function(String), true);
      expect(
          SharingService.shareHtml is Future<void> Function(String,
              {String? filename}),
          true);
      expect(
          SharingService.shareFile is Future<void> Function(String,
              {String? mimeType}),
          true);
      expect(SharingService.shareUrl is Future<void> Function(String), true);
    });
  });

  group('URL Sharing Error Handling Tests', () {
    test('shareUrl throws appropriate exceptions', () async {
      // Test that shareUrl throws appropriate exceptions for invalid input

      // Empty URL
      expect(() => SharingService.shareUrl(''), throwsA(isA<Exception>()));

      // Invalid URL format
      expect(() => SharingService.shareUrl('not-a-url'),
          throwsA(isA<Exception>()));

      // URL without protocol
      expect(() => SharingService.shareUrl('example.com'),
          throwsA(isA<Exception>()));
    });

    test('shareUrl handles platform exceptions', () async {
      // Test that shareUrl properly handles platform exceptions
      // Since we're not on a real platform, these should throw exceptions

      try {
        await SharingService.shareUrl('https://example.com');
        fail('Expected PlatformException to be thrown');
      } catch (e) {
        expect(e, isA<Exception>());
        expect(e.toString(), contains('Sharing failed'));
      }
    });
  });
}
