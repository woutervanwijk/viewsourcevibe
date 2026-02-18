import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';

void main() {
  group('Strict file type detection tests', () {
    final htmlService = HtmlService();

    test('Strict: HTML detection (content-based)', () async {
      const content = '<!DOCTYPE html><html><body><h1>Hello</h1></body></html>';
      // Pass generic filename to force content detection
      final result = await htmlService.detectFileTypeAndGenerateFilename(
          'unknown', content);
      // Expect .html extension
      expect(result, endsWith('.html'));
    });

    test('Strict: XML detection (content-based)', () async {
      const content = '<?xml version="1.0"?><root><item>Hello</item></root>';
      final result =
          await htmlService.detectFileTypeAndGenerateFilename('data', content);
      expect(result, endsWith('.xml'));
    });

    test('Strict: JSON detection (content-based)', () async {
      const content = '{"name": "test", "value": 123}';
      final result =
          await htmlService.detectFileTypeAndGenerateFilename('data', content);
      expect(result, endsWith('.json'));
    });

    test('Strict: YAML detection (content-based)', () async {
      const content = '---\nname: test\nvalue: 123';
      final result = await htmlService.detectFileTypeAndGenerateFilename(
          'config', content);
      expect(result, endsWith('.yaml'));
    });

    test('Strict: RSS detection (content-based)', () async {
      const content =
          '<rss version="2.0"><channel><title>Ref</title></channel></rss>';
      final result =
          await htmlService.detectFileTypeAndGenerateFilename('feed', content);
      // RSS usually maps to .xml or .rss (FileTypeDetector returns XML for RSS content if strictly parsed)
      // HtmlService ensures .xml for RSS content if base name has no extension
      expect(result, anyOf(endsWith('.xml'), endsWith('.rss')));
    });

    test('Strict: JS snippet should default to Text (content-based)', () async {
      const content = 'function test() { return true; }';
      final result = await htmlService.detectFileTypeAndGenerateFilename(
          'snippet', content);
      // Strict rule: JS content is ambiguous -> Text
      expect(result, endsWith('.txt'));
    });

    test('Strict: CSS snippet should default to Text (content-based)',
        () async {
      const content = 'body { margin: 0; }';
      final result = await htmlService.detectFileTypeAndGenerateFilename(
          'styles', content);
      // Strict rule: CSS content is ambiguous -> Text
      expect(result, endsWith('.txt'));
    });

    test('Strict: Markdown snippet should default to Text (content-based)',
        () async {
      const content = '# Hello World\n## Subtitle';
      final result = await htmlService.detectFileTypeAndGenerateFilename(
          'readme', content);
      // Strict rule: Markdown content is ambiguous -> Text
      expect(result, endsWith('.txt'));
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
