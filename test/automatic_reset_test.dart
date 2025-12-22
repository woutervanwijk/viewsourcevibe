import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';

void main() {
  group('Automatic syntax highlighting reset tests', () {
    
    test('Selected content type should reset to null when loading new file', () async {
      final htmlService = HtmlService();
      
      print('🔍 Testing automatic reset when loading new files:');
      
      // Step 1: Load initial file
      final initialFile = HtmlFile(
        name: 'initial.html',
        path: 'https://example.com/initial.html',
        content: '<html><body>Initial content</body></html>',
        lastModified: DateTime.now(),
        size: 40,
        isUrl: true,
      );
      
      await htmlService.loadFile(initialFile);
      
      print('  1. Initial file loaded');
      print('     Selected content type: ${htmlService.selectedContentType}');
      expect(htmlService.selectedContentType, isNull);
      
      // Step 2: Manually set a content type (simulate user selection)
      htmlService.updateFileContentType('javascript');
      
      print('  2. Manually set content type to JavaScript');
      print('     Selected content type: ${htmlService.selectedContentType}');
      expect(htmlService.selectedContentType, 'javascript');
      
      // Step 3: Load a new file - should reset to Automatic (null)
      final newFile = HtmlFile(
        name: 'new.html',
        path: 'https://example.com/new.html',
        content: '<html><body>New content</body></html>',
        lastModified: DateTime.now(),
        size: 35,
        isUrl: true,
      );
      
      await htmlService.loadFile(newFile);
      
      print('  3. New file loaded');
      print('     Selected content type: ${htmlService.selectedContentType}');
      
      // Should be reset to null (Automatic)
      expect(htmlService.selectedContentType, isNull);
      expect(htmlService.currentFile?.name, 'new.html');
      
      print('  ✅ Content type correctly reset to Automatic (null)');
    });
    
    test('Multiple file loads should always reset content type', () async {
      final htmlService = HtmlService();
      
      print('🔍 Testing multiple file loads:');
      
      final files = [
        {'name': 'file1.html', 'content': '<html><body>File 1</body></html>'},
        {'name': 'file2.css', 'content': 'body { margin: 0; }'},
        {'name': 'file3.js', 'content': 'function test() { return true; }'},
      ];
      
      for (final fileData in files) {
        final name = fileData['name']!;
        final content = fileData['content']!;
        
        print('  Loading: $name');
        
        final file = HtmlFile(
          name: name,
          path: 'https://example.com/$name',
          content: content,
          lastModified: DateTime.now(),
          size: content.length,
          isUrl: true,
        );
        
        await htmlService.loadFile(file);
        
        // Each load should reset to Automatic
        expect(htmlService.selectedContentType, isNull);
        expect(htmlService.currentFile?.name, name);
        
        print('    ✅ Content type reset to Automatic');
        
        // Simulate user changing content type
        htmlService.updateFileContentType('python');
        expect(htmlService.selectedContentType, 'python');
        print('    ✅ Manually set to Python');
      }
      
      // Final load should still reset
      final finalFile = HtmlFile(
        name: 'final.html',
        path: 'https://example.com/final.html',
        content: '<html><body>Final</body></html>',
        lastModified: DateTime.now(),
        size: 30,
        isUrl: true,
      );
      
      await htmlService.loadFile(finalFile);
      expect(htmlService.selectedContentType, isNull);
      
      print('  ✅ Final load also reset content type');
    });
    
    test('URL loading should also reset content type', () async {
      final htmlService = HtmlService();
      
      print('🔍 Testing URL loading reset:');
      
      // This test would normally require mocking HTTP requests
      // For now, we'll test the principle by checking that loadFile
      // (which is called by loadFromUrl) resets the content type
      
      // Simulate the scenario:
      // 1. User loads a file and changes content type
      final initialFile = HtmlFile(
        name: 'initial.html',
        path: 'https://example.com/initial.html',
        content: '<html><body>Initial</body></html>',
        lastModified: DateTime.now(),
        size: 35,
        isUrl: true,
      );
      
      await htmlService.loadFile(initialFile);
      expect(htmlService.selectedContentType, isNull);
      print('  1. Initial load: content type is Automatic');
      
      // User changes to manual content type
      htmlService.updateFileContentType('typescript');
      expect(htmlService.selectedContentType, 'typescript');
      print('  2. User changed to TypeScript');
      
      // Simulate loading from URL (which calls loadFile internally)
      final urlFile = HtmlFile(
        name: 'url-page.html',
        path: 'https://example.com/url-page.html',
        content: '<html><body>URL Content</body></html>',
        lastModified: DateTime.now(),
        size: 40,
        isUrl: true,
      );
      
      // This simulates what happens when loadFromUrl calls loadFile
      await htmlService.loadFile(urlFile);
      
      // Should reset to Automatic
      expect(htmlService.selectedContentType, isNull);
      expect(htmlService.currentFile?.name, 'url-page.html');
      
      print('  3. URL load: content type reset to Automatic');
      print('  ✅ URL loading correctly resets content type');
    });
    
    test('Automatic option should work correctly after reset', () async {
      final htmlService = HtmlService();
      
      print('🔍 Testing Automatic option functionality:');
      
      // Load a file
      final file = HtmlFile(
        name: 'test.html',
        path: 'https://example.com/test.html',
        content: '<html><body>Test</body></html>',
        lastModified: DateTime.now(),
        size: 30,
        isUrl: true,
      );
      
      await htmlService.loadFile(file);
      expect(htmlService.selectedContentType, isNull);
      print('  1. File loaded, content type is Automatic (null)');
      
      // Change to manual content type
      htmlService.updateFileContentType('css');
      expect(htmlService.selectedContentType, 'css');
      print('  2. Changed to CSS manually');
      
      // Use Automatic option (should revert to original file)
      htmlService.updateFileContentType('automatic');
      expect(htmlService.selectedContentType, isNull);
      print('  3. Automatic option used, content type is null again');
      
      // Load new file (should still reset)
      final newFile = HtmlFile(
        name: 'new.html',
        path: 'https://example.com/new.html',
        content: '<html><body>New</body></html>',
        lastModified: DateTime.now(),
        size: 28,
        isUrl: true,
      );
      
      await htmlService.loadFile(newFile);
      expect(htmlService.selectedContentType, isNull);
      print('  4. New file loaded, content type still Automatic');
      
      print('  ✅ Automatic option works correctly');
    });
    
    test('Content type reset should work with various file types', () async {
      final htmlService = HtmlService();
      
      print('🔍 Testing reset with different file types:');
      
      final fileTypes = [
        {
          'name': 'script.js',
          'content': 'console.log("JavaScript");',
          'extension': 'js'
        },
        {
          'name': 'style.css',
          'content': 'body { color: red; }',
          'extension': 'css'
        },
        {
          'name': 'data.json',
          'content': '{"name": "test", "value": 123}',
          'extension': 'json'
        },
        {
          'name': 'config.yaml',
          'content': 'key: value\nlist:\n  - item1\n  - item2',
          'extension': 'yaml'
        },
      ];
      
      for (final fileType in fileTypes) {
        final name = fileType['name']!;
        final content = fileType['content']!;
        final extension = fileType['extension']!;
        
        print('  Testing .$extension files:');
        
        final file = HtmlFile(
          name: name,
          path: 'https://example.com/$name',
          content: content,
          lastModified: DateTime.now(),
          size: content.length,
          isUrl: true,
        );
        
        // Load file
        await htmlService.loadFile(file);
        expect(htmlService.selectedContentType, isNull);
        print('    ✅ $name: content type reset to Automatic');
        
        // Change content type
        htmlService.updateFileContentType('python');
        expect(htmlService.selectedContentType, 'python');
        
        // Load another file of same type
        final anotherFile = HtmlFile(
          name: 'another.$extension',
          path: 'https://example.com/another.$extension',
          content: content,
          lastModified: DateTime.now(),
          size: content.length,
          isUrl: true,
        );
        
        await htmlService.loadFile(anotherFile);
        expect(htmlService.selectedContentType, isNull);
        print('    ✅ another.$extension: content type reset again');
      }
    });
  });
}