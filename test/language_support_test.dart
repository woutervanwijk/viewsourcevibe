// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:htmlviewer/services/html_service.dart';
import 'package:re_highlight/languages/all.dart';

void main() {
  group('Language Support Test', () {
    test('Check available languages in re_highlight', () {
      // Print all available languages for analysis
      print('Available languages in re_highlight:');
      builtinAllLanguages.forEach((key, value) {
        print('  - $key');
      });

      // Verify we have the expected languages
      expect(builtinAllLanguages.containsKey('xml'), isTrue);
      expect(builtinAllLanguages.containsKey('css'), isTrue);
      expect(builtinAllLanguages.containsKey('javascript'), isTrue);
      expect(builtinAllLanguages.containsKey('json'), isTrue);
      expect(builtinAllLanguages.containsKey('plaintext'), isTrue);
    });

    test('HTML Service should support common file extensions', () {
      final htmlService = HtmlService();

      // Test current supported extensions
      expect(htmlService.getLanguageForExtension('html'), 'xml');
      expect(htmlService.getLanguageForExtension('htm'), 'xml');
      expect(htmlService.getLanguageForExtension('css'), 'css');
      expect(htmlService.getLanguageForExtension('js'), 'javascript');
      expect(htmlService.getLanguageForExtension('json'), 'json');
      expect(htmlService.getLanguageForExtension('xml'), 'xml');
      expect(htmlService.getLanguageForExtension('txt'), 'plaintext');
      expect(htmlService.getLanguageForExtension('unknown'), 'plaintext');
    });

    test('HTML Service should get modes for supported languages', () {
      final htmlService = HtmlService();

      // Test that we can get modes for the languages we support
      final xmlMode = htmlService.getReHighlightModeForExtension('html');
      expect(xmlMode, isNotNull);

      final cssMode = htmlService.getReHighlightModeForExtension('css');
      expect(cssMode, isNotNull);

      final jsMode = htmlService.getReHighlightModeForExtension('js');
      expect(jsMode, isNotNull);
    });
  });
}
