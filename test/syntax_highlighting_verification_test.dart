import 'package:flutter_test/flutter_test.dart';
import 'package:htmlviewer/services/html_service.dart';
import 'package:highlight/languages/all.dart' show allLanguages;

void main() {
  group('Syntax Highlighting Verification Tests', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    test('HTML syntax highlighting should use correct language mode', () {
      final languageMode = htmlService.getLanguageModeForExtension('html');
      
      expect(languageMode, isNotNull);
      expect(languageMode, equals(allLanguages['htmlbars']));
    });

    test('CSS syntax highlighting should use correct language mode', () {
      final languageMode = htmlService.getLanguageModeForExtension('css');
      
      expect(languageMode, isNotNull);
      expect(languageMode, equals(allLanguages['css']));
    });

    test('JavaScript syntax highlighting should use correct language mode', () {
      final languageMode = htmlService.getLanguageModeForExtension('js');
      
      expect(languageMode, isNotNull);
      expect(languageMode, equals(allLanguages['javascript']));
    });

    test('JSON syntax highlighting should use correct language mode', () {
      final languageMode = htmlService.getLanguageModeForExtension('json');
      
      expect(languageMode, isNotNull);
      expect(languageMode, equals(allLanguages['json']));
    });

    test('XML syntax highlighting should use correct language mode', () {
      final languageMode = htmlService.getLanguageModeForExtension('xml');
      
      expect(languageMode, isNotNull);
      expect(languageMode, equals(allLanguages['xml']));
    });

    test('Unknown extensions should default to plaintext', () {
      final languageMode = htmlService.getLanguageModeForExtension('unknown');
      
      expect(languageMode, isNotNull);
      expect(languageMode, equals(allLanguages['plaintext']));
    });

    test('All supported extensions should have valid language modes', () {
      final extensions = ['html', 'htm', 'css', 'js', 'json', 'xml', 'txt'];
      
      for (final ext in extensions) {
        final languageMode = htmlService.getLanguageModeForExtension(ext);
        expect(languageMode, isNotNull, reason: 'Extension $ext should have a valid language mode');
      }
    });

    test('Language mode mapping should be consistent', () {
      // Test that the same extension always returns the same language mode
      final firstCall = htmlService.getLanguageModeForExtension('html');
      final secondCall = htmlService.getLanguageModeForExtension('html');
      
      expect(firstCall, equals(secondCall));
    });
  });
}