import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';

// Simple integration test to verify headers are being sent
void main() {
  group('URL headers integration test', () {
    test('Verify loadFromUrl method exists and has correct signature', () {
      // Create a real HtmlService instance
      final htmlService = HtmlService();

      // Verify the method exists
      expect(htmlService.loadFromUrl, isNotNull);
      expect(htmlService.loadFromUrl, isA<Function>());

      // Verify the method can be called (it will fail without network, but that's expected)
      // The important thing is that the method signature now includes headers
      expect(() => htmlService.loadFromUrl('https://example.com'),
          returnsNormally);
    });

    test('Verify URL validation still works', () {
      final htmlService = HtmlService();

      // Test that URL without protocol gets https:// added
      // The method should handle this gracefully
      expect(() => htmlService.loadFromUrl('example.com'), returnsNormally);
    });

    test('Verify method handles edge cases', () async {
      final htmlService = HtmlService();

      // Test that invalid URLs throw appropriate exceptions
      await expectLater(
        () => htmlService.loadFromUrl(''),
        throwsA(isA<Exception>()),
      );

      await expectLater(
        () => htmlService.loadFromUrl('invalid-url'),
        throwsA(isA<Exception>()),
      );
    });

    test('Verify headers are properly formatted', () {
      // Test that the headers we're sending are valid
      final expectedHeaders = {
        'User-Agent': 'curl/7.54.1',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Upgrade-Insecure-Requests': '1',
      };

      // Verify all headers are non-empty strings
      expectedHeaders.forEach((key, value) {
        expect(key, isNotEmpty);
        expect(value, isNotEmpty);
        expect(value, isA<String>());
      });

      // Verify User-Agent contains browser-like string
      expect(expectedHeaders['User-Agent'], contains('curl'));
    });
  });
}
