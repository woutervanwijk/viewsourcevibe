import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/main.dart';

/// Unified Sharing Service that consolidates all sharing functionality
class UnifiedSharingService {
  static const MethodChannel _channel =
      MethodChannel('info.wouter.sourceview.sharing');
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
      // Handle empty or null filenames by providing a sensible default
      final effectiveFilename =
          filename?.isNotEmpty == true ? filename! : 'shared_content.html';

      await _channel.invokeMethod(
          'shareHtml', {'html': html, 'filename': effectiveFilename});
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
              await Future.microtask(() {
                // Double-check that context is still mounted before using it
                if (context.mounted) {
                  handleSharedContent(context, sharedData);
                }
              });
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
      final result =
          await _sharedContentChannel.invokeMethod('getSharedContent');

      if (result != null && result is Map && context.mounted) {
        final sharedData = Map<String, dynamic>.from(result);
        await handleSharedContent(context, sharedData);
      }
    } catch (e) {
      debugPrint(
          'UnifiedSharingService: No initial shared content or error checking: $e');
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

      final error = sharedData['error'] as String?;

      debugPrint(
          'UnifiedSharingService: Handling shared content of type: $type');
      if (error != null) {
        debugPrint('UnifiedSharingService: Native error reported: $error');
      }

      final htmlService = Provider.of<HtmlService>(context, listen: false);

      // Route to the appropriate processing method
      if (type == 'url' && content != null) {
        await _processSharedUrl(context, htmlService, content);
      } else if (content != null) {
        // Handle content provided directly (either as text or as a read file)
        debugPrint(
            'UnifiedSharingService: Handling shared content (${content.length} characters)');

        if (type == 'text') {
          final trimmedContent = content.trim();
          String? urlToLoad;
          // Detect if it's a URL (either the whole string or containing one)
          if (isUrl(trimmedContent)) {
            urlToLoad = trimmedContent;
          } else if (isPotentialUrl(trimmedContent)) {
            final uri = Uri.tryParse(trimmedContent);
            if (uri != null &&
                (uri.scheme == 'http' || uri.scheme == 'https')) {
              urlToLoad = trimmedContent;
            } else {
              // Check if it's a URL without scheme like www.example.com
              urlToLoad = trimmedContent;
            }
          } else {
            // Check if there's a URL inside the text
            final urlPattern = RegExp(r'https?:\/\/[^\s]+');
            final match = urlPattern.firstMatch(content);
            if (match != null) {
              urlToLoad = match.group(0);
            }
          }

          // If a URL was detected, ask the user what to do
          if (urlToLoad != null) {
            try {
              // Try to get context from navigatorKey for the dialog
              final dialogContext = context.mounted
                  ? context
                  : (MyApp.navigatorKey.currentState?.context ?? context);

              final choice =
                  await _showShareChoiceDialog(dialogContext, urlToLoad);

              if (choice == 'url') {
                // Re-check context after async gap
                final safeContext = (context.mounted)
                    ? context
                    : (MyApp.navigatorKey.currentContext ?? context);
                await _processSharedUrl(safeContext, htmlService, urlToLoad);
                return;
              }
              // If they chose 'text' or cancelled, fall through to text processing
            } catch (e) {
              debugPrint(
                  'UnifiedSharingService: Error showing choice dialog: $e');
              // Fallback to showing text if dialog fails
            }
          }

          // Handle it as text content
          final finalSafeContext = (context.mounted)
              ? context
              : (MyApp.navigatorKey.currentContext ?? context);

          await _processSharedText(
            finalSafeContext,
            htmlService,
            content,
            fileName: fileName,
            path: filePath ?? 'shared://${type ?? "content"}',
            type: type,
          );
        } else {
          // Otherwise handle it as text content (could be a file read by native side)
          await _processSharedText(
            context,
            htmlService,
            content,
            fileName: fileName,
            path: filePath ?? 'shared://${type ?? "content"}',
            type:
                type, // Pass the type to determine appropriate default filename
          );
        }
      } else if (fileBytes != null && fileBytes.isNotEmpty) {
        await _processSharedFileBytes(
            context, htmlService, fileBytes, fileName);
      } else if (filePath != null && filePath.isNotEmpty) {
        // Check if this is a content URI that failed to be read
        if (filePath.startsWith('content://')) {
          debugPrint(
              'UnifiedSharingService: Content URI failed to be read: $filePath');
          await _handleContentUriError(context, htmlService, filePath, fileName,
              error: error);
        } else {
          await _processSharedFilePath(context, htmlService, filePath);
        }
      } else {
        debugPrint('UnifiedSharingService: No valid shared content found');
        if (context.mounted) {
          _showSnackBar(context, 'No valid content to display');
        }
      }
    } catch (e) {
      debugPrint('UnifiedSharingService: Error handling shared content: $e');
      if (context.mounted) {
        _showSnackBar(
            context, 'Error processing shared content: ${e.toString()}');
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
        debugPrint(
            'UnifiedSharingService: URL is actually a file path, routing to file handler: $url');
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
    String text, {
    String? fileName,
    String? path,
    String?
        type, // Add type parameter to distinguish between text and file content
  }) async {
    try {
      debugPrint(
          'UnifiedSharingService: Handling shared text content (${text.length} characters)');

      // Check if this text content is actually an error message about sandboxed files
      if (isSandboxedFileError(text)) {
        debugPrint(
            'UnifiedSharingService: Detected sandboxed file error message');
        // Extract filename from the error message if possible
        final extractedFileName =
            extractFileNameFromError(text) ?? fileName ?? 'sandboxed_file';

        final htmlFile = HtmlFile(
          name: extractedFileName,
          path: path ?? 'sandboxed://$extractedFileName',
          content: text,
          lastModified: DateTime.now(),
          size: text.length,
          isUrl: false,
        );

        await htmlService.loadFile(htmlFile);
        return;
      }

      // Determine the appropriate default filename based on content type
      final defaultFileName = type == 'text' ? 'Shared text' : 'Shared file';

      final htmlFile = HtmlFile(
        name: fileName ?? defaultFileName,
        path: path ?? 'shared://text',
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

  /// Check if text content is an error message about sandboxed files
  @visibleForTesting
  static bool isSandboxedFileError(String text) {
    return text.contains('iOS sandboxed storage') ||
        text.contains('File Provider Storage') ||
        text.contains('Library/Developer/CoreSimulator') ||
        text.contains('Containers/Shared/AppGroup') ||
        text.contains('cannot be accessed directly');
  }

  /// Extract filename from sandboxed file error message
  @visibleForTesting
  static String? extractFileNameFromError(String text) {
    try {
      // Try to find the last occurrence of a filename in the text
      // This is more reliable than regex for complex file paths with spaces
      final lastSlashIndex = text.lastIndexOf('/');

      if (lastSlashIndex != -1) {
        final lastPart = text.substring(lastSlashIndex + 1);
        final endOfFilename = lastPart.indexOf(RegExp(r'[\s\n]'));

        final filename = endOfFilename != -1
            ? lastPart.substring(0, endOfFilename)
            : lastPart;

        // Clean up the filename by removing URL encoding
        final decodedFileName = Uri.decodeFull(filename);

        debugPrint(
            'UnifiedSharingService: Extracted filename from error: $decodedFileName');

        if (decodedFileName.isNotEmpty) {
          return decodedFileName;
        }
      }
    } catch (e) {
      debugPrint(
          'UnifiedSharingService: Error extracting filename from error: $e');
    }
    return null;
  }

  /// Process shared file bytes by creating a file and loading it
  static Future<void> _processSharedFileBytes(
    BuildContext context,
    HtmlService htmlService,
    List<int> bytes,
    String? fileName,
  ) async {
    try {
      debugPrint(
          'UnifiedSharingService: Handling file bytes (${bytes.length} bytes)');

      // Security: Limit maximum file size
      if (bytes.length > 10 * 1024 * 1024) {
        // 10MB
        throw Exception('File size exceeds maximum limit (10MB)');
      }

      final content = String.fromCharCodes(bytes);
      final name = fileName ?? 'Shared file';

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

  /// Handle content URI errors by showing a helpful error message
  static Future<void> _handleContentUriError(
    BuildContext context,
    HtmlService htmlService,
    String uri,
    String? fileName, {
    String? error,
  }) async {
    try {
      debugPrint('UnifiedSharingService: Handling content URI error for: $uri');

      final effectiveFileName = fileName ?? 'Content File';

      // Provide Google Drive/Docs-specific guidance if this is a Google URI
      String errorContent;
      final errorSnippet = error != null ? '\n\nTechnical Error: $error' : '';

      if (uri.contains('com.google.android.apps.docs')) {
        // Check if this is likely Google Drive (most common case)
        if (uri.contains('storage') || uri.contains('enc%3Dencoded')) {
          errorContent = '''Google Drive File Could Not Be Loaded

This file was shared from Google Drive using a content URI:

$uri

$errorSnippet
 
Google Drive uses security measures that may prevent direct file access. Here's how to share this file:

📱 Google Drive Sharing Guide:

1. Open Google Drive app
2. Find and open the file
3. Tap the three-dot menu (⋮) in the top-right corner
4. Select "Download" to save the file to your device
5. Then share the downloaded file from your file manager

Alternative methods:
- Use "Share link" to create a shareable web link
- Use "Send a copy" to email the file
- Use "Open with" and choose this app to open directly
- Use "Make available offline" then share the local copy

💡 Tip: Google Drive files shared directly may not be accessible due to Google's security policies. Download first, then share!

🔧 Advanced Option:
If you're sharing from Google Drive:
1. Long-press the file
2. Tap "Share"
3. Choose "Save to Files" or "Download"
4. Then share the downloaded file

If you continue to have issues, try using a different file manager app to share the file.''';
        } else {
          errorContent = '''Google Docs File Could Not Be Loaded

This file was shared from Google Docs using an encrypted content URI:

$uri

$errorSnippet
 
Google Docs uses special security measures that prevent direct file access. Here's how to share this file:

📱 Google Docs Sharing Guide:

1. Open the file in Google Docs
2. Tap the three-dot menu (⋮) in the top-right corner
3. Select "Share & export"
4. Choose "Save as" to download the file to your device
5. Then share the downloaded file from your file manager

Alternative methods:
- Use "Copy to" to save to Google Drive, then share from Drive
- Use "Send a copy" to email the file to yourself
- Use "Print" and save as PDF, then share the PDF

💡 Tip: Google Docs files shared directly may not be accessible due to Google's security policies. Always save a copy first!''';
        }
      } else {
        errorContent = '''Content File Could Not Be Loaded

This file was shared from an Android app using a content URI:

$uri

$errorSnippet
 
The Android sharing handler tried to process this file but failed to read its content. Possible reasons:

1. The file is protected by Android security restrictions
2. The sharing app doesn't provide proper file access permissions
3. The file format is not supported
4. The file is too large or corrupted

Try these solutions:
- Open the file in the original app and use "Share as text" instead
- Save the file to your device storage first, then share it
- Use a different app to share the file
- Contact the app developer for support''';
      }

      final htmlFile = HtmlFile(
        name: effectiveFileName,
        path: uri,
        content: errorContent,
        lastModified: DateTime.now(),
        size: errorContent.length,
        isUrl: false,
      );

      await htmlService.loadFile(htmlFile);
    } catch (e) {
      debugPrint('UnifiedSharingService: Error handling content URI error: $e');
      if (context.mounted) {
        _showSnackBar(
            context, 'Error displaying content URI error: ${e.toString()}');
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
        normalizedFilePath =
            decodedFilePath.replaceFirst('https://file///', '/');
        debugPrint(
            'UnifiedSharingService: Converted iOS file URL to path: $normalizedFilePath');
      } else if (decodedFilePath.startsWith('https://file:///')) {
        // Handle another iOS variant
        normalizedFilePath =
            decodedFilePath.replaceFirst('https://file:///', '/');
        debugPrint(
            'UnifiedSharingService: Converted iOS file URL to path: $normalizedFilePath');
      }

      // Security: Check if path is absolute
      if (!normalizedFilePath.startsWith('/')) {
        throw Exception('Only absolute file paths are supported');
      }

      // Security: Limit maximum file size
      const maxFileSize = 10 * 1024 * 1024; // 10MB

      final file = File(normalizedFilePath);
      debugPrint(
          'UnifiedSharingService: Checking file at decoded path: $normalizedFilePath');

      if (!await file.exists()) {
        debugPrint(
            'UnifiedSharingService: File does not exist at: $normalizedFilePath');

        // Special handling for iOS file provider storage paths that might not be directly accessible
        if (filePath.contains('File Provider Storage') ||
            filePath.contains('Library/Developer/CoreSimulator') ||
            filePath.contains('Containers/Shared/AppGroup')) {
          debugPrint(
              'UnifiedSharingService: This is an iOS sandboxed file path that cannot be accessed directly');

          // Try to extract the filename and show a helpful message
          final fileName = extractFileNameFromPath(filePath);
          final errorContent = '''📱 iOS File Sharing Issue

This file is located in iOS sandboxed storage:
$filePath

🔒 Why this happened:
The iOS Share Extension provided a file path that the main app cannot access directly due to iOS security restrictions.

💡 How to fix this:

1. **Best Solution - Save to Files First**
   - Open the file in the original app
   - Tap "Share" → "Save to Files"
   - Choose a location like "On My iPhone"
   - Then share from the Files app

2. **Alternative - Share as Text**
   - Open the file in the original app
   - Tap "Share" → "Copy" or "Share as Text"
   - Paste into this app manually

3. **Advanced - Use "Open With"**
   - Long-press the file in the original app
   - Choose "Open With" → "ViewSourceVibe"

📝 Technical Details:
The Share Extension should read the file content and pass it as bytes, not just the file path. This is an iOS Share Extension configuration issue.

🔧 For Developers:
The iOS Share Extension needs to be updated to:
- Read file content from sandboxed locations
- Pass content as fileBytes parameter
- Include proper filename and MIME type

If you're the app developer, please update the native iOS Share Extension code.''';

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

  /// Show share choice dialog for detected URLs
  static Future<String?> _showShareChoiceDialog(
      BuildContext context, String url) async {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Shared URL Detected',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Load URL Source'),
              subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.pop(context, 'url'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Display as Text'),
              onTap: () => Navigator.pop(context, 'text'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
        debugPrint(
            'UnifiedSharingService: Cannot show snackbar - context not mounted: $message');
      }
    } catch (e) {
      debugPrint('UnifiedSharingService: Error showing snackbar: $e');
    }
  }

  /// Safely convert method channel arguments to Map of String dynamic
  /// This method handles various input types and converts them to the expected format
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

    // First, check if this is explicitly a file URL (file:// protocol)
    if (cleanText.startsWith('file://') || cleanText.startsWith('file///')) {
      return false;
    }

    // Check if this is an Android content:// URI - these should be treated as file shares
    if (cleanText.startsWith('content://')) {
      return false;
    }

    // Check if this is likely a file path (starts with /) - do this early to avoid false positives
    if (cleanText.startsWith('/')) {
      return false;
    }

    // Try to parse as URI - check if it's a valid HTTP/HTTPS URL first
    try {
      final uri = Uri.tryParse(cleanText);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        return true;
      }
    } catch (e) {
      // If parsing fails, continue with other checks
    }

    // Don't try to detect URLs without http:// or https:// schemes
    // This prevents false positives for text like "example.com" or "www.example.com"
    // Only explicit http:// or https:// URLs should be detected as URLs

    // Check for file path patterns in the text
    if (cleanText.contains('Users/') ||
        cleanText.contains('Library/') ||
        cleanText.contains('Containers/') ||
        cleanText.contains('Applications/')) {
      return false;
    }

    return false;
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

  /// Enhanced URL detection for shared text content
  /// This method detects potential URLs even if they're shared as plain text
  static bool isPotentialUrl(String text) {
    if (text.isEmpty) return false;

    final trimmed = text.trim();

    // Remove common URL wrappers
    final cleanText = trimmed
        .replaceAll('<', '')
        .replaceAll('>', '')
        .replaceAll('"', '')
        .replaceAll("'", '');

    // Check for common URL patterns
    try {
      final uri = Uri.tryParse(cleanText);
      if (uri != null) {
        // Valid URL with http/https scheme
        if (uri.scheme == 'http' || uri.scheme == 'https') {
          return true;
        }
        // Valid URL that might be missing scheme (www.example.com)
        if (uri.host.isNotEmpty && !uri.host.contains(' ')) {
          return true;
        }
      }
    } catch (e) {
      // Parsing failed, try simpler patterns
    }

    // Check for common URL patterns without scheme
    final urlPatterns = [
      r'www\.',
      r'http://',
      r'https://',
      r'\.com',
      r'\.org',
      r'\.net',
      r'\.io',
      r'\.co',
      r'\.app',
      r'\.dev',
    ];

    for (final pattern in urlPatterns) {
      if (cleanText.contains(RegExp(pattern, caseSensitive: false))) {
        // Additional checks to avoid false positives
        if (cleanText.contains(' ') && !cleanText.startsWith('http')) {
          // Contains spaces but doesn't start with http - might not be a URL
          continue;
        }
        return true;
      }
    }

    // Check for common URL structures
    if ((cleanText.contains('.') && cleanText.contains('/')) ||
        (cleanText.contains('.') && cleanText.length > 10)) {
      // Might be a URL, but do additional checks
      final hasInvalidChars = RegExp(r'[\s\n\r\t]').hasMatch(cleanText);
      if (!hasInvalidChars) {
        return true;
      }
    }

    return false;
  }
}
