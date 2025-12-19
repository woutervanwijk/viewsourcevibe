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

    // Set up method channel for real-time shared content handling
    _setupRealTimeSharedContentHandler(context);

    // Check for initial shared content when app starts
    _checkInitialSharedContent(context);
  }

  /// Set up method channel for handling shared content while app is running
  static void _setupRealTimeSharedContentHandler(BuildContext context) {
    try {
      const MethodChannel channel =
          MethodChannel('info.wouter.sourceviewer/shared_content');
      
      channel.setMethodCallHandler((MethodCall call) async {
        if (call.method == 'handleNewSharedContent') {
          debugPrint('SharedContentManager: Received new shared content via method channel');
          debugPrint('SharedContentManager: Raw arguments: ${call.arguments}');
          
          try {
            // Safely convert the arguments to the expected type
            final sharedData = convertToStringDynamicMap(call.arguments);
            if (sharedData != null) {
              debugPrint('SharedContentManager: Converted shared data: $sharedData');
              // Use a microtask to ensure we're not blocking the native thread
              await Future.microtask(() => handleNewSharedContent(context, sharedData));
              return true;
            } else {
              debugPrint('SharedContentManager: Failed to convert shared data to proper format');
              return false;
            }
          } catch (e) {
            debugPrint('SharedContentManager: Error processing real-time shared content: $e');
            return false;
          }
        }
        return null;
      });
      
      debugPrint('SharedContentManager: Real-time shared content handler set up');
    } catch (e) {
      debugPrint('SharedContentManager: Error setting up real-time handler: $e');
    }
  }

  /// Safely convert method channel arguments to Map<String, dynamic>
  @visibleForTesting
  static Map<String, dynamic>? convertToStringDynamicMap(dynamic arguments) {
    try {
      if (arguments == null) {
        debugPrint('SharedContentManager: Arguments are null');
        return null;
      }

      if (arguments is Map<String, dynamic>) {
        debugPrint('SharedContentManager: Arguments are already Map<String, dynamic>');
        return arguments;
      }

      if (arguments is Map) {
        debugPrint('SharedContentManager: Converting Map to Map<String, dynamic>');
        final result = <String, dynamic>{};
        arguments.forEach((key, value) {
          if (key is String) {
            result[key] = value;
          } else {
            debugPrint('SharedContentManager: Non-string key found: $key');
            result[key.toString()] = value;
          }
        });
        return result;
      }

      debugPrint('SharedContentManager: Arguments are not a Map: ${arguments.runtimeType}');
      return null;
    } catch (e) {
      debugPrint('SharedContentManager: Error converting arguments: $e');
      return null;
    }
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

  /// Handle shared content that arrives while app is running
  /// This method can be called from native side when new content is shared
  static Future<void> handleNewSharedContent(BuildContext context, Map<String, dynamic> sharedData) async {
    try {
      debugPrint('SharedContentManager: Handling new shared content while app is running');
      
      // Handle the special case where URL content is actually a file path
      if (sharedData['type'] == 'url' &&
          sharedData['content'] != null &&
          SharingService.isFilePath(sharedData['content'] as String)) {
        debugPrint('SharedContentManager: Converting URL type with file path to file type (real-time)');
        final convertedData = {
          'type': 'file',
          'filePath': sharedData['content'],
          'fileName': extractFileNameFromPath(sharedData['content'] as String),
        };
        await _handleSharedContent(context, convertedData);
      } else {
        await _handleSharedContent(context, sharedData);
      }
    } catch (e) {
      debugPrint('SharedContentManager: Error handling new shared content: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing shared content: ${e.toString()}')),
        );
      }
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
