import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HtmlService tab updates', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    test('loadFile should update all tab data', () async {
      // Create a test HTML file
      final testFile = HtmlFile(
        name: 'test.html',
        path: 'https://example.com',
        content: '<html><head><title>Test</title></head><body><h1>Hello</h1></body></html>',
        lastModified: DateTime.now(),
        size: 100,
        isUrl: true,
      );

      // Load the file
      await htmlService.loadFile(testFile);

      // Verify that currentFile is set
      expect(htmlService.currentFile, isNotNull);
      expect(htmlService.currentFile!.name, 'test.html');

      // Verify that metadata extraction was triggered (isExtractingMetadata should be false after completion)
      expect(htmlService.isExtractingMetadata, isFalse);

      // Verify that probe result is available (even if empty)
      expect(htmlService.probeResult, isNotNull);
    });

    test('loadFile should update cookies and metadata', () async {
      // Create a test HTML file
      final testFile = HtmlFile(
        name: 'test.html',
        path: 'https://example.com',
        content: '<html><head><title>Test</title></head><body><h1>Hello</h1></body></html>',
        lastModified: DateTime.now(),
        size: 100,
        isUrl: true,
      );

      // Load the file
      await htmlService.loadFile(testFile);

      // Verify that analyzed cookies are updated
      expect(htmlService.probeResult!['analyzedCookies'], isNotNull);

      // Verify that metadata is available
      expect(htmlService.pageMetadata, isNotNull);
    });

    test('probeUrl should complete without errors', () async {
      // Probe a URL
      await htmlService.probeUrl('https://example.com');

      // Verify that probe was attempted
      expect(htmlService.isProbing, isFalse);
    });
  });
}
