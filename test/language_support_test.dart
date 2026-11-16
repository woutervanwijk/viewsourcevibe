// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/source_viewer_editor.dart';
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
      // Test current supported extensions
      expect(SourceViewerEditor.getLanguageForExtension('html'), 'html');
      expect(SourceViewerEditor.getLanguageForExtension('htm'), 'html');
      expect(SourceViewerEditor.getLanguageForExtension('css'), 'css');
      expect(SourceViewerEditor.getLanguageForExtension('js'), 'javascript');
      expect(SourceViewerEditor.getLanguageForExtension('json'), 'json');
      expect(SourceViewerEditor.getLanguageForExtension('xml'), 'xml');
      expect(SourceViewerEditor.getLanguageForExtension('txt'), 'plaintext');
      expect(
          SourceViewerEditor.getLanguageForExtension('unknown'), 'plaintext');
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
