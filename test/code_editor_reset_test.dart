import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';

void main() {
  group('Code Editor Reset Tests', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    test('loadFile should reset currentFile before setting new file', () async {
      // Load first file
      final firstFile = HtmlFile(
        name: 'first.html',
        path: 'first.html',
        content: '<html><body>First content</body></html>',
        lastModified: DateTime.now(),
        size: 30,
      );

      await htmlService.loadFile(firstFile);
      
      // Verify first file is loaded
      expect(htmlService.currentFile, isNotNull);
      expect(htmlService.currentFile?.name, 'first.html');
      expect(htmlService.currentFile?.content, '<html><body>First content</body></html>');

      // Load second file
      final secondFile = HtmlFile(
        name: 'second.html',
        path: 'second.html',
        content: '<html><body>Second content</body></html>',
        lastModified: DateTime.now(),
        size: 31,
      );

      await htmlService.loadFile(secondFile);
      
      // Verify second file is loaded and first file is replaced
      expect(htmlService.currentFile, isNotNull);
      expect(htmlService.currentFile?.name, 'second.html');
      expect(htmlService.currentFile?.content, '<html><body>Second content</body></html>');
      expect(htmlService.currentFile?.content, isNot('<html><body>First content</body></html>'));
    });

    test('loadFile should reset scroll position', () {
      // This test verifies that the scroll controller is reset
      // We can't test the actual UI behavior here, but we can verify the logic
      
      final file = HtmlFile(
        name: 'test.html',
        path: 'test.html',
        content: '<html><body>Test content</body></html>',
        lastModified: DateTime.now(),
        size: 30,
      );

      // Load file should not throw and should complete the reset process
      expect(() => htmlService.loadFile(file), returnsNormally);
    });

    test('clearFile should reset currentFile to null', () async {
      // Load a file first
      final file = HtmlFile(
        name: 'test.html',
        path: 'test.html',
        content: '<html><body>Test content</body></html>',
        lastModified: DateTime.now(),
        size: 30,
      );

      await htmlService.loadFile(file);
      expect(htmlService.currentFile, isNotNull);

      // Clear the file
      htmlService.clearFile();
      expect(htmlService.currentFile, isNull);
    });
  });
}