import 'package:flutter_test/flutter_test.dart';
import 'package:htmlviewer/models/html_file.dart';
import 'package:htmlviewer/services/html_service.dart';

void main() {
  group('File Loading Tests', () {
    test('HTML Service loads files correctly', () {
      final htmlService = HtmlService();

      // Test initial state
      expect(htmlService.currentFile, null);

      // Test loading a file
      final testFile = HtmlFile(
        name: 'test.html',
        path: '/test.html',
        content: '<html><body>Hello World</body></html>',
        lastModified: DateTime.now(),
        size: 38,
      );

      htmlService.loadFile(testFile);
      expect(htmlService.currentFile, testFile);
      expect(htmlService.currentFile?.name, 'test.html');
      expect(htmlService.currentFile?.content,
          '<html><body>Hello World</body></html>');
      expect(htmlService.currentFile?.size, 38);
    });

    test('HTML Service clears files correctly', () {
      final htmlService = HtmlService();

      // Load a file first
      final testFile = HtmlFile(
        name: 'test.html',
        path: '/test.html',
        content: '<html></html>',
        lastModified: DateTime.now(),
        size: 13,
      );

      htmlService.loadFile(testFile);
      expect(htmlService.currentFile, isNotNull);

      // Clear the file
      htmlService.clearFile();
      expect(htmlService.currentFile, null);
    });

    test('File content handling with empty content', () {
      // Test file with empty content
      final emptyFile = HtmlFile(
        name: 'empty.txt',
        path: '/empty.txt',
        content: '',
        lastModified: DateTime.now(),
        size: 0,
      );

      expect(emptyFile.content, '');
      expect(emptyFile.size, 0);
      expect(emptyFile.fileSize, '0 bytes');
    });

    test('File content handling with various content types', () {
      // Test HTML content
      final htmlFile = HtmlFile(
        name: 'index.html',
        path: '/index.html',
        content:
            '<!DOCTYPE html><html><head><title>Test</title></head><body><h1>Hello</h1></body></html>',
        lastModified: DateTime.now(),
        size: 70,
      );

      expect(htmlFile.content.contains('<html>'), true);
      expect(htmlFile.content.contains('</html>'), true);
      expect(htmlFile.isHtml, true);

      // Test plain text content
      final textFile = HtmlFile(
        name: 'readme.txt',
        path: '/readme.txt',
        content: 'This is a readme file with some text content.',
        lastModified: DateTime.now(),
        size: 42,
      );

      expect(textFile.content, 'This is a readme file with some text content.');
      expect(textFile.isHtml, false);
    });

    test('File loading with different file sizes', () async {
      // Test loading a small file
      final smallFile = HtmlFile(
        name: 'small.txt',
        path: '/small.txt',
        content: 'A',
        lastModified: DateTime.now(),
        size: 1,
      );

      expect(smallFile.fileSize, '1 bytes');

      // Test loading a medium file (KB range)
      final mediumFile = HtmlFile(
        name: 'medium.txt',
        path: '/medium.txt',
        content: 'A' * 1500, // 1500 bytes
        lastModified: DateTime.now(),
        size: 1500,
      );

      expect(mediumFile.fileSize, '1.46 KB');

      // Test loading a large file (MB range)
      final largeFile = HtmlFile(
        name: 'large.txt',
        path: '/large.txt',
        content: 'A' * (2 * 1024 * 1024), // 2MB
        lastModified: DateTime.now(),
        size: 2 * 1024 * 1024,
      );

      expect(largeFile.fileSize, '2.00 MB');
    });

    test('File extension detection for various file types', () {
      // Test HTML files
      final htmlFile = HtmlFile(
        name: 'index.html',
        path: '/index.html',
        content: '<html></html>',
        lastModified: DateTime.now(),
        size: 13,
      );
      expect(htmlFile.extension, 'html');
      expect(htmlFile.isHtml, true);

      // Test HTM files
      final htmFile = HtmlFile(
        name: 'index.htm',
        path: '/index.htm',
        content: '<html></html>',
        lastModified: DateTime.now(),
        size: 13,
      );
      expect(htmFile.extension, 'htm');
      expect(htmFile.isHtml, true);

      // Test other file types
      final cssFile = HtmlFile(
        name: 'styles.css',
        path: '/styles.css',
        content: 'body { color: red; }',
        lastModified: DateTime.now(),
        size: 19,
      );
      expect(cssFile.extension, 'css');
      expect(cssFile.isHtml, false);
      expect(cssFile.isTextBased, true);

      // Test non-text files (should not be text-based)
      final pngFile = HtmlFile(
        name: 'image.png',
        path: '/image.png',
        content: '',
        lastModified: DateTime.now(),
        size: 0,
      );
      expect(pngFile.extension, 'png');
      expect(pngFile.isHtml, false);
      expect(pngFile.isTextBased, false);
    });

    test('File path handling with different path formats', () {
      // Test absolute paths
      final absoluteFile = HtmlFile(
        name: 'test.html',
        path: '/Users/test/Documents/test.html',
        content: '<html></html>',
        lastModified: DateTime.now(),
        size: 13,
      );
      expect(absoluteFile.path, '/Users/test/Documents/test.html');

      // Test relative paths
      final relativeFile = HtmlFile(
        name: 'test.html',
        path: './test.html',
        content: '<html></html>',
        lastModified: DateTime.now(),
        size: 13,
      );
      expect(relativeFile.path, './test.html');

      // Test empty paths
      final emptyPathFile = HtmlFile(
        name: 'test.html',
        path: '',
        content: '<html></html>',
        lastModified: DateTime.now(),
        size: 13,
      );
      expect(emptyPathFile.path, '');
    });
  });
}
