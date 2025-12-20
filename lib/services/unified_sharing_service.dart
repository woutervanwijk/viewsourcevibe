import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/services/html_service.dart';

/// Unified Sharing Service that consolidates all sharing functionality
class UnifiedSharingService {
  static const MethodChannel _channel =
      MethodChannel('info.wouter.sourceviewer.sharing');
  static const MethodChannel _sharedContentChannel =
      MethodChannel('info.wouter.sourceviewer/shared_content');

  /// Share text content using native platform sharing
  static Future<void> shareText(String text) async {
    try {
      await _channel.invokeMethod('shareText', {'text': text});
    } on PlatformException catch (e) {
      debugPrint("Failed to share text: '${e.message}'.");
      throw Exception("Sharing failed: ${e.message}");
    }
  }

  /// Share HTML content with optional filename
  static Future<void> shareHtml(String html, {String? filename}) async {
    try {
      await _channel.invokeMethod('shareHtml',
          {'html': html, 'filename': filename ?? 'shared_content.html'});
    } on PlatformException catch (e) {
      debugPrint("Failed to share HTML: '${e.message}'.");
      throw Exception("Sharing failed: ${e.message}");
    }
  }

  /// Share file content
  static Future<void> shareFile(String filePath, {String? mimeType}) async {
    try {
      await _channel.invokeMethod('shareFile',
          {'filePath': filePath, 'mimeType': mimeType ?? 'text/html'});
    } on PlatformException catch (e) {
      debugPrint("Failed to share file: '${e.message}'.");
      throw Exception("Sharing failed: ${e.message}");
    }
  }

  /// Share URL content using native platform sharing
  static Future<void> shareUrl(String url) async {
    try {
      await _channel.invokeMethod('shareUrl', {'url': url});
    } on PlatformException catch (e) {
      debugPrint("Failed to share URL: '${e.message}'.");
      throw Exception("Sharing failed: ${e.message}");
    }
  }

  /// Initialize the unified sharing service
  static void initialize(BuildContext context) {
    _setupMethodChannelHandlers(context);
    _checkInitialSharedContent(context);
  }

  /// Set up method channel handlers for real-time sharing
  static void _setupMethodChannelHandlers(BuildContext context) {
    try {
      _sharedContentChannel.setMethodCallHandler((MethodCall call) async {
        if (call.method == 'handleNewSharedContent') {
          debugPrint(
              'UnifiedSharingService: Received new shared content via method channel');
          
          try {
            final sharedData = _convertToStringDynamicMap(call.arguments);
            if (sharedData != null && context.mounted) {
              await Future.microtask(
                  () => handleSharedContent(context, sharedData));
              return true;
            }
          } catch (e) {
            debugPrint(
                'UnifiedSharingService: Error processing real-time shared content: $e');
            return false;
          }
        }
        return null;
      });

      debugPrint('UnifiedSharingService: Method channel handlers set up');
    } catch (e) {
      debugPrint('UnifiedSharingService: Error setting up handlers: $e');
    }
  }

  /// Check for initial shared content when app launches
  static Future<void> _checkInitialSharedContent(BuildContext context) async {
    try {
      final result = await _sharedContentChannel.invokeMethod('getSharedContent');
      
      if (result != null && result is Map && context.mounted) {
        final sharedData = Map<String, dynamic>.from(result);
        await handleSharedContent(context, sharedData);
      }
    } catch (e) {
      debugPrint('UnifiedSharingService: No initial shared content or error checking: $e');
    }
  }

  /// Handle shared content by routing to the appropriate processing method
  static Future<void> handleSharedContent(
    BuildContext context, 
    Map<String, dynamic> sharedData,
  ) async {
    try {
      final type = sharedData['type'] as String?;
      final content = sharedData['content'] as String?;
      final fileName = sharedData['fileName'] as String?;
      final filePath = sharedData['filePath'] as String?;
      final fileBytes = sharedData['fileBytes'] as List<int>?;

      debugPrint('UnifiedSharingService: Handling shared content of type: $type');

      final htmlService = Provider.of<HtmlService>(context, listen: false);

      // Route to the appropriate processing method
      if (type == 'url' && content != null) {
        await _processSharedUrl(context, htmlService, content);
      } else if (type == 'text' && content != null) {
        await _processSharedText(context, htmlService, content);
      } else if (fileBytes != null && fileBytes.isNotEmpty) {
        await _processSharedFileBytes(context, htmlService, fileBytes, fileName);
      } else if (filePath != null && filePath.isNotEmpty) {
        await _processSharedFilePath(context, htmlService, filePath);
      } else {
        debugPrint('UnifiedSharingService: No valid shared content found');
        if (context.mounted) {
          _showSnackBar(context, 'No valid content to display');
        }
      }
    } catch (e) {
      debugPrint('UnifiedSharingService: Error handling shared content: $e');
      if (context.mounted) {
        _showSnackBar(context, 'Error processing shared content: ${e.toString()}');
      }
    }
  }

