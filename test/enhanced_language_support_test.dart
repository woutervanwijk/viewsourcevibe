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
      expect(SourceViewerEditor.getLanguageForExtension('json5'), 'plaintext');

      // XML family
      expect(SourceViewerEditor.getLanguageForExtension('xml'), 'xml');
      expect(SourceViewerEditor.getLanguageForExtension('xsd'), 'xml');
      expect(SourceViewerEditor.getLanguageForExtension('xsl'), 'xml');
      expect(SourceViewerEditor.getLanguageForExtension('svg'), 'xml');

      // YAML
      expect(SourceViewerEditor.getLanguageForExtension('yaml'), 'yaml');
      expect(SourceViewerEditor.getLanguageForExtension('yml'), 'yaml');

      // Vue
      expect(SourceViewerEditor.getLanguageForExtension('vue'), 'plaintext');

      // Svelte
      expect(SourceViewerEditor.getLanguageForExtension('svelte'), 'plaintext');
    });

    test('Markup and Documentation file extensions should be supported', () {
      // Markdown
      expect(SourceViewerEditor.getLanguageForExtension('md'), 'markdown');
      expect(
          SourceViewerEditor.getLanguageForExtension('markdown'), 'markdown');

      // Plain text
      expect(SourceViewerEditor.getLanguageForExtension('txt'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('text'), 'plaintext');

      // AsciiDoc
      expect(SourceViewerEditor.getLanguageForExtension('adoc'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('asciidoc'), 'plaintext');
    });

    test('Programming Language file extensions should be supported', () {
      // Dart
      expect(SourceViewerEditor.getLanguageForExtension('dart'), 'dart');

      // Python
      expect(SourceViewerEditor.getLanguageForExtension('py'), 'python');
      expect(SourceViewerEditor.getLanguageForExtension('python'), 'python');

      // Java
      expect(SourceViewerEditor.getLanguageForExtension('java'), 'java');

      // Kotlin
      expect(SourceViewerEditor.getLanguageForExtension('kt'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('kts'), 'plaintext');

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
      expect(SourceViewerEditor.getLanguageForExtension('c++'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('h'), 'c');
      expect(SourceViewerEditor.getLanguageForExtension('hpp'), 'cpp');
      expect(SourceViewerEditor.getLanguageForExtension('hxx'), 'plaintext');

      // C
      expect(SourceViewerEditor.getLanguageForExtension('c'), 'c');

      // C#
      expect(SourceViewerEditor.getLanguageForExtension('cs'), 'csharp');

      // Scala
      expect(SourceViewerEditor.getLanguageForExtension('scala'), 'plaintext');

      // Haskell
      expect(SourceViewerEditor.getLanguageForExtension('hs'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('haskell'), 'plaintext');

      // Lua
      expect(SourceViewerEditor.getLanguageForExtension('lua'), 'plaintext');

      // Perl
      expect(SourceViewerEditor.getLanguageForExtension('pl'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('perl'), 'plaintext');

      // R
      expect(SourceViewerEditor.getLanguageForExtension('r'), 'plaintext');

      // Shell scripting
      expect(SourceViewerEditor.getLanguageForExtension('sh'), 'bash');
      expect(SourceViewerEditor.getLanguageForExtension('bash'), 'bash');
      expect(SourceViewerEditor.getLanguageForExtension('zsh'), 'bash');
      expect(SourceViewerEditor.getLanguageForExtension('fish'), 'plaintext');

      // PowerShell
      expect(SourceViewerEditor.getLanguageForExtension('ps1'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('psm1'), 'plaintext');
    });

    test('Configuration and Data file extensions should be supported', () {
      // INI files
      expect(SourceViewerEditor.getLanguageForExtension('ini'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('conf'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('config'), 'plaintext');

      // Properties
      expect(SourceViewerEditor.getLanguageForExtension('properties'),
          'plaintext');

      // TOML
      expect(SourceViewerEditor.getLanguageForExtension('toml'), 'plaintext');

      // SQL
      expect(SourceViewerEditor.getLanguageForExtension('sql'), 'sql');

      // GraphQL
      expect(
          SourceViewerEditor.getLanguageForExtension('graphql'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('gql'), 'plaintext');

      // Docker
      expect(SourceViewerEditor.getLanguageForExtension('dockerfile'),
          'plaintext');

      // Make
      expect(
          SourceViewerEditor.getLanguageForExtension('makefile'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('mk'), 'plaintext');

      // CMake
      expect(SourceViewerEditor.getLanguageForExtension('cmake'), 'plaintext');
    });

    test('Styling and Preprocessor file extensions should be supported', () {
      // SCSS/Sass
      expect(SourceViewerEditor.getLanguageForExtension('scss'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('sass'), 'plaintext');

      // Less
      expect(SourceViewerEditor.getLanguageForExtension('less'), 'plaintext');

      // Stylus
      expect(SourceViewerEditor.getLanguageForExtension('styl'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('stylus'), 'plaintext');
    });

    test('Other common file extensions should be supported', () {
      // Diff/Patch
      expect(SourceViewerEditor.getLanguageForExtension('diff'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('patch'), 'plaintext');

      // Gitignore
      expect(
          SourceViewerEditor.getLanguageForExtension('gitignore'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('ignore'), 'plaintext');

      // EditorConfig
      expect(SourceViewerEditor.getLanguageForExtension('editorconfig'),
          'plaintext');
    });

    test('Unknown file extensions should fall back to plaintext', () {
      expect(
          SourceViewerEditor.getLanguageForExtension('unknown'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('xyz123'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension(''), 'plaintext');
    });

    test('Additional re_highlight supported languages should be mapped', () {
      // Additional languages that were missing from original mapping
      expect(SourceViewerEditor.getLanguageForExtension('1c'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('abnf'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('accesslog'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('actionscript'),
          'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('ada'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('angelscript'),
          'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('apache'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('applescript'),
          'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('arcade'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('arduino'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('armasm'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('aspectj'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('autohotkey'),
          'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('autoit'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('avrasm'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('awk'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('axapta'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('basic'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('bnf'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('brainfuck'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('cal'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('capnproto'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('ceylon'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('clean'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('coq'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('cos'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('crmsh'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('csp'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('d'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('delphi'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('pas'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('django'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('dns'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('dos'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('dsconfig'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('dts'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('dust'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('ebnf'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('erb'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('excel'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('xls'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('xlsx'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('fix'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('flix'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('fortran'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('f'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('f77'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('f90'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('f95'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('gams'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('gauss'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('gcode'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('gherkin'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('glsl'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('gml'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('golo'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('gradle'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('groovy'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('haml'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('handlebars'),
          'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('hbs'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('hsp'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('http'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('hy'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('inform7'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('irpf90'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('isbl'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('jboss-cli'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('julia'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('jl'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('lasso'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('latex'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('tex'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('ldif'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('leaf'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('lisp'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('lsp'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('livescript'),
          'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('llvm'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('lsl'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('mathematica'),
          'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('nb'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('matlab'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('maxima'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('mel'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('mercury'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('mipsasm'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('mizar'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('mojolicious'),
          'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('monkey'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('moonscript'),
          'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('n1ql'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('nestedtext'),
          'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('nginx'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('nim'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('nix'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('nsis'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('objectivec'),
          'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('mm'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('ocaml'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('ml'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('mli'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('openscad'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('scad'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('oxygene'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('parser3'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('pf'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('pgsql'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('php-template'),
          'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('pony'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('processing'),
          'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('profile'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('prolog'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('protobuf'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('proto'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('puppet'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('pp'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('purebasic'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('pb'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('python-repl'),
          'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('q'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('qml'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('reasonml'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('re'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('rib'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('roboconf'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('routeros'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('rsl'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('ruleslanguage'),
          'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('sas'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('scheme'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('scm'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('ss'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('scilab'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('sci'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('smali'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('smalltalk'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('st'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('sml'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('sqf'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('stan'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('stata'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('do'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('ado'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('step21'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('stp'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('subunit'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('taggerscript'),
          'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('tap'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('tcl'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('thrift'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('tp'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('twig'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('vala'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('vapi'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('vbnet'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('vb'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('vbscript'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('vbs'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('vbscript-html'),
          'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('verilog'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('v'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('vhdl'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('vhd'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('vim'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('vimrc'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('wren'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('x86asm'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('asm'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('xl'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('xquery'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('xq'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('xql'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('xqy'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('zephir'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('zep'), 'plaintext');
      expect(SourceViewerEditor.getLanguageForExtension('gn'), 'plaintext');
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
