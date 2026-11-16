import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/source_viewer_editor.dart';
import 'package:re_highlight/languages/all.dart';

void main() {
  group('Enhanced Language Support Test', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    test('Web Development file extensions should be supported', () {
      // HTML family
      expect(SourceViewerEditor.getLanguageForExtension('html'), 'html');
      expect(SourceViewerEditor.getLanguageForExtension('htm'), 'html');
      expect(SourceViewerEditor.getLanguageForExtension('xhtml'), 'html');

      // CSS
      expect(SourceViewerEditor.getLanguageForExtension('css'), 'css');

      // JavaScript family
      expect(SourceViewerEditor.getLanguageForExtension('js'), 'javascript');
      expect(SourceViewerEditor.getLanguageForExtension('javascript'),
          'javascript');
      expect(SourceViewerEditor.getLanguageForExtension('mjs'), 'javascript');
      expect(SourceViewerEditor.getLanguageForExtension('cjs'), 'javascript');

      // TypeScript
      expect(SourceViewerEditor.getLanguageForExtension('ts'), 'typescript');
      expect(SourceViewerEditor.getLanguageForExtension('typescript'),
          'typescript');

      // JSX/TSX
      expect(SourceViewerEditor.getLanguageForExtension('jsx'), 'javascript');
      expect(SourceViewerEditor.getLanguageForExtension('tsx'), 'typescript');

      // JSON
      expect(SourceViewerEditor.getLanguageForExtension('json'), 'json');

      // XML family
      expect(SourceViewerEditor.getLanguageForExtension('xml'), 'xml');
      expect(SourceViewerEditor.getLanguageForExtension('xsd'), 'xml');
      expect(SourceViewerEditor.getLanguageForExtension('xsl'), 'xml');
      expect(SourceViewerEditor.getLanguageForExtension('svg'), 'xml');

      // YAML
      expect(SourceViewerEditor.getLanguageForExtension('yaml'), 'yaml');
      expect(SourceViewerEditor.getLanguageForExtension('yml'), 'yaml');
    });

    test('Markup and Documentation file extensions should be supported', () {
      // Markdown
      expect(SourceViewerEditor.getLanguageForExtension('md'), 'markdown');
      expect(
          SourceViewerEditor.getLanguageForExtension('markdown'), 'markdown');
    });

    test('Programming Language file extensions should be supported', () {
      // Dart
      expect(SourceViewerEditor.getLanguageForExtension('dart'), 'dart');

      // Python
      expect(SourceViewerEditor.getLanguageForExtension('py'), 'python');
      expect(SourceViewerEditor.getLanguageForExtension('python'), 'python');

      // Java
      expect(SourceViewerEditor.getLanguageForExtension('java'), 'java');

      // Swift
      expect(SourceViewerEditor.getLanguageForExtension('swift'), 'swift');

      // Go
      expect(SourceViewerEditor.getLanguageForExtension('go'), 'go');

      // Rust
      expect(SourceViewerEditor.getLanguageForExtension('rs'), 'rust');
      expect(SourceViewerEditor.getLanguageForExtension('rust'), 'rust');

      // PHP
      expect(SourceViewerEditor.getLanguageForExtension('php'), 'php');

      // Ruby
      expect(SourceViewerEditor.getLanguageForExtension('rb'), 'ruby');
      expect(SourceViewerEditor.getLanguageForExtension('ruby'), 'ruby');

      // C++
      expect(SourceViewerEditor.getLanguageForExtension('cpp'), 'cpp');
      expect(SourceViewerEditor.getLanguageForExtension('cc'), 'cpp');
      expect(SourceViewerEditor.getLanguageForExtension('cxx'), 'cpp');
      expect(SourceViewerEditor.getLanguageForExtension('h'), 'c');
      expect(SourceViewerEditor.getLanguageForExtension('hpp'), 'cpp');

      // C
      expect(SourceViewerEditor.getLanguageForExtension('c'), 'c');

      // C#
      expect(SourceViewerEditor.getLanguageForExtension('cs'), 'csharp');

      // Shell scripting
      expect(SourceViewerEditor.getLanguageForExtension('sh'), 'bash');
      expect(SourceViewerEditor.getLanguageForExtension('bash'), 'bash');
      expect(SourceViewerEditor.getLanguageForExtension('zsh'), 'bash');
    });

    test('Configuration and Data file extensions should be supported', () {
      // SQL
      expect(SourceViewerEditor.getLanguageForExtension('sql'), 'sql');
    });

    test('unsupported and unknown extensions fall back to plaintext', () {
      expect(
          SourceViewerEditor.getLanguageForExtension('unknown'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('xyz123'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension(''), 'plaintext');
      for (final ext in ['json5', 'vue', 'kt', 'scss', 'toml', 'gitignore']) {
        expect(SourceViewerEditor.getLanguageForExtension(ext), 'plaintext',
            reason: ext);
      }
    });

    test('Mode retrieval should work for supported languages', () {
      // Test that we can get modes for various languages
      expect(htmlService.getReHighlightModeForExtension('html'), isNotNull);
      expect(htmlService.getReHighlightModeForExtension('css'), isNotNull);
      expect(htmlService.getReHighlightModeForExtension('js'), isNotNull);
      expect(htmlService.getReHighlightModeForExtension('ts'), isNotNull);
      expect(htmlService.getReHighlightModeForExtension('json'), isNotNull);
      expect(htmlService.getReHighlightModeForExtension('yaml'), isNotNull);
      expect(htmlService.getReHighlightModeForExtension('dart'), isNotNull);
      expect(htmlService.getReHighlightModeForExtension('python'), isNotNull);
      expect(htmlService.getReHighlightModeForExtension('java'), isNotNull);
      expect(htmlService.getReHighlightModeForExtension('markdown'), isNotNull);
      expect(htmlService.getReHighlightModeForExtension('sql'), isNotNull);
      expect(htmlService.getReHighlightModeForExtension('bash'), isNotNull);
    });

    test('Mode retrieval should fall back gracefully for unknown languages',
        () {
      // Even for unknown languages, we should get a fallback mode
      final mode =
          htmlService.getReHighlightModeForExtension('unknown_language_xyz');
      expect(mode, isNotNull);
      expect(mode, builtinAllLanguages['plaintext']);
    });
  });
}
