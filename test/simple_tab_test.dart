import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Simple tab functionality tests', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    test('HTML file loading populates metadata', () async {
      // Load a test file
      final testFile = HtmlFile(
        name: 'test.html',
        path: 'https://example.com',
        content: '<html><head><title>Test Page</title></head><body><h1>Hello World</h1></body></html>',
        lastModified: DateTime.now(),
        size: 100,
        isUrl: true,
      );

      await htmlService.loadFile(testFile);

      // Wait a bit for metadata extraction
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify that metadata is available
      expect(htmlService.pageMetadata, isNotNull);
      expect(htmlService.pageMetadata!['title'], 'Test Page');
    });

    test('Loading states are properly managed', () async {
      // Initially should not be loading
      expect(htmlService.isLoading, isFalse);
      expect(htmlService.isWebViewLoading, isFalse);
      expect(htmlService.isExtractingMetadata, isFalse);

      // Load a file
      final testFile = HtmlFile(
        name: 'test.html',
        path: 'https://example.com',
        content: '<html><head><title>Test</title></head><body><p>Test</p></body></html>',
        lastModified: DateTime.now(),
        size: 50,
        isUrl: true,
      );

      // Loading should start
      await htmlService.loadFile(testFile);

      // After loading, states should be reset
      await Future.delayed(const Duration(milliseconds: 500));

      expect(htmlService.isLoading, isFalse);
      expect(htmlService.isWebViewLoading, isFalse);
      expect(htmlService.isExtractingMetadata, isFalse);
    });

    test('Probe result is available after loading', () async {
      final testFile = HtmlFile(
        name: 'test.html',
        path: 'https://example.com',
        content: '<html><head><title>Test</title></head><body><p>Test</p></body></html>',
        lastModified: DateTime.now(),
        size: 50,
        isUrl: true,
      );

      await htmlService.loadFile(testFile);

      // Probe result should be available
      expect(htmlService.probeResult, isNotNull);
      expect(htmlService.probeResult!['analyzedCookies'], isNotNull);
    });
  });
}
