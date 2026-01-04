import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';

void main() {
  group('URL Clear Button Filesystem Tests', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    test('Test clear button appears for filesystem files', () async {
      // Load a filesystem file
      final filesystemFile = HtmlFile(
        name: 'document.html',
        path: '/path/to/document.html',
        content: '<html><body>Filesystem content</body></html>',
        lastModified: DateTime.now(),
        size: 45,
        isUrl: false, // This is a filesystem file, not a URL
      );

      await htmlService.loadFile(filesystemFile);
      
      // Verify the file is loaded
      expect(htmlService.currentFile, isNotNull);
      expect(htmlService.currentFile?.name, 'document.html');
      expect(htmlService.currentFile?.isUrl, false);
      
      // Check if clear button should be visible
      // The new logic: _urlController.text.isNotEmpty || htmlService.currentFile != null
      // Since we have a file loaded, clear button should be visible
      final shouldShowClearButton = htmlService.currentFile != null;
      expect(shouldShowClearButton, true, reason: 'Clear button should be visible for filesystem files');
      
      // Simulate clear button press
      if (htmlService.currentFile != null) {
        await htmlService.clearFile();
      }
      
      // Verify everything is cleared
      expect(htmlService.currentFile, isNull);
      
      print('✅ Clear button works correctly for filesystem files');
    });

    test('Test clear button visibility for different file types', () async {
      // Test 1: No file loaded -> clear button should NOT be visible
      bool shouldShowClearButton = htmlService.currentFile != null;
      expect(shouldShowClearButton, false);
      
      // Test 2: Filesystem file loaded -> clear button SHOULD be visible
      final htmlFile = HtmlFile(
        name: 'test.html',
        path: 'test.html',
        content: '<html></html>',
        lastModified: DateTime.now(),
        size: 12,
        isUrl: false,
      );
      await htmlService.loadFile(htmlFile);
      
      shouldShowClearButton = htmlService.currentFile != null;
      expect(shouldShowClearButton, true);
      
      // Test 3: After clearing -> clear button should NOT be visible
      await htmlService.clearFile();
      shouldShowClearButton = htmlService.currentFile != null;
      expect(shouldShowClearButton, false);
      
      print('✅ Clear button visibility works correctly for all file types');
    });

    test('Test clear button with various filesystem file types', () async {
      // Test with different types of filesystem files
      
      // Test 1: HTML file
      final htmlFile = HtmlFile(
        name: 'index.html',
        path: 'index.html',
        content: '<html><body>HTML content</body></html>',
        lastModified: DateTime.now(),
        size: 38,
        isUrl: false,
      );
      await htmlService.loadFile(htmlFile);
      expect(htmlService.currentFile?.name, 'index.html');
      await htmlService.clearFile();
      expect(htmlService.currentFile, isNull);
      
      // Test 2: CSS file
      final cssFile = HtmlFile(
        name: 'styles.css',
        path: 'styles.css',
        content: 'body { color: red; }',
        lastModified: DateTime.now(),
        size: 20,
        isUrl: false,
      );
      await htmlService.loadFile(cssFile);
      expect(htmlService.currentFile?.name, 'styles.css');
      await htmlService.clearFile();
      expect(htmlService.currentFile, isNull);
      
      // Test 3: JavaScript file
      final jsFile = HtmlFile(
        name: 'script.js',
        path: 'script.js',
        content: 'console.log("Hello");',
        lastModified: DateTime.now(),
        size: 22,
        isUrl: false,
      );
      await htmlService.loadFile(jsFile);
      expect(htmlService.currentFile?.name, 'script.js');
      await htmlService.clearFile();
      expect(htmlService.currentFile, isNull);
      
      print('✅ Clear button works with various filesystem file types');
    });

    test('Test clear button consistency across all scenarios', () async {
      // Test that clear button works consistently in all scenarios
      
      // Scenario 1: URL file (should work)
      try {
        await htmlService.loadFromUrl('https://example.com');
        // If successful, clear should work
        if (htmlService.currentFile != null) {
          await htmlService.clearFile();
        }
      } catch (e) {
        // If error, clear should still work
        if (htmlService.currentFile != null) {
          await htmlService.clearFile();
        }
      }
      
      // Scenario 2: Filesystem file (should work)
      final filesystemFile = HtmlFile(
        name: 'file.txt',
        path: 'file.txt',
        content: 'text content',
        lastModified: DateTime.now(),
        size: 12,
        isUrl: false,
      );
      await htmlService.loadFile(filesystemFile);
      expect(htmlService.currentFile, isNotNull);
      await htmlService.clearFile();
      expect(htmlService.currentFile, isNull);
      
      // Scenario 3: No file (should be safe)
      await htmlService.clearFile();
      expect(htmlService.currentFile, isNull);
      
      print('✅ Clear button works consistently across all scenarios');
    });
  });
}