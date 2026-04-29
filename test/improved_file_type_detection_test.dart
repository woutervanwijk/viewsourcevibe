import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/file_type_detector.dart';
import 'package:view_source_vibe/services/html_service.dart';

void main() {
  group('Strict file type detection tests', () {
    final detector = FileTypeDetector();
    final htmlService = HtmlService();

    test('Strict: HTML detection (content-based)', () async {
      const content = '<!DOCTYPE html><html><body><h1>Hello</h1></body></html>';
      final result = await detector.detectFileType(content: content);
      expect(result, 'HTML');
    });

    test('Strict: XML detection (content-based)', () async {
      const content = '<?xml version="1.0"?><root><item>Hello</item></root>';
      final result = await detector.detectFileType(content: content);
      expect(result, 'XML');
    });

    test('Strict: JSON detection (content-based)', () async {
      const content = '{"name": "test", "value": 123}';
      final result = await detector.detectFileType(content: content);
      expect(result, 'JSON');
    });

    test('Strict: YAML detection (content-based)', () async {
      const content = '---\nname: test\nvalue: 123';
      final result = await detector.detectFileType(content: content);
      expect(result, 'YAML');
    });

    test('Strict: RSS detection (content-based)', () async {
      const content =
          '<rss version="2.0"><channel><title>Ref</title></channel></rss>';
      final result = await detector.detectFileType(content: content);
      expect(result, 'XML');
    });

    test('Strict: JS snippet should be JavaScript (content-based)', () async {
      const content = 'function test() { return true; }';
      final result = await detector.detectFileType(content: content);
      expect(result, 'JavaScript');
    });

    test('Strict: CSS snippet should be CSS (content-based)', () async {
      const content = 'body { margin: 0; }';
      final result = await detector.detectFileType(content: content);
      expect(result, 'CSS');
    });

    test('Strict: Markdown snippet should be Markdown (content-based)',
        () async {
      const content = '# Hello World\n## Subtitle';
      final result = await detector.detectFileType(content: content);
      expect(result, 'Markdown');
    });

    test('Strict: Extension prioritization (JS)', () async {
      const content = 'function test() {}';
      final result = await htmlService.detectFileTypeAndGenerateFilename(
          'script.js', content);
      // Extension .js -> JavaScript -> .js
      expect(result, 'script.js');
    });

    test('Strict: Extension prioritization (CSS)', () async {
      const content = 'body { color: red; }';
      final result = await htmlService.detectFileTypeAndGenerateFilename(
          'styles.css', content);
      // Extension .css -> CSS -> .css
      expect(result, 'styles.css');
    });

    test('Strict: Extension prioritization (Markdown)', () async {
      const content = '# Readme';
      final result = await htmlService.detectFileTypeAndGenerateFilename(
          'README.md', content);
      // Extension .md -> Markdown -> .md
      expect(result, 'README.md');
    });

    test('Strict: HTML with JS inside (filename override)', () async {
      const content = '<html><script>var x=1;</script></html>';
      final result = await htmlService.detectFileTypeAndGenerateFilename(
          'page.html', content);
      expect(result, 'page.html');
    });
  });
}
