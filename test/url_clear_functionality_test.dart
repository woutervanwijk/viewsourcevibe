import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';

void main() {
  group('URL Clear Functionality Tests', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    test('Test clearFile() completely resets editor state', () async {
      // First, load a file to have something to clear
      final testFile = HtmlFile(
        name: 'test.html',
        path: 'https://example.com',
        content: '<html><body>Test</body></html>',
        lastModified: DateTime.now(),
        size: 32,
        isUrl: true,
      );

      // Load the file
      await htmlService.loadFile(testFile);
      
      // Verify the file is loaded
      expect(htmlService.currentFile, isNotNull);
      expect(htmlService.currentFile?.name, 'test.html');
      expect(htmlService.currentFile?.content, contains('Test'));
      
      // Now clear the file
      await htmlService.clearFile();
      
      // Verify everything is cleared
      expect(htmlService.currentFile, isNull);
      expect(htmlService.selectedContentType, isNull);
      
      print('✅ clearFile() successfully resets all editor state');
    });

    test('Test URL input clear button functionality', () async {
      // This test verifies the clear button logic in the URL input
      
      // Simulate loading a URL file
      final urlFile = HtmlFile(
        name: 'webpage.html',
        path: 'https://example.com/page',
        content: '<html><body>Web Content</body></html>',
        lastModified: DateTime.now(),
        size: 40,
        isUrl: true,
      );

      await htmlService.loadFile(urlFile);
      
      // Verify URL file is loaded
      expect(htmlService.currentFile, isNotNull);
      expect(htmlService.currentFile?.isUrl, true);
      
      // Simulate clear button press (which calls clearFile())
      await htmlService.clearFile();
      
      // Verify everything is cleared
      expect(htmlService.currentFile, isNull);
      
      print('✅ URL clear button functionality works correctly');
    });

    test('Test clear after error display', () async {
      // Test that clearing works even after an error is displayed
      
      try {
        // This will display an error in the editor
        await htmlService.loadFromUrl('https://nonexistent-website.com');
        
        // Verify an error file was loaded
        expect(htmlService.currentFile, isNotNull);
        expect(htmlService.currentFile?.name, 'Web URL Error');
        
        // Now clear it
        await htmlService.clearFile();
        
        // Verify everything is cleared
        expect(htmlService.currentFile, isNull);
        
        print('✅ Clear works correctly after error display');
      } catch (e) {
        fail('Error handling should work: $e');
      }
    });

    test('Test multiple clear operations', () async {
      // Test that multiple clear operations don't cause issues
      
      // Clear when nothing is loaded (should be safe)
      await htmlService.clearFile();
      expect(htmlService.currentFile, isNull);
      
      // Load a file
      final testFile = HtmlFile(
        name: 'test.html',
        path: 'test.html',
        content: '<html></html>',
        lastModified: DateTime.now(),
        size: 12,
        isUrl: false,
      );
      await htmlService.loadFile(testFile);
      
      // Clear it
      await htmlService.clearFile();
      expect(htmlService.currentFile, isNull);
      
      // Clear again (should be safe)
      await htmlService.clearFile();
      expect(htmlService.currentFile, isNull);
      
      print('✅ Multiple clear operations work safely');
    });
  });
}