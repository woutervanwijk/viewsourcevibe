import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/shared_content_manager.dart';
import 'package:view_source_vibe/services/sharing_service.dart';
import 'package:flutter/material.dart';

void main() {
  group('iOS Share Extension Comprehensive Tests', () {
    
    test('Should handle iOS share extension URL schemes correctly', () async {
      // Test the URL schemes that the iOS share extension will use
      final testCases = [
        {
          'scheme': 'viewsourcevibe',
          'host': 'open',
          'query': 'url=https://example.com',
          'expectedType': 'url',
          'expectedContent': 'https://example.com'
        },
        {
          'scheme': 'viewsourcevibe',
          'host': 'text',
          'query': 'content=Hello%20World',
          'expectedType': 'text',
          'expectedContent': 'Hello World'
        },
        {
          'scheme': 'viewsourcevibe',
          'host': 'file',
          'query': 'path=file:///Users/test/file.html',
          'expectedType': 'file',
          'expectedFilePath': 'file:///Users/test/file.html'
        }
      ];
      
      for (final testCase in testCases) {
        final uriString = '${testCase['scheme']}://${testCase['host']}?${testCase['query']}';
        final uri = Uri.parse(uriString);
        
        expect(uri.scheme, testCase['scheme']);
        expect(uri.host, testCase['host']);
        
        if (testCase['expectedType'] == 'url') {
          expect(uri.queryParameters['url'], testCase['expectedContent']);
        } else if (testCase['expectedType'] == 'text') {
          expect(uri.queryParameters['content'], testCase['expectedContent']);
        } else if (testCase['expectedType'] == 'file') {
          expect(uri.queryParameters['path'], testCase['expectedFilePath']);
        }
      }
    });

    test('Should handle iOS file paths correctly', () async {
      // Test various iOS file path formats
      final iosFilePaths = [
        'file:///Users/wouter/Library/Developer/CoreSimulator/Devices/2C19D11B-BEF5-45B1-81FD-0919B6BFB505/data/Containers/Data/Application/DDE7D1D9-790B-429E-A07B-BCAE79AADB4F/tmp/info.wouter.sourceviewer-Inbox/sample.py',
        'file///var/mobile/Containers/Data/Application/app/file.txt',
        'file://localhost/Users/test/file.html',
        '/Users/test/file.css'
      ];
      
      for (final filePath in iosFilePaths) {
        expect(SharingService.isFilePath(filePath), true);
        
        // Test file name extraction
        final fileName = SharedContentManager.extractFileNameFromPath(filePath);
        expect(fileName.isNotEmpty, true);
        expect(fileName.contains('/'), false); // Should not contain path separators
      }
    });

    test('Should handle iOS URL encoding correctly', () async {
      // Test URL encoding that iOS share extension will use
      final encodedText = 'Hello%20World%21%20This%20is%20a%20test.';
      final decodedText = Uri.decodeComponent(encodedText);
      
      expect(decodedText, 'Hello World! This is a test.');
      
      // Test file path encoding
      final encodedFilePath = 'file:///Users/test/My%20File.html';
      final decodedFilePath = Uri.decodeComponent(encodedFilePath);
      
      expect(decodedFilePath, 'file:///Users/test/My File.html');
    });

    test('Should handle various iOS content types', () async {
      // Test the content types that iOS share extension supports
      final contentTypes = [
        {
          'type': 'url',
          'content': 'https://example.com',
          'isUrl': true
        },
        {
          'type': 'file',
          'filePath': '/Users/test/file.html',
          'isFilePath': true
        }
      ];
      
      for (final contentType in contentTypes) {
        if (contentType['type'] == 'file') {
          expect(SharingService.isFilePath(contentType['filePath'] as String), true);
        } else if (contentType['type'] == 'url') {
          expect(SharingService.isUrl(contentType['content'] as String), true);
        }
      }
    });

    test('Should handle iOS share extension error cases', () async {
      // Test error cases that might occur in iOS share extension
      final errorCases = [
        '', // Empty string
        '   ', // Whitespace only
      ];
      
      for (final errorCase in errorCases) {
        // Empty strings and whitespace should not be detected as URLs
        expect(SharingService.isUrl(errorCase), false);
      }
    });

    test('Should handle iOS share extension complex scenarios', () async {
      // Test complex scenarios that might occur in iOS share extension
      
      // Test 1: File path that contains URL-like parts - should be detected as file path
      final filePathWithUrl = '/Users/test/www.example.com/file.html';
      expect(SharingService.isFilePath(filePathWithUrl), true);
      expect(SharingService.isUrl(filePathWithUrl), false);
      
      // Test 2: Complex file path with spaces and special characters
      final complexFilePath = '/Users/test/My Documents/Project Files/source code.html';
      expect(SharingService.isFilePath(complexFilePath), true);
      
      // Test 3: File name extraction from complex paths
      final fileName = SharedContentManager.extractFileNameFromPath(complexFilePath);
      expect(fileName, 'source code.html');
    });

    test('Should handle iOS share extension content processing', () async {
      // Test the content processing flow that would happen in iOS share extension
      
      // Simulate iOS share extension data
      final iosSharedData = [
        {
          'url': 'https://example.com'
        },
        {
          'text': 'Hello World'
        },
        {
          'file': 'file:///Users/test/file.html'
        }
      ];
      
      for (final data in iosSharedData) {
        if (data.containsKey('url')) {
          expect(SharingService.isUrl(data['url'] as String), true);
        } else if (data.containsKey('text')) {
          expect((data['text'] as String).isNotEmpty, true);
        } else if (data.containsKey('file')) {
          expect(SharingService.isFilePath(data['file'] as String), true);
        }
      }
    });

    test('Should handle URL scheme parsing for share extension', () async {
      // Test URL scheme parsing that would be used by the share extension
      final urlSchemes = [
        'viewsourcevibe://open?url=https://example.com',
        'viewsourcevibe://text?content=Hello%20World',
        'viewsourcevibe://file?path=file:///Users/test/file.html'
      ];
      
      for (final urlScheme in urlSchemes) {
        final uri = Uri.parse(urlScheme);
        expect(uri.scheme, 'viewsourcevibe');
        expect(uri.host, isNotEmpty);
        expect(uri.queryParameters.isNotEmpty, true);
      }
    });

    test('Should handle file path normalization', () async {
      // Test file path normalization that would be used by the share extension
      final filePaths = [
        'file:///Users/test/file.html',
        'file///Users/test/file.html',
        'file://localhost/Users/test/file.html'
      ];
      
      for (final filePath in filePaths) {
        // Test that file paths are properly detected
        expect(SharingService.isFilePath(filePath), true);
        
        // Test file name extraction
        final fileName = SharedContentManager.extractFileNameFromPath(filePath);
        expect(fileName, 'file.html');
      }
    });

  });
}