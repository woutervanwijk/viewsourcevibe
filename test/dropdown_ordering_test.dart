import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';

void main() {
  group('Content type dropdown ordering tests', () {
    
    test('HTML/XML should be first options after Automatic', () async {
      final htmlService = HtmlService();
      
      print('🔍 Testing dropdown ordering:');
      
      final contentTypes = htmlService.getAvailableContentTypes();
      
      print('  Available content types:');
      for (int i = 0; i < contentTypes.length && i < 10; i++) {
        print('    ${i + 1}. ${contentTypes[i]}');
      }
      
      // Verify Automatic is first
      expect(contentTypes[0], 'automatic');
      print('  ✅ First option is "automatic"');
      
      // Verify HTML/XML come right after Automatic
      final htmlIndex = contentTypes.indexOf('html');
      final xmlIndex = contentTypes.indexOf('xml');
      
      expect(htmlIndex, greaterThan(0), reason: 'HTML should exist in list');
      expect(xmlIndex, greaterThan(0), reason: 'XML should exist in list');
      
      // HTML and XML should be in positions 1 and 2 (right after Automatic)
      expect(htmlIndex, lessThan(3), reason: 'HTML should be in top 3 positions');
      expect(xmlIndex, lessThan(3), reason: 'XML should be in top 3 positions');
      
      // HTML should come before other common types
      final cssIndex = contentTypes.indexOf('css');
      final jsIndex = contentTypes.indexOf('javascript');
      
      if (cssIndex > 0) {
        expect(htmlIndex, lessThan(cssIndex), reason: 'HTML should come before CSS');
      }
      if (jsIndex > 0) {
        expect(htmlIndex, lessThan(jsIndex), reason: 'HTML should come before JavaScript');
      }
      
      print('  ✅ HTML/XML are in top positions after Automatic');
      print('  ✅ HTML comes before other common types');
    });
    
    test('Dropdown should contain all expected common types', () async {
      final htmlService = HtmlService();
      
      print('🔍 Testing presence of common types:');
      
      final contentTypes = htmlService.getAvailableContentTypes();
      
      // Essential types that should be present
      final essentialTypes = ['automatic', 'html', 'xml', 'css', 'javascript', 'typescript'];
      
      for (final type in essentialTypes) {
        expect(contentTypes.contains(type), true, reason: '$type should be in dropdown');
        print('  ✅ $type is present');
      }
      
      // Verify Automatic is first
      expect(contentTypes[0], 'automatic');
      
      // Verify HTML/XML are near the top
      final htmlIndex = contentTypes.indexOf('html');
      final xmlIndex = contentTypes.indexOf('xml');
      
      expect(htmlIndex, lessThan(5), reason: 'HTML should be in top 5');
      expect(xmlIndex, lessThan(5), reason: 'XML should be in top 5');
      
      print('  ✅ All essential types are present and properly ordered');
    });
    
    test('Dropdown ordering should be consistent', () async {
      final htmlService = HtmlService();
      
      print('🔍 Testing ordering consistency:');
      
      // Get ordering multiple times
      final ordering1 = htmlService.getAvailableContentTypes();
      final ordering2 = htmlService.getAvailableContentTypes();
      final ordering3 = htmlService.getAvailableContentTypes();
      
      // Should be identical
      expect(ordering1, ordering2);
      expect(ordering2, ordering3);
      
      print('  ✅ Ordering is consistent across multiple calls');
      
      // Verify specific ordering requirements
      final autoIndex = ordering1.indexOf('automatic');
      final htmlIndex = ordering1.indexOf('html');
      final xmlIndex = ordering1.indexOf('xml');
      final cssIndex = ordering1.indexOf('css');
      
      expect(autoIndex, 0);
      expect(htmlIndex, greaterThan(autoIndex));
      expect(xmlIndex, greaterThan(autoIndex));
      
      if (cssIndex > 0) {
        expect(htmlIndex, lessThan(cssIndex));
        expect(xmlIndex, lessThan(cssIndex));
      }
      
      print('  ✅ Specific ordering requirements met');
    });
    
    test('Common web development types should be prioritized', () async {
      final htmlService = HtmlService();
      
      print('🔍 Testing web development type prioritization:');
      
      final contentTypes = htmlService.getAvailableContentTypes();
      
      // Web development types that should be near the top
      final webDevTypes = ['html', 'xml', 'css', 'javascript', 'typescript', 'json'];
      
      // Find positions of web dev types
      final positions = {};
      for (final type in webDevTypes) {
        if (contentTypes.contains(type)) {
          positions[type] = contentTypes.indexOf(type);
        }
      }
      
      print('  Web development type positions:');
      positions.forEach((type, position) {
        print('    $type: position $position');
      });
      
      // All web dev types should be in reasonable positions
      for (final entry in positions.entries) {
        final type = entry.key;
        final position = entry.value;
        
        expect(position, lessThan(15), reason: '$type should be in top 15 positions');
        print('    ✅ $type is in reasonable position ($position)');
      }
      
      // HTML/XML should be earliest among web dev types
      final htmlPosition = positions['html'] ?? 999;
      final xmlPosition = positions['xml'] ?? 999;
      
      for (final entry in positions.entries) {
        if (entry.key != 'html' && entry.key != 'xml') {
          expect(htmlPosition, lessThan(entry.value), 
            reason: 'HTML should come before ${entry.key}');
          expect(xmlPosition, lessThan(entry.value), 
            reason: 'XML should come before ${entry.key}');
        }
      }
      
      print('  ✅ HTML/XML are prioritized among web development types');
    });
    
    test('Dropdown should handle missing types gracefully', () async {
      final htmlService = HtmlService();
      
      print('🔍 Testing graceful handling of missing types:');
      
      final contentTypes = htmlService.getAvailableContentTypes();
      
      // The method should not crash if some expected types are missing
      // It should just skip them
      
      expect(contentTypes, isNotEmpty);
      expect(contentTypes[0], 'automatic');
      
      // Should contain at least the basic types
      expect(contentTypes.contains('automatic'), true);
      
      // If html/xml are available, they should be near top
      if (contentTypes.contains('html')) {
        final htmlIndex = contentTypes.indexOf('html');
        expect(htmlIndex, lessThan(5));
        print('  ✅ HTML is properly positioned when available');
      }
      
      if (contentTypes.contains('xml')) {
        final xmlIndex = contentTypes.indexOf('xml');
        expect(xmlIndex, lessThan(5));
        print('  ✅ XML is properly positioned when available');
      }
      
      print('  ✅ Gracefully handles available types');
    });
  });
}