  /// Process shared URL by loading it into the HTML service
  static Future<void> _processSharedUrl(
    BuildContext context,
    HtmlService htmlService,
    String url,
  ) async {
    try {
      // Check if this URL is actually a file path in disguise
      // This can happen with iOS file sharing where file paths are passed as URLs
      if (isFilePath(url)) {
        debugPrint('UnifiedSharingService: URL is actually a file path, routing to file handler: $url');
        await _processSharedFilePath(context, htmlService, url);
        return;
      }
      
      await htmlService.loadFromUrl(url);
    } catch (e) {
      debugPrint('UnifiedSharingService: Error loading URL: $e');
      if (context.mounted) {
        _showSnackBar(context, 'Error loading URL: ${e.toString()}');
      }
      rethrow;
    }
  }

  /// Process shared text by loading it as a new file
  static Future<void> _processSharedText(
    BuildContext context,
    HtmlService htmlService,
    String text,
  ) async {
    try {
      debugPrint('UnifiedSharingService: Handling shared text (${text.length} characters)');

      final htmlFile = HtmlFile(
        name: '',
        path: 'shared://text',
        content: text,
        lastModified: DateTime.now(),
        size: text.length,
        isUrl: false,
      );

      await htmlService.loadFile(htmlFile);
    } catch (e) {
      debugPrint('UnifiedSharingService: Error handling shared text: $e');
      if (context.mounted) {
        _showSnackBar(context, 'Error loading text: ${e.toString()}');
      }
      rethrow;
    }
  }

  /// Process shared file bytes by creating a file and loading it
  static Future<void> _processSharedFileBytes(
    BuildContext context,
    HtmlService htmlService,
    List<int> bytes,
    String? fileName,
  ) async {
    try {
      debugPrint('UnifiedSharingService: Handling file bytes (${bytes.length} bytes)');

      // Security: Limit maximum file size
      if (bytes.length > 10 * 1024 * 1024) { // 10MB
        throw Exception('File size exceeds maximum limit (10MB)');
      }

      final content = String.fromCharCodes(bytes);
      final name = fileName ?? '';

      final htmlFile = HtmlFile(
        name: name,
        path: 'shared://file',
        content: content,
        lastModified: DateTime.now(),
        size: bytes.length,
        isUrl: false,
      );

      await htmlService.loadFile(htmlFile);
    } catch (e) {
      debugPrint('UnifiedSharingService: Error handling file bytes: $e');
      if (context.mounted) {
        _showSnackBar(context, 'Error loading file: ${e.toString()}');
      }
      rethrow;
    }
  }

