import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/file_type_detector.dart';
import 'package:view_source_vibe/services/unified_sharing_service.dart';

class SharingService {
  static const MethodChannel _channel =
      MethodChannel('info.wouter.sourceview.sharing');

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
      final effectiveFilename = filename?.isNotEmpty == true 
          ? filename! 
          : 'shared_content.html';
      
      await _channel.invokeMethod('shareHtml',
          {'html': html, 'filename': effectiveFilename});
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

  /// Handle shared content received from other apps
  static Future<void> handleSharedContent(
    BuildContext context, {
    String? sharedText,
    String? sharedUrl,
    String? filePath,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    try {
      // debugPrint('shared $sharedText - $sharedUrl');
      final htmlService = Provider.of<HtmlService>(context, listen: false);

      // Process the shared content based on type
      // Priority 1: Handle explicit URL sharing
      if (sharedUrl != null && sharedUrl.isNotEmpty) {
        // Handle shared URL
        await _processSharedUrl(context, htmlService, sharedUrl);
      }
      // Priority 2: Check if shared text is a valid URL using the fixed isUrl method
      else if (sharedText != null && sharedText.isNotEmpty) {
        // Use the fixed isUrl method for consistent URL detection
        if (isUrl(sharedText)) {
          // This is a valid HTTP/HTTPS URL, treat it as a URL
          debugPrint(
              'SharingService: Shared text is a valid URL: $sharedText');
          // ignore: use_build_context_synchronously
          await _processSharedUrl(context, htmlService, sharedText);
        } else {
          // Not a valid URL, but check if it's a potential URL that should be opened
          if (UnifiedSharingService.isPotentialUrl(sharedText)) {
            // Try to open as URL first
            try {
              final uri = Uri.tryParse(sharedText.trim());
              if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
                debugPrint('SharingService: Detected potential URL in shared text, opening: $sharedText');
                // ignore: use_build_context_synchronously
                await _processSharedUrl(context, htmlService, sharedText);
                return; // URL handled, no need for text processing
              }
            } catch (e) {
              debugPrint('SharingService: URL detection failed for potential URL: $e');
            }
          }
          
          // Not a valid URL, treat as text content
          debugPrint(
              'SharingService: Shared text is not a URL, treating as text: $sharedText');
          // ignore: use_build_context_synchronously
          await _processSharedText(context, htmlService, sharedText);
        }
      }
      // Priority 3: Check if shared text is actually a file path
      else if (sharedText != null &&
          sharedText.isNotEmpty &&
          isFilePath(sharedText)) {
        // Handle text that looks like a file path
        debugPrint(
            'SharingService: Routing shared text as file path: $sharedText');
        await _processSharedFilePath(context, htmlService, sharedText);
      }
      // Priority 4: Handle file bytes
      else if (fileBytes != null && fileBytes.isNotEmpty) {
        // Handle shared file bytes
        await _processSharedFileBytes(
            context, htmlService, fileBytes, fileName);
      }
      // Priority 5: Handle file path
      else if (filePath != null && filePath.isNotEmpty) {
        // Handle shared file path
        await _processSharedFilePath(context, htmlService, filePath);
      } else {
        // No valid content found
        debugPrint('SharingService: No valid shared content found');
        if (context.mounted) {
          _showSnackBar(context, 'No valid content to display');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('SharingService: Error handling shared content: $e');
      debugPrint('Stack trace: $stackTrace');
      if (context.mounted) {
        _showSnackBar(context, 'Error loading shared content: ${e.toString()}');
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
      // Load the URL using the existing HTML service
      await htmlService.loadFromUrl(url);

      // The HTML service should handle its own notifications
      // Remove direct notifyListeners calls as they're not safe here
    } catch (e) {
      debugPrint('SharingService: Error loading URL: $e');
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
      debugPrint(
          'SharingService: Handling shared text (${text.length} characters)');

      final htmlFile = HtmlFile(
        name: 'Shared text', // Default name for shared text
        path: 'shared://text',
        content: text,
        lastModified: DateTime.now(),
        size: text.length,
        isUrl: false,
      );

      await htmlService.loadFile(htmlFile);
    } catch (e) {
      debugPrint('SharingService: Error handling shared text: $e');
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
      debugPrint('SharingService: Handling file bytes (${bytes.length} bytes)');

      // Check for binary files before processing
      try {
        await fileTypeDetector.detectFileType(
          filename: fileName,
          bytes: Uint8List.fromList(bytes),
        );
      } catch (e) {
        if (e is FileTypeError) {
          debugPrint('SharingService: Binary file detected: ${e.message}');
          if (context.mounted) {
            _showSnackBar(context, e.message);
          }
          return; // Don't process binary files
        }
      }

      final content = String.fromCharCodes(bytes);
      final name = fileName ?? 'Shared file'; // Default name for shared files

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
      debugPrint('SharingService: Error handling file bytes: $e');
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
      debugPrint('SharingService: Handling file path: $filePath');

      // Security: Validate file path to prevent directory traversal attacks
      if (filePath.contains('..') || filePath.contains('\\') || filePath.contains(r'\0')) {
        debugPrint('SharingService: Invalid file path detected (potential directory traversal)');
        throw Exception('Invalid file path');
      }

      // Convert file:// URLs to proper file paths
      String normalizedFilePath = filePath;
      if (filePath.startsWith('file:///')) {
        // Standard file:/// URL - remove the scheme
        normalizedFilePath = filePath.replaceFirst('file:///', '/');
        debugPrint(
            'SharingService: Converted file:/// URL to path: $normalizedFilePath');
      } else if (filePath.startsWith('file///')) {
        // Non-standard file/// URL (iOS specific) - remove the scheme
        normalizedFilePath = filePath.replaceFirst('file///', '/');
        debugPrint(
            'SharingService: Converted file/// URL to path: $normalizedFilePath');
      } else if (filePath.startsWith('file://')) {
        // Standard file:// URL - remove the scheme
        normalizedFilePath = filePath.replaceFirst('file://', '/');
        debugPrint(
            'SharingService: Converted file:// URL to path: $normalizedFilePath');
      }

      // Security: Check if path is absolute and within reasonable bounds
      if (!normalizedFilePath.startsWith('/')) {
        debugPrint('SharingService: Only absolute file paths are supported');
        throw Exception('Only absolute file paths are supported');
      }

      // Security: Limit maximum file size to prevent memory issues
      const maxFileSize = 10 * 1024 * 1024; // 10MB

      // Read file from filesystem
      final file = File(normalizedFilePath);
      debugPrint('SharingService: Checking if file exists at: ${file.path}');

      if (!await file.exists()) {
        debugPrint('SharingService: File does not exist at: ${file.path}');
        
        // If file doesn't exist, check if this might be a file path that should have been
        // handled as text content (common issue with iOS share extension)
        if (filePath.contains('File Provider Storage') || 
            filePath.contains('%20') || 
            filePath.contains('Library/Developer/CoreSimulator')) {
          debugPrint('SharingService: This looks like a sandboxed file path that should have been handled as text content');
          
          // Try to extract the filename and treat the path as content
          final fileName = normalizedFilePath.split('/').last;
          final helpfulContent = '''📱 iOS File Sharing Issue

This file could not be loaded because it's in a sandboxed iOS location that the main app cannot access.

File path: $filePath

💡 How to share this file properly:

1. **Save to Files First**
   - Open the file in the original app
   - Tap "Share" → "Save to Files"
   - Choose "On My iPhone" location
   - Then share from the Files app

2. **Share as Text**
   - Open the file in the original app
   - Use "Share as Text" or "Copy" option
   - Paste the content into this app

3. **Use "Open With"**
   - Long-press the file
   - Choose "Open With" → "ViewSourceVibe"

🔧 Technical Note:
The iOS Share Extension needs to read file content and pass it as bytes, not just the file path.''';
          
          final htmlFile = HtmlFile(
            name: fileName,
            path: 'shared://unavailable',
            content: helpfulContent,
            lastModified: DateTime.now(),
            size: helpfulContent.length,
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
        debugPrint('SharingService: File size exceeds maximum limit (10MB)');
        throw Exception('File size exceeds maximum limit (10MB)');
      }

      debugPrint('SharingService: File exists, reading content...');
      final content = await file.readAsString();
      debugPrint('SharingService: Read ${content.length} characters from file');

      final fileName = normalizedFilePath.split('/').last;

      final htmlFile = HtmlFile(
        name: fileName,
        path: normalizedFilePath,
        content: content,
        lastModified: await file.lastModified(),
        size: fileSize,
        isUrl: false,
      );

      debugPrint('SharingService: Loading file into HtmlService...');
      await htmlService.loadFile(htmlFile);
      debugPrint('SharingService: File loaded into HtmlService');
    } catch (e) {
      debugPrint('SharingService: Error handling file path: $e');
      if (context.mounted) {
        _showSnackBar(context, 'Error loading file: ${e.toString()}');
      }
      rethrow;
    }
  }

  /// Show snackbar message
  static void _showSnackBar(BuildContext context, String message) {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      debugPrint('SharingService: Error showing snackbar: $e');
    }
  }

  /// Check if a string is a URL using Dart's Uri class for robust parsing
  @visibleForTesting
  static bool isUrl(String text) {
    // Remove any surrounding whitespace and quotes
    final trimmedText = text.trim();

    // Handle empty strings
    if (trimmedText.isEmpty) {
      return false;
    }

    final cleanText = trimmedText.startsWith('"') && trimmedText.endsWith('"')
        ? trimmedText.substring(1, trimmedText.length - 1)
        : (trimmedText.startsWith("'") && trimmedText.endsWith("'"))
            ? trimmedText.substring(1, trimmedText.length - 1)
            : trimmedText;

    // First, check if this is explicitly a file URL (file:// protocol)
    if (cleanText.startsWith('file://') || cleanText.startsWith('file///')) {
      debugPrint('SharingService: Detected file URL, not HTTP URL: $cleanText');
      return false; // This is a file URL, not an HTTP URL
    }

    // Check if this is likely a file path (starts with /) - do this early to avoid false positives
    if (cleanText.startsWith('/')) {
      debugPrint('SharingService: Detected absolute file path, not URL: $cleanText');
      return false; // This is an absolute file path, not a URL
    }

    // Try to parse as URI - this is more robust than regex
    // Check if it's a valid HTTP/HTTPS URL first
    try {
      final uri = Uri.tryParse(cleanText);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        // This is a valid HTTP/HTTPS URL
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
      debugPrint('SharingService: Detected file path pattern, not URL: $cleanText');
      return false; // This contains file path patterns, not a URL
    }

    return false; // Not a URL
  }

  /// Check if a string is a file path
  @visibleForTesting
  static bool isFilePath(String text) {
    // Remove any surrounding whitespace and quotes
    final trimmedText = text.trim();

    // Handle empty strings
    if (trimmedText.isEmpty) {
      return false;
    }

    final cleanText = trimmedText.startsWith('"') && trimmedText.endsWith('"')
        ? trimmedText.substring(1, trimmedText.length - 1)
        : (trimmedText.startsWith("'") && trimmedText.endsWith("'"))
            ? trimmedText.substring(1, trimmedText.length - 1)
            : trimmedText;

    // First, check if it's definitely NOT a file path (it's a URL)
    if (cleanText.startsWith('http://') ||
        cleanText.startsWith('https://') ||
        cleanText.startsWith('www.') ||
        cleanText.startsWith('ftp://')) {
      return false;
    }

    // Check for file path patterns - be more specific
    // First check for absolute paths and special prefixes
    if (cleanText.startsWith('/') ||
        cleanText.startsWith('file://') ||
        cleanText.startsWith('file///') ||
        cleanText.startsWith('./') ||
        cleanText.startsWith('../')) {
      debugPrint(
          'SharingService: Detected file path (absolute/relative): $cleanText');
      return true;
    }

    // Then check for paths containing directory separators and common directory names
    if (cleanText.contains('/Users/') ||
        cleanText.contains('/Library/') ||
        cleanText.contains('/Containers/') ||
        cleanText.contains('/Applications/') ||
        cleanText.contains('/var/mobile/') ||
        cleanText.contains('/private/var/') ||
        cleanText.contains('.app/') ||
        cleanText.contains('/Documents/') ||
        cleanText.contains('/Downloads/') ||
        cleanText.contains('/Desktop/') ||
        cleanText.contains('Documents/') ||
        cleanText.contains('Downloads/') ||
        cleanText.contains('Desktop/') ||
        cleanText.contains('assets/') ||
        cleanText.contains('resources/') ||
        cleanText.contains('temp/') ||
        cleanText.contains('cache/') ||
        cleanText.contains('data/') ||
        cleanText.contains('files/') ||
        cleanText.contains('documents/') ||
        cleanText.contains('images/') ||
        cleanText.contains('videos/')) {
      debugPrint(
          'SharingService: Detected file path (with directory): $cleanText');
      return true;
    }

    // Check for simple filenames with extensions (but not URLs)
    if (!cleanText.contains('/') &&
        !cleanText.contains('\\') && // Don't match Windows paths
        !cleanText.contains('://') &&
        cleanText.contains('.') &&
        !cleanText
            .startsWith('.') && // Don't match hidden files like .gitignore
        cleanText.length > 3) {
      // At least "a.b"
      debugPrint('SharingService: Detected simple filename: $cleanText');
      return true;
    }

    return false;
  }

  /// Check for shared content when app is launched
  static Future<Map<String, dynamic>?> checkForSharedContent() async {
    try {
      const MethodChannel channel =
          MethodChannel('info.wouter.sourceviewer/shared_content');
      final result = await channel.invokeMethod('getSharedContent');
      return result != null ? Map<String, dynamic>.from(result) : null;
    } catch (e) {
      debugPrint('Error checking for shared content: $e');
      return null;
    }
  }
}
