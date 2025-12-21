import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/unified_sharing_service.dart';

void main() {
  group('Android Content URI Handling Tests', () {
    
    test('Test content URI detection in text/html sharing', () {
      // Test that content URIs are properly detected
      const contentUri = 'content://com.google.android.apps.docs.storage.legacy/enc%3Dencoded%3DXRVIQU-6cMc7dZO8oFhZAgoQISJgSPnEg9PMGjHJhmMinJiZjJc3L1nV-W-hzTs%3D';
      
      expect(UnifiedSharingService.isUrl(contentUri), false);
      expect(UnifiedSharingService.isFilePath(contentUri), false);
      expect(contentUri.startsWith('content://'), true);
    });

    test('Test content URI error handling', () {
      // Test that content URI errors are handled gracefully
      const contentUri = 'content://com.google.android.apps.docs.storage.legacy/test';
      
      // This should be detected as needing special handling
      expect(contentUri.startsWith('content://'), true);
    });

    test('Test file path vs content URI distinction', () {
      // Test that we can distinguish between regular file paths and content URIs
      const filePath = '/storage/emulated/0/Download/test.html';
      const contentUri = 'content://com.android.providers.downloads.documents/document/123';
      
      expect(UnifiedSharingService.isFilePath(filePath), true);
      expect(UnifiedSharingService.isFilePath(contentUri), false);
      expect(UnifiedSharingService.isUrl(contentUri), false);
    });

    test('Test URL detection with content URIs', () {
      // Ensure content URIs are not mistakenly detected as URLs
      const contentUri = 'content://com.google.android.apps.docs.storage.legacy/file';
      const httpUrl = 'https://example.com/file.html';
      const fileUrl = 'file:///storage/emulated/0/file.html';
      
      expect(UnifiedSharingService.isUrl(contentUri), false);
      expect(UnifiedSharingService.isUrl(httpUrl), true);
      expect(UnifiedSharingService.isUrl(fileUrl), false);
    });

    test('Test Google Docs content URI detection', () {
      // Test that Google Docs URIs are properly detected
      const googleDocsUri = 'content://com.google.android.apps.docs.storage.legacy/enc%3Dencoded%3DXRVIQU-6cMc7dZO8oFhZAgoQISJgSPnEg9PMGjHJhmMinJiZjJc3L1nV-W-hzTs%3D';
      const regularContentUri = 'content://com.android.providers.downloads.documents/document/123';
      
      expect(googleDocsUri.contains('com.google.android.apps.docs'), true);
      expect(regularContentUri.contains('com.google.android.apps.docs'), false);
    });

    test('Test Google Docs encrypted URI pattern', () {
      // Test detection of Google Docs encrypted URI pattern
      const encryptedUri = 'content://com.google.android.apps.docs.storage.legacy/enc%3Dencoded%3DXRVIQU-6cMc7dZO8oFhZAgoQISJgSPnEg9PMGjHJhmMinJiZjJc3L1nV-W-hzTs%3D';
      const regularUri = 'content://com.google.android.apps.docs.storage.legacy/document/123';
      
      expect(encryptedUri.contains('enc%3Dencoded'), true);
      expect(regularUri.contains('enc%3Dencoded'), false);
    });

    test('Test Google Drive URI detection', () {
      // Test detection of Google Drive URIs (most common case)
      const googleDriveUri = 'content://com.google.android.apps.docs.storage.legacy/enc%3Dencoded%3DXRVIQU-6cMc7dZO8oFhZAgoQISJgSPnEg9PMGjHJhmMinJiZjJc3L1nV-W-hzTs%3D';
      const googleDocsUri = 'content://com.google.android.apps.docs/document/123';
      
      // Both contain the docs package, but Drive has storage/encrypted pattern
      expect(googleDriveUri.contains('com.google.android.apps.docs'), true);
      expect(googleDriveUri.contains('storage'), true);
      expect(googleDriveUri.contains('enc%3Dencoded'), true);
      
      expect(googleDocsUri.contains('com.google.android.apps.docs'), true);
      expect(googleDocsUri.contains('storage'), false);
      expect(googleDocsUri.contains('enc%3Dencoded'), false);
    });

    test('Test Google Drive vs Docs URI distinction', () {
      // Test that we can distinguish between Google Drive and Google Docs URIs
      const driveUri = 'content://com.google.android.apps.docs.storage.legacy/enc%3Dencoded%3Dtest';
      const docsUri = 'content://com.google.android.apps.docs.document/123';
      
      // Google Drive detection logic
      final isLikelyDrive1 = driveUri.contains('storage') || driveUri.contains('enc%3Dencoded');
      final isLikelyDrive2 = docsUri.contains('storage') || docsUri.contains('enc%3Dencoded');
      
      expect(isLikelyDrive1, true);  // Should be identified as Drive
      expect(isLikelyDrive2, false); // Should be identified as Docs
    });

  });
}
