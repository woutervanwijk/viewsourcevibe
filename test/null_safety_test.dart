import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/html_service.dart';

void main() {
  group('Null Safety Tests', () {
    test('HTML File model handles null properties safely', () {
      // Test that HTML file properties are properly initialized
      final htmlFile = HtmlFile(
        name: 'test.html',
        path: '/path/to/test.html',
        content: '<html></html>',
        lastModified: DateTime.now(),
        size: 1024,
      );

      // Test property access
      expect(htmlFile.name, 'test.html');
      expect(htmlFile.path, '/path/to/test.html');
      expect(htmlFile.content, '<html></html>');
      expect(htmlFile.size, 1024);
      expect(htmlFile.fileSize, '1.00 KB');
      expect(htmlFile.extension, 'html');
      expect(htmlFile.isHtml, true);
      expect(htmlFile.isTextBased, true);
    });

    test('HTML File fromContent factory works correctly', () {
      final htmlFile = HtmlFile.fromContent('test.txt', 'Hello World');

      expect(htmlFile.name, 'test.txt');
      expect(htmlFile.path, '');
      expect(htmlFile.content, 'Hello World');
      expect(htmlFile.size, 11); // 'Hello World' has 11 characters
      expect(htmlFile.fileSize, '11 bytes');
      expect(htmlFile.extension, 'txt');
      expect(htmlFile.isHtml, false);
    });

    test('HTML Service handles null files safely', () async {
      final htmlService = HtmlService();

      // Test initial state
      expect(htmlService.currentFile, null);

      // Test loading a file
      final testFile = HtmlFile(
        name: 'test.html',
        path: '/test.html',
        content: '<html></html>',
        lastModified: DateTime.now(),
        size: 100,
        isUrl: false,
      );

      await htmlService.loadFile(testFile);
      expect(htmlService.currentFile, testFile);

      // Test clearing file
      await htmlService.clearFile();
      expect(htmlService.currentFile, null);
    });

    test('Settings model handles null preferences safely', () {
      final settings = AppSettings();

      // Test default values without initialization
      expect(settings.darkMode, false);
      expect(settings.themeName, 'github');
      expect(settings.themeMode, ThemeModeOption.system);
      expect(settings.fontSize, 16.0);
      expect(settings.showLineNumbers, true);
      expect(settings.wrapText, false);

      // Test setting changes
      settings.darkMode = true;
      expect(settings.darkMode, true);

      settings.themeName = 'github-dark';
      expect(settings.themeName, 'github-dark');

      settings.themeMode = ThemeModeOption.dark;
      expect(settings.themeMode, ThemeModeOption.dark);
    });

    test('File size formatting handles edge cases', () {
      // Test zero bytes
      final emptyFile = HtmlFile(
        name: 'empty.txt',
        path: '/empty.txt',
        content: '',
        lastModified: DateTime.now(),
        size: 0,
        isUrl: false,
      );
      expect(emptyFile.fileSize, '0 bytes');

      // Test small file
      final smallFile = HtmlFile(
        name: 'small.txt',
        path: '/small.txt',
        content: 'Hi',
        lastModified: DateTime.now(),
        size: 2,
        isUrl: false,
      );
      expect(smallFile.fileSize, '2 bytes');

      // Test medium file (KB range)
      final mediumFile = HtmlFile(
        name: 'medium.txt',
        path: '/medium.txt',
        content: 'A' * 1500, // 1500 bytes
        lastModified: DateTime.now(),
        size: 1500,
        isUrl: false,
      );
      expect(mediumFile.fileSize, '1.46 KB');

      // Test large file (MB range)
      final largeFile = HtmlFile(
        name: 'large.txt',
        path: '/large.txt',
        content: 'A' * (2 * 1024 * 1024), // 2MB
        lastModified: DateTime.now(),
        size: 2 * 1024 * 1024,
        isUrl: false,
      );
      expect(largeFile.fileSize, '2.00 MB');
    });

    test('File extension detection handles edge cases', () {
      // Test file with no extension
      final noExtFile = HtmlFile(
        name: 'README',
        path: '/README',
        content: 'Read me',
        lastModified: DateTime.now(),
        size: 7,
        isUrl: false,
      );
      expect(noExtFile.extension, 'readme');
      expect(noExtFile.isHtml, false);

      // Test file with multiple dots
      final multiDotFile = HtmlFile(
        name: 'archive.tar.gz',
        path: '/archive.tar.gz',
        content: 'Compressed',
        lastModified: DateTime.now(),
        size: 10,
        isUrl: false,
      );
      expect(multiDotFile.extension, 'gz');
      expect(multiDotFile.isHtml, false);

      // Test HTML file variations
      final htmlFile = HtmlFile(
        name: 'index.html',
        path: '/index.html',
        content: '<html></html>',
        lastModified: DateTime.now(),
        size: 13,
        isUrl: false,
      );
      expect(htmlFile.isHtml, true);

      final htmFile = HtmlFile(
        name: 'index.htm',
        path: '/index.htm',
        content: '<html></html>',
        lastModified: DateTime.now(),
        size: 13,
        isUrl: false,
      );
      expect(htmFile.isHtml, true);

      // Test non-HTML file
      final txtFile = HtmlFile(
        name: 'document.txt',
        path: '/document.txt',
        content: 'Text content',
        lastModified: DateTime.now(),
        size: 12,
        isUrl: false,
      );
      expect(txtFile.isHtml, false);
    });
  });
}
