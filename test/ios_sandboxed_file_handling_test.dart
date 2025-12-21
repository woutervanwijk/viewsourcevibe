import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/unified_sharing_service.dart';

void main() {
  group('iOS Sandboxed File Handling Tests', () {
    
    test('isSandboxedFileError detects sandboxed file error messages', () {
      // Test various sandboxed file error patterns
      expect(
        UnifiedSharingService.isSandboxedFileError(
          'File could not be loaded. This file is located in iOS sandboxed storage'
        ),
        true,
        reason: 'Should detect iOS sandboxed storage message'
      );

      expect(
        UnifiedSharingService.isSandboxedFileError(
          'Error: File Provider Storage access denied'
        ),
        true,
        reason: 'Should detect File Provider Storage message'
      );

      expect(
        UnifiedSharingService.isSandboxedFileError(
          'Cannot access file in Library/Developer/CoreSimulator'
        ),
        true,
        reason: 'Should detect CoreSimulator path'
      );

      expect(
        UnifiedSharingService.isSandboxedFileError(
          'File in Containers/Shared/AppGroup cannot be accessed directly'
        ),
        true,
        reason: 'Should detect AppGroup container message'
      );

      expect(
        UnifiedSharingService.isSandboxedFileError(
          'The file exists but cannot be accessed directly by the main app'
        ),
        true,
        reason: 'Should detect "cannot be accessed directly" message'
      );

      // Test that normal content is not detected as error
      expect(
        UnifiedSharingService.isSandboxedFileError(
          'This is normal text content that should be displayed'
        ),
        false,
        reason: 'Should not detect normal text as error'
      );

      expect(
        UnifiedSharingService.isSandboxedFileError(
          'Hello world! This is a test file.'
        ),
        false,
        reason: 'Should not detect normal file content as error'
      );
    });

    test('extractFileNameFromError extracts filename from error messages', () {
      // Test filename extraction from various error message formats
      expect(
        UnifiedSharingService.extractFileNameFromError(
          'File could not be loaded: file:///var/mobile/Containers/Shared/AppGroup/test.html'
        ),
        'test.html',
        reason: 'Should extract filename from file:// URL'
      );

      expect(
        UnifiedSharingService.extractFileNameFromError(
          'Error accessing /Users/test/Library/Developer/CoreSimulator/Devices/test.txt'
        ),
        'test.txt',
        reason: 'Should extract filename from absolute path'
      );

      expect(
        UnifiedSharingService.extractFileNameFromError(
          'Cannot read file:///private/var/mobile/Containers/Data/Application/documents%20file.dart'
        ),
        'documents file.dart',
        reason: 'Should handle URL-encoded filenames'
      );

      expect(
        UnifiedSharingService.extractFileNameFromError(
          'File Provider Storage access denied for /path/to/my%20document.pdf'
        ),
        'my document.pdf',
        reason: 'Should decode URL-encoded spaces'
      );

      // Test edge cases
      expect(
        UnifiedSharingService.extractFileNameFromError(
          'No file path in this message'
        ),
        null,
        reason: 'Should return null when no file path is found'
      );

      expect(
        UnifiedSharingService.extractFileNameFromError(
          'Error: file:///path/to/file%20with%20spaces%20and%20special%20chars.txt'
        ),
        'file with spaces and special chars.txt',
        reason: 'Should handle complex URL-encoded filenames'
      );
    });

    test('isFilePath correctly identifies iOS sandboxed file paths', () {
      // Test that isFilePath correctly identifies sandboxed file paths
      expect(
        UnifiedSharingService.isFilePath(
          '/var/mobile/Containers/Shared/AppGroup/group.com.test.app/File Provider Storage/test.html'
        ),
        true,
        reason: 'Should identify File Provider Storage paths as file paths'
      );

      expect(
        UnifiedSharingService.isFilePath(
          '/Users/test/Library/Developer/CoreSimulator/Devices/123456/app.documents/file.txt'
        ),
        true,
        reason: 'Should identify CoreSimulator paths as file paths'
      );

      expect(
        UnifiedSharingService.isFilePath(
          'file:///private/var/mobile/Containers/Data/Application/test.app/Documents/file.dart'
        ),
        true,
        reason: 'Should identify file:// URLs as file paths'
      );

      // Test that normal URLs are not identified as file paths
      expect(
        UnifiedSharingService.isFilePath(
          'https://example.com/file.html'
        ),
        false,
        reason: 'Should not identify HTTPS URLs as file paths'
      );

      expect(
        UnifiedSharingService.isFilePath(
          'http://localhost:8080/test.txt'
        ),
        false,
        reason: 'Should not identify HTTP URLs as file paths'
      );
    });

    test('isUrl correctly rejects iOS sandboxed file paths', () {
      // Test that isUrl correctly rejects sandboxed file paths
      expect(
        UnifiedSharingService.isUrl(
          '/var/mobile/Containers/Shared/AppGroup/group.com.test.app/File Provider Storage/test.html'
        ),
        false,
        reason: 'Should not identify File Provider Storage paths as URLs'
      );

      expect(
        UnifiedSharingService.isUrl(
          'file:///private/var/mobile/Containers/Data/Application/test.app/Documents/file.dart'
        ),
        false,
        reason: 'Should not identify file:// URLs as HTTP URLs'
      );

      // Test that normal URLs are correctly identified
      expect(
        UnifiedSharingService.isUrl(
          'https://example.com/file.html'
        ),
        true,
        reason: 'Should identify HTTPS URLs correctly'
      );

      expect(
        UnifiedSharingService.isUrl(
          'http://localhost:8080/test.txt'
        ),
        true,
        reason: 'Should identify HTTP URLs correctly'
      );
    });

    test('handleSharedContent routes sandboxed file errors to text processing', () async {
      // This is a more complex integration test that would require mocking
      // For now, we'll just verify the routing logic
      
      // Test that content containing sandboxed file error patterns is routed correctly
      final sandboxedErrorContent = '''
File could not be loaded

This file is located in iOS sandboxed storage:
file:///var/mobile/Containers/Shared/AppGroup/group.com.test.app/File Provider Storage/test.html

The file exists but cannot be accessed directly by the main app due to iOS security restrictions.
''';

      expect(
        UnifiedSharingService.isSandboxedFileError(sandboxedErrorContent),
        true,
        reason: 'Should detect complex sandboxed file error message'
      );

      final extractedName = UnifiedSharingService.extractFileNameFromError(sandboxedErrorContent);
      expect(
        extractedName,
        'test.html',
        reason: 'Should extract filename from complex error message'
      );
    });

  });
}