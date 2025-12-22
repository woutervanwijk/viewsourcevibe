import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';

void main() {
  group('Content Type Selection Unit Tests', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    test('Content type menu shows available types', () {
      final availableTypes = htmlService.getAvailableContentTypes();
      expect(availableTypes, isNotEmpty);
      expect(availableTypes.length, greaterThan(20)); // Should have many content types
    });

    test('Content type update preserves filename but updates selected content type', () async {
      // This tests the core functionality of content type selection
      final sampleFile = HtmlFile(
        name: 'test.html',
        path: 'test.html',
        content: '<html><body>Test</body></html>',
        lastModified: DateTime.now(),
        size: 32,
        isUrl: false,
      );

      await htmlService.loadFile(sampleFile);
      
      // Verify initial state
      expect(htmlService.currentFile?.name, 'test.html');
      expect(htmlService.selectedContentType, isNull);
      
      // Change to JavaScript
      htmlService.updateFileContentType('javascript');
      expect(htmlService.currentFile?.name, 'test.html'); // Filename unchanged
      expect(htmlService.selectedContentType, 'javascript'); // Selected content type updated
      
      // Change to CSS
      htmlService.updateFileContentType('css');
      expect(htmlService.currentFile?.name, 'test.html'); // Filename unchanged
      expect(htmlService.selectedContentType, 'css'); // Selected content type updated
      
      // Change to plaintext
      htmlService.updateFileContentType('plaintext');
      expect(htmlService.currentFile?.name, 'test.html'); // Filename unchanged
      expect(htmlService.selectedContentType, 'plaintext'); // Selected content type updated
    });

    test('Content type update preserves file content', () async {
      final content = '<html><body>Test Content</body></html>';
      final sampleFile = HtmlFile(
        name: 'test.html',
        path: 'test.html',
        content: content,
        lastModified: DateTime.now(),
        size: content.length,
        isUrl: false,
      );

      await htmlService.loadFile(sampleFile);
      
      // Verify initial content
      expect(htmlService.currentFile?.content, content);
      
      // Change content type
      htmlService.updateFileContentType('javascript');
      
      // Verify content is preserved
      expect(htmlService.currentFile?.content, content);
      expect(htmlService.currentFile?.size, content.length);
    });
  });
}