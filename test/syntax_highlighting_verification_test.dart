import 'package:flutter_test/flutter_test.dart';
import 'package:htmlviewer/services/html_service.dart';
import 'package:re_highlight/languages/all.dart';

void main() {
  group('Syntax Highlighting Verification Tests', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    test('HTML syntax highlighting should use correct language mode', () {
      final languageMode = htmlService.getReHighlightModeForExtension('html');
      
      expect(languageMode, isNotNull);
      // We expect vbscript-html for HTML files
      expect(languageMode, equals(builtinAllLanguages['vbscript-html']));
    });

    test('CSS syntax highlighting should use correct language mode', () {
      final languageMode = htmlService.getReHighlightModeForExtension('css');
      
      expect(languageMode, isNotNull);
      expect(languageMode, equals(builtinAllLanguages['css']));
    });

    test('JavaScript syntax highlighting should use correct language mode', () {
      final languageMode = htmlService.getReHighlightModeForExtension('js');
      
      expect(languageMode, isNotNull);
      expect(languageMode, equals(builtinAllLanguages['javascript']));
    });

    test('JSON syntax highlighting should use correct language mode', () {
      final languageMode = htmlService.getReHighlightModeForExtension('json');
      
      expect(languageMode, isNotNull);
      expect(languageMode, equals(builtinAllLanguages['json']));
    });

    test('XML syntax highlighting should use correct language mode', () {
      final languageMode = htmlService.getReHighlightModeForExtension('xml');
      
      expect(languageMode, isNotNull);
      expect(languageMode, equals(builtinAllLanguages['xml']));
    });

    test('Unknown extensions should default to plaintext', () {
      final languageMode = htmlService.getReHighlightModeForExtension('unknown');
      
      expect(languageMode, isNotNull);
      expect(languageMode, equals(builtinAllLanguages['plaintext']));
    });

    test('All supported extensions should have valid language modes', () {
      final extensions = ['html', 'htm', 'css', 'js', 'json', 'xml', 'txt'];
      
      for (final ext in extensions) {
        final languageMode = htmlService.getReHighlightModeForExtension(ext);
        expect(languageMode, isNotNull, reason: 'Extension $ext should have a valid language mode');
      }
    });

    test('Language mode mapping should be consistent', () {
      // Test that the same extension always returns the same language mode
      final firstCall = htmlService.getReHighlightModeForExtension('html');
      final secondCall = htmlService.getReHighlightModeForExtension('html');
      
      expect(firstCall, equals(secondCall));
    });
  });
}