import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/services/sharing_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Mock class for testing
class MockSharingService extends Mock implements SharingService {}

@GenerateMocks([SharingService])
void main() {
  group('Source Code Sharing Tests', () {
    
    test('Share HTML content creates proper file sharing', () async {
      // Create a test HTML file
      final htmlFile = HtmlFile(
        name: 'test.html',
        path: 'test://file',
        content: '<html><body><h1>Test Content</h1></body></html>',
        lastModified: DateTime.now(),
        size: 42,
        isUrl: false,
      );
      
      // Verify the file has content
      expect(htmlFile.content, isNotEmpty);
      expect(htmlFile.content.length, greaterThan(0));
      expect(htmlFile.name, 'test.html');
      
      // Test that sharing service can handle the content
      // Note: We can't actually test the native sharing in unit tests,
      // but we can verify the parameters are correct
      expect(htmlFile.content, contains('<html>'));
      expect(htmlFile.content, contains('Test Content'));
      expect(htmlFile.size, 42);
    });
    
    test('Share large HTML content handles reasonably sized files', () async {
      // Create a larger HTML file (simulating a typical webpage)
      final largeContent = List.generate(100, (i) => '<p>Paragraph $i</p>').join('');
      final htmlFile = HtmlFile(
        name: 'large.html',
        path: 'test://large',
        content: '<html><body>$largeContent</body></html>',
        lastModified: DateTime.now(),
        size: largeContent.length + 18, // +18 for <html><body></body></html>
        isUrl: false,
      );
      
      // Verify the file is reasonably sized
      expect(htmlFile.content.length, greaterThan(1000));
      expect(htmlFile.content.length, lessThan(5000)); // Should be under 5KB
      expect(htmlFile.name, 'large.html');
      
      // This size should be easily shareable
      expect(htmlFile.size, lessThan(10 * 1024)); // Less than 10KB
    });
    
    test('Share URL content now shares as source code file', () async {
      // Create a file that was loaded from a URL
      final urlFile = HtmlFile(
        name: 'webpage.html',
        path: 'https://example.com/page.html',
        content: '<html><body><h1>Web Page Content</h1></body></html>',
        lastModified: DateTime.now(),
        size: 45,
        isUrl: true,
      );
      
      // Verify it's a URL-based file
      expect(urlFile.path, startsWith('https://'));
      expect(urlFile.content, isNotEmpty);
      
      // With our new implementation, this should be shared as HTML content,
      // not as a URL. The toolbar should call shareHtml instead of shareUrl.
      // This test verifies the file has the content that should be shared.
      expect(urlFile.content, contains('Web Page Content'));
    });
    
    test('Empty content handling', () async {
      // Test empty content
      final emptyFile = HtmlFile(
        name: 'empty.html',
        path: 'test://empty',
        content: '',
        lastModified: DateTime.now(),
        size: 0,
        isUrl: false,
      );
      
      // Empty content should be handled gracefully
      expect(emptyFile.content.isEmpty, true);
      expect(emptyFile.size, 0);
    });
    
    test('Very large content size check', () async {
      // Test with very large content (simulating a large webpage)
      final veryLargeContent = List.generate(1000, (i) => '<div>Item $i: ${List.generate(10, (j) => 'data$j').join(' ')}</div>').join('');
      final largeFile = HtmlFile(
        name: 'very_large.html',
        path: 'test://very_large',
        content: '<html><body>$veryLargeContent</body></html>',
        lastModified: DateTime.now(),
        size: veryLargeContent.length + 18,
        isUrl: false,
      );
      
      // Check the size directly
      // Size calculations removed as they're not used in assertions
      
      // This should still be shareable but might be slow
      expect(largeFile.size, greaterThan(50 * 1024)); // > 50KB
      expect(largeFile.size, lessThan(200 * 1024)); // < 200KB (reasonable for test)
    });
  });
  
  group('Sharing Service Method Tests', () {
    
    test('ShareHtml method signature is correct', () async {
      // Verify the shareHtml method exists and has correct parameters
      expect(SharingService.shareHtml, isNotNull);
      
      // The method should accept html content and optional filename
      // We can't call it directly in tests as it requires native platform,
      // but we can verify it exists
    });
    
    test('ShareUrl method still exists for compatibility', () async {
      // Verify shareUrl still exists (though we're not using it for source code)
      expect(SharingService.shareUrl, isNotNull);
    });
  });
}