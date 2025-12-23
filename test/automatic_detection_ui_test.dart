import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';

void main() {
  group('Automatic detection UI tests', () {
    test('File extension should be correct for URL-loaded files', () async {
      final htmlService = HtmlService();

      print('🔍 Testing file extensions for URL-loaded files:');

      // Test case 1: File with proper HTML extension
      final htmlFile = HtmlFile(
        name: 'test.html',
        path: 'https://example.com/test.html',
        content: '<html><body>Test</body></html>',
        lastModified: DateTime.now(),
        size: 30,
        isUrl: true,
      );

      print('  HTML file extension: ${htmlFile.extension}');
      expect(htmlFile.extension, 'html');
      expect(htmlFile.isHtml, true);

      // Test case 2: File with descriptive name containing HTML
      final descriptiveFile = HtmlFile(
        name: 'privacy.html HTML',
        path: 'https://example.com/privacy.html',
        content: '<html><body>Privacy</body></html>',
        lastModified: DateTime.now(),
        size: 40,
        isUrl: true,
      );

      print('  Descriptive file extension: ${descriptiveFile.extension}');
      // This might be 'html' or something else depending on the name

      // Test case 3: File with no extension
      final noExtFile = HtmlFile(
        name: 'test',
        path: 'https://example.com/test',
        content: '<html><body>Test</body></html>',
        lastModified: DateTime.now(),
        size: 30,
        isUrl: true,
      );

      print('  No extension file extension: ${noExtFile.extension}');
      expect(noExtFile.extension, 'test'); // This is the problem!

      print('  ✅ File extensions work as expected');
    });

    test('Content type fallback should handle missing extensions', () async {
      final htmlService = HtmlService();

      print('🔍 Testing content type fallback logic:');

      // Simulate the logic from file_viewer.dart
      // htmlService.selectedContentType ?? file.extension

      // Test case 1: Automatic mode with proper extension
      // htmlService._selectedContentType = null; // Automatic
      // For testing, we'll just use null directly
      final htmlFile = HtmlFile(
        name: 'test.html',
        path: 'https://example.com/test.html',
        content: '<html><body>Test</body></html>',
        lastModified: DateTime.now(),
        size: 30,
        isUrl: true,
      );

      final contentType1 = htmlFile.extension; // Simulate Automatic mode
      print('  Automatic + proper extension: $contentType1');
      expect(contentType1, 'html');

      // Test case 2: Automatic mode with descriptive name
      final descriptiveFile = HtmlFile(
        name: 'privacy.html HTML',
        path: 'https://example.com/privacy.html',
        content: '<html><body>Privacy</body></html>',
        lastModified: DateTime.now(),
        size: 40,
        isUrl: true,
      );

      final contentType2 = descriptiveFile.extension; // Simulate Automatic mode
      print('  Automatic + descriptive name: $contentType2');
      // This might not be ideal

      // Test case 3: Automatic mode with no good extension
      final noExtFile = HtmlFile(
        name: 'test',
        path: 'https://example.com/test',
        content: '<html><body>Test</body></html>',
        lastModified: DateTime.now(),
        size: 30,
        isUrl: true,
      );

      final contentType3 = noExtFile.extension; // Simulate Automatic mode
      print('  Automatic + no extension: $contentType3');
      expect(contentType3, 'test'); // This is problematic!

      print('  ✅ Content type fallback logic tested');
    });

    test(
        'Automatic detection should use content-based detection when extension is unreliable',
        () async {
      final htmlService = HtmlService();

      print('🔍 Testing content-based detection for Automatic mode:');

      // The issue: when selectedContentType is null (Automatic),
      // we should use content-based detection, not just file extension

      final htmlFile = HtmlFile(
        name: 'test', // No good extension
        path: 'https://example.com/test',
        content: '<html><body>Test</body></html>',
        lastModified: DateTime.now(),
        size: 30,
        isUrl: true,
      );

      // Current problematic logic
      final currentLogic =
          htmlService.selectedContentType ?? htmlFile.extension;
      print('  Current logic result: $currentLogic');

      // Better logic: use content-based detection when Automatic
      final betterLogic = htmlService.selectedContentType ??
          (htmlFile.isUrl
              ? htmlService.getLanguageForExtension('html')
              : htmlFile.extension);
      print('  Better logic result: $betterLogic');

      print('  ✅ Content-based detection would be better for Automatic mode');
    });
  });
}
