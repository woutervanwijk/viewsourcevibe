import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';

void main() {
  group('HTML vs CSS detection tests', () {
    
    test('HTML files should not be detected as CSS', () async {
      final htmlService = HtmlService();
      
      // Test various HTML files that were previously misdetected as CSS
      final htmlExamples = [
        {
          'name': 'Basic HTML',
          'content': '<!DOCTYPE html><html><head></head><body><h1>Hello</h1></body></html>',
        },
        {
          'name': 'HTML with inline styles',
          'content': '<html><head><style>body { margin: 0; }</style></head><body></body></html>',
        },
        {
          'name': 'HTML with script containing braces',
          'content': '<html><body><script>function test() { return { key: "value" }; }</script></body></html>',
        },
        {
          'name': 'HTML with CSS-like content in attributes',
          'content': '<div style="color: red; font-size: 14px;">Text</div>',
        },
        {
          'name': 'HTML with JavaScript objects',
          'content': '<script>const config = { theme: "dark", size: "large" };</script>',
        },
        {
          'name': 'HTML with media queries in style',
          'content': '<style>@media (max-width: 600px) { body { font-size: 14px; } }</style>',
        },
      ];
      
      print('🔍 Testing HTML files that should NOT be detected as CSS:');
      
      for (final example in htmlExamples) {
        final name = example['name']!;
        final content = example['content']!;
        
        print('  Testing: $name');
        
        final result = htmlService.generateDescriptiveFilename(
            Uri.parse('https://example.com/test.html'),
            content
        );
        
        print('    Result: $result');
        
        // Should be detected as HTML, not CSS
        // With the new filename generation, it should have a proper .html extension
        expect(result, endsWith('.html'));
        expect(result, isNot(contains('CSS')));
        
        print('    ✅ Correctly detected as HTML');
      }
    });
    
    test('Pure CSS files should still be detected correctly', () async {
      final htmlService = HtmlService();
      
      // Test pure CSS content
      final cssExamples = [
        {
          'name': 'Basic CSS',
          'content': 'body { margin: 0; padding: 0; }',
        },
        {
          'name': 'CSS with media queries',
          'content': '@media (max-width: 600px) { body { font-size: 14px; } }',
        },
        {
          'name': 'CSS with imports',
          'content': '@import url("reset.css"); body { color: #333; }',
        },
        {
          'name': 'CSS with keyframes',
          'content': '@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }',
        },
        {
          'name': 'CSS with font-face',
          'content': '@font-face { font-family: "MyFont"; src: url("font.woff2"); }',
        },
        {
          'name': 'Complex CSS',
          'content': '.container { width: 100%; max-width: 1200px; margin: 0 auto; padding: 20px; }',
        },
      ];
      
      print('🔍 Testing pure CSS files that should be detected as CSS:');
      
      for (final example in cssExamples) {
        final name = example['name']!;
        final content = example['content']!;
        
        print('  Testing: $name');
        
        final result = htmlService.generateDescriptiveFilename(
            Uri.parse('https://example.com/test.css'),
            content
        );
        
        print('    Result: $result');
        
        // Should be detected as CSS, not HTML
        // With the new filename generation, it should preserve the .css extension
        expect(result, endsWith('.css'));
        expect(result, isNot(contains('HTML')));
        
        print('    ✅ Correctly detected as CSS');
      }
    });
    
    test('Mixed content should be detected correctly', () async {
      final htmlService = HtmlService();
      
      // Test files with mixed HTML/CSS/JS content
      final mixedExamples = [
        {
          'name': 'HTML with all types',
          'content': '''<!DOCTYPE html>
<html>
<head>
    <style>
        body { margin: 0; }
        @media (max-width: 600px) { body { padding: 10px; } }
    </style>
</head>
<body>
    <div class="container">Content</div>
    <script>
        const config = { theme: "dark" };
        function init() { console.log("Initialized"); }
    </script>
</body>
</html>''',
          'expected': 'HTML'
        },
        {
          'name': 'HTML-heavy mixed file',
          'content': '''<html>
<body>
    <header><h1>Title</h1></header>
    <main>
        <section><p>Content</p></section>
        <aside><div>Sidebar</div></aside>
    </main>
    <footer><p>Footer</p></footer>
    <style>body { font-family: Arial; }</style>
    <script>console.log("Loaded");</script>
</body>
</html>''',
          'expected': 'HTML'
        },
      ];
      
      print('🔍 Testing mixed content files:');
      
      for (final example in mixedExamples) {
        final name = example['name']!;
        final content = example['content']!;
        final expected = example['expected']!;
        
        print('  Testing: $name');
        
        final result = htmlService.generateDescriptiveFilename(
            Uri.parse('https://example.com/test.html'),
            content
        );
        
        print('    Result: $result');
        
        // Should be detected as expected type
        // With the new filename generation, it should have the proper extension
        if (expected == 'HTML') {
          expect(result, endsWith('.html'));
        } else if (expected == 'CSS') {
          expect(result, endsWith('.css'));
        } else if (expected == 'JavaScript') {
          expect(result, endsWith('.js'));
        }
        
        print('    ✅ Correctly detected as $expected');
      }
    });
    
    test('Edge cases that previously caused misdetection', () async {
      final htmlService = HtmlService();
      
      // Specific edge cases that might have caused issues
      final edgeCases = [
        {
          'name': 'HTML with CSS comment',
          'content': '<html><head><style>/* css comment */ body { color: red; }</style></head><body></body></html>',
          'expected': 'HTML'
        },
        {
          'name': 'HTML with body style',
          'content': '<html><body style="background: #fff; color: #333;">Content</body></html>',
          'expected': 'HTML'
        },
        {
          'name': 'HTML with script containing CSS-like objects',
          'content': '<script>const styles = { body: { margin: 0 }, header: { padding: "20px" } };</script>',
          'expected': 'HTML'
        },
        {
          'name': 'Minimal CSS that looks like JS',
          'content': 'body { margin: 0; }',
          'expected': 'CSS'
        },
      ];
      
      print('🔍 Testing edge cases:');
      
      for (final edgeCase in edgeCases) {
        final name = edgeCase['name']!;
        final content = edgeCase['content']!;
        final expected = edgeCase['expected']!;
        
        print('  Testing: $name');
        
        final result = htmlService.generateDescriptiveFilename(
            Uri.parse('https://example.com/test.html'),
            content
        );
        
        print('    Result: $result');
        
        // Should be detected as expected type
        // With the new filename generation, it should have the proper extension
        if (expected == 'HTML') {
          expect(result, endsWith('.html'));
        } else if (expected == 'CSS') {
          expect(result, endsWith('.css'));
        } else if (expected == 'JavaScript') {
          expect(result, endsWith('.js'));
        }
        
        print('    ✅ Correctly detected as $expected');
      }
    });
    
    test('Detection priority verification', () async {
      final htmlService = HtmlService();
      
      print('🔍 Testing detection priority (HTML > CSS > JS):');
      
      // HTML should always win over CSS
      final htmlWithCssLikeContent = '<html><body><div style="color: red;">Text</div></body></html>';
      final htmlResult = htmlService.generateDescriptiveFilename(
          Uri.parse('https://example.com/test.html'),
          htmlWithCssLikeContent
      );
      
      // With the new filename generation, it should preserve the .html extension
      expect(htmlResult, endsWith('.html'));
      expect(htmlResult, isNot(contains('CSS')));
      print('  ✅ HTML prioritized over CSS');
      
      // CSS should win over JS when both are present but no HTML
      final cssWithJsLikeContent = 'body { margin: 0; } const x = 5;';
      // This is a bit ambiguous, but CSS patterns should take precedence
      final cssResult = htmlService.generateDescriptiveFilename(
          Uri.parse('https://example.com/test.css'),
          cssWithJsLikeContent
      );
      
      // This might be CSS or something else, but shouldn't be HTML
      expect(cssResult, isNot(contains('HTML')));
      print('  ✅ Non-HTML content doesn\'t get detected as HTML');
    });
  });
}