  /// Process shared file path by reading and loading the file
  static Future<void> _processSharedFilePath(
    BuildContext context,
    HtmlService htmlService,
    String filePath,
  ) async {
    try {
      debugPrint('UnifiedSharingService: Handling file path: $filePath');

      // Security: Validate file path
      // For file:// URLs, we need to be careful with URL decoding
      String decodedFilePath = filePath;
      
      // Only decode if it's not already a file:// URL, as those are already properly formatted
      if (!filePath.startsWith('file://')) {
        try {
          decodedFilePath = Uri.decodeFull(filePath);
        } catch (e) {
          // If decoding fails, use the original path
        }
      }

      // Check for directory traversal patterns in the decoded path
      // Only check for actual directory traversal patterns, not legitimate path components
      bool hasDirectoryTraversal = false;
      if (decodedFilePath.contains('..')) {
        hasDirectoryTraversal = true;
      }
      if (decodedFilePath.contains('\\')) {
        hasDirectoryTraversal = true;
      }
      // Check for actual null bytes (ASCII 0) - this is the only real security concern
      for (int i = 0; i < filePath.length; i++) {
        if (filePath.codeUnitAt(i) == 0) {
          hasDirectoryTraversal = true;
          break;
        }
      }

      if (hasDirectoryTraversal) {
        throw Exception('Invalid file path');
      }

      // Convert file:// URLs to proper file paths
      // Use the decoded path for URL conversion
      String normalizedFilePath = decodedFilePath;
      if (decodedFilePath.startsWith('file:///')) {
        normalizedFilePath = decodedFilePath.replaceFirst('file:///', '/');
      } else if (decodedFilePath.startsWith('file///')) {
        normalizedFilePath = decodedFilePath.replaceFirst('file///', '/');
      } else if (decodedFilePath.startsWith('file://')) {
        normalizedFilePath = decodedFilePath.replaceFirst('file://', '/');
      } else if (decodedFilePath.startsWith('https://file///')) {
        // Handle the specific iOS case where file paths are passed as https://file/// URLs
        normalizedFilePath = decodedFilePath.replaceFirst('https://file///', '/');
        debugPrint('UnifiedSharingService: Converted iOS file URL to path: $normalizedFilePath');
      } else if (decodedFilePath.startsWith('https://file:///')) {
        // Handle another iOS variant
        normalizedFilePath = decodedFilePath.replaceFirst('https://file:///', '/');
        debugPrint('UnifiedSharingService: Converted iOS file URL to path: $normalizedFilePath');
      }

      // Security: Check if path is absolute
      if (!normalizedFilePath.startsWith('/')) {
        throw Exception('Only absolute file paths are supported');
      }

      // Security: Limit maximum file size
      const maxFileSize = 10 * 1024 * 1024; // 10MB

      final file = File(normalizedFilePath);
      debugPrint('UnifiedSharingService: Checking file at decoded path: $normalizedFilePath');

      if (!await file.exists()) {
        debugPrint('UnifiedSharingService: File does not exist at: $normalizedFilePath');
        
        // Special handling for iOS file provider storage paths that might not be directly accessible
        if (filePath.contains('File Provider Storage') || 
            filePath.contains('Library/Developer/CoreSimulator') ||
            filePath.contains('Containers/Shared/AppGroup')) {
          debugPrint('UnifiedSharingService: This is an iOS sandboxed file path that cannot be accessed directly');
          
          // Try to extract the filename and show a helpful message
          final fileName = extractFileNameFromPath(filePath);
          final errorContent = '''File could not be loaded

This file is located in iOS sandboxed storage:
$filePath

The file exists but cannot be accessed directly by this app due to iOS security restrictions.''';
          
          final htmlFile = HtmlFile(
            name: fileName,
            path: 'sandboxed://$fileName',
            content: errorContent,
            lastModified: DateTime.now(),
            size: errorContent.length,
            isUrl: false,
          );
          
          await htmlService.loadFile(htmlFile);
          return;
        }
        
        throw Exception('File does not exist: $normalizedFilePath');
      }

      // Security: Check file size before reading
      final fileSize = await file.length();
      if (fileSize > maxFileSize) {
        throw Exception('File size exceeds maximum limit (10MB)');
      }

      final content = await file.readAsString();
      final fileName = normalizedFilePath.split('/').last;

      final htmlFile = HtmlFile(
        name: fileName,
        path: normalizedFilePath,
        content: content,
        lastModified: await file.lastModified(),
        size: fileSize,
        isUrl: false,
      );

      await htmlService.loadFile(htmlFile);
    } catch (e) {
      debugPrint('UnifiedSharingService: Error handling file path: $e');
      if (context.mounted) {
        _showSnackBar(context, 'Error loading file: ${e.toString()}');
      }
      rethrow;
    }
  }

