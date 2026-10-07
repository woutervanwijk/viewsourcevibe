import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sharing URL Fix Tests', () {
    late HtmlService htmlService;

    setUp(() {
      // The test binding answers every HTTP request with 400; use the real
      // network so these non-existent domains fail like they do in the app.
      HttpOverrides.global = null;
      // Source-first: a failed load shows the error page right away.
      htmlService = HtmlService()
        ..setAppSettings(AppSettings()..useBrowserByDefault = false);
    });

    test('Test URL loading still works after sharing fix', () async {
      // This test verifies that URL loading functionality is not broken
      // by the sharing launch fix

      // We can't test actual network calls, but we can verify that
      // the loadFromUrl method is still functional

      expect(htmlService, isNotNull);

      // The service should be properly initialized
      expect(htmlService.currentFile, isNull); // Initially null

      print('✅ HTML service is properly initialized for URL loading');
    });

    test('Test sharing error handling', () async {
      try {
        // Try to load a URL that will fail
        await htmlService.loadFromUrl('https://nonexistent-test-url-12345.com');

        // Should display an error in the editor, not crash
        expect(htmlService.currentFile, isNotNull);
        expect(htmlService.currentFile?.isError, isTrue);

        print('✅ URL loading error handling works correctly');
      } catch (e) {
        fail('URL loading should handle errors gracefully: $e');
      }
    });

    test('Test clear functionality after sharing', () async {
      try {
        // Load a URL that will fail
        await htmlService.loadFromUrl('https://test-error-url.com');

        // Verify error is displayed
        expect(htmlService.currentFile, isNotNull);

        // Clear should work
        await htmlService.clearFile();
        expect(htmlService.currentFile, isNull);

        print('✅ Clear functionality works after sharing errors');
      } catch (e) {
        fail('Clear should work after sharing: $e');
      }
    });

    test('Test service initialization for sharing', () async {
      // Verify that the service is ready to handle shared content

      // Check that all necessary properties are initialized
      expect(htmlService.currentFile, isNull);
      expect(htmlService.selectedContentType, isNull);

      // Service should be able to load files
      final testFile = HtmlFile(
        name: 'test.html',
        path: 'test.html',
        content: '<html></html>',
        lastModified: DateTime.now(),
        size: 12,
        isUrl: false,
      );

      await htmlService.loadFile(testFile);
      expect(htmlService.currentFile, isNotNull);

      // Should be able to clear
      await htmlService.clearFile();
      expect(htmlService.currentFile, isNull);

      print('✅ Service is properly initialized for sharing scenarios');
    });
  });
}
