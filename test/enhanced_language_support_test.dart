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

    test('Additional re_highlight supported languages should be mapped', () {
      // Additional languages that were missing from original mapping
      expect(htmlService.getLanguageForExtension('1c'), '1c');
      expect(htmlService.getLanguageForExtension('abnf'), 'abnf');
      expect(htmlService.getLanguageForExtension('accesslog'), 'accesslog');
      expect(htmlService.getLanguageForExtension('actionscript'), 'actionscript');
      expect(htmlService.getLanguageForExtension('ada'), 'ada');
      expect(htmlService.getLanguageForExtension('angelscript'), 'angelscript');
      expect(htmlService.getLanguageForExtension('apache'), 'apache');
      expect(htmlService.getLanguageForExtension('applescript'), 'applescript');
      expect(htmlService.getLanguageForExtension('arcade'), 'arcade');
      expect(htmlService.getLanguageForExtension('arduino'), 'arduino');
      expect(htmlService.getLanguageForExtension('armasm'), 'armasm');
      expect(htmlService.getLanguageForExtension('aspectj'), 'aspectj');
      expect(htmlService.getLanguageForExtension('autohotkey'), 'autohotkey');
      expect(htmlService.getLanguageForExtension('autoit'), 'autoit');
      expect(htmlService.getLanguageForExtension('avrasm'), 'avrasm');
      expect(htmlService.getLanguageForExtension('awk'), 'awk');
      expect(htmlService.getLanguageForExtension('axapta'), 'axapta');
      expect(htmlService.getLanguageForExtension('basic'), 'basic');
      expect(htmlService.getLanguageForExtension('bnf'), 'bnf');
      expect(htmlService.getLanguageForExtension('brainfuck'), 'brainfuck');
      expect(htmlService.getLanguageForExtension('cal'), 'cal');
      expect(htmlService.getLanguageForExtension('capnproto'), 'capnproto');
      expect(htmlService.getLanguageForExtension('ceylon'), 'ceylon');
      expect(htmlService.getLanguageForExtension('clean'), 'clean');
      expect(htmlService.getLanguageForExtension('coq'), 'coq');
      expect(htmlService.getLanguageForExtension('cos'), 'cos');
      expect(htmlService.getLanguageForExtension('crmsh'), 'crmsh');
      expect(htmlService.getLanguageForExtension('csp'), 'csp');
      expect(htmlService.getLanguageForExtension('d'), 'd');
      expect(htmlService.getLanguageForExtension('delphi'), 'delphi');
      expect(htmlService.getLanguageForExtension('pas'), 'delphi');
      expect(htmlService.getLanguageForExtension('django'), 'django');
      expect(htmlService.getLanguageForExtension('dns'), 'dns');
      expect(htmlService.getLanguageForExtension('dos'), 'dos');
      expect(htmlService.getLanguageForExtension('dsconfig'), 'dsconfig');
      expect(htmlService.getLanguageForExtension('dts'), 'dts');
      expect(htmlService.getLanguageForExtension('dust'), 'dust');
      expect(htmlService.getLanguageForExtension('ebnf'), 'ebnf');
      expect(htmlService.getLanguageForExtension('erb'), 'erb');
      expect(htmlService.getLanguageForExtension('excel'), 'excel');
      expect(htmlService.getLanguageForExtension('xls'), 'excel');
      expect(htmlService.getLanguageForExtension('xlsx'), 'excel');
      expect(htmlService.getLanguageForExtension('fix'), 'fix');
      expect(htmlService.getLanguageForExtension('flix'), 'flix');
      expect(htmlService.getLanguageForExtension('fortran'), 'fortran');
      expect(htmlService.getLanguageForExtension('f'), 'fortran');
      expect(htmlService.getLanguageForExtension('f77'), 'fortran');
      expect(htmlService.getLanguageForExtension('f90'), 'fortran');
      expect(htmlService.getLanguageForExtension('f95'), 'fortran');
      expect(htmlService.getLanguageForExtension('gams'), 'gams');
      expect(htmlService.getLanguageForExtension('gauss'), 'gauss');
      expect(htmlService.getLanguageForExtension('gcode'), 'gcode');
      expect(htmlService.getLanguageForExtension('gherkin'), 'gherkin');
      expect(htmlService.getLanguageForExtension('glsl'), 'glsl');
      expect(htmlService.getLanguageForExtension('gml'), 'gml');
      expect(htmlService.getLanguageForExtension('golo'), 'golo');
      expect(htmlService.getLanguageForExtension('gradle'), 'gradle');
      expect(htmlService.getLanguageForExtension('groovy'), 'groovy');
      expect(htmlService.getLanguageForExtension('haml'), 'haml');
      expect(htmlService.getLanguageForExtension('handlebars'), 'handlebars');
      expect(htmlService.getLanguageForExtension('hbs'), 'handlebars');
      expect(htmlService.getLanguageForExtension('hsp'), 'hsp');
      expect(htmlService.getLanguageForExtension('http'), 'http');
      expect(htmlService.getLanguageForExtension('hy'), 'hy');
      expect(htmlService.getLanguageForExtension('inform7'), 'inform7');
      expect(htmlService.getLanguageForExtension('irpf90'), 'irpf90');
      expect(htmlService.getLanguageForExtension('isbl'), 'isbl');
      expect(htmlService.getLanguageForExtension('jboss-cli'), 'jboss-cli');
      expect(htmlService.getLanguageForExtension('julia'), 'julia');
      expect(htmlService.getLanguageForExtension('jl'), 'julia');
      expect(htmlService.getLanguageForExtension('lasso'), 'lasso');
      expect(htmlService.getLanguageForExtension('latex'), 'latex');
      expect(htmlService.getLanguageForExtension('tex'), 'latex');
      expect(htmlService.getLanguageForExtension('ldif'), 'ldif');
      expect(htmlService.getLanguageForExtension('leaf'), 'leaf');
      expect(htmlService.getLanguageForExtension('lisp'), 'lisp');
      expect(htmlService.getLanguageForExtension('lsp'), 'lisp');
      expect(htmlService.getLanguageForExtension('livescript'), 'livescript');
      expect(htmlService.getLanguageForExtension('llvm'), 'llvm');
      expect(htmlService.getLanguageForExtension('lsl'), 'lsl');
      expect(htmlService.getLanguageForExtension('mathematica'), 'mathematica');
      expect(htmlService.getLanguageForExtension('nb'), 'mathematica');
      expect(htmlService.getLanguageForExtension('matlab'), 'matlab');
      expect(htmlService.getLanguageForExtension('maxima'), 'maxima');
      expect(htmlService.getLanguageForExtension('mel'), 'mel');
      expect(htmlService.getLanguageForExtension('mercury'), 'mercury');
      expect(htmlService.getLanguageForExtension('mipsasm'), 'mipsasm');
      expect(htmlService.getLanguageForExtension('mizar'), 'mizar');
      expect(htmlService.getLanguageForExtension('mojolicious'), 'mojolicious');
      expect(htmlService.getLanguageForExtension('monkey'), 'monkey');
      expect(htmlService.getLanguageForExtension('moonscript'), 'moonscript');
      expect(htmlService.getLanguageForExtension('n1ql'), 'n1ql');
      expect(htmlService.getLanguageForExtension('nestedtext'), 'nestedtext');
      expect(htmlService.getLanguageForExtension('nginx'), 'nginx');
      expect(htmlService.getLanguageForExtension('nim'), 'nim');
      expect(htmlService.getLanguageForExtension('nix'), 'nix');
      expect(htmlService.getLanguageForExtension('nsis'), 'nsis');
      expect(htmlService.getLanguageForExtension('objectivec'), 'objectivec');
      expect(htmlService.getLanguageForExtension('mm'), 'objectivec');
      expect(htmlService.getLanguageForExtension('ocaml'), 'ocaml');
      expect(htmlService.getLanguageForExtension('ml'), 'ocaml');
      expect(htmlService.getLanguageForExtension('mli'), 'ocaml');
      expect(htmlService.getLanguageForExtension('openscad'), 'openscad');
      expect(htmlService.getLanguageForExtension('scad'), 'openscad');
      expect(htmlService.getLanguageForExtension('oxygene'), 'oxygene');
      expect(htmlService.getLanguageForExtension('parser3'), 'parser3');
      expect(htmlService.getLanguageForExtension('pf'), 'pf');
      expect(htmlService.getLanguageForExtension('pgsql'), 'pgsql');
      expect(htmlService.getLanguageForExtension('php-template'), 'php-template');
      expect(htmlService.getLanguageForExtension('pony'), 'pony');
      expect(htmlService.getLanguageForExtension('processing'), 'processing');
      expect(htmlService.getLanguageForExtension('profile'), 'profile');
      expect(htmlService.getLanguageForExtension('prolog'), 'prolog');
      expect(htmlService.getLanguageForExtension('protobuf'), 'protobuf');
      expect(htmlService.getLanguageForExtension('proto'), 'protobuf');
      expect(htmlService.getLanguageForExtension('puppet'), 'puppet');
      expect(htmlService.getLanguageForExtension('pp'), 'puppet');
      expect(htmlService.getLanguageForExtension('purebasic'), 'purebasic');
      expect(htmlService.getLanguageForExtension('pb'), 'purebasic');
      expect(htmlService.getLanguageForExtension('python-repl'), 'python-repl');
      expect(htmlService.getLanguageForExtension('q'), 'q');
      expect(htmlService.getLanguageForExtension('qml'), 'qml');
      expect(htmlService.getLanguageForExtension('reasonml'), 'reasonml');
      expect(htmlService.getLanguageForExtension('re'), 'reasonml');
      expect(htmlService.getLanguageForExtension('rib'), 'rib');
      expect(htmlService.getLanguageForExtension('roboconf'), 'roboconf');
      expect(htmlService.getLanguageForExtension('routeros'), 'routeros');
      expect(htmlService.getLanguageForExtension('rsl'), 'rsl');
      expect(htmlService.getLanguageForExtension('ruleslanguage'), 'ruleslanguage');
      expect(htmlService.getLanguageForExtension('sas'), 'sas');
      expect(htmlService.getLanguageForExtension('scheme'), 'scheme');
      expect(htmlService.getLanguageForExtension('scm'), 'scheme');
      expect(htmlService.getLanguageForExtension('ss'), 'scheme');
      expect(htmlService.getLanguageForExtension('scilab'), 'scilab');
      expect(htmlService.getLanguageForExtension('sci'), 'scilab');
      expect(htmlService.getLanguageForExtension('smali'), 'smali');
      expect(htmlService.getLanguageForExtension('smalltalk'), 'smalltalk');
      expect(htmlService.getLanguageForExtension('st'), 'smalltalk');
      expect(htmlService.getLanguageForExtension('sml'), 'sml');
      expect(htmlService.getLanguageForExtension('sqf'), 'sqf');
      expect(htmlService.getLanguageForExtension('stan'), 'stan');
      expect(htmlService.getLanguageForExtension('stata'), 'stata');
      expect(htmlService.getLanguageForExtension('do'), 'stata');
      expect(htmlService.getLanguageForExtension('ado'), 'stata');
      expect(htmlService.getLanguageForExtension('step21'), 'step21');
      expect(htmlService.getLanguageForExtension('stp'), 'step21');
      expect(htmlService.getLanguageForExtension('subunit'), 'subunit');
      expect(htmlService.getLanguageForExtension('taggerscript'), 'taggerscript');
      expect(htmlService.getLanguageForExtension('tap'), 'tap');
      expect(htmlService.getLanguageForExtension('tcl'), 'tcl');
      expect(htmlService.getLanguageForExtension('thrift'), 'thrift');
      expect(htmlService.getLanguageForExtension('tp'), 'tp');
      expect(htmlService.getLanguageForExtension('twig'), 'twig');
      expect(htmlService.getLanguageForExtension('vala'), 'vala');
      expect(htmlService.getLanguageForExtension('vapi'), 'vala');
      expect(htmlService.getLanguageForExtension('vbnet'), 'vbnet');
      expect(htmlService.getLanguageForExtension('vb'), 'vbnet');
      expect(htmlService.getLanguageForExtension('vbscript'), 'vbscript');
      expect(htmlService.getLanguageForExtension('vbs'), 'vbscript');
      expect(htmlService.getLanguageForExtension('vbscript-html'), 'vbscript-html');
      expect(htmlService.getLanguageForExtension('verilog'), 'verilog');
      expect(htmlService.getLanguageForExtension('v'), 'verilog');
      expect(htmlService.getLanguageForExtension('vhdl'), 'vhdl');
      expect(htmlService.getLanguageForExtension('vhd'), 'vhdl');
      expect(htmlService.getLanguageForExtension('vim'), 'vim');
      expect(htmlService.getLanguageForExtension('vimrc'), 'vim');
      expect(htmlService.getLanguageForExtension('wren'), 'wren');
      expect(htmlService.getLanguageForExtension('x86asm'), 'x86asm');
      expect(htmlService.getLanguageForExtension('asm'), 'x86asm');
      expect(htmlService.getLanguageForExtension('xl'), 'xl');
      expect(htmlService.getLanguageForExtension('xquery'), 'xquery');
      expect(htmlService.getLanguageForExtension('xq'), 'xquery');
      expect(htmlService.getLanguageForExtension('xql'), 'xquery');
      expect(htmlService.getLanguageForExtension('xqy'), 'xquery');
      expect(htmlService.getLanguageForExtension('zephir'), 'zephir');
      expect(htmlService.getLanguageForExtension('zep'), 'zephir');
      expect(htmlService.getLanguageForExtension('gn'), 'gn');
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

    test('Content detection should identify various file types', () {
      // Test HTML detection
      const htmlContent = '<!DOCTYPE html><html><head><title>Test</title></head><body>Hello</body></html>';
      expect(htmlService.ensureHtmlExtension('test', htmlContent), 'HTML File');

      // Test CSS detection
      const cssContent = 'body { background-color: #fff; } @media screen { div { color: blue; } }';
      expect(htmlService.ensureHtmlExtension('test', cssContent), 'CSS File');

      // Test JavaScript detection
      const jsContent = 'function test() { const x = 1; let y = 2; return x + y; }';
      expect(htmlService.ensureHtmlExtension('test', jsContent), 'JavaScript File');

      // Test JSON detection
      const jsonContent = '{"name": "test", "value": 123}';
      expect(htmlService.ensureHtmlExtension('test', jsonContent), 'JSON File');

      // Test YAML detection
      const yamlContent = '---\nkey: value\nlist:\n  - item1\n  - item2';
      expect(htmlService.ensureHtmlExtension('test', yamlContent), 'YAML File');

      // Test Markdown detection
      const markdownContent = '# Heading\n## Subheading\n**bold text**\n* item\n1. numbered';
      expect(htmlService.ensureHtmlExtension('test', markdownContent), 'Markdown File');

      // Test XML detection
      const xmlContent = '<?xml version="1.0"?><root><element>content</element></root>';
      expect(htmlService.ensureHtmlExtension('test', xmlContent), 'XML File');

      // Test Python detection
      const pythonContent = 'def hello():\n    print("Hello World")\n    return True';
      expect(htmlService.ensureHtmlExtension('test', pythonContent), 'Python File');

      // Test Java detection
      const javaContent = 'public class Test {\n    public static void main(String[] args) {\n        System.out.println("Hello");\n    }\n}';
      expect(htmlService.ensureHtmlExtension('test', javaContent), 'Java File');

      // Test C++ detection
      const cppContent = '#include <iostream>\nint main() {\n    std::cout << "Hello" << std::endl;\n    return 0;\n}';
      expect(htmlService.ensureHtmlExtension('test', cppContent), 'C++ File');

      // Test PHP detection
      const phpContent = '<?php\n\$variable = "test";\necho \$variable;\n?';
      expect(htmlService.ensureHtmlExtension('test', phpContent), 'PHP File');

      // Test Ruby detection
      const rubyContent = 'def hello\n  puts "Hello World"\nend\nhello()';
      expect(htmlService.ensureHtmlExtension('test', rubyContent), 'Ruby File');

      // Test SQL detection
      const sqlContent = 'SELECT * FROM users WHERE id = 1 ORDER BY name LIMIT 10;';
      expect(htmlService.ensureHtmlExtension('test', sqlContent), 'SQL File');

      // Test fallback for unknown content
      const unknownContent = 'This is just some random text without specific patterns.';
      expect(htmlService.ensureHtmlExtension('test', unknownContent), 'Text File');
    });
  });
}