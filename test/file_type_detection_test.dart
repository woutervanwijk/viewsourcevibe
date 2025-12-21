import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/file_type_detector.dart';
import 'package:view_source_vibe/services/html_service.dart';

void main() {
  group('File Type Detection Tests', () {
    late FileTypeDetector detector;
    late HtmlService htmlService;

    setUp(() {
      detector = FileTypeDetector();
      htmlService = HtmlService();
    });

    group('Extension-Based Detection', () {
      test('Should detect HTML files by extension', () async {
        expect(await detector.detectFileType(filename: 'test.html'), 'HTML');
        expect(await detector.detectFileType(filename: 'test.htm'), 'HTML');
      });

      test('Should detect CSS files by extension', () async {
        expect(await detector.detectFileType(filename: 'styles.css'), 'CSS');
      });

      test('Should detect JavaScript files by extension', () async {
        expect(await detector.detectFileType(filename: 'script.js'), 'JavaScript');
        expect(await detector.detectFileType(filename: 'script.mjs'), 'JavaScript');
      });

      test('Should detect TypeScript files by extension', () async {
        expect(await detector.detectFileType(filename: 'script.ts'), 'TypeScript');
      });

      test('Should detect JSON files by extension', () async {
        expect(await detector.detectFileType(filename: 'data.json'), 'JSON');
      });

      test('Should detect Python files by extension', () async {
        expect(await detector.detectFileType(filename: 'script.py'), 'Python');
      });

      test('Should detect Java files by extension', () async {
        expect(await detector.detectFileType(filename: 'Main.java'), 'Java');
      });

      test('Should detect Dart files by extension', () async {
        expect(await detector.detectFileType(filename: 'main.dart'), 'Dart');
      });

      test('Should detect unknown extensions as Text', () async {
        expect(await detector.detectFileType(filename: 'file.xyz'), 'Text');
        expect(await detector.detectFileType(filename: 'file.unknown'), 'Text');
      });
    });

    group('Content-Based Detection', () {
      test('Should detect HTML content without extension', () async {
        const htmlContent = '<!DOCTYPE html><html><head><title>Test</title></head><body>Hello</body></html>';
        expect(await detector.detectFileType(content: htmlContent), 'HTML');
      });

      test('Should detect CSS content without extension', () async {
        const cssContent = 'body { background-color: #fff; } @media screen { div { color: blue; } }';
        expect(await detector.detectFileType(content: cssContent), 'CSS');
      });

      test('Should detect JavaScript content without extension', () async {
        const jsContent = 'function test() { const x = 1; let y = 2; return x + y; }';
        expect(await detector.detectFileType(content: jsContent), 'JavaScript');
      });

      test('Should detect JSON content without extension', () async {
        const jsonContent = '{"name": "test", "value": 123}';
        expect(await detector.detectFileType(content: jsonContent), 'JSON');
      });

      test('Should detect YAML content without extension', () async {
        const yamlContent = '---\nkey: value\nlist:\n  - item1\n  - item2';
        expect(await detector.detectFileType(content: yamlContent), 'YAML');
      });

      test('Should detect Markdown content without extension', () async {
        const markdownContent = '# Heading\n## Subheading\n**bold text**\n* item\n1. numbered';
        expect(await detector.detectFileType(content: markdownContent), 'Markdown');
      });

      test('Should detect Python content without extension', () async {
        const pythonContent = 'def hello():\n    print("Hello World")\n    return True';
        expect(await detector.detectFileType(content: pythonContent), 'Python');
      });

      test('Should detect Java content without extension', () async {
        const javaContent = 'public class Test {\n    public static void main(String[] args) {\n        System.out.println("Hello");\n    }\n}';
        expect(await detector.detectFileType(content: javaContent), 'Java');
      });

      test('Should detect C++ content without extension', () async {
        const cppContent = '#include <iostream>\nint main() {\n    std::cout << "Hello" << std::endl;\n    return 0;\n}';
        expect(await detector.detectFileType(content: cppContent), 'C++');
      });

      test('Should detect SQL content without extension', () async {
        const sqlContent = 'SELECT * FROM users WHERE id = 1 ORDER BY name LIMIT 10;';
        expect(await detector.detectFileType(content: sqlContent), 'SQL');
      });

      test('Should detect Ruby content without extension', () async {
        const rubyContent = 'def hello\n  puts "Hello World"\nend\nhello()';
        expect(await detector.detectFileType(content: rubyContent), 'Ruby');
      });

      test('Should detect PHP content without extension', () async {
        const phpContent = '<?php\n\$variable = "test";\necho \$variable;\n?';
        expect(await detector.detectFileType(content: phpContent), 'PHP');
      });

      test('Should detect XML content without extension', () async {
        const xmlContent = '<?xml version="1.0"?><root><element>content</element></root>';
        expect(await detector.detectFileType(content: xmlContent), 'XML');
      });
    });

    group('Priority Detection', () {
      test('Should prioritize extension over content when both are present', () async {
        // Python-like content but with .js extension
        const content = 'def hello():\n    print("Hello")';
        expect(await detector.detectFileType(filename: 'test.js', content: content), 'JavaScript');
      });

      test('Should use content detection when extension is unknown', () async {
        const pythonContent = 'def hello():\n    print("Hello")';
        expect(await detector.detectFileType(filename: 'test.xyz', content: pythonContent), 'Python');
      });
    });

    group('Integration with HtmlService', () {
      test('Should generate appropriate filenames for HTML content', () async {
        const htmlContent = '<!DOCTYPE html><html><body>Test</body></html>';
        expect(await htmlService.detectFileTypeAndGenerateFilename('test', htmlContent), 'HTML File');
      });

      test('Should generate appropriate filenames for JavaScript content', () async {
        const jsContent = 'function test() { return true; }';
        expect(await htmlService.detectFileTypeAndGenerateFilename('script', jsContent), 'JavaScript File');
      });

      test('Should preserve filenames with extensions', () async {
        const content = 'function test() { return true; }';
        expect(await htmlService.detectFileTypeAndGenerateFilename('script.js', content), 'script.js');
      });

      test('Should handle edge cases gracefully', () async {
        expect(await htmlService.detectFileTypeAndGenerateFilename('', ''), 'Text File');
        expect(await htmlService.detectFileTypeAndGenerateFilename('index', ''), 'Text File');
        expect(await htmlService.detectFileTypeAndGenerateFilename('/', ''), 'Text File');
      });
    });

    group('Cache Functionality', () {
      test('Should cache detection results for better performance', () async {
        const content = 'function test() { return true; }';
        
        // First call
        final firstResult = await detector.detectFileType(content: content);
        
        // Second call with same content should be cached
        final secondResult = await detector.detectFileType(content: content);
        
        expect(firstResult, secondResult);
        expect(firstResult, 'JavaScript');
      });

      test('Should handle cache clearing', () async {
        const content = 'function test() { return true; }';
        
        // Detect and cache
        await detector.detectFileType(content: content);
        
        // Clear cache
        detector.clearCache();
        
        // Should still work after clearing cache
        final result = await detector.detectFileType(content: content);
        expect(result, 'JavaScript');
      });
    });

    group('Fallback Detection', () {
      test('Should handle edge cases gracefully', () async {
        // Test with empty content
        expect(await detector.detectFileType(content: ''), 'Text');
        
        // Test with very short content
        expect(await detector.detectFileType(content: 'x'), 'Text');
        
        // Test with random text
        expect(await detector.detectFileType(content: 'random text without specific patterns'), 'Text');
      });
    });
  });
}