  /// Show snackbar message
  static void _showSnackBar(BuildContext context, String message) {
    try {
      // Check if we can show a snackbar (context is mounted and has ScaffoldMessenger)
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } else {
        debugPrint('UnifiedSharingService: Cannot show snackbar - context not mounted: $message');
      }
    } catch (e) {
      debugPrint('UnifiedSharingService: Error showing snackbar: $e');
    }
  }

  /// Safely convert method channel arguments to Map<String, dynamic>
  static Map<String, dynamic>? _convertToStringDynamicMap(dynamic arguments) {
    try {
      if (arguments == null) {
        return null;
      }

      if (arguments is Map<String, dynamic>) {
        return arguments;
      }

      if (arguments is Map) {
        final result = <String, dynamic>{};
        arguments.forEach((key, value) {
          if (key is String) {
            result[key] = value;
          } else {
            result[key.toString()] = value;
          }
        });
        return result;
      }

      return null;
    } catch (e) {
      debugPrint('UnifiedSharingService: Error converting arguments: $e');
      return null;
    }
  }

  /// Check if a string is a URL
  @visibleForTesting
  static bool isUrl(String text) {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return false;
    }

    // Remove quotes if present
    final cleanText = trimmedText.startsWith('"') && trimmedText.endsWith('"')
        ? trimmedText.substring(1, trimmedText.length - 1)
        : (trimmedText.startsWith("'") && trimmedText.endsWith("'")
            ? trimmedText.substring(1, trimmedText.length - 1)
            : trimmedText);

    // Check if this is a file path
    if (cleanText.startsWith('/') ||
        cleanText.contains('file://') ||
        cleanText.contains('file///')) {
      return false;
    }

    // Try to parse as URI
    try {
      final uri = cleanText.startsWith('http://') || cleanText.startsWith('https://')
          ? Uri.parse(cleanText)
          : Uri.parse('https://$cleanText');

      return uri.hasScheme && uri.hasAuthority && !uri.path.contains(' ');
    } catch (e) {
      return false;
    }
  }

  /// Check if a string is a file path
  @visibleForTesting
  static bool isFilePath(String text) {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return false;
    }

    final cleanText = trimmedText.startsWith('"') && trimmedText.endsWith('"')
        ? trimmedText.substring(1, trimmedText.length - 1)
        : (trimmedText.startsWith("'") && trimmedText.endsWith("'")
            ? trimmedText.substring(1, trimmedText.length - 1)
            : trimmedText);

    // First, check if it's definitely NOT a file path (it's a URL)
    if (cleanText.startsWith('http://') ||
        cleanText.startsWith('https://') ||
        cleanText.startsWith('www.')) {
      // But make an exception for file:// URLs which are actually file paths
      if (cleanText.startsWith('file://') || cleanText.startsWith('file///')) {
        return true;
      }
      return false;
    }

    // Check for file path patterns
    if (cleanText.startsWith('/') ||
        cleanText.startsWith('file://') ||
        cleanText.startsWith('file///') ||
        cleanText.startsWith('./') ||
        cleanText.startsWith('../')) {
      return true;
    }

    // Check for iOS-specific file provider storage paths
    if (cleanText.contains('File Provider Storage') ||
        cleanText.contains('Library/Developer/CoreSimulator') ||
        cleanText.contains('Containers/Shared/AppGroup')) {
      return true;
    }

    // Check for paths containing directory separators and common directory names
    if (cleanText.contains('/Users/') ||
        cleanText.contains('/Library/') ||
        cleanText.contains('/Documents/') ||
        cleanText.contains('assets/') ||
        cleanText.contains('files/')) {
      return true;
    }

    // Check for simple filenames with extensions
    if (!cleanText.contains('/') &&
        !cleanText.contains('\\') &&
        !cleanText.contains('://') &&
        cleanText.contains('.') &&
        !cleanText.startsWith('.') &&
        cleanText.length > 3) {
      return true;
    }

    return false;
  }

  /// Extract file name from a file path
  @visibleForTesting
  static String extractFileNameFromPath(String path) {
    var cleanPath = path;
    if (cleanPath.startsWith('file:///')) {
      cleanPath = cleanPath.replaceFirst('file:///', '/');
    } else if (cleanPath.startsWith('file///')) {
      cleanPath = cleanPath.replaceFirst('file///', '/');
    } else if (cleanPath.startsWith('file://')) {
      cleanPath = cleanPath.replaceFirst('file://', '/');
    }

    final components = cleanPath.split('/');
    final lastComponent = components
        .lastWhere((component) => component.isNotEmpty, orElse: () => '');

    if (lastComponent.isEmpty || cleanPath.endsWith('/')) {
      return 'shared_file';
    }

    return lastComponent;
  }
}