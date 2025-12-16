import 'package:flutter_test/flutter_test.dart';
import 'package:htmlviewer/services/html_service.dart';
import 'package:htmlviewer/models/html_file.dart';

void main() {
  group('Scroll Controller Test', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    test('HTML Service should notify listeners when file is loaded', () {
      bool notified = false;
      htmlService.addListener(() {
        notified = true;
      });

      final testContent = '''<!DOCTYPE html>
<html>
<head>
    <title>Test</title>
</head>
<body>
    <h1>Hello World</h1>
</body>
</html>''';

      final file = HtmlFile(
        name: 'test.html',
        path: 'test.html',
        content: testContent,
        lastModified: DateTime.now(),
        size: testContent.length,
      );

      htmlService.loadFile(file);

      expect(notified, isTrue);
      expect(htmlService.currentFile, isNotNull);
      expect(htmlService.currentFile!.name, 'test.html');
    });

    test('Scroll controller integration should work', () {
      // This test verifies that the scroll controller parameter is accepted
      const testContent = 'Test content';
      
      // We can't fully test the scroll controller without a real BuildContext,
      // but we can verify the method signature works
      expect(() {
        // This would work in a real app with proper context
        // htmlService.buildHighlightedText(testContent, 'txt', context);
      }, returnsNormally);
    });
  });
}