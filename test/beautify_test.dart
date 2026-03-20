import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/utils/code_beautifier.dart';

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Beautify functionality tests', () {
    test('Beautify toggle should work correctly', () async {
      final htmlService = HtmlService();
      
      // Initially beautify should be disabled
      expect(htmlService.isBeautifyEnabled, false);
      
      // Toggle beautify on
      await htmlService.toggleIsBeautifyEnabled();
      expect(htmlService.isBeautifyEnabled, true);
      
      // Toggle beautify off
      await htmlService.toggleIsBeautifyEnabled();
      expect(htmlService.isBeautifyEnabled, false);
    });
    
    test('Code beautifier should format HTML correctly', () async {
      const uglyHtml = '<html><body><p>Test</p></body></html>';
      
      final beautified = await CodeBeautifier.beautifyAsync(uglyHtml, 'html');
      
      expect(beautified, isNot(equals(uglyHtml)));
      expect(beautified, contains('\n'));
      expect(beautified.trim(), startsWith('<html>'));
    });
  });
}