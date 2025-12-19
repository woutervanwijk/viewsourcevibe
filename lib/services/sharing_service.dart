import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/services/html_service.dart';

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
      debugPrint('shared $sharedText - $sharedUrl');
      final htmlService = Provider.of<HtmlService>(context, listen: false);

      // Process the shared content based on type
      // Priority 1: Handle explicit URL sharing
      if (sharedUrl != null && sharedUrl.isNotEmpty) {
        // Handle shared URL
        await _processSharedUrl(context, htmlService, sharedUrl);
      }
      // Priority 2: Check if shared text is actually a URL
      else if (sharedText != null &&
          sharedText.isNotEmpty &&
          isUrl(sharedText)) {
        // Handle text that looks like a URL
        await _processSharedUrl(context, htmlService, sharedText);
      }
      // Priority 2.5: Check if shared text is actually a file path
      else if (sharedText != null &&
          sharedText.isNotEmpty &&
          isFilePath(sharedText)) {
        // Handle text that looks like a file path
        debugPrint(
            'SharingService: Routing shared text as file path: $sharedText');
        await _processSharedFilePath(context, htmlService, sharedText);
      }
      // Priority 3: Handle regular text content
      else if (sharedText != null && sharedText.isNotEmpty) {
        // Handle shared text
        await _processSharedText(context, htmlService, sharedText);
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
      debugPrint('SharingService: Loading URL: $url');

      // Show loading indicator
      if (context.mounted) {
        _showSnackBar(context, 'Loading URL...');
      }

      // Load the URL using the existing HTML service
      await htmlService.loadFromUrl(url);

      // Show success message
      if (context.mounted) {
        _showSnackBar(context, 'URL loaded successfully!');
      }

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
        name: 'shared_text.txt',
        path: 'shared://text',
        content: text,
        lastModified: DateTime.now(),
        size: text.length,
      );

      await htmlService.loadFile(htmlFile);
      if (context.mounted) {
        _showSnackBar(context, 'Text loaded successfully!');
      }
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

      final content = String.fromCharCodes(bytes);
      final name = fileName ?? 'shared_file.txt';

      final htmlFile = HtmlFile(
        name: name,
        path: 'shared://file',
        content: content,
        lastModified: DateTime.now(),
        size: bytes.length,
      );

      await htmlService.loadFile(htmlFile);
      if (context.mounted) {
        _showSnackBar(context, 'File loaded successfully!');
      }
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

      // Read file from filesystem
      final file = File(normalizedFilePath);
      debugPrint('SharingService: Checking if file exists at: ${file.path}');

      if (!await file.exists()) {
        debugPrint('SharingService: File does not exist at: ${file.path}');
        throw Exception('File does not exist: $normalizedFilePath');
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
        size: await file.length(),
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
    final cleanText = trimmedText.startsWith('"') && trimmedText.endsWith('"')
        ? trimmedText.substring(1, trimmedText.length - 1)
        : (trimmedText.startsWith("'") && trimmedText.endsWith("'"))
            ? trimmedText.substring(1, trimmedText.length - 1)
            : trimmedText;

    // Check if this is a file path (starts with / or contains file system patterns)
    if (cleanText.startsWith('/') ||
        cleanText.contains('file://') ||
        cleanText.contains('file///') ||
        cleanText.contains('Users/') ||
        cleanText.contains('Library/') ||
        cleanText.contains('Containers/') ||
        cleanText.contains('Applications/')) {
      debugPrint('SharingService: Detected file path, not URL: $cleanText');
      return false; // This is a file path, not a URL
    }

    // Try to parse as URI - this is more robust than regex
    try {
      // Handle URLs with or without protocol
      final uri =
          cleanText.startsWith('http://') || cleanText.startsWith('https://')
              ? Uri.parse(cleanText)
              : Uri.parse('https://$cleanText'); // Add https:// if missing

      // Check if it's a valid URL
      return uri.hasScheme && uri.hasAuthority && !uri.path.contains(' ');
    } catch (e) {
      // If parsing fails, it's not a valid URL
      return false;
    }
  }

  /// Check if a string is a file path
  @visibleForTesting
  static bool isFilePath(String text) {
    // Remove any surrounding whitespace and quotes
    final trimmedText = text.trim();
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
