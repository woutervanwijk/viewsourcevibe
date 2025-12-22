import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';

void main() {
  group('Improved file type detection tests', () {
    
    test('HTML detection should be prioritized over JavaScript', () async {
      final htmlService = HtmlService();
      
      // Test case: HTML file with JavaScript content
      const htmlWithJs = '''<!DOCTYPE html>
<html>
<head>
    <title>Test Page</title>
    <script>
        function test() {
            const x = 5;
            let y = 10;
            return x + y;
        }
    </script>
</head>
<body>
    <h1>Hello World</h1>
    <div id="content">Content here</div>
</body>
</html>''';
      
      print('🔍 Testing HTML detection with JavaScript content:');
      
      // Test the improved content detection
      final result = htmlService.generateDescriptiveFilename(
          Uri.parse('https://example.com/test.html'),
          htmlWithJs
      );
      
      print('  Result: $result');
      
      // Should detect as HTML, not JavaScript
      expect(result, contains('HTML'));
      expect(result, isNot(contains('JavaScript')));
      
      print('  ✅ Correctly detected as HTML despite JavaScript content');
    });
    
    test('Pure JavaScript files should still be detected correctly', () async {
      final htmlService = HtmlService();
      
      const pureJs = '''function calculateSum(a, b) {
    const result = a + b;
    let message = `The sum is ${result}`;
    return { result, message };
}

class Calculator {
    static add(x, y) {
        return x + y;
    }
}

export { calculateSum, Calculator };''';
      
      print('🔍 Testing pure JavaScript detection:');
      
      final result = htmlService.generateDescriptiveFilename(
          Uri.parse('https://example.com/script.js'),
          pureJs
      );
      
      print('  Result: $result');
      
      // Should detect as JavaScript
      expect(result, contains('JavaScript'));
      expect(result, isNot(contains('HTML')));
      
      print('  ✅ Correctly detected as JavaScript');
    });
    
    test('HTML detection with various HTML patterns', () async {
      final htmlService = HtmlService();
      
      final testCases = [
        {
          'name': 'Basic HTML',
          'content': '<!DOCTYPE html><html><head></head><body><h1>Hello</h1></body></html>',
          'expected': 'HTML'
        },
        {
          'name': 'HTML5 doctype',
          'content': '<!doctype html><html><body>Content</body></html>',
          'expected': 'HTML'
        },
        {
          'name': 'HTML with divs',
          'content': '<div class="container"><span>Text</span></div>',
          'expected': 'HTML'
        },
        {
          'name': 'HTML with scripts',
          'content': '<html><head><script src="app.js"></script></head><body></body></html>',
          'expected': 'HTML'
        },
        {
          'name': 'HTML with styles',
          'content': '<html><head><style>body { margin: 0; }</style></head><body></body></html>',
          'expected': 'HTML'
        },
        {
          'name': 'HTML with closing tags',
          'content': '<html><body><p>Content</p></body></html>',
          'expected': 'HTML'
        },
      ];
      
      print('🔍 Testing various HTML patterns:');
      
      for (final testCase in testCases) {
        final name = testCase['name']!;
        final content = testCase['content']!;
        final expected = testCase['expected']!;
        
        print('  Testing: $name');
        
        final result = htmlService.generateDescriptiveFilename(
            Uri.parse('https://example.com/test.html'),
            content
        );
        
        expect(result, contains(expected));
        print('    ✅ Detected as $expected');
      }
    });
    
    test('JavaScript detection should be more specific', () async {
      final htmlService = HtmlService();
      
      final jsPatterns = [
        {
          'name': 'Function with braces',
          'content': 'function test() { return true; }',
          'shouldDetect': true
        },
        {
          'name': 'Const with assignment',
          'content': 'const x = 5;',
          'shouldDetect': true
        },
        {
          'name': 'Let with assignment',
          'content': 'let y = 10;',
          'shouldDetect': true
        },
        {
          'name': 'Arrow function',
          'content': 'const fn = () => { return 42; };',
          'shouldDetect': true
        },
        {
          'name': 'Class with extends',
          'content': 'class MyClass extends BaseClass { }',
          'shouldDetect': true
        },
        {
          'name': 'Import statement',
          'content': 'import { Component } from "react";',
          'shouldDetect': true
        },
        {
          'name': 'Just const keyword',
          'content': 'const',
          'shouldDetect': false // Not enough context
        },
        {
          'name': 'Just function keyword',
          'content': 'function',
          'shouldDetect': false // Not enough context
        },
      ];
      
      print('🔍 Testing JavaScript detection specificity:');
      
      for (final pattern in jsPatterns) {
        final name = pattern['name']!;
        final content = pattern['content']!;
        final shouldDetect = pattern['shouldDetect']!;
        
        print('  Testing: $name');
        
        final result = htmlService.generateDescriptiveFilename(
            Uri.parse('https://example.com/script.js'),
            content
        );
        
        final detectedAsJs = result.contains('JavaScript');
        
        if (shouldDetect) {
          expect(detectedAsJs, true, reason: 'Should detect as JavaScript');
          print('    ✅ Correctly detected as JavaScript');
        } else {
          expect(detectedAsJs, false, reason: 'Should not detect as JavaScript');
          print('    ✅ Correctly not detected as JavaScript');
        }
      }
    });
    
    test('CSS detection should work correctly', () async {
      final htmlService = HtmlService();
      
      const cssContent = '''body {
    margin: 0;
    padding: 0;
    font-family: Arial, sans-serif;
}

@media (max-width: 600px) {
    body {
        font-size: 14px;
    }
}

/* CSS comment */
.container {
    width: 100%;
}''';
      
      print('🔍 Testing CSS detection:');
      
      final result = htmlService.generateDescriptiveFilename(
          Uri.parse('https://example.com/styles.css'),
          cssContent
      );
      
      print('  Result: $result');
      
      expect(result, contains('CSS'));
      expect(result, isNot(contains('HTML')));
      expect(result, isNot(contains('JavaScript')));
      
      print('  ✅ Correctly detected as CSS');
    });
    
    test('Extension-based detection should work correctly', () async {
      final htmlService = HtmlService();
      
      final testCases = [
        {
          'extension': 'html',
          'expectedLanguage': 'html'
        },
        {
          'extension': 'htm',
          'expectedLanguage': 'html'
        },
        {
          'extension': 'js',
          'expectedLanguage': 'javascript'
        },
        {
          'extension': 'css',
          'expectedLanguage': 'css'
        },
        {
          'extension': 'json',
          'expectedLanguage': 'json'
        },
        {
          'extension': 'xml',
          'expectedLanguage': 'xml'
        },
        {
          'extension': 'txt',
          'expectedLanguage': 'plaintext'
        },
      ];
      
      print('🔍 Testing extension-based detection:');
      
      for (final testCase in testCases) {
        final extension = testCase['extension']!;
        final expectedLanguage = testCase['expectedLanguage']!;
        
        print('  Testing .$extension extension:');
        
        final language = htmlService.getLanguageForExtension(extension);
        
        print('    Detected language: $language');
        
        // For HTML, we expect either 'html' or 'xml' (both are acceptable)
        if (expectedLanguage == 'html') {
          expect(language, anyOf(['html', 'xml']));
        } else {
          expect(language, expectedLanguage);
        }
        
        print('    ✅ Correctly detected as $language');
      }
    });
    
    test('Real-world HTML files should be detected correctly', () async {
      final htmlService = HtmlService();
      
      // Test with a realistic HTML file that contains JavaScript
      const realisticHtml = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Realistic HTML Page</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>Welcome to My Website</h1>
            <nav>
                <ul>
                    <li><a href="/">Home</a></li>
                    <li><a href="/about">About</a></li>
                    <li><a href="/contact">Contact</a></li>
                </ul>
            </nav>
        </header>
        
        <main>
            <section>
                <h2>About Us</h2>
                <p>This is a realistic HTML page with various elements.</p>
            </section>
            
            <section>
                <h2>JavaScript Example</h2>
                <button id="clickMe">Click Me</button>
                <div id="result"></div>
                
                <script>
                    document.getElementById('clickMe').addEventListener('click', function() {
                        const resultDiv = document.getElementById('result');
                        let counter = 0;
                        
                        const interval = setInterval(() => {
                            counter++;
                            resultDiv.textContent = `Clicked ${counter} times`;
                            
                            if (counter >= 10) {
                                clearInterval(interval);
                                resultDiv.textContent = 'Stopped at 10 clicks';
                            }
                        }, 1000);
                    });
                    
                    // Modern JavaScript features
                    const user = {
                        name: 'John Doe',
                        age: 30,
                        ...{ location: 'New York' }
                    };
                    
                    console.log(`User: ${user.name}, Age: ${user.age}`);
                </script>
            </section>
        </main>
        
        <footer>
            <p>&copy; 2023 My Website. All rights reserved.</p>
        </footer>
    </div>
    
    <script src="app.js" defer></script>
    <script src="analytics.js" async></script>
</body>
</html>''';
      
      print('🔍 Testing realistic HTML file with JavaScript:');
      
      final result = htmlService.generateDescriptiveFilename(
          Uri.parse('https://example.com/index.html'),
          realisticHtml
      );
      
      print('  Result: $result');
      
      // Should be detected as HTML, not JavaScript
      expect(result, contains('HTML'));
      expect(result, isNot(contains('JavaScript')));
      
      print('  ✅ Realistic HTML file correctly detected as HTML');
    });
    
    test('Edge cases and mixed content', () async {
      final htmlService = HtmlService();
      
      final edgeCases = [
        {
          'name': 'HTML with inline JS in attributes',
          'content': '<button onclick="const x = 5; alert(x);">Click</button>',
          'expected': 'HTML'
        },
        {
          'name': 'HTML with JS in event handlers',
          'content': '<div onload="function test() { return true; }">Content</div>',
          'expected': 'HTML'
        },
        {
          'name': 'Minimal HTML',
          'content': '<!DOCTYPE html><html><body>Hi</body></html>',
          'expected': 'HTML'
        },
        {
          'name': 'HTML fragment',
          'content': '<div class="test"><span>Text</span></div>',
          'expected': 'HTML'
        },
      ];
      
      print('🔍 Testing edge cases and mixed content:');
      
      for (final edgeCase in edgeCases) {
        final name = edgeCase['name']!;
        final content = edgeCase['content']!;
        final expected = edgeCase['expected']!;
        
        print('  Testing: $name');
        
        final result = htmlService.generateDescriptiveFilename(
            Uri.parse('https://example.com/test.html'),
            content
        );
        
        expect(result, contains(expected));
        print('    ✅ Correctly detected as $expected');
      }
    });
  });
}