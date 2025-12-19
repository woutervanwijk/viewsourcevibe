import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:view_source_vibe/services/sharing_service.dart';
import 'package:view_source_vibe/services/platform_sharing_handler.dart';

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

  static Future<String?> checkForSharedExtensionUrl() async {
    try {
      const MethodChannel channel =
          MethodChannel('info.wouter.sourceviewer/shared_content');
      final result = await channel.invokeMethod('getSharedContent');

      if (result != null && result is Map) {
        final contentMap = Map<String, dynamic>.from(result);
        if (contentMap['type'] == 'url' && contentMap['content'] != null) {
          return contentMap['content'] as String;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error checking for shared extension URL: $e');
      return null;
    }
  }

  /// Check for initial shared content when app launches
  static Future<void> _checkInitialSharedContent(BuildContext context) async {
    try {
      // Check platform-specific shared content first
      final sharedData =
          await PlatformSharingHandler.checkForInitialSharedContent();
      if (sharedData != null) {
        if (context.mounted) {
          await _handleSharedContent(context, sharedData);
        }
        return;
      }

      // Also check our new shared content channel
      final channelSharedData = await SharingService.checkForSharedContent();
      if (channelSharedData != null) {
        // Handle special case: if type is "url" but content is a file URL, treat as file
        if (channelSharedData['type'] == 'url' &&
            channelSharedData['content'] != null &&
            SharingService.isFilePath(channelSharedData['content'] as String)) {
          debugPrint('SharedContentManager: Converting URL type with file path to file type');
          final sharedDataFromChannel = {
            'type': 'file',
            'filePath': channelSharedData['content'],
            'fileName': extractFileNameFromPath(channelSharedData['content'] as String),
          };
          if (context.mounted) {
            await _handleSharedContent(context, sharedDataFromChannel);
          }
        } else {
          final sharedDataFromChannel = {
            'type': channelSharedData['type'],
            'content': channelSharedData['content'],
            if (channelSharedData.containsKey('filePath'))
              'filePath': channelSharedData['filePath'],
            if (channelSharedData.containsKey('fileName'))
              'fileName': channelSharedData['fileName'],
          };
          if (context.mounted) {
            await _handleSharedContent(context, sharedDataFromChannel);
          }
        }
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

      debugPrint(
          'SharedContentManager: Handling shared content of type: $type');

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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error processing shared content: ${e.toString()}')),
        );
      }
    }
  }

  /// Extract file name from a file path
  @visibleForTesting
  static String extractFileNameFromPath(String path) {
    // Handle file:// URLs
    var cleanPath = path;
    if (cleanPath.startsWith('file:///')) {
      cleanPath = cleanPath.replaceFirst('file:///', '/');
    } else if (cleanPath.startsWith('file///')) {
      cleanPath = cleanPath.replaceFirst('file///', '/');
    } else if (cleanPath.startsWith('file://')) {
      cleanPath = cleanPath.replaceFirst('file://', '/');
    }
    
    // Extract the last component as file name
    final components = cleanPath.split('/');
    final lastComponent = components.lastWhere((component) => component.isNotEmpty, orElse: () => '');
    
    // If the path ends with a slash (directory), use fallback
    if (lastComponent.isEmpty || cleanPath.endsWith('/')) {
      return 'shared_file';
    }
    
    return lastComponent;
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
