import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';

void main() {
  group('Content Type Selection Tests', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    test('getAvailableContentTypes returns non-empty list', () {
      final contentTypes = htmlService.getAvailableContentTypes();
      expect(contentTypes, isNotEmpty);
      expect(contentTypes, contains('xml')); // html is mapped to xml in re_highlight
      expect(contentTypes, contains('javascript'));
      expect(contentTypes, contains('plaintext'));
    });

    test('updateFileContentType preserves filename but updates selected content type', () async {
      // Load a sample file
      final sampleFile = HtmlFile(
        name: 'test.html',
        path: 'test.html',
        content: '<html><body>Test</body></html>',
        lastModified: DateTime.now(),
        size: 32,
        isUrl: false,
      );

      // Load the file (async)
      await htmlService.loadFile(sampleFile);

      // Verify initial state
      expect(htmlService.currentFile?.name, 'test.html');
      expect(htmlService.currentFile?.extension, 'html');
      expect(htmlService.selectedContentType, isNull); // No selected content type initially

      // Change content type to JavaScript
      htmlService.updateFileContentType('javascript');

      // Verify the filename is preserved but selected content type is updated
      expect(htmlService.currentFile?.name, 'test.html'); // Filename unchanged
      expect(htmlService.currentFile?.extension, 'html'); // Extension unchanged
      expect(htmlService.selectedContentType, 'javascript'); // Selected content type updated

      // Change content type to CSS
      htmlService.updateFileContentType('css');

      // Verify the filename is still preserved but selected content type is updated
      expect(htmlService.currentFile?.name, 'test.html'); // Filename unchanged
      expect(htmlService.currentFile?.extension, 'html'); // Extension unchanged
      expect(htmlService.selectedContentType, 'css'); // Selected content type updated
    });

    test('updateFileContentType with plaintext preserves filename but updates selected content type', () async {
      final sampleFile = HtmlFile(
        name: 'test.html',
        path: 'test.html',
        content: '<html><body>Test</body></html>',
        lastModified: DateTime.now(),
        size: 32,
        isUrl: false,
      );

      await htmlService.loadFile(sampleFile);
      htmlService.updateFileContentType('plaintext');

      // Verify filename is preserved but selected content type is updated
      expect(htmlService.currentFile?.name, 'test.html'); // Filename unchanged
      expect(htmlService.currentFile?.extension, 'html'); // Extension unchanged
      expect(htmlService.selectedContentType, 'plaintext'); // Selected content type updated
    });

    test('updateFileContentType preserves file content', () async {
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
      htmlService.updateFileContentType('javascript');

      expect(htmlService.currentFile?.content, content);
      expect(htmlService.currentFile?.size, content.length);
    });

    test('Automatic option reverts to original file and clears selected content type', () async {
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
      
      // Verify initial state
      expect(htmlService.currentFile?.name, 'test.html');
      expect(htmlService.currentFile?.extension, 'html');
      expect(htmlService.selectedContentType, isNull);

      // Change to JavaScript
      htmlService.updateFileContentType('javascript');
      expect(htmlService.currentFile?.name, 'test.html'); // Filename unchanged
      expect(htmlService.selectedContentType, 'javascript'); // Selected content type set

      // Revert to Automatic
      htmlService.updateFileContentType('automatic');
      expect(htmlService.currentFile?.name, 'test.html'); // Filename unchanged
      expect(htmlService.selectedContentType, isNull); // Selected content type cleared

      // Verify content is preserved
      expect(htmlService.currentFile?.content, content);
    });

    test('getAvailableContentTypes includes Automatic as first option', () {
      final contentTypes = htmlService.getAvailableContentTypes();
      expect(contentTypes, isNotEmpty);
      expect(contentTypes.first, 'automatic');
      expect(contentTypes, contains('javascript'));
      expect(contentTypes, contains('plaintext'));
    });
  });
}