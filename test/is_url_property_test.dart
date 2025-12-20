import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/html_file.dart';

void main() {
  group('HtmlFile isUrl Property Tests', () {
    
    test('HtmlFile should have isUrl property defaulting to false', () {
      final file = HtmlFile(
        name: 'test.html',
        path: '/path/to/file.html',
        content: '<html><body>Test</body></html>',
        lastModified: DateTime.now(),
        size: 32,
      );
      
      expect(file.isUrl, false);
    });

    test('HtmlFile should allow setting isUrl to true', () {
      final file = HtmlFile(
        name: 'test.html',
        path: 'https://example.com/test.html',
        content: '<html><body>Test</body></html>',
        lastModified: DateTime.now(),
        size: 32,
        isUrl: true,
      );
      
      expect(file.isUrl, true);
    });

    test('HtmlFile.fromContent should default isUrl to false', () {
      final file = HtmlFile.fromContent('test.html', '<html><body>Test</body></html>');
      
      expect(file.isUrl, false);
    });

    test('HtmlFile.fromContent should allow setting isUrl to true', () {
      final file = HtmlFile.fromContent('test.html', '<html><body>Test</body></html>', isUrl: true);
      
      expect(file.isUrl, true);
    });

    test('URL-loaded files should have isUrl=true', () {
      final urlFile = HtmlFile(
        name: 'webpage.html',
        path: 'https://example.com/page.html',
        content: '<html><body><h1>Web Page</h1></body></html>',
        lastModified: DateTime.now(),
        size: 45,
        isUrl: true,
      );
      
      expect(urlFile.isUrl, true);
      expect(urlFile.path, 'https://example.com/page.html');
    });

    test('Local files should have isUrl=false', () {
      final localFile = HtmlFile(
        name: 'local.html',
        path: '/path/to/local.html',
        content: '<html><body><h1>Local File</h1></body></html>',
        lastModified: DateTime.now(),
        size: 40,
        isUrl: false,
      );
      
      expect(localFile.isUrl, false);
      expect(localFile.path, '/path/to/local.html');
    });
  });
}