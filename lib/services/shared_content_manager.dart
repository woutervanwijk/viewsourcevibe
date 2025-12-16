import 'package:flutter/material.dart';
import 'package:htmlviewer/services/sharing_service.dart';
import 'package:htmlviewer/services/platform_sharing_handler.dart';

class SharedContentManager {
  /// Initialize the shared content manager
  static void initialize(BuildContext context) {
    // Register the handler for shared content
    PlatformSharingHandler.registerSharedContentHandler((sharedData) {
      _handleSharedContent(context, sharedData);
    });
    
    // Check for initial shared content when app starts
    _checkInitialSharedContent(context);
  }
  
  /// Check for initial shared content when app launches
  static Future<void> _checkInitialSharedContent(BuildContext context) async {
    try {
      final sharedData = await PlatformSharingHandler.checkForInitialSharedContent();
      if (sharedData != null) {
        await _handleSharedContent(context, sharedData);
      }
    } catch (e) {
      debugPrint('Error checking initial shared content: $e');
    }
  }
  
  /// Handle shared content by routing to the appropriate service
  static Future<void> _handleSharedContent(
    BuildContext context,
    Map<String, dynamic> sharedData,
  ) async {
    try {
      final type = sharedData['type'] as String?;
      final content = sharedData['content'] as String?;
      final fileName = sharedData['fileName'] as String?;
      final filePath = sharedData['filePath'] as String?;
      final fileBytes = sharedData['fileBytes'] as List<int>?;
      
      debugPrint('SharedContentManager: Handling shared content of type: $type');
      
      // Route to the appropriate sharing service method
      await SharingService.handleSharedContent(
        context,
        sharedText: type == 'text' ? content : null,
        sharedUrl: type == 'url' ? content : null,
        filePath: filePath,
        fileBytes: fileBytes,
        fileName: fileName,
      );
      
    } catch (e) {
      debugPrint('SharedContentManager: Error handling shared content: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing shared content: ${e.toString()}')),
      );
    }
  }
  
  /// Manually trigger shared content handling (for testing)
  static Future<void> triggerTestSharedContent(
    BuildContext context, {
    String? text,
    String? url,
    String? filePath,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    final sharedData = <String, dynamic>{};
    
    if (text != null) {
      sharedData['type'] = 'text';
      sharedData['content'] = text;
    } else if (url != null) {
      sharedData['type'] = 'url';
      sharedData['content'] = url;
    } else if (fileBytes != null) {
      sharedData['type'] = 'file';
      sharedData['fileBytes'] = fileBytes;
      sharedData['fileName'] = fileName ?? 'test.txt';
    } else if (filePath != null) {
      sharedData['type'] = 'file';
      sharedData['filePath'] = filePath;
    }
    
    await _handleSharedContent(context, sharedData);
  }
}