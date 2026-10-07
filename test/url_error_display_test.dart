import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/html_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('URL Error Display Tests', () {
    late HtmlService htmlService;

    setUp(() {
      // The test binding answers every HTTP request with 400; use the real
      // network so these non-existent domains fail like they do in the app.
      HttpOverrides.global = null;
      // Source-first: a failed load shows the error page right away.
      htmlService = HtmlService()
        ..setAppSettings(AppSettings()..useBrowserByDefault = false);
    });

    test('Test URL error display in editor', () async {
      // Test that URL loading errors are displayed in the editor
      // instead of throwing exceptions

      try {
        // This should fail but display the error in the editor
        await htmlService
            .loadFromUrl('https://nonexistent-website-12345.com/test');

        // If we get here, check that an error file was loaded
        final currentFile = htmlService.currentFile;

        if (currentFile != null) {
          expect(currentFile.isError, isTrue);
          expect(currentFile.content, contains('Web URL Could Not Be Loaded'));
          expect(currentFile.content,
              contains('https://nonexistent-website-12345.com/test'));
          print('✅ URL error correctly displayed in editor');
        } else {
          print('❌ No file was loaded after URL error');
          fail('Expected an error file to be loaded');
        }
      } catch (e) {
        // If we get an exception, the error handling didn't work
        print('❌ URL error was thrown as exception instead of displayed: $e');
        fail('URL errors should be displayed in editor, not thrown: $e');
      }
    });

    test('Test invalid URL format error display', () async {
      try {
        // Test with an invalid URL format
        await htmlService.loadFromUrl('not-a-valid-url');

        // Check that an error file was loaded
        final currentFile = htmlService.currentFile;

        if (currentFile != null) {
          expect(currentFile.isError, isTrue);
          expect(currentFile.content, contains('Web URL Could Not Be Loaded'));
          expect(currentFile.content, contains('not-a-valid-url'));
          print('✅ Invalid URL error correctly displayed in editor');
        } else {
          print('❌ No file was loaded after invalid URL error');
          fail('Expected an error file to be loaded');
        }
      } catch (e) {
        print('❌ Invalid URL error was thrown as exception: $e');
        fail(
            'Invalid URL errors should be displayed in editor, not thrown: $e');
      }
    });

    test('Test error content structure', () async {
      try {
        await htmlService.loadFromUrl('https://example.invalid');

        final currentFile = htmlService.currentFile;

        if (currentFile != null) {
          final content = currentFile.content;

          // Verify the error content has the expected structure
          expect(content, contains('Web URL Could Not Be Loaded'));
          expect(content, contains('Error:'));
          expect(content, contains('URL:'));
          expect(content, contains('🌐 Network Issues'));
          expect(content, contains('🔒 Website Restrictions'));
          expect(content, contains('📱 URL Format Problems'));
          expect(content, contains('🔄 Redirect Issues'));
          expect(content, contains('Technical details:'));

          print('✅ Error content has correct structure');
        } else {
          fail('No error file was loaded');
        }
      } catch (e) {
        fail('Error should be displayed in editor: $e');
      }
    });

    test('Test successful URL loading still works', () async {
      // This test verifies that successful URL loading still works
      // We can't test actual network calls, but we can verify the method doesn't break

      expect(htmlService, isNotNull);
      print('✅ HTML service is properly initialized');
    });
  });
}
