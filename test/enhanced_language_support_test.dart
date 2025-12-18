import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:re_highlight/languages/all.dart';

void main() {
  group('Enhanced Language Support Test', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    test('Web Development file extensions should be supported', () {
      // HTML family
      expect(htmlService.getLanguageForExtension('html'), 'xml');
      expect(htmlService.getLanguageForExtension('htm'), 'xml');
      expect(htmlService.getLanguageForExtension('xhtml'), 'xml');
      
      // CSS
      expect(htmlService.getLanguageForExtension('css'), 'css');
      
      // JavaScript family
      expect(htmlService.getLanguageForExtension('js'), 'javascript');
      expect(htmlService.getLanguageForExtension('javascript'), 'javascript');
      expect(htmlService.getLanguageForExtension('mjs'), 'javascript');
      expect(htmlService.getLanguageForExtension('cjs'), 'javascript');
      
      // TypeScript
      expect(htmlService.getLanguageForExtension('ts'), 'typescript');
      expect(htmlService.getLanguageForExtension('typescript'), 'typescript');
      
      // JSX/TSX
      expect(htmlService.getLanguageForExtension('jsx'), 'javascript');
      expect(htmlService.getLanguageForExtension('tsx'), 'javascript');
      
      // JSON
      expect(htmlService.getLanguageForExtension('json'), 'json');
      expect(htmlService.getLanguageForExtension('json5'), 'json');
      
      // XML family
      expect(htmlService.getLanguageForExtension('xml'), 'xml');
      expect(htmlService.getLanguageForExtension('xsd'), 'xml');
      expect(htmlService.getLanguageForExtension('xsl'), 'xml');
      expect(htmlService.getLanguageForExtension('svg'), 'xml');
      
      // YAML
      expect(htmlService.getLanguageForExtension('yaml'), 'yaml');
      expect(htmlService.getLanguageForExtension('yml'), 'yaml');
      
      // Vue
      expect(htmlService.getLanguageForExtension('vue'), 'vue');
      
      // Svelte
      expect(htmlService.getLanguageForExtension('svelte'), 'html');
    });

    test('Markup and Documentation file extensions should be supported', () {
      // Markdown
      expect(htmlService.getLanguageForExtension('md'), 'markdown');
      expect(htmlService.getLanguageForExtension('markdown'), 'markdown');
      
      // Plain text
      expect(htmlService.getLanguageForExtension('txt'), 'plaintext');
      expect(htmlService.getLanguageForExtension('text'), 'plaintext');
      
      // AsciiDoc
      expect(htmlService.getLanguageForExtension('adoc'), 'asciidoc');
      expect(htmlService.getLanguageForExtension('asciidoc'), 'asciidoc');
    });

    test('Programming Language file extensions should be supported', () {
      // Dart
      expect(htmlService.getLanguageForExtension('dart'), 'dart');
      
      // Python
      expect(htmlService.getLanguageForExtension('py'), 'python');
      expect(htmlService.getLanguageForExtension('python'), 'python');
      
      // Java
      expect(htmlService.getLanguageForExtension('java'), 'java');
      
      // Kotlin
      expect(htmlService.getLanguageForExtension('kt'), 'kotlin');
      expect(htmlService.getLanguageForExtension('kts'), 'kotlin');
      
      // Swift
      expect(htmlService.getLanguageForExtension('swift'), 'swift');
      
      // Go
      expect(htmlService.getLanguageForExtension('go'), 'go');
      
      // Rust
      expect(htmlService.getLanguageForExtension('rs'), 'rust');
      expect(htmlService.getLanguageForExtension('rust'), 'rust');
      
      // PHP
      expect(htmlService.getLanguageForExtension('php'), 'php');
      
      // Ruby
      expect(htmlService.getLanguageForExtension('rb'), 'ruby');
      expect(htmlService.getLanguageForExtension('ruby'), 'ruby');
      
      // C++
      expect(htmlService.getLanguageForExtension('cpp'), 'cpp');
      expect(htmlService.getLanguageForExtension('cc'), 'cpp');
      expect(htmlService.getLanguageForExtension('cxx'), 'cpp');
      expect(htmlService.getLanguageForExtension('c++'), 'cpp');
      expect(htmlService.getLanguageForExtension('h'), 'cpp');
      expect(htmlService.getLanguageForExtension('hpp'), 'cpp');
      expect(htmlService.getLanguageForExtension('hxx'), 'cpp');
      
      // C
      expect(htmlService.getLanguageForExtension('c'), 'c');
      
      // C#
      expect(htmlService.getLanguageForExtension('cs'), 'csharp');
      
      // Scala
      expect(htmlService.getLanguageForExtension('scala'), 'scala');
      
      // Haskell
      expect(htmlService.getLanguageForExtension('hs'), 'haskell');
      expect(htmlService.getLanguageForExtension('haskell'), 'haskell');
      
      // Lua
      expect(htmlService.getLanguageForExtension('lua'), 'lua');
      
      // Perl
      expect(htmlService.getLanguageForExtension('pl'), 'perl');
      expect(htmlService.getLanguageForExtension('perl'), 'perl');
      
      // R
      expect(htmlService.getLanguageForExtension('r'), 'r');
      
      // Shell scripting
      expect(htmlService.getLanguageForExtension('sh'), 'bash');
      expect(htmlService.getLanguageForExtension('bash'), 'bash');
      expect(htmlService.getLanguageForExtension('zsh'), 'bash');
      expect(htmlService.getLanguageForExtension('fish'), 'bash');
      
      // PowerShell
      expect(htmlService.getLanguageForExtension('ps1'), 'powershell');
      expect(htmlService.getLanguageForExtension('psm1'), 'powershell');
    });

    test('Configuration and Data file extensions should be supported', () {
      // INI files
      expect(htmlService.getLanguageForExtension('ini'), 'ini');
      expect(htmlService.getLanguageForExtension('conf'), 'ini');
      expect(htmlService.getLanguageForExtension('config'), 'ini');
      
      // Properties
      expect(htmlService.getLanguageForExtension('properties'), 'properties');
      
      // TOML
      expect(htmlService.getLanguageForExtension('toml'), 'toml');
      
      // SQL
      expect(htmlService.getLanguageForExtension('sql'), 'sql');
      
      // GraphQL
      expect(htmlService.getLanguageForExtension('graphql'), 'graphql');
      expect(htmlService.getLanguageForExtension('gql'), 'graphql');
      
      // Docker
      expect(htmlService.getLanguageForExtension('dockerfile'), 'dockerfile');
      
      // Make
      expect(htmlService.getLanguageForExtension('makefile'), 'makefile');
      expect(htmlService.getLanguageForExtension('mk'), 'makefile');
      
      // CMake
      expect(htmlService.getLanguageForExtension('cmake'), 'cmake');
    });

    test('Styling and Preprocessor file extensions should be supported', () {
      // SCSS/Sass
      expect(htmlService.getLanguageForExtension('scss'), 'scss');
      expect(htmlService.getLanguageForExtension('sass'), 'scss');
      
      // Less
      expect(htmlService.getLanguageForExtension('less'), 'less');
      
      // Stylus
      expect(htmlService.getLanguageForExtension('styl'), 'stylus');
      expect(htmlService.getLanguageForExtension('stylus'), 'stylus');
    });

    test('Other common file extensions should be supported', () {
      // Diff/Patch
      expect(htmlService.getLanguageForExtension('diff'), 'diff');
      expect(htmlService.getLanguageForExtension('patch'), 'diff');
      
      // Gitignore
      expect(htmlService.getLanguageForExtension('gitignore'), 'gitignore');
      expect(htmlService.getLanguageForExtension('ignore'), 'gitignore');
      
      // EditorConfig
      expect(htmlService.getLanguageForExtension('editorconfig'), 'ini');
    });

    test('Unknown file extensions should fall back to plaintext', () {
      expect(htmlService.getLanguageForExtension('unknown'), 'plaintext');
      expect(htmlService.getLanguageForExtension('xyz123'), 'plaintext');
      expect(htmlService.getLanguageForExtension(''), 'plaintext');
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

    test('Mode retrieval should fall back gracefully for unknown languages', () {
      // Even for unknown languages, we should get a fallback mode
      final mode = htmlService.getReHighlightModeForExtension('unknown_language_xyz');
      expect(mode, isNotNull);
      expect(mode, builtinAllLanguages['plaintext']);
    });
  });
}